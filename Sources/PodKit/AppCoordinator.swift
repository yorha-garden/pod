import AppKit
import Carbon.HIToolbox
import Combine
import SwiftUI

/// Wires the system observers to the controller, and the controller to a panel.
@MainActor
public final class AppCoordinator: NSObject, NSApplicationDelegate {
    private let preferencesObserver = AccessibilityPreferencesObserver()
    private let battery = BatteryMonitor()
    private let media = NowPlayingStore(
        initial: NowPlaying(title: "Weight of the World", artist: "J'Nique Nicole", isPlaying: true)
    )

    private lazy var controller = IslandController(
        preferences: preferencesObserver.preferences,
        sink: VoiceOverSink()
    )

    private var panel: IslandPanel?
    private var hosting: NSHostingView<IslandRootView>?
    private var hotKey: GlobalHotKey?
    private var cancellables: Set<AnyCancellable> = []

    public func applicationDidFinishLaunching(_ notification: Notification) {
        buildPanel()
        observe()
        installHotKey()

        // Show the resting island straight away. An overlay nobody knows is
        // there is its own accessibility problem.
        controller.present(.collapsed(.event(.mediaChanged)))
    }

    private func buildPanel() {
        let hosting = NSHostingView(
            rootView: IslandRootView(controller: controller, media: media, battery: battery)
        )
        let panel = IslandPanel(contentRect: CGRect(x: 0, y: 0, width: 320, height: 44))
        panel.contentView = hosting
        panel.onCancel = { [weak self] in
            self?.controller.dismiss()
        }

        self.hosting = hosting
        self.panel = panel
    }

    private func observe() {
        preferencesObserver.$preferences
            .sink { [weak self] latest in
                self?.controller.updatePreferences(latest)
            }
            .store(in: &cancellables)

        controller.$state
            .sink { [weak self] state in
                self?.apply(state)
            }
            .store(in: &cancellables)

        battery.$status
            .sink { [weak self] status in
                self?.announceIfLow(status)
            }
            .store(in: &cancellables)
    }

    /// Shows the panel for a state, then sizes it once SwiftUI has caught up.
    private func apply(_ state: IslandState) {
        guard let panel else { return }

        guard state.isVisible else {
            panel.orderOut(nil)
            return
        }

        // `@Published` fires in `willSet`, so right now the hosting view is
        // still rendering the state being replaced — measuring here measures
        // the outgoing view, and for the first presentation that is an empty
        // one, which collapses the panel to nothing. Size on the next runloop
        // turn, once SwiftUI has rebuilt for the state being applied.
        //
        // The panel is only shown on that turn too, once it has its frame.
        // Showing it here would show it wherever it last was — for the first
        // presentation, the corner it was constructed in — and the frame
        // change would then sweep it across the screen to the notch.
        DispatchQueue.main.async { [weak self] in
            self?.place(for: state)
        }
    }

    /// Fits the panel to what SwiftUI laid out, then shows it there.
    private func place(for state: IslandState) {
        // A dismiss, or another state, can land between `apply` and this
        // turn. Only the current state gets placed — a stale one must not
        // bring a dismissed island back.
        guard let panel, let hosting, controller.state == state else { return }

        guard let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 })
            ?? NSScreen.main
        else {
            return
        }

        hosting.layoutSubtreeIfNeeded()

        let geometry = NotchGeometry(screen: screen)
        // Ask SwiftUI what the content wants, so the island grows with the
        // user's text size instead of clipping at a hardcoded width.
        let frame = geometry.frame(
            forContentOfSize: hosting.fittingSize,
            minimumWidth: state.isExpanded ? 300 : 0
        )

        let wasOnScreen = panel.isVisible
        panel.setFrame(
            frame,
            display: true,
            animate: controller.style.motion.animatesFrameChange(panelWasOnScreen: wasOnScreen)
        )

        if !wasOnScreen {
            panel.orderFrontRegardless()
        }

        if case .expanded(.keyboard) = state {
            // Summoned from the keyboard, so hand over the focus it asked for.
            panel.makeKey()
        }
    }

    private func announceIfLow(_ status: BatteryStatus) {
        guard status.isLow else { return }

        controller.present(
            .collapsed(.event(.batteryLow)),
            announcing: Announcement(status.accessibilityDescription, priority: .high)
        )
    }

    private func installHotKey() {
        // Control-Option-Space: unclaimed by the system, and reachable with
        // one hand or with Sticky Keys.
        hotKey = GlobalHotKey(
            keyCode: UInt32(kVK_Space),
            modifiers: UInt32(controlKey | optionKey)
        ) { [weak self] in
            MainActor.assumeIsolated {
                self?.toggleFromKeyboard()
            }
        }
    }

    private func toggleFromKeyboard() {
        if controller.state.isExpanded {
            controller.dismiss()
        } else {
            controller.present(
                .expanded(.keyboard),
                announcing: Announcement("Pod expanded", priority: .medium)
            )
        }
    }
}
