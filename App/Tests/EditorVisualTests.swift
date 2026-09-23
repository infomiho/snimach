import AppKit
import ScreenCaptureKit
import SnimachCore
import XCTest
@testable import Snimach

@MainActor
final class EditorVisualTests: XCTestCase {
    func testEditorScreenshots() async throws {
        let scenarios: [(String, NSAppearance.Name, CGSize, Bool, Bool, Bool)] = [
            ("01-dark-default", .darkAqua, CGSize(width: 936, height: 596), false, false, false),
            ("02-dark-backdrop", .darkAqua, CGSize(width: 936, height: 596), true, false, false),
            ("03-dark-presets", .darkAqua, CGSize(width: 936, height: 596), true, true, false),
            ("04-dark-picker", .darkAqua, CGSize(width: 936, height: 596), true, false, true),
            ("05-dark-compact", .darkAqua, CGSize(width: 360, height: 300), true, false, true),
            ("06-dark-short", .darkAqua, CGSize(width: 700, height: 280), false, false, false),
            ("07-light-default", .aqua, CGSize(width: 936, height: 596), false, false, false),
            ("08-light-picker", .aqua, CGSize(width: 560, height: 400), true, false, true),
            ("09-dark-presets-off", .darkAqua, CGSize(width: 936, height: 596), false, true, false),
        ]
        for (name, appearance, size, backdrop, presets, picker) in scenarios {
            let controller = EditorWindowController(document: try EditorFixture.document())
            controller.panel.appearance = NSAppearance(named: appearance)
            controller.panel.setContentSize(size)
            controller.panel.center()
            controller.show()
            defer { controller.close() }
            if backdrop { controller.accessoryBar.backdropButton.performClick(nil) }
            if picker { controller.accessoryBar.pickerButton.performClick(nil) }
            controller.panel.contentView?.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(350))
            if presets {
                // Screenshots need the popover up, deterministically. The transient behavior
                // auto-dismisses on app deactivation, which the test host does on its own
                // schedule, so screenshots pin it open; dismissal policy is covered by
                // testPresetPopoverOpensAndSelectionDismissesIt, which keeps production behavior.
                controller.backdropPopover.behavior = .applicationDefined
                controller.accessoryBar.presetsButton.performClick(nil)
                for _ in 0..<100 where !controller.backdropPopover.isShown {
                    try await Task.sleep(for: .milliseconds(50))
                }
                XCTAssertTrue(controller.backdropPopover.isShown)
                // Let any in-flight show animation finish so the snapshot is representative.
                try await Task.sleep(for: .milliseconds(300))
            }
            let windows = [controller.panel] + (presets ? [try XCTUnwrap(controller.backdropPicker.window)] : [])
            let snapshot = try await EditorSnapshot.capture(windows)
            let attachment = XCTAttachment(image: snapshot.image)
            attachment.name = "\(name)-\(snapshot.method).png"
            attachment.lifetime = .keepAlways
            add(attachment)
            assertControlsFit(controller)
        }
    }

    private func assertControlsFit(_ controller: EditorWindowController) {
        let content = controller.panel.contentView!
        let bar = controller.accessoryBar
        XCTAssertTrue(content.bounds.contains(bar.frame))
        let controls = bar.subviews.compactMap { $0 as? NSButton }.filter { !$0.isHidden }
        for control in controls {
            XCTAssertTrue(bar.bounds.contains(control.frame), control.toolTip ?? "Button")
            XCTAssertGreaterThanOrEqual(control.frame.width, 24)
            XCTAssertGreaterThanOrEqual(control.frame.height, 24)
        }
        let orderedControls = controls.sorted { $0.frame.minX < $1.frame.minX }
        for pair in zip(orderedControls, orderedControls.dropFirst()) {
            XCTAssertLessThanOrEqual(pair.0.frame.maxX, pair.1.frame.minX)
        }
        if !controller.readout.isHidden {
            XCTAssertTrue(content.bounds.contains(controller.readout.frame))
            XCTAssertGreaterThan(controller.readout.frame.minY, bar.frame.maxY)
        }
    }
}

