import SwiftUI

/// The resting island.
///
/// Read as a single accessibility element: a screen reader should get one
/// sentence about what the machine is doing, not three unlabelled fragments
/// to step through.
struct CollapsedContentView: View {
    let media: NowPlaying?
    let battery: BatteryStatus
    let style: IslandStyle

    var body: some View {
        HStack(spacing: 8) {
            if let media {
                Image(systemName: media.isPlaying ? "waveform" : "pause.fill")
                    .imageScale(.small)

                Text(media.title)
                    .font(.callout)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            BatteryBadgeView(status: battery, style: style)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: style.minimumHitTarget)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(summary)
        .accessibilityHint("Press Control Option Space to expand")
    }

    private var summary: String {
        var parts: [String] = []

        if let media {
            parts.append(media.accessibilityDescription)
        }

        if battery.isPresent {
            parts.append(battery.accessibilityDescription)
        }

        return parts.isEmpty ? "Nothing playing" : parts.joined(separator: ". ")
    }
}
