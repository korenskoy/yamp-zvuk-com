import SwiftUI
import ZvukMusic

private struct GlassCircleButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: .circle)
        } else {
            content
        }
    }
}

struct PlayerControlsView: View {
    @Environment(AppState.self) private var appState
    @Environment(PlayerService.self) private var playerService
    @Environment(CollectionService.self) private var collectionService
    @State private var appError: AppError?

    var body: some View {
        HStack(spacing: 16) {
            // Dislike
            dislikeButton

            // Shuffle toggle
            shuffleButton

            // Previous
            Button { playerService.previous() } label: {
                Image(systemName: "backward.fill")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .disabled(!playerService.hasPrevious)

            // Play / Pause
            Button { playerService.togglePlayPause() } label: {
                Image(systemName: playerService.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 32))
            }
            .buttonStyle(.plain)
            .disabled(playerService.currentTrack == nil)
            .modifier(GlassCircleButtonModifier())

            // Next
            Button { playerService.next() } label: {
                Image(systemName: "forward.fill")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .disabled(!playerService.hasNext)

            // Repeat
            repeatButton

            // Like
            likeButton
        }
        .errorAlert($appError)
    }

    // MARK: - Dislike

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
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .disabled(playerService.currentTrack == nil)
        .help("Не нравится")
    }

    // MARK: - Shuffle

    private var shuffleButton: some View {
        Button { playerService.toggleShuffle() } label: {
            Image(systemName: "shuffle")
                .font(.callout)
                .foregroundStyle(playerService.isShuffled ? .primary : .secondary)
        }
        .buttonStyle(.plain)
        .help(playerService.isShuffled ? "Выключить перемешивание" : "Перемешать")
    }

    // MARK: - Repeat

    private var repeatButton: some View {
        Button { playerService.cycleRepeatMode() } label: {
            Image(systemName: repeatIcon)
                .font(.callout)
                .foregroundStyle(playerService.repeatMode == .off ? .secondary : .primary)
        }
        .buttonStyle(.plain)
        .help(repeatHelp)
    }

    private var repeatIcon: String {
        switch playerService.repeatMode {
        case .off: "repeat"
        case .one: "repeat.1"
        case .all: "repeat"
        }
    }

    private var repeatHelp: String {
        switch playerService.repeatMode {
        case .off: "Повтор выключен"
        case .one: "Повтор одного трека"
        case .all: "Повтор всех"
        }
    }

    // MARK: - Like

    private var likeButton: some View {
        Button {
            guard let track = playerService.currentTrack else { return }
            Task {
                await collectionService.toggleTrackLike(track, client: appState.client)
            }
        } label: {
            let isLiked = playerService.currentTrack.map { collectionService.isTrackLiked($0.id) } ?? false
            Image(systemName: isLiked ? "heart.fill" : "heart")
                .font(.callout)
                .foregroundStyle(isLiked ? .red : .secondary)
        }
        .buttonStyle(.plain)
        .disabled(playerService.currentTrack == nil)
        .help("В любимые")
    }
}
