import AppKit
import SnimachCore

/// Renders `CaptureError.permission` states. The shell never touches the CG permission calls.
@MainActor
enum PermissionAlert {
    static func run(state: PermissionState) {
        // .granted needs nothing. .notDetermined means the system prompt is on screen,
        // which is dialog enough, so both stay silent.
        guard state == .denied || state == .grantedNeedsRelaunch else { return }

        let alert = NSAlert()
        alert.messageText = "Snimach needs Screen Recording permission"
        switch state {
        case .denied:
            alert.informativeText = "Enable Snimach under Privacy & Security > Screen & System Audio Recording."
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Cancel")
        case .grantedNeedsRelaunch:
            alert.informativeText = "Permission was granted. Relaunch Snimach to start capturing."
            alert.addButton(withTitle: "Relaunch")
            alert.addButton(withTitle: "Later")
        case .granted, .notDetermined:
            return
        }

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        if state == .grantedNeedsRelaunch {
            relaunch()
        } else {
            NSWorkspace.shared.open(Capturer.settingsURL)
        }
    }

    private static func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(
            at: Bundle.main.bundleURL,
            configuration: configuration
        ) { _, error in
            // Only quit after the new instance is up. Terminating unconditionally strands
            // the user with no app running when the open fails.
            guard error == nil else { return }
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }
}
