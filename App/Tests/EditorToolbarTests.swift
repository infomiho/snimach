import AppKit
import SnimachCore
import XCTest
@testable import Snimach

@MainActor
final class EditorToolbarTests: XCTestCase {
    func testSolarIconsAreBundledAndLoad() {
        let icons = ToolChoice.all.map(\.icon) + [
            "undo-left-linear", "undo-right-linear", "diskette-linear", "copy-linear",
            "close-circle-linear", "pipette-linear", "menu-dots-linear", "alt-arrow-up-linear",
            "crop-linear", "window-frame-linear", "monitor-linear", "snimach-mark",
        ]
        for icon in icons { XCTAssertNotNil(BundledIcon.image(icon), "Missing \(icon)") }
        XCTAssertNotNil(Bundle.main.url(forResource: "Snimach", withExtension: "icns"))
    }

    func testSmallShotIsCenteredWithoutUpscaling() {
        let layout = EditorLayout.make(contentSize: CGSize(width: 200, height: 150))
        XCTAssertEqual(layout.contentSize, EditorLayout.minimumContentSize)
        XCTAssertEqual(layout.canvasFrame, CGRect(x: 80, y: 65, width: 200, height: 150))
        XCTAssertEqual(layout.zoom, 1)
    }

    func testLargeShotFitsScreenWithEqualInsets() {
        let layout = EditorLayout.make(contentSize: CGSize(width: 1000, height: 800),
                                       maxContent: CGSize(width: 548, height: 448))
        XCTAssertEqual(layout.zoom, 0.5)
        XCTAssertEqual(layout.canvasFrame, CGRect(x: 24, y: 24, width: 500, height: 400))
    }

    func testResizedCanvasFitsAndCenters() {
        let frame = EditorLayout.canvasFrame(for: CGSize(width: 400, height: 200),
                                             in: CGSize(width: 236, height: 236))
        XCTAssertEqual(frame, CGRect(x: 24, y: 71, width: 188, height: 94))
    }

    func testClampedFrameSnapsToWholePoints() {
        let shot = CGRect(x: 100, y: 100, width: 200, height: 150)
        let frame = EditorLayout.clampedFrame(CGRect(x: 0, y: 0, width: 300, height: 300), near: shot)
        XCTAssertEqual(frame.size, CGSize(width: 300, height: 300))
        XCTAssertEqual(frame.origin.x, frame.origin.x.rounded())
        XCTAssertEqual(frame.origin.y, frame.origin.y.rounded())
    }

    func testTitleBarContainsOnlyOutputActions() throws {
        let controller = makeEditor()
        let toolbar = try XCTUnwrap(controller.panel.toolbar)
        XCTAssertEqual(controller.toolbarDefaultItemIdentifiers(toolbar), [.flexibleSpace, .output])
        let group = try XCTUnwrap(toolbar.items.first { $0.itemIdentifier == .output } as? NSToolbarItemGroup)
        XCTAssertEqual(group.subitems.map(\.itemIdentifier), [.save, .copy])
        for id in [NSToolbarItem.Identifier.save, .copy] {
            XCTAssertNotNil(controller.toolbar(toolbar, itemForItemIdentifier: id, willBeInsertedIntoToolbar: false))
        }
    }

    func testToolsAndHistoryLiveOnTheStage() throws {
        let controller = makeEditor()
        let stage = try XCTUnwrap(controller.panel.contentView)
        XCTAssertTrue(controller.accessoryBar.superview === stage)
        XCTAssertTrue(controller.canvas.superview === stage)
        controller.accessoryBar.arrange(in: 900)
        XCTAssertEqual(controller.accessoryBar.visibleTools, [.arrow, .number, .rectangle, .redact])
        controller.accessoryBar.toolButtons[2].performClick(nil)
        XCTAssertEqual(controller.document.tool, .rectangle)
        XCTAssertEqual(controller.accessoryBar.toolButtons[2].state, .on)
        XCTAssertEqual(controller.accessoryBar.toolButtons[0].state, .off)
    }

