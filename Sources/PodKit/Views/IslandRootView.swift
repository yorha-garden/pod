import SwiftUI

/// The island's content, across every state.
public struct IslandRootView: View {
    @ObservedObject private var controller: IslandController
    @ObservedObject private var media: NowPlayingStore
    @ObservedObject private var battery: BatteryMonitor

    @FocusState private var focus: IslandFocus?

    public init(
        controller: IslandController,
        media: NowPlayingStore,
        battery: BatteryMonitor
    ) {
        self.controller = controller
        self.media = media
        self.battery = battery
    }

    public var body: some View {
        content
            .background {
                // Nothing behind the resting target, or the material would
                // paint a shape at the notch while the island is hidden.
                if controller.state.isVisible {
                    IslandBackground(style: controller.style, cornerRadius: 18)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .animation(controller.style.motion.animation, value: controller.state)
            // A container with a name and a state, so VoiceOver announces
            // "Pod, expanded" rather than an anonymous group.
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Pod")
            .accessibilityValue(stateDescription)
            .onChange(of: focus) { _, latest in
                // Tells the dismiss timer that someone is holding focus.
                controller.setKeyboardFocus(latest != nil)
            }
    }

    @ViewBuilder
    private var content: some View {
        switch controller.state {
        case .hidden:
            if controller.hasRestingTarget {
                RestingTargetView(onExpand: { controller.expandFromClick() })
            }

        case .collapsed:
            CollapsedContentView(
                media: media.snapshot,
                battery: battery.status,
                style: controller.style,
                onExpand: { controller.expandFromClick() }
            )
            .transition(controller.style.motion.transition)

        case .expanded:
            ExpandedContentView(
                media: media.snapshot,
                battery: battery.status,
                style: controller.style,
                focus: $focus,
                onCommand: { media.send($0) }
            )
            .transition(controller.style.motion.transition)
        }
    }

    private var stateDescription: String {
        switch controller.state {
        case .hidden: "Hidden"
        case .collapsed: "Collapsed"
        case .expanded: "Expanded"
        }
    }
}
