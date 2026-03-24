import SwiftUI
import ZvukMusic

struct BlacklistView: View {
    @Environment(AppState.self) private var appState
    @Environment(CacheService.self) private var cacheService
    @State private var viewModel = BlacklistViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Чёрный список")
                    .font(.largeTitle.bold())
                    .padding(.horizontal)

                Text("Скрытые артисты и треки")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if viewModel.artists.isEmpty && viewModel.tracks.isEmpty {
                    ContentUnavailableView(
                        "Пусто",
                        systemImage: "hand.thumbsdown",
                        description: Text("Вы пока никого не заблокировали")
                    )
                    .frame(maxWidth: .infinity, minHeight: 300)
                } else {
                    if !viewModel.artists.isEmpty {
                        artistsSection
                    }
                    if !viewModel.tracks.isEmpty {
                        tracksSection
                    }
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
        .task {
            await viewModel.load(client: appState.client, cache: cacheService)
        }
    }

    // MARK: - Artists

    private var artistsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Артисты")
                .font(.title3.bold())
                .padding(.horizontal)

            LazyVStack(spacing: 0) {
                ForEach(viewModel.artists) { artist in
                    HStack(spacing: 12) {
                        artistImage(artist)

                        Text(artist.title)
                            .font(.body)
                            .lineLimit(1)

                        Spacer()

                        Button {
                            Task {
                                await viewModel.unhideArtist(artist.id, client: appState.client, cache: cacheService)
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Убрать из чёрного списка")
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        appState.selectedDestination = .artist(id: artist.id)
                    }

                    Divider().padding(.leading, 56)
                }
            }
        }
    }

    private func artistImage(_ artist: Artist) -> some View {
        Group {
            if let src = artist.image?.getURL(width: 80, height: 80),
               let url = URL(string: src) {
                CachedAsyncImage(url: url) { image in
                    image.scaledToFill()
                } placeholder: {
                    Circle().fill(.quaternary)
                }
            } else {
                Circle().fill(.quaternary)
                    .overlay {
                        Image(systemName: "person.fill")
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(Circle())
    }

    // MARK: - Tracks

    private var tracksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Треки")
                .font(.title3.bold())
                .padding(.horizontal)

            LazyVStack(spacing: 0) {
                ForEach(viewModel.tracks) { track in
                    HStack(spacing: 12) {
                        trackImage(track)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(track.title)
                                .font(.body)
                                .lineLimit(1)

                            Text(track.artists.map(\.title).joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Button {
                            Task {
                                await viewModel.unhideTrack(track.id, client: appState.client, cache: cacheService)
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Убрать из чёрного списка")
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 6)

                    Divider().padding(.leading, 56)
                }
            }
        }
    }

    private func trackImage(_ track: Track) -> some View {
        Group {
            if let src = track.release?.image?.getURL(width: 80, height: 80),
               let url = URL(string: src) {
                CachedAsyncImage(url: url) { image in
                    image.scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 6).fill(.quaternary)
                }
            } else {
                RoundedRectangle(cornerRadius: 6).fill(.quaternary)
                    .overlay {
                        Image(systemName: "music.note")
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
