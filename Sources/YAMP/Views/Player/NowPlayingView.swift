import SwiftUI
import ZvukMusic

private struct GlassCoverModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: .rect(cornerRadius: 16))
        } else {
            content
        }
    }
}

struct NowPlayingView: View {
    @Environment(AppState.self) private var appState
    @Environment(PlayerService.self) private var playerService
    @Environment(CacheService.self) private var cacheService
    @State private var lyricsVM = LyricsViewModel()

    var body: some View {
        VStack(spacing: 0) {
            if let track = playerService.currentTrack {
                ScrollView {
                    VStack(spacing: 24) {
                        coverImage(track)
                            .frame(width: 280, height: 280)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .modifier(GlassCoverModifier())
                            .shadow(radius: 12, y: 6)

                        VStack(spacing: 4) {
                            Text(track.title)
                                .font(.title2.weight(.bold))

                            Text(track.artistsString)
                                .font(.title3)
                                .foregroundStyle(.secondary)

                            if let release = track.release {
                                Text(release.title)
                                    .font(.callout)
                                    .foregroundStyle(.tertiary)
                            }
                        }

                        if lyricsVM.isLoading {
                            ProgressView("Загрузка текста...")
                        } else if lyricsVM.hasLyrics {
                            lyricsView
                        }
                    }
                    .padding(32)
                }
                .task(id: track.id) {
                    await lyricsVM.loadIfNeeded(trackId: track.id, cache: cacheService)
                }
                .onChange(of: playerService.currentTime) {
                    lyricsVM.updateCurrentLine(at: playerService.currentTime)
                }
            } else {
                ContentUnavailableView(
                    "Ничего не играет",
                    systemImage: "music.note",
                    description: Text("Выберите трек для воспроизведения")
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var lyricsView: some View {
        VStack(alignment: .center, spacing: 6) {
            ForEach(Array(lyricsVM.lines.enumerated()), id: \.element.id) { index, line in
                Text(line.text)
                    .font(lyricsVM.isSynced && index == lyricsVM.currentLineIndex
                          ? .body.weight(.bold) : .body)
                    .foregroundStyle(lyricsVM.isSynced && index == lyricsVM.currentLineIndex
                                    ? .primary : .secondary)
                    .multilineTextAlignment(.center)
                    .animation(.easeInOut(duration: 0.2), value: lyricsVM.currentLineIndex)
            }
        }
        .padding(.top, 8)
    }

    private func coverImage(_ track: SimpleTrack) -> some View {
        Group {
            if let imageURL = track.release?.image?.getURL(width: 560, height: 560),
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
        RoundedRectangle(cornerRadius: 16)
            .fill(.quaternary)
            .overlay {
                Image(systemName: "music.note")
                    .font(.system(size: 64))
                    .foregroundStyle(.secondary)
            }
    }
}
