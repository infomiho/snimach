import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import SnimachCore

// Renders an arrow and two badges onto a sample bitmap and writes it as PNG. This is the
// milestone-one probe: it exercises Document.apply, draw and render end to end, headless.

let outputPath = CommandLine.arguments.dropFirst().first ?? "sample.png"
let pointSize = CGSize(width: 400, height: 250)
let scale: CGFloat = 2

guard let base = makeBaseImage(pointSize: pointSize, scale: scale) else {
    FileHandle.standardError.write(Data("probe: could not build base image\n".utf8))
    exit(1)
}

let shot = Shot(
    image: base,
    scale: scale,
    frame: CGRect(origin: .zero, size: pointSize)
)

var document = Document(shot: shot)
document.apply(.pointerDown(CGPoint(x: 60, y: 70)))
document.apply(.pointerDragged(CGPoint(x: 210, y: 180)))
document.apply(.pointerUp(CGPoint(x: 210, y: 180)))
document.apply(.toolSelected(.number))
document.apply(.pointerUp(CGPoint(x: 300, y: 90)))
document.apply(.pointerUp(CGPoint(x: 120, y: 200)))

let image: CGImage
do {
    image = try document.render()
} catch {
    FileHandle.standardError.write(Data("probe: render failed: \(error)\n".utf8))
    exit(1)
}

let url = URL(fileURLWithPath: outputPath)
guard let destination = CGImageDestinationCreateWithURL(
    url as CFURL,
    UTType.png.identifier as CFString,
    1,
    nil
) else {
    FileHandle.standardError.write(Data("probe: could not open \(outputPath)\n".utf8))
    exit(1)
}
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else {
    FileHandle.standardError.write(Data("probe: could not write \(outputPath)\n".utf8))
    exit(1)
}

print("probe: wrote \(image.width)x\(image.height) to \(url.path)")

func makeBaseImage(pointSize: CGSize, scale: CGFloat) -> CGImage? {
    let width = Int((pointSize.width * scale).rounded())
    let height = Int((pointSize.height * scale).rounded())
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
    ) else { return nil }
    context.setFillColor(CGColor(srgbRed: 0.13, green: 0.15, blue: 0.19, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.setFillColor(CGColor(srgbRed: 0.25, green: 0.35, blue: 0.6, alpha: 1))
    context.fill(CGRect(x: 40 * scale, y: 40 * scale, width: 80 * scale, height: 60 * scale))
    return context.makeImage()
}
