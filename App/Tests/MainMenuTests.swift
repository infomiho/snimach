import AppKit
import XCTest
@testable import Snimach

final class MainMenuTests: XCTestCase {
    private func items(_ menu: NSMenu) -> [NSMenuItem] {
        menu.items.flatMap { $0.submenu?.items ?? [] }
    }

    func testCloseWindowHasCommandW() {
        let found = items(MainMenu.make()).first {
            $0.action == #selector(NSWindow.performClose(_:))
        }
        XCTAssertNotNil(found, "needs a Close Window item or Cmd+W stays dead")
        XCTAssertEqual(found?.keyEquivalent, "w")
    }

    func testQuitHasCommandQ() {
        let found = items(MainMenu.make()).first {
            $0.action == #selector(NSApplication.terminate(_:))
        }
        XCTAssertNotNil(found, "needs a Quit item or Cmd+Q stays dead")
        XCTAssertEqual(found?.keyEquivalent, "q")
    }
}
