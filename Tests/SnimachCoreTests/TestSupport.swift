import CoreGraphics
import Foundation
import XCTest
@testable import SnimachCore

struct Pixel: Equatable {
    let r: UInt8
    let g: UInt8
    let b: UInt8
    let a: UInt8
}

/// A rendered document in a known BGRA bitmap, addressable in document points.
struct Bitmap {
    let context: CGContext
    let scale: CGFloat

    var width: Int { context.width }
    var height: Int { context.height }

    func pixel(at point: CGPoint) -> Pixel {
        let x = Int((point.x * scale).rounded())
        let y = Int((point.y * scale).rounded())
        return pixel(x: x, y: height - 1 - y)
    }

    func pixel(x: Int, y: Int) -> Pixel {
        let data = context.data!.bindMemory(to: UInt8.self, capacity: context.bytesPerRow * height)
        let offset = y * context.bytesPerRow + x * 4
        return Pixel(
            r: data[offset + 2],
            g: data[offset + 1],
            b: data[offset + 0],
            a: data[offset + 3]
        )
    }

    func countInColumn(x: Int, of color: CGColor, tolerance: Int = 8) -> Int {
        let target = RGB(color)
        var total = 0
        for y in 0..<height {
            let p = pixel(x: x, y: y)
            if abs(Int(p.r) - target.r) <= tolerance,
               abs(Int(p.g) - target.g) <= tolerance,
               abs(Int(p.b) - target.b) <= tolerance {
                total += 1
            }
        }
        return total
    }

    func count(of color: CGColor, tolerance: Int = 8) -> Int {
        let target = RGB(color)
        var total = 0
        for y in 0..<height {
            for x in 0..<width {
                let p = pixel(x: x, y: y)
                if abs(Int(p.r) - target.r) <= tolerance,
                   abs(Int(p.g) - target.g) <= tolerance,
                   abs(Int(p.b) - target.b) <= tolerance {
                    total += 1
                }
            }
        }
        return total
    }
}

struct RGB {
    let r: Int
    let g: Int
    let b: Int

    init(_ color: CGColor) {
        let srgb = color.converted(
            to: CGColorSpace(name: CGColorSpace.sRGB)!,
            intent: .defaultIntent,
            options: nil
        ) ?? color
        let components = srgb.components ?? [0, 0, 0, 0]
        r = Int((components[0] * 255).rounded())
        g = Int((components[1] * 255).rounded())
        b = Int((components[2] * 255).rounded())
    }
}

func makeContext(width: Int, height: Int) -> CGContext {
    let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue
        | CGBitmapInfo.byteOrder32Little.rawValue
    return CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: bitmapInfo
    )!
}

/// A shot whose pixels are a solid colour. `pointSize` is in points, the bitmap is scaled.
func makeShot(pointSize: CGSize, scale: CGFloat, color: CGColor = CGColor(srgbRed: 0.5, green: 0.5, blue: 0.5, alpha: 1)) -> Shot {
    let width = Int((pointSize.width * scale).rounded())
    let height = Int((pointSize.height * scale).rounded())
    let context = makeContext(width: width, height: height)
    context.setFillColor(color)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    return Shot(
        image: context.makeImage()!,
        scale: scale,
        frame: CGRect(origin: .zero, size: pointSize)
    )
}

/// A shot of one-point black and white squares, so flattening an area is visible in the pixels.
func makeCheckerShot(pointSize: CGSize, scale: CGFloat) -> Shot {
    let width = Int(pointSize.width * scale)
    let height = Int(pointSize.height * scale)
    let context = makeContext(width: width, height: height)
    let black = CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1)
    let white = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
    for row in 0..<Int(pointSize.height) {
        for column in 0..<Int(pointSize.width) {
            context.setFillColor((row + column).isMultiple(of: 2) ? black : white)
            context.fill(CGRect(
                x: CGFloat(column) * scale,
                y: CGFloat(row) * scale,
                width: scale,
                height: scale
            ))
        }
    }
    return Shot(
        image: context.makeImage()!,
        scale: scale,
        frame: CGRect(origin: .zero, size: pointSize)
    )
}

/// Runs the document's single draw path into a fresh bitmap at pixel size.
func draw(_ document: Document) -> Bitmap {
    let context = makeContext(width: document.shot.image.width, height: document.shot.image.height)
    context.scaleBy(x: document.shot.scale, y: document.shot.scale)
    document.draw(in: context)
    return Bitmap(context: context, scale: document.shot.scale)
}

/// Reads a rendered image back at 1:1 so document points map to pixels.
func bitmap(_ image: CGImage, scale: CGFloat) -> Bitmap {
    let context = makeContext(width: image.width, height: image.height)
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    return Bitmap(context: context, scale: scale)
}

func assertNear(_ pixel: Pixel, _ color: CGColor, tolerance: Int = 10,
                file: StaticString = #filePath, line: UInt = #line) {
    let target = RGB(color)
    XCTAssertTrue(abs(Int(pixel.r) - target.r) <= tolerance, "red \(pixel.r) vs \(target.r)", file: file, line: line)
    XCTAssertTrue(abs(Int(pixel.g) - target.g) <= tolerance, "green \(pixel.g) vs \(target.g)", file: file, line: line)
    XCTAssertTrue(abs(Int(pixel.b) - target.b) <= tolerance, "blue \(pixel.b) vs \(target.b)", file: file, line: line)
}

