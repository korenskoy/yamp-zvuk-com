import SwiftUI
import ZvukMusic

struct ArtistHeaderView: View {
    let artist: Artist
    let subscriberCount: Int?
    let isSubscribed: Bool
    let onPlay: () -> Void
    let onShuffle: () -> Void
    let onRadio: () -> Void
    let onToggleSubscribe: () -> Void
    let onHideArtist: () -> Void

    @State private var isDescriptionExpanded = false
    @State private var showCover = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 20) {
                artistImage
                    .frame(width: 180, height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .onTapGesture {
                        if artist.image != nil { showCover = true }
                    }
                    .sheet(isPresented: $showCover) {
                        CoverSheetView(
                            imageURL: artist.image?.getURL(width: 600, height: 600),
                            title: artist.title
                        )
                    }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Артист")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    Text(artist.title)
                        .font(.largeTitle.weight(.bold))

                    if let count = subscriberCount {
                        Text(formatSubscribers(count))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    if let description = artist.description, !description.isEmpty {
                        descriptionView(description)
                    }
                }

                Spacer()
            }

            actionButtons
        }
    }

    // MARK: - Description

    private func descriptionView(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .lineLimit(isDescriptionExpanded ? nil : 3)
            .overlay(alignment: .bottom) {
                if !isDescriptionExpanded {
                    LinearGradient(
                        colors: [.clear, Color(nsColor: .windowBackgroundColor)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 20)
                }
            }
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isDescriptionExpanded.toggle()
                }
            }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(action: onPlay) {
                Label("Слушать", systemImage: "play.fill")
            }
            .buttonStyle(.accent)
            .controlSize(.large)

            Button(action: onToggleSubscribe) {
                Image(systemName: isSubscribed ? "checkmark.circle.fill" : "plus.circle")
                    .font(.title2)
                    .foregroundStyle(isSubscribed ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .help(isSubscribed ? "Отписаться" : "Подписаться")

            Button(action: onShuffle) {
                Image(systemName: "shuffle")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Перемешать")

            Button(action: onRadio) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Радио по артисту")

            Button(action: onHideArtist) {
                Image(systemName: "hand.thumbsdown")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Скрыть артиста")

            ShareButton(target: .artist(id: artist.id))
        }
    }

    // MARK: - Artist Image

    private var artistImage: some View {
        Group {
            if let imageURL = artist.image?.getURL(width: 360, height: 360),
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
                Image(systemName: "person.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
            }
    }

    // MARK: - Helpers

    private func formatSubscribers(_ count: Int) -> String {
        if count >= 1_000_000 {
            let value = Double(count) / 1_000_000
            return String(format: "%.1fM подписчиков", value)
        } else if count >= 1_000 {
            let value = Double(count) / 1_000
            return String(format: "%.1fK подписчиков", value)
        } else {
            return "\(count) подписчиков"
        }
    }
}
