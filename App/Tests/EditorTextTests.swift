import AppKit
import SnimachCore
import XCTest
@testable import Snimach

@MainActor
final class EditorTextTests: XCTestCase {
    func testClickingAwayFinishesTextAndAllowsDraggingIt() throws {
        let controller = EditorWindowController(document: Document(shot: makeTestShot(frame: CGRect(x: 0, y: 0, width: 400, height: 300))))
        controller.show()
        defer { controller.close() }
        let canvas = controller.canvas
        canvas.apply(.toolSelected(.text))
        canvas.apply(.pointerDown(CGPoint(x: 30, y: 220)))
        let editor = try XCTUnwrap(canvas.textEditor)
        editor.insertText("Label", replacementRange: NSRange(location: NSNotFound, length: 0))
        controller.accessoryBar.colorButton.performClick(nil)
        XCTAssertFalse(controller.styleShelf.isHidden)
        let location = canvas.convert(CGPoint(x: 250, y: 140), to: nil)
        let click = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseDown, location: location, modifierFlags: [],
            timestamp: 0, windowNumber: controller.panel.windowNumber, context: nil,
            eventNumber: 0, clickCount: 1, pressure: 1))
        controller.panel.sendEvent(click)
        XCTAssertNil(controller.document.textDraft)
        XCTAssertTrue(controller.styleShelf.isHidden)
        XCTAssertEqual(controller.accessoryBar.colorButton.state, .off)
        XCTAssertEqual(controller.document.tool, .select)
        XCTAssertEqual(controller.document.annotations.count, 1)
        XCTAssertNil(controller.document.selectionBounds)
        canvas.apply(.pointerDown(CGPoint(x: 35, y: 210)))
        canvas.apply(.pointerDragged(CGPoint(x: 55, y: 190)))
        canvas.apply(.pointerUp(CGPoint(x: 55, y: 190)))
        guard case .text(let text) = controller.document.annotations.first else { return XCTFail("Expected text") }
        XCTAssertEqual(text.origin, CGPoint(x: 50, y: 200))
        XCTAssertNotNil(controller.document.selectionBounds)
    }

    func testEscapeCancelsTextDraftAndReturnsToSelect() throws {
        let controller = EditorWindowController(document: Document(shot: makeTestShot()))
        controller.show()
        defer { controller.close() }
        controller.canvas.apply(.toolSelected(.text))
        controller.canvas.apply(.pointerDown(CGPoint(x: 5, y: 10)))
        let editor = try XCTUnwrap(controller.canvas.textEditor)
        editor.insertText("Draft", replacementRange: NSRange(location: NSNotFound, length: 0))
        try send("\u{1b}", code: 53, to: controller)
        XCTAssertNil(controller.document.textDraft)
        XCTAssertTrue(controller.document.annotations.isEmpty)
        XCTAssertEqual(controller.document.tool, .select)
        XCTAssertTrue(controller.panel.firstResponder === controller.canvas)
    }

    func testTypingKeepsToolKeysAndReturnInsideTextEditor() throws {
        let controller = EditorWindowController(document: Document(shot: makeTestShot(frame: CGRect(x: 100, y: 100, width: 400, height: 300))))
        controller.show()
        defer { controller.close() }
        var finished = false
        controller.onFinish = { _ in finished = true }
        try send("t", code: 17, to: controller)
        controller.canvas.apply(.pointerDown(CGPoint(x: 30, y: 220)))
        let editor = try XCTUnwrap(controller.panel.firstResponder as? NSTextView)
        try send("a", code: 0, to: controller)
        try send("\r", code: 36, to: controller)
        editor.insertText("Second line", replacementRange: NSRange(location: NSNotFound, length: 0))
        XCTAssertEqual(editor.string, "a\nSecond line")
        XCTAssertEqual(controller.document.tool, .text)
        XCTAssertFalse(finished)
        try send("\r", code: 36, modifiers: .command, to: controller)
        XCTAssertNil(controller.document.textDraft)
        XCTAssertEqual(controller.document.annotations.count, 1)
        XCTAssertTrue(controller.panel.firstResponder === controller.canvas)
        controller.canvas.apply(.undo)
        XCTAssertTrue(controller.document.annotations.isEmpty)
    }

    func testTextSizeShelfUpdatesDraftAndSelectedTextWithUndo() throws {
        let controller = EditorWindowController(document: Document(shot: makeTestShot(frame: CGRect(x: 100, y: 100, width: 400, height: 300))))
        controller.show()
        defer { controller.close() }
        controller.canvas.apply(.toolSelected(.text))
        controller.canvas.apply(.pointerDown(CGPoint(x: 30, y: 220)))
        let editor = try XCTUnwrap(controller.panel.firstResponder as? NSTextView)
        editor.insertText("Label", replacementRange: NSRange(location: NSNotFound, length: 0))
        controller.accessoryBar.colorButton.performClick(nil)
        controller.styleShelf.sizeButtons[TextSize.allCases.firstIndex(of: .large)!].performClick(nil)
        XCTAssertEqual(editor.font?.pointSize, 32)
        XCTAssertEqual(controller.document.textDraft?.size, .large)
        try send("\r", code: 36, modifiers: .command, to: controller)
        controller.styleShelf.sizeButtons[TextSize.allCases.firstIndex(of: .small)!].performClick(nil)
        XCTAssertEqual(controller.document.activeTextSize, .small)
        controller.canvas.apply(.undo)
        controller.canvas.apply(.toolSelected(.select))
        controller.canvas.apply(.pointerDown(CGPoint(x: 35, y: 205)))
        controller.canvas.apply(.pointerUp(CGPoint(x: 35, y: 205)))
        XCTAssertEqual(controller.document.activeTextSize, .large)
    }

    func testShelfChangesDraftBackgroundAndKeepsEditing() throws {
        let controller = EditorWindowController(document: Document(shot: makeTestShot(frame: CGRect(x: 100, y: 100, width: 400, height: 300))))
        controller.show()
        defer { controller.close() }
        controller.canvas.apply(.toolSelected(.text))
        controller.canvas.apply(.pointerDown(CGPoint(x: 30, y: 220)))
        let editor = try XCTUnwrap(controller.panel.firstResponder as? NSTextView)
        editor.insertText("Label", replacementRange: NSRange(location: NSNotFound, length: 0))
        controller.accessoryBar.colorButton.performClick(nil)
        controller.styleShelf.backgroundButtons[TextBackground.allCases.firstIndex(of: .solid)!].performClick(nil)
        XCTAssertEqual(controller.document.textDraft?.background, .solid)
        XCTAssertTrue(controller.panel.firstResponder === editor)
        XCTAssertFalse(controller.styleShelf.isHidden)
        try send("\u{1b}", code: 53, to: controller)
        XCTAssertTrue(controller.styleShelf.isHidden)
        XCTAssertNotNil(controller.document.textDraft)
    }

    func testPaletteClickKeepsTextDraftAndFocus() throws {
        let controller = EditorWindowController(document: Document(shot: makeTestShot(frame: CGRect(x: 100, y: 100, width: 100, height: 80))))
        controller.show()
        defer { controller.close() }
        controller.canvas.apply(.toolSelected(.text))
        controller.canvas.apply(.pointerDown(CGPoint(x: 10, y: 60)))
        let editor = try XCTUnwrap(controller.panel.firstResponder as? NSTextView)
        editor.insertText("Draft", replacementRange: NSRange(location: NSNotFound, length: 0))
        controller.panel.contentView?.layoutSubtreeIfNeeded()
        let button = controller.accessoryBar.colorButton
        button.onPress = {}
        let location = button.convert(CGPoint(x: button.bounds.midX, y: button.bounds.midY), to: nil)
        let up = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseUp, location: location, modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: controller.panel.windowNumber,
            context: nil, eventNumber: 1, clickCount: 1, pressure: 0))
        let down = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseDown, location: location, modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: controller.panel.windowNumber,
            context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
        NSApp.postEvent(up, atStart: true)
        controller.panel.sendEvent(down)
        XCTAssertEqual(controller.document.textDraft?.text, "Draft")
        XCTAssertTrue(controller.document.annotations.isEmpty)
        XCTAssertTrue(controller.panel.firstResponder === editor)
    }

    private func send(_ characters: String, code: UInt16, modifiers: NSEvent.ModifierFlags = [], to controller: EditorWindowController) throws {
        let event = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers,
            timestamp: 0, windowNumber: controller.panel.windowNumber, context: nil, characters: characters,
            charactersIgnoringModifiers: characters, isARepeat: false, keyCode: code))
        controller.panel.sendEvent(event)
    }
}
