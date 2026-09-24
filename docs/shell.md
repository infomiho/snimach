# App shell and editor window

Swift + AppKit, macOS 14+, `LSUIElement = YES`. The shell is wiring only: it owns lifecycle, windows and event routing, and no product logic. It passes the deletion test: delete it and nothing about capturing, annotating or exporting is lost, only the connections between Capturer, Document, Output and the OS.

## Interface and files

The shell has one entry point, used by both the hotkeys and the status menu:

```swift
Coordinator.capture(_ kind: Capturer.Kind)   // .area | .activeWindow(includeShadow:)
Coordinator.showSettings()
```

Shell state is four fields on `Coordinator`:

| Field | Meaning |
|---|---|
| `preview: PreviewController?` | the preview card on screen, or nil |
| `editor: EditorWindowController?` | the one open editor, or nil |
| `isCapturing: Bool` | a `Capturer.capture` call is in flight |
| `settings: SettingsWindowController?` | lazily created, reused |

Tool selection lives in the Document, so the shell holds no tool state. `preview` and `editor` are never both set: the card closes before the editor opens.

Files, one type each:

- `SnimachApp.swift`: `@main` AppDelegate with a manual `main()`, no storyboard. Builds StatusMenu, Hotkeys and Coordinator in `applicationDidFinishLaunching`.
- `Coordinator.swift`: the four fields above, the capture state machine, and the seam to Capturer, Output, the preview factory and the editor factory. All four are injected so tests replace them.
- `StatusMenu.swift`: NSStatusItem + NSMenu with Capture Area, Capture Window, Settings…, Quit. Each item calls Coordinator.
- `Hotkeys.swift`: `extension KeyboardShortcuts.Name` with two names and `initial:` defaults, and one `Task` per name looping `for await _ in KeyboardShortcuts.events(for:) where == .keyUp`.
- `PermissionAlert.swift`: one NSAlert switching on `PermissionState`. Open System Settings button for every state, Relaunch button for `.grantedNeedsRelaunch`.
- `LaunchAtLogin.swift`: `var isEnabled: Bool` reading `SMAppService.mainApp.status == .enabled` on every get, `register()` / `unregister()` on set.
- `SettingsView.swift`: SwiftUI sidebar with App, Capture, Shortcuts and About panes. App holds the save folder, LaunchAtLogin and Updates, Capture holds after capture, pointer and preview hiding, Shortcuts holds three `KeyboardShortcuts.Recorder` rows.
- `Updater.swift`: `SPUStandardUpdaterController` plus its delegate, `nil` when the bundle has no `SUFeedURL`. Publishes `UpdateCheck` (not checked, up to date, available, skipped) for the Updates section and exposes Sparkle's persisted automatic-checks flag. Sparkle's own windows do the rest.
- `SettingsWindowController.swift`: NSWindow hosting `NSHostingView(rootView: SettingsView())`, owns the activation-policy switch.
- `EditorLayout.swift`: fits and centers the stage without upscaling. `EditorStageView` overlays
  the accessory bar and color chip, and transitions backdrop changes inside a fixed window.
- `EditorControls.swift`: native material surface, Solar icon buttons, grouped editing controls,
  and an overflow menu that keeps the active tool visible.
- `BackdropPickerView.swift`: eleven named preset buttons in an anchored native popover.
- `ColorReadoutView.swift`: sampled color, hex, copy button and confirmation.
- `PreviewWindowController.swift`: `PreviewLayout` (pure: thumbnail fit, footer strip and bottom-right corner frame), `PreviewWindowController` (borderless non-activating `NSPanel`, slides in from the right edge, fades out after 5 s, hover pauses the clock and leaves 2 s after exit) and `PreviewCardView` (rounded bordered card with the shot as layer contents, pointing-hand cursor, footer strip with Open plus Save plus Discard). Reports one `PreviewOutcome` (`.edit` on click or Open, `.save` on Save, `.dismiss` on timeout or X) through a closure, then closes.
- `EditorWindowController.swift`: owns the non-activating panel, output actions in its title bar,
  and the floating controls. Reports a single `EditorOutcome` then closes. The close button
  discards, while Escape first leaves a popover or color inspection mode.
- `CanvasView.swift`: draws the document and maps pointer positions through the stage scale
  and backdrop padding. Color inspection samples source pixels and suppresses drawing.
- `EditorKeymap.swift`: pure mapping of physical keys and modifiers to editor actions.

Package dependency: `sindresorhus/KeyboardShortcuts` 3.x. Carbon hotkeys, no permission prompt, sandbox-safe, fires while an NSMenu is open.

## Event flow: hotkey to clipboard

