import Foundation
import ZvukMusic

struct LyricsLine: Identifiable {
    let id = UUID()
    let timestamp: TimeInterval
    let text: String
}

@MainActor
final class LyricsService {
    func fetchLyrics(trackId: String, cache: CacheService?) async -> (lines: [LyricsLine], isSynced: Bool)? {
        guard let cache else { return nil }
        guard let lyrics = try? await cache.getLyrics(trackId) else { return nil }

        if lyrics.isSynced {
            let lines = parseLRC(lyrics.lyrics)
            return (lines, true)
        } else {
            let lines = lyrics.lyrics.components(separatedBy: .newlines)
                .filter { !$0.isEmpty }
                .map { LyricsLine(timestamp: 0, text: $0) }
            return (lines, false)
        }
    }

    private func parseLRC(_ text: String) -> [LyricsLine] {
        var result: [LyricsLine] = []
        let pattern = /\[(\d{2}):(\d{2})(?:\.(\d{2,3}))?\](.*)/

        for line in text.components(separatedBy: .newlines) {
            guard let match = line.firstMatch(of: pattern) else { continue }
            let minutes = Double(match.1) ?? 0
            let seconds = Double(match.2) ?? 0
            let millis: Double
            if let ms = match.3 {
                millis = (Double(ms) ?? 0) / (ms.count == 2 ? 100 : 1000)
            } else {
                millis = 0
            }
            let timestamp = minutes * 60 + seconds + millis
            let text = String(match.4).trimmingCharacters(in: .whitespaces)
            if !text.isEmpty {
                result.append(LyricsLine(timestamp: timestamp, text: text))
            }
        }
        return result.sorted { $0.timestamp < $1.timestamp }
    }
}
