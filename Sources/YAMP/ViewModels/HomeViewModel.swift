import Foundation
import ZvukMusic

@MainActor
@Observable
final class HomeViewModel {
    var recommendationItems: [RecommendationItem] = []
    var editorialPlaylists: [SimplePlaylist] = []
    var isLoading = false
    var isBackgroundLoading = false
    var appError: AppError?

    private var backgroundLoadTask: Task<Void, Never>?

    func load(cache: CacheService) async {
        isLoading = true
        appError = nil
        defer { isLoading = false }

        do {
            let block = try await cache.getRecommendations()
            recommendationItems = Self.dedupedItems(from: block.pages.flatMap(\.items))

            let ids = try await cache.getEditorialPlaylistIDs()
            editorialPlaylists = ids.isEmpty ? [] : (try await cache.getSimplePlaylists(ids))

            if block.totalPages == 0 && !block.pages.isEmpty {
                print("[YAMP][Home] recommendations: totalPages=0, фон-догрузка пропущена")
            }

            if block.pages.count < block.totalPages {
                startBackgroundLoad(cache: cache)
            }
        } catch {
            self.appError = AppError.from(error)
        }
    }

    private func startBackgroundLoad(cache: CacheService) {
        backgroundLoadTask?.cancel()
        backgroundLoadTask = Task { @MainActor [weak self] in
            guard let self else { return }
            self.isBackgroundLoading = true
            defer { self.isBackgroundLoading = false }
            do {
                let full = try await cache.loadAllRecommendations()
                guard !Task.isCancelled else { return }
                self.recommendationItems = Self.dedupedItems(from: full.pages.flatMap(\.items))
            } catch is CancellationError {
                // Отмена при повторном входе на экран — штатно.
            } catch {
                print("[YAMP][Home] recommendations: фон-загрузка не удалась: \(error)")
            }
        }
    }

    private static func dedupedItems(from items: [RecommendationItem]) -> [RecommendationItem] {
        var seen = Set<String>()
        return items.filter { item in
            if case .unknown = item { return false }
            // Items с пустым исходным id не должны схлопываться по общему префиксу типа.
            if Self.hasEmptyRawID(item) { return true }
            return seen.insert(item.id).inserted
        }
    }

    private static func hasEmptyRawID(_ item: RecommendationItem) -> Bool {
        switch item {
        case .artist(let artist): return artist.id.isEmpty
        case .release(let release): return release.id.isEmpty
        case .playlist(let playlist): return playlist.id.isEmpty
        case .unknown: return true
        }
    }
}
