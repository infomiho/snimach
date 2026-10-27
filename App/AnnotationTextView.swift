import AppKit
import SnimachCore

final class AnnotationTextView: NSTextView {
    var onFinish: (() -> Void)?
    var onCancel: (() -> Void)?
    private var backgroundRect: CGRect = .zero
    private var backingColor: NSColor?

    init() {
        let storage = NSTextStorage()
        let layout = NSLayoutManager()
        let container = NSTextContainer(size: CGSize(width: 10_000_000, height: 10_000_000))
        storage.addLayoutManager(layout)
        layout.addTextContainer(container)
        super.init(frame: .zero, textContainer: container)
        isRichText = false
        allowsUndo = true
        drawsBackground = false
        textContainerInset = .zero
        textContainer?.lineFragmentPadding = 0
        textContainer?.widthTracksTextView = false
        textContainer?.heightTracksTextView = false
        textContainer?.containerSize = CGSize(width: 10_000_000, height: 10_000_000)
        isHorizontallyResizable = false
        isVerticallyResizable = false
        setAccessibilityLabel("Annotation text")
        toolTip = "⌘Return to finish · Escape to cancel"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func update(_ draft: TextAnnotation, stageOrigin: CGPoint) {
        if string != draft.text { string = draft.text }
        if font?.pointSize != draft.size.pointSize {
            font = .systemFont(ofSize: draft.size.pointSize)
            let paragraph = NSMutableParagraphStyle()
            paragraph.minimumLineHeight = draft.size.lineHeight
            paragraph.maximumLineHeight = draft.size.lineHeight
            defaultParagraphStyle = paragraph
            if let textStorage, textStorage.length > 0 {
                textStorage.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: textStorage.length))
            }
        }
        textColor = NSColor(cgColor: draft.foregroundColor)
        let padding = draft.background == .solid ? TextAnnotation.backgroundPadding : .zero
        textContainerInset = padding
        backingColor = draft.background == .solid ? NSColor(cgColor: draft.color.cgColor) : nil
        backgroundRect = CGRect(origin: .zero, size: CGSize(width: draft.contentBounds.width + padding.width * 2,
                                                            height: draft.contentBounds.height + padding.height * 2))
        needsDisplay = true
        insertionPointColor = EditorStyle.accent
        let size = CGSize(width: max(100, draft.contentBounds.width + 8) + padding.width * 2,
                          height: draft.contentBounds.height + 4 + padding.height * 2)
        frame = CGRect(x: draft.origin.x + stageOrigin.x - padding.width, y: draft.origin.y + stageOrigin.y - size.height + padding.height,
                       width: size.width, height: size.height)
    }

    override func draw(_ dirtyRect: NSRect) {
        if let backingColor {
            backingColor.setFill()
            NSBezierPath(roundedRect: backgroundRect, xRadius: TextAnnotation.backgroundCornerRadius,
                         yRadius: TextAnnotation.backgroundCornerRadius).fill()
        }
        super.draw(dirtyRect)
    }

    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection([.command, .shift, .control, .option])
        if !hasMarkedText(), event.keyCode == 53, modifiers.isEmpty {
            onCancel?()
        } else if !hasMarkedText(), (event.keyCode == 36 || event.keyCode == 76), modifiers == .command {
            onFinish?()
        } else {
            super.keyDown(with: event)
        }
    }
}
