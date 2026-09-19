// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Snimach",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SnimachCore", targets: ["SnimachCore"]),
        .executable(name: "snimach-probe", targets: ["SnimachProbe"]),
    ],
    targets: [
        .target(
            name: "SnimachCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "SnimachProbe",
            dependencies: ["SnimachCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "SnimachCoreTests",
            dependencies: ["SnimachCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
