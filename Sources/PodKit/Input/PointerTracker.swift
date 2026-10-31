import AppKit

/// Reports the pointer entering and leaving a view.
///
/// The tracking area is `.activeAlways`, so it reports whether or not Pod is
/// the active app — and Pod, as an agent, never is. `.inVisibleRect` keeps it
/// matched to the view as the island grows and shrinks, so it is installed
/// once. A tracking area does not retain its owner: keep the tracker alive.
@MainActor
public final class PointerTracker: NSResponder {
    private let onChange: (Bool) -> Void

    public init(view: NSView, onChange: @escaping (Bool) -> Void) {
        self.onChange = onChange
        super.init()

        view.addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    public override func mouseEntered(with event: NSEvent) {
        onChange(true)
    }

    public override func mouseExited(with event: NSEvent) {
        onChange(false)
    }
}
