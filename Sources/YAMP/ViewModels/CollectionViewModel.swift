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
    var appError: AppError?

    func load(cache: CacheService, collectionService: CollectionService) async {
        isLoading = true
        appError = nil
        defer { isLoading = false }

        if !collectionService.isLoaded {
            await waitForCollectionLoaded(collectionService)
        }
        guard collectionService.isLoaded else { return }

        do {
            switch selectedTab {
            case .tracks:
                likedTracks = try await cache.getLikedTracks(orderBy: .dateAdded, direction: .desc)
            case .artists:
                // Set даёт недетерминированный порядок — сортируем id для стабильной выдачи между заходами.
                let ids = collectionService.likedArtistIDs.sorted()
                guard !ids.isEmpty else { likedArtists = []; return }
                likedArtists = try await cache.getArtists(ids)
            case .releases:
                let ids = collectionService.likedReleaseIDs.sorted()
                guard !ids.isEmpty else { likedReleases = []; return }
                likedReleases = try await cache.getReleases(ids)
            }
        } catch {
            self.appError = AppError.from(error)
        }
    }

    /// Ждёт завершения начальной загрузки коллекции (запускается при старте/логине).
    /// Ограничено по времени и отменяемо, чтобы спиннер не висел вечно при сбое загрузки.
    private func waitForCollectionLoaded(_ collectionService: CollectionService) async {
        for _ in 0..<200 { // ~20 с максимум
            if collectionService.isLoaded || Task.isCancelled { return }
            try? await Task.sleep(for: .milliseconds(100))
        }
    }
}
