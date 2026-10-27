import CoreGraphics
import XCTest
@testable import SnimachCore

final class AnnotationEditingTests: XCTestCase {
    func testArrowheadWingCanBeSelectedAndFitsSelectionBounds() throws {
        var document = Document(shot: makeShot(pointSize: CGSize(width: 100, height: 100), scale: 2))
        document.apply(.pointerDown(CGPoint(x: 10, y: 50)))
        document.apply(.pointerUp(CGPoint(x: 80, y: 50)))
        document.apply(.toolSelected(.select))
        document.apply(.pointerDown(CGPoint(x: 63, y: 58)))
        document.apply(.pointerUp(CGPoint(x: 63, y: 58)))
        XCTAssertEqual(document.selectedIndex, 0)
        let bounds = try XCTUnwrap(document.selectionBounds)
        XCTAssertTrue(bounds.contains(CGPoint(x: 63, y: 58)))
    }

    func testDeletingBadgeRenumbersRemainingBadgesAndCanBeUndone() {
        var document = Document(shot: makeShot(pointSize: CGSize(width: 100, height: 100), scale: 2))
        document.apply(.toolSelected(.number))
        document.apply(.pointerUp(CGPoint(x: 20, y: 20)))
        document.apply(.pointerUp(CGPoint(x: 70, y: 70)))
        document.apply(.toolSelected(.select))
        document.apply(.pointerDown(CGPoint(x: 20, y: 20)))
        document.apply(.pointerUp(CGPoint(x: 20, y: 20)))
        document.apply(.deleteSelection)
        XCTAssertEqual(document.annotations, [.number(1, center: CGPoint(x: 70, y: 70))])
        document.apply(.undo)
        XCTAssertEqual(document.annotations.count, 2)
        document.apply(.redo)
        XCTAssertEqual(document.annotations, [.number(1, center: CGPoint(x: 70, y: 70))])
    }

    func testMovingMarkCommitsOneUndoStep() {
        var document = Document(shot: makeShot(pointSize: CGSize(width: 100, height: 100), scale: 2))
        document.apply(.toolSelected(.number))
        document.apply(.pointerUp(CGPoint(x: 20, y: 20)))
        document.apply(.toolSelected(.select))
        document.apply(.pointerDown(CGPoint(x: 20, y: 20)))
        document.apply(.pointerDragged(CGPoint(x: 25, y: 28)))
        document.apply(.pointerDragged(CGPoint(x: 30, y: 35)))
        document.apply(.pointerUp(CGPoint(x: 30, y: 35)))
        XCTAssertEqual(document.annotations, [.number(1, center: CGPoint(x: 30, y: 35))])
        document.apply(.undo)
        XCTAssertEqual(document.annotations, [.number(1, center: CGPoint(x: 20, y: 20))])
        document.apply(.redo)
        XCTAssertEqual(document.annotations, [.number(1, center: CGPoint(x: 30, y: 35))])
    }

    func testSelectsTopmostMarkWithoutAddingHistory() {
        var document = Document(shot: makeShot(pointSize: CGSize(width: 100, height: 100), scale: 2))
        document.apply(.toolSelected(.number))
        document.apply(.pointerUp(CGPoint(x: 20, y: 20)))
        document.apply(.pointerUp(CGPoint(x: 22, y: 20)))
        document.apply(.toolSelected(.select))
        document.apply(.pointerDown(CGPoint(x: 20, y: 20)))
        document.apply(.pointerUp(CGPoint(x: 20, y: 20)))
        XCTAssertEqual(document.selectedIndex, 1)
        document.apply(.undo)
        XCTAssertEqual(document.annotations.count, 1)
        XCTAssertNil(document.selectedIndex)
    }
}
