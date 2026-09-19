import CoreGraphics
import Foundation

/// Editor backdrop mode, toggled with K. Transparent is the default: export equals shot pixels.
public enum BackdropMode: String, CaseIterable, Equatable, Sendable {
    case transparent
    case solid

    /// Toggles transparent to solid and back, for the K key.
    public var next: BackdropMode {
        self == .transparent ? .solid : .transparent
    }
}

/// One gradient stop, as authored hex plus its position on the gradient line.
public struct BackdropStop: Equatable, Sendable {
    public let hex: String
    public let location: CGFloat

    public init(hex: String, location: CGFloat) {
        self.hex = hex
        self.location = location
    }

    public var color: CGColor {
        BackdropPreset.color(hex: hex)
    }
}

public enum BackdropPresetID: String, CaseIterable, Equatable, Sendable {
    case gotham
    case arendelle
    case minimal4
    case heather6
    case sierra10
    case sierra7
    case wetlands9
    case sierraMist
    case islandWaves
    case twilight10
    case quartz8
}

/// The 11 shipped backdrop looks. Gotham, Arendelle, Sierra Mist and Island Waves are exact
/// Hypercolor stops (MIT, see ATTRIBUTION.md). The rest are k-means palettes sampled from
/// backdrop.love previews as inspiration and recreated as plain CSS, never the photos.
public struct BackdropPreset: Equatable, Sendable {
    public let id: BackdropPresetID
    public let name: String
    public let stops: [BackdropStop]

    public static func preset(_ id: BackdropPresetID) -> BackdropPreset {
        all[id]!
    }

    /// Shipped order, for the editor's preset strip.
    public static let ordered: [BackdropPreset] = BackdropPresetID.allCases.map { preset($0) }

    public static let all: [BackdropPresetID: BackdropPreset] = [
        .gotham: BackdropPreset(id: .gotham, name: "Gotham", stops: [
            BackdropStop(hex: "#374151", location: 0),
            BackdropStop(hex: "#111827", location: 0.55),
            BackdropStop(hex: "#000000", location: 1),
        ]),
        .arendelle: BackdropPreset(id: .arendelle, name: "Arendelle", stops: [
            BackdropStop(hex: "#dbeafe", location: 0),
            BackdropStop(hex: "#93c5fd", location: 0.55),
            BackdropStop(hex: "#3b82f6", location: 1),
        ]),
        .minimal4: BackdropPreset(id: .minimal4, name: "Minimal 4", stops: [
            BackdropStop(hex: "#e7e6e6", location: 0),
            BackdropStop(hex: "#cac8c4", location: 0.55),
            BackdropStop(hex: "#c1bdb8", location: 1),
        ]),
        .heather6: BackdropPreset(id: .heather6, name: "Heather 6", stops: [
            BackdropStop(hex: "#5f719b", location: 0),
            BackdropStop(hex: "#557132", location: 0.55),
            BackdropStop(hex: "#103211", location: 1),
        ]),
        .sierra10: BackdropPreset(id: .sierra10, name: "Sierra 10", stops: [
            BackdropStop(hex: "#b6d0e7", location: 0),
            BackdropStop(hex: "#655851", location: 0.55),
            BackdropStop(hex: "#363a37", location: 1),
        ]),
        .sierra7: BackdropPreset(id: .sierra7, name: "Sierra 7", stops: [
            BackdropStop(hex: "#d0e2ec", location: 0),
            BackdropStop(hex: "#557189", location: 0.55),
            BackdropStop(hex: "#2d5874", location: 1),
        ]),
        .wetlands9: BackdropPreset(id: .wetlands9, name: "Wetlands 9", stops: [
            BackdropStop(hex: "#cdd3d0", location: 0),
            BackdropStop(hex: "#97915c", location: 0.55),
            BackdropStop(hex: "#252d0d", location: 1),
        ]),
        .sierraMist: BackdropPreset(id: .sierraMist, name: "Sierra Mist", stops: [
            BackdropStop(hex: "#fef08a", location: 0),
            BackdropStop(hex: "#bbf7d0", location: 0.55),
            BackdropStop(hex: "#86efac", location: 1),
        ]),
        .islandWaves: BackdropPreset(id: .islandWaves, name: "Island Waves", stops: [
            BackdropStop(hex: "#facc15", location: 0),
            BackdropStop(hex: "#f9fafb", location: 0.55),
            BackdropStop(hex: "#5eead4", location: 1),
        ]),
        .twilight10: BackdropPreset(id: .twilight10, name: "Twilight 10", stops: [
            BackdropStop(hex: "#dccebc", location: 0),
            BackdropStop(hex: "#625e4e", location: 0.55),
            BackdropStop(hex: "#0e1510", location: 1),
        ]),
        .quartz8: BackdropPreset(id: .quartz8, name: "Quartz 8", stops: [
            BackdropStop(hex: "#e1e7ed", location: 0),
            BackdropStop(hex: "#c9d6e1", location: 0.55),
            BackdropStop(hex: "#acbecc", location: 1),
        ]),
    ]

    static func color(hex: String) -> CGColor {
        var value = hex
        if value.hasPrefix("#") { value.removeFirst() }
        let scanner = Scanner(string: value)
        var number: UInt64 = 0
        scanner.scanHexInt64(&number)
        return CGColor(
            srgbRed: CGFloat((number >> 16) & 0xFF) / 255,
            green: CGFloat((number >> 8) & 0xFF) / 255,
            blue: CGFloat(number & 0xFF) / 255,
            alpha: 1
        )
    }
}
