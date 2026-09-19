import CoreGraphics

/// Committed annotation, in document points. Badge numbers are derived by the document
/// (1, 2, 3 by commit order among badges) and are always contiguous after undo and redo.
public enum Annotation: Equatable {
    case arrow(from: CGPoint, to: CGPoint)
    case number(Int, center: CGPoint)
    /// The area is replaced by a coarse average of the shot beneath it, so the original pixels
    /// are gone from the rendered image rather than merely covered.
    case redaction(CGRect)
    case rectangle(CGRect)
}
