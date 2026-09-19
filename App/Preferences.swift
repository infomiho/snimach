import Foundation
import SnimachCore

/// What happens once a shot is on the clipboard.
enum AfterCapture: String, CaseIterable, Identifiable {
    /// Show the preview card, which opens the editor on click.
    case preview
    /// Open the editor straight away.
    case editor
    /// Nothing. The shot is already copied.
    case clipboardOnly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .preview: return "Show the preview card"
        case .editor: return "Open the editor"
        case .clipboardOnly: return "Just copy it"
        }
    }
}

/// How long the preview card stays on screen.
enum PreviewHide: String, CaseIterable, Identifiable {
    /// Fade out after 5 seconds, 2 seconds after hover ends.
    case auto
    /// Stay up until Open, Save, X, or the next capture.
    case manual

    var id: String { rawValue }

    var label: String {
        switch self {
        case .auto: return "Hide after 5s"
        case .manual: return "Hide manually"
        }
    }
}

/// The settings that genuinely differ between people. Everything visual stays fixed.
@MainActor
final class Preferences: ObservableObject {
    private enum Key {
        static let saveFolder = "dev.twoducks.snimach.saveFolder"
        static let afterCapture = "dev.twoducks.snimach.afterCapture"
        static let includesPointer = "dev.twoducks.snimach.includesPointer"
        static let previewHide = "dev.twoducks.snimach.previewHide"
        static let backdrop = "dev.twoducks.snimach.backdrop"
        static let backdropPreset = "dev.twoducks.snimach.backdropPreset"
    }

    private let defaults: UserDefaults

    @Published var saveFolder: URL {
        didSet { defaults.set(saveFolder.path, forKey: Key.saveFolder) }
    }

    @Published var afterCapture: AfterCapture {
        didSet { defaults.set(afterCapture.rawValue, forKey: Key.afterCapture) }
    }

    @Published var includesPointer: Bool {
        didSet { defaults.set(includesPointer, forKey: Key.includesPointer) }
    }

    @Published var previewHide: PreviewHide {
        didSet { defaults.set(previewHide.rawValue, forKey: Key.previewHide) }
    }

    @Published var backdrop: BackdropMode {
        didSet { defaults.set(backdrop.rawValue, forKey: Key.backdrop) }
    }

    @Published var backdropPreset: BackdropPreset {
        didSet { defaults.set(backdropPreset.id.rawValue, forKey: Key.backdropPreset) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.saveFolder = defaults.string(forKey: Key.saveFolder)
            .map { URL(fileURLWithPath: $0) } ?? ShotOutput.defaultFolder
        self.afterCapture = defaults.string(forKey: Key.afterCapture)
            .flatMap(AfterCapture.init(rawValue:)) ?? .preview
        self.includesPointer = defaults.bool(forKey: Key.includesPointer)
        self.previewHide = defaults.string(forKey: Key.previewHide)
            .flatMap(PreviewHide.init(rawValue:)) ?? .auto
        self.backdrop = defaults.string(forKey: Key.backdrop)
            .flatMap(BackdropMode.init(rawValue:)) ?? .transparent
        self.backdropPreset = defaults.string(forKey: Key.backdropPreset)
            .flatMap(BackdropPresetID.init(rawValue:))
            .map(BackdropPreset.preset) ?? BackdropPreset.preset(.gotham)
    }
}
