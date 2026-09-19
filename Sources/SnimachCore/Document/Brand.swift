import CoreGraphics

/// Logo-derived design tokens. Source is `design/svg/appicon.svg`:
/// paper #EDEAE4, ink #1A1A1A, accent #E8502A, corner brackets with miter joins.
/// Components are shared so Core, AppKit and SwiftUI spell the same colors.
public enum Brand {
    public static let accentComponents: (red: CGFloat, green: CGFloat, blue: CGFloat) = (0.91, 0.31, 0.16)
    public static let inkComponents: (red: CGFloat, green: CGFloat, blue: CGFloat) = (0.10, 0.10, 0.10)
    public static let paperComponents: (red: CGFloat, green: CGFloat, blue: CGFloat) = (0.93, 0.92, 0.89)
    public static let lineComponents: (red: CGFloat, green: CGFloat, blue: CGFloat) = (0.89, 0.87, 0.85)
    public static let mutedComponents: (red: CGFloat, green: CGFloat, blue: CGFloat) = (0.44, 0.42, 0.39)

    public static var accent: CGColor {
        CGColor(
            srgbRed: accentComponents.red,
            green: accentComponents.green,
            blue: accentComponents.blue,
            alpha: 1
        )
    }

    public static var ink: CGColor {
        CGColor(
            srgbRed: inkComponents.red,
            green: inkComponents.green,
            blue: inkComponents.blue,
            alpha: 1
        )
    }

    /// Shared corner radius for cards: preview card, editor canvas, logo tile family.
    public static let cardRadius: CGFloat = 10
}
