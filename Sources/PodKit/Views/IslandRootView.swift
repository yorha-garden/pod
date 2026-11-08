import SwiftUI

/// Which of the two island panels a root view is drawing.
public enum IslandSurface: Sendable {
    /// The island itself, and everything that can be pressed.
    case content
    /// Only its shadow: the same layout, laid out identically and moving on
    /// the same springs, with nothing drawn but what goes behind the island.
    case backdrop
}

/// The island, across every state, inside the canvas it morphs in.
///
/// The canvas is the whole panel and almost all of it stays clear — the panel
/// lets the pointer through wherever nothing is drawn — with the island
/// pinned to its top centre, directly under the camera housing.
public struct IslandRootView: View {
    @ObservedObject private var controller: IslandController
    @ObservedObject private var media: NowPlayingStore
    @ObservedObject private var battery: BatteryMonitor
    @ObservedObject private var layout: IslandLayout
    private let surface: IslandSurface

    @FocusState private var focus: IslandFocus?

    public init(
        controller: IslandController,
        media: NowPlayingStore,
        battery: BatteryMonitor,
        layout: IslandLayout,
        surface: IslandSurface = .content
    ) {
        self.controller = controller
        self.media = media
        self.battery = battery
        self.layout = layout
        self.surface = surface
    }

    public var body: some View {
        ZStack(alignment: .top) {
            if showsIsland {
                island
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea()
        // The island is black — the housing grown — so it is drawn in the
        // dark appearance whatever the system's, and `.primary` text on it is
        // light.
        .environment(\.colorScheme, .dark)
    }

    /// Hidden, the island stays only as a resting target, and only where a
    /// housing gives it somewhere invisible to sit.
    private var showsIsland: Bool {
        controller.state.isVisible || controller.hasRestingTarget
    }

    private var motion: IslandMotion {
        controller.style.motion.motion(for: controller.transition)
    }

    private var island: some View {
        let shape = NotchShape(NotchShapeMetrics.metrics(for: controller.state))
        let outline = NotchShape(NotchShapeMetrics.metrics(for: controller.state, lifted: isLifted))
        let lift = isLifted ? HoverLift.standard : HoverLift(width: 0, height: 0)

        return content
            // Clipped to the island before anything goes behind it, so the
            // content never spills past the outline.
            .clipShape(shape)
            .contentShape(shape)
            .background {
                // The surface is drawn outside the layout, so the lift grows
                // the shape without moving the content or changing the size
                // the island reports — the pointer region stays still under a
                // pointer that is resting on the edge.
                surfaceBackground(outline)
                    .padding(.horizontal, -lift.width / 2)
                    .padding(.bottom, -lift.height)
            }
            .background {
                if surface == .content {
                    sizeReporter
                }
            }
            .animation(controller.style.motion.hoverLift?.animation, value: isLifted)
            .animation(motion.shapeAnimation, value: controller.state)
            .modifier(SurfaceAccessibility(surface: surface, value: stateDescription))
            .onChange(of: focus) { _, latest in
                // Tells the dismiss timer that someone is holding focus.
                if surface == .content {
                    controller.setKeyboardFocus(latest != nil)
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        let geometry = layout.geometry
        let minimum = geometry.minimumIslandSize(for: controller.state)

        Group {
            switch controller.state {
            case .hidden:
                RestingTargetView(onExpand: { controller.expandFromClick() })
                    .frame(width: minimum.width, height: minimum.height)

            case .collapsed:
                CollapsedContentView(
                    media: media.snapshot,
                    battery: battery.status,
                    style: controller.style,
                    housingWidth: geometry.housingSize.width,
                    minimumHeight: minimum.height,
                    onExpand: { controller.expandFromClick() }
                )
                .fixedSize()
                .transition(motion.transition)

            case .expanded:
                ExpandedContentView(
                    media: media.snapshot,
                    battery: battery.status,
                    style: controller.style,
                    housingHeight: geometry.housingSize.height,
                    focus: $focus,
                    onCommand: { media.send($0) }
                )
                .frame(width: minimum.width)
                .frame(minHeight: minimum.height, alignment: .top)
                // Text wraps across the fixed width and grows the island
                // downward, rather than widening it or shrinking the text.
                .fixedSize(horizontal: false, vertical: true)
                .transition(motion.transition)
            }
        }
        .opacity(surface == .content ? 1 : 0)
        .allowsHitTesting(surface == .content)
    }

    @ViewBuilder
    private func surfaceBackground(_ shape: NotchShape) -> some View {
        switch surface {
        case .content:
            IslandBackground(style: controller.style, shape: shape)
        case .backdrop:
            // The shadow only where there is an island to lift, and only where
            // translucent falloff is wanted. At rest the island is invisible on
            // purpose, so it casts nothing.
            if controller.state.isVisible, controller.style.background == .material {
                shape
                    .fill(.black)
                    .shadow(color: .black.opacity(0.45), radius: 14, y: 6)
            }
        }
    }

    /// Reports the island's laid-out size, which is where any morph in flight
    /// is heading — the app layer sizes the canvas and tracks the pointer by
    /// it.
    private var sizeReporter: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear { layout.islandSize = proxy.size }
                .onChange(of: proxy.size) { _, size in
                    layout.islandSize = size
                }
        }
    }

    // MARK: Hover lift

    /// The island grows a few points while the pointer rests on it, before it
    /// opens: the acknowledgement that the pointer has been noticed. Never
    /// while open, and never under Reduce Motion.
    private var isLifted: Bool {
        controller.hasPointerInside
            && !controller.state.isExpanded
            && controller.style.motion.hoverLift != nil
    }

    private var stateDescription: String {
        switch controller.state {
        case .hidden: "Hidden"
        case .collapsed: "Collapsed"
        case .expanded: "Expanded"
        }
    }
}

/// The content surface is the accessible one: a container with a name and a
/// state, so VoiceOver announces "Pod, expanded" rather than an anonymous
/// group. The backdrop is decoration and is not there at all.
private struct SurfaceAccessibility: ViewModifier {
    let surface: IslandSurface
    let value: String

    func body(content: Content) -> some View {
        switch surface {
        case .content:
            content
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Pod")
                .accessibilityValue(value)
        case .backdrop:
            content
                .accessibilityHidden(true)
        }
    }
}
