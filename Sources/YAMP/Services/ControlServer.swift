import Foundation
import Network
import ZvukMusic

/// Локальный HTTP-пульт: состояние плеера, логи запросов, управление
/// воспроизведением и вызовы API — всё через curl с localhost.
///
/// ponytail: HTTP + curl вместо MCP-сервера. MCP-клиента внутри приложения нет,
/// а curl есть у любого агента; при необходимости MCP-обёртка пишется снаружи
/// поверх этих же эндпоинтов.
///
/// Выключен по умолчанию — включается тумблером в настройках.
@MainActor
@Observable
final class ControlServer {
    static let port: UInt16 = 8787
    static let enabledKey = "ControlServerEnabled"

    private(set) var isRunning = false

    private var listener: NWListener?
    private var token = ""

    private var player: PlayerService?
    private var collection: CollectionService?
    private var cache: CacheService?
    private var appState: AppState?
    private var logStore: LogStore?

    func configure(
        player: PlayerService, collection: CollectionService,
        cache: CacheService, appState: AppState, logStore: LogStore
    ) {
        self.player = player
        self.collection = collection
        self.cache = cache
        self.appState = appState
        self.logStore = logStore
        if UserDefaults.standard.bool(forKey: Self.enabledKey) {
            start()
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        token = ""
        isRunning = false
        if let tokenPath = Self.tokenURL {
            try? FileManager.default.removeItem(at: tokenPath)
        }
    }

    func start() {
        guard listener == nil, let logStore else { return }
        token = UUID().uuidString
        guard let tokenPath = Self.tokenURL else {
            logStore.appendLocal(operation: "ControlServer.start", error: "no application support directory")
            return
        }
        do {
            try token.write(to: tokenPath, atomically: true, encoding: .utf8)
            let params = NWParameters.tcp
            params.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: .init(integerLiteral: Self.port))
            let listener = try NWListener(using: params)
            listener.newConnectionHandler = { [weak self] connection in
                connection.start(queue: .main)
                Task { @MainActor in self?.receive(on: connection) }
            }
            listener.start(queue: .main)
            self.listener = listener
            isRunning = true
            logStore.appendLocal(operation: "ControlServer", error: "listening on 127.0.0.1:\(Self.port), token: \(tokenPath.path)")
        } catch {
            logStore.appendLocal(operation: "ControlServer.start", error: String(describing: error))
        }
    }

    static var tokenURL: URL? {
        try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("control-token")
    }

    // MARK: - HTTP

