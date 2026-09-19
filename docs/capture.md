# Capture module

Produces a `Shot` for a dragged area or the active window. Hides ScreenCaptureKit (SCK), the
Screen Recording permission flow, the AppKit selection overlay and all screen geometry.

## 1. Interface

```swift
/// A captured bitmap plus the geometry needed to show it 1:1 on the right screen.
public struct Shot: Sendable {
    /// sRGB premultiplied BGRA. Invariant, checked in debug builds:
    /// pixel size == (frame.size * scale).rounded(). The point-to-pixel flips live here:
    /// `pixel(for:)` samples a document point, `pixelRect(for:)` maps a document rect.
    public let image: CGImage
    /// Backing scale of the display the shot was taken on (1.0 or 2.0). A shot lives on one
    /// display, so this equals the editor panel's backingScaleFactor at `frame`.
    public let scale: CGFloat
    /// Screen location in AppKit global points (y-up, origin at the main display's
    /// bottom-left), the space of NSScreen.frame, so the editor opens exactly here.
    /// Its size is the document's point grid.
    public let frame: CGRect
}

public enum PermissionState: Sendable, Equatable {
    /// Never asked. The system prompt was shown by the call that threw this.
    case notDetermined
    /// Refused or revoked. The prompt will not show again. Send the user to `settingsURL`.
    case denied
    /// TCC says granted but the running process cannot capture yet. Relaunch the app.
    case grantedNeedsRelaunch
    case granted
}

/// Every cancel cause (Esc, Task cancellation, drag under 2x2 pt, screens reconfigured or app
/// deactivated mid-drag, a newer capture(.area)) throws Swift's `CancellationError`.
public enum CaptureError: Error {
    /// Nothing captured. The state says what to tell the user.
    case permission(PermissionState)
    /// No normal-level on-screen window that is not ours (desktop only, or only our editor).
    case noWindow
    /// SCK failed for a non-permission reason. Rare. Show and move on.
    case failed(underlying: any Error)
}

@MainActor
public final class Capturer {
    public init()   // production adapters, keeps no windows alive between captures

    /// Deep link to System Settings > Privacy & Security > Screen & System Audio Recording.
    public static let settingsURL: URL   // x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture

    public enum Kind: Sendable { case area, activeWindow(includeShadow: Bool = true), fullScreen }

    /// .area: every display is captured first (the screen freezes), then a dimmed crosshair
    /// overlay shows the frozen pixels and the user drags on them. The shot is a crop of the
    /// frozen image, so hover states, tooltips and open menus survive the overlay taking the
    /// mouse and focus. Overlay up 50 to 150 ms after the call, result at mouse-up with no
    /// further capture. App activated (needed for Esc), previous app restored on cancel. A
    /// second .area call cancels the first and restarts. The selection is clamped to the
    /// display where the drag started.
    /// In .area, a click with no drag takes the window under the pointer instead of a region.
    /// .fullScreen: the whole display under the pointer, no UI, no overlay, one capture.
    /// .activeWindow: frontmost normal-level window that is not ours, as it is right now. No
    /// UI, no activation, 100 to 250 ms. includeShadow adds a transparent margin with the
    /// system shadow. Attached sheets and popovers are included. A window
    /// straddling displays is captured on the one holding most of it.
    /// Neither kind includes the cursor or our own windows.
    public func capture(_ kind: Kind) async throws -> Shot
}
```

Ordering for both kinds: SCK first, preflight and prompt only on SCK's permission error, so a
live grant works unchanged and a revocation while running is caught despite a stale preflight.

## 2. Usage from the app shell

