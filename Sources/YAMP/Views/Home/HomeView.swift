import SwiftUI
import ZvukMusic

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(CacheService.self) private var cacheService
    @State private var viewModel = HomeViewModel()

    private let minItemWidth: CGFloat = 140
    private let maxItemWidth: CGFloat = 180
    private let spacing: CGFloat = 16

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Главная")
                    .font(.largeTitle.bold())
                    .padding(.horizontal)

                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    if !viewModel.recommendationItems.isEmpty {
                        recommendationsSection
                    }

                    if !viewModel.editorialPlaylists.isEmpty {
                        editorialSection
                    }

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.callout)
                            .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .task {
            await viewModel.load(cache: cacheService)
        }
    }

    // MARK: - Recommendations

    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Рекомендации")
                .font(.title2.bold())
                .padding(.horizontal)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: minItemWidth, maximum: maxItemWidth), spacing: spacing, alignment: .top)], spacing: spacing) {
                ForEach(Array(viewModel.recommendationItems.enumerated()), id: \.offset) { _, item in
                    recommendationCard(item)
                }
            }
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private func recommendationCard(_ item: RecommendationItem) -> some View {
        switch item {
        case .release(let release):
            let simpleRelease = SimpleRelease(
                id: release.id,
                title: release.title,
                image: release.image,
                artists: release.artists
            )
            ReleaseThumbnailView(release: simpleRelease)
                .contentShape(Rectangle())
                .onTapGesture {
                    appState.selectedDestination = .release(id: release.id)
                }

        case .artist(let artist):
            artistCard(artist)
                .contentShape(Rectangle())
                .onTapGesture {
                    appState.selectedDestination = .artist(id: artist.id)
                }

        case .playlist(let playlist):
            RecommendedPlaylistCardView(playlist: playlist)

        case .unknown:
            EmptyView()
        }
    }

    private func artistCard(_ artist: RecommendationArtist) -> some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                Group {
                    if let src = artist.image?.getURL(width: 360, height: 360),
                       let url = URL(string: src) {
                        CachedAsyncImage(url: url) { image in
                            image.scaledToFill()
                        } placeholder: {
                            artistPlaceholder
                        }
                    } else {
                        artistPlaceholder
                    }
                }
                .frame(width: geo.size.width, height: geo.size.width)
                .clipped()
                .clipShape(Circle())
            }
            .aspectRatio(1, contentMode: .fit)

            VStack(spacing: 2) {
                Text(artist.title)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)

                Text("Артист")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .multilineTextAlignment(.center)
        }
    }

    private var artistPlaceholder: some View {
        Circle()
            .fill(.quaternary)
            .overlay {
                Image(systemName: "person.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            }
    }

    // MARK: - Editorial Playlists

    private var editorialSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Редакционные плейлисты")
                .font(.title2.bold())
                .padding(.horizontal)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: minItemWidth, maximum: maxItemWidth), spacing: spacing, alignment: .top)], spacing: spacing) {
                ForEach(viewModel.editorialPlaylists) { playlist in
                    EditorialPlaylistCardView(playlist: playlist)
                }
            }
            .padding(.horizontal)
        }
    }
}
