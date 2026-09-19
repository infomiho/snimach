import SnimachCore
import XCTest
@testable import Snimach

@MainActor
final class PreferencesTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suite: String!

    override func setUpWithError() throws {
        suite = "snimach-prefs-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suite)
    }

    func testDefaultsMatchTheShippedBehaviour() {
        let prefs = Preferences(defaults: defaults)
        XCTAssertEqual(prefs.afterCapture, .preview)
        XCTAssertFalse(prefs.includesPointer)
        XCTAssertEqual(prefs.previewHide, .auto)
        XCTAssertEqual(prefs.backdrop, .transparent)
        XCTAssertEqual(prefs.backdropPreset.id, .gotham)
        XCTAssertEqual(prefs.saveFolder.lastPathComponent, "Snimach")
    }

    func testEveryChangeSurvivesARelaunch() {
        let prefs = Preferences(defaults: defaults)
        let folder = URL(fileURLWithPath: "/tmp/snimach-elsewhere")
        prefs.saveFolder = folder
        prefs.afterCapture = .editor
        prefs.includesPointer = true
        prefs.previewHide = .manual
        prefs.backdrop = .solid
        prefs.backdropPreset = BackdropPreset.preset(.arendelle)

        let reloaded = Preferences(defaults: defaults)
        XCTAssertEqual(reloaded.saveFolder, folder)
        XCTAssertEqual(reloaded.afterCapture, .editor)
        XCTAssertTrue(reloaded.includesPointer)
        XCTAssertEqual(reloaded.previewHide, .manual)
        XCTAssertEqual(reloaded.backdrop, .solid)
        XCTAssertEqual(reloaded.backdropPreset.id, .arendelle)
    }
}
