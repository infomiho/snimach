# Minimal editor research and proposal

Add line and text tools, single-object selection for moving and deleting annotations, and a small color palette. Keep these interactions in the floating toolbar, with text size shown only when relevant.

## Existing editor

[Annotations](../Sources/SnimachCore/Document/Annotation.swift) currently cover arrows, numbers, redactions and rectangles. The [document](../Sources/SnimachCore/Document/Document.swift) uses snapshot undo stacks, and [style](../Sources/SnimachCore/Document/Style.swift) defines the brand accent and a four-point width.

The [keymap](../App/EditorKeymap.swift) assigns A, N, R, B, I and K to existing tools. Enter copies and Escape discards. [EditorPanel](../App/EditorWindowController.swift) intercepts key-down events before responders, which matters when introducing native text editing.

## Comparisons

These observations come from project documentation and changelogs, not hands-on testing. Version-specific changelog entries do not establish current behavior on every platform.

| Project | Platform and license | Relevant documented behavior |
| --- | --- | --- |
| [Flameshot](https://github.com/flameshot-org/flameshot) | macOS, Windows and Linux. [GPLv3+](https://github.com/flameshot-org/flameshot/blob/master/README.md?plain=1). | The capture overlay has line, arrow and text tools, a color wheel, thickness control, undo and clipboard shortcuts. Ctrl constrains a line to horizontal, vertical or diagonal. The documentation does not establish whether existing annotations can be moved or recolored. |
| [ksnip](https://github.com/ksnip/ksnip) | macOS, Windows and Linux. GPL-3.0. | Its [changelog](https://github.com/ksnip/ksnip/blob/master/CHANGELOG.md) records combined selection and movement, shape-based hit testing, selection after drawing with editable settings, and double-click text editing. |
| [Greenshot](https://github.com/greenshot/greenshot) | The linked open-source product is Windows, GPL-3.0. | Its [editor guide](https://getgreenshot.org/help/) describes moving, resizing and recoloring selected shapes. Options also set defaults for the next shape. Double-click edits text. |
| [ShareX](https://github.com/ShareX/ShareX) | Windows, GPL-3.0. | Its [image editor](https://github.com/ShareX/ShareX.ImageEditor) documents selection and manipulation alongside lines, arrows and text. Its [changelog](https://github.com/ShareX/sharex.github.io/blob/master/changelog.md) records a change where freehand drawing no longer selects existing marks, leaving selection to the Select tool. |

[Shutter's historical changelog](https://github.com/shutter-project/shutter/blob/master/CHANGES) lists 0.85 issues about instant application of properties and marker settings. Its 0.86 drawing-tool entries list requests for immediate text editing and keyboard shape movement, plus an arrow width issue after using censor. These are historical issue entries, not claims about current behavior.

Later [Shutter releases](https://github.com/shutter-project/shutter/releases) record a change to reduce data leakage under pixelation in 0.99.6 and increased maximum marker thickness for high-resolution screens in 0.99.7. The implication for Snimach is to treat redaction separately from decorative color settings and check annotations at different display scales.

[Shottr](https://shottr.cc/kb/terms) is excluded from the open-source comparison. Its published terms describe a limited use license.

## Proposed first version

The following is a design recommendation informed by these examples, not a claim that the projects use the same interaction model.

- Add **Select** on V for one annotation at a time. Drag to move, Delete to remove, and arrow keys to nudge. Hit-test near the visible stroke so thin lines remain easy to select.
- Add **Line** on L, drawn by dragging. Shift constrains its angle. Keep drawing tools active after a mark is made, and select the new mark for quick styling without switching tools. Moving an existing mark requires V, so drawing over a mark remains predictable.
- Add a six-preset color swatch. A change applies to the selected annotation only, or sets the next drawing default when nothing is selected. Redactions are not recolorable. Keep the existing stroke width fixed in this first version.
- Add **Text** on T. Click and type using a native field editor, one font and three sizes. Double-click existing text to edit it. Return inserts a newline, Command-Return finishes, and clicking elsewhere finishes. Escape first cancels text editing, then deselects, then retains the existing discard behavior. Do not intercept global tool or export keys while text editing has focus.

Keep multi-select, layers, font selection and rotation outside the first version. Preserve coherent snapshot undo for creation, movement, deletion, styling and text edits.

Deliver selection first, then line and color, then text. This order establishes object editing before adding text focus and keyboard routing.
