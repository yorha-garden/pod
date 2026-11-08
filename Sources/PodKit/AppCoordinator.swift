import AppKit
import Carbon.HIToolbox
import Combine
import SwiftUI

/// Wires the system observers to the controller, and the controller to the
/// island's two panels.
@MainActor
public final class AppCoordinator: NSObject, NSApplicationDelegate {
    private let preferencesObserver = AccessibilityPreferencesObserver()
    private let battery = BatteryMonitor()
    private let media = NowPlayingStore(
        initial: NowPlaying(title: "Weight of the World", artist: "J'Nique Nicole", isPlaying: true)
    )
    private let windowing = IslandWindowing(defaults: .standard)

    private lazy var presenceObserver = SystemPresenceObserver(
        readsSpaceKind: windowing.usesPrivateWindowServerAPI
    )

    private lazy var controller = IslandController(
        preferences: preferencesObserver.preferences,
        sink: VoiceOverSink()
    )

    private lazy var layout = IslandLayout(geometry: Self.currentGeometry())

    private var panel: IslandPanel?
    private var backdrop: IslandBackdropPanel?
    private var space: IslandSpace?
    private var hotKey: GlobalHotKey?
    private var pointerTracker: PointerTracker?
    private var cancellables: Set<AnyCancellable> = []

    public func applicationDidFinishLaunching(_ notification: Notification) {
        buildPanels()
        updateRestingTarget()
        observe()
        installHotKey()

        // Show the resting island straight away. An overlay nobody knows is
        // there is its own accessibility problem.
        controller.present(.collapsed(.event(.mediaChanged)))
    }

    public func applicationWillTerminate(_ notification: Notification) {
        space?.tearDown()
    }

    // MARK: Building

    private func buildPanels() {
        let canvas = layout.geometry.canvasFrame(fitting: .zero)

        let panel = IslandPanel(contentRect: canvas)
        panel.contentView = IslandHostingView(rootView: IslandRootView(
            controller: controller,
            media: media,
            battery: battery,
            layout: layout,
            surface: .content
        ))
        panel.onCancel = { [weak self] in
            self?.controller.dismiss()
        }

        let backdrop = IslandBackdropPanel(contentRect: canvas)
        backdrop.contentView = IslandHostingView(rootView: IslandRootView(
            controller: controller,
            media: media,
            battery: battery,
            layout: layout,
            surface: .backdrop
        ))

        self.panel = panel
        self.backdrop = backdrop

        if windowing.usesPrivateWindowServerAPI {
            space = IslandSpace()
        }

        pointerTracker = PointerTracker(
            onChange: { [weak self] inside in
                self?.controller.setPointerInside(inside)
            },
            onClickOutside: { [weak self] in
                self?.dismissOnClickElsewhere()
            }
        )
    }

