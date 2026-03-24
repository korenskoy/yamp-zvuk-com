import Foundation
import ZvukMusic

@MainActor
@Observable
final class HomeViewModel {
    var recommendationItems: [RecommendationItem] = []
    var editorialPlaylists: [SimplePlaylist] = []
    var isLoading = false
    var errorMessage: String?

    func load(cache: CacheService) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let recBlock = cache.getRecommendations()
            async let editorialIDs = cache.getEditorialPlaylistIDs()

            let block = try await recBlock
            recommendationItems = block.pages.flatMap(\.items).filter { $0 != .unknown }

            let ids = try await editorialIDs
            if !ids.isEmpty {
                editorialPlaylists = try await cache.getSimplePlaylists(ids)
            }
        } catch {
            errorMessage = "Ошибка загрузки: \(error.localizedDescription)"
        }
    }
}
