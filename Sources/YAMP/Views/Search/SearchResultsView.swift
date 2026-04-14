import SwiftUI
import ZvukMusic

private enum ExpandedSheet: Identifiable {
    case artists(title: String, items: [SimpleArtist])
    case releases(title: String, items: [SimpleRelease])

    var id: String {
        switch self {
        case .artists(let title, _), .releases(let title, _): return title
        }
    }
}

struct SearchResultsView: View {
    let viewModel: SearchViewModel
    @Environment(AppState.self) private var appState
    @Environment(PlayerService.self) private var playerService

    private let minItemWidth: CGFloat = 140
    private let maxItemWidth: CGFloat = 180
    private let gridSpacing: CGFloat = 16
    @State private var expandedSheet: ExpandedSheet?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                switch viewModel.selectedTab {
                case .top:
                    topContent
                case .tracks:
                    tracksContent(viewModel.tracks)
                case .artists:
                    artistsGrid(viewModel.artists)
                case .releases:
                    releasesAdaptiveGrid(viewModel.releases)
                case .playlists:
                    playlistsAdaptiveGrid(viewModel.playlists)
                case .podcasts:
                    podcastsAdaptiveGrid(viewModel.podcasts)
                }

                loadMoreFooter
            }
            .padding(20)
        }
        .sheet(item: $expandedSheet) { sheet in
            switch sheet {
            case .artists(let title, let artists):
                GridSheet(title: title) {
                    ForEach(artists) { artist in
                        ArtistThumbnailView(artist: artist)
                            .onTapGesture {
                                expandedSheet = nil
                                appState.selectedDestination = .artist(id: artist.id)
                            }
                    }
                }
            case .releases(let title, let releases):
                GridSheet(title: title) {
                    ForEach(releases) { release in
                        ReleaseThumbnailView(release: release)
                            .onTapGesture {
                                expandedSheet = nil
                                appState.selectedDestination = .release(id: release.id)
                            }
                    }
                }
            }
        }
    }

    // MARK: - Top (mixed results)

    @ViewBuilder
    private var topContent: some View {
        if !viewModel.topArtists.isEmpty {
            section("Артисты", expandAction: {
                expandedSheet = .artists(title: "Артисты", items: viewModel.topArtists)
            }) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.topArtists) { artist in
                            ArtistThumbnailView(artist: artist)
                                .onTapGesture {
                                    appState.selectedDestination = .artist(id: artist.id)
                                }
                        }
                    }
                }
            }
        }

        if !viewModel.topTracks.isEmpty {
            section("Треки") {
                VStack(spacing: 4) {
                    ForEach(viewModel.topTracks) { track in
                        TrackRowView(track: track) {
                            playerService.playQueue(
                                viewModel.topTracks,
                                context: .search,
                                startAt: viewModel.topTracks.firstIndex(of: track) ?? 0
                            )
                        }
                    }
                }
            }
        }

        if !viewModel.topReleases.isEmpty {
            section("Альбомы", expandAction: {
                expandedSheet = .releases(title: "Альбомы", items: viewModel.topReleases)
            }) {
                releasesHScroll(viewModel.topReleases)
            }
        }

        if !viewModel.topPlaylists.isEmpty {
            section("Плейлисты") {
                playlistsHScroll(viewModel.topPlaylists)
            }
        }

        if !viewModel.topPodcasts.isEmpty {
            section("Подкасты") {
                podcastsHScroll(viewModel.topPodcasts)
            }
        }
    }

    // MARK: - Category views

    private func tracksContent(_ tracks: [SimpleTrack]) -> some View {
        VStack(spacing: 4) {
            ForEach(tracks) { track in
                TrackRowView(track: track) {
                    playerService.playQueue(
                        tracks,
                        context: .search,
                        startAt: tracks.firstIndex(of: track) ?? 0
                    )
                }
            }
        }
    }

    private func artistsGrid(_ artists: [SimpleArtist]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 16)], spacing: 16) {
            ForEach(artists) { artist in
                ArtistThumbnailView(artist: artist, size: 100)
                    .onTapGesture {
                        appState.selectedDestination = .artist(id: artist.id)
                    }
            }
        }
    }

    // MARK: - Adaptive grids

    private var gridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: minItemWidth, maximum: maxItemWidth), spacing: gridSpacing, alignment: .top)]
    }

    private func releasesAdaptiveGrid(_ releases: [SimpleRelease]) -> some View {
        LazyVGrid(columns: gridColumns, spacing: gridSpacing) {
            ForEach(releases) { release in
                ReleaseThumbnailView(release: release)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        appState.selectedDestination = .release(id: release.id)
                    }
            }
        }
    }

    private func playlistsAdaptiveGrid(_ playlists: [SimplePlaylist]) -> some View {
        LazyVGrid(columns: gridColumns, spacing: gridSpacing) {
            ForEach(playlists) { playlist in
                adaptiveCard(
                    image: playlist.image,
                    title: playlist.title,
                    subtitle: playlist.description
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    appState.selectedDestination = .playlist(id: playlist.id)
                }
            }
        }
    }

    private func podcastsAdaptiveGrid(_ podcasts: [SimplePodcast]) -> some View {
        LazyVGrid(columns: gridColumns, spacing: gridSpacing) {
            ForEach(podcasts) { podcast in
                adaptiveCard(
                    image: podcast.image,
                    title: podcast.title,
                    subtitle: nil
                )
            }
        }
    }

    private func adaptiveCard(image: ZvukMusic.Image?, title: String, subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Group {
                if let src = image?.getURL(width: 360, height: 360),
                   let url = URL(string: src) {
                    CachedAsyncImage(url: url) { img in
                        img.scaledToFill()
                    } placeholder: {
                        placeholderView
                    }
                } else {
                    placeholderView
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Text(title)
                .font(.callout.weight(.medium))
                .lineLimit(2)

            if let desc = subtitle, !desc.isEmpty {
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }

    private var placeholderView: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(.quaternary)
            .overlay {
                Image(systemName: "music.note.list")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            }
    }

    // MARK: - Horizontal scrolls (for Top tab)

    private func releasesHScroll(_ releases: [SimpleRelease]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(releases) { release in
                    ReleaseThumbnailView(release: release, size: 160)
                        .onTapGesture {
                            appState.selectedDestination = .release(id: release.id)
                        }
                }
            }
        }
    }

    private func playlistsHScroll(_ playlists: [SimplePlaylist]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(playlists) { playlist in
                    fixedCard(image: playlist.image, title: playlist.title)
                }
            }
        }
    }

    private func podcastsHScroll(_ podcasts: [SimplePodcast]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(podcasts) { podcast in
                    fixedCard(image: podcast.image, title: podcast.title)
                }
            }
        }
    }

    private func fixedCard(image: ZvukMusic.Image?, title: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            coverImage(image, size: 160)
            Text(title)
                .font(.caption)
                .lineLimit(2)
        }
        .frame(width: 160)
    }

    private func coverImage(_ image: ZvukMusic.Image?, size: CGFloat) -> some View {
        Group {
            if let urlStr = image?.getURL(width: Int(size * 2), height: Int(size * 2)),
               let url = URL(string: urlStr) {
                CachedAsyncImage(url: url) { img in
                    img.scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.quaternary)
                }
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.quaternary)
                    .overlay {
                        Image(systemName: "music.note")
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .frame(width: size, height: size)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Load more footer

    @ViewBuilder
    private var loadMoreFooter: some View {
        if viewModel.canLoadMore {
            HStack {
                Spacer()
                if viewModel.isLoadingMore {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button("Загрузить ещё") {
                        viewModel.loadMore(client: appState.client)
                    }
                    .font(.callout)
                }
                Spacer()
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Section helper

    private func section<Content: View>(_ title: String, expandAction: (() -> Void)? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.title3.weight(.semibold))

                if let expandAction {
                    Spacer()

                    Button {
                        expandAction()
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Показать все")
                }
            }
            content()
        }
    }
}
