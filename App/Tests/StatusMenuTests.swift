import AppKit
import XCTest
@testable import Snimach

@MainActor
final class StatusMenuTests: XCTestCase {
    private func makeMenu() -> StatusMenu {
        let harness = Harness()
        return StatusMenu(coordinator: harness.coordinator)
    }

    func testCaptureRowsCarryIconsAndStandardRowsDoNot() {
        let items = makeMenu().menu.items.filter { !$0.isSeparatorItem }
        for (title, icon) in [
            ("Capture Area", "crop-linear"),
            ("Capture Window", "window-frame-linear"),
            ("Capture Screen", "monitor-linear"),
        ] {
            let item = items.first { $0.title == title }
            XCTAssertNotNil(item?.image, "\(title) needs an icon")
            XCTAssertEqual(item?.image?.accessibilityDescription, icon, "\(title) shows the wrong icon")
        }
        for title in ["Settings…", "About Snimach", "Quit Snimach"] {
            let item = items.first { $0.title == title }
            XCTAssertNil(item?.image, "\(title) stays text-only")
        }
    }

    func testMenuHoldsCapturesSettingsAboutAndQuit() {
        let titles = makeMenu().menu.items.map { $0.title }
        XCTAssertTrue(titles.contains("Capture Area"))
        XCTAssertTrue(titles.contains("Capture Window"))
        XCTAssertTrue(titles.contains("Capture Screen"))
        XCTAssertTrue(titles.contains("Settings…"))
        XCTAssertTrue(titles.contains("About Snimach"))
        XCTAssertTrue(titles.contains("Quit Snimach"))
    }

    func testCheckForUpdatesShowsOnlyWithAnUpdater() {
        let harness = Harness()
        let without = StatusMenu(coordinator: harness.coordinator).menu.items.map { $0.title }
        XCTAssertFalse(without.contains("Check for Updates…"), "no feed, no item")

        var checked = false
        let menu = StatusMenu(coordinator: harness.coordinator, checkForUpdates: { checked = true })
        let item = menu.menu.items.first { $0.title == "Check for Updates…" }
        XCTAssertNotNil(item)
        XCTAssertNil(item?.image, "Check for Updates stays text-only")
        _ = item?.target?.perform(item?.action)
        XCTAssertTrue(checked)
    }

    func testLaunchAtLoginStaysOutOfTheMenu() {
        let titles = makeMenu().menu.items.map { $0.title }
        XCTAssertFalse(titles.contains("Launch at Login"), "launch toggle lives in Settings")
    }

    func testFixedShortcutsShowKeysAndCapturesDoNot() {
        let items = makeMenu().menu.items.filter { !$0.isSeparatorItem }
        func key(_ title: String) -> String? {
            items.first { $0.title == title }?.keyEquivalent
        }
        XCTAssertEqual(key("Settings…"), ",")
        XCTAssertEqual(key("Quit Snimach"), "q")
        XCTAssertEqual(key("Capture Area"), "")
        XCTAssertEqual(key("Capture Window"), "")
        XCTAssertEqual(key("Capture Screen"), "")
    }
}
