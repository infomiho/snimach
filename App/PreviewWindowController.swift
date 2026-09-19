import AppKit
import SnimachCore

enum PreviewOutcome: Equatable {
    case edit
    case save
    case dismiss
}

@MainActor
protocol PreviewController: AnyObject {
    var onFinish: ((PreviewOutcome) -> Void)? { get set }
    func show()
    func close()
}

/// A thumbnail card in the bottom-right corner of the screen the shot came from. The shot is
/// scaled down to fit a fixed box, never up, and the card never shrinks below a clickable size.
struct PreviewLayout {
    static let maxThumbnail = CGSize(width: 240, height: 160)
    static let minCard = CGSize(width: 120, height: 80)
    static let margin: CGFloat = 16
    static let cornerRadius: CGFloat = Brand.cardRadius
    static let lifetime: Duration = .seconds(5)
    static let lifetimeAfterHover: Duration = .seconds(2)
    /// Opaque footer strip below the shot holding Open plus Save plus Discard on card chrome.
    static let footerHeight: CGFloat = 34

    let cardSize: CGSize
    let thumbnailFrame: CGRect

    static func make(shot: CGSize) -> PreviewLayout {
        let fit = min(1, maxThumbnail.width / shot.width, maxThumbnail.height / shot.height)
        let thumbnail = CGSize(width: (shot.width * fit).rounded(), height: (shot.height * fit).rounded())
        let content = CGSize(
            width: max(thumbnail.width, minCard.width),
            height: max(thumbnail.height, minCard.height)
        )
        let card = CGSize(width: content.width, height: content.height + footerHeight)
        let origin = CGPoint(
            x: ((card.width - thumbnail.width) / 2).rounded(),
            y: (footerHeight + (content.height - thumbnail.height) / 2).rounded()
        )
        return PreviewLayout(cardSize: card, thumbnailFrame: CGRect(origin: origin, size: thumbnail))
    }

    /// Bottom-right corner of `visible`, inset by the margin.
    static func cornerFrame(cardSize: CGSize, in visible: CGRect) -> CGRect {
        CGRect(
            x: (visible.maxX - margin - cardSize.width).rounded(),
            y: (visible.minY + margin).rounded(),
            width: cardSize.width,
            height: cardSize.height
        )
    }
}

/// The opt-in step between a capture and the editor. Shows the shot as a card, slides it in, and
/// reports `.edit` on click or `.dismiss` when the lifetime runs out. Hovering keeps it on screen.
@MainActor
final class PreviewWindowController: NSObject, PreviewController {
    var onFinish: ((PreviewOutcome) -> Void)?

    let panel: NSPanel
    let restingFrame: CGRect
    private var lifetime: Task<Void, Never>?
    private let hideManually: Bool

    /// `dragFile` writes the shot somewhere the Finder can take it. Nil disables dragging.
    /// When `hideManually` is true the card stays up until Open, Save, X, or the next capture.
    init(shot: Shot, dragFile: (() throws -> URL)? = nil, hideManually: Bool = false) {
        let layout = PreviewLayout.make(shot: shot.frame.size)
        let screen = NSScreen.nearest(shot.frame)
        let visible = screen?.visibleFrame ?? shot.frame
        let frame = PreviewLayout.cornerFrame(cardSize: layout.cardSize, in: visible)

        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = false

        let card = PreviewCardView(shot: shot, layout: layout)
        card.dragFile = dragFile
        panel.contentView = card

        self.panel = panel
        self.restingFrame = frame
        self.hideManually = hideManually
        super.init()

        card.onClick = { [weak self] in self?.finish(.edit) }
        card.onSave = { [weak self] in self?.finish(.save) }
        card.onDiscard = { [weak self] in self?.finish(.dismiss) }
        card.onHoverChange = { [weak self] hovering in
            guard let self, !self.hideManually else { return }
            if hovering {
                self.lifetime?.cancel()
            } else {
                self.startLifetime(PreviewLayout.lifetimeAfterHover)
            }
        }
    }

    func show() {
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        var start = restingFrame
        if !reduceMotion {
            start.origin.x += restingFrame.width + PreviewLayout.margin
        }
        panel.setFrame(start, display: false)
        panel.alphaValue = 0
        panel.animationBehavior = .none
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = reduceMotion ? 0.15 : 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            panel.animator().setFrame(restingFrame, display: true)
        }
        if !hideManually {
            startLifetime(PreviewLayout.lifetime)
        }
    }

    func close() {
        lifetime?.cancel()
        lifetime = nil
        panel.orderOut(nil)
        panel.close()
    }

    private func startLifetime(_ duration: Duration) {
        lifetime?.cancel()
        lifetime = Task { [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            self?.fadeOutAndFinish()
        }
    }

    private func fadeOutAndFinish() {
        lifetime = nil
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            Task { @MainActor in self?.finish(.dismiss) }
        }
    }

    private func finish(_ outcome: PreviewOutcome) {
        let callback = onFinish
        onFinish = nil
        close()
        callback?(outcome)
    }
}

enum PreviewCardAction {
    case open
    case save
    case discard
}

/// The card itself: rounded, bordered, the shot as layer contents. Reports clicks and hover.
/// On hover it reveals Open plus Save plus Discard targets along the bottom edge so the shot
/// can be kept, filed or dropped without opening the editor.
final class PreviewCardView: NSView {
    var onClick: (() -> Void)?
    var onSave: (() -> Void)?
    var onDiscard: (() -> Void)?
    var onHoverChange: ((Bool) -> Void)?
    var dragFile: (() throws -> URL)?

