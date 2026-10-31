import SwiftUI

/// The island at a glance.
///
/// One button with one sentence: a screen reader hears what the machine is
/// doing rather than stepping through three unlabelled fragments, and a click
/// or VoiceOver's press expands it.
struct CollapsedContentView: View {
    let media: NowPlaying?
    let battery: BatteryStatus
    let style: IslandStyle
    let onExpand: () -> Void

    var body: some View {
        Button(action: onExpand) {
            content
        }
        .buttonStyle(.plain)
        .accessibilityLabel(summary)
        .accessibilityHint("Expands Pod. Control Option Space also works.")
    }

    private var content: some View {
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
        // The whole island is the target, not just its glyphs and text.
        .contentShape(Rectangle())
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
