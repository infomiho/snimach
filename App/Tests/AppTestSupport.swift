import AppKit
import CoreGraphics
import SnimachCore
import XCTest
@testable import Snimach

@MainActor
final class FakeCaptureService: CaptureService {
    var nextResult: Result<Shot, Error> = .failure(CancellationError())
    private(set) var captureCount = 0

    func capture(_ kind: Capturer.Kind) async throws -> Shot {
        captureCount += 1
        return try nextResult.get()
    }
}

@MainActor
final class FakeOutput: OutputService {
    var copyError: Error?
    var saveError: Error?
    private(set) var copyCount = 0
    private(set) var saveCount = 0
    private(set) var lastDelivery: (image: CGImage, scale: CGFloat)?

    func copy(_ image: CGImage, scale: CGFloat) throws {
        copyCount += 1
        lastDelivery = (image, scale)
        if let copyError { throw copyError }
    }

    @discardableResult
    func save(_ image: CGImage, scale: CGFloat) throws -> URL {
        saveCount += 1
        lastDelivery = (image, scale)
        if let saveError { throw saveError }
        return URL(fileURLWithPath: "/tmp/snimach-test.png")
    }
}

@MainActor
final class FakePresenter: CoordinatorPresenter {
    var savedNear: [CGRect] = []
    private(set) var permissions: [PermissionState] = []
    private(set) var errors: [Error] = []
    private(set) var saved: [URL] = []

    func showPermission(_ state: PermissionState) { permissions.append(state) }
    func showError(_ error: Error) { errors.append(error) }
    func showSaved(_ url: URL, near shot: CGRect) { saved.append(url); savedNear.append(shot) }
}

@MainActor
final class FakeEditor: EditorController {
    var document: Document
    var onFinish: ((EditorOutcome) -> Void)?
    private(set) var shown = false
    private(set) var closed = false

    init(document: Document) {
        self.document = document
    }

    func show() { shown = true }
    func close() { closed = true }
}

@MainActor
final class FakePreview: PreviewController {
    let shot: Shot
    var onFinish: ((PreviewOutcome) -> Void)?
    private(set) var shown = false
    private(set) var closed = false

    init(shot: Shot) {
        self.shot = shot
    }

    func show() { shown = true }
    func close() { closed = true }
}

@MainActor
final class EditorBox {
    var afterCapture: AfterCapture = .preview
    var previews: [FakePreview] = []
    var editors: [FakeEditor] = []
}

@MainActor
final class Harness {
    let capture: FakeCaptureService
    let output: FakeOutput
    let presenter: FakePresenter
    let editorBox: EditorBox
    let coordinator: Coordinator
    var afterCapture: AfterCapture = .preview

    init() {
        let capture = FakeCaptureService()
        let output = FakeOutput()
        let presenter = FakePresenter()
        let box = EditorBox()
        self.capture = capture
        self.output = output
        self.presenter = presenter
        self.editorBox = box
        self.coordinator = Coordinator(
            captureService: capture,
            output: output,
            makePreview: { shot in
                let preview = FakePreview(shot: shot)
                box.previews.append(preview)
                return preview
            },
            makeEditor: { document in
                let editor = FakeEditor(document: document)
                box.editors.append(editor)
                return editor
            },
            presenter: presenter,
            afterCapture: { [unowned box] in box.afterCapture },
            // Never called: no test opens settings.
            makeSettings: { SettingsWindowController(preferences: Preferences()) }
        )
    }

    func runCapture() async {
        coordinator.capture(.area)
        await coordinator.inFlight?.value
    }

    func showPreview() async throws -> FakePreview {
        await runCapture()
        return try XCTUnwrap(editorBox.previews.last)
    }

    func openEditor() async throws -> FakeEditor {
        let preview = try await showPreview()
        preview.onFinish?(.edit)
        return try XCTUnwrap(editorBox.editors.last)
    }
}

func makeTestShot(frame: CGRect = CGRect(x: 0, y: 0, width: 20, height: 15), scale: CGFloat = 2) -> Shot {
    let width = Int((frame.width * scale).rounded())
    let height = Int((frame.height * scale).rounded())
    let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
            | CGBitmapInfo.byteOrder32Little.rawValue
    )!
    context.setFillColor(CGColor(srgbRed: 0.2, green: 0.2, blue: 0.2, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    return Shot(
        image: context.makeImage()!,
        scale: scale,
        frame: frame
    )
}
