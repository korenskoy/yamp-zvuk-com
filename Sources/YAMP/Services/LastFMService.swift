import AppKit
import Foundation
import LastFM
import ZvukMusic

/// Скроббл, не доехавший до Last.fm — хранится на диске до успешной отправки.
/// Sendable (только value-типы), чтобы безопасно передавать в nonisolated API-обёртку.
private struct PendingScrobble: Codable, Sendable {
    let artist: String
    let track: String
    let album: String?
    let duration: UInt
    let timestamp: UInt // seconds since epoch — время начала прослушивания
}

@MainActor
@Observable
final class LastFMService {
    enum ScrobbleState { case idle, scrobbled }
    enum ConnectionState { case disconnected, connecting, connected }

    private(set) var connectionState: ConnectionState = .disconnected
    /// Не приватные: ими пользуется скробблинг эфира из `LastFMService+Radio.swift`.
    var scrobbleState: ScrobbleState = .idle
    @ObservationIgnored
    var radioScrobbleTask: Task<Void, Never>?
    private(set) var connectedUsername: String?
    private(set) var sessionInvalidated = false
    /// Сколько прослушанных треков ждут отправки (накопились, пока сессия была недействительна).
    private(set) var pendingScrobbleCount = 0

    @ObservationIgnored
    private var pending: [PendingScrobble] = [] {
        didSet { pendingScrobbleCount = pending.count }
    }

    @ObservationIgnored
    private var isFlushing = false

    @ObservationIgnored
    private let apiClient = LastFMAPIClient()

    @ObservationIgnored
    private var sessionKey: String?

    @ObservationIgnored
    private weak var logStore: LogStore?

    @ObservationIgnored
    private var currentTrackId: String?

    @ObservationIgnored
    private var scrobbleThresholdReached = false

    // Keychain keys
    private static let keychainService = "ru.korenskoy.zvuk-unofficial.lastfm"
    private static let keychainSessionKey = "sessionKey"
    private static let keychainUsername = "username"

    @ObservationIgnored
    private lazy var pendingFileURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("YAMP", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("lastfm_pending_scrobbles.json")
    }()

    func configure(logStore: LogStore) {
        self.logStore = logStore
        restoreSession()
        loadPending()
        // Пробуем разгрести накопленный бэклог сразу при старте, если сессия восстановилась.
        Task { await flushPending() }
    }

    // MARK: - Authentication

    func connect() {
        sessionInvalidated = false
        connectionState = .connecting
        Task {
            let start = Date()
            do {
                let token = try await apiClient.getToken()
                logStore?.appendLastFM(
                    method: "POST", url: "last.fm/auth.getToken", statusCode: 200,
                    duration: Date().timeIntervalSince(start), error: nil,
                    requestBody: "{\"method\":\"auth.getToken\"}"
                )

                let authURL = "https://www.last.fm/api/auth/?api_key=\(LastFMCredentials.apiKey)&token=\(token)"
                if let url = URL(string: authURL) {
                    NSWorkspace.shared.open(url)
                }

                // Poll for session after user authorizes in browser
                try await Task.sleep(for: .seconds(3))
                for _ in 0..<20 {
                    let sessionStart = Date()
                    do {
                        let session = try await apiClient.getSession(token: token)
                        // Токен не логируем — маскируем.
                        let body = "{\"method\":\"auth.getSession\",\"token\":\"***\"}"
                        logStore?.appendLastFM(
                            method: "POST", url: "last.fm/auth.getSession", statusCode: 200,
                            duration: Date().timeIntervalSince(sessionStart), error: nil,
                            requestBody: body
                        )
                        sessionKey = session.key
                        connectedUsername = session.name
                        connectionState = .connected
                        saveSession(key: session.key, username: session.name)
                        await flushPending()
                        return
                    } catch {
                        logStore?.appendLastFM(
                            method: "POST", url: "last.fm/auth.getSession", statusCode: nil,
                            duration: Date().timeIntervalSince(sessionStart),
                            error: error.localizedDescription,
                            requestBody: "{\"method\":\"auth.getSession\",\"token\":\"***\"}"
                        )
                        try await Task.sleep(for: .seconds(3))
                    }
                }
                connectionState = .disconnected
            } catch {
                logStore?.appendLastFM(method: "POST", url: "last.fm/auth.getToken", statusCode: nil, duration: Date().timeIntervalSince(start), error: error.localizedDescription)
                connectionState = .disconnected
            }
        }
    }

