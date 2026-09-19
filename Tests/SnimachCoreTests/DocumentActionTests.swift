import CoreGraphics
import XCTest
@testable import SnimachCore

final class DocumentActionTests: XCTestCase {
    private func makeDocument() -> Document {
        Document(shot: makeShot(pointSize: CGSize(width: 40, height: 30), scale: 2))
    }

    func testDragCommitsArrow() {
        var document = makeDocument()
        document.apply(.pointerDown(CGPoint(x: 5, y: 5)))
        document.apply(.pointerDragged(CGPoint(x: 20, y: 18)))
        document.apply(.pointerUp(CGPoint(x: 20, y: 18)))

        XCTAssertEqual(document.annotations, [.arrow(from: CGPoint(x: 5, y: 5), to: CGPoint(x: 20, y: 18))])
        XCTAssertTrue(document.canUndo)
        XCTAssertFalse(document.canRedo)
    }

    func testShortDragCommitsNothing() {
        var document = makeDocument()
        document.apply(.pointerDown(CGPoint(x: 5, y: 5)))
        document.apply(.pointerUp(CGPoint(x: 7, y: 5)))

        XCTAssertTrue(document.annotations.isEmpty)
        XCTAssertFalse(document.canUndo)
    }

    func testShortDragCancelsPreview() {
        var document = makeDocument()
        document.apply(.pointerDown(CGPoint(x: 5, y: 5)))
        document.apply(.pointerUp(CGPoint(x: 6, y: 5)))
        XCTAssertTrue(draw(document).count(of: Style.standard.strokeColor) == 0)
    }

    func testBadgeNumberingContinuesAfterUndo() {
        var document = makeDocument()
        document.apply(.toolSelected(.number))
        document.apply(.pointerUp(CGPoint(x: 10, y: 10)))
        document.apply(.pointerUp(CGPoint(x: 20, y: 10)))
        document.apply(.pointerUp(CGPoint(x: 30, y: 10)))

        XCTAssertEqual(document.annotations, [
            .number(1, center: CGPoint(x: 10, y: 10)),
            .number(2, center: CGPoint(x: 20, y: 10)),
            .number(3, center: CGPoint(x: 30, y: 10)),
        ])

        document.apply(.undo)
        document.apply(.pointerUp(CGPoint(x: 25, y: 15)))

        XCTAssertEqual(document.annotations, [
            .number(1, center: CGPoint(x: 10, y: 10)),
            .number(2, center: CGPoint(x: 20, y: 10)),
            .number(3, center: CGPoint(x: 25, y: 15)),
        ])
    }

    func testUndoDuringDragCancelsItAndPopsPreviousCommit() {
        var document = makeDocument()
        document.apply(.pointerDown(CGPoint(x: 5, y: 5)))
        document.apply(.pointerUp(CGPoint(x: 25, y: 25)))
        document.apply(.pointerDown(CGPoint(x: 10, y: 10)))

        document.apply(.undo)

        XCTAssertTrue(document.annotations.isEmpty)
        XCTAssertFalse(document.canUndo)
        XCTAssertTrue(draw(document).count(of: Style.standard.strokeColor) == 0)
    }

    func testRedoAfterNewCommitIsNoOp() {
        var document = makeDocument()
        document.apply(.toolSelected(.number))
        document.apply(.pointerUp(CGPoint(x: 10, y: 10)))
        document.apply(.undo)
        document.apply(.pointerUp(CGPoint(x: 15, y: 15)))
        document.apply(.redo)

        XCTAssertEqual(document.annotations, [.number(1, center: CGPoint(x: 15, y: 15))])
        XCTAssertFalse(document.canRedo)
    }

    func testRedoRestoresUndoneCommit() {
        var document = makeDocument()
        document.apply(.toolSelected(.number))
        document.apply(.pointerUp(CGPoint(x: 10, y: 10)))
        document.apply(.undo)
        XCTAssertTrue(document.annotations.isEmpty)
        XCTAssertTrue(document.canRedo)

        document.apply(.redo)
        XCTAssertEqual(document.annotations, [.number(1, center: CGPoint(x: 10, y: 10))])
        XCTAssertTrue(document.canUndo)
    }