    func testCompactBarKeepsSelectedToolVisibleAndFitsMinimumWidth() {
        let controller = makeEditor()
        for tool in ToolChoice.all.map(\.tool) {
            controller.canvas.apply(.toolSelected(tool))
            let size = controller.accessoryBar.arrange(in: 360)
            XCTAssertTrue(controller.accessoryBar.visibleTools.contains(tool))
            XCTAssertEqual(controller.accessoryBar.visibleTools.count, 2)
            XCTAssertFalse(controller.accessoryBar.moreButton.isHidden)
            XCTAssertLessThanOrEqual(size.width, 360 - EditorStyle.inset * 2)
        }
    }

    func testToolbarPaddingStaysBalancedAcrossResizeThresholds() {
        let controller = makeEditor()
        let bar = controller.accessoryBar
        for width in stride(from: CGFloat(360), through: 800, by: 4) {
            let size = bar.arrange(in: width)
            XCTAssertLessThanOrEqual(size.width, width - 48, "Window width \(width)")
            let buttons = bar.subviews.compactMap { $0 as? NSButton }.filter { !$0.isHidden }
            let first = buttons.min { $0.frame.minX < $1.frame.minX }!
            let last = buttons.max { $0.frame.maxX < $1.frame.maxX }!
            XCTAssertEqual(first.frame.minX, 8)
            XCTAssertEqual(size.width - last.frame.maxX, 8)
            for button in buttons {
                XCTAssertEqual(button.frame.minY, 8)
                XCTAssertEqual(size.height - button.frame.maxY, 8)
            }
        }
        bar.arrange(in: 440)
        XCTAssertEqual(bar.visibleTools.count, 4, "Keep tools visible when they fit without the backdrop label")
    }

    func testColorChipHasEqualOuterPaddingAndNoOverlappingControls() {
        let chip = ColorReadoutView(frame: .zero)
        let content = chip.subviews.filter { $0 is NSTextField || $0 is NSButton || $0.frame.width == 22 }
        let leading = content.map { $0.frame.minX }.min()!
        let trailing = chip.bounds.width - content.map { $0.frame.maxX }.max()!
        XCTAssertEqual(leading, 12)
        XCTAssertEqual(trailing, 12)
        let button = chip.subviews.compactMap { $0 as? NSButton }.first!
        for label in chip.subviews.compactMap({ $0 as? NSTextField }) {
            XCTAssertGreaterThanOrEqual(button.frame.minX - label.frame.maxX, 12)
        }
    }

    func testPresetGridHasEqualMarginsAndEightPointGaps() {
        let picker = BackdropPickerView()
        let firstRow = Array(picker.buttons.prefix(4))
        XCTAssertEqual(firstRow[0].frame.minX, 16)
        XCTAssertEqual(picker.bounds.width - firstRow[3].frame.maxX, 16)
        for (left, right) in zip(firstRow, firstRow.dropFirst()) {
            XCTAssertEqual(right.frame.minX - left.frame.maxX, 8)
        }
        XCTAssertEqual(picker.buttons[0].frame.minY - picker.buttons[4].frame.maxY, 8)
    }

    func testToggleDoesNotResizeOrMoveTheWindow() throws {
        let controller = makeEditor(size: CGSize(width: 1000, height: 640))
        let frame = controller.panel.frame
        let bar = controller.accessoryBar.frame
        for expected in [BackdropMode.solid, .transparent, .solid] {
            controller.accessoryBar.backdropButton.performClick(nil)
            controller.panel.contentView?.layoutSubtreeIfNeeded()
            XCTAssertEqual(controller.document.backdrop, expected)
            XCTAssertEqual(controller.panel.frame, frame)
            XCTAssertEqual(controller.accessoryBar.frame, bar)
            assertCanvasFits(controller)
        }
    }

