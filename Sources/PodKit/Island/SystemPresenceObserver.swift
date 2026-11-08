import AppKit

/// Keeps `SystemPresence` in step with the system: the lock screen, fast user
/// switching, display sleep, and which kind of Space is in front.
///
/// Every one of those can take the island's windows somewhere the app did not
/// put them — a display sleeping and waking reorders windows, and a Space
/// change is when a full-screen app arrives — so each change is also a cue to
/// put the panels back.
@MainActor
public final class SystemPresenceObserver: ObservableObject {
    @Published public private(set) var presence: SystemPresence

    private let readsSpaceKind: Bool
    private var tokens: [(NotificationCenter, NSObjectProtocol)] = []

    /// - Parameter readsSpaceKind: whether to ask the window server what kind
    ///   of Space is active. Private API, so it follows the same switch as
    ///   the private Space.
    public init(readsSpaceKind: Bool) {
        self.readsSpaceKind = readsSpaceKind
        self.presence = SystemPresence(
            isScreenLocked: Self.screenIsLockedNow(),
            activeSpace: readsSpaceKind ? IslandSpace.activeSpaceKind() : .desktop
        )
        subscribe()
    }

    deinit {
        for (center, token) in tokens {
            center.removeObserver(token)
        }
    }

    private func subscribe() {
        let workspace = NSWorkspace.shared.notificationCenter

        observe(workspace, NSWorkspace.activeSpaceDidChangeNotification) { presence in
            if self.readsSpaceKind {
                presence.activeSpace = IslandSpace.activeSpaceKind()
            }
        }
        observe(workspace, NSWorkspace.screensDidSleepNotification) { $0.areScreensAsleep = true }
        observe(workspace, NSWorkspace.screensDidWakeNotification) { $0.areScreensAsleep = false }
        observe(workspace, NSWorkspace.sessionDidResignActiveNotification) { $0.isSessionActive = false }
        observe(workspace, NSWorkspace.sessionDidBecomeActiveNotification) { $0.isSessionActive = true }

        let distributed = DistributedNotificationCenter.default()
        observe(distributed, Notification.Name("com.apple.screenIsLocked")) { $0.isScreenLocked = true }
        observe(distributed, Notification.Name("com.apple.screenIsUnlocked")) { $0.isScreenLocked = false }
    }

    private func observe(
        _ center: NotificationCenter,
        _ name: Notification.Name,
        update: @escaping @MainActor (inout SystemPresence) -> Void
    ) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                var latest = self.presence
                update(&latest)
                // Published even when unchanged: a repeated wake or Space
                // change is still a cue to put the panels back in order.
                self.presence = latest
            }
        }
        tokens.append((center, token))
    }

    /// Whether the session is locked right now, from the public session
    /// dictionary — the notifications only report changes.
    private static func screenIsLockedNow() -> Bool {
        guard let session = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
        return (session["CGSSessionScreenIsLocked"] as? Bool) ?? false
    }
}
