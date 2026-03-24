import Foundation
import ZvukMusic

enum NewsTab: String, CaseIterable {
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
}

@MainActor
@Observable
final class NewsViewModel {
    var selectedTab: NewsTab = .all
    var notifications: [ZvukNotification] = []
    var isLoading = false
    var isLoadingMore = false
    var hasNextPage = false
    private var cursor: String?

    func load(client: ZvukClient?) async {
        guard let client else { return }
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
        } catch {}
    }
}
