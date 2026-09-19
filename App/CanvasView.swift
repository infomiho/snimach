import AppKit
import SnimachCore

/// The whole adapter between AppKit events and the `Document`. It draws through
/// `document.draw(in:)` and forwards mouse events as tool-agnostic actions.
final class CanvasView: NSView {
    struct HoverColor {
        let hex: String
        let color: NSColor
    }

    var document: Document {
        didSet {
            stageCache = nil
            bounds = CGRect(origin: .zero, size: document.stageSize)
            needsDisplay = true
        }
    }

    /// Window actions and inspection mode belong to the controller.
    var onTerminalKey: ((EditorKey) -> Void)?
    /// Fired after every action so the toolbar can refresh its state.
    var onChange: (() -> Void)?
    /// Carries the previous stage for the backdrop transition.
    var onStageChange: ((Document) -> Void)?
    var isPickingColor = false {
        didSet {
            isColorFrozen = false
            if isPickingColor { document.apply(.toolSelected(document.tool)) }
        }
    }
    private(set) var isColorFrozen = false
    /// Reports a sampled source pixel while inspecting colors.
    var onColorHover: ((HoverColor) -> Void)?

    /// Rendered export preview, so the stage looks exactly like the file.
    /// Flat mode keeps the direct draw path below.
    private var stageCache: CGImage?

    override var isFlipped: Bool { false }
    override var acceptsFirstResponder: Bool { true }

    /// AppKit scales bounds with the frame when the two sizes differ, so every
    /// frame change re-anchors bounds on the stage.
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        bounds = CGRect(origin: .zero, size: document.stageSize)
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    init(document: Document) {
        self.document = document
        super.init(frame: CGRect(origin: .zero, size: document.pointSize))
        bounds = CGRect(origin: .zero, size: document.stageSize)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        if document.backdrop == .transparent {
            document.draw(in: context, baseInterpolation: isScaled ? .high : .none)
            return
        }
        if stageCache == nil {
            stageCache = try? document.render()
        }
        guard let stage = stageCache else {
            document.draw(in: context, baseInterpolation: isScaled ? .high : .none)
            return
        }
        context.saveGState()
        context.interpolationQuality = isScaled ? .high : .none
        context.draw(stage, in: CGRect(origin: .zero, size: bounds.size))
        context.restoreGState()
    }

    /// The shot is only pixel exact when the view is at its natural size.
    private var isScaled: Bool {
        abs(frame.width - bounds.width) > 0.5
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        guard !isPickingColor else {
            sampleColor(at: point(of: event), selecting: true)
            return
        }
        apply(.arrowReversed(event.modifierFlags.contains(.command)))
        apply(.pointerDown(point(of: event)))
    }

    override func flagsChanged(with event: NSEvent) {
        apply(.arrowReversed(event.modifierFlags.contains(.command)))
    }

    override func mouseDragged(with event: NSEvent) {
        guard !isPickingColor else {
            return
        }
        apply(.pointerDragged(point(of: event)))
    }

    override func mouseUp(with event: NSEvent) {
        guard !isPickingColor else { return }
        apply(.pointerUp(point(of: event)))
    }

    override func mouseMoved(with event: NSEvent) {
        guard isPickingColor else { return }
        sampleColor(at: point(of: event))
    }

    func sampleColor(at location: CGPoint, selecting: Bool = false) {
        guard !isColorFrozen || selecting,
              CGRect(origin: .zero, size: document.pointSize).contains(location) else { return }
        guard let hex = ColorProbe.hex(at: location, in: document.shot),
              let rgb = ColorProbe.rgb(at: location, in: document.shot) else {
            return
        }
        let color = NSColor(
            srgbRed: CGFloat(rgb.r) / 255,
            green: CGFloat(rgb.g) / 255,
            blue: CGFloat(rgb.b) / 255,
            alpha: 1
        )
        isColorFrozen = selecting
        onColorHover?(HoverColor(hex: hex, color: color))
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if handle(event) { return true }
        return super.performKeyEquivalent(with: event)
    }

    override func keyDown(with event: NSEvent) {
        if handle(event) { return }
        super.keyDown(with: event)
    }

    private func point(of event: NSEvent) -> CGPoint {
        let point = convert(event.locationInWindow, from: nil)
        let origin = document.stageOrigin
        return CGPoint(x: point.x - origin.x, y: point.y - origin.y)
    }

    func apply(_ action: Action) {
        let before = document
        if case .toolSelected = action { isPickingColor = false }
        document.apply(action)
        stageCache = nil
        if document.stageSize != before.stageSize {
            bounds = CGRect(origin: .zero, size: document.stageSize)
            onStageChange?(before)
        }
        needsDisplay = true
        onChange?()
    }

    func handle(_ event: NSEvent) -> Bool {
        guard let key = EditorKeymap.key(forKeyCode: event.keyCode, modifiers: event.modifierFlags) else {
            return false
        }
        if isPickingColor && key == .commit {
            onTerminalKey?(.copyHex)
            return true
        }
        if key == .copyHex && !isPickingColor { return false }
        switch key {
        case .selectArrow:     apply(.toolSelected(.arrow))
        case .selectNumber:    apply(.toolSelected(.number))
        case .selectRectangle: apply(.toolSelected(.rectangle))
        case .selectRedact:    apply(.toolSelected(.redact))
        case .cycleBackdrop:   apply(.backdropSelected(document.backdrop.next))
        case .undo:         apply(.undo)
        case .redo:         apply(.redo)
        case .commit, .save, .discard, .copyHex, .togglePicker:
            onTerminalKey?(key)
        }
        return true
    }
}
