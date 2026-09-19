import AppKit

// Renders an SVG at a given pixel size. Used to build the app icon set.
//
//   swift scripts/svg2png.swift in.svg out.png 1024

let arguments = CommandLine.arguments
guard arguments.count == 4, let side = Int(arguments[3]) else {
    FileHandle.standardError.write(Data("usage: svg2png <in.svg> <out.png> <pixels>\n".utf8))
    exit(2)
}

guard let image = NSImage(contentsOfFile: arguments[1]) else {
    FileHandle.standardError.write(Data("svg2png: cannot load \(arguments[1])\n".utf8))
    exit(1)
}
image.size = NSSize(width: side, height: side)

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
) else {
    FileHandle.standardError.write(Data("svg2png: cannot create bitmap\n".utf8))
    exit(1)
}
rep.size = NSSize(width: side, height: side)

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSGraphicsContext.current?.imageInterpolation = .high
image.draw(in: NSRect(x: 0, y: 0, width: side, height: side))
NSGraphicsContext.restoreGraphicsState()

guard let data = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("svg2png: cannot encode png\n".utf8))
    exit(1)
}
try data.write(to: URL(fileURLWithPath: arguments[2]))