```swift
@MainActor final class AppShell {
    private let capturer = Capturer()
    private var inFlight: Task<Void, Never>?

    func capture(_ kind: Capturer.Kind) {
        inFlight?.cancel()
        inFlight = Task {
            do { Editor.open(try await capturer.capture(kind)) }
            catch is CancellationError { }
            catch CaptureError.permission(let state) { PermissionAlert.show(state, capturer) }
            catch CaptureError.noWindow { Alert.show("No window to capture") }
            catch { Alert.show(error.localizedDescription) }
        }
    }
}
// PermissionAlert: .notDetermined stays silent (the system prompt is the UI). .denied -> button
// opening Capturer.settingsURL. .grantedNeedsRelaunch -> Relaunch.
```

## 3. What the implementation hides

**Freeze (area).** The overlay takes the mouse and focus the moment it appears, and the app
underneath reacts: browsers drop `:hover`, tooltips close, popovers dismiss. Capturing on
mouse-up therefore never contained them. Instead every display is captured in full before the
overlay exists (one `captureRegion` per display, in parallel, our app excluded, cursor off) and
the result is a `FrozenDisplay` per display. The overlay shows those pixels and the shot is
`CGImage.cropping(to:)` of the selection times scale (`CaptureGeometry.pixelRect`, whole
pixels, so the `Shot` frame is derived from the crop and the pixel invariant holds), redrawn
into a bitmap of its own because a bare crop only references the display image and would keep
all of it alive for the shot's lifetime. Shottr and CleanShot X work the same way. The cost is that the overlay appears after the capture returns,
50 to 150 ms after the hotkey, instead of within a frame.

**Overlay (area).** One borderless `NSWindow` subclass per `NSScreen`, frame = `screen.frame`,
`level = .screenSaver`, `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary,
.stationary, .ignoresCycle]`, non-opaque, no shadow, `canBecomeKey` true and
`animationBehavior = .none`, without which AppKit zooms the window in and the frozen screen
appears to jump and scale up as it settles. Menubar-only apps
get no key events until `NSApp.activate()`, so the module records the frontmost app,
activates, and re-activates it on cancel. The content view is layer-backed with the frozen
image as `layer.contents` (matched to the screen through `NSScreenNumber`), and an
`OverlayView` on top draws a 40% dim with the selection cut out, `NSCursor.crosshair`, a
size label and, before the drag starts, full-width and full-height guidelines through the
pointer, so a drag redraws only the dim. The drag itself is a `RubberBand` value: anchor and
tip in AppKit points clamped to the frame of the panel under mouse-down (the pointer on a display's
top edge sits outside `NSScreen.frame`), Shift squares it along the longer side (shrinking to
the room left) and reshapes the band the moment it is pressed or released, Space slides the
whole band and resizing resumes from the moved anchor. Esc, Space and Shift arrive via
`keyDown`, `keyUp` and `flagsChanged`. Mouse moves arrive through an always-active
`NSTrackingArea` per panel, since plain mouse-moved events reach the key window only. The
y flip uses `NSScreen.screens[0]`, the primary display, not `NSScreen.main`, which is the key
window's screen.

**Two coordinate spaces.** AppKit is y-up. SCK and `CGWindowListCopyWindowInfo` are y-down from
the main display's top-left, in points. One conversion: `cgY = mainDisplayHeight - appKitMaxY`.

**Area capture.** Each display is captured whole with
`SCContentFilter(display:excludingApplications:[us] exceptingWindows:[])`,
`sourceRect = display bounds`, `width/height = display.size * display.scale`,
`captureResolution = .best`, `showsCursor = false`. Excluding our app keeps the status item
and any of our windows out. The clamped selection S (CG space) becomes the crop
`(S - display.origin) * display.scale`. Mouse-up pays nothing.

**Active window.** `CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements])`
returns front-to-back order. The first entry with layer 0, alpha > 0, bounds at least 20x20 pt
and owner pid != ours wins, which stays correct while our own editor is frontmost. Both
shadow variants share one path: a display-style filter including the target plus same-app
on-screen windows in front of it that intersect its frame (sheets, popovers), `sourceRect` =
frame expanded by 64 pt and clamped, `ignoreShadowsDisplay = !includeShadow`,
`shouldBeOpaque = false`, clear background, `ignoreGlobalClipDisplay = true`. Trimming the
result to its opaque bounding box yields the exact frame including the shadow, which SCK
cannot report for `desktopIndependentWindow` filters.

