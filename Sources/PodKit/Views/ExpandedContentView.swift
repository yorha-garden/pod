import SwiftUI

/// The island once it is open.
///
/// A container rather than one combined element, because now there are
/// controls to land on, and each needs its own label and focus stop.
struct ExpandedContentView: View {
    let media: NowPlaying?
    let battery: BatteryStatus
    let style: IslandStyle
    @FocusState.Binding var focus: IslandFocus?
    let onCommand: (MediaCommand) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let media {
                VStack(alignment: .leading, spacing: 2) {
                    Text(media.title)
                        .font(.headline)

                    if let artist = media.artist, !artist.isEmpty {
                        Text(artist)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                // Wraps and lets the island grow. A minimumScaleFactor would
                // shrink the text instead, which is the wrong trade for
                // anyone who set a larger size on purpose.
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(media.accessibilityDescription)

                MediaControlsView(
                    snapshot: media,
                    style: style,
                    focus: $focus,
                    onCommand: onCommand
                )
            } else {
                Text("Nothing playing")
                    .font(.headline)
            }

            Divider()

            BatteryBadgeView(status: battery, style: style)
        }
        .padding(14)
        .frame(minWidth: 280, alignment: .leading)
        .accessibilityElement(children: .contain)
    }
}
