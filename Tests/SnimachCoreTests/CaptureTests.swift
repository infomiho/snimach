import CoreGraphics
import Foundation
import XCTest
@testable import SnimachCore

@MainActor
final class CaptureTests: XCTestCase {
    private let display2x = DisplayInfo(
        id: 1,
        frame: CGRect(x: 0, y: 0, width: 1000, height: 800),
        scale: 2
    )
    private let display1x = DisplayInfo(
        id: 2,
        frame: CGRect(x: 1000, y: 0, width: 800, height: 600),
        scale: 1
    )

    private func makeCapturer(backend: FakeCaptureBackend,
                              selector: ScriptedAreaSelector,
                              prompted: Bool = false,
                              pointer: CGPoint = .zero,
                              includesPointer: Bool = false,
                              onPrompt: @escaping () -> Void = {}) -> Capturer {
        Capturer(
            backend: backend,
            selector: selector,
            hasPrompted: { prompted },
            markPrompted: onPrompt,
            pointerLocation: { pointer },
            includesPointer: { includesPointer }
        )
    }

    /// The freeze runs through a task group, so the number of hops before the selector opens
    /// is not fixed. Yield until the observed state arrives instead of counting yields.
    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<200 {
            if condition() { return }
            await Task.yield()
        }
    }

    // MARK: - Area

    func testAreaOn2xDisplayFreezesTheDisplayAndCropsAtPointScale() async throws {
        let backend = FakeCaptureBackend()
        backend.displaysList = [display2x]
        let selector = ScriptedAreaSelector([.rect(CGRect(x: 100, y: 100, width: 200, height: 150))])
        let capturer = makeCapturer(backend: backend, selector: selector)

        let shot = try await capturer.capture(.area)

        XCTAssertEqual(shot.scale, 2)
        XCTAssertEqual(shot.image.width, 400)
        XCTAssertEqual(shot.image.height, 300)
        XCTAssertEqual(shot.frame, CGRect(x: 100, y: 550, width: 200, height: 150))

        XCTAssertEqual(backend.captureCalls.count, 1, "the whole display is captured once, before the drag")
        let call = backend.captureCalls[0]
        XCTAssertEqual(call.display, display2x.id)
        XCTAssertEqual(call.rect, CGRect(x: 0, y: 0, width: 1000, height: 800))
        XCTAssertEqual(call.scale, 2)
        XCTAssertNil(call.only)
        XCTAssertEqual(call.excludingPID, getpid())
        XCTAssertFalse(call.keepShadows)
    }

    func testAreaFreezesEveryDisplayBeforeTheSelectorOpens() async throws {
        let backend = FakeCaptureBackend()
        backend.displaysList = [display2x, display1x]
        let selector = ScriptedAreaSelector([.rect(CGRect(x: 0, y: 0, width: 100, height: 100))])
        let capturer = makeCapturer(backend: backend, selector: selector)

        _ = try await capturer.capture(.area)

        let shown = try XCTUnwrap(selector.shown.first)
        XCTAssertEqual(shown.map(\.display), [display2x, display1x])
        XCTAssertEqual(shown[0].image.width, 2000)
        XCTAssertEqual(shown[0].image.height, 1600)
        XCTAssertEqual(shown[1].image.width, 800)
        XCTAssertEqual(shown[1].image.height, 600)
        XCTAssertEqual(backend.captureCalls.count, 2, "the selection is a crop, not a second capture")
    }

    func testAreaShotIsCroppedFromTheFrozenPixels() async throws {
        let backend = FakeCaptureBackend()
        backend.displaysList = [display2x]
        backend.markerRect = CGRect(x: 300, y: 200, width: 50, height: 50)
        let selector = ScriptedAreaSelector([.rect(CGRect(x: 250, y: 150, width: 200, height: 150))])
        let capturer = makeCapturer(backend: backend, selector: selector)

        let shot = try await capturer.capture(.area)

        let pixels = bitmap(shot.image, scale: shot.scale)
        assertNear(pixels.pixel(at: CGPoint(x: 75, y: 75)), FakeCaptureBackend.marker)
        assertNear(pixels.pixel(at: CGPoint(x: 25, y: 25)), FakeCaptureBackend.fill)
        assertNear(pixels.pixel(at: CGPoint(x: 150, y: 125)), FakeCaptureBackend.fill)
    }

    func testAreaShotOwnsItsPixelsInsteadOfTheFrozenDisplay() async throws {
        let backend = FakeCaptureBackend()
        backend.displaysList = [display2x]
        let selector = ScriptedAreaSelector([.rect(CGRect(x: 100, y: 100, width: 200, height: 150))])
        let capturer = makeCapturer(backend: backend, selector: selector)

        let shot = try await capturer.capture(.area)

        XCTAssertEqual(shot.image.bytesPerRow, shot.image.width * 4,
                       "a crop that shares the display bitmap keeps the display's row stride")
    }

    func testSelectionTouchingTheDisplayEdgeCropsOnThatDisplay() async throws {
        let backend = FakeCaptureBackend()
        backend.displaysList = [display2x, display1x]
        let selector = ScriptedAreaSelector([.rect(CGRect(x: 900, y: 100, width: 100, height: 200))])
        let capturer = makeCapturer(backend: backend, selector: selector)

        let shot = try await capturer.capture(.area)

        XCTAssertEqual(shot.scale, 2)
        XCTAssertEqual(shot.image.width, 200)
        XCTAssertEqual(shot.image.height, 400)
        XCTAssertEqual(shot.frame, CGRect(x: 900, y: 500, width: 100, height: 200))
        XCTAssertEqual(Set(backend.captureCalls.map(\.display)), [display2x.id, display1x.id])
    }

    func testTinySelectionThrowsCancellation() async throws {
        let backend = FakeCaptureBackend()
        backend.displaysList = [display2x]
        let selector = ScriptedAreaSelector([.rect(CGRect(x: 10, y: 10, width: 1, height: 1))])
        let capturer = makeCapturer(backend: backend, selector: selector)

        await XCTAssertThrowsCancellation { _ = try await capturer.capture(.area) }
        XCTAssertEqual(selector.callCount, 1)
    }

    func testSelectorCancellationPropagates() async throws {
        let backend = FakeCaptureBackend()
        backend.displaysList = [display2x]
        let selector = ScriptedAreaSelector([.fail(CancellationError())])
        let capturer = makeCapturer(backend: backend, selector: selector)

        await XCTAssertThrowsCancellation { _ = try await capturer.capture(.area) }
    }

    func testTaskCancellationTearsDownSelection() async throws {
        let backend = FakeCaptureBackend()
        backend.displaysList = [display2x]
        let selector = ScriptedAreaSelector([.suspend])
        let capturer = makeCapturer(backend: backend, selector: selector)

        let task = Task { try await capturer.capture(.area) }
        await waitUntil { selector.callCount == 1 }
        XCTAssertEqual(selector.callCount, 1)

        task.cancel()
        let result = await task.result
        guard case .failure(let error) = result else {
            return XCTFail("expected cancellation, got success")
        }
        XCTAssertTrue(error is CancellationError)
        XCTAssertTrue(selector.isIdle, "no selection may be left suspended")
    }

    func testCancellationDuringFreezeNeverOpensTheSelector() async throws {
        let backend = FakeCaptureBackend()
        backend.displaysList = [display2x]
        let gate = AsyncGate()
        backend.beforeCaptureReturn = { await gate.wait() }
        let selector = ScriptedAreaSelector([.rect(CGRect(x: 0, y: 0, width: 100, height: 100))])
        let capturer = makeCapturer(backend: backend, selector: selector)

        let task = Task { try await capturer.capture(.area) }
        await waitUntil { backend.captureCalls.count == 1 }
        XCTAssertEqual(backend.captureCalls.count, 1)

        task.cancel()
        gate.open()
        let result = await task.result
        guard case .failure(let error) = result else {
            return XCTFail("a cancelled capture must not return a shot")
        }
        XCTAssertTrue(error is CancellationError)
        XCTAssertEqual(selector.callCount, 0)
    }

    func testSecondAreaCaptureCancelsTheFirst() async throws {
        let backend = FakeCaptureBackend()
        backend.displaysList = [display2x]
        let selector = ScriptedAreaSelector([
            .suspend,
            .rect(CGRect(x: 0, y: 0, width: 100, height: 100)),
        ])
        let capturer = makeCapturer(backend: backend, selector: selector)

        let first = Task { try await capturer.capture(.area) }
        await waitUntil { selector.callCount == 1 }

        let second = Task { try await capturer.capture(.area) }
        let secondResult = await second.result
        guard case .success = secondResult else {
            return XCTFail("second capture should succeed")
        }

        first.cancel()
        let firstResult = await first.result
        guard case .failure(let error) = firstResult else {
            return XCTFail("first capture should be cancelled")
        }
        XCTAssertTrue(error is CancellationError)
        XCTAssertTrue(selector.isIdle)
    }

    func testFrontmostWindowContainingThePointWins() {
        let front = CGRect(x: 0, y: 0, width: 100, height: 100)
        let back = CGRect(x: 50, y: 50, width: 200, height: 200)
        let windows = [front, back]

        XCTAssertEqual(CaptureGeometry.frontmostWindow(containing: CGPoint(x: 60, y: 60), in: windows), front)
        XCTAssertEqual(CaptureGeometry.frontmostWindow(containing: CGPoint(x: 180, y: 180), in: windows), back)
        XCTAssertNil(CaptureGeometry.frontmostWindow(containing: CGPoint(x: 400, y: 400), in: windows))
    }

    func testAreaOffersPickableWindowsToTheSelectorFrontToBack() async throws {
        let backend = FakeCaptureBackend()
        backend.displaysList = [display2x]
        let first = CGRect(x: 100, y: 100, width: 200, height: 120)
        let second = CGRect(x: 40, y: 40, width: 300, height: 260)
        backend.windows = [
            WindowInfo(id: 1, pid: getpid(), layer: 0, alpha: 1,
                       frame: CGRect(x: 0, y: 0, width: 500, height: 400)),
            WindowInfo(id: 2, pid: 99, layer: 0, alpha: 1, frame: first),
            WindowInfo(id: 3, pid: 99, layer: 3, alpha: 1, frame: second),
            WindowInfo(id: 4, pid: 99, layer: 0, alpha: 0, frame: second),
            WindowInfo(id: 5, pid: 99, layer: 0, alpha: 1,
                       frame: CGRect(x: 0, y: 0, width: 10, height: 10)),
            WindowInfo(id: 6, pid: 42, layer: 0, alpha: 1, frame: second),
        ]
        let selector = ScriptedAreaSelector([.rect(CGRect(x: 0, y: 0, width: 50, height: 50))])
        let capturer = makeCapturer(backend: backend, selector: selector)

        _ = try await capturer.capture(.area)

        XCTAssertEqual(selector.offeredWindows.first, [first, second],
                       "ours, the wrong layer, the invisible and the tiny are all left out")
    }

    func testThePointerIsLeftOutUnlessTheSettingAsksForIt() async throws {
        for wanted in [false, true] {
            let backend = FakeCaptureBackend()
            backend.displaysList = [display2x]
            let capturer = makeCapturer(
                backend: backend,
                selector: ScriptedAreaSelector([]),
                includesPointer: wanted
            )

            _ = try await capturer.capture(.fullScreen)

            XCTAssertEqual(backend.captureCalls.first?.showsCursor, wanted)
        }
    }

    // MARK: - Full screen

    func testFullScreenCapturesTheDisplayUnderThePointer() async throws {
        let backend = FakeCaptureBackend()
        backend.displaysList = [display2x, display1x]
        let capturer = makeCapturer(
            backend: backend,
            selector: ScriptedAreaSelector([]),
            pointer: CGPoint(x: 1200, y: 100)
        )

        let shot = try await capturer.capture(.fullScreen)

        XCTAssertEqual(shot.scale, 1)
        XCTAssertEqual(shot.image.width, 800)
        XCTAssertEqual(shot.image.height, 600)
        XCTAssertEqual(shot.frame, CGRect(x: 1000, y: 200, width: 800, height: 600))

        XCTAssertEqual(backend.captureCalls.count, 1, "no overlay, no second pass")
        let call = backend.captureCalls[0]
        XCTAssertEqual(call.display, display1x.id)
        XCTAssertEqual(call.rect, CGRect(x: 0, y: 0, width: 800, height: 600))
        XCTAssertEqual(call.excludingPID, getpid())
    }

    func testFullScreenFallsBackToTheFirstDisplayWhenThePointerIsOffscreen() async throws {
        let backend = FakeCaptureBackend()
        backend.displaysList = [display2x, display1x]
        let capturer = makeCapturer(
            backend: backend,
            selector: ScriptedAreaSelector([]),
            pointer: CGPoint(x: -500, y: -500)
        )

        let shot = try await capturer.capture(.fullScreen)

        XCTAssertEqual(shot.scale, 2)
        XCTAssertEqual(backend.captureCalls[0].display, display2x.id)
    }

    // MARK: - Active window

    func testActiveWindowSkipsIneligibleAndIncludesCompanionsAndShadow() async throws {
        let backend = FakeCaptureBackend()
        backend.displaysList = [display2x]
        backend.transparentMargin = 64

        let targetFrame = CGRect(x: 100, y: 100, width: 200, height: 100)
        backend.windows = [
            WindowInfo(id: 1, pid: getpid(), layer: 0, alpha: 1,
                       frame: CGRect(x: 0, y: 0, width: 500, height: 400)),
            WindowInfo(id: 2, pid: 99, layer: 5, alpha: 1, frame: targetFrame),
            WindowInfo(id: 3, pid: 99, layer: 0, alpha: 0, frame: targetFrame),
            WindowInfo(id: 4, pid: 99, layer: 0, alpha: 1,
                       frame: CGRect(x: 0, y: 0, width: 10, height: 10)),
            WindowInfo(id: 5, pid: 42, layer: 3, alpha: 1,
                       frame: CGRect(x: 120, y: 140, width: 100, height: 60)),
            WindowInfo(id: 6, pid: 42, layer: 0, alpha: 1, frame: targetFrame),
        ]

        let capturer = makeCapturer(backend: backend, selector: ScriptedAreaSelector([]))

        let shot = try await capturer.capture(.activeWindow(includeShadow: true))

        XCTAssertEqual(shot.frame.size.width, 200)
        XCTAssertEqual(shot.frame.size.height, 100)
        XCTAssertEqual(shot.frame.origin, CGPoint(x: 100, y: 600))

        XCTAssertEqual(backend.captureCalls.count, 1)
        let call = backend.captureCalls[0]
        XCTAssertEqual(Set(call.only ?? []), Set([5, 6]))
        XCTAssertNil(call.excludingPID)
        XCTAssertTrue(call.keepShadows)
        XCTAssertEqual(call.rect, CGRect(x: 36, y: 36, width: 328, height: 228))
    }

    func testActiveWindowWithoutShadowIsTrimmed() async throws {
        let backend = FakeCaptureBackend()
        backend.displaysList = [display2x]
        backend.transparentMargin = 64
        backend.windows = [
            WindowInfo(id: 7, pid: 42, layer: 0, alpha: 1,
                       frame: CGRect(x: 100, y: 100, width: 200, height: 100)),
        ]
        let capturer = makeCapturer(backend: backend, selector: ScriptedAreaSelector([]))

        let shot = try await capturer.capture(.activeWindow(includeShadow: false))

        XCTAssertEqual(backend.captureCalls[0].keepShadows, false)
        XCTAssertEqual(shot.image.width, 400)
        XCTAssertEqual(shot.image.height, 200)
        XCTAssertEqual(shot.frame.size, CGSize(width: 200, height: 100))
    }

    func testNoEligibleWindowThrowsNoWindow() async throws {
        let backend = FakeCaptureBackend()
        backend.displaysList = [display2x]
        backend.windows = [
            WindowInfo(id: 1, pid: getpid(), layer: 0, alpha: 1,
                       frame: CGRect(x: 0, y: 0, width: 500, height: 400)),
            WindowInfo(id: 2, pid: 42, layer: 0, alpha: 0,
                       frame: CGRect(x: 0, y: 0, width: 500, height: 400)),
        ]
        let capturer = makeCapturer(backend: backend, selector: ScriptedAreaSelector([]))

        await XCTAssertThrowsCaptureError { _ = try await capturer.capture(.activeWindow()) } verify: {
            guard case CaptureError.noWindow = $0 else {
                return XCTFail("expected noWindow, got \($0)")
            }
        }
    }

    // MARK: - Permission

    func testGrantedButNotRelaunchedMapsToGrantedNeedsRelaunch() async throws {
        let backend = FakeCaptureBackend()
        backend.failWithPermission = true
        backend.preflight = true
        let capturer = makeCapturer(backend: backend, selector: ScriptedAreaSelector([]))

        await XCTAssertThrowsCaptureError { _ = try await capturer.capture(.area) } verify: {
            guard case .permission(.grantedNeedsRelaunch) = $0 else {
                return XCTFail("expected grantedNeedsRelaunch, got \($0)")
            }
        }
    }

    func testPromptedAndDeniedMapsToDenied() async throws {
        let backend = FakeCaptureBackend()
        backend.failWithPermission = true
        backend.preflight = false
        let capturer = makeCapturer(backend: backend, selector: ScriptedAreaSelector([]), prompted: true)

        await XCTAssertThrowsCaptureError { _ = try await capturer.capture(.area) } verify: {
            guard case .permission(.denied) = $0 else {
                return XCTFail("expected denied, got \($0)")
            }
        }
        XCTAssertEqual(backend.promptCount, 0)
    }

    func testFirstDenialPromptsOnceAndMapsToNotDetermined() async throws {
        let backend = FakeCaptureBackend()
        backend.failWithPermission = true
        backend.preflight = false
        var didPrompt = false
        let capturer = makeCapturer(
            backend: backend,
            selector: ScriptedAreaSelector([]),
            onPrompt: { didPrompt = true }
        )

        await XCTAssertThrowsCaptureError { _ = try await capturer.capture(.area) } verify: {
            guard case .permission(.notDetermined) = $0 else {
                return XCTFail("expected notDetermined, got \($0)")
            }
        }
        XCTAssertTrue(didPrompt)
        XCTAssertEqual(backend.promptCount, 1)
    }

    func testEmptyDisplayListIsAPermissionFailure() async throws {
        let backend = FakeCaptureBackend()
        backend.displaysList = []
        let capturer = makeCapturer(backend: backend, selector: ScriptedAreaSelector([]))

        await XCTAssertThrowsCaptureError { _ = try await capturer.capture(.area) } verify: {
            guard case .permission(.notDetermined) = $0 else {
                return XCTFail("expected notDetermined, got \($0)")
            }
        }
    }
}

private func XCTAssertThrowsCancellation(_ block: () async throws -> Void,
                                         file: StaticString = #filePath, line: UInt = #line) async {
    do {
        try await block()
        XCTFail("expected CancellationError", file: file, line: line)
    } catch is CancellationError {
    } catch {
        XCTFail("expected CancellationError, got \(error)", file: file, line: line)
    }
}

private func XCTAssertThrowsCaptureError(_ block: () async throws -> Void,
                                         verify: (CaptureError) -> Void,
                                         file: StaticString = #filePath, line: UInt = #line) async {
    do {
        try await block()
        XCTFail("expected CaptureError", file: file, line: line)
    } catch let error as CaptureError {
        verify(error)
    } catch {
        XCTFail("expected CaptureError, got \(error)", file: file, line: line)
    }
}
