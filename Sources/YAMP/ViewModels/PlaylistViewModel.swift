import Foundation
import ZvukMusic

@MainActor
@Observable
final class PlaylistViewModel {
    let playlistId: String
    var playlist: Playlist?
    var isLoading = false
    var error: String?

    init(playlistId: String) {
        self.playlistId = playlistId
    }

    func load(cache: CacheService) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            playlist = try await cache.getPlaylist(playlistId)
        } catch {
            self.error = String(describing: error)
        }
    }

    func deletePlaylist(client: ZvukClient?, cache: CacheService, collection: CollectionService) async -> Bool {
        guard let client else { return false }
        do {
            let result = try await client.deletePlaylist(playlistId)
            if result {
                cache.invalidatePlaylist(playlistId)
                cache.invalidateUserPlaylists()
                collection.bumpPlaylistsVersion()
            }
            return result
        } catch {
            return false
        }
    }

    func renamePlaylist(_ newName: String, client: ZvukClient?, cache: CacheService, collection: CollectionService) async -> Bool {
        guard let client else { return false }
        do {
            let result = try await client.renamePlaylist(playlistId, newName: newName)
            if result {
                cache.invalidatePlaylist(playlistId)
                cache.invalidateUserPlaylists()
                await load(cache: cache)
                collection.bumpPlaylistsVersion()
            }
            return result
        } catch {
            return false
        }
    }
}
