import Foundation

/// What is playing, as far as Pod knows.
public struct NowPlaying: Equatable, Sendable {
    public var title: String
    public var artist: String?
    public var isPlaying: Bool

    public init(title: String, artist: String? = nil, isPlaying: Bool = false) {
        self.title = title
        self.artist = artist
        self.isPlaying = isPlaying
    }

    /// What a screen reader should hear for this snapshot.
    ///
    /// Built on the model rather than in the view, so the sentence a VoiceOver
    /// user gets is covered by tests instead of being whatever the layout
    /// happened to concatenate.
    public var accessibilityDescription: String {
        let state = isPlaying ? "Playing" : "Paused"

        if let artist, !artist.isEmpty {
            return "\(state), \(title), by \(artist)"
        }

        return "\(state), \(title)"
    }
}

public enum MediaCommand: Equatable, Sendable {
    case play
    case pause
    case next
    case previous
}

/// Holds the current media snapshot for the view layer.
///
/// The backend is a closure seam. Reading the system Now Playing state on
/// macOS needs the private MediaRemote framework, so Pod ships a local
/// placeholder rather than taking a dependency on a private API, and leaves
/// the seam for a real integration to fill.
@MainActor
public final class NowPlayingStore: ObservableObject {
    @Published public private(set) var snapshot: NowPlaying?

    private let perform: (MediaCommand) -> Void

    public init(initial: NowPlaying? = nil, perform: @escaping (MediaCommand) -> Void = { _ in }) {
        self.snapshot = initial
        self.perform = perform
    }

    public func update(_ snapshot: NowPlaying?) {
        self.snapshot = snapshot
    }

    /// Applies a command locally so the controls are exercisable without a
    /// backend, then forwards it to whatever seam was supplied.
    public func send(_ command: MediaCommand) {
        switch command {
        case .play:
            snapshot?.isPlaying = true
        case .pause:
            snapshot?.isPlaying = false
        case .next, .previous:
            break
        }

        perform(command)
    }
}
