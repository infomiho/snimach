import AppKit
import XCTest
@testable import Snimach

final class EditorKeymapTests: XCTestCase {
    func testToolKeys() {
        XCTAssertEqual(EditorKeymap.key(forKeyCode: 0, modifiers: []), .selectArrow)
        XCTAssertEqual(EditorKeymap.key(forKeyCode: 45, modifiers: []), .selectNumber)
        XCTAssertEqual(EditorKeymap.key(forKeyCode: 15, modifiers: []), .selectRectangle)
        XCTAssertEqual(EditorKeymap.key(forKeyCode: 11, modifiers: []), .selectRedact)
        XCTAssertNil(EditorKeymap.key(forKeyCode: 0, modifiers: .command))
    }

    func testCommitKeys() {
        XCTAssertEqual(EditorKeymap.key(forKeyCode: 36, modifiers: []), .commit)
        XCTAssertEqual(EditorKeymap.key(forKeyCode: 76, modifiers: []), .commit)
        XCTAssertEqual(EditorKeymap.key(forKeyCode: 8, modifiers: .command), .commit)
        XCTAssertNil(EditorKeymap.key(forKeyCode: 36, modifiers: .command))
    }

    func testSaveAndDiscard() {
        XCTAssertEqual(EditorKeymap.key(forKeyCode: 1, modifiers: .command), .save)
        XCTAssertEqual(EditorKeymap.key(forKeyCode: 53, modifiers: []), .discard)
    }

    func testUndoAndRedo() {
        XCTAssertEqual(EditorKeymap.key(forKeyCode: 6, modifiers: .command), .undo)
        XCTAssertEqual(EditorKeymap.key(forKeyCode: 6, modifiers: [.command, .shift]), .redo)
        XCTAssertNil(EditorKeymap.key(forKeyCode: 6, modifiers: []))
    }

    func testUnknownKey() {
        XCTAssertNil(EditorKeymap.key(forKeyCode: 99, modifiers: []))
    }

    func testTabRemainsAvailableForFocusNavigation() {
        XCTAssertNil(EditorKeymap.key(forKeyCode: 48, modifiers: []))
        XCTAssertNil(EditorKeymap.key(forKeyCode: 48, modifiers: .command))
    }

    func testISelectsColorPicker() {
        XCTAssertEqual(EditorKeymap.key(forKeyCode: 34, modifiers: []), .togglePicker)
        XCTAssertNil(EditorKeymap.key(forKeyCode: 34, modifiers: .command))
    }

    func testKCyclesBackdrop() {
        XCTAssertEqual(EditorKeymap.key(forKeyCode: 40, modifiers: []), .cycleBackdrop)
        XCTAssertNil(EditorKeymap.key(forKeyCode: 40, modifiers: .command))
    }
}
