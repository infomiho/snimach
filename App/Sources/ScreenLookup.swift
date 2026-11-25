import AppKit

extension NSScreen {
    /// The screen a global-point rect lives on, falling back to the main screen.
    static func nearest(_ rect: CGRect) -> NSScreen? {
        screens.first { $0.frame.intersects(rect) } ?? main
    }
}
