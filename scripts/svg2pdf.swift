import AppKit
import CoreGraphics

// Converts a 24x24 SVG into a vector PDF. Used once to vendor the Solar icons so the app does
// not depend on runtime SVG support.
//
//   swift scripts/svg2pdf.swift in.svg out.pdf

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    FileHandle.standardError.write(Data("usage: svg2pdf <in.svg> <out.pdf>\n".utf8))
    exit(2)
}
let source = arguments[1]
let destination = arguments[2]

guard let image = NSImage(contentsOfFile: source) else {
    FileHandle.standardError.write(Data("svg2pdf: cannot load \(source)\n".utf8))
    exit(1)
}
image.size = NSSize(width: 24, height: 24)
let rect = CGRect(x: 0, y: 0, width: 24, height: 24)

let data = NSMutableData()
guard let consumer = CGDataConsumer(data: data as CFMutableData) else {
    FileHandle.standardError.write(Data("svg2pdf: cannot create consumer\n".utf8))
    exit(1)
}
var mediaBox = rect
guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
    FileHandle.standardError.write(Data("svg2pdf: cannot create PDF context\n".utf8))
    exit(1)
}
context.beginPDFPage(nil)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
image.draw(in: rect)
NSGraphicsContext.restoreGraphicsState()
context.endPDFPage()
context.closePDF()

try data.write(to: URL(fileURLWithPath: destination))