    private func receive(on connection: NWConnection) {
        // ponytail: один receive на запрос. Команды — короткие GET без тела,
        // в 64 КБ умещается с запасом; если появится POST с телом — склеивать чанки.
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, _, _ in
            guard let data, let head = String(data: data, encoding: .utf8) else {
                connection.cancel()
                return
            }
            Task { @MainActor in await self?.handle(head, on: connection) }
        }
    }

    private func handle(_ head: String, on connection: NWConnection) async {
        let lines = head.split(separator: "\r\n", omittingEmptySubsequences: false)
        let target = lines.first?.split(separator: " ").dropFirst().first.map(String.init) ?? "/"
        let bearer = lines.first { $0.lowercased().hasPrefix("authorization:") }?
            .split(separator: " ").last.map(String.init)

        guard let bearer, bearer == token, !token.isEmpty else {
            respond(["error": "unauthorized"], status: "401 Unauthorized", on: connection)
            return
        }

        let parts = target.split(separator: "?", maxSplits: 1)
        let path = String(parts.first ?? "/")
        let query = parts.count > 1 ? Self.parseQuery(String(parts[1])) : [:]

        do {
            respond(try await route(path: path, query: query), on: connection)
        } catch {
            logStore?.appendLocal(operation: "ControlServer \(path)", error: String(describing: error))
            respond(["error": String(describing: error)], status: "500 Internal Server Error", on: connection)
        }
    }

    private static func parseQuery(_ raw: String) -> [String: String] {
        var result: [String: String] = [:]
        for pair in raw.split(separator: "&") {
            let kv = pair.split(separator: "=", maxSplits: 1)
            guard let key = kv.first else { continue }
            let value = kv.count > 1 ? String(kv[1]).replacingOccurrences(of: "+", with: " ") : ""
            result[String(key)] = value.removingPercentEncoding ?? value
        }
        return result
    }

    private func respond(_ body: [String: Any], status: String = "200 OK", on connection: NWConnection) {
        let json = (try? JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted, .sortedKeys]))
            ?? Data(#"{"error":"encoding failed"}"#.utf8)
        let headers = "HTTP/1.1 \(status)\r\n"
            + "Content-Type: application/json; charset=utf-8\r\n"
            + "Content-Length: \(json.count)\r\nConnection: close\r\n\r\n"
        var response = Data(headers.utf8)
        response.append(json)
        connection.send(content: response, completion: .contentProcessed { _ in connection.cancel() })
    }

    // MARK: - Routes

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func route(path: String, query: [String: String]) async throws -> [String: Any] {
        guard let player, let collection, let cache, let appState, let logStore else {
            return ["error": "not configured"]
        }
        switch path {
        case "/state":
            return state(player: player, appState: appState)

        case "/logs":
            let limit = Int(query["limit"] ?? "") ?? 50
            let onlyErrors = query["errors"] == "1"
            let full = query["full"] == "1"
            let entries = logStore.entries.filter { !onlyErrors || $0.isError }.suffix(limit)
            return ["entries": entries.map { Self.json(for: $0, full: full) }]

        case "/play":
            player.resume()
        case "/pause":
            player.pause()
        case "/toggle":
            player.togglePlayPause()
        case "/next":
            player.next()
        case "/prev":
            player.previous()
        case "/shuffle":
            player.toggleShuffle()
        case "/repeat":
            player.cycleRepeatMode()

        case "/volume":
            guard let value = Double(query["v"] ?? "") else { return ["error": "v=0.0…1.0 required"] }
            player.volume = min(max(value, 0), 1)
        case "/seek":
            guard let time = Double(query["t"] ?? "") else { return ["error": "t=<seconds> required"] }
            player.seek(to: time)

        case "/like":
            guard let track = player.currentTrack else { return ["error": "nothing is playing"] }
            await collection.toggleTrackLike(track, client: appState.client)
            return ["liked": collection.isTrackLiked(track.id), "track": track.title]

        case "/search":
            guard let client = appState.client else { return ["error": "not authenticated"] }
            guard let text = query["q"], !text.isEmpty else { return ["error": "q=<query> required"] }
            let limit = Int(query["limit"] ?? "") ?? 10
            let found = try await client.searchTracks(text, limit: limit)
            return ["tracks": found.items.map(Self.json(for:))]

        case "/playlists":
            let ids = try await cache.getUserPlaylistIDs()
            let playlists = try await cache.getSimplePlaylists(ids)
            return ["playlists": playlists.map { ["id": $0.id, "title": $0.title, "duration": $0.duration] }]

        case "/liked":
            let tracks = try await cache.getLikedTracks()
            return ["tracks": tracks.map { Self.json(for: $0.simplified) }]

        case "/radio":
            let stations = try await cache.getRadioStations()
            return ["stations": stations.map { ["id": $0.id, "name": $0.name] }]

        case "/grid":
            // Проба tiny-эндпоинта: быстрый способ увидеть анти-бот блокировку изнутри приложения.
            let page = try await cache.getGrid(name: query["name"] ?? "main")
            return ["version": page.version, "sections": page.sections.map {
                ["title": $0.header?.title ?? "", "type": $0.type, "view": $0.view, "items": $0.data.count]
            }]

        case "/playlist/create":
            guard let client = appState.client else { return ["error": "not authenticated"] }
            guard let name = query["name"], !name.isEmpty else { return ["error": "name required"] }
            let ids = Self.trackIds(query["tracks"], player: player)
            let id = try await client.createPlaylist(name, trackIds: ids.isEmpty ? nil : ids)
            cache.invalidateUserPlaylists()
            collection.bumpPlaylistsVersion()
            return ["created": id, "tracks": ids.count]

        case "/playlist/add":
            guard let client = appState.client else { return ["error": "not authenticated"] }
            guard let id = query["id"] else { return ["error": "id required"] }
            let ids = Self.trackIds(query["tracks"], player: player)
            guard !ids.isEmpty else { return ["error": "tracks=<id,id> required, or play a track"] }
            let added = try await client.addTracksToPlaylist(id, trackIds: ids)
            cache.invalidatePlaylist(id)
            collection.bumpPlaylistsVersion()
            return ["added": added, "playlist": id, "tracks": ids]

        case "/play/track":
            guard let client = appState.client, let id = query["id"] else { return ["error": "id required"] }
            guard let track = try await client.getTrack(id)?.simplified else { return ["error": "track not found"] }
            player.play(track: track, context: .search)
            return ["playing": track.title]

        case "/play/playlist":
            guard let client = appState.client, let id = query["id"] else { return ["error": "id required"] }
            let tracks = try await client.getPlaylistTracks(id)
            guard !tracks.isEmpty else { return ["error": "playlist is empty"] }
            player.playQueue(tracks, context: .playlist(id: id))
            return ["playing": tracks.count]

        case "/play/radio":
            guard let id = query["id"] else { return ["error": "id required"] }
            let stations = try await cache.getRadioStations()
            guard let station = stations.first(where: { $0.id == id }) else { return ["error": "station not found"] }
            player.playStation(station)
            return ["playing": station.name]

        default:
            return ["error": "unknown path", "paths": [
                "/state", "/logs?limit=50&errors=1&full=1", "/play", "/pause", "/toggle", "/next", "/prev",
                "/shuffle", "/repeat", "/volume?v=0.5", "/seek?t=30", "/like", "/search?q=&limit=10",
                "/playlists", "/liked", "/radio", "/grid?name=main",
                "/playlist/create?name=&tracks=", "/playlist/add?id=&tracks=",
                "/play/track?id=", "/play/playlist?id=", "/play/radio?id=",
            ]]
        }
        return state(player: player, appState: appState)
    }

    private func state(player: PlayerService, appState: AppState) -> [String: Any] {
        var result: [String: Any] = [
            "isPlaying": player.isPlaying,
            "position": player.currentTime,
            "duration": player.duration,
            "volume": player.volume,
            "shuffle": player.isShuffled,
            "repeat": String(describing: player.repeatMode),
            "queueIndex": player.queueIndex,
            "queueCount": player.queue.count,
            "authenticated": appState.isAuthenticated,
        ]
        if let track = player.currentTrack {
            result["track"] = Self.json(for: track)
        }
        if let station = player.currentStation {
            result["station"] = station.name
            result["onAir"] = [player.onAir?.artist, player.onAir?.title].compactMap { $0 }.joined(separator: " — ")
        }
        return result
    }

    /// `tracks=1,2,3`; пустой параметр означает «текущий трек».
    private static func trackIds(_ raw: String?, player: PlayerService) -> [String] {
        guard let raw, !raw.isEmpty else {
            return [player.currentTrack?.id].compactMap { $0 }
        }
        return raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    private static func json(for track: SimpleTrack) -> [String: Any] {
        [
            "id": track.id,
            "title": track.title,
            "artist": track.artists.map(\.title).joined(separator: ", "),
            "album": track.release?.title ?? "",
            "duration": track.duration,
        ]
    }

    private static func json(for entry: LogStore.Entry, full: Bool) -> [String: Any] {
        var result: [String: Any] = [
            "time": ISO8601DateFormatter().string(from: entry.timestamp),
            "source": entry.apiSource.rawValue,
            "method": entry.method,
            "url": entry.url,
            "name": entry.shortURL,
            "ms": Int(entry.duration * 1000),
        ]
        if let status = entry.statusCode { result["status"] = status }
        if let error = entry.error { result["error"] = error }
        if full {
            if let request = entry.requestBody { result["request"] = request }
            if let response = entry.responseBody { result["response"] = response }
        } else if let preview = entry.preview {
            result["preview"] = preview
        }
        return result
    }
}
