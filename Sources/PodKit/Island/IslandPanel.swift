import AppKit

/// The window the island lives in.
///
/// A borderless `NSPanel` returns false from `canBecomeKey` by default, and
/// that single default is why notch overlays tend to be unreachable without a
/// mouse: with no key window there is no first responder, so there is no focus
/// ring, nothing for Tab to land on, and nothing for VoiceOver to navigate
/// into. Pod overrides it, and pairs it with `.nonactivatingPanel` so taking
/// the key focus does not drag the user out of the app they were working in.
public final class IslandPanel: NSPanel {
    /// Invoked on Escape, so the controller can dismiss.
    public var onCancel: (() -> Void)?

    public init(contentRect: CGRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isMovable = false
        isReleasedWhenClosed = false

        // Named, so VoiceOver announces the panel instead of an anonymous
        // window, and given the floating subrole it actually has.
        setAccessibilityLabel("Pod")
        setAccessibilitySubrole(.floatingWindow)
    }

    /// The override that makes the island reachable from the keyboard.
    public override var canBecomeKey: Bool { true }

    /// Still false: Pod is an agent and never becomes the active app. The
    /// panel can hold key focus for keyboard use without stealing the user's
    /// main window.
    public override var canBecomeMain: Bool { false }

    /// Escape dismisses, the way every other transient macOS surface does.
    public override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}
