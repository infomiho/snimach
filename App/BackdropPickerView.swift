import AppKit
import SnimachCore

enum BackdropSwatch {
    static func image(preset: BackdropPreset?, size: CGFloat = 18, selected: Bool = false) -> NSImage {
        NSImage(size: CGSize(width: size, height: size), flipped: false) { rect in
            let radius: CGFloat = size <= 18 ? size / 2 : 8
            let inset: CGFloat = size <= 18 ? 0.5 : 3
            let path = NSBezierPath(roundedRect: rect.insetBy(dx: inset, dy: inset), xRadius: radius, yRadius: radius)
            guard let preset else {
                NSColor.secondaryLabelColor.setStroke()
                path.lineWidth = 1
                path.setLineDash([2, 2], count: 2, phase: 0)
                path.stroke()
                return true
            }
            let gradient = NSGradient(
                colors: preset.stops.map { NSColor(cgColor: $0.color)! },
                atLocations: preset.stops.map(\.location), colorSpace: .sRGB
            )
            NSGraphicsContext.saveGraphicsState()
            path.addClip()
            gradient?.draw(from: CGPoint(x: 0, y: size), to: CGPoint(x: size, y: 0), options: [])
            NSGraphicsContext.restoreGraphicsState()
            NSColor.separatorColor.setStroke()
            path.lineWidth = 1
            path.stroke()
            if selected {
                EditorStyle.accent.setStroke()
                let ring = NSBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), xRadius: radius + 2, yRadius: radius + 2)
                ring.lineWidth = 2
                ring.stroke()
                let mark = NSAttributedString(string: "✓", attributes: [
                    .font: NSFont.systemFont(ofSize: 17, weight: .semibold),
                    .foregroundColor: NSColor.white,
                    .strokeColor: NSColor.black.withAlphaComponent(0.5),
                    .strokeWidth: -2,
                ])
                let markSize = mark.size()
                mark.draw(at: CGPoint(x: (size - markSize.width) / 2, y: (size - markSize.height) / 2))
            }
            return true
        }
    }
}

final class BackdropPickerView: NSView {
    override var acceptsFirstResponder: Bool { true }
    static let size = CGSize(width: 256, height: 258)
    let presets = BackdropPreset.ordered
    private(set) var buttons: [NSButton] = []
    private(set) var selection: BackdropPresetID?
    private let caption = NSTextField(labelWithString: "")
    var onSelect: ((BackdropPresetID) -> Void)?
    var onToggle: (() -> Void)?

    init() {
        super.init(frame: CGRect(origin: .zero, size: Self.size))
        setAccessibilityRole(.group)
        setAccessibilityLabel("Backdrop presets")
        let title = NSTextField(labelWithString: "Backdrop")
        title.font = .systemFont(ofSize: 12, weight: .semibold)
        title.frame = CGRect(x: 16, y: 225, width: 224, height: 17)
        addSubview(title)
        for (index, preset) in presets.enumerated() {
            let button = NSButton(image: BackdropSwatch.image(preset: preset, size: 50), target: self, action: #selector(selectPreset(_:)))
            button.frame = CGRect(x: 16 + (index % 4) * 58, y: 163 - (index / 4) * 58, width: 50, height: 50)
            button.tag = index
            button.isBordered = false
            button.imageScaling = .scaleNone
            button.toolTip = preset.name
            button.setAccessibilityLabel(preset.name)
            buttons.append(button)
            addSubview(button)
        }
        caption.font = .systemFont(ofSize: 12)
        caption.frame = CGRect(x: 16, y: 16, width: 140, height: 17)
        addSubview(caption)
        let hint = NSTextField(labelWithString: "K toggles")
        hint.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        hint.textColor = .secondaryLabelColor
        hint.alignment = .right
        hint.frame = CGRect(x: 165, y: 16, width: 75, height: 17)
        addSubview(hint)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func update(preset: BackdropPreset, active: Bool) {
        selection = active ? preset.id : nil
        caption.stringValue = active ? preset.name : "No backdrop"
        for (index, button) in buttons.enumerated() {
            let selected = presets[index].id == selection
            button.image = BackdropSwatch.image(preset: presets[index], size: 50, selected: selected)
            button.setAccessibilityValue(selected ? "Selected" : "")
        }
    }

    @objc private func selectPreset(_ sender: NSButton) { onSelect?(presets[sender.tag].id) }

    override func keyDown(with event: NSEvent) {
        if EditorKeymap.key(forKeyCode: event.keyCode, modifiers: event.modifierFlags) == .cycleBackdrop {
            onToggle?()
            return
        }
        let directions: [UInt16: Int] = [123: -1, 124: 1, 125: 4, 126: -4]
        guard let step = directions[event.keyCode] else {
            super.keyDown(with: event)
            return
        }
        guard let current = window?.firstResponder as? NSButton,
              let index = buttons.firstIndex(of: current) else {
            window?.makeFirstResponder(buttons.first)
            return
        }
        let next = min(max(0, index + step), buttons.count - 1)
        window?.makeFirstResponder(buttons[next])
    }
}
