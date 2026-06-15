import AppKit
import AVFoundation
import Foundation
import MediaPlayer
import ZvukMusic

@MainActor
@Observable
final class PlayerService {
    enum RepeatMode: Int, Codable { case off, one, all }

    private(set) var currentTrack: SimpleTrack?
    private(set) var queue: [QueueItem] = []
    private(set) var queueIndex: Int = 0
    private(set) var isPlaying = false
    private(set) var currentTime: Double = 0
    private(set) var duration: Double = 0
    var isShuffled = false
    var repeatMode: RepeatMode = .off

    private var originalQueue: [QueueItem] = []

    var volume: Double = 0.7 {
        didSet {
            player.volume = Float(volume)
            appSettings?.volume = volume
        }
    }

    private let player = AVPlayer()
    private var timeObserver: Any?
    private var itemObserver: NSKeyValueObservation?
    private var statusObserver: NSKeyValueObservation?
    private var endObserver: (any NSObjectProtocol)?

    /// Поколение загрузки: каждый новый `loadAndPlay` инкрементирует счётчик,
    /// а результат применяется только если поколение не устарело (защита от гонки быстрых next/prev).
    private var loadGeneration = 0

    @ObservationIgnored
    private weak var appState: AppState?

    @ObservationIgnored
    private var appSettings: AppSettings?

    @ObservationIgnored
    private weak var cacheService: CacheService?

    @ObservationIgnored
    private weak var historyStore: ListeningHistoryStore?

    @ObservationIgnored
    private weak var lastFMService: LastFMService?

    @ObservationIgnored
    private weak var logStore: LogStore?

    init() {
        player.volume = Float(volume)
        setupTimeObserver()
        setupRemoteCommands()
    }

    func configure(appState: AppState, settings: AppSettings, cache: CacheService, history: ListeningHistoryStore, lastFM: LastFMService, logStore: LogStore) {
        self.appState = appState
        self.appSettings = settings
        self.cacheService = cache
        self.historyStore = history
        self.lastFMService = lastFM
        self.logStore = logStore
        self.volume = settings.volume
        restoreState()
    }

    // MARK: - Playback Controls

    func play(track: SimpleTrack, context: PlaybackContext) {
        let item = QueueItem(track: track, context: context)
        queue = [item]
        originalQueue = [item]
        queueIndex = 0
        Task { await loadAndPlay(track) }
    }

    func playQueue(_ tracks: [SimpleTrack], context: PlaybackContext, startAt index: Int = 0) {
        guard !tracks.isEmpty else { return }
        let items = tracks.map { QueueItem(track: $0, context: context) }
        originalQueue = items
        if isShuffled {
            let current = items[min(index, items.count - 1)]
            var shuffled = items
            shuffled.remove(at: min(index, items.count - 1))
            shuffled.shuffle()
            shuffled.insert(current, at: 0)
            queue = shuffled
            queueIndex = 0
        } else {
            queue = items
            queueIndex = min(index, queue.count - 1)
        }
        guard let track = queue[safe: queueIndex]?.track else { return }
        Task { await loadAndPlay(track) }
    }

    /// При включённом shuffle новые треки идут в конец как есть — тот же компромисс, что в Wave-auto-continue.
    func appendToQueue(_ tracks: [SimpleTrack], context: PlaybackContext) {
        guard !tracks.isEmpty else { return }
        let items = tracks.map { QueueItem(track: $0, context: context) }
        queue.append(contentsOf: items)
        originalQueue.append(contentsOf: items)
        saveState()
    }

    func resume() {
        player.play()
        isPlaying = true
        updateNowPlayingPlaybackState()
    }

    func pause() {
        player.pause()
        isPlaying = false
        updateNowPlayingPlaybackState()
    }

    func togglePlayPause() {
        if isPlaying { pause() } else { resume() }
    }

    func next() {
        if queueIndex + 1 < queue.count {
            queueIndex += 1
        } else if repeatMode == .all, !queue.isEmpty {
            queueIndex = 0
        } else {
            return
        }
        guard let item = queue[safe: queueIndex] else {
            isPlaying = false
            return
        }
        Task { await loadAndPlay(item.track) }
    }

