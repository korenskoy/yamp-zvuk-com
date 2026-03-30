import Foundation
import ZvukMusic

@MainActor
@Observable
final class HomeViewModel {
    var recommendationItems: [RecommendationItem] = []
    var editorialPlaylists: [SimplePlaylist] = []
    var isLoading = false
    var appError: AppError?

    func load(cache: CacheService) async {
        isLoading = true
        appError = nil
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
            self.appError = AppError.from(error)
        }
    }
}
