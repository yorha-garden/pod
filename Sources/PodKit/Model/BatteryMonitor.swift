import Foundation
import IOKit.ps

/// The machine's power state.
public struct BatteryStatus: Equatable, Sendable {
    public var percentage: Int
    public var isCharging: Bool
    public var isPresent: Bool

    public init(percentage: Int, isCharging: Bool, isPresent: Bool) {
        self.percentage = percentage
        self.isCharging = isCharging
        self.isPresent = isPresent
    }

    public static let absent = BatteryStatus(percentage: 0, isCharging: false, isPresent: false)

    public var isLow: Bool {
        isPresent && !isCharging && percentage <= 20
    }

    /// A glyph that carries the state on its own, so the badge never depends
    /// on a tint the user may not be able to pick out.
    public var symbolName: String {
        if isCharging { return "battery.100percent.bolt" }
        if percentage <= 10 { return "battery.0percent" }
        if percentage <= 20 { return "battery.25percent" }
        if percentage <= 60 { return "battery.50percent" }
        return "battery.100percent"
    }

    public var accessibilityDescription: String {
        guard isPresent else { return "No battery" }

        if isCharging {
            return "Battery \(percentage) percent, charging"
        }

        if isLow {
            return "Battery \(percentage) percent, low"
        }

        return "Battery \(percentage) percent"
    }
}

/// Polls the system power sources.
///
/// IOKit's power source API is public, unlike the system Now Playing state,
/// so this is a real reading rather than a placeholder.
@MainActor
public final class BatteryMonitor: ObservableObject {
    @Published public private(set) var status: BatteryStatus

    private var timer: Timer?

    public init(pollInterval: TimeInterval = 30) {
        self.status = Self.read()

        let timer = Timer(timeInterval: pollInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refresh()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    deinit {
        timer?.invalidate()
    }

    public func refresh() {
        let latest = Self.read()
        if latest != status {
            status = latest
        }
    }

    public static func read() -> BatteryStatus {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            return .absent
        }

        let sources = IOPSCopyPowerSourcesList(blob).takeRetainedValue() as [CFTypeRef]

        for source in sources {
            guard
                let description = IOPSGetPowerSourceDescription(blob, source)?
                    .takeUnretainedValue() as? [String: Any],
                let current = description[kIOPSCurrentCapacityKey] as? Int,
                let maximum = description[kIOPSMaxCapacityKey] as? Int,
                maximum > 0
            else {
                continue
            }

            let percentage = Int((Double(current) / Double(maximum) * 100).rounded())
            let state = description[kIOPSPowerSourceStateKey] as? String
            let charging = description[kIOPSIsChargingKey] as? Bool
                ?? (state == kIOPSACPowerValue)

            return BatteryStatus(percentage: percentage, isCharging: charging, isPresent: true)
        }

        return .absent
    }
}
