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
    var isLoading = false
    var isQuickSearching = false
    var hasSearched = false
    var appError: AppError?

    // Quick search (top tab)
    var topTracks: [SimpleTrack] = []
    var topArtists: [SimpleArtist] = []
    var topReleases: [SimpleRelease] = []
    var topPlaylists: [SimplePlaylist] = []
    var topPodcasts: [SimplePodcast] = []

    // Full search (category tabs) — loaded lazily
    var tracks: [SimpleTrack] = []
    var artists: [SimpleArtist] = []
    var releases: [SimpleRelease] = []
    var playlists: [SimplePlaylist] = []
    var podcasts: [SimplePodcast] = []

    private var searchTask: Task<Void, Never>?
    private var categoryTask: Task<Void, Never>?
    private var lastQuery = ""
    private var fullSearchLoaded = false

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

            lastQuery = trimmed
            fullSearchLoaded = false
            clearCategoryResults()

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
        if selectedTab != .top {
            loadFullSearch(client: client)
        }
    }

    func onTabChanged(client: ZvukClient?) {
        if selectedTab != .top && !fullSearchLoaded && hasSearched {
            loadFullSearch(client: client)
        }
    }

    private func loadFullSearch(client: ZvukClient?) {
        guard let client, !fullSearchLoaded else { return }
        categoryTask?.cancel()
        appError = nil

        let searchQuery = lastQuery
        categoryTask = Task {
            isLoading = true
            defer { isLoading = false }

            do {
                let result = try await client.search(searchQuery, limit: 30)
                guard !Task.isCancelled else { return }

                tracks = result.tracks?.items ?? []
                artists = result.artists?.items ?? []
                releases = result.releases?.items ?? []
                playlists = result.playlists?.items ?? []
                podcasts = result.podcasts?.items ?? []
                fullSearchLoaded = true
            } catch {
                guard !Task.isCancelled else { return }
                self.appError = AppError.from(error)
            }
        }
    }

    func clearResults() {
        topTracks = []; topArtists = []; topReleases = []
        topPlaylists = []; topPodcasts = []
        clearCategoryResults()
        hasSearched = false
        fullSearchLoaded = false
        lastQuery = ""
    }

    private func clearCategoryResults() {
        tracks = []; artists = []; releases = []
        playlists = []; podcasts = []
    }
}
