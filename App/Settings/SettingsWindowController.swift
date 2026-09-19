import AppKit
import SwiftUI

/// An LSUIElement app cannot reliably take focus on Sonoma, so the window switches the app to
/// `.regular` while it is open and back to `.accessory` when it closes.
@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let launchAtLogin = LaunchAtLoginModel()
    private let selection = SettingsSelection()

    init(preferences: Preferences) {
        let model = launchAtLogin
        let hosting = NSHostingController(
            rootView: SettingsView(launchAtLogin: model, preferences: preferences, selection: selection)
        )
        let window = NSWindow(contentViewController: hosting)
        window.title = "Snimach Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        window.center()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func show(tab: SettingsTab = .app) {
        // The window outlives one visit, so the login item status is re-read on every open.
        launchAtLogin.refresh()
        selection.tab = tab
        NSApp.setActivationPolicy(.regular)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        // Plain `activate()` often leaves an LSUIElement app behind the current one.
        // Activating via the running application steals key focus reliably.
        NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps])
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
