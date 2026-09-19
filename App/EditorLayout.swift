import AppKit
import SnimachCore

struct EditorLayout {
    static let style: NSWindow.StyleMask = [.titled, .closable, .resizable, .nonactivatingPanel]
    static let minimumContentSize = CGSize(width: 360, height: 280)
    let contentSize: CGSize
    let canvasFrame: CGRect
    let zoom: CGFloat

    static func make(shot: CGRect, maxContent: CGSize? = nil) -> EditorLayout {
        make(contentSize: shot.size, maxContent: maxContent)
    }

    static func make(contentSize: CGSize, maxContent: CGSize? = nil) -> EditorLayout {
        let natural = CGSize(
            width: max(minimumContentSize.width, contentSize.width + EditorStyle.inset * 2),
            height: max(minimumContentSize.height, contentSize.height + EditorStyle.inset * 2)
        )
        let size = CGSize(width: min(natural.width, maxContent?.width ?? natural.width),
                          height: min(natural.height, maxContent?.height ?? natural.height))
        return EditorLayout(contentSize: size, canvasFrame: canvasFrame(for: contentSize, in: size),
                            zoom: zoom(for: contentSize, in: size))
    }

    static func zoom(for shot: CGSize, in content: CGSize) -> CGFloat {
        guard shot.width > 0, shot.height > 0 else { return 1 }
        let width = max(1, content.width - EditorStyle.inset * 2)
        let height = max(1, content.height - EditorStyle.inset * 2)
        return min(1, width / shot.width, height / shot.height)
    }

    static func canvasFrame(for shot: CGSize, in content: CGSize) -> CGRect {
        let scale = zoom(for: shot, in: content)
        let size = CGSize(width: floor(shot.width * scale), height: floor(shot.height * scale))
        return CGRect(x: ((content.width - size.width) / 2).rounded(),
                      y: ((content.height - size.height) / 2).rounded(),
                      width: size.width, height: size.height)
    }

    static func clampedFrame(_ frame: CGRect, near shot: CGRect) -> CGRect {
        let visible = NSScreen.nearest(shot)?.visibleFrame ?? shot
        let x = min(max(shot.midX - frame.width / 2, visible.minX), max(visible.minX, visible.maxX - frame.width))
        let y = min(max(shot.midY - frame.height / 2, visible.minY), max(visible.minY, visible.maxY - frame.height))
        return CGRect(x: x.rounded(), y: y.rounded(), width: frame.width, height: frame.height)
    }
}

final class EditorStageView: NSView {
    let canvas: CanvasView
    let accessoryBar: EditorAccessoryBar
    let readout: ColorReadoutView
    private var transitionImage: NSImageView?
    private var readoutAtTop = true

    init(canvas: CanvasView, accessoryBar: EditorAccessoryBar, readout: ColorReadoutView) {
        self.canvas = canvas
        self.accessoryBar = accessoryBar
        self.readout = readout
        super.init(frame: .zero)
        wantsLayer = true
        addSubview(canvas)
        addSubview(accessoryBar)
        addSubview(readout)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds,
            options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect], owner: self))
    }

    override func mouseMoved(with event: NSEvent) {
        avoidPointer(convert(event.locationInWindow, from: nil))
    }

    override func layout() {
        super.layout()
        let barSize = accessoryBar.arrange(in: bounds.width)
        accessoryBar.frame.origin = CGPoint(x: ((bounds.width - barSize.width) / 2).rounded(), y: EditorStyle.toolbarBottomInset)
        positionReadout()
        canvas.frame = EditorLayout.canvasFrame(for: canvas.document.stageSize, in: bounds.size)
    }

    func avoidPointer(_ point: CGPoint) {
        guard canvas.isPickingColor, !canvas.isColorFrozen,
              readout.frame.insetBy(dx: -24, dy: -24).contains(point) else { return }
        readoutAtTop.toggle()
        positionReadout()
    }

    private func positionReadout() {
        let y = readoutAtTop
            ? bounds.maxY - EditorStyle.inset - ColorReadoutView.size.height
            : accessoryBar.frame.maxY + EditorStyle.readoutGap
        readout.frame.origin = CGPoint(x: ((bounds.width - ColorReadoutView.size.width) / 2).rounded(), y: y)
    }

    func transition(from previous: Document) {
        transitionImage?.removeFromSuperview()
        transitionImage = nil
        guard window?.isVisible == true, !EditorStyle.reducesMotion,
              let image = try? previous.render() else {
            needsLayout = true
            layoutSubtreeIfNeeded()
            return
        }
        let snapshot = StageSnapshotView(frame: canvas.frame)
        snapshot.image = NSImage(cgImage: image, size: previous.stageSize)
        snapshot.imageScaling = .scaleAxesIndependently
        snapshot.wantsLayer = true
        snapshot.layer?.cornerRadius = Brand.cardRadius
        snapshot.layer?.masksToBounds = true
        addSubview(snapshot, positioned: .above, relativeTo: canvas)
        transitionImage = snapshot
        canvas.alphaValue = 0
        needsLayout = true
        layoutSubtreeIfNeeded()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = EditorStyle.transitionDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            snapshot.animator().alphaValue = 0
            canvas.animator().alphaValue = 1
        } completionHandler: { [weak self, weak snapshot] in
            snapshot?.removeFromSuperview()
            if self?.transitionImage === snapshot { self?.transitionImage = nil }
        }
    }
}

private final class StageSnapshotView: NSImageView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