**Permission.** On `SCStreamError.Code.userDeclined` (-3801) or an empty display list:
preflight true throws `.grantedNeedsRelaunch`, a `UserDefaults` "prompted" flag throws
`.denied`, otherwise `CGRequestScreenCaptureAccess()` (system dialog once, returns at once),
set the flag, throw `.notDetermined`.

**Cancellation.** The drag is a `CheckedContinuation` inside `withTaskCancellationHandler`.
Every cancel cause runs one teardown: release overlay windows, restore the previous app,
resume with `CancellationError` exactly once. The freeze captures are not interruptible, a
cancel during them drops the images and never opens the overlay.

## 4. Dependency strategy

Two seams, both internal (`init(backend:selector:)`), with `init()` wiring production.

**Port for SCK and permission** (true external, so a fake adapter is mandatory):

```swift
struct DisplayInfo: Sendable { let id: CGDirectDisplayID; let frame: CGRect /*CG pts*/; let scale: CGFloat }
struct WindowInfo: Sendable { let id: CGWindowID; let pid: pid_t; let layer: Int; let alpha: CGFloat
                              let frame: CGRect /*CG pts*/ }

protocol CaptureBackend: Sendable {
    func preflightPermission() -> Bool
    func requestPermission() -> Bool                 // shows the system prompt at most once
    func displays() async throws -> [DisplayInfo]    // throws BackendError.permissionDenied
    func onScreenWindowsFrontToBack() -> [WindowInfo]  // no permission needed for these fields
    func captureRegion(display: CGDirectDisplayID, rect: CGRect, scale: CGFloat,
                       only windows: [CGWindowID]?, excludingPID: pid_t?,
                       keepShadows: Bool) async throws -> CGImage
}
```

Production adapter `ScreenCaptureKitBackend` maps this onto `SCShareableContent
.excludingDesktopWindows(true, onScreenWindowsOnly: true)`, the two `SCContentFilter`
initialisers, one `SCStreamConfiguration` builder (points times scale to pixels),
`SCScreenshotManager.captureImage(contentFilter:configuration:)`, the two CG permission calls
and `CGWindowListCopyWindowInfo`. It is the only file importing SCK.

Fake adapter `FakeCaptureBackend` holds `displays`, `windows`, `preflight`, `promptResult`,
`failWithPermission`, renders a solid `CGImage` of `rect.size * scale` pixels and records calls.

**Seam for the selection UI** (in-process AppKit, but it blocks on a human):

```swift
struct FrozenDisplay { let display: DisplayInfo; let image: CGImage }
protocol AreaSelector {
    // `windows` are the pickable frames in CG points, front to back.
    func select(over displays: [FrozenDisplay], windows: [CGRect]) async throws -> CGRect /*CG pts*/
}
```

`OverlayAreaSelector` is the AppKit adapter above. `ScriptedAreaSelector` returns a preset rect,
throws, or suspends, and records what it was shown.

**Tests at the interface** (XCTest, `@MainActor`, no screen, no permission):

- area on a 2x display: one full-display capture before the selector, `scale 2`, crop pixels =
  points times 2, AppKit-space frame, our pid excluded
- every display is frozen and handed to the selector, the selection adds no capture call
- the crop lands on the right pixels (a marker painted by the fake shows up where expected)
- drag from a 2x display onto a 1x one: rect clamped to the 2x display, `scale 2`
- `RubberBand`: drag clamps to the display, Shift squares along the longer side and shrinks at
  the edge, toggling Shift reshapes the band at once, an origin outside the display starts on
  its edge, Space slides the band until it touches the edge and resizing resumes from there
