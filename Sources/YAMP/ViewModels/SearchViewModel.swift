import Foundation
import ZvukMusic

enum SearchTab: String, CaseIterable {
    case top = "Топ"
    case artists = "Артисты"
    case tracks = "Треки"
    case releases = "Альбомы"
    case podcasts = "Подкасты"
    case playlists = "Плейлисты"
}

@MainActor
@Observable
final class SearchViewModel {
    var query = ""
    var selectedTab: SearchTab = .top
    var isQuickSearching = false
    var hasSearched = false
    var appError: AppError?

    // Quick search (top tab)
    var topTracks: [SimpleTrack] = []
    var topArtists: [SimpleArtist] = []
    var topReleases: [SimpleRelease] = []
    var topPlaylists: [SimplePlaylist] = []
    var topPodcasts: [SimplePodcast] = []

    // Category tabs — loaded lazily per tab
    var tracks: [SimpleTrack] = []
    var artists: [SimpleArtist] = []
    var releases: [SimpleRelease] = []
    var playlists: [SimplePlaylist] = []
    var podcasts: [SimplePodcast] = []

    // Per-tab loading / pagination state
    var loadingTab: SearchTab?
    private var tracksCursor: String?
    private var artistsCursor: String?
    private var releasesCursor: String?
    private var playlistsCursor: String?
    private var podcastsCursor: String?
    private var loadedTabs: Set<SearchTab> = []
    private var loadingMoreTabs: Set<SearchTab> = []

    private let pageSize = 30

    private var searchTask: Task<Void, Never>?
    private var categoryTask: Task<Void, Never>?
    private var loadMoreTasks: [SearchTab: Task<Void, Never>] = [:]
    private var lastQuery = ""

    var autocompleteSuggestion: String? {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard trimmedQuery.count >= 2 else { return nil }
        let candidates: [String] =
            topArtists.map(\.title) +
            topReleases.map(\.title) +
            topPlaylists.map(\.title) +
            topTracks.map(\.title)
        return candidates.first { $0.lowercased().hasPrefix(trimmedQuery) && $0.lowercased() != trimmedQuery }
    }

    var isEmpty: Bool {
        switch selectedTab {
        case .top:
            topTracks.isEmpty && topArtists.isEmpty && topReleases.isEmpty
                && topPlaylists.isEmpty && topPodcasts.isEmpty
        case .tracks: tracks.isEmpty
        case .artists: artists.isEmpty
        case .releases: releases.isEmpty
        case .playlists: playlists.isEmpty
        case .podcasts: podcasts.isEmpty
        }
    }

    /// Whether the current tab is loading its first page.
    var isLoading: Bool {
        loadingTab == selectedTab
    }

    /// Whether the current tab can load more results.
    var canLoadMore: Bool {
        guard loadedTabs.contains(selectedTab) else { return false }
        switch selectedTab {
        case .top: return false
        case .tracks: return tracksCursor != nil
        case .artists: return artistsCursor != nil
        case .releases: return releasesCursor != nil
        case .playlists: return playlistsCursor != nil
        case .podcasts: return podcastsCursor != nil
        }
    }

    /// Whether the current tab is currently paginating.
    var isLoadingMore: Bool {
        loadingMoreTabs.contains(selectedTab)
    }

    func onQueryChanged(client: ZvukClient?) {
        searchTask?.cancel()
        categoryTask?.cancel()

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            clearResults()
            return
        }

        guard let client else { return }

