import Foundation
import ZvukMusic

@MainActor
@Observable
final class CollectionService {
    private(set) var likedTrackIDs: Set<String> = []
    private(set) var likedArtistIDs: Set<String> = []
    private(set) var likedReleaseIDs: Set<String> = []
    private(set) var likedPlaylistIDs: Set<String> = []
    private(set) var playlistsVersion = 0
    private(set) var isLoaded = false
    var error: String?

    @ObservationIgnored
    private weak var cache: CacheService?

    @ObservationIgnored
    private weak var lastFM: LastFMService?

    @ObservationIgnored
    private weak var settings: AppSettings?

    func configure(cache: CacheService, lastFM: LastFMService, settings: AppSettings) {
        self.cache = cache
        self.lastFM = lastFM
        self.settings = settings
    }

    func bumpPlaylistsVersion() { playlistsVersion += 1 }

    func isTrackLiked(_ id: String) -> Bool { likedTrackIDs.contains(id) }
    func isArtistLiked(_ id: String) -> Bool { likedArtistIDs.contains(id) }
    func isReleaseLiked(_ id: String) -> Bool { likedReleaseIDs.contains(id) }
    func isPlaylistLiked(_ id: String) -> Bool { likedPlaylistIDs.contains(id) }

    func loadCollection(client: ZvukClient?) async {
        guard let client else { return }
        do {
            let collection = try await client.getCollection()
            likedTrackIDs = Set(collection.tracks.compactMap(\.id))
            likedArtistIDs = Set(collection.artists.compactMap(\.id))
            likedReleaseIDs = Set(collection.releases.compactMap(\.id))
            likedPlaylistIDs = Set(collection.playlists.compactMap(\.id))
        } catch {
            self.error = String(describing: error)
        }
        isLoaded = true
    }

    // MARK: - Track

    func toggleTrackLike(_ track: SimpleTrack, client: ZvukClient?) async {
        guard let client else { return }
        let id = track.id
        let wasLiked = likedTrackIDs.contains(id)

        if wasLiked {
            likedTrackIDs.remove(id)
            do { _ = try await client.unlikeTrack(id) } catch { likedTrackIDs.insert(id); return }
            if settings?.isScrobblingEnabled == true { lastFM?.unloveTrack(track) }
        } else {
            likedTrackIDs.insert(id)
            do { _ = try await client.likeTrack(id) } catch { likedTrackIDs.remove(id); return }
            if settings?.isScrobblingEnabled == true { lastFM?.loveTrack(track) }
        }
        cache?.invalidateLikedTracks()
    }

    // MARK: - Artist

    func toggleArtistLike(_ id: String, client: ZvukClient?) async {
        guard let client else { return }
        if likedArtistIDs.contains(id) {
            likedArtistIDs.remove(id)
            do { _ = try await client.unlikeArtist(id) } catch { likedArtistIDs.insert(id) }
        } else {
            likedArtistIDs.insert(id)
            do { _ = try await client.likeArtist(id) } catch { likedArtistIDs.remove(id) }
        }
    }

    // MARK: - Playlist

    func togglePlaylistLike(_ id: String, client: ZvukClient?) async {
        guard let client else { return }
        if likedPlaylistIDs.contains(id) {
            likedPlaylistIDs.remove(id)
            do { _ = try await client.unlikePlaylist(id) } catch { likedPlaylistIDs.insert(id) }
        } else {
            likedPlaylistIDs.insert(id)
            do { _ = try await client.likePlaylist(id) } catch { likedPlaylistIDs.remove(id) }
        }
        cache?.invalidateUserPlaylists()
        await loadCollection(client: client)
        bumpPlaylistsVersion()
    }

    // MARK: - Release

    func toggleReleaseLike(_ id: String, client: ZvukClient?) async {
        guard let client else { return }
        if likedReleaseIDs.contains(id) {
            likedReleaseIDs.remove(id)
            do { _ = try await client.unlikeRelease(id) } catch { likedReleaseIDs.insert(id) }
        } else {
            likedReleaseIDs.insert(id)
            do { _ = try await client.likeRelease(id) } catch { likedReleaseIDs.remove(id) }
        }
    }
}
