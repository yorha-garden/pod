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
    /// Focus for the unseen sizers, kept apart from the island's own.
    @FocusState private var sizerFocus: IslandFocus?

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
        .background(alignment: .top) {
            // Measured once, by the content surface; the backdrop reads the
            // same sizes from the shared layout.
            if surface == .content {
                sizers
            }
        }
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

    /// The island: one persistent container whose frame is given per state
    /// and springs between them. That frame is what morphs — the content
    /// inside it is swapped with a transition and clipped to the outline, and
    /// the surface is drawn behind it, reaching past it for the hover lift.
    private var island: some View {
        let size = islandSize
        let shape = NotchShape(NotchShapeMetrics.metrics(for: controller.state))
        let outline = NotchShape(NotchShapeMetrics.metrics(for: controller.state, lifted: isLifted))
        let outset = HoverLift.outset(lifted: isLifted, pressed: isDipped)

        return ZStack(alignment: .top) {
            content
        }
        .opacity(surface == .content ? 1 : 0)
        .allowsHitTesting(surface == .content)
        .frame(width: size.width, height: size.height, alignment: .top)
        // Clipped to the island before anything goes behind it, so the
        // content never spills past the outline.
        .clipShape(shape)
        .contentShape(shape)
        .background {
            // The surface is drawn outside the layout, so the lift grows the
            // shape without moving the content or changing the size the
            // island reports — the pointer region stays still under a pointer
            // that is resting on the edge.
            surfaceBackground(outline)
                .padding(.horizontal, -outset.width / 2)
                .padding(.bottom, -outset.height)
        }
        // Innermost wins: a step between states moves everything on its
        // spring, the lift and the dip included, so opening from a lifted or
        // pressed island starts where it is. A lift or dip on its own uses
        // its own spring.
        .animation(motion.shapeAnimation, value: controller.state)
        .animation(controller.style.motion.pressDip?.animation, value: isDipped)
        .animation(controller.style.motion.hoverLift?.animation, value: isLifted)
        .modifier(SurfaceAccessibility(surface: surface, value: stateDescription))
        .onChange(of: focus) { _, latest in
            // Tells the dismiss timer that someone is holding focus.
            if surface == .content {
                controller.setKeyboardFocus(latest != nil)
            }
        }
        .onChange(of: size, initial: true) { _, size in
            // Where the morph is heading: the app layer sizes the canvas and
            // tracks the pointer by it.
            if surface == .content {
                layout.islandSize = size
            }
        }
    }

    /// The size the island springs toward in the current state.
    private var islandSize: CGSize {
        layout.geometry.islandSize(
            for: controller.state,
            collapsedContent: layout.collapsedContentSize,
            expandedContentHeight: layout.expandedContentHeight
        )
    }

    @ViewBuilder
    private var content: some View {
        let geometry = layout.geometry

        switch controller.state {
        case .hidden:
            RestingTargetView(
                onExpand: { controller.expandFromClick() },
                onPressChange: reportPress
            )
            .frame(width: geometry.housingSize.width, height: geometry.housingSize.height)

        case .collapsed:
            collapsedContent(onExpand: { controller.expandFromClick() }, onPressChange: reportPress)
                .transition(motion.transition)

        case .expanded:
            expandedContent(focus: $focus, onCommand: { media.send($0) })
                .transition(motion.transition)
        }
    }

    private func collapsedContent(
        onExpand: @escaping () -> Void,
        onPressChange: @escaping (Bool) -> Void
    ) -> some View {
        let geometry = layout.geometry

        return CollapsedContentView(
            media: media.snapshot,
            battery: battery.status,
            style: controller.style,
            housingWidth: geometry.housingSize.width,
            minimumHeight: geometry.minimumIslandSize(for: .collapsed(.hover)).height,
            onExpand: onExpand,
            onPressChange: onPressChange
        )
        .fixedSize()
    }

    private func expandedContent(
        focus: FocusState<IslandFocus?>.Binding,
        onCommand: @escaping (MediaCommand) -> Void
    ) -> some View {
        let geometry = layout.geometry

        return ExpandedContentView(
            media: media.snapshot,
            battery: battery.status,
            style: controller.style,
            housingHeight: geometry.housingSize.height,
            focus: focus,
            onCommand: onCommand
        )
        .frame(width: geometry.minimumIslandSize(for: .expanded(.hover)).width)
        // Text wraps across the fixed width and grows the island downward,
        // rather than widening it or shrinking the text.
        .fixedSize(horizontal: false, vertical: true)
    }

    /// Both states' content, laid out unseen, so the size of a state is known
    /// before the island moves to it — the frame can then spring straight to
    /// its destination instead of jumping to whatever the incoming content
    /// measures.
    private var sizers: some View {
        ZStack(alignment: .top) {
            collapsedContent(onExpand: {}, onPressChange: { _ in })
                .onGeometryChange(for: CGSize.self, of: \.size) { size in
                    layout.collapsedContentSize = size
                }

            expandedContent(focus: $sizerFocus, onCommand: { _ in })
                .onGeometryChange(for: CGFloat.self, of: \.size.height) { height in
                    layout.expandedContentHeight = height
                }
        }
        .hidden()
        .disabled(true)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func reportPress(_ pressed: Bool) {
        if surface == .content {
            controller.setPressed(pressed)
        }
    }

    @ViewBuilder
    private func surfaceBackground(_ shape: NotchShape) -> some View {
        switch surface {
        case .content:
            IslandBackground(style: controller.style, shape: shape)
        case .backdrop:
            // Always there, so it moves with the island on the same spring:
            // inserted only when the island showed, it appeared at its final
            // size and faded in, a box at the open size behind an island
            // still growing — and lingered at that size while it shrank. Only
            // the shadow comes and goes. It falls only where there is an
            // island to lift, and only where translucent falloff is wanted; at
            // rest the island is invisible on purpose, so it casts nothing.
            shape
                .fill(.black)
                .shadow(color: .black.opacity(castsShadow ? 0.45 : 0), radius: 14, y: 6)
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

    private var castsShadow: Bool {
        controller.state.isVisible && controller.style.background == .material
    }

    /// A held click on the lifted island dips it back, until the release
    /// opens it.
    private var isDipped: Bool {
        isLifted && controller.isPressed && controller.style.motion.pressDip != nil
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
