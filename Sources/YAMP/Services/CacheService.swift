import Foundation
import ZvukMusic

private struct CacheEntry<T> {
    let value: T
    let insertedAt: Date
    let ttl: TimeInterval

    var isExpired: Bool {
        Date().timeIntervalSince(insertedAt) > ttl
    }
}

private enum TTL {
    static let stableEntity: TimeInterval = 30 * 60
    static let simplePlaylist: TimeInterval = 10 * 60
    static let fullPlaylist: TimeInterval = 5 * 60
    static let lyrics: TimeInterval = 60 * 60
    static let queryResult: TimeInterval = 2 * 60
    static let recommendations: TimeInterval = 30 * 60
    static let stream: TimeInterval = 9 * 60
}

private enum Limits {
    static let tracks = 2000
    static let artists = 500
    static let releases = 500
    static let playlists = 100
    static let simplePlaylists = 200
    static let lyrics = 200
    static let streams = 500
    /// Каталог радио запрашивается целиком; на момент написания в нём 161 станция.
    static let radioCatalogue = 250
}

@MainActor
@Observable
final class CacheService {

    private weak var appState: AppState?
    private var client: ZvukClient? { appState?.client }

    // Entity caches
    private var tracks: [String: CacheEntry<Track>] = [:]
    private var artists: [String: CacheEntry<Artist>] = [:]
    private var releases: [String: CacheEntry<Release>] = [:]
    private var playlists: [String: CacheEntry<Playlist>] = [:]
    private var simplePlaylists: [String: CacheEntry<SimplePlaylist>] = [:]
    private var lyricsCache: [String: CacheEntry<Lyrics?>] = [:]
    private var streams: [String: CacheEntry<String>] = [:]

    // Query result caches
    private var likedTrackIDs: CacheEntry<[String]>?
    private var userPlaylistIDs: CacheEntry<[String]>?
    private var editorialPlaylistIDs: CacheEntry<[String]>?
    private var hiddenCollection: CacheEntry<HiddenCollection>?
    private var recommendations: CacheEntry<DynamicBlock>?
    private var recommendationsInflight: Task<DynamicBlock, Error>?
    private var recommendationsInflightGeneration = 0
    private var grids: [String: CacheEntry<GridPage>] = [:]
    private var radioStations: CacheEntry<[RadioStation]>?

    func configure(appState: AppState) {
        self.appState = appState
        loadPersistedRecommendations()
    }

    // MARK: - Tracks

    func getTrack(_ id: String) async throws -> Track? {
        let result = try await getTracks([id])
        return result.first
    }

    func getTracks(_ ids: [String]) async throws -> [Track] {
        guard let client, !ids.isEmpty else { return [] }

        var result: [String: Track] = [:]
        var missingIDs: [String] = []

        for id in ids {
            if let entry = tracks[id], !entry.isExpired {
                result[id] = entry.value
            } else {
                missingIDs.append(id)
            }
        }

        if !missingIDs.isEmpty {
            let fetched = try await client.getTracks(missingIDs)
            for track in fetched {
                tracks[track.id] = CacheEntry(value: track, insertedAt: Date(), ttl: TTL.stableEntity)
                result[track.id] = track
            }
            evictIfNeeded(&tracks, max: Limits.tracks)
        }

        return ids.compactMap { result[$0] }
    }

    // MARK: - Artists

    func getArtist(
        _ id: String,
        withReleases: Bool = false,
        withPopularTracks: Bool = false,
        withRelatedArtists: Bool = false,
        withDescription: Bool = false
    ) async throws -> Artist? {
        if let entry = artists[id], !entry.isExpired {
            let cached = entry.value
            let satisfiesRequest =
                (!withReleases || !cached.releases.isEmpty) &&
                (!withPopularTracks || !cached.popularTracks.isEmpty) &&
                (!withRelatedArtists || !cached.relatedArtists.isEmpty) &&
                (!withDescription || cached.description != nil)
            if satisfiesRequest {
                return cached
            }
        }
        guard let client else { return nil }
        let artist = try await client.getArtist(
            id, withReleases: withReleases,
            withPopularTracks: withPopularTracks,
            withRelatedArtists: withRelatedArtists,
            withDescription: withDescription
        )
        if let artist {
            artists[id] = CacheEntry(value: artist, insertedAt: Date(), ttl: TTL.stableEntity)
            evictIfNeeded(&artists, max: Limits.artists)
        }
        return artist
    }

