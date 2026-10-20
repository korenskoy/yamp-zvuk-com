import SwiftUI
import ZvukMusic

struct PlaylistView: View {
    let playlistId: String
    @Environment(AppState.self) private var appState
    @Environment(PlayerService.self) private var playerService
    @Environment(CacheService.self) private var cacheService
    @Environment(CollectionService.self) private var collectionService
    @Environment(LogStore.self) private var logStore
    @State private var viewModel: PlaylistViewModel
    @State private var showRenameSheet = false
    @State private var newName = ""

    init(playlistId: String) {
        self.playlistId = playlistId
        self._viewModel = State(initialValue: PlaylistViewModel(playlistId: playlistId))
    }

    var body: some View {
        ZStack {
            if viewModel.isLoading {
                ProgressView()
            } else if let playlist = viewModel.playlist {
                playlistContent(playlist)
            } else {
                ContentUnavailableView(
                    "Не удалось загрузить",
                    systemImage: "exclamationmark.triangle"
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .errorAlert($viewModel.appError)
        .task(id: playlistId) {
            viewModel = PlaylistViewModel(playlistId: playlistId)
            await viewModel.load(cache: cacheService)
        }
        .sheet(isPresented: $showRenameSheet) {
            renameSheet
        }
    }

    private func isOwn(_ playlist: Playlist) -> Bool {
        appState.isOwnedByCurrentUser(userId: playlist.userId)
    }

    private func playlistContent(_ playlist: Playlist) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PlaylistHeaderView(
                    playlist: playlist,
                    isOwnPlaylist: appState.isOwnedByCurrentUser(userId: playlist.userId),
                    isLiked: collectionService.isPlaylistLiked(playlist.id),
                    onPlay: {
                        if !playlist.tracks.isEmpty {
                            playerService.playQueue(
                                playlist.tracks,
                                context: .playlist(id: playlist.id)
                            )
                        }
                    },
                    onToggleLike: {
                        Task {
                            await collectionService.togglePlaylistLike(playlist.id, client: appState.client)
                        }
                    },
                    onRename: {
                        newName = playlist.title
                        showRenameSheet = true
                    },
                    onDelete: {
                        Task {
                            let deleted = await viewModel.deletePlaylist(
                                client: appState.client, cache: cacheService, collection: collectionService
                            )
                            if deleted {
                                appState.selectedDestination = .collection
                            }
                        }
                    }
                )

                if playlist.tracks.isEmpty {
                    ContentUnavailableView(
                        "Плейлист пуст",
                        systemImage: "music.note.list",
                        description: Text("Добавьте треки в плейлист")
                    )
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(playlist.tracks.enumerated()), id: \.element.id) { index, track in
                            HStack(spacing: 8) {
                                Text("\(index + 1)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .frame(width: 24, alignment: .trailing)

                                TrackRowView(
                                    track: track,
                                    onPlay: {
                                        playerService.playQueue(
                                            playlist.tracks,
                                            context: .playlist(id: playlist.id),
                                            startAt: index
                                        )
                                    },
                                    onRemoveFromPlaylist: isOwn(playlist) ? {
                                        Task {
                                            await viewModel.removeTrack(
                                                track.id, client: appState.client,
                                                cache: cacheService, logStore: logStore
                                            )
                                        }
                                    } : nil
                                )
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    private var renameSheet: some View {
        VStack(spacing: 16) {
            Text("Переименовать плейлист")
                .font(.headline)

            TextField("Название", text: $newName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)

            HStack {
                Button("Отмена") {
                    showRenameSheet = false
                }
                .buttonStyle(.bordered)

                Button("Сохранить") {
                    Task {
                        _ = await viewModel.renamePlaylist(newName, client: appState.client, cache: cacheService, collection: collectionService)
                        showRenameSheet = false
                    }
                }
                .buttonStyle(.accent)
                .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
    }
}
