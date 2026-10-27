import AppKit

enum EditorKey: Equatable {
    case select
    case deleteSelection
    case nudge(CGSize)
    case selectText
    case selectLine
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
        case (17, []):              return .selectText
        case (37, []):              return .selectLine
        case (9, []):               return .select
        case (51, []), (117, []):   return .deleteSelection
        case (123...126, []) , (123...126, .shift):
            let step: CGFloat = flags.contains(.shift) ? 10 : 1
            switch keyCode {
            case 123: return .nudge(CGSize(width: -step, height: 0))
            case 124: return .nudge(CGSize(width: step, height: 0))
            case 125: return .nudge(CGSize(width: 0, height: -step))
            default: return .nudge(CGSize(width: 0, height: step))
            }
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
