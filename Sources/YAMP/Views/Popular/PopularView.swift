import SwiftUI
import ZvukMusic

private struct ExpandedPlaylists: Identifiable {
    let id = UUID()
    let title: String
    let items: [SimplePlaylist]
}

private struct ExpandedReleases: Identifiable {
    let id = UUID()
    let title: String
    let items: [SimpleRelease]
}

private struct ExpandedArtists: Identifiable {
    let id = UUID()
    let title: String
    let items: [SimpleArtist]
}

struct PopularView: View {
    @Environment(AppState.self) private var appState
    @Environment(CacheService.self) private var cacheService
    @Environment(PlayerService.self) private var playerService
    @State private var viewModel = PopularViewModel()
    @State private var expandedPlaylists: ExpandedPlaylists?
    @State private var expandedReleases: ExpandedReleases?
    @State private var expandedArtists: ExpandedArtists?

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("Популярное")
                            .font(.largeTitle.bold())
                            .padding(.horizontal)

                        ForEach(viewModel.sections) { section in
                            sectionView(section)
                        }

                        if let error = viewModel.errorMessage {
                            Text(error)
                                .foregroundStyle(.red)
                                .font(.callout)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
        .task {
            await viewModel.load(cache: cacheService)
        }
        .sheet(item: $expandedPlaylists) { item in
            GridSheet(title: item.title) {
                ForEach(item.items) { playlist in
                    EditorialPlaylistCardView(playlist: playlist)
                }
            }
        }
        .sheet(item: $expandedReleases) { item in
            GridSheet(title: item.title) {
                ForEach(item.items) { release in
                    ReleaseThumbnailView(release: release)
                        .contentShape(Rectangle())
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
                        .contentShape(Rectangle())
                        .onTapGesture {
                            expandedArtists = nil
                            appState.selectedDestination = .artist(id: artist.id)
                        }
                }
            }
        }
    }

    // MARK: - Section Routing

    @ViewBuilder
    private func sectionView(_ section: PopularSectionData) -> some View {
        switch section {
        case .playlists(_, let title, let items):
            playlistCarousel(title: title, playlists: items)
        case .releases(_, let title, let items):
            releaseCarousel(title: title, releases: items)
        case .artists(_, let title, let items):
            artistCarousel(title: title, artists: items)
        case .tracks(_, let title, let playlistId, let items):
            trackListSection(title: title, playlistId: playlistId, tracks: items)
        }
    }

    // MARK: - Playlist Carousel

    private func playlistCarousel(title: String, playlists: [SimplePlaylist]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(title: title) {
                expandedPlaylists = ExpandedPlaylists(title: title, items: playlists)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(playlists) { playlist in
                        EditorialPlaylistCardView(playlist: playlist)
                            .frame(width: 160)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Release Carousel

    private func releaseCarousel(title: String, releases: [SimpleRelease]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(title: title) {
                expandedReleases = ExpandedReleases(title: title, items: releases)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(releases) { release in
                        ReleaseThumbnailView(release: release, size: 160)
                            .onTapGesture {
                                appState.selectedDestination = .release(id: release.id)
                            }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Artist Carousel

    private func artistCarousel(title: String, artists: [SimpleArtist]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(title: title) {
                expandedArtists = ExpandedArtists(title: title, items: artists)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(artists) { artist in
                        ArtistThumbnailView(artist: artist)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                appState.selectedDestination = .artist(id: artist.id)
                            }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Track List

    private func trackListSection(title: String, playlistId: String, tracks: [SimpleTrack]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                appState.selectedDestination = .playlist(id: playlistId)
            } label: {
                HStack(spacing: 4) {
                    Text(title)
                        .font(.title3.weight(.semibold))
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal)

            let visibleTracks = Array(tracks.prefix(8))
            let midpoint = (visibleTracks.count + 1) / 2

            HStack(alignment: .top, spacing: 24) {
                VStack(spacing: 4) {
                    ForEach(Array(visibleTracks.prefix(midpoint).enumerated()), id: \.element.id) { index, track in
                        numberedTrackRow(track: track, index: index, allTracks: tracks, playlistId: playlistId)
                    }
                }

                if visibleTracks.count > midpoint {
                    VStack(spacing: 4) {
                        ForEach(Array(visibleTracks.dropFirst(midpoint).enumerated()), id: \.element.id) { offset, track in
                            let index = midpoint + offset
                            numberedTrackRow(track: track, index: index, allTracks: tracks, playlistId: playlistId)
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private func numberedTrackRow(track: SimpleTrack, index: Int, allTracks: [SimpleTrack], playlistId: String) -> some View {
        HStack(spacing: 8) {
            Text("\(index + 1)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 20, alignment: .trailing)

            TrackRowView(track: track) {
                playerService.playQueue(allTracks, context: .playlist(id: playlistId), startAt: index)
            }
        }
    }

    // MARK: - Section Header

    private func sectionHeader(title: String, onExpand: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
                .font(.title3.weight(.semibold))

            Spacer()

            Button {
                onExpand()
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Показать все")
        }
        .padding(.horizontal)
    }
}
