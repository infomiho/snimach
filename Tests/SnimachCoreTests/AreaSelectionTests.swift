import CoreGraphics
import XCTest
@testable import SnimachCore

final class AreaSelectionTests: XCTestCase {
    /// A press at x 100, y 100 (AppKit points, y-up from the bottom of an 800-point main
    /// display) dragged to x 300, y 250 spans 200x150 points. Its top edge sits 250 points
    /// above the bottom, which is 550 points below the top: the CG rect is (100, 550, 200, 150).
    func testReleaseAfterADragEmitsTheRegionInBackendSpace() {
        var selection = AreaSelection(mainDisplayHeight: 800, pickableWindows: [])
        selection.press(at: CGPoint(x: 100, y: 100),
                        within: CGRect(x: 0, y: 0, width: 1000, height: 800),
                        shiftHeld: false)
        selection.drag(to: CGPoint(x: 300, y: 250))

        XCTAssertEqual(selection.release(), .region(CGRect(x: 100, y: 550, width: 200, height: 150)))
    }

    /// A drag one point wide and one tall is an accidental click, not a region.
    func testADragUnderTwoPointsOnEitherAxisEmitsNoSelection() {
        var selection = AreaSelection(mainDisplayHeight: 800, pickableWindows: [])
        selection.press(at: CGPoint(x: 100, y: 100),
                        within: CGRect(x: 0, y: 0, width: 1000, height: 800),
                        shiftHeld: false)
        selection.drag(to: CGPoint(x: 101, y: 101))

        XCTAssertNil(selection.release())
    }

    /// Exactly 2x2 is a region: the accept rule is inclusive on both axes.
    func testADragOfExactlyTwoPointsIsAccepted() {
        var selection = AreaSelection(mainDisplayHeight: 800, pickableWindows: [])
        selection.press(at: CGPoint(x: 100, y: 100),
                        within: CGRect(x: 0, y: 0, width: 1000, height: 800),
                        shiftHeld: false)
        selection.drag(to: CGPoint(x: 102, y: 102))

        // AppKit (100, 100, 2, 2); top edge 102 above the bottom, CG top at 800 - 102.
        XCTAssertEqual(selection.release(), .region(CGRect(x: 100, y: 698, width: 2, height: 2)))
    }

    /// 1x3 passes the 3-point show-the-band rule but still fails the 2-point accept rule, with
    /// no hovered window there is no fallback either.
    func testANarrowDragThatShowsTheBandIsStillNotARegion() {
        var selection = AreaSelection(mainDisplayHeight: 800, pickableWindows: [])
        selection.press(at: CGPoint(x: 100, y: 100),
                        within: CGRect(x: 0, y: 0, width: 1000, height: 800),
                        shiftHeld: false)
        selection.drag(to: CGPoint(x: 101, y: 103))

        XCTAssertTrue(selection.isDragging)
        XCTAssertNil(selection.release())
    }

    /// One pickable window, given in backend CG points at (100, 100) spanning 200x150 on an
    /// 800-point-tall main display. In AppKit points it covers y 550...700; a pointer at
    /// (150, 600) is inside it. A click with no drag selects it by its index.
    func testClickWithNoDragPicksTheHoveredWindow() {
        let window = CGRect(x: 100, y: 100, width: 200, height: 150)
        var selection = AreaSelection(mainDisplayHeight: 800, pickableWindows: [window])
        selection.pointerMoved(to: CGPoint(x: 150, y: 600))

        XCTAssertEqual(selection.release(), .window(0))
    }

