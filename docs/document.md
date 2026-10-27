# Document module

The Document module owns annotations, selection, drawing gestures, text drafts, undo and redo,
and rendering. It is a value type with no AppKit dependency. The canvas and export path use the
same renderer.

## Interface

`Document(shot:)` starts with the Arrow tool, orange drawing color, medium text size and no
backdrop. Its public state includes `annotations`, `selectedIndex`, `selectionBounds`,
`textDraft`, `activeColor`, `activeTextSize`, `canUndo` and `canRedo`.

`apply(_:)` accepts actions from the shell:

- `toolSelected`, `pointerDown`, `pointerDragged` and `pointerUp` handle drawing and selection.
- `arrowReversed` reverses an arrow while Command is held. `angleConstrained` snaps lines and
  arrows to 45-degree increments while Shift is held.
- `deselect`, `deleteSelection` and `nudgeSelection` edit the selected object.
- `colorSelected` changes the selected object or draft. Without a selection it changes the
  next drawing color. Redactions have no decorative color.
- `textSizeSelected` changes selected text or a draft. Without a selection it sets the next
  text size.
- `editText` opens existing text at a point. The Text tool also opens existing text, or starts
  an empty draft when clicking elsewhere.
- `textChanged`, `finishText` and `cancelText` manage a text editing session.
- `undo` and `redo` restore annotation snapshots.
- `backdropSelected` and `backdropPresetSelected` change export chrome without adding history.

Annotations are arrows, lines, numbered badges, rectangles, redactions and text. Decorative
annotations store their own color. `TextAnnotation` stores the string, top-left origin, size
and color. `AnnotationColor` defines six presets. `TextSize` defines 16, 24 and 32 point text in
one system font.

## Selection and gestures

Select picks the topmost hit annotation. Lines use distance to the segment, arrowheads use
the rendered triangle, rectangles use their outline, and badges and text use their visible
area. Empty clicks clear selection.

Movement previews translate the selected annotation from its original geometry. Releasing
commits one history entry for the whole drag. Cancelling restores the starting snapshot.
Selection alone never adds history. Undo and redo clear selection so an old array index cannot
refer to a different object.

Drawing tools stay active after creating an annotation. The new annotation becomes selected
for immediate styling. Selecting another tool clears the selection. Deleting a numbered badge
renumbers the remaining badges in drawing order.

## Text editing

A draft remains separate from committed annotations until `finishText`. Editing an existing
label temporarily hides its committed version. Cancel restores that version without adding
history. Finishing an unchanged label is a no-op. Empty new labels are ignored, and finishing
an empty existing label removes it.

A completed text edit is one document undo step. Document Undo finishes and reverses a changed
draft before touching earlier work. Redo finishes a draft, which clears obsolete redo history
when it creates a new change. The native text view handles character-level undo while typing.

Text uses explicit newlines rather than automatic wrapping. CoreText supplies measurement and
rendering. The shell uses the same font sizes and line heights for its native text view.

## Rendering and coordinates

Document coordinates are screenshot points, origin bottom-left and y up. The screenshot
occupies `(0, 0, pointSize.width, pointSize.height)`. `stageOrigin` adds backdrop padding only
in the shell. Text origins are the top-left corner of their first line.

`draw(in:baseInterpolation:includesTextDraft:)` draws the screenshot, committed annotations,
and live previews. `render(includesTextDraft:)` uses that path in a bitmap at `shot.scale`,
then adds the optional gradient backdrop. Both include the text draft by default. The canvas
passes `includesTextDraft: false` while its native text view displays the draft, preventing
double-painted text. Selection outlines are shell-only and never enter the exported image.

Redactions sample the original screenshot and paint coarse averaged cells. Moving one samples
its new location. Exported images contain the flattened result. A moved or removed redaction
reveals the original screenshot at its previous location.

## History and tests

History consists of small `[Annotation]` snapshots. Creation, movement, deletion, recoloring,
resizing text and finishing text edits record changes. Tool selection, defaults and backdrop
settings do not. New changes clear the redo stack.

Tests exercise three boundaries:

- Document actions and observable state for editing and history.
- Rendered pixels for geometry, colors, text and redaction.
- AppKit controls and input events for shortcuts, focus, text editing and responsive layout.

Multi-selection, layers, rotation, font browsing and variable stroke widths are outside this
editor's scope.
