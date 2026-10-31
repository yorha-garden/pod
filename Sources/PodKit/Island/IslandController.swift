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

    /// Whether the pointer is over the island. Like keyboard focus, it holds
    /// the island open: nothing the pointer rests on is taken away on a timer.
    @Published public private(set) var hasPointerInside = false

    /// Whether the panel stays at the notch while hidden, as something for the
    /// pointer to rest on and click. Set by the app layer from the display:
    /// only where a camera housing gives it somewhere invisible to sit.
    @Published public var hasRestingTarget = false

    public var policy: DismissPolicy

    /// How long the pointer must rest on the island before it expands, so
    /// crossing the notch on the way to the menu bar does not open it.
    public var hoverIntentDelay: TimeInterval = 0.25

    private var preferences: AccessibilityPreferences
    private let sink: AnnouncementSink
    private var coalescer = AnnouncementCoalescer()
    private var dismissWork: DispatchWorkItem?
    private var hoverWork: DispatchWorkItem?

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
        // An explicit dismiss outranks a hover that was about to expand.
        cancelHoverIntent()

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

    /// Called by the app layer as the pointer enters and leaves the island.
    ///
    /// Entering starts the hover intent; leaving cancels it and restarts the
    /// dismiss clock. Hovering never takes the keyboard focus — only a click
    /// or the hotkey does — so typing elsewhere keeps working.
    public func setPointerInside(_ inside: Bool) {
        guard inside != hasPointerInside else { return }

        hasPointerInside = inside
        cancelHoverIntent()

        if inside, !state.isExpanded {
            let work = DispatchWorkItem { [weak self] in
                MainActor.assumeIsolated {
                    self?.expandFromHover()
                }
            }
            hoverWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + hoverIntentDelay, execute: work)
        }

        rescheduleDismiss()
    }

    /// A click on the island, or on its resting target: expand at once.
    ///
    /// Announced, like the hotkey, because a deliberate press should be
    /// confirmed to someone who cannot see the result.
    public func expandFromClick() {
        cancelHoverIntent()

        guard !state.isExpanded else { return }

        present(.expanded(.hover), announcing: Announcement("Pod expanded", priority: .medium))
    }

    private func expandFromHover() {
        hoverWork = nil

        guard hasPointerInside, !state.isExpanded else { return }

        present(.expanded(.hover))
    }

    private func cancelHoverIntent() {
        hoverWork?.cancel()
        hoverWork = nil
    }

    private func rescheduleDismiss() {
        cancelPendingDismiss()

        guard let reason = state.reason else { return }

        let outcome = policy.outcome(
            reason: reason,
            hasKeyboardFocus: hasKeyboardFocus,
            hasPointerInside: hasPointerInside,
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
