import AppKit
import CoreGraphics

/// One borderless window per `NSScreen`, at `.screenSaver` level so it sits above everything,
/// including full-screen apps. Each window shows its display's frozen pixels under the dim, so
/// the user selects on the exact image the shot is cropped from. The drag is in AppKit global
/// points, clamped to the display where it started. Esc, a tiny drag or task cancellation end it
/// with `CancellationError`.
@MainActor
final class OverlayAreaSelector: NSObject, AreaSelector {
    private var panels: [OverlayPanel] = []
    private var frozen: [FrozenDisplay] = []
    /// Pickable windows as handed in, CG points, front to back.
    private var pickable: [CGRect] = []
    /// The same windows in AppKit points, filled in once the screens are known.
    private var windows: [CGRect] = []
    /// The window under the pointer before any drag starts.
    private var hovered: CGRect?
    private var previousApp: NSRunningApplication?
    private var continuation: CheckedContinuation<CGRect, Error>?
    private var isFinished = false
    private var band: RubberBand?
    private var mainDisplayHeight: CGFloat = 0
    private var cursorPushed = false

    func select(over displays: [FrozenDisplay], windows: [CGRect]) async throws -> CGRect {
        // A second `capture(.area)` cancels the first and restarts.
        if continuation != nil {
            finish(with: .failure(CancellationError()))
        }
        frozen = displays
        pickable = windows
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            self.isFinished = false
            self.present()
        }
    }

    func cancel() {
        finish(with: .failure(CancellationError()))
    }

    private func present() {
        let screens = NSScreen.screens
        guard !screens.isEmpty else {
            finish(with: .failure(CaptureError.failed(underlying: OverlayError.noScreens)))
            return
        }
        // `NSScreen.main` is the key window's screen, which can be any display. The flip needs
        // the primary display, the one at origin zero, which AppKit lists first.
        mainDisplayHeight = screens[0].frame.height
        windows = pickable.map(flipped)
        previousApp = NSWorkspace.shared.frontmostApplication

        for screen in screens {
            let panel = OverlayPanel(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            panel.isReleasedWhenClosed = false
            panel.level = .screenSaver
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.hidesOnDeactivate = false
            panel.acceptsMouseMovedEvents = true
            // `.default` lets AppKit animate the window in, which zooms the frozen screen into
            // place and reads as the whole screen jumping. The overlay must appear in one frame.
            panel.animationBehavior = .none
            panel.interaction = self

            panel.contentView = makeContent(for: screen)
            panels.append(panel)
        }

        for panel in panels { panel.orderFrontRegardless() }
        // `NSApp.activate()` silently fails for LSUIElement apps. The fallout matches every
        // symptom: no key events and no pushed cursor (pushes only show for the active app)
        // until a click activates us. Activating via the running application works reliably.
        NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps])
        panels.first?.makeKey()
        // `push`, not `set`: activation and cursor-rect evaluation clobber a set cursor,
        // while a pushed one sticks until `pop`, with no click or mouse move needed.
        NSCursor.crosshair.push()
        cursorPushed = true
        mouseMoved()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidResignActive),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    /// The frozen image sits in a layer of its own so the dim view above it redraws only the
    /// cheap dim path on every drag.
    private func makeContent(for screen: NSScreen) -> NSView {
        let bounds = CGRect(origin: .zero, size: screen.frame.size)
        let content = NSView(frame: bounds)
        content.wantsLayer = true
        content.layer?.contents = frozenImage(for: screen)
        content.layer?.contentsGravity = .resize
        content.layer?.contentsScale = screen.backingScaleFactor

        let view = OverlayView(frame: bounds)
        view.screenFrame = screen.frame
        view.autoresizingMask = [.width, .height]
        content.addSubview(view)
        return content
    }

    private func frozenImage(for screen: NSScreen) -> CGImage? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        guard let number = screen.deviceDescription[key] as? NSNumber else { return nil }
        let id = CGDirectDisplayID(truncating: number)
        return frozen.first { $0.display.id == id }?.image
    }

    /// Re-push after returning from another app. Pairs with the pop in
    /// `applicationDidResignActive` so push/pop stay balanced.
    @objc private func applicationDidBecomeActive() {
        if !cursorPushed {
            NSCursor.crosshair.push()
            cursorPushed = true
        }
    }

    /// Switching to another app mid-drag cancels, but only once a drag is under way so the
    /// activation itself cannot cancel the overlay. Either way the pushed cursor is popped so
    /// it never leaks into the other app.
    @objc private func applicationDidResignActive() {
        if cursorPushed {
            NSCursor.pop()
            cursorPushed = false
        }
        guard band != nil else { return }
        cancel()
    }

    @objc private func screenParametersChanged() {
        cancel()
    }

    /// `bounds` is the frame of the panel that took the click, so a press on the very edge of a
    /// display, where the pointer sits outside every `NSScreen.frame`, still starts a drag there.
    func mouseDown(at point: CGPoint, within bounds: CGRect) {
        guard !isFinished else { return }
        band = RubberBand(origin: point, bounds: bounds)
        band?.isSquare = NSEvent.modifierFlags.contains(.shift)
        refresh()
    }

    func mouseDragged(to point: CGPoint) {
        guard !isFinished, band != nil else { return }
        band?.drag(to: point)
        refresh()
    }

    func mouseMoved() {
        guard !isFinished, band == nil else { return }
        hovered = CaptureGeometry.frontmostWindow(containing: NSEvent.mouseLocation, in: windows)
        refresh()
    }

    func mouseUp() {
        guard !isFinished else { return }
        if let rect = band?.rect, rect.width >= 2, rect.height >= 2 {
            finish(with: .success(flipped(rect)))
        } else if let hovered {
            // A click with no drag takes the window under the pointer.
            finish(with: .success(flipped(hovered)))
        } else {
            finish(with: .failure(CancellationError()))
        }
    }

    func spaceChanged(isDown: Bool) {
        band?.isMoving = isDown
    }

    func modifiersChanged(_ flags: NSEvent.ModifierFlags) {
        guard band != nil else { return }
        band?.isSquare = flags.contains(.shift)
        refresh()
    }

    /// The views redraw only when their selection or guideline position changed, so a pointer
    /// moving on one display does not repaint the others.
    private static let dragThreshold: CGFloat = 3

    /// True once the drag is big enough to mean a region rather than a click.
    private var isDragging: Bool {
        guard let rect = band?.rect else { return false }
        return rect.width >= Self.dragThreshold || rect.height >= Self.dragThreshold
    }

    private func refresh() {
        let mouse = NSEvent.mouseLocation
        let dragging = isDragging
        // A click that has not moved yet still shows the window under the pointer.
        let shown = dragging ? band?.rect : (hovered ?? band?.rect)
        for panel in panels {
            guard let view = panel.contentView?.subviews.first as? OverlayView else { continue }
            view.selection = shown?.intersection(view.screenFrame)
            view.isPick = !dragging && hovered != nil
            view.showsHint = !dragging
            view.cursorPoint = band == nil && view.screenFrame.contains(mouse)
                ? CGPoint(x: mouse.x - view.screenFrame.minX, y: mouse.y - view.screenFrame.minY)
                : nil
        }
    }

    private func finish(with result: Result<CGRect, Error>) {
        guard !isFinished else { return }
        isFinished = true
        let continuation = self.continuation
        self.continuation = nil
        teardown()
        switch result {
        case .success(let rect): continuation?.resume(returning: rect)
        case .failure(let error): continuation?.resume(throwing: error)
        }
    }

    private func teardown() {
        NotificationCenter.default.removeObserver(self)
        if cursorPushed {
            NSCursor.pop()
            cursorPushed = false
        }
        for panel in panels {
            panel.orderOut(nil)
            panel.close()
        }
        panels.removeAll()
        frozen.removeAll()
        pickable.removeAll()
        windows.removeAll()
        hovered = nil
        band = nil
        previousApp?.activate()
        previousApp = nil
    }

    /// Flips a rect between AppKit points and CG points. The conversion is its own inverse, so
    /// one function serves both directions.
    private func flipped(_ rect: CGRect) -> CGRect {
        CaptureGeometry.appKitFrame(rect, mainDisplayHeight: mainDisplayHeight)
    }
}