struct CaptureCall: Equatable {
    let display: CGDirectDisplayID
    let rect: CGRect
    let scale: CGFloat
    let only: [CGWindowID]?
    let excludingPID: pid_t?
    let keepShadows: Bool
    let showsCursor: Bool
}

/// Renders a solid, or shadow-margined, image of the requested pixel size and records every call.
/// `markerRect` (display-local points) is painted blue so a crop's position can be checked.
final class FakeCaptureBackend: CaptureBackend, @unchecked Sendable {
    static let fill = CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1)
    static let marker = CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1)

    var displaysList: [DisplayInfo] = []
    var windows: [WindowInfo] = []
    var preflight = false
    var promptResult = false
    var failWithPermission = false
    var transparentMargin: CGFloat = 0
    var markerRect: CGRect?
    var beforeCaptureReturn: (() async -> Void)?
    private(set) var promptCount = 0
    private(set) var captureCalls: [CaptureCall] = []

    func preflightPermission() -> Bool { preflight }

    func requestPermission() -> Bool {
        promptCount += 1
        return promptResult
    }

    func displays() async throws -> [DisplayInfo] {
        if failWithPermission || displaysList.isEmpty { throw BackendError.permissionDenied }
        return displaysList
    }

    func onScreenWindowsFrontToBack() -> [WindowInfo] { windows }

    func captureRegion(display: CGDirectDisplayID,
                       rect: CGRect,
                       scale: CGFloat,
                       only windows: [CGWindowID]?,
                       excludingPID: pid_t?,
                       keepShadows: Bool,
                       showsCursor: Bool) async throws -> CGImage {
        if failWithPermission { throw BackendError.permissionDenied }
        let call = CaptureCall(
            display: display,
            rect: rect,
            scale: scale,
            only: windows,
            excludingPID: excludingPID,
            keepShadows: keepShadows,
            showsCursor: showsCursor
        )
        // The freeze captures displays concurrently off the main actor. Recording on the main
        // actor, where the tests read, keeps the array free of races.
        await MainActor.run { captureCalls.append(call) }

        if let beforeCaptureReturn { await beforeCaptureReturn() }

        let width = Int((rect.width * scale).rounded())
        let height = Int((rect.height * scale).rounded())
        let context = makeContext(width: width, height: height)
        let inset = transparentMargin * scale
        context.setFillColor(Self.fill)
        context.fill(CGRect(
            x: inset,
            y: inset,
            width: CGFloat(width) - inset * 2,
            height: CGFloat(height) - inset * 2
        ))
        if let markerRect {
            let local = markerRect.offsetBy(dx: -rect.minX, dy: -rect.minY)
            context.setFillColor(Self.marker)
            context.fill(flippedPixels(of: local, scale: scale, imageHeight: height))
        }
        return context.makeImage()!
    }

    /// The context is y-up while display-local rects are y-down, so the fill has to flip.
    private func flippedPixels(of rect: CGRect, scale: CGFloat, imageHeight: Int) -> CGRect {
        CGRect(
            x: rect.minX * scale,
            y: CGFloat(imageHeight) - rect.maxY * scale,
            width: rect.width * scale,
            height: rect.height * scale
        )
    }
}

/// Returns preset selections in order, throws, or suspends until cancelled.
@MainActor
final class ScriptedAreaSelector: AreaSelector {
    enum Outcome {
        case rect(CGRect)
        case fail(Error)
        case suspend
    }

    private(set) var outcomes: [Outcome]
    private var waiters: [CheckedContinuation<CGRect, Error>] = []
    private(set) var callCount = 0
    private(set) var cancelCount = 0
    private(set) var shown: [[FrozenDisplay]] = []
    private(set) var offeredWindows: [[CGRect]] = []

    var isIdle: Bool { waiters.isEmpty }

    init(_ outcomes: [Outcome]) {
        self.outcomes = outcomes
    }

    func select(over displays: [FrozenDisplay], windows: [CGRect]) async throws -> CGRect {
        callCount += 1
        shown.append(displays)
        offeredWindows.append(windows)
        guard !outcomes.isEmpty else { throw CancellationError() }
        switch outcomes.removeFirst() {
        case .rect(let rect):
            return rect
        case .fail(let error):
            throw error
        case .suspend:
            return try await withCheckedThrowingContinuation { continuation in
                waiters.append(continuation)
            }
        }
    }

    func cancel() {
        cancelCount += 1
        let pending = waiters
        waiters.removeAll()
        for waiter in pending { waiter.resume(throwing: CancellationError()) }
    }
}

/// A one-shot gate tests use to hold a capture open while they cancel it.
@MainActor
final class AsyncGate {
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var isOpen = false

    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
        isOpen = true
        let pending = waiters
        waiters.removeAll()
        for waiter in pending { waiter.resume() }
    }
}
