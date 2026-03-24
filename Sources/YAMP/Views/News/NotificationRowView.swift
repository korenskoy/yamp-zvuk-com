import SwiftUI
import ZvukMusic

struct NotificationRowView: View {
    let notification: ZvukNotification
    let onNavigate: (NavigationDestination) -> Void
    @Environment(PlayerService.self) private var playerService
    @Environment(CacheService.self) private var cacheService

    var body: some View {
        switch notification.body {
        case .newRelease(let author, let release):
            newReleaseRow(author: author, release: release)
        case .newPodcastEpisode(let episode):
            newEpisodeRow(episode: episode)
        case .newBook(let author, let book):
            newBookRow(author: author, book: book)
        case .newProfilePlaylist(let author, let playlist):
            playlistRow(
                author: author,
                playlist: playlist,
                subtitle: "создал плейлист"
            )
        case .playlistTracksAdded(let author, let playlist, let count):
            playlistRow(
                author: author,
                playlist: playlist,
                subtitle: "добавил \(count) \(trackWord(count)) в плейлист"
            )
        case .playlistLiked(let author, let playlist):
            playlistRow(
                author: author,
                playlist: playlist,
                subtitle: "лайкнул плейлист"
            )
        case .unknown:
            EmptyView()
        }
    }

    // MARK: - New Release

