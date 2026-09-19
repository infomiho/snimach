# Document module

The Document module owns everything between "pointer and key actions in shot coordinates" and
"pixels": the list of annotations, the in-progress drag, undo and redo, and rendering. It is a
value type with no AppKit dependency. The canvas view and the export path are thin adapters over it,
and both draw through the same function.

## Interface

```swift
import CoreGraphics

enum Tool { case arrow, number, redact, rectangle }

/// Editor backdrop mode, toggled with K. Transparent exports shot pixels only.
enum BackdropMode { case transparent, solid }

/// Committed annotation, in document points. Badge numbers are derived by the document
/// (1, 2, 3 by commit order among badges) and are always contiguous after undo and redo.
enum Annotation: Equatable {
    case arrow(from: CGPoint, to: CGPoint)
    case number(Int, center: CGPoint)
    /// The area is replaced by a coarse average of the shot beneath it, so the original pixels
    /// are gone from the rendered image rather than merely covered.
    case redaction(CGRect)
    case rectangle(CGRect)
}

/// Everything that can happen to a document. Pointer actions are tool-agnostic: the document
/// decides what a press, drag, or release means for the current tool.
enum Action {
    case toolSelected(Tool)
    case pointerDown(CGPoint)
    case pointerDragged(CGPoint)
    case pointerUp(CGPoint)
    case arrowReversed(Bool)     // Cmd held: the arrow points back at the drag origin
    // Tools: arrow, number, rectangle, redact. Every tool but number is a drag.
    // `.redaction` replaces its area with a coarse average of the shot, so the original pixels
    // are absent from `render()` rather than covered by an opaque shape.
    case backdropSelected(BackdropMode)
    case backdropPresetSelected(BackdropPreset)
    case undo
    case redo
}

enum RenderError: Error { case bitmapContextUnavailable }

/// Value type. Hold it in a `var`, mutate it with `apply`, read it back. No reference semantics,
/// no callbacks, no threads.
struct Document {
    /// Tool starts as `.arrow`, backdrop as `.transparent`, history starts empty.
    init(shot: Shot)

    /// Defined by the Capture module: `image: CGImage`, `scale: CGFloat`,
    /// `frame: CGRect` (AppKit global points), `hasAlpha: Bool`.
    /// Invariant: `image.width == frame.width * scale` and `image.height == frame.height * scale`.
    let shot: Shot
    /// Size of the document in points. Equal to `shot.frame.size`.
    var pointSize: CGSize { get }
    private(set) var tool: Tool
    /// Committed annotations in commit order. Excludes any in-progress arrow.
    private(set) var annotations: [Annotation]
    var canUndo: Bool { get }
    var canRedo: Bool { get }

    /// Total function: every action is valid in every state and never throws.
    /// - pointerDown, pointerDragged, pointerUp with `.arrow`: down starts a preview, drags move
    ///   its tip, up commits an arrow if the tip moved at least `Style.minimumArrowLength` points,
    ///   otherwise commits nothing.
    /// - pointerUp with `.number`: commits a badge at the up point, numbered (badge count + 1).
    /// - undo, redo, toolSelected during a drag cancel the drag first, then act.
    /// - `backdropSelected` and `backdropPresetSelected` switch export chrome without touching history.
    /// - undo or redo on an empty stack is a no-op. A new commit clears the redo stack.
    /// - pointerDragged or pointerUp without a matching pointerDown is a no-op.
    /// Cost: O(1) per action apart from copying the small annotation array into history on commit.
    mutating func apply(_ action: Action)

    /// The single rendering path. Draws the base shot, all committed annotations, and the
    /// in-progress arrow preview (if any) into `context`. The caller must not draw the shot
    /// itself: the base image belongs to this function so screen and export share one path.
    /// Precondition on the context: the CTM maps document space to the device, meaning 1 unit is
    /// 1 point, origin bottom-left, y up, covering `pointSize`. An unflipped NSView at any backing
    /// scale satisfies this natively. Leaves the graphics state as it found it.
    /// Cost: one CGImage blit plus O(annotations) path fills. Fine at 60 Hz during a drag.
    func draw(in context: CGContext)

    /// Base shot plus committed annotations as one image at `shot.scale`, with the same pixel
    /// size as `shot.image`. Ignores any in-progress drag. Pure: does not mutate the document.
    /// With a solid backdrop the shot is composited onto the preset gradient with
    /// padding, rounded corners and a shadow. Throws only if CoreGraphics cannot allocate the bitmap. Cost: one full-size bitmap
    /// allocation (about 60 MB for a 5K shot) and one `draw(in:)`, single-digit milliseconds.
    func render() throws -> CGImage
}
```

### Coordinate space

Document space is shot points, origin bottom-left, y up, with the image occupying
`(0, 0, pointSize.width, pointSize.height)`. This is the native CoreGraphics space and the default
unflipped NSView space, so the canvas passes `convert(event.locationInWindow, from: nil)` through
untouched and `draw(in:)` draws the base image right side up with no extra transform. Pixels appear
only inside `render()`, which applies exactly one `scaleBy(x: shot.scale, y: shot.scale)`. Nothing
outside the module converts between points and pixels.

`shot.frame.origin` is not used by this module. It positions the editor window on screen and is the
shell's concern.

### Style

One colour, one stroke width, one font, badge radius, arrow head geometry, and the minimum arrow
length are an internal constant `Style.standard`. Style is not on the interface because the product
has no styling.

## Usage

Canvas view, the whole adapter:

