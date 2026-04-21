import SwiftUI
import ZvukMusic

private struct GlassSheetBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: .rect(cornerRadius: 16))
        } else {
            content.background(.ultraThinMaterial)
        }
    }
}

struct CoverSheetView: View {
    let imageURL: String?
    let title: String
    let subtitle: String
    let artists: [SimpleArtist]
    let trackId: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(PlayerService.self) private var playerService
    @Environment(CollectionService.self) private var collectionService
    @Environment(AppState.self) private var appState

    init(track: SimpleTrack) {
        self.imageURL = track.release?.image?.getURL(width: 600, height: 600)
        self.title = track.title
        self.subtitle = track.artistsString
        self.artists = track.artists
        self.trackId = track.id
    }

    init(imageURL: String?, title: String, subtitle: String = "") {
        self.imageURL = imageURL
        self.title = title
        self.subtitle = subtitle
        self.artists = []
        self.trackId = nil
    }

    private var isCurrentTrack: Bool {
        guard let trackId else { return false }
        return playerService.currentTrack?.id == trackId
    }

    var body: some View {
        VStack(spacing: 16) {
            placeholder
                .overlay {
                    if let imageURL, let url = URL(string: imageURL) {
                        CachedAsyncImage(url: url) { image in
                            image
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color.clear
                        }
                    }
                }
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title3.weight(.semibold))
                        .lineLimit(1)
                    if !artists.isEmpty {
                        HStack(spacing: 0) {
                            ForEach(Array(artists.enumerated()), id: \.element.id) { index, artist in
                                if index > 0 {
                                    Text(", ")
                                        .font(.body)
                                        .foregroundStyle(.secondary)
                                }
                                Button(artist.title) {
                                    dismiss()
                                    Task { @MainActor in
                                        appState.selectedDestination = .artist(id: artist.id)
                                    }
                                }
                                .buttonStyle(.plain)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .focusable(false)
                            }
                        }
                        .lineLimit(1)
                    } else if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if isCurrentTrack, let track = playerService.currentTrack {
                    let isLiked = collectionService.isTrackLiked(track.id)
                    HStack(spacing: 16) {
                        ShareButton(target: .track(id: track.id))

                        Button {
                            Task {
                                _ = try? await appState.client?.hideTrack(track.id)
                                playerService.next()
                            }
                        } label: {
                            Image(systemName: "hand.thumbsdown")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .focusable(false)
                        .help("Не нравится")

                        Button {
                            Task {
                                await collectionService.toggleTrackLike(track, client: appState.client)
                            }
                        } label: {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .font(.title2)
                                .foregroundStyle(isLiked ? .red : .secondary)
                        }
                        .buttonStyle(.plain)
                        .focusable(false)
                        .help("Нравится")

                        Button {
                            playerService.previous()
                        } label: {
                            Image(systemName: "backward.fill")
                                .font(.title2)
                                .foregroundStyle(playerService.hasPrevious ? .primary : .tertiary)
                        }
                        .buttonStyle(.plain)
                        .focusable(false)
                        .disabled(!playerService.hasPrevious)

                        Button {
                            if playerService.isPlaying {
                                playerService.pause()
                            } else {
                                playerService.resume()
                            }
                        } label: {
                            Image(systemName: playerService.isPlaying ? "pause.fill" : "play.fill")
                                .font(.title)
                                .foregroundStyle(.primary)
                                .frame(width: 24)
                        }
                        .buttonStyle(.plain)
                        .focusable(false)

                        Button {
                            playerService.next()
                        } label: {
                            Image(systemName: "forward.fill")
                                .font(.title2)
                                .foregroundStyle(playerService.hasNext ? .primary : .tertiary)
                        }
                        .buttonStyle(.plain)
                        .focusable(false)
                        .disabled(!playerService.hasNext)
                    }
                }
            }
        }
        .padding(24)
        .frame(minWidth: 450, minHeight: 500)
        .modifier(GlassSheetBackgroundModifier())
        .onTapGesture {
            dismiss()
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(.quaternary)
            .overlay {
                Image(systemName: "music.note")
                    .font(.system(size: 64))
                    .foregroundStyle(.secondary)
            }
    }
}