    private func newReleaseRow(author: NotificationArtistAuthor, release: NotificationRelease) -> some View {
        HStack(spacing: 12) {
            PlayableCoverView(
                src: release.image?.src,
                size: 64,
                releaseId: release.id
            )

            VStack(alignment: .leading, spacing: 4) {
                authorLabel(imageURL: author.image?.src, name: author.title)

                Text(release.title)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)

                Text(release.artists.map(\.title).joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let type = release.type {
                    Text(releaseTypeName(type))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            timeLabel
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onNavigate(.release(id: release.id))
        }
    }

    // MARK: - New Episode

    private func newEpisodeRow(episode: NotificationEpisode) -> some View {
        HStack(spacing: 12) {
            coverImage(src: episode.image?.src, size: 64)

            VStack(alignment: .leading, spacing: 4) {
                if let podcast = episode.podcast {
                    authorLabel(imageURL: podcast.image?.src, name: podcast.title)
                }

                Text(episode.title)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)

                if episode.duration > 0 {
                    Text(formatDuration(episode.duration))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            timeLabel
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    // MARK: - New Book

    private func newBookRow(author: NotificationBookAuthor, book: NotificationBook) -> some View {
        HStack(spacing: 12) {
            coverImage(src: book.image?.src, size: 64)

            VStack(alignment: .leading, spacing: 4) {
                authorLabel(imageURL: author.image?.src, name: author.rname)

                Text(book.title)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)

                Text(book.bookAuthors.map(\.rname).joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            timeLabel
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    // MARK: - Playlist notifications

    private func playlistRow(author: NotificationProfileAuthor, playlist: NotificationPlaylist, subtitle: String) -> some View {
        HStack(spacing: 12) {
            playlistCover(playlist: playlist, size: 64)

            VStack(alignment: .leading, spacing: 4) {
                authorLabel(imageURL: author.image?.src, name: author.name)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(playlist.title)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)

                Text("\(playlist.trackCount) \(trackWord(playlist.trackCount))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            timeLabel
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onNavigate(.playlist(id: playlist.id))
        }
    }

    // MARK: - Shared Components

    private func authorLabel(imageURL: String?, name: String) -> some View {
        HStack(spacing: 6) {
            if let src = imageURL,
               let url = URL(string: zvukImageURL(src: src, width: 40, height: 40)) {
                CachedAsyncImage(url: url) { image in
                    image.scaledToFill()
                } placeholder: {
                    Circle().fill(.quaternary)
                }
                .frame(width: 20, height: 20)
                .clipShape(Circle())
            }

            Text(name)
                .font(.caption.weight(.medium))
                .lineLimit(1)
        }
    }

    private func coverImage(src: String?, size: CGFloat) -> some View {
        Group {
            if let src,
               let url = URL(string: zvukImageURL(src: src, width: Int(size * 2), height: Int(size * 2))) {
                CachedAsyncImage(url: url) { image in
                    image.scaledToFill()
                } placeholder: {
                    coverPlaceholder(size: size)
                }
            } else {
                coverPlaceholder(size: size)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func coverPlaceholder(size: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(.quaternary)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: "music.note")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
    }

    private func playlistCover(playlist: NotificationPlaylist, size: CGFloat) -> some View {
        Group {
            if let coverSrc = playlist.coverV1?.src ?? playlist.image.map({ $0.src }) {
                coverImage(src: coverSrc, size: size)
            } else {
                coverPlaceholder(size: size)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var timeLabel: some View {
        Text(formatRelativeDate(notification.createdAt))
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .frame(minWidth: 50, alignment: .trailing)
    }

    // MARK: - Helpers

    private func formatRelativeDate(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: iso) ?? ISO8601DateFormatter().date(from: iso) else {
            return ""
        }
        let relative = RelativeDateTimeFormatter()
        relative.locale = Locale(identifier: "ru_RU")
        relative.unitsStyle = .abbreviated
        return relative.localizedString(for: date, relativeTo: Date())
    }

    private func formatDuration(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private func releaseTypeName(_ type: String) -> String {
        switch type.lowercased() {
        case "single": "Сингл"
        case "album": "Альбом"
        case "ep": "EP"
        case "compilation": "Сборник"
        default: type
        }
    }

    private func trackWord(_ count: Int) -> String {
        let mod10 = count % 10
        let mod100 = count % 100
        if mod100 >= 11 && mod100 <= 19 { return "треков" }
        if mod10 == 1 { return "трек" }
        if mod10 >= 2 && mod10 <= 4 { return "трека" }
        return "треков"
    }
}

// MARK: - Playable Cover (hover play button for releases)

private struct PlayableCoverView: View {
    let src: String?
    let size: CGFloat
    let releaseId: String

    @Environment(PlayerService.self) private var playerService
    @Environment(CacheService.self) private var cacheService
    @State private var isHovered = false

    private var isPlayingThisRelease: Bool {
        guard let current = playerService.currentTrack else { return false }
        return current.release?.id == releaseId
    }

    var body: some View {
        ZStack {
            // Cover image
            Group {
                if let src,
                   let url = URL(string: zvukImageURL(src: src, width: Int(size * 2), height: Int(size * 2))) {
                    CachedAsyncImage(url: url) { image in
                        image.scaledToFill()
                    } placeholder: {
                        placeholder
                    }
                } else {
                    placeholder
                }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Play/pause overlay
            if isHovered || isPlayingThisRelease {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.black.opacity(0.45))
                    .frame(width: size, height: size)

                Image(systemName: isPlayingThisRelease && playerService.isPlaying
                      ? "pause.fill"
                      : "play.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .frame(width: size, height: size)
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            if isPlayingThisRelease {
                playerService.togglePlayPause()
            } else {
                Task {
                    await playRelease()
                }
            }
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(.quaternary)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: "music.note")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
    }

    private func playRelease() async {
        do {
            let releases = try await cacheService.getReleases([releaseId])
            guard let release = releases.first, !release.tracks.isEmpty else { return }
            playerService.playQueue(release.tracks, context: .album(id: releaseId))
        } catch {}
    }
}

// MARK: - Image URL helper

private func zvukImageURL(src: String, width: Int, height: Int) -> String {
    var urlString = src
    if urlString.hasPrefix("/") {
        urlString = "https://zvuk.com\(urlString)"
    }
    guard var components = URLComponents(string: urlString) else { return urlString }
    var queryItems = components.queryItems ?? []
    queryItems.removeAll { $0.name == "size" }
    queryItems.append(URLQueryItem(name: "size", value: "\(width)x\(height)"))
    components.queryItems = queryItems
    return components.string ?? urlString
}
