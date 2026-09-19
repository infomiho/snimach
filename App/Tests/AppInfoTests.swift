import XCTest
@testable import Snimach

final class AppInfoTests: XCTestCase {
    func testBundleMetadataIsFilledIn() {
        XCTAssertEqual(AppInfo.name, "Snimach")
        XCTAssertFalse(AppInfo.shortVersion.isEmpty, "CFBundleShortVersionString must be set")
        XCTAssertFalse(AppInfo.build.isEmpty, "CFBundleVersion must be set")
        XCTAssertFalse(AppInfo.copyright.isEmpty, "NSHumanReadableCopyright must be set")
    }

    func testVersionReadsAsMarketingVersionAndBuild() {
        XCTAssertEqual(AppInfo.version, "Version \(AppInfo.shortVersion) (\(AppInfo.build))")
    }
}
