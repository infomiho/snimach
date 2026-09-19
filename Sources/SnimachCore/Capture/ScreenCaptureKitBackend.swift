import CoreGraphics
import ScreenCaptureKit

/// The only file that imports ScreenCaptureKit. Maps the `CaptureBackend` port onto SCK and the
/// two CG permission calls.
final class ScreenCaptureKitBackend: CaptureBackend {
    func preflightPermission() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    func requestPermission() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    func displays() async throws -> [DisplayInfo] {
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
        } catch let error as SCStreamError where error.code == .userDeclined {
            throw BackendError.permissionDenied
        }
        guard !content.displays.isEmpty else { throw BackendError.permissionDenied }

        return content.displays.map { display in
            let bounds = CGDisplayBounds(display.displayID)
            // `CGDisplayPixelsWide` reports logical points on current macOS, which captures at
            // half resolution on Retina. The display mode carries the physical pixels instead.
            let modeWidth = CGDisplayCopyDisplayMode(display.displayID).map { CGFloat($0.pixelWidth) }
            let scale = bounds.width > 0 ? (modeWidth ?? bounds.width) / bounds.width : 1
            return DisplayInfo(id: display.displayID, frame: bounds, scale: scale)
        }
    }

    func onScreenWindowsFrontToBack() -> [WindowInfo] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        return list.compactMap { info in
            guard let number = info[kCGWindowNumber as String] as? NSNumber,
                  let owner = info[kCGWindowOwnerPID as String] as? NSNumber,
                  let layer = info[kCGWindowLayer as String] as? NSNumber,
                  let bounds = info[kCGWindowBounds as String] as? [String: Any],
                  let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary)
            else { return nil }
            let alpha = (info[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1
            return WindowInfo(
                id: CGWindowID(truncating: number),
                pid: pid_t(owner.int32Value),
                layer: layer.intValue,
                alpha: CGFloat(alpha),
                frame: frame
            )
        }
    }

    func captureRegion(display id: CGDirectDisplayID,
                       rect: CGRect,
                       scale: CGFloat,
                       only windows: [CGWindowID]?,
                       excludingPID: pid_t?,
                       keepShadows: Bool,
                       showsCursor: Bool) async throws -> CGImage {
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
        } catch let error as SCStreamError where error.code == .userDeclined {
            throw BackendError.permissionDenied
        }
        guard let display = content.displays.first(where: { $0.displayID == id }) else {
            throw BackendError.permissionDenied
        }

        let filter: SCContentFilter
        if let windows {
            let included = content.windows.filter { windows.contains($0.windowID) }
            filter = SCContentFilter(display: display, including: included)
        } else {
            let excluded = excludingPID.map { pid in
                content.applications.filter { $0.processID == pid }
            } ?? []
            filter = SCContentFilter(
                display: display,
                excludingApplications: excluded,
                exceptingWindows: []
            )
        }

        let configuration = SCStreamConfiguration()
        configuration.sourceRect = rect
        configuration.width = Int((rect.width * scale).rounded())
        configuration.height = Int((rect.height * scale).rounded())
        configuration.captureResolution = .best
        configuration.showsCursor = showsCursor
        configuration.shouldBeOpaque = false
        configuration.ignoreGlobalClipDisplay = true
        configuration.ignoreShadowsDisplay = !keepShadows
        let clear = CGColor(gray: 0, alpha: 0)
        configuration.backgroundColor = clear

        do {
            return try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
            )
        } catch let error as SCStreamError where error.code == .userDeclined {
            throw BackendError.permissionDenied
        }
    }
}
