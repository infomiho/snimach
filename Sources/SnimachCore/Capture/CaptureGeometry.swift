import CoreGraphics

/// Pure geometry shared by the capture paths. Both SCK and `CGWindowListCopyWindowInfo` work in
/// points, y-down from the main display's top-left. AppKit is y-up from the main display's
/// bottom-left, so one conversion ties the two together.
enum CaptureGeometry {
    static func displayContaining(_ point: CGPoint, in displays: [DisplayInfo]) -> DisplayInfo? {
        displays.first { $0.frame.contains(point) }
    }

    /// The index of the first window in front-to-back order that covers the point.
    static func frontmostWindow(containing point: CGPoint, in windows: [CGRect]) -> Int? {
        windows.firstIndex { $0.contains(point) }
    }

    static func displayHoldingMost(of rect: CGRect, in displays: [DisplayInfo]) -> DisplayInfo? {
        displays.max { lhs, rhs in
            overlap(lhs.frame, rect) < overlap(rhs.frame, rect)
        }
    }

    static func expanded(_ rect: CGRect, by margin: CGFloat, clampedTo bounds: CGRect) -> CGRect {
        rect.insetBy(dx: -margin, dy: -margin).intersection(bounds)
    }

    static func mainDisplayHeight(in displays: [DisplayInfo]) -> CGFloat {
        let main = displays.first { $0.frame.origin == .zero } ?? displays.first
        return main?.frame.height ?? 0
    }

    /// CG (y-down) to AppKit (y-up). Its own inverse.
    static func appKitFrame(_ rect: CGRect, mainDisplayHeight: CGFloat) -> CGRect {
        CGRect(
            x: rect.origin.x,
            y: mainDisplayHeight - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    /// Display-local points to whole image pixels, kept inside the image. Both spaces are y-down
    /// from the top-left, so only the scale changes.
    static func pixelRect(_ rect: CGRect, scale: CGFloat, in image: CGImage) -> CGRect {
        let scaled = CGRect(
            x: (rect.minX * scale).rounded(),
            y: (rect.minY * scale).rounded(),
            width: (rect.width * scale).rounded(),
            height: (rect.height * scale).rounded()
        )
        return scaled.intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))
    }

    /// Tightest rect containing pixels with alpha above `threshold`, in image pixel coordinates
    /// with the origin at the top-left (the same orientation as CG window bounds).
    static func opaqueBoundingBox(of image: CGImage, alphaThreshold: UInt8 = 1) -> CGRect? {
        let width = image.width
        let height = image.height
        let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue
            | CGBitmapInfo.byteOrder32Little.rawValue
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let base = context.data else { return nil }
        let data = base.bindMemory(to: UInt8.self, capacity: context.bytesPerRow * height)

        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1
        for y in 0..<height {
            for x in 0..<width {
                let alpha = data[y * context.bytesPerRow + x * 4 + 3]
                if alpha > alphaThreshold {
                    if x < minX { minX = x }
                    if x > maxX { maxX = x }
                    if y < minY { minY = y }
                    if y > maxY { maxY = y }
                }
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    private static func overlap(_ lhs: CGRect, _ rhs: CGRect) -> CGFloat {
        let intersection = lhs.intersection(rhs)
        guard !intersection.isNull else { return 0 }
        return intersection.width * intersection.height
    }
}
