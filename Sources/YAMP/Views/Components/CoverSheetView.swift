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
    let trackId: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(PlayerService.self) private var playerService
    @Environment(CollectionService.self) private var collectionService
    @Environment(AppState.self) private var appState

    init(track: SimpleTrack) {
        self.imageURL = track.release?.image?.getURL(width: 600, height: 600)
        self.title = track.title
        self.subtitle = track.artistsString
        self.trackId = track.id
    }

    init(imageURL: String?, title: String, subtitle: String = "") {
        self.imageURL = imageURL
        self.title = title
        self.subtitle = subtitle
        self.trackId = nil
    }

    private var isCurrentTrack: Bool {
        guard let trackId else { return false }
        return playerService.currentTrack?.id == trackId
    }

    var body: some View {
        VStack(spacing: 16) {
            if let imageURL, let url = URL(string: imageURL) {
                CachedAsyncImage(url: url) { image in
                    image
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } placeholder: {
                    ProgressView()
                        .frame(width: 400, height: 400)
                }
            } else {
                placeholder
            }

            HStack {
                if isCurrentTrack {
                    Button {
                        guard let track = playerService.currentTrack else { return }
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
                }

                VStack(spacing: 4) {
                    Text(title)
                        .font(.title3.weight(.semibold))
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)

                if isCurrentTrack, let track = playerService.currentTrack {
                    Button {
                        Task {
                            await collectionService.toggleTrackLike(track, client: appState.client)
                        }
                    } label: {
                        Image(systemName: collectionService.isTrackLiked(track.id) ? "heart.fill" : "heart")
                            .font(.title2)
                            .foregroundStyle(collectionService.isTrackLiked(track.id) ? .red : .secondary)
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    .help("Нравится")
                }
            }
        }
        .padding(24)
        .frame(minWidth: 450, minHeight: 500)
        .modifier(GlassSheetBackgroundModifier())
        .onTapGesture {
            dismiss()
        }
        .keyboardShortcut(.escape, modifiers: [])
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(.quaternary)
            .frame(width: 400, height: 400)
            .overlay {
                Image(systemName: "music.note")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            }
    }
}