    func getArtists(_ ids: [String]) async throws -> [Artist] {
        guard let client, !ids.isEmpty else { return [] }

        var result: [String: Artist] = [:]
        var missingIDs: [String] = []

        for id in ids {
            if let entry = artists[id], !entry.isExpired {
                result[id] = entry.value
            } else {
                missingIDs.append(id)
            }
        }

        if !missingIDs.isEmpty {
            let fetched = try await client.getArtists(missingIDs)
            for artist in fetched {
                artists[artist.id] = CacheEntry(value: artist, insertedAt: Date(), ttl: TTL.stableEntity)
                result[artist.id] = artist
            }
            evictIfNeeded(&artists, max: Limits.artists)
        }

        return ids.compactMap { result[$0] }
    }

    // MARK: - Releases

    func getRelease(_ id: String) async throws -> Release? {
        if let entry = releases[id], !entry.isExpired {
            return entry.value
        }
        guard let client else { return nil }
        let release = try await client.getRelease(id)
        if let release {
            releases[id] = CacheEntry(value: release, insertedAt: Date(), ttl: TTL.stableEntity)
            evictIfNeeded(&releases, max: Limits.releases)
        }
        return release
    }

    func getReleases(_ ids: [String]) async throws -> [Release] {
        guard let client, !ids.isEmpty else { return [] }

        var result: [String: Release] = [:]
        var missingIDs: [String] = []

        for id in ids {
            if let entry = releases[id], !entry.isExpired {
                result[id] = entry.value
            } else {
                missingIDs.append(id)
            }
        }

        if !missingIDs.isEmpty {
            let fetched = try await client.getReleases(missingIDs)
            for release in fetched {
                releases[release.id] = CacheEntry(value: release, insertedAt: Date(), ttl: TTL.stableEntity)
                result[release.id] = release
            }
            evictIfNeeded(&releases, max: Limits.releases)
        }

        return ids.compactMap { result[$0] }
    }

    // MARK: - Playlists

    func getPlaylist(_ id: String) async throws -> Playlist? {
        if let entry = playlists[id], !entry.isExpired {
            return entry.value
        }
        guard let client else { return nil }
        let playlist = try await client.getPlaylist(id)
        if let playlist {
            playlists[id] = CacheEntry(value: playlist, insertedAt: Date(), ttl: TTL.fullPlaylist)
            evictIfNeeded(&playlists, max: Limits.playlists)
        }
        return playlist
    }

    func getSimplePlaylists(_ ids: [String]) async throws -> [SimplePlaylist] {
        guard let client, !ids.isEmpty else { return [] }

        var result: [String: SimplePlaylist] = [:]
        var missingIDs: [String] = []

        for id in ids {
            if let entry = simplePlaylists[id], !entry.isExpired {
                result[id] = entry.value
            } else {
                missingIDs.append(id)
            }
        }

        if !missingIDs.isEmpty {
            let fetched = try await client.getShortPlaylist(missingIDs)
            for pl in fetched {
                simplePlaylists[pl.id] = CacheEntry(value: pl, insertedAt: Date(), ttl: TTL.simplePlaylist)
                result[pl.id] = pl
            }
            evictIfNeeded(&simplePlaylists, max: Limits.simplePlaylists)
        }

        return ids.compactMap { result[$0] }
    }

    // MARK: - Lyrics

    func getLyrics(_ trackId: String) async throws -> Lyrics? {
        if let entry = lyricsCache[trackId], !entry.isExpired {
            return entry.value
        }
        guard let client else { return nil }
        let lyrics = try await client.getLyrics(trackId)
        lyricsCache[trackId] = CacheEntry(value: lyrics, insertedAt: Date(), ttl: TTL.lyrics)
        evictIfNeeded(&lyricsCache, max: Limits.lyrics)
        return lyrics
    }

    // MARK: - Stream URLs

    func resolveStreamURL(trackId: String, quality: StreamQuality) async throws -> String {
        let key = "\(trackId)_\(quality.rawValue)"
        if let entry = streams[key], !entry.isExpired {
            return entry.value
        }
        guard let client else { throw ZvukError.unauthorized(message: "No client") }

        // Try direct stream first
        if let direct = try? await client.getDirectStreamURL(trackId, quality: quality) {
            streams[key] = CacheEntry(value: direct.stream, insertedAt: Date(), ttl: TTL.stream)
            evictIfNeeded(&streams, max: Limits.streams)
            return direct.stream
        }

        // Map to GraphQL quality
        let gqlQuality: Quality = switch quality {
        case .mid: .mid
        case .high: .high
        case .flac: .flac
        }

        do {
            let url = try await client.getStreamURL(trackId, quality: gqlQuality)
            streams[key] = CacheEntry(value: url, insertedAt: Date(), ttl: TTL.stream)
            evictIfNeeded(&streams, max: Limits.streams)
            return url
        } catch let error as ZvukError {
            if case .subscriptionRequired = error {
                let url = try await client.getStreamURL(trackId, quality: .mid)
                // Кэшируем и под запрошенным ключом, и под mid — иначе каждый плей трека без подписки
                // повторяет полный цикл (direct → запрошенное качество → mid).
                streams[key] = CacheEntry(value: url, insertedAt: Date(), ttl: TTL.stream)
                streams["\(trackId)_mid"] = CacheEntry(value: url, insertedAt: Date(), ttl: TTL.stream)
                evictIfNeeded(&streams, max: Limits.streams)
                return url
            }
            throw error
        }
    }

