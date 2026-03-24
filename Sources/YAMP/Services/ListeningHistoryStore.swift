import Foundation
import ZvukMusic

@MainActor
@Observable
final class ListeningHistoryStore {
    private(set) var entries: [HistoryEntry] = []

    private static let maxEntries = 250
    private static let fileName = "listening_history.json"
    private static let isoFormatter = ISO8601DateFormatter()

    private var fileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("YAMP", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(Self.fileName)
    }

    init() {
        load()
    }

    func record(_ track: SimpleTrack) {
        let now = Self.isoFormatter.string(from: Date())
        let entry = HistoryEntry(track: track, lastListeningDttm: now)
        entries.insert(entry, at: 0)
        if entries.count > Self.maxEntries {
            entries = Array(entries.prefix(Self.maxEntries))
        }
        save()
    }

    func clear() {
        entries.removeAll()
        save()
    }

    // MARK: - Persistence

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([HistoryEntry].self, from: data)
        else { return }
        entries = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
