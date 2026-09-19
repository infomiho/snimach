import Foundation

/// Bundle metadata, read once from `Info.plist`. The About pane is its only reader.
enum AppInfo {
    static var name: String { string("CFBundleName") ?? "Snimach" }
    static var shortVersion: String { string("CFBundleShortVersionString") ?? "" }
    static var build: String { string("CFBundleVersion") ?? "" }
    static var copyright: String { string("NSHumanReadableCopyright") ?? "" }

    static var version: String { "Version \(shortVersion) (\(build))" }

    private static func string(_ key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !value.isEmpty else {
            return nil
        }
        return value
    }
}
