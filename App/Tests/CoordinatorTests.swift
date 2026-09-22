import AppKit
import SnimachCore
import XCTest
@testable import Snimach

@MainActor
final class CoordinatorTests: XCTestCase {
    func testCaptureCopiesAndShowsPreviewWithoutEditor() async throws {
        let harness = Harness()
        harness.capture.nextResult = .success(makeTestShot())

        await harness.runCapture()

        XCTAssertEqual(harness.capture.captureCount, 1)
        XCTAssertEqual(harness.output.copyCount, 1)
        let preview = try XCTUnwrap(harness.editorBox.previews.last)
        XCTAssertTrue(preview.shown)
        XCTAssertTrue(harness.coordinator.preview === preview)
        XCTAssertNil(harness.coordinator.editor)
        XCTAssertTrue(harness.editorBox.editors.isEmpty)
        XCTAssertFalse(harness.coordinator.isCapturing)
    }

    func testCapturedShotIsDeliveredWithItsOwnScale() async throws {
        let harness = Harness()
        let shot = makeTestShot(scale: 1)
        harness.capture.nextResult = .success(shot)

        await harness.runCapture()

        let delivery = try XCTUnwrap(harness.output.lastDelivery)
        XCTAssertTrue(delivery.image === shot.image)
        XCTAssertEqual(delivery.scale, 1, "a 1x shot must not reach the pasteboard at Retina DPI")
    }

    func testPreviewEditOpensEditorOnSameShot() async throws {
        let harness = Harness()
        harness.capture.nextResult = .success(makeTestShot())
        let preview = try await harness.showPreview()

        preview.onFinish?(.edit)

        let editor = try XCTUnwrap(harness.editorBox.editors.last)
        XCTAssertTrue(editor.shown)
        XCTAssertTrue(harness.coordinator.editor === editor)
        XCTAssertNil(harness.coordinator.preview)
        XCTAssertEqual(editor.document.shot.frame, preview.shot.frame)
    }

    func testPreviewDismissLeavesIdle() async throws {
        let harness = Harness()
        harness.capture.nextResult = .success(makeTestShot())
        let preview = try await harness.showPreview()

        preview.onFinish?(.dismiss)

        XCTAssertNil(harness.coordinator.preview)
        XCTAssertNil(harness.coordinator.editor)
        XCTAssertTrue(harness.editorBox.editors.isEmpty)
        XCTAssertEqual(harness.output.copyCount, 1)
    }

    func testCaptureWhilePreviewShowingReplacesIt() async throws {
        let harness = Harness()
        harness.capture.nextResult = .success(makeTestShot())
        let first = try await harness.showPreview()

        await harness.runCapture()

        XCTAssertTrue(first.closed)
        XCTAssertNil(first.onFinish)
        XCTAssertEqual(harness.capture.captureCount, 2)
        XCTAssertEqual(harness.editorBox.previews.count, 2)
        XCTAssertTrue(harness.coordinator.preview === harness.editorBox.previews.last)
    }

    func testCaptureIgnoredWhileEditing() async throws {
        let harness = Harness()
        harness.capture.nextResult = .success(makeTestShot())
        _ = try await harness.openEditor()

        harness.coordinator.capture(.area)
        await harness.coordinator.inFlight?.value

        XCTAssertEqual(harness.capture.captureCount, 1)
        XCTAssertEqual(harness.editorBox.editors.count, 1)
        XCTAssertEqual(harness.editorBox.previews.count, 1)
    }

    func testCaptureIgnoredWhileCapturing() async throws {
        let harness = Harness()
        harness.capture.nextResult = .success(makeTestShot())

        harness.coordinator.capture(.area)
        harness.coordinator.capture(.area)
        XCTAssertEqual(harness.capture.captureCount, 0)

        await harness.coordinator.inFlight?.value
        XCTAssertEqual(harness.capture.captureCount, 1)
    }

    func testCancellationReturnsToIdle() async throws {
        let harness = Harness()
        harness.capture.nextResult = .failure(CancellationError())

        await harness.runCapture()

        XCTAssertFalse(harness.coordinator.isCapturing)
        XCTAssertNil(harness.coordinator.editor)
        XCTAssertTrue(harness.presenter.errors.isEmpty)
        XCTAssertTrue(harness.presenter.permissions.isEmpty)
    }

    func testPermissionErrorMapsToPermissionPresenter() async throws {
        let harness = Harness()
        harness.capture.nextResult = .failure(CaptureError.permission(.grantedNeedsRelaunch))

        await harness.runCapture()

        XCTAssertEqual(harness.presenter.permissions, [.grantedNeedsRelaunch])
        XCTAssertTrue(harness.presenter.errors.isEmpty)
    }

