import ServiceManagement
import XCTest
@testable import Snimach

@MainActor
final class LaunchAtLoginModelTests: XCTestCase {
    private func makeModel(_ fake: FakeLoginItem) -> LaunchAtLoginModel {
        LaunchAtLoginModel(launchAtLogin: LaunchAtLogin(service: fake))
    }

    func testRefreshPicksUpAChangeMadeInSystemSettings() {
        let fake = FakeLoginItem()
        fake.status = .notRegistered
        let model = makeModel(fake)
        XCTAssertFalse(model.isEnabled)

        fake.status = .enabled
        model.refresh()
        XCTAssertTrue(model.isEnabled)
    }

    func testApprovalNoticeClearsOnceApproved() {
        let fake = FakeLoginItem()
        fake.status = .requiresApproval
        let model = makeModel(fake)
        XCTAssertTrue(model.requiresApproval)

        fake.status = .enabled
        model.refresh()
        XCTAssertFalse(model.requiresApproval)
        XCTAssertTrue(model.isEnabled)
    }

    func testFailedRegisterIsReportedAndTheToggleStaysOff() {
        let fake = FakeLoginItem()
        fake.registerError = NSError(
            domain: "test", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Operation not permitted"]
        )
        let model = makeModel(fake)

        model.setEnabled(true)

        XCTAssertEqual(model.failure, "Operation not permitted")
        XCTAssertFalse(model.isEnabled, "nothing was registered, so the toggle must not read on")
    }

    func testSuccessfulToggleClearsAnEarlierFailure() {
        let fake = FakeLoginItem()
        fake.registerError = NSError(domain: "test", code: 1)
        let model = makeModel(fake)
        model.setEnabled(true)
        XCTAssertNotNil(model.failure)

        fake.registerError = nil
        model.setEnabled(true)
        XCTAssertNil(model.failure)
        XCTAssertTrue(model.isEnabled)
    }
}
