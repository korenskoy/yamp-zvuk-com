import Foundation
import Observation
import ZvukMusic

enum CollectionTab: String, CaseIterable {
    case tracks = "Треки"
    case artists = "Артисты"
    case releases = "Альбомы"
}

@MainActor
@Observable
final class CollectionViewModel {
    var selectedTab: CollectionTab = .tracks
    var likedTracks: [Track] = []
    var likedArtists: [Artist] = []
    var likedReleases: [Release] = []
    var isLoading = false
    var appError: AppError?

    func load(cache: CacheService, collectionService: CollectionService) async {
        isLoading = true
        appError = nil
        defer { isLoading = false }

        if !collectionService.isLoaded {
            await withCheckedContinuation { continuation in
                withObservationTracking {
                    _ = collectionService.isLoaded
                } onChange: {
                    Task { @MainActor in continuation.resume() }
                }
            }
        }
        guard collectionService.isLoaded else { return }

        do {
            switch selectedTab {
            case .tracks:
                likedTracks = try await cache.getLikedTracks(orderBy: .dateAdded, direction: .desc)
            case .artists:
                let ids = Array(collectionService.likedArtistIDs)
                guard !ids.isEmpty else { likedArtists = []; return }
                likedArtists = try await cache.getArtists(ids)
            case .releases:
                let ids = Array(collectionService.likedReleaseIDs)
                guard !ids.isEmpty else { likedReleases = []; return }
                likedReleases = try await cache.getReleases(ids)
            }
        } catch {
            self.appError = AppError.from(error)
        }
    }
}
