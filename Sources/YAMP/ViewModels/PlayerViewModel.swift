import Foundation
import ZvukMusic

@MainActor
@Observable
final class PlayerViewModel {
    let playerService: PlayerService

    init(playerService: PlayerService) {
        self.playerService = playerService
    }

    var currentTrack: SimpleTrack? { playerService.currentTrack }
    var isPlaying: Bool { playerService.isPlaying }
    var currentTime: Double { playerService.currentTime }
    var duration: Double { playerService.duration }
    var hasNext: Bool { playerService.hasNext }
    var hasPrevious: Bool { playerService.hasPrevious }

    var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }

    var currentTimeString: String {
        formatTime(currentTime)
    }

    var durationString: String {
        formatTime(duration)
    }

    var coverURL: String {
        guard let release = currentTrack?.release else { return "" }
        return release.image?.getURL(width: 300, height: 300) ?? ""
    }

    func togglePlayPause() {
        playerService.togglePlayPause()
    }

    func next() {
        playerService.next()
    }

    func previous() {
        playerService.previous()
    }

    func seek(to time: Double) {
        playerService.seek(to: time)
    }

    private func formatTime(_ time: Double) -> String {
        guard time.isFinite && time >= 0 else { return "0:00" }
        let total = Int(time)
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
