import CoreGraphics
import CoreText

public enum RenderError: Error {
    case bitmapContextUnavailable
}

/// Owns annotations, the in-progress drag, undo/redo and rendering. A value type with no AppKit
/// dependency, so the canvas view and the export path are thin adapters over it.
public struct Document {
    public let shot: Shot
    public private(set) var tool: Tool
    public private(set) var annotations: [Annotation]
    public private(set) var backdrop: BackdropMode
    public private(set) var backdropPreset: BackdropPreset

    private var dragOrigin: CGPoint?
    private var dragTip: CGPoint?
    private var isArrowReversed = false
    private var undoStack: [[Annotation]] = []
    private var redoStack: [[Annotation]] = []

    public init(shot: Shot) {
        self.shot = shot
        self.tool = .arrow
        self.annotations = []
        self.backdrop = .transparent
        self.backdropPreset = BackdropPreset.preset(.gotham)
    }

    /// Size of the document in points. Equal to `shot.frame.size`.
    public var pointSize: CGSize { shot.frame.size }

    /// Size of the editor stage in points: the shot plus the backdrop pad.
    /// Equal to `pointSize` when the backdrop is off.
    public var stageSize: CGSize {
        guard backdrop != .transparent else { return pointSize }
        let pad = Style.backdrop.padding
        return CGSize(
            width: pointSize.width + pad * 2,
            height: pointSize.height + pad * 2
        )
    }

