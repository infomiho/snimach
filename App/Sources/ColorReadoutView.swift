import AppKit

final class ColorReadoutView: EditorSurface {
    static let size = CGSize(width: 252, height: 54)
    private let swatch = NSView()
    private let hexField = NSTextField(labelWithString: "")
    private let hint = NSTextField(labelWithString: "Click to select · ⌘C to copy")
    private var restingHint = "Click to select · ⌘C to copy"
    let copyButton = EditorButton(icon: "copy-linear", label: "Copy color", shortcut: "⌘C")
    var onCopy: (() -> Void)?
    private var flashTask: Task<Void, Never>?
    var displayedText: String { hexField.stringValue }
    var displayedHint: String { hint.stringValue }

    override init(frame frameRect: NSRect) {
        super.init(frame: CGRect(origin: frameRect.origin, size: Self.size))
        cornerRadius = 10
        swatch.frame = CGRect(x: 12, y: 16, width: 22, height: 22)
        swatch.wantsLayer = true
        swatch.layer?.cornerRadius = 6
        swatch.layer?.borderWidth = 1
        swatch.layer?.borderColor = NSColor.separatorColor.cgColor
        addSubview(swatch)
        hexField.frame = CGRect(x: 46, y: 29, width: 154, height: 17)
        hexField.font = .monospacedSystemFont(ofSize: 13, weight: .semibold)
        addSubview(hexField)
        hint.frame = CGRect(x: 46, y: 11, width: 154, height: 14)
        hint.font = .systemFont(ofSize: 10)
        hint.textColor = .secondaryLabelColor
        addSubview(hint)
        copyButton.frame = CGRect(x: 212, y: 12, width: 28, height: 30)
        copyButton.onPress = { [weak self] in self?.onCopy?() }
        addSubview(copyButton)
        setAccessibilityLabel("Sampled color")
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func update(hex: String, color: NSColor, selected: Bool = false) {
        flashTask?.cancel()
        restingHint = selected ? "Selected · ⌘C to copy" : "Click to select · ⌘C to copy"
        hint.stringValue = restingHint
        hexField.stringValue = hex
        swatch.layer?.backgroundColor = color.cgColor
        copyButton.setAccessibilityLabel("Copy \(hex)")
        setAccessibilityValue("\(selected ? "Selected" : "Preview") \(hex)")
        toolTip = "Click a pixel to select its color. Click another to replace it. Esc exits color inspection."
    }

    func flash(_ message: String) {
        hint.stringValue = message
        flashTask?.cancel()
        flashTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            guard let self else { return }
            self.hint.stringValue = self.restingHint
        }
        NSAccessibility.post(element: self, notification: .announcementRequested,
                             userInfo: [.announcement: message, .priority: NSAccessibilityPriorityLevel.medium.rawValue])
    }
}
