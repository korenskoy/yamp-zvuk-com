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
    var appError: AppError?

    @ObservationIgnored
    private weak var cache: CacheService?

    @ObservationIgnored
    private weak var lastFM: LastFMService?

    @ObservationIgnored
    private weak var settings: AppSettings?

    @ObservationIgnored
    private weak var logStore: LogStore?

    func configure(cache: CacheService, lastFM: LastFMService, settings: AppSettings, logStore: LogStore) {
        self.cache = cache
        self.lastFM = lastFM
        self.settings = settings
        self.logStore = logStore
    }

    /// Сбрасывает состояние коллекции при logout, чтобы лайки прежнего аккаунта не утекали в новую сессию.
    func reset() {
        likedTrackIDs = []
        likedArtistIDs = []
        likedReleaseIDs = []
        likedPlaylistIDs = []
        playlistsVersion = 0
        isLoaded = false
        appError = nil
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
            self.appError = AppError.from(error)
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
            do { _ = try await client.unlikeTrack(id) } catch {
                likedTrackIDs.insert(id)
                logStore?.appendLocal(operation: "unlikeTrack \(id)", error: "\(error)")
                return
            }
            if settings?.isScrobblingEnabled == true { lastFM?.unloveTrack(track) }
        } else {
            likedTrackIDs.insert(id)
            do { _ = try await client.likeTrack(id) } catch {
                likedTrackIDs.remove(id)
                logStore?.appendLocal(operation: "likeTrack \(id)", error: "\(error)")
                return
            }
            if settings?.isScrobblingEnabled == true { lastFM?.loveTrack(track) }
        }
        cache?.invalidateLikedTracks()
    }

    // MARK: - Artist

    func toggleArtistLike(_ id: String, client: ZvukClient?) async {
        guard let client else { return }
        if likedArtistIDs.contains(id) {
            likedArtistIDs.remove(id)
            do { _ = try await client.unlikeArtist(id) } catch {
                likedArtistIDs.insert(id)
                logStore?.appendLocal(operation: "unlikeArtist \(id)", error: "\(error)")
            }
        } else {
            likedArtistIDs.insert(id)
            do { _ = try await client.likeArtist(id) } catch {
                likedArtistIDs.remove(id)
                logStore?.appendLocal(operation: "likeArtist \(id)", error: "\(error)")
            }
        }
    }

    // MARK: - Playlist

    func togglePlaylistLike(_ id: String, client: ZvukClient?) async {
        guard let client else { return }
        if likedPlaylistIDs.contains(id) {
            likedPlaylistIDs.remove(id)
            do { _ = try await client.unlikePlaylist(id) } catch {
                likedPlaylistIDs.insert(id)
                logStore?.appendLocal(operation: "unlikePlaylist \(id)", error: "\(error)")
            }
        } else {
            likedPlaylistIDs.insert(id)
            do { _ = try await client.likePlaylist(id) } catch {
                likedPlaylistIDs.remove(id)
                logStore?.appendLocal(operation: "likePlaylist \(id)", error: "\(error)")
            }
        }
        cache?.invalidateUserPlaylists()
        bumpPlaylistsVersion()
    }

    // MARK: - Release

    func toggleReleaseLike(_ id: String, client: ZvukClient?) async {
        guard let client else { return }
        if likedReleaseIDs.contains(id) {
            likedReleaseIDs.remove(id)
            do { _ = try await client.unlikeRelease(id) } catch {
                likedReleaseIDs.insert(id)
                logStore?.appendLocal(operation: "unlikeRelease \(id)", error: "\(error)")
            }
        } else {
            likedReleaseIDs.insert(id)
            do { _ = try await client.likeRelease(id) } catch {
                likedReleaseIDs.remove(id)
                logStore?.appendLocal(operation: "likeRelease \(id)", error: "\(error)")
            }
        }
    }
}
