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
        // Binary search: find last line whose timestamp <= time
        var low = 0
        var high = lines.count - 1
        var result = 0
        while low <= high {
            let mid = (low + high) / 2
            if lines[mid].timestamp <= time {
                result = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        currentLineIndex = result
    }

    var hasLyrics: Bool {
        !lines.isEmpty
    }
}
