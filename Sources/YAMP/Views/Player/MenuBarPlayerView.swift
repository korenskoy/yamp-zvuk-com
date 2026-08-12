import SwiftUI
import ZvukMusic

/// Компактный плеер в поповере строки меню. Отдельная `Scene`, поэтому environment
/// прокидывается явно из `MenuBarController` — окно приложения может быть закрыто.
struct MenuBarPlayerView: View {
    @Environment(PlayerService.self) private var playerService
    @Environment(CollectionService.self) private var collectionService
    @Environment(AppState.self) private var appState

    @State private var appError: AppError?
    /// Позиция во время перетаскивания: пока пользователь тянет, не дёргаем `seek` на каждый кадр.
    @State private var seekPosition: Double?

    var body: some View {
        VStack(spacing: 14) {
            if let station = playerService.currentStation {
                // У эфира одна-единственная кнопка, поэтому она стоит в строке со
                // станцией: отдельный ряд под ней был бы пустой полосой.
                stationInfo(station)
            } else if let track = playerService.currentTrack {
                trackInfo(track)
                progress
                controls
            } else {
                Text("Ничего не играет")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                controls
            }
        }
        .padding(16)
        .frame(width: 320)
        // В поповере кнопки ловят фокус и обводятся кольцом — в мини-плеере оно только мешает.
        .focusEffectDisabled()
        .errorAlert($appError)
    }

    // MARK: - Station info

    /// У эфира нет позиции и длительности, поэтому вместо прогресса —
    /// только логотип, что сейчас звучит, и название станции.
    private func stationInfo(_ station: RadioStation) -> some View {
        HStack(spacing: 12) {
            RadioStationInfo(station: station, logoSize: 48, titleLineLimit: 2)
            playPauseButton
        }
    }

    // MARK: - Track info

    private func trackInfo(_ track: SimpleTrack) -> some View {
        HStack(spacing: 12) {
            cover(track)

            VStack(alignment: .leading, spacing: 3) {
                Text(track.title)
                    .font(.headline)
                    .lineLimit(2)

                Text(subtitle(track))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
    }

    private func subtitle(_ track: SimpleTrack) -> String {
        guard let release = track.release?.title, !release.isEmpty else { return track.artistsString }
        return "\(track.artistsString) — \(release)"
    }

    private func cover(_ track: SimpleTrack) -> some View {
        Group {
            if let imageURL = track.release?.image?.getURL(width: 128, height: 128),
               let url = URL(string: imageURL) {
                CachedAsyncImage(url: url) { image in
                    image
                } placeholder: {
                    coverPlaceholder
                }
            } else {
                coverPlaceholder
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(radius: 4, y: 2)
    }

    private var coverPlaceholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(.quaternary)
            .overlay {
                Image(systemName: "music.note")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
    }

    // MARK: - Progress

    /// Своя полоса вместо `Slider`: системный слайдер оставляет кольцо фокуса в точке клика,
    /// и оно не едет за значением при обновлении времени.
    private var progress: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let total = max(playerService.duration, 1)
                let value = seekPosition ?? playerService.currentTime
                let ratio = min(max(value / total, 0), 1)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.quaternary)
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: geo.size.width * ratio)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            let position = gesture.location.x / geo.size.width
                            seekPosition = min(max(position, 0), 1) * total
                        }
                        .onEnded { _ in
                            if let position = seekPosition { playerService.seek(to: position) }
                            seekPosition = nil
                        }
                )
            }
            .frame(height: 4)

            HStack {
                Text((seekPosition ?? playerService.currentTime).formattedTime)
                Spacer()
                Text(playerService.duration.formattedTime)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
    }

    // MARK: - Controls

    /// В эфире остаётся только пауза: переходов между треками у радио нет, а лайк
    /// и «не нравится» подействовали бы на трек из сохранённой очереди — тот, что
    /// сейчас не играет.
    private var controls: some View {
        HStack(spacing: 20) {
            if !isRadio {
                dislikeButton
                previousButton
            }

            playPauseButton

            if !isRadio {
                nextButton
                likeButton
            }
        }
    }

    private var isRadio: Bool { playerService.currentStation != nil }

    private var previousButton: some View {
        Button { playerService.previous() } label: {
            Image(systemName: "backward.fill")
                .font(.title3)
        }
        .buttonStyle(.plain)
        .disabled(!playerService.hasPrevious)
    }

    private var playPauseButton: some View {
        Button { playerService.togglePlayPause() } label: {
            Image(systemName: playerService.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                .font(.system(size: 34))
        }
        .buttonStyle(.plain)
        .disabled(playerService.currentTrack == nil && playerService.currentStation == nil)
    }

    private var nextButton: some View {
        Button { playerService.next() } label: {
            Image(systemName: "forward.fill")
                .font(.title3)
        }
        .buttonStyle(.plain)
        .disabled(!playerService.hasNext)
    }

    private var dislikeButton: some View {
        Button {
            guard let track = playerService.currentTrack else { return }
            Task {
                do {
                    _ = try await appState.client?.hideTrack(track.id)
                } catch {
                    appError = AppError.from(error)
                }
                playerService.dislikeCurrentAndAdvance(trackId: track.id)
            }
        } label: {
            Image(systemName: "hand.thumbsdown")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .disabled(playerService.currentTrack == nil)
        .help("Не нравится")
    }

    private var likeButton: some View {
        Button {
            guard let track = playerService.currentTrack else { return }
            Task {
                await collectionService.toggleTrackLike(track, client: appState.client)
            }
        } label: {
            let isLiked = playerService.currentTrack.map { collectionService.isTrackLiked($0.id) } ?? false
            Image(systemName: isLiked ? "heart.fill" : "heart")
                .font(.title3)
                .foregroundStyle(isLiked ? .red : .secondary)
        }
        .buttonStyle(.plain)
        .disabled(playerService.currentTrack == nil)
        .help("В любимые")
    }
}
