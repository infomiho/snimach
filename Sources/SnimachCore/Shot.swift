import CoreGraphics

/// A captured bitmap plus the geometry needed to show it 1:1 on the right screen.
public struct Shot: Sendable {
    /// sRGB premultiplied BGRA. Invariant: pixel size == (frame.size * scale).rounded().
    public let image: CGImage
    /// Backing scale of the display the shot was taken on (1.0 or 2.0).
    public let scale: CGFloat
    /// Screen location in AppKit global points (y-up, origin at the main display's
    /// bottom-left), the space of `NSScreen.frame`.
    public let frame: CGRect
    /// True only for window shots that include the shadow (transparent margin).
    public let hasAlpha: Bool

    public init(image: CGImage, scale: CGFloat, frame: CGRect, hasAlpha: Bool) {
        self.image = image
        self.scale = scale
        self.frame = frame
        self.hasAlpha = hasAlpha
    }
}