enum OverlayError: Error {
    case noScreens
}

private final class OverlayPanel: NSWindow {
    weak var interaction: OverlayAreaSelector?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func mouseDown(with event: NSEvent) {
        interaction?.mouseDown(at: screenPoint(of: event), within: frame)
    }

    override func mouseDragged(with event: NSEvent) {
        interaction?.mouseDragged(to: screenPoint(of: event))
    }

    override func mouseUp(with event: NSEvent) {
        interaction?.mouseUp()
    }

    override func mouseMoved(with event: NSEvent) {
        interaction?.mouseMoved()
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case Self.escape: interaction?.cancel()
        case Self.space: interaction?.spaceChanged(isDown: true)
        default: super.keyDown(with: event)
        }
    }

    override func keyUp(with event: NSEvent) {
        if event.keyCode == Self.space {
            interaction?.spaceChanged(isDown: false)
        } else {
            super.keyUp(with: event)
        }
    }

    override func flagsChanged(with event: NSEvent) {
        interaction?.modifiersChanged(event.modifierFlags)
    }

    /// The event's own location, not `NSEvent.mouseLocation`: coalesced drag events carry the
    /// position they were generated at, which is where the user saw the band land.
    private func screenPoint(of event: NSEvent) -> CGPoint {
        convertPoint(toScreen: event.locationInWindow)
    }

    private static let escape: UInt16 = 53
    private static let space: UInt16 = 49
}

