import Foundation
import MediaPlayer
import ZvukMusic

// Интернет-радио живёт в том же AVPlayer, что и музыка: громкость, медиа-клавиши
// и MPNowPlayingInfoCenter — общие для приложения ресурсы, и второй плеер пришлось
// бы с этим синхронизировать. Очередь при переходе в эфир намеренно сохраняется,
// чтобы музыка продолжилась там же, где её прервали.
extension PlayerService {

    /// Включить радиостанцию.
    func playStation(_ station: RadioStation) {
        guard let url = station.streamURL else {
            logStore?.appendLocal(
                operation: "playStation \(station.id)",
                error: "У станции «\(station.name)» нет ссылки на поток"
            )
            return
        }

        currentStation = station
        onAir = nil

        attachStream(url) { [weak self] in
            self?.handleStreamFailure(station: station)
        }

        setTrackCommandsEnabled(false)
        updateNowPlayingForRadio()
        startMetadataPolling(for: station)
    }

    /// Выйти из режима радио. Звук не трогаем: вызывающая сторона либо ставит
    /// свой элемент, либо останавливает плеер сама.
    func stopRadio() {
        guard currentStation != nil else { return }
        currentStation = nil
        onAir = nil
        metadataPoller.stop()
        lastFMService?.cancelRadioScrobble()
        detachStreamObserver()
        setTrackCommandsEnabled(true)
    }

    private func handleStreamFailure(station: RadioStation) {
        guard currentStation?.id == station.id else { return }
        markPlaybackStopped()
        logStore?.appendLocal(
            operation: "radio \(station.id)",
            error: "Поток станции «\(station.name)» прервался"
        )
    }

    // MARK: - Метаданные эфира

    private func startMetadataPolling(for station: RadioStation) {
        guard let source = station.metaDataUrl, let url = URL(string: source) else { return }
        metadataPoller.start(url: url) { [weak self] nowPlaying in
            self?.handleOnAirChange(nowPlaying, station: station)
        }
    }

    private func handleOnAirChange(_ nowPlaying: RadioNowPlaying, station: RadioStation) {
        guard currentStation?.id == station.id else { return }
        onAir = nowPlaying
        updateNowPlayingForRadio()

        if appSettings?.isScrobblingEnabled ?? false {
            lastFMService?.radioTrackChanged(nowPlaying, stationName: station.name)
        }
    }

    // MARK: - Now Playing

    /// В эфире нет длительности, поэтому вместо неё системе сообщается флаг
    /// живого потока — иначе Control Center рисует прогресс от нуля.
    private func updateNowPlayingForRadio() {
        guard let station = currentStation else { return }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: onAir?.title ?? station.name,
            MPMediaItemPropertyAlbumTitle: station.name,
            MPNowPlayingInfoPropertyIsLiveStream: true,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
        ]
        if let artist = onAir?.artist, !artist.isEmpty {
            info[MPMediaItemPropertyArtist] = artist
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info

        loadRadioArtwork(station: station)
    }

    private func loadRadioArtwork(station: RadioStation) {
        let source = onAir?.coverURL ?? station.logoColored?.png
        guard let source, let url = URL(string: source) else { return }
        let stationId = station.id

        Task.detached {
            guard let nsImage = await ImageCacheService.shared.image(for: url) else { return }
            let artwork = MPMediaItemArtwork(boundsSize: nsImage.size) { _ in nsImage }
            await MainActor.run {
                guard self.currentStation?.id == stationId else { return }
                var current = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                current[MPMediaItemPropertyArtwork] = artwork
                MPNowPlayingInfoCenter.default().nowPlayingInfo = current
            }
        }
    }

    /// Перемотка и переходы между треками к эфиру неприменимы — на время радио
    /// соответствующие системные команды выключаются.
    private func setTrackCommandsEnabled(_ enabled: Bool) {
        let center = MPRemoteCommandCenter.shared()
        center.nextTrackCommand.isEnabled = enabled
        center.previousTrackCommand.isEnabled = enabled
        center.changePlaybackPositionCommand.isEnabled = enabled
    }
}
