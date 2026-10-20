import SwiftUI
import ZvukMusic

struct TrackRowView<Trailing: View>: View {
    let track: SimpleTrack
    let trailing: Trailing
    let onPlay: () -> Void
    /// Задан только там, где трек показан внутри плейлиста.
    var onRemoveFromPlaylist: (() -> Void)?
    @Environment(PlayerService.self) private var playerService
    @Environment(CollectionService.self) private var collectionService
    @Environment(AppState.self) private var appState
    @Environment(LogStore.self) private var logStore

    init(
        track: SimpleTrack,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() },
        onPlay: @escaping () -> Void,
        onRemoveFromPlaylist: (() -> Void)? = nil
    ) {
        self.track = track
        self.trailing = trailing()
        self.onPlay = onPlay
        self.onRemoveFromPlaylist = onRemoveFromPlaylist
    }

    private var isLiked: Bool {
        collectionService.isTrackLiked(track.id)
    }

    private var isPlaying: Bool {
        playerService.currentTrack?.id == track.id
    }

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                coverImage
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                if isPlaying {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.black.opacity(0.45))
                        .frame(width: 36, height: 36)

                    Image(systemName: playerService.isPlaying ? "speaker.wave.2.fill" : "play.fill")
                        .font(.caption)
                        .foregroundStyle(.white)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.callout)
                    .lineLimit(1)
                    .foregroundStyle(isPlaying ? Color.accentColor : Color.primary)

                HStack(spacing: 4) {
                    if track.explicit {
                        Image(systemName: "e.square.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    artistsText
                }
            }

            Spacer()

            trailing

            Text(track.durationString)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isPlaying ? Color.accentColor.opacity(0.12) : .clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onPlay()
        }
        .contextMenu {
            Button(isLiked ? "Убрать лайк" : "Нравится") {
                Task { await collectionService.toggleTrackLike(track, client: appState.client) }
            }

            addToPlaylistMenu

            Button("В конец очереди") {
                playerService.appendToQueue([track], context: .search)
            }

            Divider()

            if let artist = track.artists.first {
                Button("Перейти к артисту") {
                    appState.selectedDestination = .artist(id: artist.id)
                }
            }

            if let releaseId = track.release?.id {
                Button("Перейти к альбому") {
                    appState.selectedDestination = .release(id: releaseId)
                }
            }

            Button("Похожие треки") {
                Task {
                    guard let client = appState.client else { return }
                    do {
                        let related = try await client.getRelatedTracks(track.id, limit: 30)
                        guard !related.isEmpty else {
                            logStore.appendLocal(
                                operation: "getRelatedTracks \(track.id)",
                                error: "сервис не вернул похожих треков"
                            )
                            return
                        }
                        playerService.playQueue(related, context: .radioTrack(id: track.id))
                    } catch {
                        appState.appError = AppError.from(error)
                    }
                }
            }

            if let onRemoveFromPlaylist {
                Button("Убрать из плейлиста", role: .destructive, action: onRemoveFromPlaylist)
            }

            Divider()

            Button("Скопировать ссылку") {
                if let url = ShareService.url(for: .track(id: track.id)) {
                    ShareService.copyToPasteboard(url)
                }
            }
        }
        .task {
            await collectionService.loadUserPlaylistsIfNeeded()
        }
    }

    @ViewBuilder
    private var addToPlaylistMenu: some View {
        Menu("Добавить в плейлист") {
            if collectionService.userPlaylists.isEmpty {
                Text("Нет плейлистов")
            } else {
                ForEach(collectionService.userPlaylists, id: \.id) { playlist in
                    Button(playlist.title) {
                        Task {
                            await collectionService.addTrack(
                                track.id, toPlaylist: playlist.id, client: appState.client
                            )
                        }
                    }
                }
            }
        }
    }

    private var coverImage: some View {
        Group {
            if let imageURL = track.release?.image?.getURL(width: 72, height: 72),
               let url = URL(string: imageURL) {
                CachedAsyncImage(url: url) { image in
                    image
                } placeholder: {
                    placeholderView
                }
            } else {
                placeholderView
            }
        }
    }

    private var placeholderView: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(.quaternary)
            .overlay {
                Image(systemName: "music.note")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
    }

    private var artistsText: some View {
        Text(track.artistsString)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }
}
