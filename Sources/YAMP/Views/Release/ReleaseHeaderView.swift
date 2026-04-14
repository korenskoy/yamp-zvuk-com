import SwiftUI
import ZvukMusic

struct ReleaseHeaderView: View {
    let release: Release
    let isLiked: Bool
    var onPlayAll: () -> Void
    var onToggleLike: () -> Void
    var onArtistTap: ((String) -> Void)? = nil
    @State private var showCover = false

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
                        subtitle: release.artists.map(\.title).joined(separator: ", ")
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
    }

    private var artistsLine: some View {
        HStack(spacing: 0) {
            ForEach(Array(release.artists.enumerated()), id: \.element.id) { index, artist in
                if index > 0 {
                    Text(", ")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                Text(artist.title)
                    .font(.title3)
                    .foregroundStyle(onArtistTap != nil ? Color.accentColor : .primary)
                    .onTapGesture {
                        onArtistTap?(artist.id)
                    }
            }
        }
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
