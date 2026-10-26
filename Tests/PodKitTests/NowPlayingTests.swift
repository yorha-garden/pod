import Testing
@testable import PodKit

@Suite("Now playing descriptions")
struct NowPlayingTests {
    @Test("A playing track names its state, title and artist")
    func playingWithArtist() {
        let snapshot = NowPlaying(
            title: "Weight of the World",
            artist: "J'Nique Nicole",
            isPlaying: true
        )

        #expect(snapshot.accessibilityDescription == "Playing, Weight of the World, by J'Nique Nicole")
    }

    @Test("A paused track says so rather than relying on an icon")
    func pausedIsSpoken() {
        let snapshot = NowPlaying(title: "Amusement Park", isPlaying: false)

        #expect(snapshot.accessibilityDescription == "Paused, Amusement Park")
    }

    @Test("A missing artist is left out instead of read as empty")
    func emptyArtistIsOmitted() {
        let snapshot = NowPlaying(title: "City Ruins", artist: "", isPlaying: true)

        #expect(snapshot.accessibilityDescription == "Playing, City Ruins")
    }

    @Test("Play and pause commands move the local snapshot")
    @MainActor
    func commandsApplyLocally() {
        let store = NowPlayingStore(initial: NowPlaying(title: "Peaceful Sleep", isPlaying: false))

        store.send(.play)
        #expect(store.snapshot?.isPlaying == true)

        store.send(.pause)
        #expect(store.snapshot?.isPlaying == false)
    }
}
