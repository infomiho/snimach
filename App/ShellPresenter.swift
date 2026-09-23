import AppKit
import SnimachCore

/// The real presenter: system alerts for permission and errors, a fading HUD for saves.
@MainActor
final class ShellPresenter: CoordinatorPresenter {
    func showPermission(_ state: PermissionState) {
        PermissionAlert.run(state: state)
    }

    func showError(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Snimach"
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    func showSaved(_ url: URL, near shot: CGRect) {
        HUD.flash("Saved \(url.lastPathComponent)", on: NSScreen.nearest(shot)) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }
}
