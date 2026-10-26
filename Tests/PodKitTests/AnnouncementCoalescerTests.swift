import Foundation
import Testing
@testable import PodKit

@Suite("Screen reader announcement coalescing")
struct AnnouncementCoalescerTests {
    private let start = Date(timeIntervalSince1970: 1_000_000)

    @Test("The first announcement is always spoken")
    func firstIsSpoken() {
        var coalescer = AnnouncementCoalescer()

        #expect(coalescer.admit(Announcement("Playing"), at: start) != nil)
    }

    @Test("A repeat inside the duplicate window is dropped")
    func repeatIsDropped() {
        var coalescer = AnnouncementCoalescer(duplicateWindow: 2)
        _ = coalescer.admit(Announcement("Battery 20 percent"), at: start)

        let again = coalescer.admit(
            Announcement("Battery 20 percent"),
            at: start.addingTimeInterval(1)
        )

        #expect(again == nil)
    }

    @Test("A repeat is spoken again once the window has passed")
    func repeatSpokenAfterWindow() {
        var coalescer = AnnouncementCoalescer(duplicateWindow: 2)
        _ = coalescer.admit(Announcement("Battery 20 percent"), at: start)

        let again = coalescer.admit(
            Announcement("Battery 20 percent"),
            at: start.addingTimeInterval(2.5)
        )

        #expect(again != nil)
    }

    @Test("Low priority chatter is dropped inside the quiet period")
    func chatterIsDropped() {
        var coalescer = AnnouncementCoalescer(quietPeriod: 0.75)
        _ = coalescer.admit(Announcement("Volume 40 percent", priority: .low), at: start)

        let chatter = coalescer.admit(
            Announcement("Volume 45 percent", priority: .low),
            at: start.addingTimeInterval(0.2)
        )

        #expect(chatter == nil)
    }

    @Test("High priority interrupts even as an immediate repeat")
    func urgentAlwaysInterrupts() {
        var coalescer = AnnouncementCoalescer()
        let urgent = Announcement("Battery critically low", priority: .high)
        _ = coalescer.admit(urgent, at: start)

        let again = coalescer.admit(urgent, at: start.addingTimeInterval(0.05))

        #expect(again == urgent)
    }

    @Test("Reset lets the same message through again")
    func resetClearsHistory() {
        var coalescer = AnnouncementCoalescer()
        _ = coalescer.admit(Announcement("Playing"), at: start)

        coalescer.reset()

        #expect(coalescer.admit(Announcement("Playing"), at: start.addingTimeInterval(0.1)) != nil)
    }
}
