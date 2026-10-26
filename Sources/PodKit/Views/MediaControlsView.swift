import SwiftUI

/// Where the keyboard focus can land inside the island.
public enum IslandFocus: Hashable, Sendable {
    case previous
    case playPause
    case next
}

/// Transport controls.
///
/// Each one is a real button with a spoken label, its own focus stop, and a
/// hit target at the accessibility floor however small the glyph is drawn.
struct MediaControlsView: View {
    let snapshot: NowPlaying
    let style: IslandStyle
    @FocusState.Binding var focus: IslandFocus?
    let onCommand: (MediaCommand) -> Void

    var body: some View {
        HStack(spacing: 2) {
            control(
                stop: .previous,
                command: .previous,
                symbol: "backward.fill",
                label: "Previous track"
            )

            control(
                stop: .playPause,
                command: snapshot.isPlaying ? .pause : .play,
                symbol: snapshot.isPlaying ? "pause.fill" : "play.fill",
                label: snapshot.isPlaying ? "Pause" : "Play"
            )

            control(
                stop: .next,
                command: .next,
                symbol: "forward.fill",
                label: "Next track"
            )
        }
    }

    private func control(
        stop: IslandFocus,
        command: MediaCommand,
        symbol: String,
        label: String
    ) -> some View {
        Button {
            onCommand(command)
        } label: {
            Image(systemName: symbol)
                .imageScale(.medium)
                .frame(minWidth: style.minimumHitTarget, minHeight: style.minimumHitTarget)
                // Without this the target is the glyph's own bounds, which is
                // a few points across.
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Explicit, so Tab reaches the controls whether or not the user has
        // switched on Full Keyboard Access.
        .focusable()
        .focused($focus, equals: stop)
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isButton)
    }
}
