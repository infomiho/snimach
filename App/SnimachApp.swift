import AppKit
import SnimachCore

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var coordinator: Coordinator?
    private var statusMenu: StatusMenu?
    private var hotkeys: Hotkeys?
    private var updater: Updater?

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard NSClassFromString("XCTestCase") == nil else { return }

        MainMenu.install()
        let preferences = Preferences()
        let updater = Updater()
        self.updater = updater
        let capturer = Capturer(includesPointer: { preferences.includesPointer })
        let output = ShotOutput(folder: { preferences.saveFolder })
        let coordinator = Coordinator(
            captureService: capturer,
            output: output,
            makePreview: { shot in
                PreviewWindowController(shot: shot, dragFile: {
                    try output.temporaryPNG(shot)
                }, hideManually: preferences.previewHide == .manual)
            },
            makeEditor: { AppDelegate.editorWindowController(document: $0, preferences: preferences) },
            presenter: ShellPresenter(),
            afterCapture: { preferences.afterCapture },
            makeSettings: { SettingsWindowController(preferences: preferences, updater: updater) }
        )
        self.coordinator = coordinator
        statusMenu = StatusMenu(coordinator: coordinator, checkForUpdates: updater.map { updater in
            { updater.checkForUpdates() }
        })
        hotkeys = Hotkeys(coordinator: coordinator)
    }

    @objc func showSettings() {
        Task { @MainActor in coordinator?.showSettings() }
    }

    @objc func showAbout() {
        Task { @MainActor in coordinator?.showAbout() }
    }
}

extension AppDelegate {
    /// Seeds a fresh capture with the backdrop prefs before the editor opens.
    @MainActor
    static func editorWindowController(document: Document, preferences: Preferences) -> EditorWindowController {
        var seeded = document
        seeded.apply(.backdropSelected(preferences.backdrop))
        seeded.apply(.backdropPresetSelected(preferences.backdropPreset))
        return EditorWindowController(document: seeded)
    }
}