    func disconnect() {
        sessionKey = nil
        connectedUsername = nil
        connectionState = .disconnected
        scrobbleState = .idle
        sessionInvalidated = false
        deleteSession()
    }

    var isConnected: Bool { connectionState == .connected && sessionKey != nil }

    /// Взводит флаг разлогина, если Last.fm вернул код 9 (недействительная сессия).
    private func flagIfInvalidSession(_ error: Error) {
        if case LastFMError.LastFMServiceError(.InvalidSessionKey, _) = error {
            sessionInvalidated = true
        }
    }

    // MARK: - Now Playing

    func updateNowPlaying(track: SimpleTrack) {
        guard isConnected else { return }
        currentTrackId = track.id
        scrobbleState = .idle
        scrobbleThresholdReached = false

        sendNowPlaying(artist: track.artistsString, title: track.title,
                       album: track.release?.title, duration: UInt(track.duration))
    }

    /// Отправка «сейчас играет» по строкам: Last.fm не знает про наши ID, и
    /// этим же путём уходит эфир радио, где трека с ID попросту нет.
    func sendNowPlaying(artist: String, title: String, album: String?, duration: UInt) {
        guard let key = sessionKey else { return }
        let body = trackJSON(artist: artist, track: title, album: album, duration: duration)

        Task {
            let start = Date()
            do {
                try await apiClient.updateNowPlaying(
                    artist: artist, track: title, album: album, duration: duration, sessionKey: key
                )
                logStore?.appendLastFM(
                    method: "POST", url: "last.fm/track.updateNowPlaying", statusCode: 200,
                    duration: Date().timeIntervalSince(start), error: nil, requestBody: body
                )
            } catch {
                logStore?.appendLastFM(
                    method: "POST", url: "last.fm/track.updateNowPlaying", statusCode: nil,
                    duration: Date().timeIntervalSince(start),
                    error: error.localizedDescription, requestBody: body
                )
                flagIfInvalidSession(error)
            }
        }
    }

    // MARK: - Scrobble

    func checkAndScrobble(track: SimpleTrack, currentTime: Double, duration: Double) {
        guard isConnected,
              !scrobbleThresholdReached,
              track.id == currentTrackId,
              duration >= 30
        else { return }

        let threshold = min(duration * 0.5, 240)
        guard currentTime >= threshold else { return }

        scrobbleThresholdReached = true
        scrobble(track: track)
    }

    private func scrobble(track: SimpleTrack) {
        sendScrobble(artist: track.artistsString, title: track.title,
                     album: track.release?.title, duration: UInt(track.duration))
    }

    /// Отправка скроббла по строкам; этим же путём уходит эфир радио.
    func sendScrobble(artist: String, title: String, album: String?, duration: UInt) {
        guard let key = sessionKey else { return }
        let timestamp = Date()

        let body = trackJSON(artist: artist, track: title, album: album, duration: duration)

        Task {
            let start = Date()
            do {
                let accepted = try await apiClient.scrobble(
                    artist: artist, track: title, album: album,
                    duration: duration, date: timestamp, sessionKey: key
                )
                logStore?.appendLastFM(
                    method: "POST", url: "last.fm/track.scrobble", statusCode: 200,
                    duration: Date().timeIntervalSince(start), error: nil, requestBody: body
                )
                if accepted > 0 {
                    scrobbleState = .scrobbled
                }
                // Успешно — заодно разгребаем накопленный бэклог.
                await flushPending()
            } catch {
                logStore?.appendLastFM(
                    method: "POST", url: "last.fm/track.scrobble", statusCode: nil,
                    duration: Date().timeIntervalSince(start),
                    error: error.localizedDescription, requestBody: body
                )
                flagIfInvalidSession(error)
                // Не теряем прослушанное — откладываем до следующей успешной отправки.
                enqueuePending(artist: artist, track: title, album: album, duration: duration, date: timestamp)
            }
        }
    }

