import Testing
@testable import PodKit

@Suite("Battery status")
struct BatteryStatusTests {
    @Test("A low battery is low only while it is not charging")
    func lowRequiresDischarging() {
        let discharging = BatteryStatus(percentage: 15, isCharging: false, isPresent: true)
        let charging = BatteryStatus(percentage: 15, isCharging: true, isPresent: true)

        #expect(discharging.isLow)
        #expect(!charging.isLow)
    }

    @Test("An absent battery is never low")
    func absentIsNeverLow() {
        #expect(!BatteryStatus.absent.isLow)
        #expect(BatteryStatus.absent.accessibilityDescription == "No battery")
    }

    @Test("The low state carries a cue that is not colour", arguments: [5, 12, 20])
    func lowStateIsSpokenAndDrawn(percentage: Int) {
        let status = BatteryStatus(percentage: percentage, isCharging: false, isPresent: true)
        let healthy = BatteryStatus(percentage: 85, isCharging: false, isPresent: true)

        // Spoken, so a screen reader hears it.
        #expect(status.accessibilityDescription.contains("low"))
        // And drawn differently, so a sighted user who cannot pick out a red
        // tint still sees a different glyph.
        #expect(status.symbolName != healthy.symbolName)
    }

    @Test("Charging is announced and gets its own glyph")
    func chargingIsDistinct() {
        let status = BatteryStatus(percentage: 42, isCharging: true, isPresent: true)

        #expect(status.accessibilityDescription == "Battery 42 percent, charging")
        #expect(status.symbolName.contains("bolt"))
    }

    @Test("Reading the real power source does not trap")
    @MainActor
    func readingRealHardwareIsSafe() {
        // Exercises the IOKit path on whatever machine the suite runs on;
        // a desktop with no battery must come back absent, not crash.
        let status = BatteryMonitor.read()

        if status.isPresent {
            #expect(status.percentage >= 0 && status.percentage <= 100)
        } else {
            #expect(status == .absent)
        }
    }
}
