import SwiftUI
import ZvukMusic

struct TrackRowView<Trailing: View>: View {
    let track: SimpleTrack
    let trailing: Trailing
    let onPlay: () -> Void
    var onArtistTap: ((String) -> Void)? = nil
    var onReleaseTap: ((String) -> Void)? = nil
    @Environment(PlayerService.self) private var playerService

    init(
        track: SimpleTrack,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() },
        onPlay: @escaping () -> Void
    ) {
        self.track = track
        self.trailing = trailing()
        self.onPlay = onPlay
    }

    private var isPlaying: Bool {
        playerService.currentTrack?.id == track.id
    }

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                coverImage
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                if isPlaying {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.black.opacity(0.45))
                        .frame(width: 36, height: 36)

                    Image(systemName: playerService.isPlaying ? "speaker.wave.2.fill" : "play.fill")
                        .font(.caption)
                        .foregroundStyle(.white)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.callout)
                    .lineLimit(1)
                    .foregroundStyle(isPlaying ? Color.accentColor : Color.primary)

                HStack(spacing: 4) {
                    if track.explicit {
                        Image(systemName: "e.square.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    artistsText
                }
            }

            Spacer()

            trailing

            Text(track.durationString)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isPlaying ? Color.accentColor.opacity(0.12) : .clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onPlay()
        }
    }

    private var coverImage: some View {
        Group {
            if let imageURL = track.release?.image?.getURL(width: 72, height: 72),
               let url = URL(string: imageURL) {
                CachedAsyncImage(url: url) { image in
                    image
                } placeholder: {
                    placeholderView
                }
            } else {
                placeholderView
            }
        }
    }

    private var placeholderView: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(.quaternary)
            .overlay {
                Image(systemName: "music.note")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
    }

    private var artistsText: some View {
        Text(track.artistsString)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }
}
