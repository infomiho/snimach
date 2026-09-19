import CoreGraphics

/// A captured bitmap plus the geometry needed to show it 1:1 on the right screen.
///
/// Pixels are sRGB premultiplied BGRA. Invariant: pixel size == (frame.size × scale).rounded().
/// A debug build checks it at construction, so document points and image pixels cannot drift
/// apart without the cause pointing at itself.
public struct Shot: Sendable {
    public let image: CGImage
    /// Backing scale of the display the shot was taken on (1.0 or 2.0).
    public let scale: CGFloat
    /// Screen location in AppKit global points (y-up, origin at the main display's
    /// bottom-left), the space of `NSScreen.frame`. Its size is the document's point grid.
    public let frame: CGRect

    public init(image: CGImage, scale: CGFloat, frame: CGRect) {
        assert(
            scale > 0
                && image.width == Int((frame.width * scale).rounded())
                && image.height == Int((frame.height * scale).rounded()),
            "Shot pixels must cover its frame at its scale"
        )
        self.image = image
        self.scale = scale
        self.frame = frame
    }

    /// The pixel whose center is nearest to a document point (y-up from the shot's bottom
    /// left). The result is not clamped to the image.
    func pixel(for point: CGPoint) -> (x: Int, y: Int) {
        (
            Int((point.x * scale).rounded()),
            Int(((frame.height - point.y) * scale).rounded())
        )
    }

    /// The image pixels covering a rect given in document points. The document grid is y-up,
    /// the bitmap y-down, so this is the one place that flip happens for the document paths.
    /// Integral so a crop never samples between pixels.
    func pixelRect(for rect: CGRect) -> CGRect {
        CGRect(
            x: rect.minX * scale,
            y: (frame.height - rect.maxY) * scale,
            width: rect.width * scale,
            height: rect.height * scale
        ).integral
    }
}