1. **KeyboardShortcuts** emits `.keyUp` for `.captureArea`. Hotkeys calls `coordinator.capture(.area)`.
2. **Coordinator** guards `editor == nil && !isCapturing`, otherwise returns. Sets `isCapturing = true`.
3. **Capturer** runs `try await capture(.area)`. It owns the crosshair overlay, Esc inside selection, and the whole permission flow including the system prompt. Every cancel cause throws `CancellationError`, which returns the Coordinator to idle silently.
4. **PermissionAlert** renders `.denied` (points at System Settings) and `.grantedNeedsRelaunch` (offers Relaunch). `.notDetermined` stays silent because the system prompt is already on screen. Other `CaptureError` cases get a one-line alert. Coordinator resets `isCapturing` on every error path.
5. **Coordinator** receives `Shot`, sets `isCapturing = false`, calls `Output.copy(shot.image)` so the plain shot is on the pasteboard before anything is on screen, then calls the preview factory and stores `preview`. Most captures end here.
6. **PreviewWindowController** shows the card in the bottom-right corner of the shot's screen. On timeout or X it fades and reports `.dismiss`, and the Coordinator clears `preview`. On click or Open it closes at once and reports `.edit`. On Save it closes at once and reports `.save` so the Coordinator files the plain shot without opening the editor. The Coordinator clears `preview`, and for `.edit` builds `Document(shot:)`, calls the editor factory and stores `editor`.
7. **EditorWindowController** creates `EditorPanel` with a fitted stage, output actions in the title bar and editing controls floating at the bottom, centered on the shot and clamped to the visible frame. Move it by the title bar like any window. Sets level and collectionBehavior, then `makeKeyAndOrderFront(nil)`. Cursor is crosshair.
8. **CanvasView** draws flat documents directly and uses the document export renderer for backdrops. Mouse positions are converted to document coordinates, subtracting backdrop padding. Each action refreshes the controls. Backdrop transitions leave the window frame unchanged.
9. **EditorKeymap** maps A, N, R and B to drawing tools, K to backdrop, and I to color inspection. Cmd+Z and Shift+Cmd+Z change annotation history. Enter or Cmd+C copies, Cmd+S saves, and Escape first leaves inspection before discarding. Tab copies the sampled hex only when inspecting from the canvas.
10. **EditorWindowController** on `.commit`: `let image = try document.render()`, `orderOut`, `onFinish(.copy(image))`. On `.save`: same with `.saveAndCopy(image)`. On `.discard`: nothing rendered. A render failure surfaces as one alert.
11. **Coordinator** calls `Output.copy(image)` for `.copy`, replacing the plain shot with the annotated one. For `.saveAndCopy` it calls `try Output.save(image)` then `Output.copy(image)`, with one alert if save throws. Sets `editor = nil`.

## What the shell hides

**Preview card.** Borderless `NSPanel` with `.nonactivatingPanel`, `level = .floating`, the same `collectionBehavior` as the editor. A borderless panel cannot become key, so the click never moves focus and there are no key events to route. The hover tracking area uses `.activeAlways` so it fires in a window that is not key, and `.cursorUpdate` sets the pointing hand the same way, since cursor rects only refresh in key windows. Slide and fade go through `NSAnimationContext`, and `accessibilityDisplayShouldReduceMotion` drops the slide. The lifetime is a `Task` that is cancelled on hover and restarted on exit. When `PreviewHide` is `.manual` no lifetime starts and the card stays until Open, Save, X, or the next capture. Action clicks are plain mouse hit tests in the card view, not buttons, so focus never moves.

**Window class.** `EditorPanel: NSPanel`, `styleMask: [.titled, .closable, .nonactivatingPanel]`, `canBecomeKey = true`, `canBecomeMain = false`, `isFloatingPanel = true`, `hidesOnDeactivate = false`. A regular movable window with a title bar, so no `constrainFrameRect` override: the default clamp below the menu bar is what a window should do.

**Activation.** The editor never calls `NSApp.activate()`. A non-activating panel that can become key receives key events while the app stays inactive, Spotlight style, so closing it returns focus to the previous app with no hide or yield step. Fallback if keys ever fail to arrive: `NSApp.activate()` on show, and on close `NSApp.yieldActivation(to: previous)` then `previous.activate()`, with `previous` read from `NSWorkspace.shared.frontmostApplication` before showing. `activate(ignoringOtherApps:)` is deprecated on macOS 14 and its flag is ignored.

**Key equivalents.** `EditorPanel` routes editor shortcuts before normal responder dispatch, so they work while a toolbar button has focus. Unhandled keys keep native behavior. Tab is reserved for copying only when the canvas has focus in color inspection mode. The native preset popover handles its own focus and dismissal.

**Level and Spaces.** `level = .floating`, `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]`. `fullScreenAuxiliary` lets the panel join a full-screen app's Space, `canJoinAllSpaces` keeps it visible if the user switches Space mid-edit, `transient` and `ignoresCycle` keep it out of Mission Control and Cmd+backtick.

**Menu bar clamp.** The default `constrainFrameRect` applies: a windowed editor must stay below the menu bar, and the layout clamps the centered window into the visible frame.

