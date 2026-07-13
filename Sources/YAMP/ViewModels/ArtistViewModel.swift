import Foundation
import ZvukMusic

@MainActor
@Observable
final class ArtistViewModel {
    let artistId: String
    var artist: Artist?
    var isLoading = false
    var isDisliked = false
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

    func toggleHidden(client: ZvukClient?, cache: CacheService) async {
        guard let client else { return }
        do {
            if isDisliked {
                _ = try await client.removeFromHidden(artistId, type: .artist)
            } else {
                _ = try await client.addToHidden(artistId, type: .artist)
            }
            cache.invalidateHiddenCollection()
            isDisliked.toggle()
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
            isDisliked = (try? await cache.isArtistHidden(artistId)) ?? false
        } catch {
            self.appError = AppError.from(error)
        }
    }
}
