import CoreGraphics
import Testing
@testable import PodKit

@Suite("Hover region")
struct HoverRegionTests {
    private let region = HoverRegion(
        island: CGRect(x: 751, y: 1074.5, width: 208, height: 37.5),
        exitSlack: 8
    )

    @Test("The pointer enters only over the island itself")
    func entersOverTheIsland() {
        #expect(region.contains(CGPoint(x: 855, y: 1090), wasInside: false))
        #expect(!region.contains(CGPoint(x: 745, y: 1090), wasInside: false))
        #expect(!region.contains(CGPoint(x: 855, y: 1070), wasInside: false))
    }

    @Test("Once in, the pointer may drift a little before it counts as gone")
    func leavesWithSlack() {
        let justOutside = CGPoint(x: 745, y: 1090)

        #expect(region.contains(justOutside, wasInside: true))
        #expect(!region.contains(CGPoint(x: 700, y: 1090), wasInside: true))
    }

    @Test("A pointer pushed against the top edge is still over the island")
    func topEdgeCounts() {
        #expect(region.contains(CGPoint(x: 855, y: 1112), wasInside: false))
    }

    @Test("Nothing is over an island that is not there")
    func emptyRegion() {
        #expect(!HoverRegion.none.contains(.zero, wasInside: true))
    }
}
