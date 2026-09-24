import Foundation
import Sparkle

/// What Sparkle last reported, as the Updates section in Settings shows it.
enum UpdateCheck: Equatable {
    case notChecked(lastChecked: Date?)
    case upToDate
    case available(version: String)
    case skipped(version: String)

    var summary: String {
        switch self {
        case .notChecked(nil):
            return "Not checked yet."
        case .notChecked(let date?):
            let when = date.formatted(.relative(presentation: .named))
            return "Last checked \(when)."
        case .upToDate:
            return "Up to date."
        case .available(let version):
            return "Snimach \(version) is ready to install."
        case .skipped(let version):
            return "Version \(version) skipped."
        }
    }

    var actionTitle: String {
        if case .available = self { return "Install Update…" }
        return "Check for Updates…"
    }

    var isAvailable: Bool {
        if case .available = self { return true }
        return false
    }
}

/// In-app updates through Sparkle. The feed comes from `SUFeedURL` in `Info.plist`, which
/// Debug and ad-hoc builds leave empty, so the updater only runs in signed releases.
/// The update windows are Sparkle's own. As its delegate this mirrors what Sparkle found
/// into `check` so Settings can show it.
@MainActor
final class Updater: NSObject, ObservableObject {
    @Published private(set) var check: UpdateCheck = .notChecked(lastChecked: nil)

    private var controller: SPUStandardUpdaterController!

    /// `nil` when the bundle carries no feed, so callers can leave the update UI out.
    init?(bundle: Bundle = .main) {
        guard let feed = bundle.object(forInfoDictionaryKey: "SUFeedURL") as? String,
              !feed.isEmpty else {
            return nil
        }
        super.init()
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: self, userDriverDelegate: nil)
        check = .notChecked(lastChecked: controller.updater.lastUpdateCheckDate)
    }

    /// Sparkle persists the choice in the app's defaults.
    var automaticallyChecks: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set {
            objectWillChange.send()
            controller.updater.automaticallyChecksForUpdates = newValue
        }
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}

extension Updater: SPUUpdaterDelegate {
    nonisolated func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        let version = item.displayVersionString
        MainActor.assumeIsolated { check = .available(version: version) }
    }

    nonisolated func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        MainActor.assumeIsolated { check = .upToDate }
    }

    nonisolated func updater(
        _ updater: SPUUpdater,
        userDidMake choice: SPUUserUpdateChoice,
        forUpdate updateItem: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        guard choice == .skip else { return }
        let version = updateItem.displayVersionString
        MainActor.assumeIsolated { check = .skipped(version: version) }
    }
}
