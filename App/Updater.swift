import Foundation
import Sparkle

/// In-app updates through Sparkle. The feed comes from `SUFeedURL` in `Info.plist`, which
/// Debug and ad-hoc builds leave empty, so the updater only runs in signed releases.
@MainActor
final class Updater {
    private let controller: SPUStandardUpdaterController

    /// `nil` when the bundle carries no feed, so callers can leave the menu item out.
    init?(bundle: Bundle = .main) {
        guard let feed = bundle.object(forInfoDictionaryKey: "SUFeedURL") as? String,
              !feed.isEmpty else {
            return nil
        }
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
