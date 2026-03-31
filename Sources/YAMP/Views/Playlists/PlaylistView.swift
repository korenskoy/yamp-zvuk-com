import SwiftUI
import ZvukMusic

struct PlaylistView: View {
    let playlistId: String
    @Environment(AppState.self) private var appState
    @Environment(PlayerService.self) private var playerService
    @Environment(CacheService.self) private var cacheService
    @Environment(CollectionService.self) private var collectionService
    @State private var viewModel: PlaylistViewModel
    @State private var showRenameSheet = false
    @State private var showCover = false
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

    private func playlistContent(_ playlist: Playlist) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                playlistHeader(playlist)

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

                                TrackRowView(track: track) {
                                    playerService.playQueue(
                                        playlist.tracks,
                                        context: .playlist(id: playlist.id),
                                        startAt: index
                                    )
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    private func playlistHeader(_ playlist: Playlist) -> some View {
        HStack(alignment: .top, spacing: 20) {
            coverImage(playlist)
                .frame(width: 160, height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(radius: 8, y: 4)
                .onTapGesture {
                    if playlist.image != nil { showCover = true }
                }
                .sheet(isPresented: $showCover) {
                    CoverSheetView(
                        imageURL: playlist.image?.getURL(width: 600, height: 600),
                        title: playlist.title,
                        subtitle: playlistSubtitle(playlist)
                    )
                }

            VStack(alignment: .leading, spacing: 8) {
                Text(playlist.title)
                    .font(.title.weight(.bold))

                Text(playlistSubtitle(playlist))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let desc = playlist.description, !desc.isEmpty {
                    Text(desc)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                playlistActions(playlist)
            }

            Spacer()
        }
    }

    private func coverImage(_ playlist: Playlist) -> some View {
        Group {
            if let imageURL = playlist.image?.getURL(width: 400, height: 400),
               let url = URL(string: imageURL) {
                CachedAsyncImage(url: url) { image in
                    image.scaledToFill()
                } placeholder: {
                    placeholderView
                }
            } else {
                placeholderView
            }
        }
    }

    private var placeholderView: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(.quaternary)
            .overlay {
                Image(systemName: "music.note.list")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
            }
    }

    private func playlistActions(_ playlist: Playlist) -> some View {
        HStack(spacing: 12) {
            Button {
                if !playlist.tracks.isEmpty {
                    playerService.playQueue(
                        playlist.tracks,
                        context: .playlist(id: playlist.id)
                    )
                }
            } label: {
                Label("Воспроизвести", systemImage: "play.fill")
            }
            .buttonStyle(.accent)
            .controlSize(.large)
            .disabled(playlist.tracks.isEmpty)

            if !isOwnPlaylist(playlist) {
                Button {
                    Task {
                        await collectionService.togglePlaylistLike(playlist.id, client: appState.client)
                    }
                } label: {
                    Image(systemName: collectionService.isPlaylistLiked(playlist.id)
                          ? "checkmark" : "plus")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(collectionService.isPlaylistLiked(playlist.id)
                      ? "Убрать из коллекции" : "Добавить в коллекцию")
            }

            if isOwnPlaylist(playlist) {
                Button {
                    newName = playlist.title
                    showRenameSheet = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Переименовать")

                Button {
                    Task {
                        let deleted = await viewModel.deletePlaylist(
                            client: appState.client, cache: cacheService, collection: collectionService
                        )
                        if deleted {
                            appState.selectedDestination = .collection
                        }
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Удалить")
            }
        }
    }

    private func isOwnPlaylist(_ playlist: Playlist) -> Bool {
        guard let userId = playlist.userId,
              let currentId = appState.currentUser?.id else { return false }
        return userId == String(currentId)
    }

    private func playlistSubtitle(_ playlist: Playlist) -> String {
        var parts: [String] = []
        parts.append("\(playlist.tracks.count) треков")
        if playlist.duration > 0 {
            let hours = playlist.duration / 3600
            let minutes = (playlist.duration % 3600) / 60
            if hours > 0 {
                parts.append("\(hours) ч \(minutes) мин")
            } else {
                parts.append("\(minutes) мин")
            }
        }
        return parts.joined(separator: " · ")
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