        appError = nil

        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }

            isQuickSearching = true
            defer { isQuickSearching = false }

            // Сбрасываем категории только при реальной смене запроса — иначе затрём результаты,
            // уже загруженные через onSubmit (Enter до срабатывания debounce).
            if lastQuery != trimmed {
                lastQuery = trimmed
                resetCategoryState()
            }

            do {
                let result = try await client.quickSearch(trimmed, limit: 20)
                guard !Task.isCancelled else { return }

                topTracks = result.tracks
                topArtists = result.artists
                topReleases = result.releases
                topPlaylists = result.playlists
                topPodcasts = result.podcasts
            } catch {
                guard !Task.isCancelled else { return }
                self.appError = AppError.from(error)
            }
        }
    }

    func onSubmit(client: ZvukClient?) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return }
        hasSearched = true
        // Enter может опередить debounce — фиксируем актуальный запрос синхронно,
        // чтобы loadCurrentTab не искал по устаревшему/пустому lastQuery.
        if trimmed != lastQuery {
            lastQuery = trimmed
            resetCategoryState()
        }
        if selectedTab != .top {
            loadCurrentTab(client: client)
        }
    }

    func onTabChanged(client: ZvukClient?) {
        guard hasSearched, selectedTab != .top else { return }
        guard !loadedTabs.contains(selectedTab) else { return }
        loadCurrentTab(client: client)
    }

    func loadMore(client: ZvukClient?) {
        guard let client, hasSearched, selectedTab != .top else { return }
        guard loadedTabs.contains(selectedTab) else { return }
        guard !loadingMoreTabs.contains(selectedTab) else { return }
        guard canLoadMore else { return }

        let tab = selectedTab
        let searchQuery = lastQuery
        loadingMoreTabs.insert(tab)

        loadMoreTasks[tab]?.cancel()
        loadMoreTasks[tab] = Task {
            defer { loadingMoreTabs.remove(tab) }
            do {
                try await fetchTab(tab, query: searchQuery, client: client, append: true)
            } catch is CancellationError {
                return
            } catch {
                self.appError = AppError.from(error)
            }
        }
    }

    func clearResults() {
        topTracks = []; topArtists = []; topReleases = []
        topPlaylists = []; topPodcasts = []
        resetCategoryState()
        hasSearched = false
        lastQuery = ""
    }

    // MARK: - Private

    private func resetCategoryState() {
        for task in loadMoreTasks.values { task.cancel() }
        loadMoreTasks.removeAll()
        tracks = []; artists = []; releases = []
        playlists = []; podcasts = []
        tracksCursor = nil; artistsCursor = nil; releasesCursor = nil
        playlistsCursor = nil; podcastsCursor = nil
        loadedTabs.removeAll()
        loadingMoreTabs.removeAll()
        loadingTab = nil
    }

    private func loadCurrentTab(client: ZvukClient?) {
        guard let client else { return }
        categoryTask?.cancel()
        appError = nil

        let tab = selectedTab
        let searchQuery = lastQuery
        categoryTask = Task {
            loadingTab = tab
            defer {
                if loadingTab == tab { loadingTab = nil }
            }

            do {
                try await fetchTab(tab, query: searchQuery, client: client, append: false)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                self.appError = AppError.from(error)
            }
        }
    }

    private func fetchTab(_ tab: SearchTab, query searchQuery: String, client: ZvukClient, append: Bool) async throws {
        switch tab {
        case .top:
            return
        case .tracks:
            let cursor = append ? tracksCursor : nil
            let page = try await client.searchTracks(searchQuery, limit: pageSize, cursor: cursor)
            try Task.checkCancellation()
            tracks = append ? tracks + page.items : page.items
            tracksCursor = page.page?.cursor
        case .artists:
            let cursor = append ? artistsCursor : nil
            let page = try await client.searchArtists(searchQuery, limit: pageSize, cursor: cursor)
            try Task.checkCancellation()
            artists = append ? artists + page.items : page.items
            artistsCursor = page.page?.cursor
        case .releases:
            let cursor = append ? releasesCursor : nil
            let page = try await client.searchReleases(searchQuery, limit: pageSize, cursor: cursor)
            try Task.checkCancellation()
            releases = append ? releases + page.items : page.items
            releasesCursor = page.page?.cursor
        case .playlists:
            let cursor = append ? playlistsCursor : nil
            let page = try await client.searchPlaylists(searchQuery, limit: pageSize, cursor: cursor)
            try Task.checkCancellation()
            playlists = append ? playlists + page.items : page.items
            playlistsCursor = page.page?.cursor
        case .podcasts:
            let cursor = append ? podcastsCursor : nil
            let page = try await client.searchPodcasts(searchQuery, limit: pageSize, cursor: cursor)
            try Task.checkCancellation()
            podcasts = append ? podcasts + page.items : page.items
            podcastsCursor = page.page?.cursor
        }
        loadedTabs.insert(tab)
    }
}
