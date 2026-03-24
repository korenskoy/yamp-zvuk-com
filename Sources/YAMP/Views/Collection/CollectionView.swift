import SwiftUI
import ZvukMusic

struct CollectionView: View {
    @Environment(AppState.self) private var appState
    @Environment(PlayerService.self) private var playerService
    @Environment(CollectionService.self) private var collectionService
    @Environment(CacheService.self) private var cacheService
    @State private var viewModel = CollectionViewModel()

    var body: some View {
        VStack(spacing: 0) {
            GlassTabBar(selection: $viewModel.selectedTab)
                .padding(.vertical, 8)

            ZStack {
                if viewModel.isLoading {
                    ProgressView()
                } else {
                    switch viewModel.selectedTab {
                    case .tracks:
                        likedTracksView
                    case .artists:
                        likedArtistsView
                    case .releases:
                        likedReleasesView
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task(id: viewModel.selectedTab) {
            await viewModel.load(cache: cacheService, collectionService: collectionService)
        }
    }

    private var likedTracksView: some View {
        Group {
            if viewModel.likedTracks.isEmpty {
                ContentUnavailableView(
                    "Нет лайкнутых треков",
                    systemImage: "heart",
                    description: Text("Нажмите на сердечко, чтобы добавить трек")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(viewModel.likedTracks) { track in
                            let simple = SimpleTrack(
                                id: track.id,
                                title: track.title,
                                duration: track.duration,
                                explicit: track.explicit,
                                artists: track.artists,
                                release: track.release
                            )
                            TrackRowView(track: simple) {
                                let simpleTracks = viewModel.likedTracks.map { t in
                                    SimpleTrack(id: t.id, title: t.title, duration: t.duration,
                                                explicit: t.explicit, artists: t.artists, release: t.release)
                                }
                                let idx = viewModel.likedTracks.firstIndex(where: { $0.id == track.id }) ?? 0
                                playerService.playQueue(simpleTracks, context: .liked, startAt: idx)
                            }
                        }
                    }
                    .padding(20)
                }
            }
        }
    }

    private var likedArtistsView: some View {
        Group {
            if viewModel.likedArtists.isEmpty {
                ContentUnavailableView(
                    "Нет лайкнутых артистов",
                    systemImage: "heart",
                    description: Text("Добавьте артистов в коллекцию")
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 16)], spacing: 16) {
                        ForEach(viewModel.likedArtists) { artist in
                            let simple = SimpleArtist(id: artist.id, title: artist.title, image: artist.image)
                            ArtistThumbnailView(artist: simple, size: 100)
                                .onTapGesture {
                                    appState.selectedDestination = .artist(id: artist.id)
                                }
                        }
                    }
                    .padding(20)
                }
            }
        }
    }

    private var likedReleasesView: some View {
        Group {
            if viewModel.likedReleases.isEmpty {
                ContentUnavailableView(
                    "Нет лайкнутых альбомов",
                    systemImage: "heart",
                    description: Text("Добавьте альбомы в коллекцию")
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 16, alignment: .top)], spacing: 16) {
                        ForEach(viewModel.likedReleases) { release in
                            let simple = SimpleRelease(
                                id: release.id, title: release.title, date: release.date,
                                type: release.type, image: release.image, explicit: release.explicit,
                                artists: release.artists
                            )
                            ReleaseThumbnailView(release: simple)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    appState.selectedDestination = .release(id: release.id)
                                }
                        }
                    }
                    .padding(20)
                }
            }
        }
    }
}
