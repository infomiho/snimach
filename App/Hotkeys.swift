import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let captureArea = Self("captureArea", initial: .init(.a, modifiers: [.command, .shift]))
    static let captureWindow = Self("captureWindow", initial: .init(.w, modifiers: [.command, .shift]))
    // E for entire screen. Cmd+Shift+S would shadow Save As in every app.
    static let captureScreen = Self("captureScreen", initial: .init(.e, modifiers: [.command, .shift]))
}

/// One stream per shortcut, owned by the app and cancelled on quit.
@MainActor
final class Hotkeys {
    private var tasks: [Task<Void, Never>] = []

    init(coordinator: Coordinator) {
        tasks.append(Task { [weak coordinator] in
            for await event in KeyboardShortcuts.events(for: .captureArea) where event == .keyUp {
                coordinator?.capture(.area)
            }
        })
        tasks.append(Task { [weak coordinator] in
            for await event in KeyboardShortcuts.events(for: .captureWindow) where event == .keyUp {
                coordinator?.capture(.activeWindow())
            }
        })
        tasks.append(Task { [weak coordinator] in
            for await event in KeyboardShortcuts.events(for: .captureScreen) where event == .keyUp {
                coordinator?.capture(.fullScreen)
            }
        })
    }

    deinit {
        tasks.forEach { $0.cancel() }
    }
}
