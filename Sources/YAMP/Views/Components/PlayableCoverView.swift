import SwiftUI
import ZvukMusic

struct PlayableCoverView: View {
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
        } catch {
            // Сетевые ошибки логируются транспортным слоем клиента в LogStore
        }
    }
}

func zvukImageURL(src: String, width: Int, height: Int) -> String {
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
