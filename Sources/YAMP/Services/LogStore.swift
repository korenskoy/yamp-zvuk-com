import Foundation
import Observation
import ZvukMusic

@Observable
@MainActor
final class LogStore {
    enum APISource: String {
        case zvuk = "Zvuk"
        case lastfm = "Last.fm"
    }

    struct Entry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let method: String
        let url: String
        let statusCode: Int?
        let duration: TimeInterval
        let error: String?
        let bytesSent: Int
        let bytesReceived: Int
        let requestBody: String?
        let responseBody: String?
        let apiSource: APISource

        var isError: Bool { error != nil }
        var hasDetails: Bool { requestBody != nil || responseBody != nil }

        var operationName: String? {
            guard let body = requestBody,
                  let data = body.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let name = json["operationName"] as? String else { return nil }
            return name
        }

        var preview: String? {
            guard let body = responseBody, !body.isEmpty else { return nil }
            let clean = body.prefix(128).replacingOccurrences(of: "\n", with: " ")
            return body.count > 128 ? clean + "…" : String(clean)
        }

        var shortURL: String {
            if url.contains("graphql"), let op = operationName {
                return "GraphQL: \(op)"
            }
            if url.contains("graphql") {
                return "GraphQL"
            }
            return URL(string: url)?.lastPathComponent ?? url
        }
    }

    private(set) var entries: [Entry] = []
    var isVisible = false

    private static let maxEntries = 500
    private let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    func attach(to client: ZvukClient?) {
        client?.onNetworkLog = { [weak self] log in
            Task { @MainActor in
                self?.append(log)
            }
        }
    }

    func clear() {
        entries.removeAll()
    }

    func formattedTime(_ date: Date) -> String {
        formatter.string(from: date)
    }

    func appendLastFM(method: String, url: String, statusCode: Int?, duration: TimeInterval, error: String?, requestBody: String? = nil) {
        let entry = Entry(
            timestamp: Date(),
            method: method,
            url: url,
            statusCode: statusCode,
            duration: duration,
            error: error,
            bytesSent: 0,
            bytesReceived: 0,
            requestBody: requestBody,
            responseBody: nil,
            apiSource: .lastfm
        )
        entries.append(entry)
        if entries.count > Self.maxEntries {
            entries.removeFirst(entries.count - Self.maxEntries)
        }
    }

    private func append(_ log: NetworkLogEntry) {
        let entry = Entry(
            timestamp: log.timestamp,
            method: log.method,
            url: log.url,
            statusCode: log.statusCode,
            duration: log.duration,
            error: log.error,
            bytesSent: log.bytesSent,
            bytesReceived: log.bytesReceived,
            requestBody: log.requestBody,
            responseBody: log.responseBody,
            apiSource: .zvuk
        )
        entries.append(entry)
        if entries.count > Self.maxEntries {
            entries.removeFirst(entries.count - Self.maxEntries)
        }
    }
}