private final class OverlayView: NSView {
    var selection: CGRect? {
        didSet { needsDisplay = true }
    }
    var screenFrame: CGRect = .zero
    /// Pointer in view coordinates while it is over this screen before the drag, nil otherwise.
    var cursorPoint: CGPoint? {
        didSet { if cursorPoint != oldValue { needsDisplay = true } }
    }
    /// The selection is a window under the pointer rather than a dragged region.
    var isPick = false {
        didSet { if isPick != oldValue { needsDisplay = true } }
    }
    var showsHint = false {
        didSet { if showsHint != oldValue { needsDisplay = true } }
    }
    private var trackingArea: NSTrackingArea?

    override var isFlipped: Bool { false }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    /// Plain mouse-moved events reach the key window only, and only one panel is key. A tracking
    /// area active at all times delivers them for every display, and the panel forwards them.
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let dim = NSColor.black.withAlphaComponent(0.4).cgColor

        context.saveGState()
        defer { context.restoreGState() }

        guard let selection, selection.width > 0, selection.height > 0 else {
            context.setFillColor(dim)
            context.fill(bounds)
            if let cursorPoint { drawGuidelines(through: cursorPoint, in: context) }
            drawHint(in: context)
            return
        }

        let local = CGRect(
            x: selection.minX - screenFrame.minX,
            y: selection.minY - screenFrame.minY,
            width: selection.width,
            height: selection.height
        )
        let path = CGMutablePath()
        path.addRect(bounds)
        path.addRect(local)
        context.addPath(path)
        context.setFillColor(dim)
        context.fillPath(using: .evenOdd)

        if isPick {
            context.setStrokeColor(Self.pickColor)
            context.setLineWidth(3)
            context.stroke(local.insetBy(dx: -1.5, dy: -1.5))
        } else {
            context.setStrokeColor(NSColor.white.cgColor)
            context.setLineWidth(1)
            context.stroke(local)
        }

        drawSizeLabel(for: selection.size, at: CGPoint(x: local.minX, y: local.maxY + 4))
        drawHint(in: context)
    }

    /// Shown on the screen holding the pointer until a drag starts, because a click on a window
    /// is not something the overlay otherwise advertises.
    private func drawHint(in context: CGContext) {
        guard showsHint, cursorPoint != nil else { return }
        let text = "Drag to select    Click a window    Esc to cancel"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor.white,
        ]
        let size = (text as NSString).size(withAttributes: attributes)
        let padding: CGFloat = 16
        let pill = CGRect(
            x: ((bounds.width - size.width) / 2 - padding).rounded(),
            y: (bounds.maxY - 110).rounded(),
            width: (size.width + padding * 2).rounded(),
            height: (size.height + 14).rounded()
        )
        context.setFillColor(NSColor.black.withAlphaComponent(0.72).cgColor)
        context.addPath(CGPath(
            roundedRect: pill,
            cornerWidth: pill.height / 2,
            cornerHeight: pill.height / 2,
            transform: nil
        ))
        context.fillPath()
        (text as NSString).draw(
            at: CGPoint(x: pill.minX + padding, y: pill.minY + 7),
            withAttributes: attributes
        )
    }

    /// The logo accent, so a window pick never looks like a dragged region.
    private static let pickColor = Brand.accent

    /// Full-height and full-width lines through the pointer, so a selection can be lined up with
    /// content on the frozen image before the drag starts.
    private func drawGuidelines(through point: CGPoint, in context: CGContext) {
        let x = point.x.rounded() + 0.5
        let y = point.y.rounded() + 0.5
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.6).cgColor)
        context.setLineWidth(1)
        context.move(to: CGPoint(x: x, y: bounds.minY))
        context.addLine(to: CGPoint(x: x, y: bounds.maxY))
        context.move(to: CGPoint(x: bounds.minX, y: y))
        context.addLine(to: CGPoint(x: bounds.maxX, y: y))
        context.strokePath()
    }

    private func drawSizeLabel(for size: CGSize, at point: CGPoint) {
        let text = "\(Int(size.width.rounded())) x \(Int(size.height.rounded()))"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.white,
            .backgroundColor: NSColor.black.withAlphaComponent(0.7),
        ]
        text.draw(at: point, withAttributes: attributes)
    }
}
