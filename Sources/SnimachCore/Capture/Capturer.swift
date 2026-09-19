import CoreGraphics
import Foundation

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
/// deactivated mid-drag, a newer `capture(.area)`) throws Swift's `CancellationError`.
public enum CaptureError: Error {
    case permission(PermissionState)
    case noWindow
    case failed(underlying: any Error)
}

extension CaptureError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .permission: return "Snimach needs Screen Recording permission."
        case .noWindow: return "No window to capture."
        case .failed(let underlying): return underlying.localizedDescription
        }
    }
}

@MainActor
public final class Capturer {
    /// Deep link to System Settings > Privacy & Security > Screen & System Audio Recording.
    public static let settingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
    )!

    private let backend: CaptureBackend
    private let selector: AreaSelector
    private let hasPrompted: () -> Bool
    private let markPrompted: () -> Void
    private let pointerLocation: () -> CGPoint
    private let includesPointer: () -> Bool

    /// Production adapters. Keeps no windows alive between captures.
    /// `includesPointer` is read on every capture, so the setting takes effect at once.
    public convenience init(includesPointer: @escaping () -> Bool = { false }) {
        self.init(
            backend: ScreenCaptureKitBackend(),
            selector: OverlayAreaSelector(),
            hasPrompted: { UserDefaults.standard.bool(forKey: Self.promptedKey) },
            markPrompted: { UserDefaults.standard.set(true, forKey: Self.promptedKey) },
            pointerLocation: { ScreenPointer.current() },
            includesPointer: includesPointer
        )
    }

    init(backend: CaptureBackend,
         selector: AreaSelector,
         hasPrompted: @escaping () -> Bool,
         markPrompted: @escaping () -> Void,
         pointerLocation: @escaping () -> CGPoint,
         includesPointer: @escaping () -> Bool = { false }) {
        self.backend = backend
        self.selector = selector
        self.hasPrompted = hasPrompted
        self.markPrompted = markPrompted
        self.pointerLocation = pointerLocation
        self.includesPointer = includesPointer
    }

    private static let promptedKey = "dev.twoducks.snimach.permissionPrompted"

    /// Permission snapshot, no prompt, no side effects. Enables the shell's Relaunch button.
    public var permissionState: PermissionState {
        if backend.preflightPermission() { return .granted }
        return hasPrompted() ? .denied : .notDetermined
    }

    public enum Kind: Sendable {
        case area
        case activeWindow(includeShadow: Bool = true)
        /// The whole display under the pointer.
        case fullScreen
    }

    public func capture(_ kind: Kind) async throws -> Shot {
        switch kind {
        case .area:
            return try await captureArea()
        case .activeWindow(let includeShadow):
            return try await captureActiveWindow(includeShadow: includeShadow)
        case .fullScreen:
            return try await captureFullScreen()
        }
    }

    // MARK: - Area

    private func captureArea() async throws -> Shot {
        let displays = try await loadDisplays()
        let mainHeight = CaptureGeometry.mainDisplayHeight(in: displays)

        // The overlay takes the mouse and focus, which clears hover states, tooltips and open
        // popovers in the app underneath. Freezing every display before it appears keeps them.
        let frozen = try await freeze(displays)
        try Task.checkCancellation()

        let pickable = Self.pickable(in: backend.onScreenWindowsFrontToBack(), ownPID: getpid())
        let selection = try await withTaskCancellationHandler {
            try await selector.select(over: frozen, windows: pickable.map(\.frame))
        } onCancel: {
            Task { @MainActor in self.selector.cancel() }
        }
        try Task.checkCancellation()

        guard selection.width >= Self.minimumSelection, selection.height >= Self.minimumSelection,
              let display = CaptureGeometry.displayHoldingMost(of: selection, in: displays),
              let source = frozen.first(where: { $0.display.id == display.id })
        else {
            throw CancellationError()
        }

        let localRect = selection.offsetBy(dx: -display.frame.origin.x, dy: -display.frame.origin.y)
        let pixels = CaptureGeometry.pixelRect(localRect, scale: display.scale, in: source.image)
        guard pixels.width > 0, pixels.height > 0,
              let image = Self.detachedCrop(of: source.image, to: pixels)
        else {
            throw CancellationError()
        }

        let frameCG = CGRect(
            x: display.frame.minX + pixels.minX / display.scale,
            y: display.frame.minY + pixels.minY / display.scale,
            width: pixels.width / display.scale,
            height: pixels.height / display.scale
        )
        return Shot(
            image: image,
            scale: display.scale,
            frame: CaptureGeometry.appKitFrame(frameCG, mainDisplayHeight: mainHeight),
            hasAlpha: false
        )
    }

    /// `cropping(to:)` only references the source, so the shot would keep the whole frozen
    /// display alive for as long as it exists. Redrawing gives the shot pixels of its own.
    private static func detachedCrop(of image: CGImage, to pixels: CGRect) -> CGImage? {
        guard let crop = image.cropping(to: pixels) else { return nil }
        let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue
            | CGBitmapInfo.byteOrder32Little.rawValue
        guard let context = CGContext(
            data: nil,
            width: crop.width,
            height: crop.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }
        context.interpolationQuality = .none
        context.draw(crop, in: CGRect(x: 0, y: 0, width: crop.width, height: crop.height))
        return context.makeImage()
    }

    /// Captures every display at once, our own windows excluded, in the order of `displays`.
    private func freeze(_ displays: [DisplayInfo]) async throws -> [FrozenDisplay] {
        let unordered = try await withThrowingTaskGroup(of: FrozenDisplay.self) { group in
            for display in displays {
                group.addTask {
                    let image = try await self.capture(
                        display: display,
                        rect: CGRect(origin: .zero, size: display.frame.size),
                        only: nil,
                        excludingPID: getpid(),
                        keepShadows: false
                    )
                    return FrozenDisplay(display: display, image: image)
                }
            }
            var frozen: [FrozenDisplay] = []
            for try await item in group { frozen.append(item) }
            return frozen
        }
        return displays.compactMap { display in
            unordered.first { $0.display.id == display.id }
        }
    }

    // MARK: - Full screen

    private func captureFullScreen() async throws -> Shot {
        let displays = try await loadDisplays()
        let mainHeight = CaptureGeometry.mainDisplayHeight(in: displays)
        let pointer = pointerLocation()
        guard let display = CaptureGeometry.displayContaining(pointer, in: displays)
            ?? displays.first
        else {
            throw permissionError()
        }

        let image = try await capture(
            display: display,
            rect: CGRect(origin: .zero, size: display.frame.size),
            only: nil,
            excludingPID: getpid(),
            keepShadows: false
        )
        try Task.checkCancellation()

        return Shot(
            image: image,
            scale: display.scale,
            frame: CaptureGeometry.appKitFrame(display.frame, mainDisplayHeight: mainHeight),
            hasAlpha: false
        )
    }

    // MARK: - Active window

    private func captureActiveWindow(includeShadow: Bool) async throws -> Shot {
        let displays = try await loadDisplays()
        let mainHeight = CaptureGeometry.mainDisplayHeight(in: displays)
        let windows = backend.onScreenWindowsFrontToBack()

        guard let target = Self.target(in: windows, ownPID: getpid()),
              let display = CaptureGeometry.displayHoldingMost(of: target.frame, in: displays)
        else {
            throw CaptureError.noWindow
        }

        let companions = Self.companions(of: target, in: windows)
        let captureRect = CaptureGeometry.expanded(
            target.frame,
            by: Self.shadowMargin,
            clampedTo: display.frame
        )
        let localRect = captureRect.offsetBy(
            dx: -display.frame.origin.x,
            dy: -display.frame.origin.y
        )
        let image = try await capture(
            display: display,
            rect: localRect,
            only: [target.id] + companions.map(\.id),
            excludingPID: nil,
            keepShadows: includeShadow
        )
        try Task.checkCancellation()

        let trimmed = CaptureGeometry.opaqueBoundingBox(of: image)
        let trimRect = trimmed ?? CGRect(
            x: 0,
            y: 0,
            width: CGFloat(image.width),
            height: CGFloat(image.height)
        )
        let output = trimmed.flatMap { image.cropping(to: $0) } ?? image
        let frameCG = CGRect(
            x: captureRect.minX + trimRect.minX / display.scale,
            y: captureRect.minY + trimRect.minY / display.scale,
            width: trimRect.width / display.scale,
            height: trimRect.height / display.scale
        )

        return Shot(
            image: output,
            scale: display.scale,
            frame: CaptureGeometry.appKitFrame(frameCG, mainDisplayHeight: mainHeight),
            hasAlpha: includeShadow
        )
    }

    /// Normal-level, visible, big enough and not ours. Front to back.
    static func pickable(in windows: [WindowInfo], ownPID: pid_t) -> [WindowInfo] {
        windows.filter { window in
            window.layer == 0
                && window.alpha > 0
                && window.frame.width >= 20
                && window.frame.height >= 20
                && window.pid != ownPID
        }
    }

    static func target(in windows: [WindowInfo], ownPID: pid_t) -> WindowInfo? {
        pickable(in: windows, ownPID: ownPID).first
    }

    /// Same-app windows in front of the target that intersect it: sheets and popovers.
    static func companions(of target: WindowInfo, in windows: [WindowInfo]) -> [WindowInfo] {
        guard let index = windows.firstIndex(where: { $0.id == target.id }) else { return [] }
        return windows[..<index].filter {
            $0.pid == target.pid && $0.frame.intersects(target.frame)
        }
    }

    // MARK: - Shared

    private func loadDisplays() async throws -> [DisplayInfo] {
        try await runBackend { try await backend.displays() }
    }

    private func capture(display: DisplayInfo,
                         rect: CGRect,
                         only windows: [CGWindowID]?,
                         excludingPID: pid_t?,
                         keepShadows: Bool) async throws -> CGImage {
        try await runBackend {
            try await backend.captureRegion(
                display: display.id,
                rect: rect,
                scale: display.scale,
                only: windows,
                excludingPID: excludingPID,
                keepShadows: keepShadows,
                showsCursor: includesPointer()
            )
        }
    }

    private func runBackend<T>(_ work: () async throws -> T) async throws -> T {
        do {
            return try await work()
        } catch BackendError.permissionDenied {
            throw permissionError()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw CaptureError.failed(underlying: error)
        }
    }

    private func permissionError() -> CaptureError {
        if backend.preflightPermission() { return .permission(.grantedNeedsRelaunch) }
        if hasPrompted() { return .permission(.denied) }
        _ = backend.requestPermission()
        markPrompted()
        return .permission(.notDetermined)
    }

    private static let minimumSelection: CGFloat = 2
    private static let shadowMargin: CGFloat = 64
}
