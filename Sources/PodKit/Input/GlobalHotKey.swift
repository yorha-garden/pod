import AppKit
import Carbon.HIToolbox

/// A system-wide hotkey.
///
/// Carbon's hotkey API is the only way to register one without the
/// accessibility permission an event tap needs. That matters here: the
/// keyboard path should not sit behind a permission dialog, because it is the
/// path a keyboard-only user needs in order to reach anything at all.
public final class GlobalHotKey {
    private static var actions: [UInt32: () -> Void] = [:]
    private static var nextIdentifier: UInt32 = 1
    private static var handler: EventHandlerRef?

    private let identifier: UInt32
    private var reference: EventHotKeyRef?

    public init?(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        Self.installHandlerIfNeeded()

        identifier = Self.nextIdentifier
        Self.nextIdentifier += 1
        Self.actions[identifier] = action

        let hotKeyID = EventHotKeyID(signature: OSType(0x504F_4421), id: identifier)
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &reference
        )

        guard status == noErr else {
            Self.actions[identifier] = nil
            return nil
        }
    }

    deinit {
        if let reference {
            UnregisterEventHotKey(reference)
        }
        Self.actions[identifier] = nil
    }

    private static func installHandlerIfNeeded() {
        guard handler == nil else { return }

        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, _ -> OSStatus in
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

                if let action = GlobalHotKey.actions[hotKeyID.id] {
                    DispatchQueue.main.async(execute: action)
                }

                return noErr
            },
            1,
            &spec,
            nil,
            &handler
        )
    }
}