- the area shot owns its pixels (row stride equals its width), so the frozen displays are freed
  on teardown
- area hands the selector the pickable windows, front to back, with ours, the wrong layer, the
  invisible and the tiny left out, and `frontmostWindow(containing:in:)` picks among them
- full screen captures the display under the pointer, falling back to the first display
- drag under 2x2 pt, Esc and Task cancellation each throw `CancellationError`, no overlay left,
  a cancel during the freeze never opens the selector
- second `capture(.area)` during a suspended first one: the first is cancelled, the second runs
- active window skips layer != 0, alpha 0, tiny and our own windows, passes companions and
  the shadow margin. Nothing eligible throws `.noWindow`
- permission matrix: SCK denied plus preflight true gives `.grantedNeedsRelaunch`, plus flag
  gives `.denied`, plus no flag prompts once and gives `.notDetermined`

## 5. Trade-offs and gotchas

**Leverage is high** in `Shot` (pixels = points times scale, AppKit-space frame, so the editor
and save path do zero geometry), in the freeze (hover states survive, the overlay previews the
exact shot, mouse-up is instant), in the single window path (shadow or not, sheets included)
and in the permission mapping that folds three CG and SCK signals into one enum. The
geometry rules (space flip, clamp, pixel crop, shadow margin, alpha trim) are pure
functions on `CaptureGeometry` and `Shot`.

**Leverage is thin** in the port's `captureRegion`, which lets SCK's shape (window allow-list,
shadow flag) through because it is one method and the fake stays trivial. Clamping to one
display rules out cross-display shots in exchange for a Shot that is always pixel-exact 1:1.
Lifting the clamp means per-display tiles composited at max scale, with no interface change.
The freeze holds one full bitmap per display for the length of the drag (about 60 MB for a
5K display), released on teardown.

**macOS gotchas (sources):**

- `SCStreamConfiguration.width/height` are pixels, `SCDisplay`, `contentRect` and `sourceRect`
  are points. Forgetting `pointPixelScale` gives blurry shots. https://developer.apple.com/forums/thread/739593
- No supported way to get a window's shadow extent (DTS, FB15370384 open), hence the margin
  and trim. https://developer.apple.com/forums/thread/765360
- `includeChildWindows` is 14.2+ (not needed, companions are listed explicitly).
  `captureImage(in:)` is 15.2+. `captureScreenshot` with `SCScreenshotConfiguration` is 26+.
  The 14 baseline uses `captureImage(contentFilter:configuration:)`.
  https://github.com/dotnet/macios/wiki/ScreenCaptureKit-macOS-xcode26.0-b1
- `CGRequestScreenCaptureAccess()` prompts only the first time and returns immediately. After
  a refusal it returns false silently, so the app opens System Settings. https://developer.apple.com/forums/thread/732726
- A fresh grant needs a relaunch on macOS 14 even though the preflight flips to true at once,
  hence `.grantedNeedsRelaunch`. https://developer.apple.com/documentation/ScreenCaptureKit/capturing-screen-content-in-macos
- macOS 15 re-asks monthly via a system dialog that can appear at capture time.
  https://9to5mac.com/2024/10/07/macos-sequoia-screen-recording-popups/
- macOS 15 ignores grants for ad-hoc signed binaries, so debug builds need a real Developer
  ID. https://github.com/CapSoftware/Cap/issues/1722
- `SCWindow.frame` and CG bounds are y-down from the main display's top-left, the opposite of
  NSScreen. https://blog.eusoftbank.com/en/2024/10/transform-scwindow-coordinate/
- `CGWindowListCopyWindowInfo` is front-to-back only with `.optionOnScreenOnly`, current Space
  only. https://developer.apple.com/forums/thread/713113
- Exclude our own app in the filter instead of hiding the overlay and waiting a frame.
  https://charleswiltgen.github.io/Axiom/skills/macos/screencapturekit