    func toggleShuffle() {
        isShuffled.toggle()
        guard let current = queue[safe: queueIndex] else { return }
        if isShuffled {
            originalQueue = queue
            var remaining = queue
            remaining.remove(at: queueIndex)
            remaining.shuffle()
            remaining.insert(current, at: 0)
            queue = remaining
            queueIndex = 0
        } else {
            if let idx = originalQueue.firstIndex(where: { $0.id == current.id }) {
                queueIndex = idx
            }
            queue = originalQueue
        }
    }

    func cycleRepeatMode() {
        switch repeatMode {
        case .off: repeatMode = .one
        case .one: repeatMode = .all
        case .all: repeatMode = .off
        }
    }

    func previous() {
        if currentTime > 3 {
            seek(to: 0)
            return
        }
        guard queueIndex > 0 else { return }
        queueIndex -= 1
        Task { await loadAndPlay(queue[queueIndex].track) }
    }

    func adjustVolume(by delta: Double) {
        volume = min(1.0, max(0.0, volume + delta))
    }

    func seek(to time: Double) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player.seek(to: cmTime)
        currentTime = time
        updateNowPlayingInfo()
    }

    var hasNext: Bool { queueIndex + 1 < queue.count || repeatMode == .all }
    var hasPrevious: Bool { queueIndex > 0 || currentTime > 3 }

    // MARK: - Stream Resolution

    private func loadAndPlay(_ track: SimpleTrack) async {
        loadGeneration += 1
        let generation = loadGeneration

        currentTrack = track
        currentTime = 0
        duration = Double(track.duration)
        historyStore?.record(track)
        if appSettings?.isScrobblingEnabled ?? false {
            lastFMService?.updateNowPlaying(track: track)
        }
        saveState()

        let quality = appSettings?.preferredQuality ?? .high

        do {
            guard let cache = cacheService else {
                logStore?.appendLocal(operation: "loadAndPlay \(track.id)", error: "CacheService недоступен")
                return
            }
            let urlString = try await cache.resolveStreamURL(trackId: track.id, quality: quality)
            // Пользователь мог переключить трек, пока резолвился URL — не подменяем актуальный плейбэк.
            guard generation == loadGeneration else { return }
            guard let url = URL(string: urlString) else {
                logStore?.appendLocal(operation: "loadAndPlay \(track.id)", error: "Некорректный URL потока: \(urlString)")
                return
            }

            let item = AVPlayerItem(url: url)
            observePlayerItem(item)
            player.replaceCurrentItem(with: item)
            player.play()
            isPlaying = true
            updateNowPlayingInfo()
        } catch {
            guard generation == loadGeneration else { return }
            isPlaying = false
            logStore?.appendLocal(operation: "loadAndPlay \(track.id)", error: "\(error)")
        }
    }

    /// Останавливает воспроизведение и полностью очищает очередь/сохранённое состояние (при logout).
    func stopAndClear() {
        loadGeneration += 1
        player.pause()
        player.replaceCurrentItem(with: nil)
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        statusObserver?.invalidate()
        statusObserver = nil
        isPlaying = false
        currentTrack = nil
        queue = []
        originalQueue = []
        queueIndex = 0
        currentTime = 0
        duration = 0
        UserDefaults.standard.removeObject(forKey: Self.stateKey)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    /// Удаляет текущий («не нравится») трек из очереди и продолжает со следующего.
    func dislikeCurrentAndAdvance(trackId: String) {
        // Трек мог смениться, пока выполнялся hideTrack — тогда просто убираем его из очередей.
        guard queue.indices.contains(queueIndex), queue[queueIndex].track.id == trackId else {
            queue.removeAll { $0.track.id == trackId }
            originalQueue.removeAll { $0.track.id == trackId }
            if queueIndex >= queue.count { queueIndex = max(0, queue.count - 1) }
            saveState()
            return
        }

        queue.remove(at: queueIndex)
        originalQueue.removeAll { $0.track.id == trackId }

        guard !queue.isEmpty else {
            stopAndClear()
            return
        }
        if queueIndex >= queue.count {
            guard repeatMode == .all else {
                // Был последним — останавливаемся в конце.
                queueIndex = queue.count - 1
                player.pause()
                isPlaying = false
                currentTime = 0
                updateNowPlayingPlaybackState()
                saveState()
                return
            }
            queueIndex = 0
        }
        saveState()
        Task { await loadAndPlay(queue[queueIndex].track) }
    }

    // MARK: - Time Observer

    private func setupTimeObserver() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                guard let self else { return }
                self.currentTime = time.seconds.isFinite ? time.seconds : 0
                if self.appSettings?.isScrobblingEnabled ?? false,
                   let track = self.currentTrack {
                    self.lastFMService?.checkAndScrobble(
                        track: track,
                        currentTime: self.currentTime,
                        duration: self.duration
                    )
                }
            }
        }
    }

    private func observePlayerItem(_ item: AVPlayerItem) {
        statusObserver?.invalidate()
        itemObserver?.invalidate()

        statusObserver = item.observe(\.status) { [weak self] item, _ in
            Task { @MainActor in
                guard let self else { return }
                if item.status == .readyToPlay {
                    let dur = item.duration.seconds
                    if dur.isFinite { self.duration = dur }
                }
            }
        }

        // block-based observer не снимается через removeObserver(self,...) — храним токен и снимаем по нему.
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleTrackEnd()
            }
        }
    }

    private func handleTrackEnd() {
        switch repeatMode {
        case .one:
            seek(to: 0)
            resume()
        case .all:
            next()
        case .off:
            if queueIndex + 1 < queue.count {
                next()
            } else if let waveParams = currentWaveParams {
                Task { await loadMoreWave(params: waveParams) }
            } else {
                isPlaying = false
                currentTime = 0
                updateNowPlayingPlaybackState()
            }
        }
    }

    // MARK: - Wave Auto-Continue

    private var currentWaveParams: PlaybackContext.WaveParams? {
        guard let item = queue[safe: queueIndex],
              case .wave(let params) = item.context else { return nil }
        return params
    }

    private func loadMoreWave(params: PlaybackContext.WaveParams) async {
        guard let client = appState?.client else { return }
        do {
            let tracks = try await params.fetchTracks(client: client)
            guard !tracks.isEmpty else {
                isPlaying = false
                currentTime = 0
                updateNowPlayingPlaybackState()
                return
            }
            appendToQueue(tracks, context: .wave(params: params))
            next()
        } catch {
            isPlaying = false
            currentTime = 0
            updateNowPlayingPlaybackState()
            logStore?.appendLocal(operation: "loadMoreWave", error: "\(error)")
        }
    }

    // MARK: - Now Playing

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.resume() }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlayPause() }
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.next() }
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.previous() }
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor in self?.seek(to: event.positionTime) }
            return .success
        }
    }

    private func updateNowPlayingInfo() {
        guard let track = currentTrack else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artistsString,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
        ]
        if let releaseName = track.release?.title {
            info[MPMediaItemPropertyAlbumTitle] = releaseName
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info

        // Load artwork asynchronously via image cache
        if let src = track.release?.image?.getURL(width: 600, height: 600),
           let url = URL(string: src) {
            let trackId = track.id
            Task.detached {
                guard let nsImage = await ImageCacheService.shared.image(for: url) else { return }
                let artwork = MPMediaItemArtwork(boundsSize: nsImage.size) { _ in nsImage }
                await MainActor.run {
                    guard self.currentTrack?.id == trackId else { return }
                    var current = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                    current[MPMediaItemPropertyArtwork] = artwork
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = current
                }
            }
        }
    }

    private func updateNowPlayingPlaybackState() {
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    // MARK: - State Persistence

    private struct SavedState: Codable {
        let queue: [QueueItem]
        let queueIndex: Int
        let isShuffled: Bool
        let repeatMode: RepeatMode
    }

    private static let stateKey = "playerState"

    func saveState() {
        let state = SavedState(
            queue: queue,
            queueIndex: queueIndex,
            isShuffled: isShuffled,
            repeatMode: repeatMode
        )
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: Self.stateKey)
    }

    private func restoreState() {
        guard let data = UserDefaults.standard.data(forKey: Self.stateKey),
              let state = try? JSONDecoder().decode(SavedState.self, from: data),
              !state.queue.isEmpty
        else { return }

        queue = state.queue
        queueIndex = min(state.queueIndex, queue.count - 1)
        isShuffled = state.isShuffled
        repeatMode = state.repeatMode
        currentTrack = queue[safe: queueIndex]?.track
        if let track = currentTrack {
            duration = Double(track.duration)
            updateNowPlayingInfo()
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
