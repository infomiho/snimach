import AppKit
import SnimachCore

enum EditorStyle {
    static let inset: CGFloat = 24
    static let toolbarBottomInset: CGFloat = 32
    static let controlPadding: CGFloat = 8
    static let controlGap: CGFloat = 1
    static let groupPadding: CGFloat = 8
    static let readoutGap: CGFloat = 12
    static let controlSize = CGSize(width: 34, height: 30)
    static let barHeight: CGFloat = controlSize.height + controlPadding * 2
    static let cornerRadius: CGFloat = barHeight / 2
    static let transitionDuration: TimeInterval = 0.24
    static let accent = NSColor(
        srgbRed: Brand.accentComponents.red,
        green: Brand.accentComponents.green,
        blue: Brand.accentComponents.blue,
        alpha: 1
    )
    static var reducesMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
}

class EditorSurface: NSVisualEffectView {
    var cornerRadius: CGFloat = EditorStyle.cornerRadius {
        didSet { updateMask() }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        material = .hudWindow
        blendingMode = .withinWindow
        state = .active
        wantsLayer = true
        updateMask()
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
        shadow = NSShadow()
        shadow?.shadowColor = NSColor.black.withAlphaComponent(0.3)
        shadow?.shadowBlurRadius = 16
        shadow?.shadowOffset = NSSize(width: 0, height: -4)
    }

    private func updateMask() {
        let radius = cornerRadius
        let size = CGSize(width: radius * 2 + 1, height: radius * 2 + 1)
        let mask = NSImage(size: size, flipped: false) { rect in
            NSColor.white.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        mask.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        mask.resizingMode = .stretch
        maskImage = mask
        layer?.cornerRadius = radius
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}

final class EditorButton: NSButton {
    enum Segment { case leading, trailing }
    var segment: Segment?
    var segmentActive = false { didSet { needsDisplay = true } }
    static let labelInset: CGFloat = 8
    static let labelGap: CGFloat = 8
    static let swatchSize: CGFloat = 18
    static var backdropWidth: CGFloat {
        ceil(("Backdrop" as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 13)]).width)
            + swatchSize + labelGap + labelInset * 2
    }
    private var hovered = false
    var onPress: (() -> Void)?

    init(icon: String? = nil, label: String, shortcut: String? = nil) {
        super.init(frame: CGRect(origin: .zero, size: EditorStyle.controlSize))
        title = ""
        image = icon.flatMap(BundledIcon.image)
        imagePosition = .imageOnly
        isBordered = false
        bezelStyle = .regularSquare
        setButtonType(.momentaryChange)
        font = .systemFont(ofSize: 13)
        contentTintColor = .labelColor
        toolTip = shortcut.map { "\(label) (\($0))" } ?? label
        setAccessibilityLabel(label)
        target = self
        action = #selector(press)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    @objc private func press() { onPress?() }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }

    override func mouseEntered(with event: NSEvent) {
        hovered = true
        needsDisplay = true
    }
    override func mouseExited(with event: NSEvent) {
        hovered = false
        needsDisplay = true
    }

    private var highlightOpacity: CGFloat {
        if isHighlighted { return 0.22 }
        return state == .on ? 0.16 : 0.08
    }

    override func draw(_ dirtyRect: NSRect) {
        if let segment {
            drawSegment(segment)
            return
        }
        if isEnabled && (state == .on || hovered || isHighlighted) {
            let opacity = highlightOpacity
            NSColor.labelColor.withAlphaComponent(opacity).setFill()
            NSBezierPath(roundedRect: bounds, xRadius: 7, yRadius: 7).fill()
        }
        super.draw(dirtyRect)
    }

    private func drawSegment(_ segment: Segment) {
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: bounds).addClip()
        var outline = bounds
        outline.size.width += 7
        if segment == .trailing { outline.origin.x -= 7 }
        let background = NSBezierPath(roundedRect: outline, xRadius: 7, yRadius: 7)
        NSColor.labelColor.withAlphaComponent(segmentActive ? 0.12 : 0.04).setFill()
        background.fill()
        if hovered || isHighlighted || (segment == .trailing && state == .on) {
            NSColor.labelColor.withAlphaComponent(isHighlighted ? 0.12 : 0.06).setFill()
            background.fill()
        }
        if segment == .trailing {
            NSColor.labelColor.withAlphaComponent(0.14).setFill()
            NSBezierPath(rect: CGRect(x: 0, y: 7, width: 0.5, height: bounds.height - 14)).fill()
            cell?.drawInterior(withFrame: bounds, in: self)
        } else {
            let size = Self.swatchSize
            let x = title.isEmpty ? (bounds.width - size) / 2 : Self.labelInset
            image?.draw(in: CGRect(x: x, y: (bounds.height - size) / 2, width: size, height: size))
            if !title.isEmpty {
                let attributes: [NSAttributedString.Key: Any] = [.font: font!, .foregroundColor: NSColor.labelColor]
                let textSize = (title as NSString).size(withAttributes: attributes)
                (title as NSString).draw(at: CGPoint(x: x + size + Self.labelGap,
                    y: (bounds.height - textSize.height) / 2), withAttributes: attributes)
            }
        }
        NSGraphicsContext.restoreGraphicsState()
    }
}

