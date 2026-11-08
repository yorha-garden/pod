import CoreGraphics
import Testing
@testable import PodKit

@Suite("Island shape and canvas")
struct IslandShapeTests {
    /// A 14-inch MacBook Pro's logical frame and camera housing.
    private let notched = NotchGeometry(
        screenFrame: CGRect(x: 0, y: 0, width: 1710, height: 1112),
        housingSize: CGSize(width: 208, height: 37.5)
    )

    private let external = NotchGeometry(
        screenFrame: CGRect(x: 0, y: 0, width: 1710, height: 1112)
    )

    // MARK: Sizes per state

    @Test("At rest the island is the housing exactly, so it draws nowhere the display has pixels")
    func restingIsTheHousing() {
        #expect(notched.minimumIslandSize(for: .hidden) == notched.housingSize)
    }

    @Test("Collapsed, the island is at least the housing, and never below the hit floor")
    func collapsedFloor() {
        let size = notched.minimumIslandSize(for: .collapsed(.hover))

        #expect(size.width == notched.housingSize.width)
        #expect(size.height == IslandStyle.hitTargetFloor)
        #expect(external.minimumIslandSize(for: .collapsed(.hover)).height == IslandStyle.hitTargetFloor)
    }

    @Test("Open, the island is the housing grown outward")
    func expandedGrowsFromTheHousing() {
        #expect(notched.minimumIslandSize(for: .expanded(.hover)) == CGSize(width: 368, height: 179.5))
    }

    @Test("Open on a display without a housing, the island keeps a usable size")
    func expandedWithoutHousing() {
        #expect(external.minimumIslandSize(for: .expanded(.hover)) == CGSize(width: 345, height: 175))
    }

    // MARK: Canvas

    @Test("The canvas hangs from the top edge, centred on the housing")
    func canvasIsCentredAndPinned() {
        let canvas = notched.canvasFrame(fitting: CGSize(width: 368, height: 180))

        #expect(canvas.maxY == notched.screenFrame.maxY)
        #expect(canvas.midX == notched.housingRect.midX)
        #expect(canvas.width >= NotchGeometry.minimumCanvasSize.width)
        #expect(canvas.height >= NotchGeometry.minimumCanvasSize.height)
    }

    @Test("The canvas keeps the display's centre line on an odd-width display")
    func canvasParity() {
        let odd = NotchGeometry(screenFrame: CGRect(x: 0, y: 0, width: 1511, height: 982))
        let canvas = odd.canvasFrame(fitting: CGSize(width: 300, height: 100))

        #expect(canvas.midX == odd.screenFrame.midX)
        #expect(canvas.minX == canvas.minX.rounded())
    }

    @Test("The canvas grows for an island that outgrows it, and is clamped to the display")
    func canvasGrowsAndClamps() {
        let large = CGSize(width: 900, height: 500)
        let canvas = notched.canvasFrame(fitting: large)

        #expect(canvas.width >= large.width + 2 * NotchGeometry.canvasMargin)
        #expect(canvas.height >= large.height + NotchGeometry.canvasMargin)
        #expect(!notched.canvas(notched.canvasFrame(fitting: .zero), fits: large))
        #expect(notched.canvas(canvas, fits: large))

        let huge = notched.canvasFrame(fitting: CGSize(width: 5000, height: 5000))
        #expect(notched.screenFrame.contains(huge))
    }

    @Test("The island sits on screen exactly where the canvas pins it")
    func islandFrameOnScreen() {
        let frame = notched.islandFrame(forSize: notched.housingSize)

        #expect(frame == notched.housingRect)
        #expect(notched.islandFrame(forSize: .zero).isNull)
    }

    // MARK: Corners

    @Test("Collapsed corners match the housing's; open corners are softer")
    func cornerRadii() {
        #expect(NotchShapeMetrics.metrics(for: .hidden) == .collapsed)
        #expect(NotchShapeMetrics.metrics(for: .collapsed(.hover)) == .collapsed)
        #expect(NotchShapeMetrics.metrics(for: .expanded(.hover)) == .expanded)
        #expect(NotchShapeMetrics.metrics(for: .hidden, lifted: true) == .lifted)
        // Open, the lift does not apply: the island is already as far out as
        // it goes.
        #expect(NotchShapeMetrics.metrics(for: .expanded(.hover), lifted: true) == .expanded)
        #expect(NotchShapeMetrics.expanded.bottomCornerRadius > NotchShapeMetrics.collapsed.bottomCornerRadius)
    }

    @Test("Radii are clamped to what the island's size can hold")
    func radiiAreClamped() {
        let metrics = NotchShapeMetrics(topCornerRadius: 40, bottomCornerRadius: 60)

        let small = metrics.clamped(to: CGSize(width: 40, height: 30))
        #expect(small.bottomCornerRadius == 20)
        #expect(small.topCornerRadius == 10)

        let tall = metrics.clamped(to: CGSize(width: 400, height: 400))
        #expect(tall.topCornerRadius == NotchShapeMetrics.maximumTopCornerRadius)

        let flat = NotchShapeMetrics.collapsed.clamped(to: CGSize(width: 200, height: 10))
        #expect(flat.topCornerRadius == 0)
    }
}
