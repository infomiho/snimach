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

    public private(set) var drawingColor: AnnotationColor = .orange
    public private(set) var selectedIndex: Int?

    public private(set) var drawingTextBackground: TextBackground = .none
    public private(set) var drawingTextSize: TextSize = .medium
    public private(set) var textDraft: TextAnnotation?
    private var editedTextIndex: Int?
    private var movementStart: [Annotation]?
    private var dragOrigin: CGPoint?
    private var dragTip: CGPoint?
    private var isAngleConstrained = false
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

    public var activeTextBackground: TextBackground? {
        if let draft = textDraft { return draft.background }
        if let index = selectedIndex {
            if case .text(let text) = annotations[index] { return text.background }
            return nil
        }
        return tool == .text ? drawingTextBackground : nil
    }

    public var activeTextSize: TextSize? {
        if let draft = textDraft { return draft.size }
        if let index = selectedIndex {
            if case .text(let text) = annotations[index] { return text.size }
            return nil
        }
        return tool == .text ? drawingTextSize : nil
    }

    public var activeColor: AnnotationColor? {
        if let draft = textDraft { return draft.color }
        if let index = selectedIndex { return annotations[index].color }
        return tool == .redact ? nil : drawingColor
    }

    public var selectionBounds: CGRect? {
        guard textDraft == nil else { return nil }
        return selectedIndex.map { annotations[$0].bounds }
    }

    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }

    /// Total function: every action is valid in every state and never throws.
    public mutating func apply(_ action: Action) {
        switch action {
        case .toolSelected(let newTool):
            finishText()
            cancelDrag()
            tool = newTool
            selectedIndex = nil

        case .pointerDown(let point):
            if tool == .text {
                finishText()
                beginText(at: point, creating: true)
                return
            }
            if tool == .select {
                cancelDrag()
                selectedIndex = annotations.indices.reversed().first { annotations[$0].contains(point) }
                if selectedIndex != nil {
                    movementStart = annotations
                    dragOrigin = point
                }
                return
            }
            guard tool.isDrag else { return }
            dragOrigin = point
            dragTip = point

        case .pointerDragged(let point):
            guard dragOrigin != nil else { return }
            dragTip = point
            if tool == .select { moveSelection(to: point) }

        case .pointerUp(let point):
            switch tool {
            case .text: break
            case .select:
                moveSelection(to: point)
                if let previous = movementStart, previous != annotations {
                    undoStack.append(previous)
                    redoStack.removeAll()
                }
                movementStart = nil
                cancelDrag()
            case .arrow, .line:
                guard let origin = dragOrigin else { return }
                cancelDrag()
                if hypot(point.x - origin.x, point.y - origin.y) >= Style.standard.minimumArrowLength {
                    commit(preview(from: origin, to: point))
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

        case .angleConstrained(let constrained):
            isAngleConstrained = constrained

        case .arrowReversed(let reversed):
            isArrowReversed = reversed

        case .backdropSelected(let mode):
            backdrop = mode

        case .backdropPresetSelected(let preset):
            backdropPreset = preset

        case .textBackgroundSelected(let background):
            cancelDrag()
            drawingTextBackground = background
            if textDraft != nil {
                textDraft?.background = background
            } else if let index = selectedIndex {
                guard case .text(var text) = annotations[index], text.background != background else { return }
                undoStack.append(annotations)
                text.background = background
                annotations[index] = .text(text)
                redoStack.removeAll()
            }

        case .textSizeSelected(let size):
            cancelDrag()
            if textDraft != nil {
                textDraft?.size = size
            } else if let index = selectedIndex {
                guard case .text(var text) = annotations[index], text.size != size else { return }
                undoStack.append(annotations)
                text.size = size
                annotations[index] = .text(text)
                redoStack.removeAll()
            } else {
                drawingTextSize = size
            }

        case .textChanged(let text):
            textDraft?.text = text

        case .editText(let point):
            finishText()
            beginText(at: point, creating: false)

        case .finishText:
            finishText()

        case .cancelText:
            textDraft = nil
            editedTextIndex = nil

        case .colorSelected(let color):
            drawingColor = color
            if textDraft != nil {
                textDraft?.color = color
                return
            }
            cancelDrag()
            guard let index = selectedIndex else { return }
            let updated = annotations[index].colored(color)
            guard updated != annotations[index] else { return }
            undoStack.append(annotations)
            annotations[index] = updated
            redoStack.removeAll()

        case .deselect:
            finishText()
            cancelDrag()
            selectedIndex = nil

        case .nudgeSelection(let offset):
            finishText()
            cancelDrag()
            guard let index = selectedIndex, offset != .zero else { return }
            undoStack.append(annotations)
            annotations[index] = annotations[index].translated(by: offset)
            redoStack.removeAll()

        case .deleteSelection:
            finishText()
            cancelDrag()
            guard let index = selectedIndex else { return }
            undoStack.append(annotations)
            annotations.remove(at: index)
            var number = 0
            annotations = annotations.map { annotation in
                guard case .number(_, let center, let color) = annotation else { return annotation }
                number += 1
                return .number(number, center: center, color: color)
            }
            redoStack.removeAll()
            selectedIndex = nil

        case .undo:
            if textDraft != nil {
                let previous = annotations
                finishText()
                guard annotations != previous else { return }
            }
            cancelDrag()
            guard let previous = undoStack.popLast() else { return }
            redoStack.append(annotations)
            annotations = previous
            selectedIndex = nil

        case .redo:
            finishText()
            cancelDrag()
            guard let next = redoStack.popLast() else { return }
            undoStack.append(annotations)
            annotations = next
            selectedIndex = nil
        }
    }

    private mutating func beginText(at point: CGPoint, creating: Bool) {
        cancelDrag()
        let hit = annotations.indices.reversed().first { annotations[$0].contains(point) }
        if let index = hit, case .text(let text) = annotations[index] {
            editedTextIndex = index
            selectedIndex = index
            textDraft = text
        } else if creating {
            editedTextIndex = nil
            selectedIndex = nil
            textDraft = TextAnnotation(text: "", origin: point, size: drawingTextSize, color: drawingColor, background: drawingTextBackground)
        }
    }

    private mutating func finishText() {
        guard let draft = textDraft else { return }
        let index = editedTextIndex
        textDraft = nil
        editedTextIndex = nil
        let empty = draft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if let index {
            let updated = Annotation.text(draft)
            guard empty || annotations[index] != updated else { return }
            undoStack.append(annotations)
            if empty {
                annotations.remove(at: index)
                selectedIndex = nil
            } else {
                annotations[index] = updated
                selectedIndex = index
            }
            redoStack.removeAll()
        } else if !empty {
            undoStack.append(annotations)
            annotations.append(.text(draft))
            selectedIndex = annotations.count - 1
            redoStack.removeAll()
        }
    }

    private func preview(from origin: CGPoint, to tip: CGPoint) -> Annotation {
        let tip = constrainedTip(from: origin, to: tip)
        switch tool {
        case .line: return .line(from: origin, to: tip)
        case .redact: return .redaction(Geometry.rect(from: origin, to: tip))
        case .rectangle: return .rectangle(Geometry.rect(from: origin, to: tip))
        case .text, .select, .arrow, .number: return arrow(from: origin, to: tip)
        }
    }

    private func constrainedTip(from origin: CGPoint, to tip: CGPoint) -> CGPoint {
        guard isAngleConstrained && (tool == .line || tool == .arrow) else { return tip }
        let dx = tip.x - origin.x
        let dy = tip.y - origin.y
        let angle = (atan2(dy, dx) / (.pi / 4)).rounded() * (.pi / 4)
        let length = hypot(dx, dy)
        return CGPoint(x: origin.x + cos(angle) * length, y: origin.y + sin(angle) * length)
    }

    private func arrow(from origin: CGPoint, to tip: CGPoint) -> Annotation {
        isArrowReversed ? .arrow(from: tip, to: origin) : .arrow(from: origin, to: tip)
    }

    private var badgeCount: Int {
        annotations.filter { if case .number = $0 { true } else { false } }.count
    }

    private mutating func commit(_ annotation: Annotation) {
        undoStack.append(annotations)
        annotations.append(annotation.colored(drawingColor))
        selectedIndex = annotations.count - 1
        redoStack.removeAll()
    }

    private mutating func moveSelection(to point: CGPoint) {
        guard let index = selectedIndex, let previous = movementStart, let origin = dragOrigin else { return }
        annotations[index] = previous[index].translated(by: CGSize(width: point.x - origin.x, height: point.y - origin.y))
    }

    private mutating func cancelDrag() {
        if let previous = movementStart { annotations = previous }
        movementStart = nil
        dragOrigin = nil
        dragTip = nil
    }

    /// Draws the base shot, committed annotations and the in-progress preview.
    public func draw(in context: CGContext, baseInterpolation: CGInterpolationQuality = .none, includesTextDraft: Bool = true) {
        context.saveGState()
        defer { context.restoreGState() }

        // The base is a bitmap at exactly 1:1. Never resample it: with default smoothing any
        // sub-pixel misalignment turns the whole preview soft instead of staying crisp.
        context.saveGState()
        context.interpolationQuality = baseInterpolation
        context.draw(shot.image, in: CGRect(origin: .zero, size: pointSize))
        context.restoreGState()

        drawAnnotations(in: context, includesTextDraft: includesTextDraft)
    }

    private func drawAnnotations(in context: CGContext, includesTextDraft: Bool) {
        for (index, annotation) in annotations.enumerated() where index != editedTextIndex {
            draw(annotation, in: context)
        }
        if includesTextDraft, let draft = textDraft {
            draw(.text(draft), in: context)
        }
        if tool != .select, let origin = dragOrigin, let tip = dragTip {
            draw(preview(from: origin, to: tip).colored(drawingColor), in: context)
        }
    }

    public func renderStageBackground() throws -> CGImage {
        guard backdrop == .solid else { return shot.image }
        return try renderBackdrop(content: shot.image)
    }

    public func drawStageAnnotations(in context: CGContext, includesTextDraft: Bool = true) {
        context.saveGState()
        defer { context.restoreGState() }
        if backdrop == .solid {
            let card = CGRect(origin: stageOrigin, size: pointSize)
            context.addPath(CGPath(roundedRect: card, cornerWidth: Style.backdrop.radius,
                                   cornerHeight: Style.backdrop.radius, transform: nil))
            context.clip()
            context.translateBy(x: stageOrigin.x, y: stageOrigin.y)
        }
        drawAnnotations(in: context, includesTextDraft: includesTextDraft)
    }

    /// Base shot plus committed annotations as one image at `shot.scale`. With a solid
    /// backdrop the shot is composited onto the preset gradient with padding, rounded
    /// corners and a shadow. Includes live previews without changing document state.
    public func render(includesTextDraft: Bool = true) throws -> CGImage {
        let flat = try renderFlat(includesTextDraft: includesTextDraft)
        guard backdrop == .solid else {
            return flat
        }
        return try renderBackdrop(content: flat)
    }

    /// Flat render at exactly `shot.image` pixel size. Shared by every backdrop mode.
    private func renderFlat(includesTextDraft: Bool) throws -> CGImage {
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
        draw(in: context, includesTextDraft: includesTextDraft)

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
        case .text(let text):
            context.saveGState()
            if text.background == .solid {
                context.setFillColor(text.color.cgColor)
                let radius = TextAnnotation.backgroundCornerRadius
                context.addPath(CGPath(roundedRect: text.bounds, cornerWidth: radius, cornerHeight: radius, transform: nil))
                context.fillPath()
            }
            context.textMatrix = .identity
            let ascent = CTFontGetAscent(text.size.font)
            for (index, line) in text.lines.enumerated() {
                context.textPosition = CGPoint(x: text.origin.x, y: text.origin.y - ascent - CGFloat(index) * text.size.lineHeight)
                CTLineDraw(line, context)
            }
            context.restoreGState()
        case .line(let from, let to, let color):
            context.saveGState()
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(Style.standard.strokeWidth)
            context.setLineCap(.round)
            context.move(to: from)
            context.addLine(to: to)
            context.strokePath()
            context.restoreGState()
        case .arrow(let from, let to, let color):
            drawArrow(from: from, to: to, color: color, in: context)
        case .number(let value, let center, let color):
            drawBadge(value, center: center, color: color, in: context)
        case .redaction(let rect):
            drawRedaction(rect, in: context)
        case .rectangle(let rect, let color):
            drawRectangle(rect, color: color, in: context)
        }
    }

    private func drawArrow(from: CGPoint, to: CGPoint, color: AnnotationColor, in context: CGContext) {
        let style = Style.standard
        guard let shape = Geometry.arrowShape(
            from: from,
            to: to,
            headLength: style.headLength,
            headHalfAngle: style.headHalfAngle
        ) else { return }

        context.saveGState()
        defer { context.restoreGState() }
        context.setStrokeColor(color.cgColor)
        context.setFillColor(color.cgColor)
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

    private func drawRectangle(_ rect: CGRect, color: AnnotationColor, in context: CGContext) {
        let style = Style.standard
        context.saveGState()
        defer { context.restoreGState() }
        context.setStrokeColor(color.cgColor)
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
        let source = shot.pixelRect(for: rect)
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

    private func drawBadge(_ value: Int, center: CGPoint, color: AnnotationColor, in context: CGContext) {
        let style = Style.standard
        let radius = style.badgeRadius

        context.saveGState()
        context.setFillColor(color.cgColor)
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
            kCTForegroundColorAttributeName: color.labelColor,
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
