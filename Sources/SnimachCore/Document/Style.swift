import CoreGraphics
import CoreText

/// The product has no styling, so every visual constant lives here. Tests read these
/// values through `@testable import` to build expected pixel colours.
enum Style {
    struct Standard {
        let strokeColor: CGColor
        let strokeWidth: CGFloat
        let badgeColor: CGColor
        let labelColor: CGColor
        let font: CTFont
        let badgeRadius: CGFloat
        let headLength: CGFloat
        let headHalfAngle: CGFloat
        let minimumArrowLength: CGFloat
        /// Smallest drag that commits a rect, for both the rectangle and the redaction.
        let minimumShapeSide: CGFloat
        /// Side of one redaction cell, in document points.
        let redactionCell: CGFloat
        /// Painted only when the shot cannot be sampled, so a redaction is never see-through.
        let redactionFallback: CGColor
    }

    static let standard = Standard(
        strokeColor: Brand.accent,
        strokeWidth: 4,
        badgeColor: Brand.accent,
        labelColor: CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1),
        font: boldSystemFont(ofSize: 17),
        badgeRadius: 14,
        headLength: 18,
        headHalfAngle: .pi / 7,
        minimumArrowLength: 4,
        minimumShapeSide: 4,
        redactionCell: 8,
        redactionFallback: CGColor(srgbRed: 0.35, green: 0.35, blue: 0.35, alpha: 1)
    )

    struct Backdrop {
        /// Pad around the shot, in points. Matches the prototype stage.
        let padding: CGFloat
        /// Corner radius of the shot on the backdrop, in points.
        let radius: CGFloat
        let shadowBlur: CGFloat
        let shadowOffset: CGSize
        let shadowColor: CGColor
    }

    static let backdrop = Backdrop(
        padding: 48,
        radius: 16,
        shadowBlur: 24,
        shadowOffset: CGSize(width: 0, height: -12),
        shadowColor: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.45)
    )

    private static func boldSystemFont(ofSize size: CGFloat) -> CTFont {
        let base = CTFontCreateUIFontForLanguage(.system, size, nil)
            ?? CTFontCreateWithName("Helvetica" as CFString, size, nil)
        return CTFontCreateCopyWithSymbolicTraits(base, size, nil, .boldTrait, .boldTrait) ?? base
    }
}