    /// Moves after the press must not change the fallback: the pick froze at press time.
    func testPointerMovesMidDragDoNotChangeTheFallbackPick() {
        let window = CGRect(x: 100, y: 100, width: 200, height: 150)
        var selection = AreaSelection(mainDisplayHeight: 800, pickableWindows: [window])
        selection.pointerMoved(to: CGPoint(x: 150, y: 600))
        selection.press(at: CGPoint(x: 150, y: 600),
                        within: CGRect(x: 0, y: 0, width: 1000, height: 800),
                        shiftHeld: false)
        selection.pointerMoved(to: CGPoint(x: 900, y: 100))
        selection.drag(to: CGPoint(x: 151, y: 600))

        XCTAssertEqual(selection.release(), .window(0))
    }

    /// The too-small drag lands on the same window: releasing it falls back to the pick,
    /// matching a click.
    func testATinyDragOnAHoveredWindowPicksThatWindow() {
        let window = CGRect(x: 100, y: 100, width: 200, height: 150)
        var selection = AreaSelection(mainDisplayHeight: 800, pickableWindows: [window])
        selection.pointerMoved(to: CGPoint(x: 150, y: 600))
        selection.press(at: CGPoint(x: 150, y: 600),
                        within: CGRect(x: 0, y: 0, width: 1000, height: 800),
                        shiftHeld: false)
        selection.drag(to: CGPoint(x: 151, y: 600))

        XCTAssertEqual(selection.release(), .window(0))
    }

    /// Before the drag, the highlight is the hovered window. Past three points on either axis
    /// it hands off to the band, which is what reads as "this will be a region".
    func testTheHighlightHandsOffFromPickToBandOnceTheDragReadsAsARegion() {
        let window = CGRect(x: 100, y: 100, width: 200, height: 150)
        var selection = AreaSelection(mainDisplayHeight: 800, pickableWindows: [window])
        selection.pointerMoved(to: CGPoint(x: 150, y: 600))
        XCTAssertEqual(selection.highlight, CGRect(x: 100, y: 550, width: 200, height: 150))
        XCTAssertTrue(selection.isPickHighlight)
        XCTAssertFalse(selection.isDragging)

        selection.press(at: CGPoint(x: 150, y: 600),
                        within: CGRect(x: 0, y: 0, width: 1000, height: 800),
                        shiftHeld: false)
        selection.drag(to: CGPoint(x: 153, y: 601))
        XCTAssertTrue(selection.isDragging)
        XCTAssertFalse(selection.isPickHighlight)
        XCTAssertEqual(selection.highlight, CGRect(x: 150, y: 600, width: 3, height: 1))
    }

    /// Two points is still a click: the band has not taken over the highlight yet.
    func testAShortDragKeepsThePickHighlight() {
        let window = CGRect(x: 100, y: 100, width: 200, height: 150)
        var selection = AreaSelection(mainDisplayHeight: 800, pickableWindows: [window])
        selection.pointerMoved(to: CGPoint(x: 150, y: 600))
        selection.press(at: CGPoint(x: 150, y: 600),
                        within: CGRect(x: 0, y: 0, width: 1000, height: 800),
                        shiftHeld: false)
        selection.drag(to: CGPoint(x: 152, y: 600))

        XCTAssertFalse(selection.isDragging)
        XCTAssertTrue(selection.isPickHighlight)
        XCTAssertEqual(selection.highlight, CGRect(x: 100, y: 550, width: 200, height: 150))
    }

    /// Shift keeps the band a square on the longer side of the drag, live: it reshapes at
    /// once, whether it was held at press or toggled mid-drag.
    func testShiftSquaresTheRegionOnTheLongerSideOfTheDrag() {
        var selection = AreaSelection(mainDisplayHeight: 800, pickableWindows: [])
        selection.press(at: CGPoint(x: 100, y: 100),
                        within: CGRect(x: 0, y: 0, width: 1000, height: 800),
                        shiftHeld: false)
        selection.drag(to: CGPoint(x: 180, y: 140))
        selection.setShiftHeld(true)
        // Longer side 80: tip squares up to (180, 180). AppKit rect (100, 100, 80, 80) has its
        // top 180 above the bottom, so in CG points it starts 620 below the top.
        XCTAssertEqual(selection.release(), .region(CGRect(x: 100, y: 620, width: 80, height: 80)))
    }

