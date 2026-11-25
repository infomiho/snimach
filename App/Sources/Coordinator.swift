import AppKit
import CoreGraphics
import SnimachCore

@MainActor
protocol CaptureService: AnyObject {
    func capture(_ kind: Capturer.Kind) async throws -> Shot
}

extension Capturer: CaptureService {}

@MainActor
protocol OutputService: AnyObject {
    func copy(_ image: CGImage, scale: CGFloat) throws
    @discardableResult func save(_ image: CGImage, scale: CGFloat) throws -> URL
}

extension ShotOutput: OutputService {}

extension OutputService {
    /// Delivery for the capture path. A Shot's pixels come with their own scale, so callers
    /// never re-pair them.
    func copy(_ shot: Shot) throws { try copy(shot.image, scale: shot.scale) }

    @discardableResult
    func save(_ shot: Shot) throws -> URL { try save(shot.image, scale: shot.scale) }
}

@MainActor
protocol CoordinatorPresenter: AnyObject {
    func showPermission(_ state: PermissionState)
    func showError(_ error: Error)
    func showSaved(_ url: URL, near shot: CGRect)
}

/// Wiring only: it owns lifecycle and event routing, never product logic. All seams are injected
/// so tests replace the capturer, the output, the preview factory and the editor factory.
///
/// A capture lands on the pasteboard immediately and shows a preview card. The editor is opt-in:
/// it opens only when the user clicks the card, and copies again on commit.
@MainActor
final class Coordinator {
    private let captureService: CaptureService
    private let output: OutputService
    private let makePreview: (Shot) -> PreviewController
    private let makeEditor: (Document) -> EditorController
    private let presenter: CoordinatorPresenter
    private let afterCapture: () -> AfterCapture
    private let makeSettings: () -> SettingsWindowController

    private(set) var preview: PreviewController?
    private(set) var editor: EditorController?
    private(set) var inFlight: Task<Void, Never>?
    private var settings: SettingsWindowController?

    var isCapturing: Bool { inFlight != nil }

    init(captureService: CaptureService,
         output: OutputService,
         makePreview: @escaping (Shot) -> PreviewController,
         makeEditor: @escaping (Document) -> EditorController,
         presenter: CoordinatorPresenter,
         afterCapture: @escaping () -> AfterCapture = { .preview },
         makeSettings: @escaping () -> SettingsWindowController) {
        self.captureService = captureService
        self.output = output
        self.makePreview = makePreview
        self.makeEditor = makeEditor
        self.presenter = presenter
        self.afterCapture = afterCapture
        self.makeSettings = makeSettings
    }

    /// A hotkey while the editor is open or a capture is in flight is ignored. A preview still on
    /// screen is dropped first so it does not end up inside the new shot.
    func capture(_ kind: Capturer.Kind) {
        guard editor == nil, inFlight == nil else { return }
        dismissPreview()
        inFlight = Task { [weak self] in
            await self?.runCapture(kind)
            self?.inFlight = nil
        }
    }

    func showSettings() {
        if settings == nil { settings = makeSettings() }
        settings?.show()
    }

    func showAbout() {
        if settings == nil { settings = makeSettings() }
        settings?.show(tab: .about)
    }

    private func runCapture(_ kind: Capturer.Kind) async {
        do {
            let shot = try await captureService.capture(kind)
            deliver(shot)
        } catch is CancellationError {
            // Every cancel cause returns to idle silently.
        } catch let error as CaptureError {
            switch error {
            case .permission(.notDetermined):
                // The system prompt is already on screen. Showing our own alert on top
                // of it doubles the dialogs and sends the user to System Settings before
                // the TCC entry exists, so stay silent.
                break
            case .permission(let state):
                presenter.showPermission(state)
            case .noWindow, .failed:
                presenter.showError(error)
            }
        } catch {
            presenter.showError(error)
        }
    }

    private func deliver(_ shot: Shot) {
        // The plain shot is on the pasteboard before anything appears on screen.
        // Failure is not actionable, the preview card is the feedback.
        try? output.copy(shot)
        switch afterCapture() {
        case .clipboardOnly: break
        case .editor: openEditor(shot)
        case .preview: showPreview(shot)
        }
    }

    private func showPreview(_ shot: Shot) {
        let preview = makePreview(shot)
        preview.onFinish = { [weak self] outcome in
            self?.preview = nil
            switch outcome {
            case .edit: self?.openEditor(shot)
            case .save: self?.savePlainShot(shot)
            case .dismiss: break
            }
        }
        self.preview = preview
        preview.show()
    }

    private func savePlainShot(_ shot: Shot) {
        do {
            let url = try output.save(shot)
            try output.copy(shot)
            presenter.showSaved(url, near: shot.frame)
        } catch {
            presenter.showError(error)
        }
    }

    private func dismissPreview() {
        preview?.onFinish = nil
        preview?.close()
        preview = nil
    }

    private func openEditor(_ shot: Shot) {
        let editor = makeEditor(Document(shot: shot))
        editor.onFinish = { [weak self] outcome in
            self?.finish(outcome, shot: shot)
        }
        self.editor = editor
        editor.show()
    }

    private func finish(_ outcome: EditorOutcome, shot: Shot) {
        let scale = shot.scale
        editor = nil
        switch outcome {
        case .discard:
            break
        case .copy(let image):
            // Failure is not actionable, the editor closing is the feedback.
            try? output.copy(image, scale: scale)
        case .saveAndCopy(let image):
            do {
                let url = try output.save(image, scale: scale)
                try output.copy(image, scale: scale)
                presenter.showSaved(url, near: shot.frame)
            } catch {
                presenter.showError(error)
            }
        }
    }
}
