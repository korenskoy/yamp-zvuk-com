import Foundation
import ZvukMusic

@MainActor
@Observable
final class ArtistViewModel {
    let artistId: String
    var artist: Artist?
    var isLoading = false
    var appError: AppError?

    var subscriberCount: Int? {
        artist?.collectionItemData?.likesCount
    }

    init(artistId: String) {
        self.artistId = artistId
    }

    func loadRadio(client: ZvukClient?, playerService: PlayerService) async {
        guard let client, let artist else { return }
        do {
            let result = try await client.getRadioByArtist(artist.id)
            let tracks = result.tracks
            if !tracks.isEmpty {
                playerService.playQueue(
                    tracks.map(\.simplified),
                    context: .radioArtist(id: artist.id)
                )
            }
        } catch {
            self.appError = AppError.from(error)
        }
    }

    func hideArtist(client: ZvukClient?) async {
        guard let artist else { return }
        do {
            _ = try await client?.addToHidden(artist.id, type: .artist)
        } catch {
            self.appError = AppError.from(error)
        }
    }

    func load(cache: CacheService) async {
        isLoading = true
        appError = nil
        defer { isLoading = false }

        do {
            artist = try await cache.getArtist(
                artistId,
                withReleases: true,
                withPopularTracks: true,
                withRelatedArtists: true,
                withDescription: true
            )
        } catch {
            self.appError = AppError.from(error)
        }
    }
}
