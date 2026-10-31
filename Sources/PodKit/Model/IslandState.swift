import Foundation

/// Why the island is currently on screen.
///
/// The reason is carried alongside the state because dismiss timing depends on
/// it: something the user summoned deliberately must not time out the way an
/// incidental hover does.
public enum PresentationReason: Equatable, Sendable {
    /// The pointer: resting on the island, or clicking it.
    case hover
    /// The user asked for it — global hotkey, or tabbing into the panel.
    case keyboard
    /// A system event pushed it open without the user asking.
    case event(SystemEvent)

    /// Whether the user deliberately brought the island up.
    public var isUserInitiated: Bool {
        switch self {
        case .hover, .keyboard:
            return true
        case .event:
            return false
        }
    }
}

/// A machine event worth surfacing at the notch.
public enum SystemEvent: Equatable, Sendable {
    case mediaChanged
    case volumeChanged
    case batteryLow
    case powerSourceChanged
}

/// What the island is showing.
public enum IslandState: Equatable, Sendable {
    case hidden
    case collapsed(PresentationReason)
    case expanded(PresentationReason)

    public var reason: PresentationReason? {
        switch self {
        case .hidden:
            return nil
        case let .collapsed(reason), let .expanded(reason):
            return reason
        }
    }

    public var isVisible: Bool {
        self != .hidden
    }

    public var isExpanded: Bool {
        if case .expanded = self { return true }
        return false
    }
}
