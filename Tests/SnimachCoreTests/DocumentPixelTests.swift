import CoreGraphics
import XCTest
@testable import SnimachCore

final class DocumentPixelTests: XCTestCase {
    private let baseColor = CGColor(srgbRed: 0.5, green: 0.5, blue: 0.5, alpha: 1)

    private func makeDocument(pointSize: CGSize = CGSize(width: 60, height: 40), scale: CGFloat = 2) -> Document {
        Document(shot: makeShot(pointSize: pointSize, scale: scale, color: baseColor))
    }

    func testRenderOfEmptyDocumentMatchesBaseAndDimensions() throws {
        let document = makeDocument()
        let image = try document.render()

        XCTAssertEqual(image.width, document.shot.image.width)
        XCTAssertEqual(image.height, document.shot.image.height)

        let rendered = bitmap(image, scale: document.shot.scale)
        assertNear(rendered.pixel(at: CGPoint(x: 30, y: 20)), baseColor)
        assertNear(rendered.pixel(at: CGPoint(x: 2, y: 2)), baseColor)
    }

    func testArrowPaintsShaftAndLeavesCorner() {
        var document = makeDocument()
        document.apply(.pointerDown(CGPoint(x: 10, y: 10)))
        document.apply(.pointerDragged(CGPoint(x: 40, y: 10)))
        document.apply(.pointerUp(CGPoint(x: 40, y: 10)))

        let rendered = draw(document)
        assertNear(rendered.pixel(at: CGPoint(x: 16, y: 10)), Style.standard.strokeColor)
        assertNear(rendered.pixel(at: CGPoint(x: 2, y: 38)), baseColor)
    }

    func testBadgePaintsDiscAndLabel() {
        var document = makeDocument()
        document.apply(.toolSelected(.number))
        document.apply(.pointerUp(CGPoint(x: 30, y: 20)))

        let rendered = draw(document)
        assertNear(rendered.pixel(at: CGPoint(x: 20, y: 20)), Style.standard.badgeColor)

        let label = RGB(Style.standard.labelColor)
        var sawLabel = false
        for dx in -6...6 {
            for dy in -6...6 {
                let p = rendered.pixel(at: CGPoint(x: 30 + dx, y: 20 + dy))
                if abs(Int(p.r) - label.r) <= 30, abs(Int(p.g) - label.g) <= 30, abs(Int(p.b) - label.b) <= 30 {
                    sawLabel = true
                }
            }
        }
        XCTAssertTrue(sawLabel, "badge label should paint light pixels near the centre")
    }

    func testDragPreviewPaintsAndUndoCancels() {
        var document = makeDocument()
        document.apply(.pointerDown(CGPoint(x: 10, y: 10)))
        document.apply(.pointerDragged(CGPoint(x: 40, y: 30)))
        XCTAssertGreaterThan(draw(document).count(of: Style.standard.strokeColor), 0)

        document.apply(.undo)
        XCTAssertEqual(draw(document).count(of: Style.standard.strokeColor), 0)
    }

    func testStrokeIsTwiceAsManyPixelsAtScaleTwo() {
        var single = makeDocument(pointSize: CGSize(width: 60, height: 40), scale: 1)
        single.apply(.pointerDown(CGPoint(x: 10, y: 20)))
        single.apply(.pointerUp(CGPoint(x: 50, y: 20)))

        var double = makeDocument(pointSize: CGSize(width: 60, height: 40), scale: 2)
        double.apply(.pointerDown(CGPoint(x: 10, y: 20)))
        double.apply(.pointerUp(CGPoint(x: 50, y: 20)))

        let singleWidth = draw(single).countInColumn(x: 30, of: Style.standard.strokeColor)
        let doubleWidth = draw(double).countInColumn(x: 60, of: Style.standard.strokeColor)

        XCTAssertGreaterThan(singleWidth, 0)
        XCTAssertEqual(Double(doubleWidth) / Double(singleWidth), 2, accuracy: 0.4)
    }

