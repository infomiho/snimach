import CoreGraphics

/// Reads the base shot pixel under a document point. The editor color readout is display-only:
/// it shows what is in `shot.image`, never an annotation, and copies the hex on Tab.
public enum ColorProbe {
    /// Hex of the shot pixel under `point`, as `#RRGGBB`. Returns nil when the shot
    /// cannot be sampled. Points outside the shot clamp to the nearest edge.
    public static func hex(at point: CGPoint, in shot: Shot) -> String? {
        guard let pixel = rgb(at: point, in: shot) else { return nil }
        return String(format: "#%02X%02X%02X", pixel.r, pixel.g, pixel.b)
    }

    /// sRGB bytes of the shot pixel under `point`. Document points are y-up from the
    /// bottom left; `Shot.pixel(for:)` owns the flip to the y-down bitmap.
    public static func rgb(at point: CGPoint, in shot: Shot) -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8)? {
        guard shot.image.width > 0, shot.image.height > 0 else { return nil }
        let (x, y) = shot.pixel(for: point)
        let clampedX = min(max(x, 0), shot.image.width - 1)
        let clampedY = min(max(y, 0), shot.image.height - 1)
        guard let crop = shot.image.cropping(to: CGRect(x: clampedX, y: clampedY, width: 1, height: 1)) else {
            return nil
        }
        let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue
            | CGBitmapInfo.byteOrder32Little.rawValue
        guard let context = CGContext(
            data: nil,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }
        context.draw(crop, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        guard let data = context.data?.bindMemory(to: UInt8.self, capacity: 4) else { return nil }
        return (r: data[2], g: data[1], b: data[0], a: data[3])
    }
}
