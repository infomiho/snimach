import CoreGraphics
import XCTest
@testable import SnimachCore

final class RubberBandTests: XCTestCase {
    private let display = CGRect(x: 0, y: 0, width: 1000, height: 800)

    func testDragDefinesTheRectAndStopsAtTheDisplayEdge() {
        var band = RubberBand(origin: CGPoint(x: 100, y: 100), bounds: display)

        band.drag(to: CGPoint(x: 300, y: 250))
        XCTAssertEqual(band.rect, CGRect(x: 100, y: 100, width: 200, height: 150))

        band.drag(to: CGPoint(x: 1200, y: -50))
        XCTAssertEqual(band.rect, CGRect(x: 100, y: 0, width: 900, height: 100))
    }

    func testSquareBandFollowsTheLongerSideAndStaysOnTheDisplay() {
        var band = RubberBand(origin: CGPoint(x: 100, y: 100), bounds: display)
        band.isSquare = true

        band.drag(to: CGPoint(x: 300, y: 150))
        XCTAssertEqual(band.rect, CGRect(x: 100, y: 100, width: 200, height: 200))

        band.drag(to: CGPoint(x: 50, y: 400))
        XCTAssertEqual(band.rect, CGRect(x: 0, y: 100, width: 100, height: 100),
                       "only 100 pt of room to the left: the square shrinks to what fits")
    }

    func testShiftMidDragReshapesAtOnceAndReleasingRestoresTheDrag() {
        var band = RubberBand(origin: CGPoint(x: 100, y: 100), bounds: display)
        band.drag(to: CGPoint(x: 300, y: 150))

        band.isSquare = true
        XCTAssertEqual(band.rect, CGRect(x: 100, y: 100, width: 200, height: 200))

        band.isSquare = false
        XCTAssertEqual(band.rect, CGRect(x: 100, y: 100, width: 200, height: 50))
    }

    func testOriginOutsideTheDisplayStartsOnItsEdge() {
        var band = RubberBand(origin: CGPoint(x: 500, y: 805), bounds: display)
        XCTAssertEqual(band.rect, CGRect(x: 500, y: 800, width: 0, height: 0))

        band.drag(to: CGPoint(x: 600, y: 700))
        XCTAssertEqual(band.rect, CGRect(x: 500, y: 700, width: 100, height: 100))
    }

    func testSpaceMovesTheBandWithinTheDisplayAndResizingResumesFromTheMovedAnchor() {
        var band = RubberBand(origin: CGPoint(x: 100, y: 100), bounds: display)
        band.drag(to: CGPoint(x: 300, y: 250))

        band.isMoving = true
        band.drag(to: CGPoint(x: 350, y: 270))
        XCTAssertEqual(band.rect, CGRect(x: 150, y: 120, width: 200, height: 150))

        band.drag(to: CGPoint(x: 2000, y: 270))
        XCTAssertEqual(band.rect, CGRect(x: 800, y: 120, width: 200, height: 150),
                       "the band slides until it touches the edge, it never leaves the display")

        band.isMoving = false
        band.drag(to: CGPoint(x: 900, y: 300))
        XCTAssertEqual(band.rect, CGRect(x: 800, y: 120, width: 100, height: 180))
    }
}