    // MARK: - Grids

    func getGrid(name: String) async throws -> GridPage {
        if let entry = grids[name], !entry.isExpired {
            return entry.value
        }
        guard let client else { return GridPage() }
        let grid = try await client.getGrid(name: name)
        grids[name] = CacheEntry(value: grid, insertedAt: Date(), ttl: TTL.stableEntity)
        return grid
    }

    // MARK: - Radio Stations

    /// Каталог интернет-радио. Меняется редко, поэтому берётся целиком одним
    /// запросом и живёт столько же, сколько прочие стабильные сущности.
    func getRadioStations() async throws -> [RadioStation] {
        if let entry = radioStations, !entry.isExpired {
            return entry.value
        }
        guard let client else { return [] }
        let stations = try await client.getRadioStations(limit: Limits.radioCatalogue)
        radioStations = CacheEntry(value: stations, insertedAt: Date(), ttl: TTL.stableEntity)
        return stations
    }

    // MARK: - Liked Tracks (query result)

    func getLikedTracks(orderBy: OrderBy = .dateAdded, direction: OrderDirection = .desc) async throws -> [Track] {
        guard let client else { return [] }

        if let cached = likedTrackIDs, !cached.isExpired {
            return try await getTracks(cached.value)
        }

        let stubs = try await client.getLikedTracks(orderBy: orderBy, direction: direction)
        let ids = stubs.map(\.id)
        likedTrackIDs = CacheEntry(value: ids, insertedAt: Date(), ttl: TTL.queryResult)

        return try await getTracks(ids)
    }

    // MARK: - User Playlists (query result)

    func getUserPlaylistIDs() async throws -> [String] {
        if let cached = userPlaylistIDs, !cached.isExpired {
            return cached.value
        }
        guard let client else { return [] }
        let items = try await client.getUserPlaylists()
        let ids = items.compactMap(\.id)
        userPlaylistIDs = CacheEntry(value: ids, insertedAt: Date(), ttl: TTL.queryResult)
        return ids
    }

    // MARK: - Editorial Playlists (query result)

    func getEditorialPlaylistIDs() async throws -> [String] {
        if let cached = editorialPlaylistIDs, !cached.isExpired {
            return cached.value
        }
        guard let client else { return [] }
        let ids = try await client.getEditorialPlaylistIds()
        editorialPlaylistIDs = CacheEntry(value: ids, insertedAt: Date(), ttl: TTL.queryResult)
        return ids
    }

    // MARK: - Recommendations (query result)

    func getRecommendations() async throws -> DynamicBlock {
        if let cached = recommendations, !cached.isExpired {
            return cached.value
        }
        guard let client else { return DynamicBlock() }
        let block = try await client.getMusicRecommendations()
        recommendations = CacheEntry(value: block, insertedAt: Date(), ttl: TTL.recommendations)
        persistRecommendations()
        return block
    }

    /// Догружает все недостающие страницы рекомендаций последовательно и кэширует полный набор.
    /// Параллельные вызовы делят одну in-flight задачу — повторного трафика к API не происходит.
    func loadAllRecommendations() async throws -> DynamicBlock {
        if let inflight = recommendationsInflight {
            return try await inflight.value
        }
        recommendationsInflightGeneration += 1
        let generation = recommendationsInflightGeneration
        let task = Task { try await performLoadAllRecommendations() }
        recommendationsInflight = task
        // Очищаем только свою задачу: отменённый/перезапущенный вызов не должен обнулять чужой inflight.
        defer { if recommendationsInflightGeneration == generation { recommendationsInflight = nil } }
        return try await task.value
    }

