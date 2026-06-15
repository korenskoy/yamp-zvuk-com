import SwiftUI
import ZvukMusic

private struct LiquidGlassBarModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
        } else {
            content
                .background(.bar)
        }
    }
}

struct PlayerBarView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppSettings.self) private var appSettings
    @Environment(PlayerService.self) private var playerService
    @Environment(LastFMService.self) private var lastFMService
    @State private var showQueue = false
    @State private var showCover = false
    @State private var showProgress = false
    @State private var appError: AppError?

    var body: some View {
        if let track = playerService.currentTrack {
            VStack(spacing: 0) {
                if #unavailable(macOS 26.0) {
                    Divider()
                }

                HStack(spacing: 16) {
                    trackInfo(track)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    PlayerControlsView()
                        .fixedSize()

                    HStack(spacing: 12) {
                        Spacer()
                        VolumeControlView()

                        Button {
                            appState.selectedDestination = .nowPlaying
                        } label: {
                            Image(systemName: "text.quote")
                                .font(.callout)
                        }
                        .buttonStyle(.plain)
                        .help("Текст песни")

                        Button {
                            showQueue.toggle()
                        } label: {
                            Image(systemName: "list.bullet")
                                .font(.callout)
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showQueue) {
                            QueueView()
                        }

                        Button(action: playRadioByTrack) {
                            Image(systemName: "dot.radiowaves.left.and.right")
                                .font(.callout)
                        }
                        .buttonStyle(.plain)
                        .help("Радио по треку")

                        ShareButton(
                            target: playerService.currentTrack.map { .track(id: $0.id) },
                            font: .callout
                        )

                        if lastFMService.isConnected && appSettings.isScrobblingEnabled {
                            Button {
                                if let username = lastFMService.connectedUsername,
                                   let encoded = username.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                                   let url = URL(string: "https://www.last.fm/user/\(encoded)") {
                                    NSWorkspace.shared.open(url)
                                }
                            } label: {
                                LastFMIcon()
                                    .fill(lastFMService.scrobbleState == .scrobbled ? Color.red : Color.primary)
                                    .frame(width: 12, height: 12)
                                    .opacity(lastFMService.scrobbleState == .scrobbled ? 1 : 0.2)
                            }
                            .buttonStyle(.plain)
                            .help(lastFMService.scrobbleState == .scrobbled ? "Заскробблено" : "Ожидание скробблинга")
                            .animation(.easeInOut(duration: 0.3), value: lastFMService.scrobbleState == .scrobbled)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .overlay(alignment: .bottom) {
                    if showProgress {
                        progressOverlay
                            .transition(.opacity)
                            .allowsHitTesting(false)
                    }
                }

                ProgressBarView(isExpanded: $showProgress)
                    .padding(.horizontal, 16)
            }
            .errorAlert($appError)
            .modifier(LiquidGlassBarModifier())
            .animation(.easeInOut(duration: 0.2), value: showProgress)
        }
    }

    private func playRadioByTrack() {
        guard let track = playerService.currentTrack else { return }
        Task {
            guard let client = appState.client else { return }
            do {
                let result = try await client.getRadioByTrack(track.id)
                let tracks = result.tracks
                if !tracks.isEmpty {
                    playerService.playQueue(
                        tracks.map(\.simplified),
                        context: .radioTrack(id: track.id)
                    )
                }
            } catch {
                appError = AppError.from(error)
            }
        }
    }

    private var progressOverlay: some View {
        VStack {
            Spacer()
            HStack {
                Text(formatTime(isSeeking: false))
                Spacer()
                Text(formatRemainingTime())
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .background(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: Color(.windowBackgroundColor).opacity(0.7), location: 0.3),
                    .init(color: Color(.windowBackgroundColor), location: 0.6),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        )
    }

    private func formatTime(isSeeking: Bool) -> String {
        playerService.currentTime.formattedTime
    }

    private func formatRemainingTime() -> String {
        let remaining = playerService.duration - playerService.currentTime
        return remaining.formattedTime(negative: true)
    }

    private func trackInfo(_ track: SimpleTrack) -> some View {
        HStack(spacing: 10) {
            coverImage(track)

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                    .onTapGesture {
                        if let releaseId = track.release?.id {
                            appState.selectedDestination = .release(id: releaseId)
                        }
                    }
                    .onHover { inside in
                        if track.release != nil {
                            NSCursor.pointingHand.set()
                            if !inside { NSCursor.arrow.set() }
                        }
                    }

                artistsLine(track.artists)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func coverImage(_ track: SimpleTrack) -> some View {
        Group {
            if let imageURL = track.release?.image?.getURL(width: 80, height: 80),
               let url = URL(string: imageURL) {
                CachedAsyncImage(url: url) { image in
                    image
                } placeholder: {
                    coverPlaceholder
                }
            } else {
                coverPlaceholder
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onTapGesture {
            if track.release?.image != nil {
                showCover = true
            }
        }
        .sheet(isPresented: $showCover) {
            CoverSheetView(track: track)
        }
    }

    private func artistsLine(_ artists: [SimpleArtist]) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(artists.enumerated()), id: \.element.id) { index, artist in
                if index > 0 {
                    Text(", ")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(artist.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .onHover { inside in
                        if inside { NSCursor.pointingHand.set() } else { NSCursor.arrow.set() }
                    }
                    .onTapGesture {
                        appState.selectedDestination = .artist(id: artist.id)
                    }
            }
        }
        .lineLimit(1)
    }

    private var coverPlaceholder: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(.quaternary)
            .overlay {
                Image(systemName: "music.note")
                    .foregroundStyle(.secondary)
            }
    }
}
