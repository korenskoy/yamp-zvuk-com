import SwiftUI
import ZvukMusic

private struct ExpandedItem<T>: Identifiable {
    let id = UUID()
    let title: String
    let items: [T]
}

struct ArtistView: View {
    let artistId: String
    @Environment(AppState.self) private var appState
    @Environment(PlayerService.self) private var playerService
    @Environment(CollectionService.self) private var collectionService
    @Environment(CacheService.self) private var cacheService
    @State private var viewModel: ArtistViewModel
    @State private var expandedReleases: ExpandedItem<SimpleRelease>?
    @State private var expandedArtists: ExpandedItem<SimpleArtist>?

    init(artistId: String) {
        self.artistId = artistId
        self._viewModel = State(initialValue: ArtistViewModel(artistId: artistId))
    }

    var body: some View {
        ZStack {
            if viewModel.isLoading {
                ProgressView()
            } else if let error = viewModel.error {
                ContentUnavailableView(
                    "Ошибка загрузки",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            } else if let artist = viewModel.artist {
                artistContent(artist)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: artistId) {
            viewModel = ArtistViewModel(artistId: artistId)
            await viewModel.load(cache: cacheService)
        }
    }

    private func artistContent(_ artist: Artist) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ArtistHeaderView(
                    artist: artist,
                    subscriberCount: viewModel.subscriberCount,
                    isSubscribed: collectionService.isArtistLiked(artist.id),
                    onPlay: {
                        guard !artist.popularTracks.isEmpty else { return }
                        playerService.playQueue(
                            artist.popularTracks,
                            context: .artist(id: artist.id)
                        )
                    },
                    onShuffle: {
                        guard !artist.popularTracks.isEmpty else { return }
                        playerService.playQueue(
                            artist.popularTracks.shuffled(),
                            context: .artist(id: artist.id)
                        )
                    },
                    onRadio: {
                        Task {
                            guard let client = appState.client else { return }
                            let result = try? await client.getRadioByArtist(artist.id)
                            if let tracks = result?.tracks, !tracks.isEmpty {
                                let simple = tracks.map {
                                    SimpleTrack(id: $0.id, title: $0.title, duration: $0.duration,
                                                explicit: $0.explicit, artists: $0.artists, release: $0.release)
                                }
                                playerService.playQueue(
                                    simple,
                                    context: .radioArtist(id: artist.id)
                                )
                            }
                        }
                    },
                    onToggleSubscribe: {
                        Task {
                            await collectionService.toggleArtistLike(artist.id, client: appState.client)
                        }
                    },
                    onHideArtist: {
                        Task {
                            _ = try? await appState.client?.addToHidden(artist.id, type: .artist)
                        }
                    }
                )

                if !artist.popularTracks.isEmpty {
                    popularTracksSection(artist)
                }

                let albums = artist.releases.filter { $0.type == .album || $0.type == .ep || $0.type == .compilation }
                let singles = artist.releases.filter { $0.type == .single }

                if !albums.isEmpty {
                    releasesGrid(title: "Альбомы", releases: albums)
                }

                if !singles.isEmpty {
                    releasesGrid(title: "Синглы", releases: singles)
                }

                if !artist.relatedArtists.isEmpty {
                    relatedArtistsSection(artist)
                }
            }
            .padding(20)
        }
        .sheet(item: $expandedReleases) { item in
            GridSheet(title: item.title) {
                ForEach(item.items) { release in
                    ReleaseThumbnailView(release: release)
                        .onTapGesture {
                            expandedReleases = nil
                            appState.selectedDestination = .release(id: release.id)
                        }
                }
            }
        }
        .sheet(item: $expandedArtists) { item in
            GridSheet(title: item.title) {
                ForEach(item.items) { artist in
                    ArtistThumbnailView(artist: artist)
                        .onTapGesture {
                            expandedArtists = nil
                            appState.selectedDestination = .artist(id: artist.id)
                        }
                }
            }
        }
    }

    // MARK: - Popular Tracks (two-column)

    private func popularTracksSection(_ artist: Artist) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Популярные треки")
                .font(.title3.weight(.semibold))

            let tracks = Array(artist.popularTracks.prefix(12))
            let midpoint = (tracks.count + 1) / 2

            HStack(alignment: .top, spacing: 24) {
                VStack(spacing: 4) {
                    ForEach(Array(tracks.prefix(midpoint).enumerated()), id: \.element.id) { index, track in
                        trackRow(track: track, index: index, allTracks: artist.popularTracks, artistId: artist.id)
                    }
                }

                if tracks.count > midpoint {
                    VStack(spacing: 4) {
                        ForEach(Array(tracks.dropFirst(midpoint).enumerated()), id: \.element.id) { offset, track in
                            let index = midpoint + offset
                            trackRow(track: track, index: index, allTracks: artist.popularTracks, artistId: artist.id)
                        }
                    }
                }
            }
        }
    }

    private func trackRow(track: SimpleTrack, index: Int, allTracks: [SimpleTrack], artistId: String) -> some View {
        HStack(spacing: 8) {
            Text("\(index + 1)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 20, alignment: .trailing)

            TrackRowView(track: track) {
                playerService.playQueue(
                    allTracks,
                    context: .artist(id: artistId),
                    startAt: index
                )
            }

            likeButton(for: track)
        }
    }

    // MARK: - Track Like Button

    private func likeButton(for track: SimpleTrack) -> some View {
        Button {
            Task {
                await collectionService.toggleTrackLike(track, client: appState.client)
            }
        } label: {
            Image(systemName: collectionService.isTrackLiked(track.id) ? "heart.fill" : "heart")
                .font(.caption)
                .foregroundStyle(collectionService.isTrackLiked(track.id) ? .red : .secondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Releases Grid

    private func releasesGrid(title: String, releases: [SimpleRelease]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.title3.weight(.semibold))

                Spacer()

                Button {
                    expandedReleases = ExpandedItem(title: title, items: releases)
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Показать все")
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(releases) { release in
                        ReleaseThumbnailView(release: release, size: 160)
                            .onTapGesture {
                                appState.selectedDestination = .release(id: release.id)
                            }
                    }
                }
            }
        }
    }

    // MARK: - Related Artists

    private func relatedArtistsSection(_ artist: Artist) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Похожие артисты")
                    .font(.title3.weight(.semibold))

                Spacer()

                Button {
                    expandedArtists = ExpandedItem(title: "Похожие артисты", items: artist.relatedArtists)
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Показать все")
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(artist.relatedArtists) { related in
                        ArtistThumbnailView(artist: related)
                            .onTapGesture {
                                appState.selectedDestination = .artist(id: related.id)
                            }
                    }
                }
            }
        }
    }
}
