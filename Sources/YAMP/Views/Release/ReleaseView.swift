import SwiftUI
import ZvukMusic

struct ReleaseView: View {
    let releaseId: String
    @Environment(AppState.self) private var appState
    @Environment(PlayerService.self) private var playerService
    @Environment(CollectionService.self) private var collectionService
    @Environment(CacheService.self) private var cacheService
    @State private var viewModel: ReleaseViewModel
    @State private var expandedReleases: [SimpleRelease]?

    init(releaseId: String) {
        self.releaseId = releaseId
        self._viewModel = State(initialValue: ReleaseViewModel(releaseId: releaseId))
    }

    var body: some View {
        ZStack {
            if viewModel.isLoading {
                ProgressView()
            } else if let release = viewModel.release {
                releaseContent(release)
            } else {
                ContentUnavailableView(
                    "Не удалось загрузить",
                    systemImage: "exclamationmark.triangle"
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .errorAlert($viewModel.appError)
        .task(id: releaseId) {
            viewModel = ReleaseViewModel(releaseId: releaseId)
            await viewModel.load(cache: cacheService)
        }
        .sheet(isPresented: Binding(
            get: { expandedReleases != nil },
            set: { if !$0 { expandedReleases = nil } }
        )) {
            if let releases = expandedReleases {
                GridSheet(title: "Похожие альбомы") {
                    ForEach(releases) { release in
                        ReleaseThumbnailView(release: release)
                            .onTapGesture {
                                expandedReleases = nil
                                appState.selectedDestination = .release(id: release.id)
                            }
                    }
                }
            }
        }
    }

    private func releaseContent(_ release: Release) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ReleaseHeaderView(
                    release: release,
                    isLiked: collectionService.isReleaseLiked(release.id),
                    onPlayAll: {
                        if !release.tracks.isEmpty {
                            playerService.playQueue(release.tracks, context: .album(id: release.id))
                        }
                    },
                    onToggleLike: {
                        Task {
                            await collectionService.toggleReleaseLike(release.id, client: appState.client)
                        }
                    },
                    onArtistTap: { artistId in
                        appState.selectedDestination = .artist(id: artistId)
                    }
                )

                if !release.tracks.isEmpty {
                    trackListSection(release)
                }

                if !release.related.isEmpty {
                    relatedSection(release)
                }
            }
            .padding(20)
        }
    }

    private func trackListSection(_ release: Release) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(release.tracks.enumerated()), id: \.element.id) { index, track in
                HStack(spacing: 8) {
                    Text("\(index + 1)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 24, alignment: .trailing)

                    TrackRowView(track: track) {
                        playerService.playQueue(
                            release.tracks,
                            context: .album(id: release.id),
                            startAt: index
                        )
                    }
                }
            }
        }
    }

    private func relatedSection(_ release: Release) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Похожие альбомы")
                    .font(.title3.weight(.semibold))

                Spacer()

                Button {
                    expandedReleases = release.related
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Показать все")
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(release.related) { related in
                        ReleaseThumbnailView(release: related, size: 160)
                            .onTapGesture {
                                appState.selectedDestination = .release(id: related.id)
                            }
                    }
                }
            }
        }
    }
}
