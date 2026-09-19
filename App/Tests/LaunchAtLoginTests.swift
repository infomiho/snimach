import ServiceManagement
import XCTest
@testable import Snimach

final class FakeLoginItem: LoginItemControlling {
    var status: SMAppService.Status = .notRegistered
    var registerError: Error?
    var unregisterError: Error?
    private(set) var registerCount = 0
    private(set) var unregisterCount = 0

    func register() throws {
        registerCount += 1
        if let registerError { throw registerError }
        status = .enabled
    }

    func unregister() throws {
        unregisterCount += 1
        if let unregisterError { throw unregisterError }
        status = .notRegistered
    }
}

final class LaunchAtLoginTests: XCTestCase {
    func testIsEnabledReadsStatus() {
        let fake = FakeLoginItem()
        fake.status = .enabled
        XCTAssertTrue(LaunchAtLogin(service: fake).isEnabled)

        fake.status = .notRegistered
        XCTAssertFalse(LaunchAtLogin(service: fake).isEnabled)
    }

    func testRequiresApproval() {
        let fake = FakeLoginItem()
        fake.status = .requiresApproval
        XCTAssertTrue(LaunchAtLogin(service: fake).requiresApproval)
    }

    func testSetEnabledRegistersAndUnregisters() throws {
        let fake = FakeLoginItem()
        let login = LaunchAtLogin(service: fake)

        try login.setEnabled(true)
        XCTAssertEqual(fake.registerCount, 1)

        try login.setEnabled(false)
        XCTAssertEqual(fake.unregisterCount, 1)
    }
}
