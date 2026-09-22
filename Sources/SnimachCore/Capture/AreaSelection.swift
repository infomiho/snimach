import CoreGraphics

/// The area-selection drag as a decision: pointer events in AppKit global points, the accepted
/// region out in CG points.
struct AreaSelection {
    /// A drag must cover this much on both axes to be a region rather than an accident. The
    /// seam's contract: `release()` only ever hands back a region that passed this check.
    private static let minimumSize: CGFloat = 2

    private let mainDisplayHeight: CGFloat
    private let windows: [CGRect]
    private var band: RubberBand?
    private var hovered: CGRect?

    init(mainDisplayHeight: CGFloat, pickableWindows: [CGRect]) {
        self.mainDisplayHeight = mainDisplayHeight
        self.windows = pickableWindows.map {
            CaptureGeometry.appKitFrame($0, mainDisplayHeight: mainDisplayHeight)
        }
    }

    mutating func press(at point: CGPoint, within displayBounds: CGRect, shiftHeld: Bool) {
        var band = RubberBand(origin: point, bounds: displayBounds)
        band.isSquare = shiftHeld
        self.band = band
    }

    mutating func drag(to point: CGPoint) {
        band?.drag(to: point)
    }

    /// The pointer moved before any drag. The frontmost window under it is the pick candidate.
    mutating func pointerMoved(to point: CGPoint) {
        guard band == nil else { return }
        hovered = CaptureGeometry.frontmostWindow(containing: point, in: windows)
    }

    /// A drag this long on either axis reads as a deliberate region rather than an accidental
    /// click, so the band takes over the highlight from the hovered window.
    private static let bandDisplayThreshold: CGFloat = 3

    var isDragging: Bool {
        guard let rect = band?.rect else { return false }
        return rect.width >= Self.bandDisplayThreshold || rect.height >= Self.bandDisplayThreshold
    }

    /// The region to lift out of the dim, in AppKit global points: the band once it reads as a
    /// region, otherwise the hovered window if there is one.
    var highlight: CGRect? { isDragging ? band?.rect : (hovered ?? band?.rect) }

    /// True when the highlight is the hovered window rather than a dragged region.
    var isPickHighlight: Bool { !isDragging && hovered != nil }

    /// Whether a press has started a drag. Backgrounding the app cancels only mid-drag,
    /// because activating the overlay itself fires the notification.
    var hasDragUnderway: Bool { band != nil }

    mutating func setShiftHeld(_ isOn: Bool) { band?.isSquare = isOn }

    mutating func setSpaceHeld(_ isOn: Bool) { band?.isMoving = isOn }

    /// The accepted region in CG points, or nil when the user made no selection: a drag too
    /// small falls back to the window hovered before the press.
    func release() -> CGRect? {
        if let rect = band?.rect,
           rect.width >= Self.minimumSize, rect.height >= Self.minimumSize {
            return CaptureGeometry.appKitFrame(rect, mainDisplayHeight: mainDisplayHeight)
        }
        guard let hovered else { return nil }
        return CaptureGeometry.appKitFrame(hovered, mainDisplayHeight: mainDisplayHeight)
    }
}
