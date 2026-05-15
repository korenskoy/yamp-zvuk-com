import Foundation
import Observation
import SwiftUI
import os.log

@MainActor
@Observable
final class UpdateService {
    struct AvailableUpdate: Equatable {
        let version: String
        let url: URL
    }

    private(set) var availableUpdate: AvailableUpdate?
    private(set) var lastCheckedAt: Date?
    private(set) var isChecking: Bool = false

    var autoCheckOnLaunch: Bool {
        get {
            access(keyPath: \.autoCheckOnLaunch)
            return _autoCheckOnLaunch
        }
        set {
            withMutation(keyPath: \.autoCheckOnLaunch) {
                _autoCheckOnLaunch = newValue
            }
            applyAutoCheckPolicy()
        }
    }

    @ObservationIgnored
    @AppStorage("autoCheckUpdates") private var _autoCheckOnLaunch: Bool = true

    let checkInterval: TimeInterval = 24 * 60 * 60

    private static let log = Logger(subsystem: "ru.korenskoy.zvuk-unofficial", category: "UpdateService")
    private let feedURL = URL(string: "https://github.com/korenskoy/yamp-zvuk-com/releases.atom")!
    private let session: URLSession
    private var pollingTask: Task<Void, Never>?

    init(session: URLSession = .shared) {
        self.session = session
    }

    func start() {
        guard autoCheckOnLaunch else { return }
        Task { await checkNow() }
        schedulePolling()
    }

    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func checkNow() async {
        isChecking = true
        defer {
            isChecking = false
            lastCheckedAt = Date()
        }

        var request = URLRequest(url: feedURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.setValue("application/atom+xml", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return }
            guard (200..<300).contains(http.statusCode) else {
                Self.log.error("Atom feed HTTP \(http.statusCode)")
                return
            }
            guard let latest = AtomFeedParser.parseLatestStable(data: data) else {
                Self.log.notice("No usable entry in atom feed")
                clearUpdate()
                return
            }
            let current = AppVersion.marketing
            if Self.compareSemver(latest.version, current) == .orderedDescending {
                Self.log.notice("Update available: \(latest.version, privacy: .public) > \(current, privacy: .public)")
                let next = AvailableUpdate(version: latest.version, url: latest.url)
                if availableUpdate != next { availableUpdate = next }
            } else {
                clearUpdate()
            }
        } catch {
            Self.log.error("Atom feed fetch failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func clearUpdate() {
        if availableUpdate != nil { availableUpdate = nil }
    }

    private func applyAutoCheckPolicy() {
        if autoCheckOnLaunch {
            if pollingTask == nil { schedulePolling() }
        } else {
            stop()
        }
    }

    private func schedulePolling() {
        pollingTask?.cancel()
        let interval = checkInterval
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { return }
                await self?.checkNow()
            }
        }
    }

    /// Покомпонентное числовое сравнение: "1.2" < "1.2.1" < "1.10".
    nonisolated static func compareSemver(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = lhs.split(separator: ".").map { Int($0) ?? 0 }
        let right = rhs.split(separator: ".").map { Int($0) ?? 0 }
        let count = max(left.count, right.count)
        for index in 0..<count {
            let lhsPart = index < left.count ? left[index] : 0
            let rhsPart = index < right.count ? right[index] : 0
            if lhsPart < rhsPart { return .orderedAscending }
            if lhsPart > rhsPart { return .orderedDescending }
        }
        return .orderedSame
    }
}
