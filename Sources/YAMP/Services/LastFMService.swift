import AppKit
import Foundation
import LastFM
import ZvukMusic

@MainActor
@Observable
final class LastFMService {
    enum ScrobbleState { case idle, scrobbled }
    enum ConnectionState { case disconnected, connecting, connected }

    private(set) var connectionState: ConnectionState = .disconnected
    private(set) var scrobbleState: ScrobbleState = .idle
    private(set) var connectedUsername: String?

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

    func configure(logStore: LogStore) {
        self.logStore = logStore
        restoreSession()
    }

    // MARK: - Authentication

    func connect() {
        connectionState = .connecting
        Task {
            let start = Date()
            do {
                let token = try await apiClient.getToken()
                logStore?.appendLastFM(method: "POST", url: "last.fm/auth.getToken", statusCode: 200, duration: Date().timeIntervalSince(start), error: nil, requestBody: "{\"method\":\"auth.getToken\"}")

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
                        let body = "{\"method\":\"auth.getSession\",\"token\":\"\(token)\"}"
                        logStore?.appendLastFM(method: "POST", url: "last.fm/auth.getSession", statusCode: 200, duration: Date().timeIntervalSince(sessionStart), error: nil, requestBody: body)
                        sessionKey = session.key
                        connectedUsername = session.name
                        connectionState = .connected
                        saveSession(key: session.key, username: session.name)
                        return
                    } catch {
                        logStore?.appendLastFM(method: "POST", url: "last.fm/auth.getSession", statusCode: nil, duration: Date().timeIntervalSince(sessionStart), error: error.localizedDescription, requestBody: "{\"method\":\"auth.getSession\",\"token\":\"\(token)\"}")
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
        deleteSession()
    }

    var isConnected: Bool { connectionState == .connected && sessionKey != nil }

    // MARK: - Now Playing

    func updateNowPlaying(track: SimpleTrack) {
        guard isConnected, let key = sessionKey else { return }
        currentTrackId = track.id
        scrobbleState = .idle
        scrobbleThresholdReached = false

        let artist = track.artistsString
        let title = track.title
        let album = track.release?.title
        let dur = UInt(track.duration)

        let body = trackJSON(artist: artist, track: title, album: album, duration: dur)

        Task {
            let start = Date()
            do {
                try await apiClient.updateNowPlaying(artist: artist, track: title, album: album, duration: dur, sessionKey: key)
                logStore?.appendLastFM(method: "POST", url: "last.fm/track.updateNowPlaying", statusCode: 200, duration: Date().timeIntervalSince(start), error: nil, requestBody: body)
            } catch {
                logStore?.appendLastFM(method: "POST", url: "last.fm/track.updateNowPlaying", statusCode: nil, duration: Date().timeIntervalSince(start), error: error.localizedDescription, requestBody: body)
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
        guard let key = sessionKey else { return }

        let artist = track.artistsString
        let title = track.title
        let album = track.release?.title
        let dur = UInt(track.duration)
        let timestamp = Date()

        let body = trackJSON(artist: artist, track: title, album: album, duration: dur)

        Task {
            let start = Date()
            do {
                let accepted = try await apiClient.scrobble(artist: artist, track: title, album: album, duration: dur, date: timestamp, sessionKey: key)
                logStore?.appendLastFM(method: "POST", url: "last.fm/track.scrobble", statusCode: 200, duration: Date().timeIntervalSince(start), error: nil, requestBody: body)
                if accepted > 0 {
                    scrobbleState = .scrobbled
                }
            } catch {
                logStore?.appendLastFM(method: "POST", url: "last.fm/track.scrobble", statusCode: nil, duration: Date().timeIntervalSince(start), error: error.localizedDescription, requestBody: body)
            }
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
                logStore?.appendLastFM(method: "POST", url: "last.fm/track.love", statusCode: 200, duration: Date().timeIntervalSince(start), error: nil, requestBody: body)
            } catch {
                logStore?.appendLastFM(method: "POST", url: "last.fm/track.love", statusCode: nil, duration: Date().timeIntervalSince(start), error: error.localizedDescription, requestBody: body)
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
                logStore?.appendLastFM(method: "POST", url: "last.fm/track.unlove", statusCode: 200, duration: Date().timeIntervalSince(start), error: nil, requestBody: body)
            } catch {
                logStore?.appendLastFM(method: "POST", url: "last.fm/track.unlove", statusCode: nil, duration: Date().timeIntervalSince(start), error: error.localizedDescription, requestBody: body)
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
        SecItemAdd(add as CFDictionary, nil)
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
}

// MARK: - API Credentials
// Register your own at https://www.last.fm/api/account/create if needed

private enum LastFMCredentials {
    static let apiKey = "5f6043bb316a036361fb73479f7a491a"
    static let apiSecret = "a169c25cfa36586c1654db565bc0a938"
}
