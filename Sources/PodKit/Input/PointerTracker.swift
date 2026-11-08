import AppKit

/// Where the pointer counts as over the island, in screen coordinates.
///
/// The island's window is a large transparent canvas, so the window's bounds
/// say nothing about where the island is. This is the island's own rect —
/// with a little slack to leave by, so the hover lift growing the shape under
/// a pointer resting at its edge does not flip it out and back in again.
public struct HoverRegion: Equatable, Sendable {
    public var island: CGRect
    /// How far outside the island the pointer may drift, once in, before it
    /// counts as having left.
    public var exitSlack: CGFloat

    public init(island: CGRect, exitSlack: CGFloat = 8) {
        self.island = island
        self.exitSlack = exitSlack
    }

    public static let none = HoverRegion(island: .null)

    /// Whether a pointer at `point` is over the island, given whether it was
    /// a moment ago.
    public func contains(_ point: CGPoint, wasInside: Bool) -> Bool {
        guard !island.isNull, !island.isEmpty else { return false }

        let region = wasInside ? island.insetBy(dx: -exitSlack, dy: -exitSlack) : island
        // The top edge is the display's edge: a pointer pushed against it is
        // still over the island, so the region runs past it.
        let reaching = CGRect(
            x: region.minX,
            y: region.minY,
            width: region.width,
            height: region.height + exitSlack
        )
        return reaching.contains(point)
    }
}

/// Reports the pointer entering and leaving the island, and clicks that land
/// anywhere else.
///
/// Follows the pointer with event monitors rather than a tracking area, so
/// what counts is the island's shape, not the canvas around it — and so it
/// keeps working while the pointer is over another app's window, which it is
/// whenever it is over the canvas's transparent part. Mouse monitors need no
/// accessibility permission; only key monitors do.
@MainActor
public final class PointerTracker {
    public var region: HoverRegion = .none {
        didSet {
            guard region != oldValue else { return }
            // The island moved or resized under a pointer that may be resting
            // still: re-evaluate now rather than on the next movement.
            evaluate(NSEvent.mouseLocation)
        }
    }

    private let onChange: (Bool) -> Void
    private let onClickOutside: () -> Void
    private var isInside = false
    private var monitors: [Any] = []

    public init(onChange: @escaping (Bool) -> Void, onClickOutside: @escaping () -> Void = {}) {
        self.onChange = onChange
        self.onClickOutside = onClickOutside

        let moves: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged]
        let clicks: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown]

        // Global monitors see events bound for other apps — including the
        // ones that fall through the canvas's transparent part.
        if let global = NSEvent.addGlobalMonitorForEvents(matching: moves.union(clicks), handler: { [weak self] event in
            let type = event.type
            MainActor.assumeIsolated {
                self?.handle(type, at: NSEvent.mouseLocation)
            }
        }) {
            monitors.append(global)
        }

        // Local monitors see the ones that land on Pod's own panel.
        if let local = NSEvent.addLocalMonitorForEvents(matching: moves, handler: { [weak self] event in
            let type = event.type
            MainActor.assumeIsolated {
                self?.handle(type, at: NSEvent.mouseLocation)
            }
            return event
        }) {
            monitors.append(local)
        }
    }

    deinit {
        for monitor in monitors {
            NSEvent.removeMonitor(monitor)
        }
    }

    private func handle(_ type: NSEvent.EventType, at location: CGPoint) {
        switch type {
        case .leftMouseDown, .rightMouseDown:
            // Only global clicks arrive here, so this one went to another app.
            if !region.contains(location, wasInside: false) {
                onClickOutside()
            }
        default:
            evaluate(location)
        }
    }

    private func evaluate(_ location: CGPoint) {
        let inside = region.contains(location, wasInside: isInside)
        guard inside != isInside else { return }

        isInside = inside
        onChange(inside)
    }
}
