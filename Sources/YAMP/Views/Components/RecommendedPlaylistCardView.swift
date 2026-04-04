import SwiftUI
import ZvukMusic

struct RecommendedPlaylistCardView: View {
    let playlist: RecommendationPlaylist

    @Environment(AppState.self) private var appState
    @Environment(PlayerService.self) private var playerService
    @Environment(CacheService.self) private var cacheService
    @State private var isHovered = false

    private var isPlayingThisPlaylist: Bool {
        let idx = playerService.queueIndex
        guard idx >= 0, idx < playerService.queue.count else { return false }
        return playerService.queue[idx].context == .playlist(id: playlist.id)
    }

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                coverOverlay(size: geo.size.width)
            }
            .aspectRatio(1, contentMode: .fit)

            VStack(spacing: 2) {
                Text(playlist.title)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)

                Text("Плейлист")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .multilineTextAlignment(.center)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            appState.selectedDestination = .playlist(id: playlist.id)
        }
    }

    private func coverOverlay(size: CGFloat) -> some View {
        ZStack {
            GeneratedCoverView(seed: playlist.id)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            if isHovered || (isPlayingThisPlaylist && playerService.isPlaying) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.black.opacity(0.45))
                    .frame(width: size, height: size)

                Image(systemName: isPlayingThisPlaylist && playerService.isPlaying
                      ? "pause.fill"
                      : "play.fill")
                    .font(size > 100 ? .title2 : .title3)
                    .foregroundStyle(.white)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .frame(width: size, height: size)
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            if isPlayingThisPlaylist {
                playerService.togglePlayPause()
            } else {
                Task { await playPlaylist() }
            }
        }
    }

    private func playPlaylist() async {
        do {
            guard let full = try await cacheService.getPlaylist(playlist.id),
                  !full.tracks.isEmpty else { return }
            playerService.playQueue(full.tracks, context: .playlist(id: playlist.id))
        } catch {
            // Сетевые ошибки логируются транспортным слоем клиента в LogStore
        }
    }
}
