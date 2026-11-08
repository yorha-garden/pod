import Testing
@testable import PodKit

@Suite("Low battery warning")
struct LowBatteryWarningTests {
    private func onBattery(_ percentage: Int) -> BatteryStatus {
        BatteryStatus(percentage: percentage, isCharging: false, isPresent: true)
    }

    private func charging(_ percentage: Int) -> BatteryStatus {
        BatteryStatus(percentage: percentage, isCharging: true, isPresent: true)
    }

    /// Feeds readings in order and returns which ones warned.
    private func warnings(_ readings: [BatteryStatus]) -> [Bool] {
        var warning = LowBatteryWarning()
        return readings.map { warning.shouldWarn(for: $0) }
    }

    @Test("Successive low readings warn once, not on every percent lost")
    func successiveLowReadingsWarnOnce() {
        #expect(warnings([onBattery(13), onBattery(12), onBattery(11)]) == [true, false, false])
    }

    @Test("Becoming low warns")
    func becomingLowWarns() {
        #expect(warnings([onBattery(22), onBattery(21), onBattery(20), onBattery(19)]) == [false, false, true, false])
    }

    @Test("Already low when Pod starts, it warns once")
    func lowAtLaunchWarnsOnce() {
        #expect(warnings([onBattery(13), onBattery(13), onBattery(12)]) == [true, false, false])
    }

    @Test("Each deeper step warns once")
    func deeperStepsWarnOnceEach() {
        let readings = [19, 12, 10, 9, 6, 5, 4, 1].map(onBattery)

        #expect(warnings(readings) == [true, false, true, false, false, true, false, false])
    }

    @Test("A drop straight past a step warns for the deepest step reached, once")
    func dropPastSeveralSteps() {
        #expect(warnings([onBattery(8), onBattery(7), onBattery(4)]) == [true, false, true])
    }

    @Test("Charging re-arms it, so a later discharge warns again")
    func chargingRearms() {
        let readings = [onBattery(15), charging(15), charging(30), onBattery(30), onBattery(20), onBattery(18)]

        #expect(warnings(readings) == [true, false, false, false, true, false])
    }

    @Test("Unplugging while still low warns again, once")
    func unpluggingWhileLowWarns() {
        #expect(warnings([onBattery(15), charging(16), onBattery(16), onBattery(15)]) == [true, false, true, false])
    }

    @Test("A reading wavering just above the threshold does not warn again")
    func waveringDoesNotRewarn() {
        let readings = [20, 21, 20, 22, 20, 23, 19].map(onBattery)

        #expect(warnings(readings) == [true, false, false, false, false, false, false])
    }

    @Test("Climbing clearly back above the threshold re-arms it")
    func climbingBackRearms() {
        let readings = [20, 24, 20].map(onBattery)

        #expect(warnings(readings) == [true, false, true])
    }

    @Test("The first warning comes exactly where the badge starts saying Low")
    func firstStepMatchesTheBadge() {
        let first = LowBatteryWarning.thresholds[0]

        #expect(onBattery(first).isLow)
        #expect(!onBattery(first + 1).isLow)
    }

    @Test("No battery never warns")
    func noBatteryNeverWarns() {
        #expect(warnings([.absent, .absent]) == [false, false])
    }
}
