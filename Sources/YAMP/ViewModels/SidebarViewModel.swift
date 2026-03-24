import Foundation
import ZvukMusic

@MainActor
@Observable
final class SidebarViewModel {
    var playlists: [SimplePlaylist] = []
    var isLoadingPlaylists = false
    var error: String?

    func loadPlaylists(cache: CacheService) async {
        isLoadingPlaylists = true
        error = nil
        defer { isLoadingPlaylists = false }

        do {
            let ids = try await cache.getUserPlaylistIDs()
            guard !ids.isEmpty else { return }
            playlists = try await cache.getSimplePlaylists(ids)
        } catch {
            self.error = String(describing: error)
        }
    }
}
