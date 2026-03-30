import Foundation
import ZvukMusic

@MainActor
@Observable
final class PlaylistViewModel {
    let playlistId: String
    var playlist: Playlist?
    var isLoading = false
    var appError: AppError?

    init(playlistId: String) {
        self.playlistId = playlistId
    }

    func load(cache: CacheService) async {
        isLoading = true
        appError = nil
        defer { isLoading = false }

        do {
            playlist = try await cache.getPlaylist(playlistId)
        } catch {
            self.appError = AppError.from(error)
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
            self.appError = AppError.from(error)
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
            self.appError = AppError.from(error)
            return false
        }
    }
}
