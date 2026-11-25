import Carbon.HIToolbox

/// Escape while the area selection is up, wherever the keyboard focus is. A separate seam
/// because the production adapter takes the key away from every other app while armed.
@MainActor
protocol CancelKey: AnyObject {
    /// Calls `onPress` for every press until `disarm()`. Arming again replaces the handler.
    func arm(onPress: @escaping () -> Void)
    func disarm()
}

/// Escape as a system-wide Carbon hot key. The overlay's own `keyDown` only fires while the app
/// is active and a panel is key, which a menu bar app cannot count on: activation may not take,
/// and another app can take the focus while the overlay still covers every display. A hot key
/// is delivered regardless and needs no Accessibility or Input Monitoring grant.
@MainActor
final class GlobalEscapeKey: CancelKey {
    private var onPress: (() -> Void)?
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?

    func arm(onPress: @escaping () -> Void) {
        disarm()
        self.onPress = onPress
        installHandler()
        // A failed registration leaves the overlay's `keyDown` as the only way out.
        RegisterEventHotKey(
            UInt32(kVK_Escape),
            0,
            Self.hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKey
        )
    }

    func disarm() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
        hotKey = nil
        handler = nil
        onPress = nil
    }

    private func installHandler() {
        var pressed = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetEventDispatcherTarget(),
            Self.handleHotKeyEvent,
            1,
            &pressed,
            Unmanaged.passUnretained(self).toOpaque(),
            &handler
        )
    }

    /// Every hot key of the process arrives here first, the capture shortcuts included, so
    /// anything but Escape is passed on to the handlers installed before this one.
    private static let handleHotKeyEvent: EventHandlerUPP = { _, event, userData in
        guard let event, let userData, GlobalEscapeKey.isEscape(event) else {
            return OSStatus(eventNotHandledErr)
        }
        let key = Unmanaged<GlobalEscapeKey>.fromOpaque(userData).takeUnretainedValue()
        MainActor.assumeIsolated { key.onPress?() }
        return noErr
    }

    private nonisolated static func isEscape(_ event: EventRef) -> Bool {
        var pressedID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &pressedID
        )
        return status == noErr
            && pressedID.signature == hotKeyID.signature
            && pressedID.id == hotKeyID.id
    }

    /// "SNMC", so the id cannot collide with the hot keys the app shell registers.
    nonisolated static let hotKeyID = EventHotKeyID(signature: 0x534E_4D43, id: 1)
}
