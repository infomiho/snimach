import CoreGraphics

/// The area-selection drag as a value: the anchor where the mouse went down and the tip it has
/// moved to, both kept inside one display so the band stops at its edge.
struct RubberBand: Equatable {
    private(set) var origin: CGPoint
    private(set) var tip: CGPoint
    let bounds: CGRect
    /// Shift held: the band is a square along the longer side of the drag. Toggling it reshapes
    /// the band at once, without waiting for the pointer to move.
    var isSquare = false {
        didSet { if isSquare != oldValue { drag(to: lastPoint) } }
    }
    /// Space held: the pointer slides the whole band instead of resizing it.
    var isMoving = false
    private var lastPoint: CGPoint

    /// The origin is clamped too: at the top edge the pointer reports `bounds.maxY` itself.
    init(origin: CGPoint, bounds: CGRect) {
        self.bounds = bounds
        let start = Self.clamp(origin, to: bounds)
        self.origin = start
        self.tip = start
        self.lastPoint = start
    }

    var rect: CGRect {
        CGRect(
            x: min(origin.x, tip.x),
            y: min(origin.y, tip.y),
            width: abs(tip.x - origin.x),
            height: abs(tip.y - origin.y)
        )
    }

    mutating func drag(to point: CGPoint) {
        defer { lastPoint = point }
        if isMoving {
            slide(by: CGVector(dx: point.x - lastPoint.x, dy: point.y - lastPoint.y))
        } else {
            let target = Self.clamp(point, to: bounds)
            tip = isSquare ? squared(target) : target
        }
    }

    private mutating func slide(by delta: CGVector) {
        let current = rect
        let dx = min(max(delta.dx, bounds.minX - current.minX), bounds.maxX - current.maxX)
        let dy = min(max(delta.dy, bounds.minY - current.minY), bounds.maxY - current.maxY)
        origin = CGPoint(x: origin.x + dx, y: origin.y + dy)
        tip = CGPoint(x: tip.x + dx, y: tip.y + dy)
    }

    /// The square keeps the drag's direction and shrinks to the room left on the display.
    private func squared(_ target: CGPoint) -> CGPoint {
        let dx = target.x - origin.x
        let dy = target.y - origin.y
        let signX: CGFloat = dx < 0 ? -1 : 1
        let signY: CGFloat = dy < 0 ? -1 : 1
        let roomX = signX < 0 ? origin.x - bounds.minX : bounds.maxX - origin.x
        let roomY = signY < 0 ? origin.y - bounds.minY : bounds.maxY - origin.y
        let side = min(max(abs(dx), abs(dy)), roomX, roomY)
        return CGPoint(x: origin.x + signX * side, y: origin.y + signY * side)
    }

    private static func clamp(_ point: CGPoint, to bounds: CGRect) -> CGPoint {
        CGPoint(
            x: min(max(point.x, bounds.minX), bounds.maxX),
            y: min(max(point.y, bounds.minY), bounds.maxY)
        )
    }
}
