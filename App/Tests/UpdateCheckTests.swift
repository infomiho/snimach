import XCTest
@testable import Snimach

final class UpdateCheckTests: XCTestCase {
    func testSummaryNamesTheVersionSparkleFound() {
        XCTAssertEqual(UpdateCheck.available(version: "0.2.0").summary, "Snimach 0.2.0 is ready to install.")
        XCTAssertEqual(UpdateCheck.skipped(version: "0.2.0").summary, "Version 0.2.0 skipped.")
        XCTAssertEqual(UpdateCheck.upToDate.summary, "Up to date.")
    }

    func testNeverCheckedDiffersFromCheckedEarlier() {
        XCTAssertEqual(UpdateCheck.notChecked(lastChecked: nil).summary, "Not checked yet.")
        let earlier = UpdateCheck.notChecked(lastChecked: Date(timeIntervalSinceNow: -3600)).summary
        XCTAssertTrue(earlier.hasPrefix("Last checked "), earlier)
    }

    func testOnlyAnAvailableUpdateOffersToInstall() {
        XCTAssertEqual(UpdateCheck.available(version: "0.2.0").actionTitle, "Install Update…")
        for check in [UpdateCheck.upToDate, .skipped(version: "0.2.0"), .notChecked(lastChecked: nil)] {
            XCTAssertEqual(check.actionTitle, "Check for Updates…")
        }
    }
}
