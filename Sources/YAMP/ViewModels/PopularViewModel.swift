import Foundation
import ZvukMusic

/// Секции грида, которые не нужно отображать пользователю
private let ignoredGridSections: Set<String> = [
    "top_100_artists_new_web",
]

enum PopularSectionData: Identifiable {
    case playlists(id: String, title: String, items: [SimplePlaylist])
    case releases(id: String, title: String, items: [SimpleRelease])
    case artists(id: String, title: String, items: [SimpleArtist])
    case tracks(id: String, title: String, playlistId: String, items: [SimpleTrack])

    var id: String {
        switch self {
        case .playlists(let id, _, _): id
        case .releases(let id, _, _): id
        case .artists(let id, _, _): id
        case .tracks(let id, _, _, _): id
        }
    }

    var title: String {
        switch self {
        case .playlists(_, let title, _): title
        case .releases(_, let title, _): title
        case .artists(_, let title, _): title
        case .tracks(_, let title, _, _): title
        }
    }
}

@MainActor
@Observable
final class PopularViewModel {
    var sections: [PopularSectionData] = []
    var isLoading = false
    var appError: AppError?

    func load(cache: CacheService) async {
        isLoading = true
        appError = nil
        defer { isLoading = false }

        let grid: GridPage
        do {
            grid = try await cache.getGrid(name: GridName.popularMusic)
        } catch {
            self.appError = AppError.from(error)
            return
        }

        let enabledSections = grid.sections.filter(\.enabled)

        let results: [(Int, PopularSectionData?)] = await withTaskGroup(of: (Int, PopularSectionData?).self) { group in
            for (index, section) in enabledSections.enumerated() {
                let sectionId = "\(index)"
                group.addTask {
                    do {
                        switch section.type {
                        case "listing":
                            return (index, try await self.loadListingSection(section, id: sectionId, cache: cache))
                        case "content":
                            return (index, try await self.loadContentSection(section, id: sectionId, cache: cache))
                        default:
                            return (index, nil)
                        }
                    } catch {
                        // Сетевые ошибки логируются транспортным слоем клиента в LogStore
                        return (index, nil)
                    }
                }
            }
            var collected: [(Int, PopularSectionData?)] = []
            for await result in group {
                collected.append(result)
            }
            return collected
        }

        sections = results
            .sorted { $0.0 < $1.0 }
            .compactMap(\.1)
    }

    // MARK: - Section Loading

    private func loadListingSection(_ section: GridSection, id: String, cache: CacheService) async throws -> PopularSectionData? {
        if let list = section.content?.list, ignoredGridSections.contains(list) {
            return nil
        }

        let title = section.header?.title ?? ""
        guard !title.isEmpty else { return nil }

        let playlistIds = section.playlistIds
        let releaseIds = section.releaseIds
        let artistIds = section.artistIds

        if !releaseIds.isEmpty {
            let releases = try await cache.getReleases(releaseIds)
            let simpleReleases = releases.map { release in
                SimpleRelease(
                    id: release.id, title: release.title, date: release.date,
                    type: release.type, image: release.image, explicit: release.explicit,
                    artists: release.artists
                )
            }
            guard !simpleReleases.isEmpty else { return nil }
            return .releases(id: id, title: title, items: simpleReleases)
        }

        if !artistIds.isEmpty {
            let artists = try await cache.getArtists(artistIds)
            let simpleArtists = artists.map { artist in
                SimpleArtist(id: artist.id, title: artist.title, image: artist.image)
            }
            guard !simpleArtists.isEmpty else { return nil }
            return .artists(id: id, title: title, items: simpleArtists)
        }

        if !playlistIds.isEmpty {
            let playlists = try await cache.getSimplePlaylists(playlistIds)
            guard !playlists.isEmpty else { return nil }
            return .playlists(id: id, title: title, items: playlists)
        }

        return nil
    }

    private func loadContentSection(_ section: GridSection, id: String, cache: CacheService) async throws -> PopularSectionData? {
        guard let playlistId = section.playlistIds.first else { return nil }

        let playlist = try await cache.getPlaylist(playlistId)
        guard let playlist, !playlist.tracks.isEmpty else { return nil }

        let title = section.header?.title ?? playlist.title
        return .tracks(id: id, title: title, playlistId: playlistId, items: playlist.tracks)
    }
}