    func testRedactionFlattensItsAreaAndLeavesTheRestAlone() throws {
        var document = Document(shot: makeCheckerShot(pointSize: CGSize(width: 40, height: 30), scale: 2))
        document.apply(.toolSelected(.redact))
        document.apply(.pointerDown(CGPoint(x: 8, y: 8)))
        document.apply(.pointerUp(CGPoint(x: 24, y: 24)))
        XCTAssertEqual(document.annotations.count, 1)

        let rendered = bitmap(try document.render(), scale: 2)

        // Inside: neighbouring points that differed in the shot now read the same, and the value
        // is an average rather than either original colour.
        let inside = rendered.pixel(at: CGPoint(x: 12, y: 12))
        XCTAssertEqual(inside, rendered.pixel(at: CGPoint(x: 13, y: 12)))
        XCTAssertGreaterThan(Int(inside.r), 40)
        XCTAssertLessThan(Int(inside.r), 215)

        // Outside: the checker is untouched.
        XCTAssertNotEqual(
            rendered.pixel(at: CGPoint(x: 2, y: 2)),
            rendered.pixel(at: CGPoint(x: 3, y: 2))
        )
        XCTAssertNotEqual(
            rendered.pixel(at: CGPoint(x: 30, y: 12)),
            rendered.pixel(at: CGPoint(x: 31, y: 12))
        )
    }

    func testRectanglePaintsItsEdgeAndLeavesTheMiddle() {
        var document = makeDocument()
        document.apply(.toolSelected(.rectangle))
        document.apply(.pointerDown(CGPoint(x: 10, y: 10)))
        document.apply(.pointerUp(CGPoint(x: 40, y: 30)))

        let rendered = draw(document)
        assertNear(rendered.pixel(at: CGPoint(x: 25, y: 10)), Style.standard.strokeColor)
        assertNear(rendered.pixel(at: CGPoint(x: 10, y: 20)), Style.standard.strokeColor)
        assertNear(rendered.pixel(at: CGPoint(x: 25, y: 20)), baseColor)
    }

    func testColorProbeReadsBasePixelAndFormatsHex() {
        let shot = makeShot(
            pointSize: CGSize(width: 4, height: 4),
            scale: 1,
            color: CGColor(srgbRed: 0.23, green: 0.48, blue: 0.84, alpha: 1)
        )
        XCTAssertEqual(ColorProbe.hex(at: CGPoint(x: 1, y: 1), in: shot), "#3B7AD6")
    }

    func testColorProbeClampsOutsidePoints() {
        let shot = makeShot(pointSize: CGSize(width: 4, height: 4), scale: 1, color: baseColor)
        XCTAssertNotNil(ColorProbe.hex(at: CGPoint(x: -10, y: 99), in: shot))
    }

    func testColorProbeMatchesAtScaleTwo() {
        let color = CGColor(srgbRed: 0.23, green: 0.48, blue: 0.84, alpha: 1)
        let shot = makeShot(pointSize: CGSize(width: 4, height: 4), scale: 2, color: color)
        XCTAssertEqual(ColorProbe.hex(at: CGPoint(x: 1, y: 1), in: shot), "#3B7AD6")
    }

    func testColorProbeSamplesTheNearestPixelCenter() {
        let shot = makeCheckerShot(pointSize: CGSize(width: 4, height: 4), scale: 1)
        // x 0.6 lies inside column 0, but column 1's center is nearer.
        XCTAssertEqual(ColorProbe.hex(at: CGPoint(x: 0.6, y: 0.7), in: shot), "#FFFFFF")
        // x 1.6 likewise falls on column 2's center.
        XCTAssertEqual(ColorProbe.hex(at: CGPoint(x: 1.6, y: 0.7), in: shot), "#000000")
    }

    func testRedactionCoversEveryPixelTheRectTouches() {
        // All white except a black band at document x 6...7, which the drag only grazes.
        let context = makeContext(width: 8, height: 8)
        context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 6, y: 0, width: 1, height: 8))
        let shot = Shot(
            image: context.makeImage()!,
            scale: 1,
            frame: CGRect(origin: .zero, size: CGSize(width: 8, height: 8))
        )

        var document = Document(shot: shot)
        document.apply(.toolSelected(.redact))
        document.apply(.pointerDown(CGPoint(x: 1.4, y: 1.4)))
        document.apply(.pointerUp(CGPoint(x: 6.6, y: 6.6)))

        let rendered = draw(document)
        let centre = rendered.pixel(at: CGPoint(x: 4, y: 4))
        XCTAssertLessThan(Int(centre.r), 250,
                          "the grazed black column must reach into the redacted sample")
        XCTAssertGreaterThan(Int(centre.r), 0)
        assertNear(rendered.pixel(at: CGPoint(x: 0.2, y: 4)),
                   CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
    }
}
