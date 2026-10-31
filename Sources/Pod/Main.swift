import AppKit
import PodKit

// Pod runs as an agent: no Dock icon, no window of its own, just the island.
@main
@MainActor
enum Main {
    /// Held here on purpose — `NSApplication.delegate` is a weak reference, so
    /// a local would be deallocated the moment `main` returned into `run`.
    private static let coordinator = AppCoordinator()

    static func main() {
        let application = NSApplication.shared

        application.delegate = coordinator
        application.setActivationPolicy(.accessory)
        application.run()
    }
}
