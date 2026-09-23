import CoreGraphics

struct DisplayInfo: Sendable, Equatable {
    let id: CGDirectDisplayID
    /// CG points, y-down from the main display's top-left.
    let frame: CGRect
    let scale: CGFloat
}

struct WindowInfo: Sendable, Equatable {
    let id: CGWindowID
    let pid: pid_t
    let layer: Int
    let alpha: CGFloat
    /// CG points, y-down from the main display's top-left.
    let frame: CGRect
}

/// A display's pixels as they were when the hotkey fired. The overlay shows them and the area
/// shot is cropped from them, so nothing that changes on screen after the hotkey (a hover state
/// lost to the overlay, a tooltip closing) can leak into the result.
struct FrozenDisplay: Sendable {
    let display: DisplayInfo
    let image: CGImage
}

enum BackendError: Error, Equatable {
    case permissionDenied
}

/// The seam that hides ScreenCaptureKit and the two CG permission calls. The only production
/// adapter is `ScreenCaptureKitBackend`, so tests substitute `FakeCaptureBackend` wholesale.
protocol CaptureBackend: Sendable {
    func preflightPermission() -> Bool
    /// Shows the system prompt at most once and returns immediately.
    func requestPermission() -> Bool
    /// Throws `BackendError.permissionDenied` when TCC refuses or the display list is empty.
    func displays() async throws -> [DisplayInfo]
    /// Front-to-back, current Space, no permission needed for these fields.
    func onScreenWindowsFrontToBack() -> [WindowInfo]
    /// Captures `rect` (display-local points) at `scale`. When `only` is set the filter includes
    /// just those windows plus `excludingPID` is ignored. `keepShadows` keeps the system shadow,
    /// `showsCursor` draws the pointer into the image.
    func captureRegion(display: CGDirectDisplayID,
                       rect: CGRect,
                       scale: CGFloat,
                       only windows: [CGWindowID]?,
                       excludingPID: pid_t?,
                       keepShadows: Bool,
                       showsCursor: Bool) async throws -> CGImage
}

/// What the user accepted in the overlay.
enum AreaChoice: Equatable {
    /// A dragged region in CG points.
    case region(CGRect)
    /// The window at this index of the pickable frames handed to the selector.
    case window(Int)
}

/// The in-process AppKit selection UI. A separate seam because it blocks on a human.
@MainActor
protocol AreaSelector: AnyObject {
    /// Shows the frozen displays and returns what the user accepted: a drag of at least 2x2
    /// points clamped to the display it started on, or a window picked from `windows`
    /// (pickable frames in CG points, front to back) by a click with no drag. The only error is
    /// `CancellationError`: every no-selection outcome, including a too-small drag with nothing
    /// hovered, returns idle silently.
    func select(over displays: [FrozenDisplay], windows: [CGRect]) async throws -> AreaChoice
    /// Ends any in-flight selection with `CancellationError`. Called on task cancellation.
    func cancel()
}