```swift
final class CanvasView: NSView {
    var document: Document { didSet { needsDisplay = true } }
    override var isFlipped: Bool { false }    // keeps document space equal to view space

    override func draw(_ dirtyRect: NSRect) {
        document.draw(in: NSGraphicsContext.current!.cgContext)
    }
    override func mouseDown(with e: NSEvent)    { document.apply(.pointerDown(convert(e.locationInWindow, from: nil))) }
    override func mouseDragged(with e: NSEvent) { document.apply(.pointerDragged(convert(e.locationInWindow, from: nil))) }
    override func mouseUp(with e: NSEvent)      { document.apply(.pointerUp(convert(e.locationInWindow, from: nil))) }
}
```

The view's `bounds` equals `document.pointSize`. The editor keymap forwards Cmd+Z as `.undo`,
Shift+Cmd+Z as `.redo`, and tool keys as `.toolSelected`.

Export path (Enter, Cmd+C, Cmd+S):

```swift
let image = try canvas.document.render()    // CGImage at Retina pixel size, then clipboard or file
```

## What the implementation hides

- **Arrow geometry.** The shaft is stroked from `from` to the head's base rather than to `to`, so
  the round cap never pokes through the tip. The head is a filled triangle at `to` computed from
  `atan2(dy, dx)`, `Style.headLength`, and `Style.headHalfAngle`. Callers only ever say two points.
- **Badge layout.** A filled circle of `Style.badgeRadius` with the label centred using CoreText
  typographic bounds from `CTLineGetTypographicBounds`, baseline at
  `center.y - (ascent - descent) / 2`. The context's text matrix is reset to identity before
  `CTLineDraw` because AppKit contexts may leave it flipped.
- **Numbering.** A badge's number is derived at commit time as `badges.count + 1`. Undo, redo, and
  the per-shot reset need no bookkeeping.
- **Gesture state.** A private drag origin and drag tip. The preview arrow is drawn by the same
  arrow routine as committed ones, so preview and export cannot drift.
- **Undo and redo.** Two stacks of `[Annotation]` snapshots. The arrays hold a handful of enum
  values, so a snapshot per commit is cheaper than inverse operations and makes redo free.
- **Scale conversion.** `render()` builds a `CGContext(data: nil, width: image.width,
  height: image.height, bitsPerComponent: 8, bytesPerRow: 0, space: sRGB,
  bitmapInfo: premultipliedFirst | byteOrder32Little)`, applies the single scale transform,
  calls `draw(in:)`, and returns `makeImage()`. This works headless with no window or view.
- **Single render path.** `draw(in:)` is the only place that touches `CGContext` for drawing.
  `render()` and the view both call it. There is no separate export renderer.

## Dependencies and tests

The module depends on CoreGraphics and CoreText only. Both are in-process and run headless. The
module creates nothing external: the shot arrives through `init`, the context arrives through
`draw(in:)`, and `render()` returns a value instead of writing a file or the pasteboard. No protocol
wraps CoreGraphics because there is only one adapter, so a seam there would be hypothetical.

Tests cross the same seam as callers, in two layers.

**Action tests** (fast, most of them). Build a document from a tiny shot (for example 40 by 30 points
at scale 2, solid gray), apply an action sequence, assert on `annotations`, `tool`, `canUndo`,
and `canRedo`.

- A drag from A to B commits `.arrow(from: A, to: B)`. A 2-point drag commits nothing.
- Three badge taps yield numbers 1, 2, 3. Undo then tap yields 3 again.
- Undo during a drag cancels it and pops the previous commit. Redo after a new commit is a no-op.
- Dragged or up without a down leaves the document unchanged.

**Pixel tests** (few, cover geometry and the render contract). Call `render()` or draw into a test
bitmap, then read pixels back through `context.data` (BGRA, premultiplied, rows top-down).

- Render of an empty document equals the base pixels and has the dimensions of `shot.image`.
- After an arrow, the shaft midpoint pixel is the annotation colour and a far corner is still base.
- After a badge, the ring pixel is the annotation colour and the centre pixel is the label colour.
- During a drag, `draw(in:)` paints the shaft. After `.undo`, it does not.
- A shot with scale 2 produces a stroke twice as many pixels wide as scale 1.

Implementer notes for pixel tests: expected colours come from `Style.standard` through
`@testable import`. Build them in the sRGB colour space the bitmap uses. A colour created with the
generic `CGColor(red:green:blue:alpha:)` initializer is converted on draw and lands a few units off,
so the comparison helper uses a small tolerance.

## Trade-offs

**Reducer over explicit methods.** `apply(_:)` replaces six methods, and the actions are
tool-agnostic, so the view never learns what a tool is. Every ordering rule (undo mid-drag, tool
switch mid-drag, redo invalidation) lives in one `switch`. A new tool is one enum case and one
branch, not a new method plus new view code. Tests are plain action lists. The price is one
indirection for readers who prefer named methods.

**Value type over a class with delegates.** The view stores a struct and redraws on every `didSet`.
No observer protocol, no notification, and tests never need a run loop. The cost is a redraw per
action even for no-op actions, which is negligible at the rates involved.

**High leverage.** `draw(in:)` serves live preview, export, and every pixel test. `apply` is the
second: six action kinds buy gesture handling, commit rules, numbering, and history.

**Deliberately thin.** `annotations` is exposed read-only so tests can assert on structure without
decoding pixels. It is the only part of the interface that exists for tests rather than the app.

**Out of scope by design.** Hit-testing, selection, moving annotations, styling, text caching.
Adding any of them stays inside the module because the view only ever sends actions and calls `draw`.