    private func performLoadAllRecommendations() async throws -> DynamicBlock {
        let initial = try await getRecommendations()
        // totalPages приходит через decodeDefault со значением 0 — это означает «сервер поле не прислал»,
        // в таком случае угадывать число страниц нельзя.
        guard initial.totalPages > 0 else {
            if !initial.pages.isEmpty {
                print("[YAMP][Cache] recommendations: totalPages=0, страниц больше не запрашиваем")
            }
            return initial
        }
        guard initial.totalPages > initial.pages.count, let client else {
            return initial
        }

        let initialInsertedAt = recommendations?.insertedAt ?? Date()
        let loaded = Set(initial.pages.map(\.page))
        let missing = (1...initial.totalPages).filter { !loaded.contains($0) }

        var pagesByNumber: [Int: DynamicBlockPage] = Dictionary(
            uniqueKeysWithValues: initial.pages.map { ($0.page, $0) }
        )

        for page in missing {
            try Task.checkCancellation()
            let block = try await client.getMusicRecommendations(pages: [page])
            // API может прислать чужую/дубликат страницу — берём только ту, что запрашивали.
            if let actual = block.pages.first(where: { $0.page == page }) {
                pagesByNumber[page] = actual
            } else {
                print("[YAMP][Cache] recommendations: страница \(page) не пришла в ответе, прерываем")
                break
            }
        }

        let merged = DynamicBlock(
            totalPages: initial.totalPages,
            pages: pagesByNumber.keys.sorted().compactMap { pagesByNumber[$0] }
        )
        recommendations = CacheEntry(value: merged, insertedAt: initialInsertedAt, ttl: TTL.recommendations)
        persistRecommendations()
        return merged
    }

    func invalidateRecommendations() {
        recommendationsInflight?.cancel()
        recommendationsInflight = nil
        recommendationsInflightGeneration += 1
        recommendations = nil
        deletePersistedRecommendations()
    }

    // MARK: - Recommendations persistence

    private struct PersistedRecommendations: Codable {
        let block: DynamicBlock
        let insertedAt: Date
    }

    private func recommendationsCacheURL() -> URL? {
        guard let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        let dir = base.appendingPathComponent("yamp", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("recommendations.json")
    }

    private func loadPersistedRecommendations() {
        guard recommendations == nil,
              let url = recommendationsCacheURL(),
              FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            let persisted = try JSONDecoder().decode(PersistedRecommendations.self, from: data)
            let entry = CacheEntry(value: persisted.block, insertedAt: persisted.insertedAt, ttl: TTL.recommendations)
            if entry.isExpired {
                try? FileManager.default.removeItem(at: url)
            } else {
                recommendations = entry
            }
        } catch {
            print("[YAMP][Cache] не удалось прочитать persisted recommendations: \(error)")
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func persistRecommendations() {
        guard let url = recommendationsCacheURL(), let entry = recommendations else { return }
        let persisted = PersistedRecommendations(block: entry.value, insertedAt: entry.insertedAt)
        do {
            let data = try JSONEncoder().encode(persisted)
            try data.write(to: url, options: .atomic)
        } catch {
            print("[YAMP][Cache] не удалось сохранить recommendations на диск: \(error)")
        }
    }

    private func deletePersistedRecommendations() {
        guard let url = recommendationsCacheURL() else { return }
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Hidden Collection (query result)

    func getHiddenCollection() async throws -> HiddenCollection {
        if let cached = hiddenCollection, !cached.isExpired {
            return cached.value
        }
        guard let client else { return HiddenCollection() }
        let hidden = try await client.getHiddenCollection()
        hiddenCollection = CacheEntry(value: hidden, insertedAt: Date(), ttl: TTL.queryResult)
        return hidden
    }

    func invalidateHiddenCollection() {
        hiddenCollection = nil
    }

    /// Whether the artist is hidden (disliked). Uses the cached hidden collection,
    /// which holds only lightweight ids — one request per session.
    func isArtistHidden(_ id: String) async throws -> Bool {
        let hidden = try await getHiddenCollection()
        return hidden.artists.contains { $0.id == id }
    }

    // MARK: - Invalidation

    func invalidatePlaylist(_ id: String) {
        playlists.removeValue(forKey: id)
        simplePlaylists.removeValue(forKey: id)
    }

    func invalidateLikedTracks() {
        likedTrackIDs = nil
    }

    func invalidateUserPlaylists() {
        userPlaylistIDs = nil
    }

    func invalidateAll() {
        tracks.removeAll()
        artists.removeAll()
        releases.removeAll()
        playlists.removeAll()
        simplePlaylists.removeAll()
        lyricsCache.removeAll()
        streams.removeAll()
        likedTrackIDs = nil
        userPlaylistIDs = nil
        editorialPlaylistIDs = nil
        recommendationsInflight?.cancel()
        recommendationsInflight = nil
        recommendationsInflightGeneration += 1
        recommendations = nil
        deletePersistedRecommendations()
        hiddenCollection = nil
        grids.removeAll()
    }

    // MARK: - Eviction

    private func evictIfNeeded<T>(_ store: inout [String: CacheEntry<T>], max: Int) {
        guard store.count > max else { return }
        let sorted = store.sorted { $0.value.insertedAt < $1.value.insertedAt }
        let toRemove = store.count - max
        for (key, _) in sorted.prefix(toRemove) {
            store.removeValue(forKey: key)
        }
    }
}
