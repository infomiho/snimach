import CoreGraphics

public enum AnnotationColor: String, CaseIterable, Sendable {
    case orange, red, blue, green, black, white

    public var name: String { rawValue.capitalized }

    public var cgColor: CGColor {
        switch self {
        case .orange: return Brand.accent
        case .red: return CGColor(srgbRed: 0.9, green: 0.15, blue: 0.2, alpha: 1)
        case .blue: return CGColor(srgbRed: 0.15, green: 0.4, blue: 0.95, alpha: 1)
        case .green: return CGColor(srgbRed: 0.1, green: 0.6, blue: 0.3, alpha: 1)
        case .black: return CGColor(srgbRed: 0.08, green: 0.08, blue: 0.08, alpha: 1)
        case .white: return CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
        }
    }

    var labelColor: CGColor { self == .white ? AnnotationColor.black.cgColor : AnnotationColor.white.cgColor }
}
