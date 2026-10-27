import CoreGraphics
import CoreText
import Foundation

public enum TextSize: Double, CaseIterable, Sendable {
    case small = 16
    case medium = 24
    case large = 32

    public var name: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }

    public var pointSize: CGFloat { CGFloat(rawValue) }
    public var lineHeight: CGFloat { ceil(CTFontGetAscent(font) + CTFontGetDescent(font) + CTFontGetLeading(font)) }

    var font: CTFont {
        CTFontCreateUIFontForLanguage(.system, pointSize, nil)
            ?? CTFontCreateWithName("Helvetica" as CFString, pointSize, nil)
    }
}

public struct TextAnnotation: Equatable {
    public var text: String
    public var origin: CGPoint
    public var size: TextSize
    public var color: AnnotationColor

    public init(text: String, origin: CGPoint, size: TextSize = .medium, color: AnnotationColor = .orange) {
        self.text = text
        self.origin = origin
        self.size = size
        self.color = color
    }

    var lines: [CTLine] {
        text.components(separatedBy: "\n").map { line in
            let attributes: [NSAttributedString.Key: Any] = [
                NSAttributedString.Key(kCTFontAttributeName as String): size.font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): color.cgColor,
            ]
            return CTLineCreateWithAttributedString(NSAttributedString(string: line, attributes: attributes))
        }
    }

    public var bounds: CGRect {
        let lines = lines
        let width = lines.map { CGFloat(CTLineGetTypographicBounds($0, nil, nil, nil)) }.max() ?? 0
        let height = CGFloat(lines.count) * size.lineHeight
        return CGRect(x: origin.x, y: origin.y - height, width: max(1, ceil(width)), height: height)
    }
}
