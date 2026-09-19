# Tasks

Ordered. One at a time, both suites green before the next.

## 1. Identity

- [x] 1.1 Pick a direction in `design/logo-variants.html`. Corner frame with an orange diagonal.
- [x] 1.2 Author the chosen mark as one source SVG. `design/svg/appicon.svg`, 824 on a 1024 canvas at the macOS corner radius.
- [x] 1.3 Generate the AppIcon set, 16 through 1024 at 1x and 2x, and wire it into `App/project.yml`. `scripts/make-icon.sh` builds it.
- [x] 1.4 Derive the menu bar template mark from the same geometry and replace `camera.viewfinder`.
- [x] 1.5 About window with name, version and copyright, and fill `NSHumanReadableCopyright`.

## 2. Editor completeness

- [x] 2.1 Redaction tool. Pixelates from `shot.image`, pinned by a checkerboard pixel test.
- [x] 2.2 Rectangle tool, reusing the arrow's drag path.
- [x] 2.3 Toolbar items and keymap entries for both. `R` draws a rectangle, `B` hides an area.

## 3. Modes and settings

- [x] 3.1 Full screen capture, on `⌘⇧E`. Captures the display under the pointer.
- [x] 3.2 Window picker in the overlay. The window under the pointer highlights, a click captures it.
- [x] 3.3 Settings: save folder with choose and reveal, what happens after a capture, whether the pointer is included.
- [x] 3.4 Reveal in Finder by clicking the save HUD, and drag the shot out of the preview card as a PNG file.
- [x] 3.5 Editor window is resizable, and a shot larger than the screen opens fitted.
- [x] 3.6 The overlay says what it does, and a window pick is drawn in the accent colour rather
  than looking like a dragged region.

## Bugs

- [x] B1 Launch at login shows stale state for the whole app run. `LaunchAtLoginModel` in
  `App/Settings/SettingsView.swift` snapshots `isEnabled` and `requiresApproval` in `init`, and the
  settings window is built once and cached by `Coordinator`, so toggling the login item in System
  Settings never shows until relaunch. This contradicts `LaunchAtLogin`, which documents status as
  read live and never cached. Re-read when the window becomes key. The same `didSet` swallows
  `setEnabled` errors with `try?`, so a failed register leaves the toggle on with no feedback.
- [x] B2 The save HUD lands on the wrong screen. `App/PermissionAlert.swift` positions the flash on
  `NSScreen.main`, the screen holding keyboard focus, not the screen the shot came from. Pass the
  shot's screen in. `NSScreen.nearest(_:)` already exists for this.

## 4. Settings tabs

- [x] 4.1 Split SettingsView into Capture plus Shortcuts plus General toolbar tabs
- [x] 4.2 Move after capture and pointer and preview lifetime to Capture and recorders to Shortcuts and folder and launch to General
- [x] 4.3 Keep single window controller and activation flow unchanged

## 5. Preview actions

- [x] 5.1 Add Open plus Save plus Discard buttons in a card footer while keeping panel non activating
- [x] 5.2 Add hide pref with After 5s or Manually
- [x] 5.3 Keep clipboard first and keep drag out behavior
- [x] 5.4 Use Solar icon buttons with tooltips in the preview action bar instead of drawn text

## 6. Editor and menu polish

Design replicate with variants in `design/toolbar-6x/index.html`. Size and zoom were cut
from 6.1: with no interaction behind them they were decoration.

- [x] 6.1 Show color swatch plus hex under the cursor with Tab to copy, display only otherwise
- [x] 6.2 Rectangle and Hide live in their own segment; AppKit collapses it into the system overflow menu when crowded (priorities, no hand-rolled insert/remove)
- [x] 6.3 Status menu capture rows reuse Solar (crop, window frame, monitor); Settings, About and Quit stay text-only like Apple menus, deliberately unlike the mock
- [x] 6.4 Dropped: Launch at Login stays in Settings, out of the menu

## 7. Backdrop export

- [x] 7.1 Researched plus picked with approval: 11 final presets in the gallery shortlist
  - [x] Prototype in `design/backdrop/index.html` on the 6.X shell with live K toggle
  - [x] 10 presets plus color picker plus trim sub-toggle, auto-hide preset bar
  - [x] 20 palette-derived gradients with base64 source photos, click to apply
  - [x] Wetlands 2 algorithm shootout: median-cut vs k-means Lab vs Vibrant vs OKLCH ramp vs Lightflow
  - [x] Gradient repo dive: Hypercolor MIT exact stops, Screenshotter mesh technique, PrettyShot DB-backed
  - [x] 5 default bangers: Gotham plus Arendelle via Hypercolor MIT, Wetlands via k-means, Slate Orb plus Mist original mesh
  - [x] Kept Gotham, Arendelle, Minimal 4, Heather 6, Sierra 10, Sierra 7, Wetlands 9; gallery rebuilt as 27 cards
  - [x] 20 new candidates: 12 k-means palettes from Quartz plus Twilight plus Coastal plus Mystic, 8 muted Hypercolor exact
  - [x] Final 11: keeps plus Sierra Mist plus Island Waves plus Twilight 10 plus Quartz 8
- [x] 7.2 Editor backdrop mode on K with Transparent plus Solid and default Transparent pref, preset menu on the toolbar button
- [x] 7.3 Backdrop in Document render with pixel test, editor canvas previews the export render
- [x] Stage bounds fix: setFrame scales bounds when sizes differ, CanvasView re-anchors bounds on the stage
- [x] Preset strip under the toolbar as in the HTML: round swatches, presets only, shown only while a backdrop is on
- [x] Backdrop control is one click-to-toggle button with the live swatch plus name, no dropdown menu
- [x] Review follow-ups: Solar dots overflow glyph, single-build overflow menu, preset validity test, chrome-never-undoable test, K end-to-end test, prefs seeding test, tab-copy test
- [x] Dropped Trim window shadow: two modes, popup menu without the trim row

## 8. Logo design system

- [x] 8.1 Centralize logo tokens in Brand with accent plus ink plus paper plus line plus muted plus card radius
- [x] 8.2 Draw annotations in logo accent instead of pure red with pixel tests following Style
- [x] 8.3 Tint Settings controls with logo accent and share card radius between preview card and editor canvas
- [x] 8.4 Draw the sidebar selection in logo accent instead of system blue
- [x] 8.5 Show the app logo on top of the sidebar tabs
- [x] 8.6 Keep About as a sidebar tab reusing AboutView and drop the separate About window

## 9. Floating editor controls

- [x] 9.1 Implement the approved `design/editor-8x-v2` layout in AppKit.
- [x] 9.2 Keep output actions in the title bar and editing controls in one floating bar.
- [x] 9.3 Replace the preset strip with an anchored grid of eleven presets.
- [x] 9.4 Add color inspection on I, a contextual copy chip, and Escape to leave the mode.
- [x] 9.5 Keep the window fixed through backdrop transitions and adapt controls to narrow windows.

## Not doing

Text recognition, scrolling capture, uploads, pinned shots, video. Each is a different product.
Reopen Last Shot which needs last Document kept in Coordinator.
