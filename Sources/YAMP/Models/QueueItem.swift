import Foundation
import ZvukMusic

enum PlaybackContext: Hashable, Codable {
    case search
    case liked
    case album(id: String)
    case playlist(id: String)
    case artist(id: String)
    case radioArtist(id: String)
    case radioTrack(id: String)
    case wave(params: WaveParams)

    struct WaveParams: Hashable, Codable {
        var energy: Double
        var fun: Double
        var genres: [WaveGenre]
        var language: WaveLanguage?
        var instrumental: Bool
        var popularity: WavePopularity?

        func fetchTracks(client: ZvukClient, count: Int = 25) async throws -> [SimpleTrack] {
            let tracks = try await client.getPersonalWave(
                count: count,
                energy: energy,
                fun: fun,
                genres: genres,
                language: language,
                instrumental: instrumental,
                popularity: popularity
            )
            return tracks.compactMap { t in
                guard !t.id.isEmpty else { return nil }
                return SimpleTrack(
                    id: t.id, title: t.title, duration: t.duration,
                    explicit: t.explicit, artists: t.artists, release: t.release
                )
            }
        }
    }
}

struct QueueItem: Identifiable, Hashable, Codable {
    let id: UUID
    let track: SimpleTrack
    let context: PlaybackContext

    init(track: SimpleTrack, context: PlaybackContext) {
        self.id = UUID()
        self.track = track
        self.context = context
    }
}
