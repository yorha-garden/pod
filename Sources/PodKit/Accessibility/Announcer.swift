import Foundation

/// Something worth saying to a screen reader.
public struct Announcement: Equatable, Sendable {
    public enum Priority: Int, Comparable, Sendable {
        /// Incidental: a track tick, a volume nudge.
        case low = 0
        /// Worth interrupting idle speech: a track change.
        case medium = 1
        /// Interrupts: battery critical, something the user must act on.
        case high = 2

        public static func < (lhs: Priority, rhs: Priority) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    public var message: String
    public var priority: Priority

    public init(_ message: String, priority: Priority = .medium) {
        self.message = message
        self.priority = priority
    }
}

/// Decides which announcements actually reach the screen reader.
///
/// A notch HUD updates constantly — progress ticks, volume, battery percentage
/// — and posting each one turns VoiceOver into an unusable stream that talks
/// over the user. This drops repeats inside a short window while letting
/// genuinely new or urgent messages through immediately.
public struct AnnouncementCoalescer: Sendable {
    /// Repeats of the same message inside this window are dropped.
    public var duplicateWindow: TimeInterval
    /// Low priority messages are dropped if anything was said this recently.
    public var quietPeriod: TimeInterval

    private var lastAdmitted: (message: String, at: Date)?

    public init(duplicateWindow: TimeInterval = 2.0, quietPeriod: TimeInterval = 0.75) {
        self.duplicateWindow = duplicateWindow
        self.quietPeriod = quietPeriod
    }

    /// Returns the announcement to speak, or `nil` to stay quiet.
    public mutating func admit(_ announcement: Announcement, at now: Date) -> Announcement? {
        guard let last = lastAdmitted else {
            lastAdmitted = (announcement.message, now)
            return announcement
        }

        let elapsed = now.timeIntervalSince(last.at)

        // Urgent messages are never withheld, repeat or not.
        if announcement.priority == .high {
            lastAdmitted = (announcement.message, now)
            return announcement
        }

        if announcement.message == last.message, elapsed < duplicateWindow {
            return nil
        }

        if announcement.priority == .low, elapsed < quietPeriod {
            return nil
        }

        lastAdmitted = (announcement.message, now)
        return announcement
    }

    /// Forget the history, so the next message is always spoken. Called when
    /// the island is dismissed and reopened: the user has moved on.
    public mutating func reset() {
        lastAdmitted = nil
    }
}
