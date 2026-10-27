import AppKit
import SnimachCore

final class AnnotationStyleShelf: EditorSurface {
    let colorButtons: [EditorButton]
    let sizeButtons: [EditorButton]
    let backgroundButtons: [EditorButton]
    var onColor: ((AnnotationColor) -> Void)?
    var onSize: ((TextSize) -> Void)?
    var onBackground: ((TextBackground) -> Void)?
    private var showsText = false

    override init(frame: NSRect) {
        colorButtons = AnnotationColor.allCases.map { StyleButton(label: $0.name) }
        sizeButtons = TextSize.allCases.map { StyleButton(label: "\($0.name) text") }
        backgroundButtons = TextBackground.allCases.map { StyleButton(label: $0 == .none ? "No text background" : "Solid text background") }
        super.init(frame: frame)
        cornerRadius = 16
        setAccessibilityLabel("Annotation style")
        for (index, button) in colorButtons.enumerated() {
            let color = AnnotationColor.allCases[index]
            button.image = Self.swatch(color)
            button.onPress = { [weak self] in self?.onColor?(color) }
            addSubview(button)
        }
        for (index, button) in sizeButtons.enumerated() {
            let size = TextSize.allCases[index]
            button.title = ["S", "M", "L"][index]
            button.imagePosition = .noImage
            button.onPress = { [weak self] in self?.onSize?(size) }
            addSubview(button)
        }
        for (index, button) in backgroundButtons.enumerated() {
            let background = TextBackground.allCases[index]
            button.onPress = { [weak self] in self?.onBackground?(background) }
            addSubview(button)
        }
        isHidden = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func update(document: Document) {
        showsText = document.activeTextSize != nil
        for (index, button) in colorButtons.enumerated() {
            button.state = document.activeColor == AnnotationColor.allCases[index] ? .on : .off
        }
        for (index, button) in sizeButtons.enumerated() {
            button.isHidden = !showsText
            button.state = document.activeTextSize == TextSize.allCases[index] ? .on : .off
        }
        let color = document.activeColor ?? document.drawingColor
        for (index, button) in backgroundButtons.enumerated() {
            let background = TextBackground.allCases[index]
            button.isHidden = !showsText
            button.state = document.activeTextBackground == background ? .on : .off
            button.image = Self.preview(color, solid: background == .solid)
        }
    }

    @discardableResult
    func arrange(in width: CGFloat) -> CGSize {
        let padding: CGFloat = 12
        let rowPadding: CGFloat = 8
        let rowHeight = EditorStyle.controlSize.height
        let groupGap: CGFloat = 16
        let colorsWidth = CGFloat(colorButtons.count) * 30
        let sizesWidth = CGFloat(sizeButtons.count) * 30
        let backgroundsWidth = CGFloat(backgroundButtons.count) * 42
        let textWidth = sizesWidth + groupGap + backgroundsWidth
        let rowWidth = padding * 2 + colorsWidth + groupGap + textWidth
        let wraps = showsText && rowWidth > width - EditorStyle.inset * 2
        let shelfWidth = showsText ? (wraps ? padding * 2 + textWidth : rowWidth) : padding * 2 + colorsWidth
        let height = rowPadding * 2 + rowHeight * (wraps ? 2 : 1) + (wraps ? rowPadding : 0)
        let colorsX = wraps ? (shelfWidth - colorsWidth) / 2 : padding
        for (index, button) in colorButtons.enumerated() {
            button.frame = CGRect(x: colorsX + CGFloat(index) * 30,
                                  y: wraps ? rowPadding * 2 + rowHeight : rowPadding, width: 30, height: rowHeight)
        }
        let sizesX = wraps ? padding : padding + colorsWidth + groupGap
        for (index, button) in sizeButtons.enumerated() {
            button.frame = CGRect(x: sizesX + CGFloat(index) * 30, y: rowPadding, width: 30, height: rowHeight)
        }
        let backgroundsX = sizesX + sizesWidth + groupGap
        for (index, button) in backgroundButtons.enumerated() {
            button.frame = CGRect(x: backgroundsX + CGFloat(index) * 42, y: rowPadding, width: 42, height: rowHeight)
        }
        setFrameSize(CGSize(width: shelfWidth, height: height))
        return frame.size
    }

    private static func swatch(_ color: AnnotationColor) -> NSImage {
        NSImage(size: CGSize(width: 18, height: 18), flipped: false) { rect in
            NSColor(cgColor: color.cgColor)?.setFill()
            let circle = NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1))
            circle.fill()
            NSColor.separatorColor.setStroke()
            circle.lineWidth = 1
            circle.stroke()
            return true
        }
    }

    private static func preview(_ color: AnnotationColor, solid: Bool) -> NSImage {
        NSImage(size: CGSize(width: 34, height: 22), flipped: false) { rect in
            let foreground: NSColor
            if solid {
                NSColor(cgColor: color.cgColor)?.setFill()
                NSBezierPath(roundedRect: rect, xRadius: 5, yRadius: 5).fill()
                foreground = NSColor(cgColor: TextAnnotation(text: "Aa", origin: .zero, color: color, background: .solid).foregroundColor) ?? .white
            } else {
                let neutral: NSColor = color == .white ? .darkGray : .lightGray
                neutral.setFill()
                NSBezierPath(roundedRect: rect, xRadius: 5, yRadius: 5).fill()
                foreground = NSColor(cgColor: color.cgColor) ?? .labelColor
            }
            let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.boldSystemFont(ofSize: 12), .foregroundColor: foreground]
            let size = ("Aa" as NSString).size(withAttributes: attributes)
            ("Aa" as NSString).draw(at: CGPoint(x: (rect.width - size.width) / 2, y: (rect.height - size.height) / 2), withAttributes: attributes)
            return true
        }
    }
}

private final class StyleButton: EditorButton {
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if state == .on {
            NSColor.labelColor.setStroke()
            let outline = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 6, yRadius: 6)
            outline.lineWidth = 1.5
            outline.stroke()
        }
    }

    override func mouseDown(with event: NSEvent) {
        let textEditor = window?.firstResponder as? AnnotationTextView
        super.mouseDown(with: event)
        if let textEditor { window?.makeFirstResponder(textEditor) }
    }
}