**Coordinate contract with Document.** Points sent to `document.apply` are in the same space as the `CGContext` given to `document.draw(in:)`: CG-native, origin bottom-left, y up, units of points, image at `(0, 0, w, h)`. CanvasView keeps `isFlipped = false` so view points equal that space with no conversion. `render()` calls the same `draw(in:)` into a bitmap, so the base image and annotations have exactly one drawing site.

**Drawing strategy.** `draw(_ dirtyRect:)` on a layer-backed NSView, no custom CALayer tree. The Document's interface is a CGContext, so drawRect is the zero-cost adapter. A full redraw of a 5K shot per drag event costs a few milliseconds on Apple silicon. If a drag ever feels sluggish, the internal seam is a two-view split with the base image as `layer.contents` below and annotations in a transparent view above. That change stays inside CanvasView.

**Settings window.** LSUIElement apps activate unreliably on Sonoma under cooperative activation. `SettingsWindowController.show()` does `NSApp.setActivationPolicy(.regular)`, `makeKeyAndOrderFront`, `NSApp.activate()`. `windowWillClose` restores `.accessory`. A transient Dock icon while Settings is open is the price of a text field that reliably takes focus. `KeyboardShortcuts.Recorder` works inside NSHostingView, stores to UserDefaults itself and warns about menu and system conflicts.

**Launch at login.** `SMAppService.mainApp`. Status is read from the system every time, never cached, because the user can toggle it in System Settings. `.requiresApproval` shows a one-line hint with `SMAppService.openSystemSettingsLoginItems()`.

**Permission.** The shell makes no `CGPreflightScreenCaptureAccess` or `CGRequestScreenCaptureAccess` calls. Screen Recording cannot be granted in-process, and a fresh grant needs a relaunch, so the Capturer reports permission state on the thrown `CaptureError.permission` and the shell only renders it. During development every re-signed build resets the grant.

## Testable vs deliberately untested

Testable without windows, since the interface is the test surface:

- `Coordinator` state machine with fake Capturer, Output, preview factory and editor factory: capture copies once and shows the preview with no editor, `.edit` opens the editor on the same shot, `.dismiss` returns to idle, hotkey while the card is up replaces it, hotkey while editing is ignored, hotkey while capturing is ignored, cancel returns to idle, each `CaptureError` case maps to the right alert, save error surfaces once, editor cleared after every outcome.
- `PreviewLayout`: thumbnail fit never upscales, card keeps a minimum size, frame sits in the bottom-right corner.
- `EditorKeymap`: table test of keyCode + modifiers to EditorKey, including Enter vs Cmd+Enter and plain `a` vs Cmd+A.
- `LaunchAtLogin` with a protocol over `SMAppService` status, register and unregister.

Left untested on purpose and covered by a manual checklist: preview slide, fade and hover, panel level and Spaces behavior, key events reaching a non-activating panel, `constrainFrameRect`, activation policy switch, hotkey registration, the TCC dialog, drawRect pixel output. These are OS behaviors, and a test would only mock the thing under question.

## Trade-offs and gotchas

**Hotkey while the editor is open: ignored.** The guard in `Coordinator.capture` is the only place this is decided. A new shot would capture our own panel and drop unsaved annotations. A hotkey while only the preview card is up is different: nothing is unsaved, so the card is closed silently and the capture proceeds, which also keeps the card out of the new shot. Not chosen: `KeyboardShortcuts.disable` on open and `enable` on close, which passes the keystroke through to the frontmost app but adds a second piece of state to keep in sync.

**NSPanel over NSWindow.** Chosen for `.nonactivatingPanel`, which removes the activate and yield problem. Cost: `canBecomeMain` must be false and the panel cannot host a sheet. Neither is needed.

**`events(for:)` over `onKeyUp`.** The package marks the closure handlers deprecated in favor of the AsyncStream. Each stream runs in a `Task` owned by Hotkeys and cancelled on quit.

**Hotkey collisions with editor keys.** If the user records a bare letter as a hotkey, the Recorder allows it, and pressing it in the editor is swallowed by the Carbon hotkey before the panel sees it. Acceptable for a minimal app. The Recorder's conflict check covers menu and system shortcuts only.

**Accessory app activation is heuristic on Sonoma.** Forum reports show `activate()` succeeding only some of the time for accessory apps. The editor sidesteps this by never activating. The Settings window switches policy to `.regular` first.

Sources: KeyboardShortcuts readme and source (https://github.com/sindresorhus/KeyboardShortcuts), SMAppService (https://nilcoalescing.com/blog/LaunchAtLoginSetting/), borderless key windows and Esc (https://soff.es/blog/cancel-borderless-window), non-activating hotkey panels (https://ardentswift.com/posts/hotkey-window/, https://multi.app/blog/nailing-the-activation-behavior-of-a-spotlight-raycast-like-command-palette), collectionBehavior (https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct), Sonoma activation (https://developer.apple.com/forums/thread/739075, https://developer.apple.com/forums/thread/739524), screen capture permission (https://developer.apple.com/forums/thread/732726, https://github.com/nashaofu/xcap/issues/160).