struct ToolChoice {
    let tool: Tool
    let icon: String
    let label: String
    let key: String

    static let all: [ToolChoice] = [
        ToolChoice(tool: .arrow, icon: "arrow-right-up-linear", label: "Arrow", key: "A"),
        ToolChoice(tool: .number, icon: "hashtag-linear", label: "Number", key: "N"),
        ToolChoice(tool: .rectangle, icon: "stop-linear", label: "Rectangle", key: "R"),
        ToolChoice(tool: .redact, icon: "redact", label: "Hide", key: "B"),
    ]
}

final class EditorAccessoryBar: EditorSurface {
    let undoButton = EditorButton(icon: "undo-left-linear", label: "Undo", shortcut: "⌘Z")
    let redoButton = EditorButton(icon: "undo-right-linear", label: "Redo", shortcut: "⇧⌘Z")
    let backdropButton = EditorButton(label: "Backdrop", shortcut: "K")
    let presetsButton = EditorButton(icon: "alt-arrow-up-linear", label: "Choose a backdrop")
    let pickerButton = EditorButton(icon: "pipette-linear", label: "Color picker", shortcut: "I")
    let moreButton = EditorButton(icon: "menu-dots-linear", label: "More tools")
    private(set) var toolButtons: [EditorButton] = []
    private(set) var visibleTools: [Tool] = []
    private var selectedTool: Tool = .arrow
    private var picking = false
    private var availableWidth: CGFloat = 900
    var onTool: ((Tool) -> Void)?
    private let separators = [NSBox(), NSBox()]

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setAccessibilityRole(.toolbar)
        setAccessibilityLabel("Editor tools")
        toolButtons = ToolChoice.all.map { choice in
            let button = EditorButton(icon: choice.icon, label: choice.label, shortcut: choice.key)
            button.onPress = { [weak self] in self?.onTool?(choice.tool) }
            return button
        }
        for view in toolButtons + [moreButton, undoButton, redoButton, backdropButton, presetsButton, pickerButton] {
            addSubview(view)
        }
        for separator in separators {
            separator.boxType = .separator
            addSubview(separator)
        }
        backdropButton.imagePosition = .imageLeading
        backdropButton.segment = .leading
        presetsButton.segment = .trailing
        moreButton.onPress = { [weak self] in self?.showMoreTools() }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func update(document: Document, picking: Bool) {
        selectedTool = document.tool
        self.picking = picking
        undoButton.isEnabled = document.canUndo
        redoButton.isEnabled = document.canRedo
        pickerButton.state = picking ? .on : .off
        backdropButton.segmentActive = document.backdrop == .solid
        presetsButton.segmentActive = document.backdrop == .solid
        backdropButton.image = BackdropSwatch.image(preset: document.backdrop == .solid ? document.backdropPreset : nil)
        backdropButton.toolTip = document.backdrop == .solid
            ? "Backdrop: \(document.backdropPreset.name) (K)" : "Add a backdrop (K)"
        backdropButton.setAccessibilityValue(document.backdrop == .solid ? document.backdropPreset.name : "Off")
        arrange(in: availableWidth)
    }