    /// A resting target only exists where a camera housing gives it somewhere
    /// invisible to sit. Anywhere else it would cover part of the menu bar, so
    /// the island is simply hidden there and the hotkey is the way in.
    private func updateRestingTarget() {
        controller.hasRestingTarget = layout.geometry.hasHousing
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

        layout.$islandSize
            .removeDuplicates()
            .sink { [weak self] size in
                self?.islandDidLayOut(at: size)
            }
            .store(in: &cancellables)

        // Locking, user switching, display sleep and Space changes can each
        // take the panels off screen or reorder them; every one is a cue to
        // put them back where they belong.
        presenceObserver.$presence
            .dropFirst()
            .sink { [weak self] presence in
                guard let self else { return }
                self.updateWindows(for: self.controller.state, presence: presence)
            }
            .store(in: &cancellables)

        battery.$status
            .sink { [weak self] status in
                self?.announceIfLow(status)
            }
            .store(in: &cancellables)

        // Displays come and go — a lid closing onto an external monitor
        // takes the housing with it.
        NotificationCenter.default
            .publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in
                self?.displaysDidChange()
            }
            .store(in: &cancellables)
    }

    // MARK: Placing the windows

    /// `@Published` fires in `willSet`, so `state` here is the one arriving
    /// and `controller.state` still the one leaving. Nothing here measures
    /// SwiftUI: the panels are a fixed canvas, and the island morphs inside
    /// them once SwiftUI catches up.
    private func apply(_ state: IslandState) {
        updateWindows(for: state, presence: presenceObserver.presence)

        if case .expanded(.keyboard) = state {
            // Summoned from the keyboard, so hand over the focus it asked
            // for — on the next turn, once SwiftUI has built the controls
            // there are to focus.
            DispatchQueue.main.async { [weak self] in
                guard let self, let panel = self.panel, self.controller.state == state else { return }
                panel.makeKey()
            }
        }
    }

    private func updateWindows(for state: IslandState, presence: SystemPresence) {
        guard let panel else { return }

        panel.allowsKeyFocus = windowing.allowsKeyFocus(presence: presence)

        guard windowing.panelsBelongOnScreen(
            state: state,
            hasRestingTarget: controller.hasRestingTarget,
            presence: presence
        ) else {
            hidePanels()
            // Nothing is under the pointer once the island is gone.
            pointerTracker?.region = .none
            controller.setPointerInside(false)
            return
        }

        // Hand the keyboard back before going to rest. A key panel at rest
        // would go on receiving the user's typing while showing nothing.
        if !state.isVisible, panel.isKeyWindow {
            hidePanels()
        }

        showPanels()
    }

    /// Orders the panels in if they are out, the backdrop first so it lands
    /// beneath, and (re)joins them to the private Space — ordering a window in
    /// puts it on the Space in front, so the move has to follow every order.
    private func showPanels() {
        guard let panel, let backdrop else { return }

        if !backdrop.isVisible {
            backdrop.orderFrontRegardless()
        }
        if !panel.isVisible {
            panel.orderFrontRegardless()
        }
        space?.add([backdrop, panel])
    }

    private func hidePanels() {
        guard let panel, let backdrop else { return }

        space?.remove([backdrop, panel])
        panel.orderOut(nil)
        backdrop.orderOut(nil)
    }

    /// The island has a new laid-out size: track the pointer over it, and
    /// grow the canvas if the island has outgrown it. Growing is never
    /// visible — the canvas is clear and keeps the island pinned to the same
    /// spot — so it is done at once, without animation.
    private func islandDidLayOut(at size: CGSize) {
        let geometry = layout.geometry
        pointerTracker?.region = HoverRegion(island: geometry.islandFrame(forSize: size))

        guard let panel, !geometry.canvas(panel.frame, fits: size) else { return }
        setCanvas(geometry.canvasFrame(fitting: size))
    }

    private func setCanvas(_ frame: CGRect) {
        panel?.setFrame(frame, display: false)
        backdrop?.setFrame(frame, display: false)
    }

    private func displaysDidChange() {
        layout.geometry = Self.currentGeometry()
        updateRestingTarget()
        setCanvas(layout.geometry.canvasFrame(fitting: layout.islandSize))
        pointerTracker?.region = HoverRegion(island: layout.islandFrame)
        updateWindows(for: controller.state, presence: presenceObserver.presence)
    }

    /// The display with a camera housing if there is one, since that is where
    /// the island belongs; otherwise the main display.
    private static func currentGeometry() -> NotchGeometry {
        let screen = NSScreen.screens.first(where: { NotchGeometry(screen: $0).hasHousing })
            ?? NSScreen.main
            ?? NSScreen.screens.first

        guard let screen else {
            return NotchGeometry(screenFrame: .zero)
        }
        return NotchGeometry(screen: screen)
    }

    // MARK: Input

    /// A click anywhere but the island closes it, like any other transient
    /// surface. Only an open island: a collapsed one is already out of the
    /// way and leaves on its own timer.
    private func dismissOnClickElsewhere() {
        guard controller.state.isExpanded else { return }
        controller.dismiss()
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
