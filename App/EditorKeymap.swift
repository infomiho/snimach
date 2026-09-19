import AppKit

enum EditorKey: Equatable {
    case selectArrow
    case selectNumber
    case selectRectangle
    case selectRedact
    case togglePicker
    case cycleBackdrop
    case undo
    case redo
    case commit
    case save
    case discard
    case copyHex
}

/// Pure key table. The view forwards blindly because `Document.apply` never throws.
enum EditorKeymap {
    static func key(forKeyCode keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> EditorKey? {
        let flags = modifiers.intersection([.command, .shift, .option, .control])
        switch (keyCode, flags) {
        case (53, []):              return .discard
        case (36, []), (76, []):    return .commit
        case (8, .command):         return .commit
        case (1, .command):         return .save
        case (6, .command):         return .undo
        case (6, [.command, .shift]): return .redo
        case (0, []):               return .selectArrow
        case (45, []):              return .selectNumber
        case (15, []):              return .selectRectangle
        case (11, []):              return .selectRedact
        case (34, []):              return .togglePicker
        case (40, []):              return .cycleBackdrop
        default:                    return nil
        }
    }
}
