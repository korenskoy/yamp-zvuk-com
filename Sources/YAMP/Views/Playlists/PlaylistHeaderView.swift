import SwiftUI
import ZvukMusic

struct PlaylistHeaderView: View {
    let playlist: Playlist
    let isOwnPlaylist: Bool
    let isLiked: Bool
    let onPlay: () -> Void
    let onToggleLike: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void
    @State private var showCover = false

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            coverImage
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

                playlistActions
            }

            Spacer()
        }
    }

    private var coverImage: some View {
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

    private var playlistActions: some View {
        HStack(spacing: 12) {
            Button(action: onPlay) {
                Label("Воспроизвести", systemImage: "play.fill")
            }
            .buttonStyle(.accent)
            .controlSize(.large)
            .disabled(playlist.tracks.isEmpty)

            if !isOwnPlaylist {
                Button(action: onToggleLike) {
                    Image(systemName: isLiked ? "checkmark" : "plus")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(isLiked ? "Убрать из коллекции" : "Добавить в коллекцию")
            }

            if isOwnPlaylist {
                Button(action: onRename) {
                    Image(systemName: "pencil")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Переименовать")

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Удалить")
            }
        }
    }
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