@MainActor
private enum EditorFixture {
    static func document() throws -> Document {
        let size = CGSize(width: 900, height: 560)
        let context = try XCTUnwrap(CGContext(data: nil, width: 1800, height: 1120, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.scaleBy(x: 2, y: 2)
        let graphics = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphics
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSColor(calibratedWhite: 0.96, alpha: 1).setFill()
        NSBezierPath(rect: CGRect(origin: .zero, size: size)).fill()
        NSColor(calibratedWhite: 0.91, alpha: 1).setFill()
        NSBezierPath(rect: CGRect(x: 0, y: 0, width: 190, height: 560)).fill()
        text("Field notes", at: CGPoint(x: 24, y: 507), size: 18, weight: .semibold)
        for (index, title) in ["Overview", "Capture", "Editor", "Export"].enumerated() {
            text(title, at: CGPoint(x: 24, y: 450 - index * 38), size: 14)
        }
        text("A quieter workspace", at: CGPoint(x: 226, y: 492), size: 28, weight: .semibold)
        text("Design notes / September 2026", at: CGPoint(x: 226, y: 458), size: 13)
        for (index, title) in ["Capture what matters", "Keep the image in focus", "Make every action clear"].enumerated() {
            let y = 375 - index * 108
            text(title, at: CGPoint(x: 226, y: y), size: 17, weight: .semibold)
            text("Simple controls, thoughtful spacing, room to work.", at: CGPoint(x: 226, y: y - 29), size: 14)
            NSColor(calibratedWhite: 0.85, alpha: 1).setFill()
            NSBezierPath(rect: CGRect(x: 226, y: y - 52, width: 638, height: 1)).fill()
        }
        text("All changes saved", at: CGPoint(x: 226, y: 16), size: 12)
        text("900 × 560", at: CGPoint(x: 810, y: 16), size: 12)
        let image = try XCTUnwrap(context.makeImage())
        let shot = Shot(image: image, scale: 2, frame: CGRect(x: 100, y: 100, width: 900, height: 560))
        var document = Document(shot: shot)
        document.apply(.backdropPresetSelected(BackdropPreset.preset(.sierra7)))
        document.apply(.pointerDown(CGPoint(x: 720, y: 255)))
        document.apply(.pointerUp(CGPoint(x: 600, y: 372)))
        return document
    }

    private static func text(_ value: String, at point: CGPoint, size: CGFloat, weight: NSFont.Weight = .regular) {
        (value as NSString).draw(at: point, withAttributes: [
            .font: NSFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: NSColor(calibratedWhite: 0.22, alpha: 1),
        ])
    }
}

@MainActor
private enum EditorSnapshot {
    struct Capture {
        let image: NSImage
        let method: String
    }

    static func capture(_ windows: [NSWindow]) async throws -> Capture {
        if CGPreflightScreenCaptureAccess() {
            return Capture(image: try await windowImage(windows), method: "screen")
        }
        return Capture(image: try viewImage(windows), method: "appkit")
    }

    private static func windowImage(_ windows: [NSWindow]) async throws -> NSImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let ids = windows.map { CGWindowID($0.windowNumber) }
        let included = content.windows.filter { ids.contains($0.windowID) }
        XCTAssertEqual(included.count, windows.count)
        let rect = included.reduce(CGRect.null) { $0.union($1.frame) }
        let display = try XCTUnwrap(content.displays.first { $0.frame.contains(rect) })
        let filter = SCContentFilter(display: display, including: included)
        let configuration = SCStreamConfiguration()
        configuration.sourceRect = rect.offsetBy(dx: -display.frame.minX, dy: -display.frame.minY)
        configuration.width = Int(rect.width * 2)
        configuration.height = Int(rect.height * 2)
        configuration.showsCursor = false
        configuration.ignoreShadowsDisplay = true
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        return NSImage(cgImage: image, size: rect.size)
    }

    private static func viewImage(_ windows: [NSWindow]) throws -> NSImage {
        let union = windows.reduce(CGRect.null) { $0.union($1.frame) }
        let image = NSImage(size: union.size)
        image.lockFocus()
        defer { image.unlockFocus() }
        for window in windows {
            let content = try XCTUnwrap(window.contentView)
            let view = window is EditorPanel ? try XCTUnwrap(content.superview) : content
            view.layoutSubtreeIfNeeded()
            let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
            view.cacheDisplay(in: view.bounds, to: bitmap)
            let viewFrame = window.convertToScreen(view.convert(view.bounds, to: nil))
            let destination = viewFrame.offsetBy(dx: -union.minX, dy: -union.minY)
            window.effectiveAppearance.performAsCurrentDrawingAppearance {
                NSColor.windowBackgroundColor.setFill()
                NSBezierPath(roundedRect: destination, xRadius: 12, yRadius: 12).fill()
                bitmap.draw(in: destination)
            }
        }
        return image
    }
}
