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

@MainActor
enum HUD {
    private static var current: NSPanel?

    /// `screen` is the shot's screen. `NSScreen.main` follows keyboard focus, which on a second
    /// monitor is the wrong place entirely.
    static func flash(_ text: String, on screen: NSScreen? = nil, action: (() -> Void)? = nil) {
        current?.close()

        let font = NSFont.systemFont(ofSize: 13, weight: .medium)
        let textSize = (text as NSString).size(withAttributes: [.font: font])
        let textWidth = ceil(textSize.width)
        let horizontalPadding: CGFloat = 20
        let verticalPadding: CGFloat = 10
        let width = min(max(textWidth + horizontalPadding * 2, 180), 480)
        let height = ceil(textSize.height + verticalPadding * 2)

        let panel = NSPanel(
            contentRect: CGRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = action == nil
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]

        let label = NSTextField(labelWithString: text)
        label.font = font
        label.textColor = .white
        label.alignment = .center
        label.lineBreakMode = .byTruncatingMiddle
        label.translatesAutoresizingMaskIntoConstraints = false

        let background = HUDBackgroundView(frame: panel.contentView!.bounds)
        background.onClick = action
        background.wantsLayer = true
        background.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.8).cgColor
        background.layer?.cornerRadius = 12
        background.autoresizingMask = [.width, .height]
        background.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: horizontalPadding),
            label.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -horizontalPadding),
            label.centerYAnchor.constraint(equalTo: background.centerYAnchor),
        ])
        panel.contentView = background

        if let screen = screen ?? NSScreen.main {
            let origin = CGPoint(
                x: screen.frame.midX - panel.frame.width / 2,
                y: screen.frame.minY + 120
            )
            panel.setFrameOrigin(origin)
        }
        panel.orderFrontRegardless()
        current = panel

        Task { [weak panel] in
            // A clickable HUD needs long enough to actually be clicked.
            try? await Task.sleep(for: .seconds(action == nil ? 1.6 : 3.2))
            panel?.close()
            if current === panel { current = nil }
        }
    }
}

/// The HUD body. Clickable only when the flash was given somewhere to go, which today means
/// revealing the file that was just saved.
final class HUDBackgroundView: NSView {
    var onClick: (() -> Void)?

    override func resetCursorRects() {
        guard onClick != nil else { return }
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func mouseDown(with event: NSEvent) {
        guard let onClick else { return }
        onClick()
        window?.close()
    }
}
