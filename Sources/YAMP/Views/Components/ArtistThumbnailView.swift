import SwiftUI
import ZvukMusic

struct ArtistThumbnailView: View {
    let artist: SimpleArtist
    var size: CGFloat = 80

    var body: some View {
        VStack(spacing: 6) {
            artistImage
                .frame(width: size, height: size)
                .clipShape(Circle())

            Text(artist.title)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(width: size + 20)
    }

    private var artistImage: some View {
        Group {
            if let imageURL = artist.image?.getURL(width: Int(size * 2), height: Int(size * 2)),
               let url = URL(string: imageURL) {
                CachedAsyncImage(url: url) { image in
                    image.scaledToFill()
                } placeholder: {
                    Circle()
                        .fill(.quaternary)
                        .overlay {
                            Image(systemName: "person.fill")
                                .foregroundStyle(.secondary)
                        }
                }
            } else {
                Circle()
                    .fill(.quaternary)
                    .overlay {
                        Image(systemName: "person.fill")
                            .foregroundStyle(.secondary)
                    }
            }
        }
    }
}
