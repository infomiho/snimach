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

public enum TextBackground: String, CaseIterable, Sendable {
    case none, solid

    public var name: String { rawValue.capitalized }
}

public struct TextAnnotation: Equatable {
    public var text: String
    public var origin: CGPoint
    public var size: TextSize
    public var color: AnnotationColor
    public var background: TextBackground
    public static let backgroundPadding = CGSize(width: 6, height: 3)
    public static let backgroundCornerRadius: CGFloat = 5

    public init(text: String, origin: CGPoint, size: TextSize = .medium, color: AnnotationColor = .orange, background: TextBackground = .none) {
        self.text = text
        self.origin = origin
        self.size = size
        self.color = color
        self.background = background
    }

    public var foregroundColor: CGColor {
        guard background == .solid else { return color.cgColor }
        let components = color.cgColor.components ?? [0, 0, 0, 1]
        func linear(_ component: CGFloat) -> CGFloat {
            component <= 0.04045 ? component / 12.92 : pow((component + 0.055) / 1.055, 2.4)
        }
        let luminance = 0.2126 * linear(components[0]) + 0.7152 * linear(components[1]) + 0.0722 * linear(components[2])
        return luminance > 0.179 ? CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1) : AnnotationColor.white.cgColor
    }

    var lines: [CTLine] {
        text.components(separatedBy: "\n").map { line in
            let attributes: [NSAttributedString.Key: Any] = [
                NSAttributedString.Key(kCTFontAttributeName as String): size.font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): foregroundColor,
            ]
            return CTLineCreateWithAttributedString(NSAttributedString(string: line, attributes: attributes))
        }
    }

    public var contentBounds: CGRect {
        let lines = lines
        let width = lines.map { CGFloat(CTLineGetTypographicBounds($0, nil, nil, nil)) }.max() ?? 0
        let height = CGFloat(lines.count) * size.lineHeight
        return CGRect(x: origin.x, y: origin.y - height, width: max(1, ceil(width)), height: height)
    }

    public var bounds: CGRect {
        guard background == .solid else { return contentBounds }
        return contentBounds.insetBy(dx: -Self.backgroundPadding.width, dy: -Self.backgroundPadding.height)
    }
}