    private let shot: Shot
    private let thumbnailFrame: CGRect
    private var mouseDownAt: CGPoint?
    private var isDragging = false
    private let actionBar = PreviewActionBarView()

    static func footerFrame(in bounds: CGRect) -> CGRect {
        CGRect(x: 0, y: 0, width: bounds.width, height: PreviewLayout.footerHeight)
    }

    init(shot: Shot, layout: PreviewLayout) {
        self.shot = shot
        self.thumbnailFrame = layout.thumbnailFrame
        super.init(frame: CGRect(origin: .zero, size: layout.cardSize))
        wantsLayer = true
        toolTip = "Copied. Click to annotate, hover for save or discard, or drag the image out."

        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        layer?.cornerRadius = PreviewLayout.cornerRadius
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.masksToBounds = true

        let thumbnail = CALayer()
        thumbnail.frame = layout.thumbnailFrame
        thumbnail.contents = shot.image
        thumbnail.contentsGravity = .resizeAspect
        thumbnail.contentsScale = shot.scale
        thumbnail.name = "thumbnail"
        layer?.addSublayer(thumbnail)

        let hairline = CALayer()
        hairline.frame = CGRect(
            x: 0,
            y: PreviewLayout.footerHeight,
            width: layout.cardSize.width,
            height: 1
        )
        hairline.backgroundColor = NSColor.separatorColor.cgColor
        layer?.addSublayer(hairline)

        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .cursorUpdate, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
        actionBar.frame = Self.footerFrame(in: bounds)
        actionBar.autoresizingMask = [.width, .maxYMargin]
        actionBar.toolTip = "Open in editor, save to file, or discard"
        addSubview(actionBar)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.pointingHand.set()
    }

    override func mouseEntered(with event: NSEvent) {
        onHoverChange?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHoverChange?(false)
    }

    /// The click fires on mouse up, so a drag out of the card is possible at all. Firing on
    /// mouse down would open the editor before the drag could start.
    override func mouseDown(with event: NSEvent) {
        mouseDownAt = event.locationInWindow
        isDragging = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard !isDragging, let start = mouseDownAt, let dragFile else { return }
        let moved = hypot(
            event.locationInWindow.x - start.x,
            event.locationInWindow.y - start.y
        )
        guard moved >= Self.dragThreshold, let url = try? dragFile() else { return }

        isDragging = true
        let item = NSDraggingItem(pasteboardWriter: url as NSURL)
        item.setDraggingFrame(
            thumbnailFrame,
            contents: NSImage(cgImage: shot.image, size: thumbnailFrame.size)
        )
        beginDraggingSession(with: [item], event: event, source: self)
    }

    override func mouseUp(with event: NSEvent) {
        let dragged = isDragging
        mouseDownAt = nil
        isDragging = false
        guard !dragged else { return }
        let point = convert(event.locationInWindow, from: nil)
        switch actionAt(point) {
        case .open: onClick?()
        case .save: onSave?()
        case .discard: onDiscard?()
        case nil: onClick?()
        }
    }

    private func actionAt(_ point: NSPoint) -> PreviewCardAction? {
        guard point.y < PreviewLayout.footerHeight else { return nil }
        let total = PreviewActionBarView.buttonWidth * 3
        let startX = ((bounds.width - total) / 2).rounded()
        guard point.x >= startX, point.x <= startX + total else { return nil }
        switch Int((point.x - startX) / PreviewActionBarView.buttonWidth) {
        case 0: return .open
        case 1: return .save
        default: return .discard
        }
    }

    private static let dragThreshold: CGFloat = 4
}

extension PreviewCardView: NSDraggingSource {
    func draggingSession(_ session: NSDraggingSession,
                         sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        .copy
    }
}

/// Footer strip on opaque card chrome below the shot, so the buttons never blend into
/// image pixels. Glyphs are drawn at full strength because buttons in a never-active panel
/// render dimmed by AppKit. Clicks fall through to the parent, so plain clicks and drags
/// keep working in a non activating panel.
private final class PreviewActionBarView: NSView {
    static let buttonWidth: CGFloat = 44
    /// Glyphs draw at 80 percent of the bundled 18pt icon, so they sit with breathing room.
    static let glyphScale: CGFloat = 0.8

    private static let icons = ["pen-linear", "diskette-linear", "close-circle-linear"]

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        let total = Self.buttonWidth * CGFloat(Self.icons.count)
        let startX = ((bounds.width - total) / 2).rounded()
        for (index, name) in Self.icons.enumerated() {
            guard let image = BundledIcon.image(name) else { continue }
            let glyph = tinted(image, color: .controlTextColor)
            let drawSize = NSSize(
                width: (glyph.size.width * Self.glyphScale).rounded(),
                height: (glyph.size.height * Self.glyphScale).rounded()
            )
            let x = startX + CGFloat(index) * Self.buttonWidth
            let origin = CGPoint(
                x: (x + (Self.buttonWidth - drawSize.width) / 2).rounded(),
                y: ((bounds.height - drawSize.height) / 2).rounded()
            )
            glyph.draw(in: CGRect(origin: origin, size: drawSize))
        }
    }

    private func tinted(_ image: NSImage, color: NSColor) -> NSImage {
        let copy = NSImage(size: image.size)
        copy.lockFocus()
        color.set()
        CGRect(origin: .zero, size: copy.size).fill()
        image.draw(in: CGRect(origin: .zero, size: copy.size), from: .zero, operation: .destinationIn, fraction: 1)
        copy.unlockFocus()
        return copy
    }
}
