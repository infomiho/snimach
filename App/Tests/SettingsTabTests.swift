import XCTest
@testable import Snimach

final class SettingsTabTests: XCTestCase {
    func testEveryTabIconIsVendored() {
        for tab in SettingsTab.allCases {
            XCTAssertNotNil(BundledIcon.image(tab.icon), "\(tab.icon).pdf is missing from App/Resources/Icons")
        }
    }
}
