import SwiftUI
import ZvukMusic

struct ReleaseHeaderView: View {
    let release: Release
    let isLiked: Bool
    var onPlayAll: () -> Void
    var onToggleLike: () -> Void
    var onArtistTap: ((String) -> Void)? = nil
    @State private var showCover = false
    @State private var showAllArtists = false

    private static let maxInlineArtists = 8

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            coverImage
                .frame(width: 160, height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(radius: 8, y: 4)
                .onTapGesture {
                    if release.image != nil { showCover = true }
                }
                .sheet(isPresented: $showCover) {
                    CoverSheetView(
                        imageURL: release.image?.getURL(width: 600, height: 600),
                        title: release.title,
                        subtitle: artistsSubtitle
                    )
                }

            VStack(alignment: .leading, spacing: 8) {
                Text(release.title)
                    .font(.title.weight(.bold))

                artistsLine

                HStack(spacing: 8) {
                    if let type = release.type {
                        Text(typeLabel(type))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let year = release.year {
                        Text(String(year))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if !release.tracks.isEmpty {
                        Text("\(release.tracks.count) треков")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if !release.genres.isEmpty {
                    Text(release.genres.map(\.name).joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 12) {
                    Button {
                        onPlayAll()
                    } label: {
                        Label("Воспроизвести", systemImage: "play.fill")
                    }
                    .buttonStyle(.accent)
                    .controlSize(.large)

                    Button(action: onToggleLike) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.title2)
                            .foregroundStyle(isLiked ? .red : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help(isLiked ? "Убрать из коллекции" : "Добавить в коллекцию")

                    ShareButton(target: .release(id: release.id))
                }
            }

            Spacer()
        }
        .sheet(isPresented: $showAllArtists) {
            GridSheet(title: "Исполнители", minItemWidth: 100, maxItemWidth: 140) {
                ForEach(release.artists) { artist in
                    ArtistThumbnailView(artist: artist)
                        .onTapGesture {
                            showAllArtists = false
                            onArtistTap?(artist.id)
                        }
                }
            }
        }
    }

    private var artistsLine: some View {
        ViewThatFits(in: .horizontal) {
            ForEach((1...max(1, min(release.artists.count, Self.maxInlineArtists))).reversed(), id: \.self) { count in
                artistsRow(visibleCount: count)
            }
        }
    }

    private func artistsRow(visibleCount: Int) -> some View {
        let remaining = release.artists.count - visibleCount
        return HStack(spacing: 0) {
            ForEach(release.artists.prefix(visibleCount).indices, id: \.self) { index in
                let artist = release.artists[index]
                if index > 0 {
                    Text(", ")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: true, vertical: false)
                }

                Text(artist.title)
                    .font(.title3)
                    .foregroundStyle(onArtistTap != nil ? Color.accentColor : .primary)
                    .fixedSize(horizontal: true, vertical: false)
                    .onTapGesture {
                        onArtistTap?(artist.id)
                    }
            }

            if remaining > 0 {
                Text(" \(Self.moreSuffix(remaining))")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                    .fixedSize(horizontal: true, vertical: false)
                    .onTapGesture {
                        showAllArtists = true
                    }
            }
        }
        .lineLimit(1)
    }

    private var artistsSubtitle: String {
        let names = release.artists.map(\.title)
        guard names.count > 3 else {
            return names.joined(separator: ", ")
        }
        return names.prefix(3).joined(separator: ", ") + " " + Self.moreSuffix(names.count - 3)
    }

    private static func moreSuffix(_ count: Int) -> String {
        "и ещё \(count)"
    }

    private var coverImage: some View {
        Group {
            if let imageURL = release.image?.getURL(width: 400, height: 400),
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
        RoundedRectangle(cornerRadius: 12)
            .fill(.quaternary)
            .overlay {
                Image(systemName: "music.note")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
            }
    }

    private func typeLabel(_ type: ReleaseType) -> String {
        switch type {
        case .album: "Альбом"
        case .single: "Сингл"
        case .ep: "EP"
        case .compilation: "Сборник"
        }
    }
}
