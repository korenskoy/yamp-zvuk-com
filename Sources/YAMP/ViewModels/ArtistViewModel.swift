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