    /// Shift held already at press squares from the first drag, the common real-world path.
    func testShiftHeldAtPressSquaresTheRegion() {
        var selection = AreaSelection(mainDisplayHeight: 800, pickableWindows: [])
        selection.press(at: CGPoint(x: 100, y: 100),
                        within: CGRect(x: 0, y: 0, width: 1000, height: 800),
                        shiftHeld: true)
        selection.drag(to: CGPoint(x: 180, y: 140))

        XCTAssertEqual(selection.release(), .region(CGRect(x: 100, y: 620, width: 80, height: 80)))
    }

    /// Space turns a continuing drag into a slide: the region keeps its size and moves.
    func testSpaceSlidesTheWholeRegionInsteadOfResizingIt() {
        var selection = AreaSelection(mainDisplayHeight: 800, pickableWindows: [])
        selection.press(at: CGPoint(x: 100, y: 100),
                        within: CGRect(x: 0, y: 0, width: 1000, height: 800),
                        shiftHeld: false)
        selection.drag(to: CGPoint(x: 200, y: 180))
        selection.setSpaceHeld(true)
        selection.drag(to: CGPoint(x: 150, y: 140))
        // The 100x80 region slid by (-50, -40): AppKit (50, 60, 100, 80), CG top at 800 - 140.
        XCTAssertEqual(selection.release(), .region(CGRect(x: 50, y: 660, width: 100, height: 80)))
    }

    /// Releasing Space resumes resizing from the moved anchor.
    func testReleasingSpaceResumesResizingFromTheMovedAnchor() {
        var selection = AreaSelection(mainDisplayHeight: 800, pickableWindows: [])
        selection.press(at: CGPoint(x: 100, y: 100),
                        within: CGRect(x: 0, y: 0, width: 1000, height: 800),
                        shiftHeld: false)
        selection.drag(to: CGPoint(x: 200, y: 180))
        selection.setSpaceHeld(true)
        selection.drag(to: CGPoint(x: 150, y: 140))
        selection.setSpaceHeld(false)
        selection.drag(to: CGPoint(x: 170, y: 160))

        // Slid to AppKit (50, 60, 100, 80), then resized from (50, 60) to (170, 160):
        // AppKit (50, 60, 120, 100), CG top at 800 - 160.
        XCTAssertEqual(selection.release(), .region(CGRect(x: 50, y: 640, width: 120, height: 100)))
    }

    /// Leaving the app mid-drag cancels; before any drag it must not, because the app
    /// activation that shows the overlay itself fires the notification.
    func testADragIsUnderwayOnlyOnceThePointerIsPressed() {
        var selection = AreaSelection(mainDisplayHeight: 800, pickableWindows: [])
        selection.pointerMoved(to: CGPoint(x: 500, y: 400))
        XCTAssertFalse(selection.hasDragUnderway)

        selection.press(at: CGPoint(x: 100, y: 100),
                        within: CGRect(x: 0, y: 0, width: 1000, height: 800),
                        shiftHeld: false)
        XCTAssertTrue(selection.hasDragUnderway)
    }

    /// The band stops at the edge of the display it started on, even when the pointer runs on.
    func testADragPastTheDisplayEdgeEndsAtThatEdge() {
        var selection = AreaSelection(mainDisplayHeight: 800, pickableWindows: [])
        selection.press(at: CGPoint(x: 990, y: 400),
                        within: CGRect(x: 0, y: 0, width: 1000, height: 800),
                        shiftHeld: false)
        selection.drag(to: CGPoint(x: 1500, y: 700))
        // Clamped tip (1000, 700): AppKit (990, 400, 10, 300), CG top at 800 - 700.
        XCTAssertEqual(selection.release(), .region(CGRect(x: 990, y: 100, width: 10, height: 300)))
    }
}
