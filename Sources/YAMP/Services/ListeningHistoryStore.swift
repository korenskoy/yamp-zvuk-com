import Foundation
import os.log
import ZvukMusic

@MainActor
@Observable
final class ListeningHistoryStore {
    private(set) var entries: [HistoryEntry] = []

    private static let maxEntries = 250
    private static let fileName = "listening_history.json"
    private static let isoFormatter = ISO8601DateFormatter()
    private static let log = Logger(subsystem: "ru.korenskoy.zvuk-unofficial", category: "ListeningHistory")

    /// Декодирует элементы по одному — одна повреждённая запись не губит весь массив.
    private struct FailableDecodable<T: Decodable>: Decodable {
        let value: T?
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            value = try? container.decode(T.self)
        }
    }

    private let fileURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("YAMP", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent(Self.fileName)
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
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            Self.log.error("Не удалось прочитать файл истории: \(error.localizedDescription, privacy: .public)")
            return
        }
        do {
            entries = try JSONDecoder().decode([HistoryEntry].self, from: data)
        } catch {
            Self.log.error("Не удалось декодировать историю: \(error.localizedDescription, privacy: .public)")
            // Спасаем валидные записи; если ничего не осталось — архивируем файл, а не перезаписываем молча.
            let salvaged = (try? JSONDecoder().decode([FailableDecodable<HistoryEntry>].self, from: data))?
                .compactMap(\.value) ?? []
            entries = salvaged
            if salvaged.isEmpty {
                let backup = fileURL.appendingPathExtension("corrupt")
                try? FileManager.default.removeItem(at: backup)
                try? FileManager.default.moveItem(at: fileURL, to: backup)
            }
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(entries)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            Self.log.error("Не удалось сохранить историю: \(error.localizedDescription, privacy: .public)")
        }
    }
}
