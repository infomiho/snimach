# Output

Delivers a flattened Retina shot to the general pasteboard or to a PNG file in `~/Pictures/Snimach`. Two entry points, no UI, no AppKit views. The app is not sandboxed.

## Interface

```swift
import AppKit
import CoreGraphics

/// Delivers a flattened shot to the pasteboard or to disk.
///
/// Configuration is the whole seam: pass a different folder, pasteboard or clock and the
/// module behaves identically against them. There is no protocol to implement.
///
/// Thread: main thread. Both methods are synchronous and return only when the side effect
/// is complete, so the caller may close the editor immediately afterwards.
///
/// Performance (M2 Pro, synthetic image, real screenshots compress somewhat worse):
///   1200x800: PNG 7 ms, LZW TIFF 13 ms.  2880x1800: PNG 33 ms, TIFF 69 ms.
///   5120x2880: PNG 94 ms, TIFF 190 ms. `copy` encodes only the PNG and promises the TIFF,
///   so it stays under about 100 ms even for a 5K display, like `save`. The PNG encoded for
///   the most recent image and scale is kept, so `save` followed by `copy` of the same image
///   encodes PNG once. The pasteboard keeps the last copied image until a reader asks for its
///   TIFF or the pasteboard changes.
final class ShotOutput {

    /// `~/Pictures/Snimach`. ~/Pictures is not TCC-protected, so writing there never
    /// triggers a Files and Folders prompt. See "Why ~/Pictures and no sandbox" below.
    static let defaultFolder: URL

    /// - Parameters:
    ///   - folder: where `save` writes, read on every save because the user can change it
    ///     while the app runs. Created on first save if missing, intermediates too.
    ///   - pasteboard: where `copy` writes. Tests pass `NSPasteboard(name:)`.
    ///   - now: clock for filenames. Tests pass a fixed date.
    init(folder: @escaping () -> URL = { defaultFolder },
         pasteboard: NSPasteboard = .general,
         now: @escaping () -> Date = Date.init)

    /// Replaces the pasteboard contents with the shot.
    ///
    /// Invariants after return:
    ///   - The pasteboard holds exactly one item declaring `public.png` and `public.tiff`,
    ///     both carrying DPI = 72 * scale. The TIFF is encoded on the first read. AppKit
    ///     readers (Mail, Preview, Xcode, Notes) paste at `image.width / scale` points. Chromium readers (Slack, Notion, Chrome, Figma
    ///     desktop) receive the PNG bytes with the pHYs chunk intact.
    ///   - Previous contents are gone, even on failure.
    /// - Parameters:
    ///   - image: the flattened bitmap, pixel dimensions.
    ///   - scale: backing scale of the shot (1, 2 or 3). Must be > 0.
    /// - Throws: `ShotOutputError.encodingFailed` if ImageIO refuses the image. Not expected
    ///   for the 8-bit sRGB bitmaps the document module emits.
    func copy(_ image: CGImage, scale: CGFloat) throws

    /// Writes the shot as PNG and returns the file written.
    ///
    /// Invariants:
    ///   - Never overwrites. Name is `Snimach <yyyy-MM-dd> at <HH.mm.ss>.png`. On collision
    ///     ` (2)`, ` (3)` and so on are appended. Collision is decided by the OS at open time
    ///     (O_EXCL semantics), not by a stat-then-write race.
    ///   - The folder is created if missing, with intermediate directories.
    ///   - The file carries DPI = 72 * scale in its pHYs chunk, so Preview and Finder show
    ///     the logical size.
    ///   - Either the returned URL exists with complete contents, or an error is thrown and
    ///     no partial file remains. The data is fully encoded before the file is opened.
    /// - Throws: `ShotOutputError.folderUnavailable` (cannot create or not writable),
    ///   `.writeFailed` (disk full, permission, more than 99 collisions in one second),
    ///   `.encodingFailed`.
    @discardableResult
    func save(_ image: CGImage, scale: CGFloat) throws -> URL

    /// Writes the shot to a temporary PNG so it can be dragged out as a real file. The name
    /// is what the receiving app shows, so it matches the save folder's naming.
    func temporaryPNG(_ image: CGImage, scale: CGFloat) throws -> URL

    /// The capture path's drag: a Shot carries its own scale, so callers never re-pair it.
    func temporaryPNG(_ shot: Shot) throws -> URL
}

enum ShotOutputError: Error {
    case encodingFailed
    case folderUnavailable(URL, underlying: Error)
    case writeFailed(URL, underlying: Error)
}
```

