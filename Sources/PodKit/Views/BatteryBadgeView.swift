import SwiftUI

/// The battery readout.
///
/// Three cues for one state — glyph, number and, when it matters, the word
/// "Low". A tint is not one of them, because a red bar is no cue at all for
/// anyone who cannot pick red out.
struct BatteryBadgeView: View {
    let status: BatteryStatus
    let style: IslandStyle

    var body: some View {
        if status.isPresent {
            HStack(spacing: 4) {
                Image(systemName: status.symbolName)
                    .imageScale(.small)

                Text("\(status.percentage)%")
                    .font(.caption)
                    .monospacedDigit()

                if status.isLow {
                    Text("Low")
                        .font(.caption.weight(.semibold))
                }
            }
            .foregroundStyle(status.isLow ? .primary : .secondary)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(status.accessibilityDescription)
        }
    }
}
