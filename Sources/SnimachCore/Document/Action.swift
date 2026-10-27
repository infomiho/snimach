import CoreGraphics

public enum Tool: Equatable {
    case select
    case line
    case arrow
    case number
    case redact
    case rectangle

    /// Tools whose gesture is a drag rather than a single click.
    var isDrag: Bool { self != .number }
}

/// Everything that can happen to a document. Pointer actions are tool-agnostic: the document
/// decides what a press, drag, or release means for the current tool.
public enum Action: Equatable {
    case toolSelected(Tool)
    case pointerDown(CGPoint)
    case pointerDragged(CGPoint)
    case pointerUp(CGPoint)
    /// Cmd held while drawing: the arrow points back at where the drag started.
    case arrowReversed(Bool)
    case angleConstrained(Bool)
    /// Backdrop mode or preset picked in the editor. Chrome, never undoable.
    case backdropSelected(BackdropMode)
    case backdropPresetSelected(BackdropPreset)
    case colorSelected(AnnotationColor)
    case deselect
    case nudgeSelection(CGSize)
    case deleteSelection
    case undo
    case redo
}