    func testPresetsApplyEnableBackdropAndPreserveAnnotations() {
        let controller = makeEditor()
        controller.canvas.apply(.toolSelected(.number))
        controller.canvas.apply(.pointerUp(CGPoint(x: 10, y: 10)))
        let annotations = controller.document.annotations
        for (index, preset) in controller.backdropPicker.presets.enumerated() {
            controller.backdropPicker.buttons[index].performClick(nil)
            XCTAssertEqual(controller.document.backdrop, .solid)
            XCTAssertEqual(controller.document.backdropPreset.id, preset.id)
            XCTAssertEqual(controller.backdropPicker.selection, preset.id)
            XCTAssertEqual(controller.document.annotations, annotations)
        }
        controller.canvas.apply(.undo)
        XCTAssertTrue(controller.document.annotations.isEmpty)
        XCTAssertEqual(controller.document.backdropPreset.id, .quartz8)
    }

    func testPresetPopoverOpensAndSelectionDismissesIt() async throws {
        let controller = makeEditor(size: CGSize(width: 700, height: 440))
        controller.show()
        defer { controller.close() }
        controller.accessoryBar.presetsButton.performClick(nil)
        XCTAssertTrue(controller.backdropPopover.isShown)
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertNil(controller.backdropPicker.selection)
        XCTAssertTrue(controller.backdropPicker.window?.firstResponder === controller.backdropPicker)
        let rightArrow = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero,
            modifierFlags: [], timestamp: 0, windowNumber: controller.backdropPicker.window!.windowNumber,
            context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: 124))
        controller.backdropPicker.keyDown(with: rightArrow)
        XCTAssertTrue(controller.backdropPicker.window?.firstResponder === controller.backdropPicker.buttons.first)
        XCTAssertNil(controller.backdropPicker.selection)
        controller.backdropPicker.buttons[1].performClick(nil)
        for _ in 0..<20 where controller.backdropPopover.isShown {
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertFalse(controller.backdropPopover.isShown)
        XCTAssertEqual(controller.document.backdropPreset.id, .arendelle)
        XCTAssertTrue(controller.panel.firstResponder === controller.canvas)
    }

    func testPickerIsAnExclusiveModeAndEscapeLeavesItBeforeDiscarding() throws {
        let controller = makeEditor()
        var discarded = false
        controller.onFinish = { if case .discard = $0 { discarded = true } }
        XCTAssertTrue(controller.readout.isHidden)
        try press(34, in: controller)
        XCTAssertTrue(controller.canvas.isPickingColor)
        XCTAssertFalse(controller.readout.isHidden)
        XCTAssertTrue(controller.accessoryBar.toolButtons.allSatisfy { $0.state == .off })
        try press(53, in: controller)
        XCTAssertFalse(controller.canvas.isPickingColor)
        XCTAssertTrue(controller.readout.isHidden)
        XCTAssertFalse(discarded)
        try press(53, in: controller)
        XCTAssertTrue(discarded)
    }

    func testSelectingToolLeavesPickerMode() throws {
        let controller = makeEditor()
        controller.accessoryBar.pickerButton.performClick(nil)
        try press(15, in: controller)
        XCTAssertEqual(controller.document.tool, .rectangle)
        XCTAssertFalse(controller.canvas.isPickingColor)
        XCTAssertTrue(controller.readout.isHidden)
    }

    func testPickerClicksAndDragsDoNotAnnotate() throws {
        let controller = makeEditor()
        controller.canvas.apply(.toolSelected(.number))
        controller.accessoryBar.pickerButton.performClick(nil)
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseDragged, .leftMouseUp] {
            let event = try XCTUnwrap(NSEvent.mouseEvent(with: type, location: CGPoint(x: 10, y: 10),
                modifierFlags: [], timestamp: 0, windowNumber: controller.panel.windowNumber,
                context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
            switch type {
            case .leftMouseDown: controller.canvas.mouseDown(with: event)
            case .leftMouseDragged: controller.canvas.mouseDragged(with: event)
            default: controller.canvas.mouseUp(with: event)
            }
        }
        XCTAssertTrue(controller.document.annotations.isEmpty)
        XCTAssertFalse(controller.document.canUndo)
    }

    func testSelectedColorSurvivesMovementAndCopiesWithoutClosing() throws {
        let context = try XCTUnwrap(CGContext(data: nil, width: 40, height: 30, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 20, height: 30))
        context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1))
        context.fill(CGRect(x: 20, y: 0, width: 20, height: 30))
        let shot = Shot(image: try XCTUnwrap(context.makeImage()), scale: 1,
            frame: CGRect(x: 0, y: 0, width: 40, height: 30))
        let controller = EditorWindowController(document: Document(shot: shot))
        defer { controller.close() }
        controller.selectPreset(.sierra7)
        controller.panel.setContentSize(CGSize(width: 360, height: 280))
        var finished = false
        controller.onFinish = { _ in finished = true }
        let board = NSPasteboard.general
        let saved = board.pasteboardItems?.compactMap { item -> NSPasteboardItem? in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) { copy.setData(data, forType: type) }
            }
            return copy
        } ?? []
        defer {
            board.clearContents()
            board.writeObjects(saved)
        }
        board.clearContents()
        board.setString("unchanged", forType: .string)
        try press(48, in: controller)
        XCTAssertEqual(board.string(forType: .string), "unchanged")
        controller.accessoryBar.pickerButton.performClick(nil)
        try press(48, in: controller)
        XCTAssertEqual(board.string(forType: .string), "unchanged")
        func pointEvent(_ type: NSEvent.EventType, x: CGFloat) throws -> NSEvent {
            let origin = controller.document.stageOrigin
            let location = controller.canvas.convert(CGPoint(x: origin.x + x, y: origin.y + 10), to: nil)
            return try XCTUnwrap(NSEvent.mouseEvent(with: type, location: location,
                modifierFlags: [], timestamp: 0, windowNumber: controller.panel.windowNumber,
                context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
        }
        controller.canvas.mouseMoved(with: try pointEvent(.mouseMoved, x: 5))
        XCTAssertEqual(controller.currentHex, "#FF0000")
        controller.canvas.mouseDown(with: try pointEvent(.leftMouseDown, x: 5))
        controller.canvas.mouseMoved(with: try pointEvent(.mouseMoved, x: 35))
        controller.canvas.mouseDragged(with: try pointEvent(.leftMouseDragged, x: 35))
        XCTAssertTrue(controller.canvas.isColorFrozen)
        XCTAssertEqual(controller.currentHex, "#FF0000")
        controller.readout.copyButton.performClick(nil)
        XCTAssertEqual(board.string(forType: .string), "#FF0000")
        controller.canvas.mouseDown(with: try pointEvent(.leftMouseDown, x: 35))
        XCTAssertEqual(controller.currentHex, "#0000FF")
        controller.panel.makeFirstResponder(controller.readout.copyButton)
        let copyKey = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero,
            modifierFlags: .command, timestamp: 0, windowNumber: controller.panel.windowNumber,
            context: nil, characters: "c", charactersIgnoringModifiers: "c", isARepeat: false, keyCode: 8))
        controller.panel.sendEvent(copyKey)
        XCTAssertEqual(board.string(forType: .string), "#0000FF")
        XCTAssertFalse(finished)
        XCTAssertTrue(controller.canvas.isPickingColor)
        XCTAssertEqual(controller.readout.displayedHint, "Copied")
        try press(53, in: controller)
        controller.accessoryBar.pickerButton.performClick(nil)
        XCTAssertFalse(controller.canvas.isColorFrozen)
        controller.canvas.mouseMoved(with: try pointEvent(.mouseMoved, x: 5))
        XCTAssertEqual(controller.currentHex, "#FF0000")
        XCTAssertTrue(controller.document.annotations.isEmpty)
    }

    func testPickerKeepsImageSizeAndReadoutAvoidsPointerUntilSelection() throws {
        let controller = makeEditor(size: CGSize(width: 900, height: 560))
        let stage = try XCTUnwrap(controller.panel.contentView as? EditorStageView)
        for size in [CGSize(width: 360, height: 280), CGSize(width: 936, height: 596)] {
            controller.panel.setContentSize(size)
            stage.layoutSubtreeIfNeeded()
            let original = controller.canvas.frame
            controller.accessoryBar.pickerButton.performClick(nil)
            XCTAssertEqual(controller.canvas.frame, original)
            let initial = controller.readout.frame
            let pointer = CGPoint(x: initial.midX, y: initial.midY)
            stage.avoidPointer(pointer)
            XCTAssertFalse(controller.readout.frame.insetBy(dx: -24, dy: -24).contains(pointer))
            let moved = controller.readout.frame
            stage.avoidPointer(pointer)
            XCTAssertEqual(controller.readout.frame, moved)
            controller.canvas.sampleColor(at: CGPoint(x: 10, y: 10), selecting: true)
            stage.avoidPointer(CGPoint(x: moved.midX, y: moved.midY))
            XCTAssertEqual(controller.readout.frame, moved)
            XCTAssertEqual(controller.canvas.frame, original)
            assertCanvasFits(controller)
            controller.accessoryBar.pickerButton.performClick(nil)
        }
    }

    func testDisabledBackdropHasNoSelectedPreset() {
        let picker = BackdropPickerView()
        let preset = BackdropPreset.preset(.sierra7)
        picker.update(preset: preset, active: true)
        XCTAssertEqual(picker.selection, .sierra7)
        picker.update(preset: preset, active: false)
        XCTAssertNil(picker.selection)
        XCTAssertTrue(picker.buttons.allSatisfy { ($0.accessibilityValue() as? String) != "Selected" })
    }

    func testWindowCloseDiscardsScreenshot() {
        let controller = makeEditor()
        var discarded = false
        controller.onFinish = { if case .discard = $0 { discarded = true } }
        controller.panel.performClose(nil)
        XCTAssertTrue(discarded)
    }

    func testReadoutSamplesAndConfirmsWithoutChangingHex() async throws {
        let controller = makeEditor()
        let hex = try XCTUnwrap(controller.currentHex)
        XCTAssertEqual(controller.readout.displayedText, hex)
        controller.readout.flash("Copied")
        XCTAssertEqual(controller.readout.displayedText, hex)
        try await Task.sleep(for: .seconds(1.4))
        XCTAssertEqual(controller.readout.displayedHint, "Click to select · ⌘C to copy")
    }

    func testHistoryButtonsTrackDocumentAndPerformActions() {
        let controller = makeEditor()
        XCTAssertFalse(controller.accessoryBar.undoButton.isEnabled)
        XCTAssertFalse(controller.accessoryBar.redoButton.isEnabled)
        controller.canvas.apply(.pointerDown(CGPoint(x: 1, y: 1)))
        controller.canvas.apply(.pointerUp(CGPoint(x: 15, y: 12)))
        XCTAssertTrue(controller.accessoryBar.undoButton.isEnabled)
        controller.accessoryBar.undoButton.performClick(nil)
        XCTAssertTrue(controller.document.annotations.isEmpty)
        XCTAssertTrue(controller.accessoryBar.redoButton.isEnabled)
        controller.accessoryBar.redoButton.performClick(nil)
        XCTAssertEqual(controller.document.annotations.count, 1)
    }

    func testKAndAnnotationKeysWorkAfterResizingAndBackdropChange() throws {
        let controller = makeEditor(size: CGSize(width: 900, height: 560))
        controller.panel.setContentSize(CGSize(width: 360, height: 300))
        let frame = controller.panel.frame
        try press(40, in: controller)
        try press(15, in: controller)
        controller.panel.contentView?.layoutSubtreeIfNeeded()
        XCTAssertEqual(controller.document.backdrop, .solid)
        XCTAssertEqual(controller.document.tool, .rectangle)
        XCTAssertEqual(controller.panel.frame, frame)
        XCTAssertEqual(controller.canvas.bounds.width, controller.document.stageSize.width, accuracy: 0.001)
        XCTAssertEqual(controller.canvas.bounds.height, controller.document.stageSize.height, accuracy: 0.001)
        assertCanvasFits(controller)
    }

    func testOutputActionsRemainVisibleAtMinimumWidth() async throws {
        let controller = makeEditor()
        controller.show()
        defer { controller.close() }
        controller.panel.setContentSize(EditorLayout.minimumContentSize)
        try await Task.sleep(for: .milliseconds(200))
        let toolbar = try XCTUnwrap(controller.panel.toolbar)
        XCTAssertTrue(toolbar.visibleItems?.contains { $0.itemIdentifier == .output } ?? false)
    }

    func testWindowRoutesToolKeysWhileButtonHasFocus() throws {
        let controller = makeEditor()
        controller.panel.makeFirstResponder(controller.accessoryBar.pickerButton)
        let event = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero,
            modifierFlags: [], timestamp: 0, windowNumber: controller.panel.windowNumber,
            context: nil, characters: "r", charactersIgnoringModifiers: "r", isARepeat: false, keyCode: 15))
        controller.panel.sendEvent(event)
        XCTAssertEqual(controller.document.tool, .rectangle)
    }

    func testPrefsSeedEditorDocumentAndSwatch() {
        let suite = "snimach-seed-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let prefs = Preferences(defaults: defaults)
        prefs.backdrop = .solid
        prefs.backdropPreset = BackdropPreset.preset(.arendelle)
        let controller = AppDelegate.editorWindowController(document: Document(shot: makeTestShot()), preferences: prefs)
        XCTAssertEqual(controller.document.backdrop, .solid)
        XCTAssertEqual(controller.document.backdropPreset.id, .arendelle)
        XCTAssertEqual(controller.backdropPicker.selection, .arendelle)
        XCTAssertNotNil(controller.accessoryBar.backdropButton.image)
    }

    func testCopyAndSaveExportDocumentInsteadOfEditorChrome() throws {
        for (keyCode, modifiers) in [(UInt16(36), NSEvent.ModifierFlags()), (UInt16(1), .command)] {
            let controller = makeEditor()
            controller.selectPreset(.sierra7)
            let expected = try controller.document.render()
            var output: CGImage?
            controller.onFinish = {
                switch $0 {
                case .copy(let image), .saveAndCopy(let image): output = image
                case .discard: XCTFail("Unexpected discard")
                }
            }
            try press(keyCode, modifiers: modifiers, in: controller)
            XCTAssertEqual(output?.width, expected.width)
            XCTAssertEqual(output?.height, expected.height)
            XCTAssertEqual(output?.dataProvider?.data as Data?, expected.dataProvider?.data as Data?)
        }
    }

    private func makeEditor(size: CGSize? = nil) -> EditorWindowController {
        let shot = size.map { makeTestShot(frame: CGRect(origin: CGPoint(x: 200, y: 200), size: $0)) }
            ?? makeTestShot()
        return EditorWindowController(document: Document(shot: shot))
    }

    private func press(_ keyCode: UInt16, modifiers: NSEvent.ModifierFlags = [], in controller: EditorWindowController) throws {
        let event = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero,
            modifierFlags: modifiers, timestamp: 0, windowNumber: controller.panel.windowNumber,
            context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: keyCode))
        controller.canvas.keyDown(with: event)
    }

    private func assertCanvasFits(_ controller: EditorWindowController, file: StaticString = #filePath, line: UInt = #line) {
        let content = controller.panel.contentView!
        let frame = controller.canvas.frame
        XCTAssertGreaterThanOrEqual(frame.minX, 0, file: file, line: line)
        XCTAssertGreaterThanOrEqual(frame.minY, 0, file: file, line: line)
        XCTAssertLessThanOrEqual(frame.maxX, content.bounds.width, file: file, line: line)
        XCTAssertLessThanOrEqual(frame.maxY, content.bounds.height, file: file, line: line)
    }
}
