import AppKit
import Foundation

/// Where admitted announcements go once the coalescer has let them through.
///
/// A protocol so the controller's announcement behaviour can be asserted in
/// tests instead of being spoken into a void.
@MainActor
public protocol AnnouncementSink: AnyObject {
    func post(_ announcement: Announcement)
}

/// Hands announcements to VoiceOver.
public final class VoiceOverSink: AnnouncementSink {
    public init() {}

    public func post(_ announcement: Announcement) {
        let level: NSAccessibilityPriorityLevel = switch announcement.priority {
        case .low: .low
        case .medium: .medium
        case .high: .high
        }

        NSAccessibility.post(
            element: NSApplication.shared,
            notification: .announcementRequested,
            userInfo: [
                .announcement: announcement.message,
                .priority: level.rawValue,
            ]
        )
    }
}

/// Records announcements rather than speaking them. For tests.
public final class RecordingSink: AnnouncementSink {
    public private(set) var posted: [Announcement] = []

    public init() {}

    public func post(_ announcement: Announcement) {
        posted.append(announcement)
    }
}