    func testFirstPromptStaysSilent() async throws {
        let harness = Harness()
        harness.capture.nextResult = .failure(CaptureError.permission(.notDetermined))

        await harness.runCapture()

        XCTAssertTrue(harness.presenter.permissions.isEmpty)
        XCTAssertTrue(harness.presenter.errors.isEmpty)
        XCTAssertNil(harness.coordinator.editor)
    }

    func testNoWindowMapsToError() async throws {
        let harness = Harness()
        harness.capture.nextResult = .failure(CaptureError.noWindow)

        await harness.runCapture()

        XCTAssertEqual(harness.presenter.errors.count, 1)
        XCTAssertTrue(harness.presenter.errors.first is CaptureError)
    }

    func testCopyOutcomeCopiesAgainAndClearsEditor() async throws {
        let harness = Harness()
        harness.capture.nextResult = .success(makeTestShot())
        let editor = try await harness.openEditor()

        editor.onFinish?(.copy(makeTestShot().image))

        XCTAssertEqual(harness.output.copyCount, 2)
        XCTAssertEqual(harness.output.saveCount, 0)
        XCTAssertNil(harness.coordinator.editor)
    }

    func testSaveOutcomeSavesCopiesAndShowsHUD() async throws {
        let harness = Harness()
        harness.capture.nextResult = .success(makeTestShot())
        let editor = try await harness.openEditor()

        editor.onFinish?(.saveAndCopy(makeTestShot().image))

        XCTAssertEqual(harness.output.saveCount, 1)
        XCTAssertEqual(harness.output.copyCount, 2)
        XCTAssertEqual(harness.presenter.saved.count, 1)
        XCTAssertNil(harness.coordinator.editor)
    }

    func testSaveErrorSurfacesOnceAndDoesNotCopy() async throws {
        let harness = Harness()
        harness.capture.nextResult = .success(makeTestShot())
        harness.output.saveError = NSError(domain: "test", code: 1)
        let editor = try await harness.openEditor()

        editor.onFinish?(.saveAndCopy(makeTestShot().image))

        XCTAssertEqual(harness.presenter.errors.count, 1)
        XCTAssertEqual(harness.output.saveCount, 1)
        XCTAssertEqual(harness.output.copyCount, 1)
        XCTAssertNil(harness.coordinator.editor)
    }

    func testDiscardDoesNothingAndClearsEditor() async throws {
        let harness = Harness()
        harness.capture.nextResult = .success(makeTestShot())
        let editor = try await harness.openEditor()

        editor.onFinish?(.discard)

        XCTAssertEqual(harness.output.copyCount, 1)
        XCTAssertEqual(harness.output.saveCount, 0)
        XCTAssertNil(harness.coordinator.editor)
    }

    func testPreviewSaveSavesPlainShotAndShowsHUD() async throws {
        let harness = Harness()
        harness.capture.nextResult = .success(makeTestShot())
        let preview = try await harness.showPreview()

        preview.onFinish?(.save)

        XCTAssertNil(harness.coordinator.preview)
        XCTAssertNil(harness.coordinator.editor)
        XCTAssertTrue(harness.editorBox.editors.isEmpty)
        XCTAssertEqual(harness.output.saveCount, 1)
        XCTAssertEqual(harness.output.copyCount, 2)
        XCTAssertEqual(harness.presenter.saved.count, 1)
    }

    func testPreviewSaveErrorSurfacesOnce() async throws {
        let harness = Harness()
        harness.capture.nextResult = .success(makeTestShot())
        harness.output.saveError = NSError(domain: "test", code: 1)
        let preview = try await harness.showPreview()

        preview.onFinish?(.save)

        XCTAssertEqual(harness.presenter.errors.count, 1)
        XCTAssertEqual(harness.output.saveCount, 1)
        XCTAssertEqual(harness.output.copyCount, 1)
        XCTAssertNil(harness.coordinator.preview)
    }

    func testClipboardOnlyShowsNothingAfterCopying() async throws {
        let harness = Harness()
        harness.editorBox.afterCapture = .clipboardOnly
        harness.capture.nextResult = .success(makeTestShot())

        await harness.runCapture()

        XCTAssertEqual(harness.output.copyCount, 1)
        XCTAssertTrue(harness.editorBox.previews.isEmpty)
        XCTAssertTrue(harness.editorBox.editors.isEmpty)
        XCTAssertNil(harness.coordinator.preview)
        XCTAssertNil(harness.coordinator.editor)
    }

    func testEditorSettingSkipsTheCard() async throws {
        let harness = Harness()
        harness.editorBox.afterCapture = .editor
        harness.capture.nextResult = .success(makeTestShot())

        await harness.runCapture()

        XCTAssertEqual(harness.output.copyCount, 1)
        XCTAssertTrue(harness.editorBox.previews.isEmpty)
        let editor = try XCTUnwrap(harness.editorBox.editors.last)
        XCTAssertTrue(editor.shown)
        XCTAssertTrue(harness.coordinator.editor === editor)
    }
}
