import Carbon.HIToolbox
import XCTest
@testable import SnimachCore

/// Hot key events are sent straight to the dispatcher, the way the system delivers them, so no
/// real key is pressed and the tests do not depend on which app has the focus.
@MainActor
final class GlobalEscapeKeyTests: XCTestCase {
    private let foreignHotKey = EventHotKeyID(signature: 0x54455354, id: 1)

    func testAnEscapeHotKeyPressReachesTheHandlerWhileArmed() {
        let key = GlobalEscapeKey()
        var presses = 0
        key.arm { presses += 1 }
        defer { key.disarm() }

        let status = sendHotKeyPressed(GlobalEscapeKey.hotKeyID)

        XCTAssertEqual(status, noErr)
        XCTAssertEqual(presses, 1)
    }

    func testOtherHotKeysArePassedOn() {
        let key = GlobalEscapeKey()
        var presses = 0
        key.arm { presses += 1 }
        defer { key.disarm() }

        let status = sendHotKeyPressed(foreignHotKey)

        XCTAssertEqual(status, OSStatus(eventNotHandledErr))
        XCTAssertEqual(presses, 0)
    }

    func testADisarmedKeyIgnoresEscape() {
        let key = GlobalEscapeKey()
        var presses = 0
        key.arm { presses += 1 }
        key.disarm()

        let status = sendHotKeyPressed(GlobalEscapeKey.hotKeyID)

        XCTAssertEqual(status, OSStatus(eventNotHandledErr))
        XCTAssertEqual(presses, 0)
    }

    private func sendHotKeyPressed(_ id: EventHotKeyID) -> OSStatus {
        var event: EventRef?
        CreateEvent(
            nil,
            OSType(kEventClassKeyboard),
            UInt32(kEventHotKeyPressed),
            0,
            EventAttributes(kEventAttributeNone),
            &event
        )
        guard let event else {
            XCTFail("could not create the hot key event")
            return OSStatus(eventNotHandledErr)
        }
        defer { ReleaseEvent(event) }
        var pressedID = id
        SetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            MemoryLayout<EventHotKeyID>.size,
            &pressedID
        )
        return SendEventToEventTarget(event, GetEventDispatcherTarget())
    }
}
