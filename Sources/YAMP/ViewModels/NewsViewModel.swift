import Foundation
import ZvukMusic

enum NewsTab: String, CaseIterable, Codable, Hashable, Sendable {
    case all = "Все"
    case music = "Музыка"
    case podcasts = "Подкасты"
    case books = "Книги"
    case friends = "Друзья"

    var notificationTypes: [NotificationType] {
        switch self {
        case .all: NotificationType.all
        case .music: [.newRelease]
        case .podcasts: [.newPodcastEpisode]
        case .books: [.newBook]
        case .friends: [.newProfilePlaylist, .playlistTracksAdded, .playlistLiked]
        }
    }

    /// Книги через плеер не воспроизводятся — отдельный flow в Zvuk
    var isPlayable: Bool {
        self != .books
    }
}

@MainActor
@Observable
final class NewsViewModel {
    struct CollectProgress: Equatable {
        let current: Int
        let total: Int
    }

    var selectedTab: NewsTab = .all
    var notifications: [ZvukNotification] = []
    var isLoading = false
    var isLoadingMore = false
    var appError: AppError?
    var hasNextPage = false
    var collectProgress: CollectProgress?
    private var cursor: String?

    var isCollecting: Bool { collectProgress != nil }

    var canPlayAll: Bool {
        selectedTab.isPlayable && !notifications.isEmpty && !isLoading && !isCollecting
    }

    func load(client: ZvukClient?) async {
        guard let client else { return }
        appError = nil
        isLoading = true
        defer { isLoading = false }

        cursor = nil
        hasNextPage = false

        do {
            let feed = try await client.getNotifications(
                types: selectedTab.notificationTypes,
                limit: 30
            )
            notifications = feed.notifications
            cursor = feed.pageInfo.cursor
            hasNextPage = feed.pageInfo.hasNextPage
        } catch {
            self.appError = AppError.from(error)
            notifications = []
        }
    }

    func loadMore(client: ZvukClient?) async {
        guard let client, hasNextPage, let cursor, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let feed = try await client.getNotifications(
                types: selectedTab.notificationTypes,
                cursor: cursor,
                limit: 30
            )
            notifications.append(contentsOf: feed.notifications)
            self.cursor = feed.pageInfo.cursor
            hasNextPage = feed.pageInfo.hasNextPage
        } catch {
            self.appError = AppError.from(error)
        }
    }

    /// Дёргает CacheService последовательно — параллелить запросы к Zvuk API запрещено.
    /// Per-item ошибки молча проглатываются, транспорт логирует их в LogStore.
    func collectTracks(cacheService: CacheService) async -> [SimpleTrack] {
        guard !isCollecting else { return [] }

        let playable = notifications.filter(Self.isPlayable)
        guard !playable.isEmpty else { return [] }

        collectProgress = CollectProgress(current: 0, total: playable.count)
        defer { collectProgress = nil }

        var tracks: [SimpleTrack] = []
        for (index, notification) in playable.enumerated() {
            if Task.isCancelled { return tracks }
            tracks.append(contentsOf: await Self.fetchTracks(for: notification, cacheService: cacheService))
            collectProgress = CollectProgress(current: index + 1, total: playable.count)
        }
        return tracks
    }

    private static func fetchTracks(
        for notification: ZvukNotification,
        cacheService: CacheService
    ) async -> [SimpleTrack] {
        switch notification.body {
        case .newRelease(_, let release):
            return (try? await cacheService.getRelease(release.id))?.tracks ?? []

        case .newProfilePlaylist(_, let playlist),
             .playlistTracksAdded(_, let playlist, _),
             .playlistLiked(_, let playlist):
            return (try? await cacheService.getPlaylist(playlist.id))?.tracks ?? []

        case .newPodcastEpisode(let episode):
            guard let trackId = episode.trackId,
                  let track = try? await cacheService.getTrack(trackId)
            else { return [] }
            return [SimpleTrack(
                id: track.id, title: track.title, duration: track.duration,
                explicit: track.explicit, artists: track.artists, release: track.release
            )]

        case .newBook, .unknown:
            return []
        }
    }

    private static func isPlayable(_ notification: ZvukNotification) -> Bool {
        switch notification.body {
        case .newRelease, .newProfilePlaylist, .playlistTracksAdded, .playlistLiked:
            true
        case .newPodcastEpisode(let episode):
            episode.trackId != nil
        case .newBook, .unknown:
            false
        }
    }
}
