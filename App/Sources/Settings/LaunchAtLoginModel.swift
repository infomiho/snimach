import Foundation

/// The user can change the login item in System Settings at any time, so the pane re-reads the
/// status every time it opens rather than trusting a snapshot taken at launch.
@MainActor
final class LaunchAtLoginModel: ObservableObject {
    @Published private(set) var isEnabled: Bool
    @Published private(set) var requiresApproval: Bool
    /// Set when the system refused to register or unregister, so the pane can say so.
    @Published private(set) var failure: String?

    private let launchAtLogin: LaunchAtLogin

    init(launchAtLogin: LaunchAtLogin = LaunchAtLogin()) {
        self.launchAtLogin = launchAtLogin
        self.isEnabled = launchAtLogin.isEnabled
        self.requiresApproval = launchAtLogin.requiresApproval
    }

    func refresh() {
        failure = nil
        readStatus()
    }

    func setEnabled(_ enabled: Bool) {
        do {
            try launchAtLogin.setEnabled(enabled)
            failure = nil
        } catch {
            failure = error.localizedDescription
        }
        // Report what the system actually did, not what was asked for.
        readStatus()
    }

    private func readStatus() {
        isEnabled = launchAtLogin.isEnabled
        requiresApproval = launchAtLogin.requiresApproval
    }
}
