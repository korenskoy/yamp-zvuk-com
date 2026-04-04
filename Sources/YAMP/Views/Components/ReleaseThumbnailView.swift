import SwiftUI
import ZvukMusic

struct ReleaseThumbnailView: View {
    let release: SimpleRelease
    var size: CGFloat? = nil

    @Environment(PlayerService.self) private var playerService
    @Environment(CacheService.self) private var cacheService
    @State private var isHovered = false

    private var isPlayingThisRelease: Bool {
        guard let current = playerService.currentTrack else { return false }
        return current.release?.id == release.id
    }

    var body: some View {
        if let size {
            fixedContent(size: size)
        } else {
            flexibleContent
        }
    }

    // MARK: - Fixed size (used when explicit size is passed)

    private func fixedContent(size: CGFloat) -> some View {
        VStack(spacing: 6) {
            coverOverlay(size: size)
                .frame(width: size, height: size)

            labels
        }
        .frame(width: size)
    }

    // MARK: - Flexible (fills grid cell width)

    private var flexibleContent: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                coverOverlay(size: geo.size.width)
            }
            .aspectRatio(1, contentMode: .fit)

            labels
        }
    }

    // MARK: - Shared

    private func coverOverlay(size: CGFloat) -> some View {
        ZStack {
            coverImage(size: size)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            if isHovered || (isPlayingThisRelease && playerService.isPlaying) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.black.opacity(0.45))
                    .frame(width: size, height: size)

                Image(systemName: isPlayingThisRelease && playerService.isPlaying
                      ? "pause.fill"
                      : "play.fill")
                    .font(size > 100 ? .title2 : .title3)
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
                Task { await playRelease() }
            }
        }
    }

    private var labels: some View {
        VStack(spacing: 2) {
            Text(release.title)
                .font(.caption.weight(.medium))
                .lineLimit(1)

            Text(release.artists.map(\.title).joined(separator: ", "))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .multilineTextAlignment(.center)
    }

    private func coverImage(size: CGFloat) -> some View {
        Group {
            if let imageURL = release.image?.getURL(width: 360, height: 360),
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
        RoundedRectangle(cornerRadius: 8)
            .fill(.quaternary)
            .overlay {
                Image(systemName: "music.note")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
    }

    private func playRelease() async {
        do {
            let releases = try await cacheService.getReleases([release.id])
            guard let full = releases.first, !full.tracks.isEmpty else { return }
            playerService.playQueue(full.tracks, context: .album(id: release.id))
        } catch {
            // Сетевые ошибки логируются транспортным слоем клиента в LogStore
        }
    }
}