    @discardableResult
    func arrange(in width: CGFloat) -> CGSize {
        availableWidth = width
        let room = width - EditorStyle.inset * 2
        let showLabel = Self.requiredWidth(toolCount: 4, showsLabel: true) <= room
        let compact = Self.requiredWidth(toolCount: 4, showsLabel: false) > room
        visibleTools = compact ? [.arrow, .number] : ToolChoice.all.map(\.tool)
        if compact && !visibleTools.contains(selectedTool) { visibleTools[1] = selectedTool }
        var x = EditorStyle.controlPadding
        for (index, choice) in ToolChoice.all.enumerated() {
            let button = toolButtons[index]
            button.isHidden = !visibleTools.contains(choice.tool)
            button.state = !picking && choice.tool == selectedTool ? .on : .off
        }
        for tool in visibleTools {
            guard let index = ToolChoice.all.firstIndex(where: { $0.tool == tool }) else { continue }
            place(toolButtons[index], at: &x)
        }
        moreButton.isHidden = !compact
        if compact { place(moreButton, at: &x) }
        placeSeparator(separators[0], at: &x)
        place(undoButton, at: &x)
        place(redoButton, at: &x)
        placeSeparator(separators[1], at: &x)
        backdropButton.title = showLabel ? "Backdrop" : ""
        backdropButton.imagePosition = showLabel ? .imageLeading : .imageOnly
        place(backdropButton, at: &x, width: showLabel ? EditorButton.backdropWidth : 30)
        x -= EditorStyle.controlGap
        place(presetsButton, at: &x, width: 24)
        place(pickerButton, at: &x)
        let size = CGSize(width: x - EditorStyle.controlGap + EditorStyle.controlPadding, height: EditorStyle.barHeight)
        setFrameSize(size)
        return size
    }

    private static func requiredWidth(toolCount: Int, showsLabel: Bool) -> CGFloat {
        let buttonCount = CGFloat(toolCount + 5)
        let buttons = CGFloat(toolCount + 3) * EditorStyle.controlSize.width
            + (showsLabel ? EditorButton.backdropWidth : 30) + 24
        let separators = 2 * (EditorStyle.groupPadding * 2 + 1)
        let gaps = (buttonCount - 4) * EditorStyle.controlGap
        return EditorStyle.controlPadding * 2 + buttons + separators + gaps
    }

    private func place(_ view: NSView, at x: inout CGFloat, width: CGFloat = 34) {
        view.frame = CGRect(x: x, y: EditorStyle.controlPadding, width: width, height: EditorStyle.controlSize.height)
        x += width + EditorStyle.controlGap
    }

    private func placeSeparator(_ view: NSView, at x: inout CGFloat) {
        x += EditorStyle.groupPadding - EditorStyle.controlGap
        view.frame = CGRect(x: x, y: (EditorStyle.barHeight - 20) / 2, width: 1, height: 20)
        x += 1 + EditorStyle.groupPadding
    }

    private func showMoreTools() {
        let menu = NSMenu()
        for (index, choice) in ToolChoice.all.enumerated() where !visibleTools.contains(choice.tool) {
            let item = NSMenuItem(title: choice.label, action: #selector(selectOverflowTool(_:)), keyEquivalent: choice.key.lowercased())
            item.keyEquivalentModifierMask = []
            item.image = BundledIcon.image(choice.icon)
            item.target = self
            item.tag = index
            menu.addItem(item)
        }
        menu.popUp(positioning: nil, at: CGPoint(x: 0, y: moreButton.bounds.maxY + 6), in: moreButton)
    }

    @objc private func selectOverflowTool(_ sender: NSMenuItem) {
        onTool?(ToolChoice.all[sender.tag].tool)
    }
}