    /// Offset of the shot inside the stage, in points. Zero without a backdrop.
    public var stageOrigin: CGPoint {
        backdrop == .transparent
            ? .zero
            : CGPoint(x: Style.backdrop.padding, y: Style.backdrop.padding)
    }

    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }

    /// Total function: every action is valid in every state and never throws.
    public mutating func apply(_ action: Action) {
        switch action {
        case .toolSelected(let newTool):
            cancelDrag()
            tool = newTool

        case .pointerDown(let point):
            guard tool.isDrag else { return }
            dragOrigin = point
            dragTip = point

        case .pointerDragged(let point):
            guard dragOrigin != nil else { return }
            dragTip = point

        case .pointerUp(let point):
            switch tool {
            case .arrow:
                guard let origin = dragOrigin else { return }
                cancelDrag()
                if hypot(point.x - origin.x, point.y - origin.y) >= Style.standard.minimumArrowLength {
                    commit(arrow(from: origin, to: point))
                }
            case .number:
                commit(.number(badgeCount + 1, center: point))
            case .redact, .rectangle:
                guard let origin = dragOrigin else { return }
                let shape = tool
                cancelDrag()
                let rect = Geometry.rect(from: origin, to: point)
                if rect.width >= Style.standard.minimumShapeSide,
                   rect.height >= Style.standard.minimumShapeSide {
                    commit(shape == .redact ? .redaction(rect) : .rectangle(rect))
                }
            }

        case .arrowReversed(let reversed):
            isArrowReversed = reversed

        case .backdropSelected(let mode):
            backdrop = mode

        case .backdropPresetSelected(let preset):
            backdropPreset = preset

        case .undo:
            cancelDrag()
            guard let previous = undoStack.popLast() else { return }
            redoStack.append(annotations)
            annotations = previous

        case .redo:
            cancelDrag()
            guard let next = redoStack.popLast() else { return }
            undoStack.append(annotations)
            annotations = next
        }
    }

    private func preview(from origin: CGPoint, to tip: CGPoint) -> Annotation {
        switch tool {
        case .redact: return .redaction(Geometry.rect(from: origin, to: tip))
        case .rectangle: return .rectangle(Geometry.rect(from: origin, to: tip))
        case .arrow, .number: return arrow(from: origin, to: tip)
        }
    }

    private func arrow(from origin: CGPoint, to tip: CGPoint) -> Annotation {
        isArrowReversed ? .arrow(from: tip, to: origin) : .arrow(from: origin, to: tip)
    }

    private var badgeCount: Int {
        annotations.filter { if case .number = $0 { true } else { false } }.count
    }

    private mutating func commit(_ annotation: Annotation) {
        undoStack.append(annotations)
        annotations.append(annotation)
        redoStack.removeAll()
    }

    private mutating func cancelDrag() {
        dragOrigin = nil
        dragTip = nil
    }

    /// The single rendering path. Draws the base shot, committed annotations and the in-progress
    /// arrow preview. The caller must not draw the shot itself.
    public func draw(in context: CGContext, baseInterpolation: CGInterpolationQuality = .none) {
        context.saveGState()
        defer { context.restoreGState() }

        // The base is a bitmap at exactly 1:1. Never resample it: with default smoothing any
        // sub-pixel misalignment turns the whole preview soft instead of staying crisp.
        context.saveGState()
        context.interpolationQuality = baseInterpolation
        context.draw(shot.image, in: CGRect(origin: .zero, size: pointSize))
        context.restoreGState()

        for annotation in annotations {
            draw(annotation, in: context)
        }
        if let origin = dragOrigin, let tip = dragTip {
            draw(preview(from: origin, to: tip), in: context)
        }
    }

    /// Base shot plus committed annotations as one image at `shot.scale`. With a solid
    /// backdrop the shot is composited onto the preset gradient with padding, rounded
    /// corners and a shadow. Ignores any in-progress drag. Pure.
    public func render() throws -> CGImage {
        let flat = try renderFlat()
        guard backdrop == .solid else {
            return flat
        }
        return try renderBackdrop(content: flat)
    }

    /// Flat render at exactly `shot.image` pixel size. Shared by every backdrop mode.
    private func renderFlat() throws -> CGImage {
        let width = shot.image.width
        let height = shot.image.height
        let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue
            | CGBitmapInfo.byteOrder32Little.rawValue
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: bitmapInfo
        ) else {
            throw RenderError.bitmapContextUnavailable
        }

        context.scaleBy(x: shot.scale, y: shot.scale)
        draw(in: context)

        guard let image = context.makeImage() else {
            throw RenderError.bitmapContextUnavailable
        }
        return image
    }

    /// Full-bleed preset gradient with the content on a padded, rounded, shadowed card.
    /// The bitmap context is y-up, so the CSS 135deg line runs from the top-left
    /// to the bottom-right of the displayed image.
    private func renderBackdrop(content: CGImage) throws -> CGImage {
        let style = Style.backdrop
        let contentPoints = CGSize(
            width: CGFloat(content.width) / shot.scale,
            height: CGFloat(content.height) / shot.scale
        )
        let background = CGSize(
            width: contentPoints.width + style.padding * 2,
            height: contentPoints.height + style.padding * 2
        )
        let width = Int((background.width * shot.scale).rounded())
        let height = Int((background.height * shot.scale).rounded())
        let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue
            | CGBitmapInfo.byteOrder32Little.rawValue
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil,
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: space,
                  bitmapInfo: bitmapInfo
              ) else {
            throw RenderError.bitmapContextUnavailable
        }

        context.scaleBy(x: shot.scale, y: shot.scale)

        let stops = backdropPreset.stops
        guard let gradient = CGGradient(
            colorsSpace: space,
            colors: stops.map { $0.color } as CFArray,
            locations: stops.map { $0.location }
        ) else {
            throw RenderError.bitmapContextUnavailable
        }
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: background.height),
            end: CGPoint(x: background.width, y: 0),
            options: []
        )

        let card = CGRect(
            x: style.padding,
            y: style.padding,
            width: contentPoints.width,
            height: contentPoints.height
        )
        let path = CGPath(
            roundedRect: card,
            cornerWidth: style.radius,
            cornerHeight: style.radius,
            transform: nil
        )
        context.saveGState()
        context.addPath(path)
        context.setShadow(
            offset: style.shadowOffset,
            blur: style.shadowBlur,
            color: style.shadowColor
        )
        context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
        context.drawPath(using: .fill)
        context.restoreGState()

        context.saveGState()
        context.addPath(path)
        context.clip()
        context.draw(content, in: card)
        context.restoreGState()

        guard let image = context.makeImage() else {
            throw RenderError.bitmapContextUnavailable
        }
        return image
    }

    private func draw(_ annotation: Annotation, in context: CGContext) {
        switch annotation {
        case .arrow(let from, let to):
            drawArrow(from: from, to: to, in: context)
        case .number(let value, let center):
            drawBadge(value, center: center, in: context)
        case .redaction(let rect):
            drawRedaction(rect, in: context)
        case .rectangle(let rect):
            drawRectangle(rect, in: context)
        }
    }

    private func drawArrow(from: CGPoint, to: CGPoint, in context: CGContext) {
        let style = Style.standard
        guard let shape = Geometry.arrowShape(
            from: from,
            to: to,
            headLength: style.headLength,
            headHalfAngle: style.headHalfAngle
        ) else { return }

        context.saveGState()
        defer { context.restoreGState() }
        context.setStrokeColor(style.strokeColor)
        context.setFillColor(style.strokeColor)
        context.setLineWidth(style.strokeWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.move(to: from)
        context.addLine(to: shape.shaftEnd)
        context.strokePath()
        context.move(to: shape.tip)
        context.addLine(to: shape.left)
        context.addLine(to: shape.right)
        context.closePath()
        context.fillPath()
    }

    private func drawRectangle(_ rect: CGRect, in context: CGContext) {
        let style = Style.standard
        context.saveGState()
        defer { context.restoreGState() }
        context.setStrokeColor(style.strokeColor)
        context.setLineWidth(style.strokeWidth)
        context.setLineJoin(.miter)
        context.stroke(rect)
    }

    /// Downsamples the shot under `rect` to a handful of cells and paints them back with no
    /// interpolation, so what lands in the output is the average, never the original pixels.
    private func drawRedaction(_ rect: CGRect, in context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }
        context.interpolationQuality = .none

        guard let cells = redactionCells(for: rect) else {
            context.setFillColor(Style.standard.redactionFallback)
            context.fill(rect)
            return
        }
        context.draw(cells, in: rect)
    }

    private func redactionCells(for rect: CGRect) -> CGImage? {
        let scale = shot.scale
        // Document points are y-up from the bottom left, image pixels y-down from the top left.
        let source = CGRect(
            x: rect.minX * scale,
            y: (pointSize.height - rect.maxY) * scale,
            width: rect.width * scale,
            height: rect.height * scale
        ).integral
        guard source.width >= 1, source.height >= 1,
              let crop = shot.image.cropping(to: source) else {
            return nil
        }

        let cell = Style.standard.redactionCell
        let columns = max(1, Int((rect.width / cell).rounded()))
        let rows = max(1, Int((rect.height / cell).rounded()))
        let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue
            | CGBitmapInfo.byteOrder32Little.rawValue
        guard let context = CGContext(
            data: nil,
            width: columns,
            height: rows,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }
        context.interpolationQuality = .medium
        context.draw(crop, in: CGRect(x: 0, y: 0, width: columns, height: rows))
        return context.makeImage()
    }

    private func drawBadge(_ value: Int, center: CGPoint, in context: CGContext) {
        let style = Style.standard
        let radius = style.badgeRadius

        context.saveGState()
        context.setFillColor(style.badgeColor)
        context.fillEllipse(in: CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        ))
        context.restoreGState()

        let label = "\(value)" as CFString
        let attributes: [CFString: Any] = [
            kCTFontAttributeName: style.font,
            kCTForegroundColorAttributeName: style.labelColor,
        ]
        guard let attributed = CFAttributedStringCreate(nil, label, attributes as CFDictionary) else {
            return
        }
        let line = CTLineCreateWithAttributedString(attributed)

        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var leading: CGFloat = 0
        let width = CTLineGetTypographicBounds(line, &ascent, &descent, &leading)

        context.saveGState()
        context.textMatrix = .identity
        context.textPosition = CGPoint(
            x: center.x - CGFloat(width) / 2,
            y: center.y - (ascent - descent) / 2
        )
        CTLineDraw(line, context)
        context.restoreGState()
    }
}
