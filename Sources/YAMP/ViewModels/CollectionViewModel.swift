import Foundation
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
    var error: String?

    func load(cache: CacheService, collectionService: CollectionService) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        var waited = 0
        while !collectionService.isLoaded && waited < 200 {
            try? await Task.sleep(for: .milliseconds(50))
            waited += 1
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
            self.error = String(describing: error)
        }
    }
}
