import Foundation

/// Owns when the island is on screen, how long it stays, and what is said.
///
/// Preferences arrive through `updatePreferences` rather than being observed
/// here, which keeps Combine and `NSWorkspace` out of the controller and lets
/// the dismiss scheduling be tested directly.
@MainActor
public final class IslandController: ObservableObject {
    @Published public private(set) var state: IslandState = .hidden
    @Published public private(set) var style: IslandStyle

    /// Whether the panel currently holds the keyboard focus. The dismiss
    /// timer consults this, so focus is never pulled away on a timer.
    @Published public private(set) var hasKeyboardFocus = false

    public var policy: DismissPolicy

    private var preferences: AccessibilityPreferences
    private let sink: AnnouncementSink
    private var coalescer = AnnouncementCoalescer()
    private var dismissWork: DispatchWorkItem?

    public init(
        preferences: AccessibilityPreferences = .standard,
        policy: DismissPolicy = DismissPolicy(),
        sink: AnnouncementSink
    ) {
        self.preferences = preferences
        self.policy = policy
        self.sink = sink
        self.style = IslandStyle.resolve(for: preferences)
    }

    /// Fed from `AccessibilityPreferencesObserver` by the app layer.
    ///
    /// Re-runs the dismiss schedule, so turning VoiceOver on while the island
    /// is up extends the timeout already in flight instead of only the next.
    public func updatePreferences(_ latest: AccessibilityPreferences) {
        guard latest != preferences else { return }

        preferences = latest
        style = IslandStyle.resolve(for: latest)
        rescheduleDismiss()
    }

    /// Show the island, or change what it is showing.
    ///
    /// Announcements are coalesced here, so callers can push state as often as
    /// they like without talking over the user.
    public func present(_ newState: IslandState, announcing announcement: Announcement? = nil) {
        let wasHidden = !state.isVisible
        state = newState

        if wasHidden {
            // A fresh presentation: whatever was said last time is no longer
            // what the user is listening for, so let the next message through.
            coalescer.reset()
        }

        if let announcement, let admitted = coalescer.admit(announcement, at: Date()) {
            sink.post(admitted)
        }

        rescheduleDismiss()
    }

    public func dismiss() {
        cancelPendingDismiss()

        guard state.isVisible else { return }

        state = .hidden
        hasKeyboardFocus = false
    }

    /// Called by the view layer as focus enters and leaves the panel.
    public func setKeyboardFocus(_ focused: Bool) {
        guard focused != hasKeyboardFocus else { return }

        hasKeyboardFocus = focused
        // Focus arriving cancels any pending dismiss; focus leaving restarts
        // the clock from now rather than resuming a stale deadline.
        rescheduleDismiss()
    }

    private func rescheduleDismiss() {
        cancelPendingDismiss()

        guard let reason = state.reason else { return }

        let outcome = policy.outcome(
            reason: reason,
            hasKeyboardFocus: hasKeyboardFocus,
            preferences: preferences
        )

        guard case let .dismiss(after) = outcome else { return }

        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                self?.dismiss()
            }
        }
        dismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + after, execute: work)
    }

    private func cancelPendingDismiss() {
        dismissWork?.cancel()
        dismissWork = nil
    }
}