    // MARK: - Offline scrobble queue

    func enqueuePending(artist: String, track: String, album: String?, duration: UInt, date: Date) {
        pending.append(PendingScrobble(
            artist: artist, track: track, album: album,
            duration: duration, timestamp: UInt(date.timeIntervalSince1970)
        ))
        savePending()
    }

    /// Отправляет отложенные скробблы батчами по 50. Отправленные удаляет; при ошибке останавливается,
    /// остаток ждёт следующего раза.
    private func flushPending() async {
        guard !isFlushing, isConnected, let key = sessionKey, !pending.isEmpty else { return }
        isFlushing = true
        defer { isFlushing = false }

        while !pending.isEmpty {
            let batch = Array(pending.prefix(50))
            let start = Date()
            do {
                let accepted = try await apiClient.scrobbleBatch(items: batch, sessionKey: key)
                logStore?.appendLastFM(
                    method: "POST", url: "last.fm/track.scrobble", statusCode: 200,
                    duration: Date().timeIntervalSince(start), error: nil,
                    requestBody: "{\"method\":\"track.scrobble\",\"batch\":\(batch.count)}"
                )
                if accepted > 0 { scrobbleState = .scrobbled }
                pending.removeFirst(batch.count)
                savePending()
            } catch {
                logStore?.appendLastFM(
                    method: "POST", url: "last.fm/track.scrobble", statusCode: nil,
                    duration: Date().timeIntervalSince(start),
                    error: error.localizedDescription,
                    requestBody: "{\"method\":\"track.scrobble\",\"batch\":\(batch.count)}"
                )
                flagIfInvalidSession(error)
                return
            }
        }
    }

    private func loadPending() {
        guard let data = try? Data(contentsOf: pendingFileURL) else { return }
        pending = (try? JSONDecoder().decode([PendingScrobble].self, from: data)) ?? []
    }

    private func savePending() {
        do {
            let data = try JSONEncoder().encode(pending)
            try data.write(to: pendingFileURL, options: .atomic)
        } catch {
            logStore?.appendLastFM(
                method: "FILE", url: "lastfm_pending_scrobbles.json", statusCode: nil,
                duration: 0, error: error.localizedDescription
            )
        }
    }

    // MARK: - Love / Unlove

    func loveTrack(_ track: SimpleTrack) {
        guard isConnected, let key = sessionKey else { return }
        let artist = track.artistsString
        let title = track.title
        let body = trackJSON(artist: artist, track: title, album: nil, duration: 0)

        Task {
            let start = Date()
            do {
                try await apiClient.loveTrack(artist: artist, track: title, sessionKey: key)
                logStore?.appendLastFM(
                    method: "POST", url: "last.fm/track.love", statusCode: 200,
                    duration: Date().timeIntervalSince(start), error: nil, requestBody: body
                )
            } catch {
                logStore?.appendLastFM(
                    method: "POST", url: "last.fm/track.love", statusCode: nil,
                    duration: Date().timeIntervalSince(start),
                    error: error.localizedDescription, requestBody: body
                )
                flagIfInvalidSession(error)
            }
        }
    }

    func unloveTrack(_ track: SimpleTrack) {
        guard isConnected, let key = sessionKey else { return }
        let artist = track.artistsString
        let title = track.title
        let body = trackJSON(artist: artist, track: title, album: nil, duration: 0)

        Task {
            let start = Date()
            do {
                try await apiClient.unloveTrack(artist: artist, track: title, sessionKey: key)
                logStore?.appendLastFM(
                    method: "POST", url: "last.fm/track.unlove", statusCode: 200,
                    duration: Date().timeIntervalSince(start), error: nil, requestBody: body
                )
            } catch {
                logStore?.appendLastFM(
                    method: "POST", url: "last.fm/track.unlove", statusCode: nil,
                    duration: Date().timeIntervalSince(start),
                    error: error.localizedDescription, requestBody: body
                )
                flagIfInvalidSession(error)
            }
        }
    }

