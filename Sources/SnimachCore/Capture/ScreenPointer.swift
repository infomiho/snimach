import AppKit

/// The pointer in CG points, y-down from the primary display's top left, the space the capture
/// backend works in.
enum ScreenPointer {
    static func current() -> CGPoint {
        let appKit = NSEvent.mouseLocation
        let mainHeight = NSScreen.screens.first?.frame.height ?? 0
        return CGPoint(x: appKit.x, y: mainHeight - appKit.y)
    }
}