    func testPointerWithoutDownIsNoOp() {
        var document = makeDocument()
        document.apply(.pointerDragged(CGPoint(x: 10, y: 10)))
        document.apply(.pointerUp(CGPoint(x: 10, y: 10)))

        XCTAssertTrue(document.annotations.isEmpty)
        XCTAssertFalse(document.canUndo)
        XCTAssertFalse(document.canRedo)
    }

    func testToolSelectedDuringDragCancelsIt() {
        var document = makeDocument()
        document.apply(.pointerDown(CGPoint(x: 5, y: 5)))
        document.apply(.toolSelected(.number))
        document.apply(.pointerUp(CGPoint(x: 30, y: 20)))

        XCTAssertEqual(document.annotations, [.number(1, center: CGPoint(x: 30, y: 20))])
    }

    func testUndoAndRedoOnEmptyStackAreNoOps() {
        var document = makeDocument()
        document.apply(.undo)
        document.apply(.redo)

        XCTAssertTrue(document.annotations.isEmpty)
        XCTAssertFalse(document.canUndo)
        XCTAssertFalse(document.canRedo)
    }

    func testReversedDragCommitsArrowPointingBackAtTheOrigin() {
        var document = makeDocument()
        document.apply(.pointerDown(CGPoint(x: 5, y: 5)))
        document.apply(.pointerDragged(CGPoint(x: 20, y: 18)))
        document.apply(.arrowReversed(true))
        document.apply(.pointerUp(CGPoint(x: 20, y: 18)))

        XCTAssertEqual(document.annotations, [.arrow(from: CGPoint(x: 20, y: 18), to: CGPoint(x: 5, y: 5))])
    }

    func testRedactDragCommitsARect() {
        var document = makeDocument()
        document.apply(.toolSelected(.redact))
        document.apply(.pointerDown(CGPoint(x: 6, y: 4)))
        document.apply(.pointerDragged(CGPoint(x: 26, y: 20)))
        document.apply(.pointerUp(CGPoint(x: 26, y: 20)))

        XCTAssertEqual(document.annotations, [.redaction(CGRect(x: 6, y: 4, width: 20, height: 16))])
        XCTAssertTrue(document.canUndo)
    }

    func testRedactDragBackwardsNormalisesTheRect() {
        var document = makeDocument()
        document.apply(.toolSelected(.redact))
        document.apply(.pointerDown(CGPoint(x: 26, y: 20)))
        document.apply(.pointerUp(CGPoint(x: 6, y: 4)))

        XCTAssertEqual(document.annotations, [.redaction(CGRect(x: 6, y: 4, width: 20, height: 16))])
    }

    func testRedactTooSmallCommitsNothing() {
        var document = makeDocument()
        document.apply(.toolSelected(.redact))
        document.apply(.pointerDown(CGPoint(x: 6, y: 4)))
        document.apply(.pointerUp(CGPoint(x: 8, y: 5)))

        XCTAssertTrue(document.annotations.isEmpty)
        XCTAssertFalse(document.canUndo)
    }

    func testRectangleDragCommitsARect() {
        var document = makeDocument()
        document.apply(.toolSelected(.rectangle))
        document.apply(.pointerDown(CGPoint(x: 5, y: 5)))
        document.apply(.pointerDragged(CGPoint(x: 25, y: 20)))
        document.apply(.pointerUp(CGPoint(x: 25, y: 20)))

        XCTAssertEqual(document.annotations, [.rectangle(CGRect(x: 5, y: 5, width: 20, height: 15))])
    }

    func testRectangleTooSmallCommitsNothing() {
        var document = makeDocument()
        document.apply(.toolSelected(.rectangle))
        document.apply(.pointerDown(CGPoint(x: 5, y: 5)))
        document.apply(.pointerUp(CGPoint(x: 7, y: 6)))

        XCTAssertTrue(document.annotations.isEmpty)
    }
}