    private func trackJSON(artist: String, track: String, album: String?, duration: UInt) -> String {
        var dict: [String: Any] = ["artist": artist, "track": track, "duration": duration]
        if let album { dict["album"] = album }
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: .sortedKeys),
              let str = String(data: data, encoding: .utf8)
        else { return "{}" }
        return str
    }

    // MARK: - Keychain

    private func saveSession(key: String, username: String) {
        save(toKeychain: key, account: Self.keychainSessionKey)
        save(toKeychain: username, account: Self.keychainUsername)
    }

    private func restoreSession() {
        guard let key = load(fromKeychain: Self.keychainSessionKey),
              let username = load(fromKeychain: Self.keychainUsername)
        else { return }
        sessionKey = key
        connectedUsername = username
        connectionState = .connected
    }

    private func deleteSession() {
        delete(fromKeychain: Self.keychainSessionKey)
        delete(fromKeychain: Self.keychainUsername)
    }

    private func save(toKeychain value: String, account: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(add as CFDictionary, nil)
        if status != errSecSuccess {
            logStore?.appendLastFM(
                method: "KEYCHAIN", url: "keychain/\(account)", statusCode: nil,
                duration: 0, error: "SecItemAdd OSStatus \(status)"
            )
        }
    }

    private func load(fromKeychain account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func delete(fromKeychain account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Nonisolated API wrapper (avoids Swift 6 Sendable issues)

private final class LastFMAPIClient: Sendable {
    nonisolated(unsafe) private let lastFM = LastFM(apiKey: LastFMCredentials.apiKey, apiSecret: LastFMCredentials.apiSecret)

    struct SessionResult: Sendable {
        let key: String
        let name: String
    }

    func getToken() async throws -> String {
        try await lastFM.Auth.getToken()
    }

    func getSession(token: String) async throws -> SessionResult {
        let session = try await lastFM.Auth.getSession(token: token)
        return SessionResult(key: session.key, name: session.name)
    }

    func updateNowPlaying(artist: String, track: String, album: String?, duration: UInt, sessionKey: String) async throws {
        let params = TrackNowPlayingParams(artist: artist, track: track, album: album, duration: duration)
        _ = try await lastFM.Track.updateNowPlaying(params: params, sessionKey: sessionKey)
    }

    func loveTrack(artist: String, track: String, sessionKey: String) async throws {
        let params = TrackParams(track: track, artist: artist)
        try await lastFM.Track.love(params: params, sessionKey: sessionKey)
    }

    func unloveTrack(artist: String, track: String, sessionKey: String) async throws {
        let params = TrackParams(track: track, artist: artist)
        try await lastFM.Track.unlove(params: params, sessionKey: sessionKey)
    }

    func scrobble(artist: String, track: String, album: String?, duration: UInt, date: Date, sessionKey: String) async throws -> UInt {
        var params = ScrobbleParams()
        try params.addItem(item: ScrobbleParamItem(artist: artist, track: track, date: date, album: album, duration: duration))
        let result = try await lastFM.Track.scrobble(params: params, sessionKey: sessionKey)
        return result.accepted
    }

    /// Батч-скроббл (до 50 позиций за запрос). Timestamp'ы уже проставлены в каждом элементе.
    func scrobbleBatch(items: [PendingScrobble], sessionKey: String) async throws -> UInt {
        var params = ScrobbleParams()
        for item in items {
            try params.addItem(item: ScrobbleParamItem(
                artist: item.artist, track: item.track, timestamp: item.timestamp,
                album: item.album, duration: item.duration
            ))
        }
        let result = try await lastFM.Track.scrobble(params: params, sessionKey: sessionKey)
        return result.accepted
    }
}

// MARK: - API Credentials
// Инъекция на этапе сборки: Configuration/Secrets.xcconfig → Info.plist → Bundle.
// В исходниках секрета нет. Шаблон — Configuration/Secrets.example.xcconfig.

private enum LastFMCredentials {
    static let apiKey = Bundle.main.object(forInfoDictionaryKey: "LastFMAPIKey") as? String ?? ""
    static let apiSecret = Bundle.main.object(forInfoDictionaryKey: "LastFMAPISecret") as? String ?? ""
}
