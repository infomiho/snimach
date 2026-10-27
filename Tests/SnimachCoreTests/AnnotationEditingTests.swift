import CoreGraphics
import XCTest
@testable import SnimachCore

final class AnnotationEditingTests: XCTestCase {
    func testLastChosenColorCarriesFromTextToFutureShapes() {
        var document = Document(shot: makeShot(pointSize: CGSize(width: 200, height: 150), scale: 2))
        document.apply(.toolSelected(.text))
        document.apply(.pointerDown(CGPoint(x: 20, y: 120)))
        document.apply(.textChanged("Blue label"))
        document.apply(.colorSelected(.blue))
        document.apply(.finishText)
        document.apply(.toolSelected(.line))
        document.apply(.pointerDown(CGPoint(x: 20, y: 30)))
        document.apply(.pointerUp(CGPoint(x: 100, y: 30)))
        XCTAssertEqual(document.annotations.last?.color, .blue)
        document.apply(.colorSelected(.green))
        document.apply(.toolSelected(.number))
        document.apply(.pointerUp(CGPoint(x: 150, y: 80)))
        XCTAssertEqual(document.annotations.last?.color, .green)
        XCTAssertEqual(document.annotations.first?.color, .blue)
    }

    func testRedoCannotReplaceNewTextDraftWithUndoneAnnotation() {
        var document = Document(shot: makeShot(pointSize: CGSize(width: 200, height: 150), scale: 2))
        document.apply(.toolSelected(.number))
        document.apply(.pointerUp(CGPoint(x: 10, y: 10)))
        document.apply(.undo)
        document.apply(.toolSelected(.text))
        document.apply(.pointerDown(CGPoint(x: 20, y: 120)))
        document.apply(.textChanged("New label"))
        document.apply(.redo)
        XCTAssertNil(document.textDraft)
        guard case .text(let text) = document.annotations.first else { return XCTFail("Expected the new text") }
        XCTAssertEqual(text.text, "New label")
        XCTAssertFalse(document.canRedo)
    }

    func testDeletingTextDuringEditEndsDraftAndUndoRestoresIt() {
        var document = Document(shot: makeShot(pointSize: CGSize(width: 200, height: 150), scale: 2))
        document.apply(.toolSelected(.text))
        document.apply(.pointerDown(CGPoint(x: 20, y: 120)))
        document.apply(.textChanged("Original"))
        document.apply(.finishText)
        document.apply(.pointerDown(CGPoint(x: 25, y: 110)))
        document.apply(.deleteSelection)
        XCTAssertNil(document.textDraft)
        XCTAssertTrue(document.annotations.isEmpty)
        document.apply(.undo)
        XCTAssertEqual(document.annotations.count, 1)
    }

    func testDocumentUndoDuringTextDraftPreservesEarlierAnnotations() {
        var document = Document(shot: makeShot(pointSize: CGSize(width: 200, height: 150), scale: 2))
        document.apply(.toolSelected(.number))
        document.apply(.pointerUp(CGPoint(x: 10, y: 10)))
        document.apply(.toolSelected(.text))
        document.apply(.pointerDown(CGPoint(x: 30, y: 120)))
        document.apply(.textChanged("Draft"))
        document.apply(.undo)
        XCTAssertNil(document.textDraft)
        XCTAssertEqual(document.annotations, [.number(1, center: CGPoint(x: 10, y: 10))])
        document.apply(.redo)
        XCTAssertEqual(document.annotations.count, 2)
    }

    func testTextDraftCommitsOnceAndEditingCanBeCancelled() {
        var document = Document(shot: makeShot(pointSize: CGSize(width: 200, height: 150), scale: 2))
        document.apply(.toolSelected(.text))
        document.apply(.pointerDown(CGPoint(x: 20, y: 100)))
        document.apply(.textChanged("Hello\nworld"))
        XCTAssertTrue(document.annotations.isEmpty)
        XCTAssertFalse(document.canUndo)
        document.apply(.finishText)
        XCTAssertEqual(document.annotations.count, 1)
        document.apply(.pointerDown(CGPoint(x: 25, y: 90)))
        XCTAssertEqual(document.textDraft?.text, "Hello\nworld")
        document.apply(.textChanged("Replacement"))
        document.apply(.cancelText)
        document.apply(.undo)
        XCTAssertTrue(document.annotations.isEmpty)
        document.apply(.redo)
        document.apply(.pointerDown(CGPoint(x: 25, y: 90)))
        XCTAssertEqual(document.textDraft?.text, "Hello\nworld")
    }

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