Nothing else is public. A `CGImage` carries no point size, so the scale is passed explicitly.
Where the source is a captured `Shot`, the scale comes with it: the shell's `OutputService`
protocol extension offers `copy(_ shot:)` and `save(_ shot:)` so the pairing is typed once.

## Usage

```swift
let output = ShotOutput()

// Enter or Cmd+C
func editorDidCommit(_ flattened: CGImage, scale: CGFloat) {
    try? output.copy(flattened, scale: scale)   // failure is not actionable, log it
    editor.close()
}

// Cmd+S: save, then copy. The second call reuses the PNG encoded by the first.
func editorDidSave(_ flattened: CGImage, scale: CGFloat) {
    do {
        let url = try output.save(flattened, scale: scale)
        try output.copy(flattened, scale: scale)
        hud.flash("Saved to \(url.deletingLastPathComponent().lastPathComponent)")
    } catch {
        hud.flash("Couldn’t save: \(error.localizedDescription)")
    }
}
```

## What the implementation hides

- **Pasteboard type set.** `NSImage.writeObjects` declares only `public.tiff`, and an uncompressed TIFF is two orders of magnitude larger than the PNG of the same bitmap. Chromium reads images through `NSImage(pasteboard:)` and prefers `public.png` when present, and Chromium apps themselves write both `public.png` and `public.tiff` ([Chromium clipboard_mac.mm](https://chromium.googlesource.com/chromium/src/+/master/ui/base/clipboard/clipboard_mac.mm), [claude-code #30934](https://github.com/anthropics/claude-code/issues/30934)). The implementation builds one `NSPasteboardItem`, calls `setData` for `.png` and `setDataProvider` for `.tiff`, and writes it with `writeObjects`. Most readers take the PNG, so the TIFF, twice the PNG's encode time, is only paid for when a reader asks. AppKit adds the legacy `Apple PNG pasteboard type` and `NeXT TIFF v4.0 pasteboard type` aliases itself.
- **DPI metadata.** PNG is encoded with `CGImageDestination` and `kCGImagePropertyDPIWidth/Height = 72 * scale`, which produces a pHYs chunk that `NSImage` decodes at logical point size. TIFF goes through `NSBitmapImageRep(cgImage:)` with `size` set to points, then `tiffRepresentation(using: .lzw, factor: 0)`, which stores the same resolution. Figma honors 144 DPI and places the image at 1x ([Figma forum](https://forum.figma.com/t/retina-images-and-screenshots-no-longer-pasting-or-importing-2x/25232)). Slack and Notion ignore DPI and scale to their layout, which is what users expect there.
- **Never routes through `NSImage(cgImage:size:)`.** That path yields an `NSCGImageSnapshotRep` and has a known double-sizing bug on mixed-DPI setups ([gist](https://gist.github.com/jaz303/b0e73bc2effe71283b5c), [Apple forums](https://developer.apple.com/forums/thread/103621)).
- **One encoder.** A private `encodePNG(image, scale) throws -> Data` produces the PNG bytes for both the pasteboard and the file, and the result for the most recent image and scale is cached. Internal seam, tested only through `copy` and `save`.
- **Filename scheme.** `Snimach yyyy-MM-dd at HH.mm.ss.png` with an `en_US_POSIX` formatter in the local time zone. Sorts chronologically in Finder and contains nothing that needs escaping in Slack or a terminal.
- **Folder creation and collisions.** `createDirectory(withIntermediateDirectories: true)`, then `Data.write(to:options: .withoutOverwriting)`, which fails with `CocoaError.fileWriteFileExists` (516) instead of clobbering ([Apple docs](https://developer.apple.com/documentation/foundation/nsdata/writingoptions/withoutoverwriting)). On 516 the suffix increments and the write retries. `.withoutOverwriting` cannot be combined with `.atomic`, which is why the whole file is encoded before opening.

## Dependencies and tests

Both dependencies are local-substitutable by instance rather than by protocol. The production and test adapters are the same class pointed at a different name or path, so a port would be a one-adapter seam and there is none.

- **Pasteboard.** `NSPasteboard(name: NSPasteboard.Name("dev.twoducks.snimach.test.\(UUID())"))` works in a plain process without `NSApplication`. Tests call `releaseGlobally()` in teardown ([Apple docs](https://developer.apple.com/documentation/appkit/nspasteboard/init(name:))).
- **Filesystem.** A fresh subfolder of `FileManager.default.temporaryDirectory` per test, removed in teardown.
- **Clock.** The injected `now` closure, fixed in tests.

Tests at the interface, XCTest, no mocks:

1. `copy` declares `public.png` and `public.tiff` on a single item, and `NSImage(pasteboard:)` reports `size == pixels / scale` for scale 1, 2 and 3.
2. `copy` PNG bytes decode via `CGImageSource` to `DPIWidth == 72 * scale` and the original pixel dimensions.
3. `copy` TIFF resolves on read to the original pixel dimensions at `size == pixels / scale`.
4. `copy` twice: only the second shot is present, `changeCount` advanced, one item.
5. `save` into a missing nested folder creates it and returns a file that decodes to identical pixels.
6. `save` twice with the same fixed clock yields `... .png` and `... (2).png`, both present, the first unchanged.
7. `save` where `folder` sits under a read-only directory throws `folderUnavailable`.
8. `save` then `copy` of the same image: pasteboard PNG bytes equal the file bytes.

## Trade-offs

- **Depth.** Two methods with two parameters each hide type negotiation, DPI, two encoders, naming, folder creation and race-free collision handling. Deleting the module would spread pasteboard type knowledge into the editor and file naming into the shell.
- **Promised TIFF.** Eager LZW costs an extra encode, 190 ms at 5K, on every copy, before the preview appears. Raw TIFF encodes in 20 ms but puts 56 MB on the pasteboard. Promising it instead keeps the last copied image alive until a reader asks or the pasteboard changes. Quitting normally encodes it first. A crash before any read leaves the TIFF type holding empty data, while the PNG, which nearly every reader takes, stays intact.
- **Synchronous.** Guarantees the paste target sees the data the instant the editor closes. The cost is a short main-thread stall on huge shots. An async variant would need a "copy pending" state in the shell for no user-visible gain.
- **Confirmation lives in the shell.** `copy` needs none, the editor closing is the feedback. `save` returns the URL and the shell shows a brief HUD. A `UNUserNotification` would add a permission prompt and Notification Center clutter for a rarely used path. Keeping UI out keeps the module testable without a window.

## Why ~/Pictures and no sandbox

The sandbox is mandatory only for the Mac App Store. A Developer ID app needs Hardened Runtime and notarization but not the sandbox ([Apple, App Sandbox](https://developer.apple.com/documentation/security/app-sandbox), [Eclectic Light](https://eclecticlight.co/2023/06/24/explainer-the-app-sandbox/)). Screen capture already requires the Screen Recording grant either way, so the sandbox buys no user-visible trust and would add a second system to manage. Unsandboxed, `~/Desktop`, `~/Documents` and `~/Downloads` are TCC "Files and Folders" protected and prompt on first write, while `~/Pictures` is not in that set ([Eclectic Light, TCC](https://eclecticlight.co/2025/11/08/explainer-permissions-privacy-and-tcc/)). Hence `~/Pictures/Snimach`: zero prompts. If the app ever moves to the App Store, the only change is adding `com.apple.security.assets.pictures.read-write` ([entitlement list](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.assets.pictures.read-write)). The sandbox has no Desktop entitlement at all, which would require a user-selected folder plus a security-scoped bookmark, another reason to stay in `~/Pictures`.
