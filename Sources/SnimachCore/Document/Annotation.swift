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


extension Annotation {
    var bounds: CGRect {
        switch self {
        case .arrow(let from, let to):
            let shaft = Geometry.rect(from: from, to: to).insetBy(dx: -2, dy: -2)
            return shaft.union(arrowHead(from: from, to: to).boundingBoxOfPath)
        case .number(_, let center):
            let radius = Style.standard.badgeRadius
            return CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        case .redaction(let rect), .rectangle(let rect): return rect
        }
    }

    func translated(by offset: CGSize) -> Annotation {
        func moved(_ point: CGPoint) -> CGPoint {
            CGPoint(x: point.x + offset.width, y: point.y + offset.height)
        }
        switch self {
        case .arrow(let from, let to): return .arrow(from: moved(from), to: moved(to))
        case .number(let value, let center): return .number(value, center: moved(center))
        case .redaction(let rect): return .redaction(rect.offsetBy(dx: offset.width, dy: offset.height))
        case .rectangle(let rect): return .rectangle(rect.offsetBy(dx: offset.width, dy: offset.height))
        }
    }

    private func arrowHead(from: CGPoint, to: CGPoint) -> CGPath {
        let path = CGMutablePath()
        let style = Style.standard
        if let shape = Geometry.arrowShape(from: from, to: to, headLength: style.headLength,
                                           headHalfAngle: style.headHalfAngle) {
            path.move(to: shape.tip)
            path.addLine(to: shape.left)
            path.addLine(to: shape.right)
            path.closeSubpath()
        }
        return path
    }

    func contains(_ point: CGPoint) -> Bool {
        switch self {
        case .number(_, let center):
            return hypot(point.x - center.x, point.y - center.y) <= Style.standard.badgeRadius + 5
        case .redaction(let rect):
            return rect.contains(point)
        case .rectangle(let rect):
            return rect.insetBy(dx: -5, dy: -5).contains(point)
                && !rect.insetBy(dx: 5, dy: 5).contains(point)
        case .arrow(let from, let to):
            if arrowHead(from: from, to: to).contains(point) { return true }
            let dx = to.x - from.x
            let dy = to.y - from.y
            let lengthSquared = dx * dx + dy * dy
            guard lengthSquared > 0 else { return false }
            let projection = ((point.x - from.x) * dx + (point.y - from.y) * dy) / lengthSquared
            let fraction = min(1, max(0, projection))
            return hypot(point.x - from.x - fraction * dx, point.y - from.y - fraction * dy) <= 6
        }
    }
}
