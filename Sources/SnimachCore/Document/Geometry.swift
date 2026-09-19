import CoreGraphics

/// An arrow drawn from `from` to `to`. The shaft stops at the base of the head so the round
/// cap never pokes through the tip.
struct ArrowShape {
    let shaftEnd: CGPoint
    let tip: CGPoint
    let left: CGPoint
    let right: CGPoint
}

enum Geometry {
    /// The rect two drag points span, whichever way the drag ran.
    static func rect(from origin: CGPoint, to tip: CGPoint) -> CGRect {
        CGRect(
            x: min(origin.x, tip.x),
            y: min(origin.y, tip.y),
            width: abs(tip.x - origin.x),
            height: abs(tip.y - origin.y)
        )
    }

    static func arrowShape(from: CGPoint, to: CGPoint, headLength: CGFloat,
                           headHalfAngle: CGFloat) -> ArrowShape? {
        let dx = to.x - from.x
        let dy = to.y - from.y
        let length = hypot(dx, dy)
        guard length > 0 else { return nil }

        let angle = atan2(dy, dx)
        let head = min(headLength, length)
        let base = CGPoint(x: to.x - cos(angle) * head, y: to.y - sin(angle) * head)
        let halfWidth = head * tan(headHalfAngle)

        return ArrowShape(
            shaftEnd: base,
            tip: to,
            left: CGPoint(x: base.x - sin(angle) * halfWidth, y: base.y + cos(angle) * halfWidth),
            right: CGPoint(x: base.x + sin(angle) * halfWidth, y: base.y - cos(angle) * halfWidth)
        )
    }
}
