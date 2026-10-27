import AppKit
import SnimachCore
import XCTest
@testable import Snimach

@MainActor
final class CanvasRenderingTests: XCTestCase {
    func testBackdropRedrawsForAnnotationsPresetAndShot() throws {
        let controller = EditorWindowController(document: Document(shot: makeTestShot(frame: CGRect(x: 0, y: 0, width: 100, height: 80))))
        controller.show()
        defer { controller.close() }
        let canvas = controller.canvas
        canvas.apply(.backdropSelected(.solid))
        canvas.apply(.toolSelected(.line))
        canvas.apply(.pointerDown(CGPoint(x: 20, y: 20)))
        canvas.apply(.pointerUp(CGPoint(x: 80, y: 50)))
        let original = try image(canvas)
        controller.styleShelf.colorButtons[AnnotationColor.allCases.firstIndex(of: .blue)!].performClick(nil)
        let recolored = try image(canvas)
        XCTAssertNotEqual(recolored.tiffRepresentation, original.tiffRepresentation)
        canvas.apply(.undo)
        XCTAssertNotEqual(try image(canvas).tiffRepresentation, recolored.tiffRepresentation)
        let beforePreset = try XCTUnwrap(image(canvas).colorAt(x: 5, y: 5))
        canvas.apply(.backdropPresetSelected(BackdropPreset.preset(.arendelle)))
        let afterPreset = try XCTUnwrap(image(canvas).colorAt(x: 5, y: 5))
        XCTAssertNotEqual(beforePreset, afterPreset)

        let frame = CGRect(x: 0, y: 0, width: 100, height: 80)
        let context = try XCTUnwrap(CGContext(data: nil, width: 200, height: 160, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue))
        context.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 200, height: 160))
        let shot = Shot(image: try XCTUnwrap(context.makeImage()), scale: 2, frame: frame)
        var replacement = Document(shot: shot)
        replacement.apply(.backdropSelected(.solid))
        replacement.apply(.backdropPresetSelected(BackdropPreset.preset(.arendelle)))
        canvas.document = replacement
        let center = try XCTUnwrap(image(canvas).colorAt(x: 98, y: 88)?.usingColorSpace(.deviceRGB))
        XCTAssertEqual(center.redComponent, 1, accuracy: 0.02)
        XCTAssertEqual(center.greenComponent, 0, accuracy: 0.02)
        XCTAssertEqual(center.blueComponent, 0, accuracy: 0.02)
    }

    private func image(_ canvas: CanvasView) throws -> NSBitmapImageRep {
        let width = Int(canvas.bounds.width)
        let height = Int(canvas.bounds.height)
        let rep = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let graphics = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: rep))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphics
        canvas.draw(canvas.bounds)
        NSGraphicsContext.restoreGraphicsState()
        return rep
    }
}
