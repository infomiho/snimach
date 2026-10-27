import AppKit
import SnimachCore

/// Adapts AppKit events and drawing to the document.
final class CanvasView: NSView, NSTextViewDelegate {
    private(set) var textEditor: AnnotationTextView?
    struct HoverColor {
        let hex: String
        let color: NSColor
    }

    var document: Document {
        didSet {
            if oldValue.shot.image !== document.shot.image || oldValue.shot.scale != document.shot.scale
                || oldValue.backdrop != document.backdrop || oldValue.backdropPreset != document.backdropPreset {
                stageCache = nil
            }
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
            if isPickingColor {
                document.apply(.toolSelected(document.tool))
                syncTextEditor()
            }
        }
    }
    private(set) var isColorFrozen = false
    /// Reports a sampled source pixel while inspecting colors.
    var onColorHover: ((HoverColor) -> Void)?

    /// Stable shot and backdrop, reused while annotations change.
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
        addCursorRect(bounds, cursor: document.tool == .select ? .arrow : .crosshair)
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
        defer { drawSelection(in: context) }
        if document.backdrop == .transparent {
            document.draw(in: context, baseInterpolation: isScaled ? .high : .none, includesTextDraft: false)
            return
        }
        if stageCache == nil {
            stageCache = try? document.renderStageBackground()
        }
        guard let stage = stageCache else {
            document.draw(in: context, baseInterpolation: isScaled ? .high : .none, includesTextDraft: false)
            return
        }
        context.saveGState()
        context.interpolationQuality = isScaled ? .high : .none
        context.draw(stage, in: CGRect(origin: .zero, size: bounds.size))
        context.restoreGState()
        document.drawStageAnnotations(in: context, includesTextDraft: false)
    }

    private func drawSelection(in context: CGContext) {
        guard let rect = document.selectionBounds else { return }
        let zoom = frame.width / bounds.width
        context.saveGState()
        context.translateBy(x: document.stageOrigin.x, y: document.stageOrigin.y)
        context.setStrokeColor(EditorStyle.accent.cgColor)
        context.setLineWidth(1 / zoom)
        context.setLineDash(phase: 0, lengths: [4 / zoom, 3 / zoom])
        context.stroke(rect.insetBy(dx: -3 / zoom, dy: -3 / zoom))
        context.restoreGState()
    }

    /// The shot is only pixel exact when the view is at its natural size.
    private var isScaled: Bool {
        abs(frame.width - bounds.width) > 0.5
    }

    override func mouseDown(with event: NSEvent) {
        if document.textDraft != nil {
            apply(.finishText)
            return
        }
        window?.makeFirstResponder(self)
        guard !isPickingColor else {
            sampleColor(at: point(of: event), selecting: true)
            return
        }
        apply(.angleConstrained(event.modifierFlags.contains(.shift)))
        apply(.arrowReversed(event.modifierFlags.contains(.command)))
        let location = point(of: event)
        if event.clickCount == 2 && document.tool == .select {
            apply(.editText(location))
        } else if document.tool != .text || CGRect(origin: .zero, size: document.pointSize).contains(location) {
            apply(.pointerDown(location))
        }
    }

    override func flagsChanged(with event: NSEvent) {
        apply(.angleConstrained(event.modifierFlags.contains(.shift)))
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
        if document.stageSize != before.stageSize {
            bounds = CGRect(origin: .zero, size: document.stageSize)
            onStageChange?(before)
        }
        syncTextEditor()
        needsDisplay = true
        window?.invalidateCursorRects(for: self)
        onChange?()
    }

    private func syncTextEditor() {
        guard let draft = document.textDraft else {
            guard let editor = textEditor else { return }
            textEditor = nil
            editor.delegate = nil
            editor.removeFromSuperview()
            window?.makeFirstResponder(self)
            return
        }
        if let editor = textEditor {
            editor.update(draft, stageOrigin: document.stageOrigin)
            return
        }
        let editor = AnnotationTextView()
        textEditor = editor
        editor.delegate = self
        editor.onFinish = { [weak self] in self?.apply(.finishText) }
        editor.onCancel = { [weak self] in
            self?.apply(.cancelText)
            self?.apply(.toolSelected(.select))
        }
        editor.update(draft, stageOrigin: document.stageOrigin)
        addSubview(editor)
        window?.makeFirstResponder(editor)
        editor.setSelectedRange(NSRange(location: (editor.string as NSString).length, length: 0))
    }

    func textDidChange(_ notification: Notification) {
        guard let editor = textEditor, notification.object as? NSTextView === editor else { return }
        apply(.textChanged(editor.string))
    }

    func handle(_ event: NSEvent) -> Bool {
        guard textEditor == nil else { return false }
        guard let key = EditorKeymap.key(forKeyCode: event.keyCode, modifiers: event.modifierFlags) else {
            return false
        }
        if isPickingColor && key == .commit {
            onTerminalKey?(.copyHex)
            return true
        }
        if key == .copyHex && !isPickingColor { return false }
        switch key {
        case .selectText: apply(.toolSelected(.text))
        case .selectLine: apply(.toolSelected(.line))
        case .select: apply(.toolSelected(.select))
        case .deleteSelection: apply(.deleteSelection)
        case .nudge(let offset): apply(.nudgeSelection(offset))
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
