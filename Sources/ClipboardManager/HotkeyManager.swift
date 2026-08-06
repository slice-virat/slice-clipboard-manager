import AppKit
import Carbon.HIToolbox
import ClipCore

/// Registers a system-wide hotkey using the Carbon Event Manager.
@MainActor
final class HotkeyManager {
    enum RegistrationError: LocalizedError {
        case registrationFailed(OSStatus)

        var errorDescription: String? {
            switch self {
            case .registrationFailed(let status):
                return "Could not register the hotkey (error \(status)). "
                     + "Another app is probably already using that combination."
            }
        }
    }

    /// Maps hotkey ids back to their handlers for the C callback.
    private static var handlers: [UInt32: () -> Void] = [:]
    private static var nextID: UInt32 = 1
    private static var eventHandler: EventHandlerRef?

    private let config: HotkeyConfig
    private let handler: () -> Void
    private var hotKeyRef: EventHotKeyRef?
    private var id: UInt32?

    init(config: HotkeyConfig, handler: @escaping () -> Void) {
        self.config = config
        self.handler = handler
    }

    static func fire(id: UInt32) {
        handlers[id]?()
    }

    func register() throws {
        unregister()
        Self.installEventHandlerIfNeeded()

        let myID = Self.nextID
        Self.nextID += 1

        // 'CLIP' as a four-char code.
        let hotKeyID = EventHotKeyID(signature: OSType(0x434C4950), id: myID)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            config.keyCode,
            config.carbonModifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &ref
        )
        guard status == noErr, let ref else {
            throw RegistrationError.registrationFailed(status)
        }
        hotKeyRef = ref
        id = myID
        Self.handlers[myID] = handler
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let id {
            Self.handlers.removeValue(forKey: id)
            self.id = nil
        }
    }

    private static func installEventHandlerIfNeeded() {
        guard eventHandler == nil else { return }
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetEventDispatcherTarget(),
            hotkeyEventCallback,
            1,
            &spec,
            nil,
            &eventHandler
        )
    }
}

/// C callback invoked by Carbon on the main run loop.
private func hotkeyEventCallback(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr else { return status }
    MainActor.assumeIsolated {
        HotkeyManager.fire(id: hotKeyID.id)
    }
    return noErr
}
