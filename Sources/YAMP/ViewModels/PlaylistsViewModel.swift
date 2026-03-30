import Foundation
import ZvukMusic

@MainActor
@Observable
final class PlaylistsViewModel {
    var playlists: [SimplePlaylist] = []
    var isLoading = false
    var appError: AppError?

    func load(cache: CacheService) async {
        isLoading = true
        appError = nil
        defer { isLoading = false }

        do {
            let ids = try await cache.getUserPlaylistIDs()
            guard !ids.isEmpty else { playlists = []; return }
            playlists = try await cache.getSimplePlaylists(ids)
        } catch {
            self.appError = AppError.from(error)
        }
    }

    func deletePlaylist(_ id: String, client: ZvukClient?, cache: CacheService) async {
        guard let client else { return }
        do {
            _ = try await client.deletePlaylist(id)
        } catch {
            self.appError = AppError.from(error)
            return
        }
        cache.invalidatePlaylist(id)
        cache.invalidateUserPlaylists()
        await load(cache: cache)
    }
}
