import CoreGraphics
import Testing
@testable import PodKit

@Suite("Notch geometry")
struct NotchGeometryTests {
    /// A 13-inch MacBook Air's logical frame and camera housing.
    private let notched = NotchGeometry(
        screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982),
        housingSize: CGSize(width: 200, height: 38)
    )

    /// An external display: same frame, nothing to work around.
    private let external = NotchGeometry(
        screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982)
    )

    @Test("The housing sits centred on the top edge")
    func housingIsCentred() {
        #expect(notched.hasHousing)
        #expect(notched.housingRect == CGRect(x: 656, y: 944, width: 200, height: 38))
    }

    @Test("A display without a housing reports none")
    func externalHasNoHousing() {
        #expect(!external.hasHousing)
        #expect(external.housingRect.isNull)
    }

    @Test("The island is centred and pinned to the top edge")
    func islandIsPinnedToTop() {
        let frame = notched.frame(forContentOfSize: CGSize(width: 320, height: 90))

        #expect(frame.midX == notched.screenFrame.midX)
        #expect(frame.maxY == notched.screenFrame.maxY)
    }

    @Test("The island is never narrower than the housing it works around")
    func islandCoversTheHousingWidth() {
        let frame = notched.frame(forContentOfSize: CGSize(width: 120, height: 30))

        #expect(frame.width >= notched.housingSize.width)
    }

    @Test("Content shorter than the hit floor still gets a reachable target")
    func heightRespectsTheHitFloor() {
        let frame = notched.frame(forContentOfSize: CGSize(width: 320, height: 12))

        #expect(frame.height == IslandStyle.hitTargetFloor)
    }

    @Test("Oversized content is clamped to the display, not grown off-screen")
    func oversizedContentIsClamped() {
        let frame = notched.frame(forContentOfSize: CGSize(width: 5000, height: 4000))

        #expect(frame.width == notched.screenFrame.width)
        #expect(frame.height == notched.screenFrame.height)
        #expect(notched.screenFrame.contains(frame))
    }

    @Test("Growing content grows the island rather than clipping it")
    func contentGrowthGrowsTheIsland() {
        let small = notched.frame(forContentOfSize: CGSize(width: 320, height: 80))
        let large = notched.frame(forContentOfSize: CGSize(width: 320, height: 160))

        #expect(large.height > small.height)
    }

    @Test("The occluded band matches the housing height")
    func occlusionMatchesHousing() {
        let frame = notched.frame(forContentOfSize: CGSize(width: 320, height: 120))

        #expect(notched.occlusion(in: frame).height == 38)
        #expect(notched.topInsetClearingHousing(in: frame) == 38)
    }

    @Test("There is nothing to clear on a display without a housing")
    func noOcclusionWithoutHousing() {
        let frame = external.frame(forContentOfSize: CGSize(width: 320, height: 120))

        #expect(external.occlusion(in: frame).isNull)
        #expect(external.topInsetClearingHousing(in: frame) == 0)
    }
}
