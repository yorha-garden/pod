import Foundation

/// Decides when a draining battery is worth interrupting the user for.
///
/// A low battery keeps reporting itself — every percent it loses is a new
/// reading — and each reading is not a new event. The warning comes when the
/// battery *becomes* low, and once more at each deeper step, so the island
/// pops out and VoiceOver speaks three times in a whole discharge rather than
/// twenty.
///
/// Connecting the charger, or the level climbing clearly back above the
/// threshold, re-arms it, so the next discharge warns again. The margin keeps a
/// reading that wavers between 20 and 21 percent from warning on every swing.
public struct LowBatteryWarning: Equatable, Sendable {
    /// The levels a discharge is warned at, from the first down.
    public static let thresholds = [20, 10, 5]

    /// How far above the first threshold the level must climb, on battery,
    /// before a later fall below it warns again.
    public static let rearmMargin = 3

    /// The deepest threshold already warned for in this discharge.
    private var warnedAt: Int?

    public init() {}

    /// Feeds one reading; true when this reading is the one to warn about.
    public mutating func shouldWarn(for status: BatteryStatus) -> Bool {
        guard status.isPresent, !status.isCharging else {
            warnedAt = nil
            return false
        }

        let first = Self.thresholds[0]

        if status.percentage > first + Self.rearmMargin {
            warnedAt = nil
            return false
        }

        // The deepest step this reading has reached, if it has reached one.
        guard let reached = Self.thresholds.last(where: { status.percentage <= $0 }) else {
            // Just above the threshold, inside the margin: neither low nor
            // far enough back to warn again.
            return false
        }

        if let warnedAt, reached >= warnedAt {
            return false
        }

        warnedAt = reached
        return true
    }
}
