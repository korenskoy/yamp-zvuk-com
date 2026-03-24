import Foundation
import ZvukMusic

@MainActor
@Observable
final class LyricsViewModel {
    var lines: [LyricsLine] = []
    var isSynced = false
    var isLoading = false
    var currentLineIndex: Int = 0

    private let lyricsService = LyricsService()
    private var loadedTrackId: String?

    func loadIfNeeded(trackId: String?, cache: CacheService?) async {
        guard let trackId, trackId != loadedTrackId else { return }
        loadedTrackId = trackId
        lines = []
        isSynced = false
        isLoading = true
        defer { isLoading = false }

        guard let result = await lyricsService.fetchLyrics(trackId: trackId, cache: cache) else {
            return
        }
        lines = result.lines
        isSynced = result.isSynced
    }

    func updateCurrentLine(at time: Double) {
        guard isSynced, !lines.isEmpty else { return }
        var index = 0
        for (i, line) in lines.enumerated() {
            if line.timestamp <= time {
                index = i
            } else {
                break
            }
        }
        currentLineIndex = index
    }

    var hasLyrics: Bool {
        !lines.isEmpty
    }
}
