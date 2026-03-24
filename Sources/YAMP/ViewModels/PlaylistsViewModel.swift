import Foundation
import ZvukMusic

@MainActor
@Observable
final class PlaylistsViewModel {
    var playlists: [SimplePlaylist] = []
    var isLoading = false
    var error: String?

    func load(cache: CacheService) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let ids = try await cache.getUserPlaylistIDs()
            guard !ids.isEmpty else { playlists = []; return }
            playlists = try await cache.getSimplePlaylists(ids)
        } catch {
            self.error = String(describing: error)
        }
    }

    func deletePlaylist(_ id: String, client: ZvukClient?, cache: CacheService) async {
        guard let client else { return }
        do {
            _ = try await client.deletePlaylist(id)
        } catch {
            self.error = String(describing: error)
            return
        }
        cache.invalidatePlaylist(id)
        cache.invalidateUserPlaylists()
        await load(cache: cache)
    }
}
