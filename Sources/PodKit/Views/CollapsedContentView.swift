import SwiftUI

/// The island at a glance: the housing, widened, with something either side.
///
/// One button with one sentence: a screen reader hears what the machine is
/// doing rather than stepping through three unlabelled fragments, and a click
/// or VoiceOver's press expands it. Nothing is drawn behind the housing —
/// the middle of the island is left empty, the housing's width wide.
struct CollapsedContentView: View {
    let media: NowPlaying?
    let battery: BatteryStatus
    let style: IslandStyle
    let housingWidth: CGFloat
    let minimumHeight: CGFloat
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
        NotchEarsLayout(gap: housingWidth, minimumHeight: minimumHeight) {
            leading
                .padding(.leading, 14)
                .padding(.trailing, 8)

            BatteryBadgeView(status: battery, style: style)
                .padding(.leading, 8)
                .padding(.trailing, 14)
        }
        .foregroundStyle(.primary)
        // The whole island is the target, not just its glyphs and text.
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var leading: some View {
        HStack(spacing: 6) {
            if let media {
                Image(systemName: media.isPlaying ? "waveform" : "pause.fill")
                    .imageScale(.small)

                Text(media.title)
                    .font(.callout)
                    .lineLimit(1)
            } else {
                Image(systemName: "music.note")
                    .imageScale(.small)
                    .foregroundStyle(.secondary)
            }
        }
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

/// Lays two views out either side of the camera housing, in ears of equal
/// width, so the island stays centred on the housing however lopsided its
/// content.
///
/// Each ear is at most `maximumEarWidth` wide, and what does not fit is
/// truncated by the content's own line limit — the full sentence is in the
/// button's label. The island is never shorter than `minimumHeight`.
struct NotchEarsLayout: Layout {
    var gap: CGFloat
    var minimumHeight: CGFloat
    var maximumEarWidth: CGFloat = 170

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = earSizes(subviews)
        let ear = sizes.map(\.width).max() ?? 0
        let height = max(minimumHeight, sizes.map(\.height).max() ?? 0)

        return CGSize(width: 2 * ear + gap, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let ear = max(0, (bounds.width - gap) / 2)
        let proposal = ProposedViewSize(width: ear, height: bounds.height)

        for (index, subview) in subviews.prefix(2).enumerated() {
            // The leading ear hugs its outer edge, the trailing ear its own:
            // content sits against the island's ends, clear of the housing.
            let isLeading = index == 0
            subview.place(
                at: CGPoint(x: isLeading ? bounds.minX : bounds.maxX, y: bounds.midY),
                anchor: isLeading ? .leading : .trailing,
                proposal: proposal
            )
        }
    }

    private func earSizes(_ subviews: Subviews) -> [CGSize] {
        subviews.prefix(2).map {
            $0.sizeThatFits(ProposedViewSize(width: maximumEarWidth, height: nil))
        }
    }
}
