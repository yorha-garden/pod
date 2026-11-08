import AppKit

/// How the island's two windows are set up.
///
/// The island is drawn into two stacked panels that share one fixed frame — a
/// transparent canvas hanging from the top edge of the display:
///
/// - the **content** panel holds the island and everything you can press;
/// - the **backdrop** panel, one level below, holds what is only decoration
///   (the shadow), and never takes the pointer.
///
/// Neither window is ever resized to follow the island. The island's shape
/// morphs inside the canvas instead, in SwiftUI, so its springs are the only
/// motion there is — AppKit's own window animation is switched off.
///
/// Kept as values, apart from the panels themselves, so the setup can be
/// asserted without creating a window.
public struct IslandWindowConfiguration: Equatable {
    public var styleMask: NSWindow.StyleMask
    public var level: NSWindow.Level
    public var collectionBehavior: NSWindow.CollectionBehavior
    public var sharingType: NSWindow.SharingType
    public var animationBehavior: NSWindow.AnimationBehavior
    public var canBecomeVisibleWithoutLogin: Bool
    /// `nil` leaves the window on AppKit's default, which is per-pixel: the
    /// window takes the pointer where it draws and lets it through where it
    /// is clear. That is what makes a canvas larger than the island harmless.
    public var ignoresMouseEvents: Bool?
    public var acceptsMouseMovedEvents: Bool

    /// The window server's shielding level — the one screen savers and the
    /// display-capture shield draw at. Public API, despite the `CG` prefix.
    public static var shieldingLevel: NSWindow.Level {
        NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
    }

    /// Borderless and non-activating, with the content view running to the
    /// window's edges so SwiftUI owns the whole canvas.
    public static let styleMask: NSWindow.StyleMask = [
        .borderless, .nonactivatingPanel, .fullSizeContentView,
    ]

    /// On every Space, fixed in place during Space switches, out of the window
    /// cycle, and allowed beside a full-screen app.
    public static let collectionBehavior: NSWindow.CollectionBehavior = [
        .canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary,
    ]

    /// The panel with the island in it: one above the shield, so it sits over
    /// everything an app can put on screen, menu bar and full-screen apps
    /// included.
    public static let content = IslandWindowConfiguration(
        styleMask: styleMask,
        level: NSWindow.Level(rawValue: shieldingLevel.rawValue + 1),
        collectionBehavior: collectionBehavior,
        sharingType: .readOnly,
        animationBehavior: .none,
        canBecomeVisibleWithoutLogin: true,
        ignoresMouseEvents: nil,
        acceptsMouseMovedEvents: true
    )

    /// The panel behind it: at the shield level itself, and never under the
    /// pointer, so a shadow's soft edge is never something you can click.
    public static let backdrop = IslandWindowConfiguration(
        styleMask: styleMask,
        level: shieldingLevel,
        collectionBehavior: collectionBehavior,
        sharingType: .readOnly,
        animationBehavior: .none,
        canBecomeVisibleWithoutLogin: false,
        ignoresMouseEvents: true,
        acceptsMouseMovedEvents: false
    )

    /// Applies everything except the style mask, which only the initialiser
    /// can set, and the level-independent basics every island window shares.
    @MainActor
    public func apply(to panel: NSPanel) {
        panel.hasShadow = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.isMovable = false
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.animationBehavior = animationBehavior
        panel.level = level
        panel.collectionBehavior = collectionBehavior
        panel.sharingType = sharingType
        panel.canBecomeVisibleWithoutLogin = canBecomeVisibleWithoutLogin
        panel.acceptsMouseMovedEvents = acceptsMouseMovedEvents
        if let ignoresMouseEvents {
            panel.ignoresMouseEvents = ignoresMouseEvents
        }
    }
}
