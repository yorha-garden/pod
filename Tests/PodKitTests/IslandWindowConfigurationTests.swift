import AppKit
import Testing
@testable import PodKit

@Suite("Island windows")
struct IslandWindowConfigurationTests {
    @Test("The content panel sits one above the shield, the backdrop at it")
    func levels() {
        let shield = Int(CGShieldingWindowLevel())

        #expect(IslandWindowConfiguration.content.level.rawValue == shield + 1)
        #expect(IslandWindowConfiguration.backdrop.level.rawValue == shield)
    }

    @Test("Both panels join every Space, stay put, skip the window cycle and sit beside full-screen apps")
    func collectionBehaviour() {
        for configuration in [IslandWindowConfiguration.content, .backdrop] {
            #expect(configuration.collectionBehavior.rawValue == 0x151)
            #expect(configuration.collectionBehavior.contains(.canJoinAllSpaces))
            #expect(configuration.collectionBehavior.contains(.stationary))
            #expect(configuration.collectionBehavior.contains(.ignoresCycle))
            #expect(configuration.collectionBehavior.contains(.fullScreenAuxiliary))
        }
    }

    @Test("Neither panel activates Pod, and the content runs to the window's edges")
    func styleMask() {
        for configuration in [IslandWindowConfiguration.content, .backdrop] {
            #expect(configuration.styleMask.contains(.nonactivatingPanel))
            #expect(configuration.styleMask.contains(.fullSizeContentView))
            #expect(!configuration.styleMask.contains(.titled))
        }
    }

    @Test("Neither panel lets AppKit animate it: the island's motion is the style's alone")
    func noWindowAnimation() {
        #expect(IslandWindowConfiguration.content.animationBehavior == .none)
        #expect(IslandWindowConfiguration.backdrop.animationBehavior == .none)
    }

    @Test("The content panel takes the pointer only where it draws; the backdrop never does")
    func pointerHandling() {
        // Left on AppKit's per-pixel default, so the clear canvas around the
        // island lets clicks through to whatever is underneath.
        #expect(IslandWindowConfiguration.content.ignoresMouseEvents == nil)
        #expect(IslandWindowConfiguration.backdrop.ignoresMouseEvents == true)
        #expect(!IslandWindowConfiguration.backdrop.acceptsMouseMovedEvents)
    }

    @Test("Screen sharing can read the island but not capture it as a window of its own")
    func sharing() {
        #expect(IslandWindowConfiguration.content.sharingType == .readOnly)
        #expect(IslandWindowConfiguration.backdrop.sharingType == .readOnly)
    }
}
