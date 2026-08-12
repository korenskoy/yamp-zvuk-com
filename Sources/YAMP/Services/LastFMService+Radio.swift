import Foundation

// Скробблинг эфира. От трекового отличается тем, что у радио нет ни ID трека,
// ни надёжной длительности: есть только строки «исполнитель» и «название»,
// которые станция обновляет по ходу вещания.
extension LastFMService {
    /// Сколько запись должна продержаться в эфире, чтобы уйти в Last.fm.
    ///
    /// Это же и основной фильтр рекламы: ролики и джинглы короче минуты и до
    /// порога просто не доживают, поэтому распознавать их отдельно не нужно.
    private static let radioScrobbleThreshold: Duration = .seconds(60)

    /// В эфире сменилась запись.
    func radioTrackChanged(_ nowPlaying: RadioNowPlaying, stationName: String) {
        cancelRadioScrobble()

        guard isConnected,
              let artist = nowPlaying.artist?.trimmingCharacters(in: .whitespaces), !artist.isEmpty,
              let title = nowPlaying.title?.trimmingCharacters(in: .whitespaces), !title.isEmpty,
              // Станция, назвавшая исполнителем саму себя, объявляет эфир, а не играет музыку.
              artist.localizedCaseInsensitiveCompare(stationName) != .orderedSame
        else { return }

        scrobbleState = .idle
        let duration = UInt(nowPlaying.runtime ?? 0)
        sendNowPlaying(artist: artist, title: title, album: nowPlaying.album, duration: duration)

        radioScrobbleTask = Task { [weak self] in
            try? await Task.sleep(for: Self.radioScrobbleThreshold)
            guard !Task.isCancelled, let self else { return }
            self.sendScrobble(artist: artist, title: title, album: nowPlaying.album, duration: duration)
        }
    }

    /// Эфир прекратился — отложенный скроббл больше не актуален.
    func cancelRadioScrobble() {
        radioScrobbleTask?.cancel()
        radioScrobbleTask = nil
    }
}
