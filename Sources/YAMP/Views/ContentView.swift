import SwiftUI
import AppKit

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(LogStore.self) private var logStore
    @State private var searchViewModel = SearchViewModel()

    var body: some View {
        VStack(spacing: 0) {
            NavigationSplitView {
                SidebarView()
            } detail: {
                detailView
                    .searchable(text: $searchViewModel.query, placement: .toolbar, prompt: "Поиск...")
                    .searchSuggestions {
                        if let suggestion = searchViewModel.autocompleteSuggestion {
                            Text(suggestion)
                                .searchCompletion(suggestion)
                        }
                    }
                    .onSubmit(of: .search) {
                        if appState.selectedDestination != .search {
                            appState.selectedDestination = .search
                        }
                        searchViewModel.onSubmit(client: appState.client)
                    }
                    .onChange(of: searchViewModel.query) {
                        if !searchViewModel.query.isEmpty && appState.selectedDestination != .search {
                            appState.selectedDestination = .search
                        }
                        searchViewModel.onQueryChanged(client: appState.client)
                    }
                    .toolbar {
                        ToolbarItemGroup(placement: .navigation) {
                            Button {
                                appState.goBack()
                            } label: {
                                Image(systemName: "chevron.left")
                            }
                            .disabled(!appState.canGoBack)
                            .keyboardShortcut("[", modifiers: .command)

                            Button {
                                appState.goForward()
                            } label: {
                                Image(systemName: "chevron.right")
                            }
                            .disabled(!appState.canGoForward)
                            .keyboardShortcut("]", modifiers: .command)
                        }
                    }
            }

            PlayerBarView()
            LogPanelView()
        }
        .frame(minWidth: 800, minHeight: 500)
        .overlay {
            MouseNavigationHandler(
                onBack: { appState.goBack() },
                onForward: { appState.goForward() }
            )
            .frame(width: 0, height: 0)
        }
        .task {
            logStore.attach(to: appState.client)
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch appState.selectedDestination {
        case .home:
            HomeView()
        case .search:
            SearchView(viewModel: searchViewModel)
        case .news:
            NewsView()
        case .collection:
            CollectionView()
        case .history:
            HistoryView()
        case .wave:
            WaveView()
        case .playlist(let id):
            PlaylistView(playlistId: id)
        case .artist(let id):
            ArtistView(artistId: id)
        case .release(let id):
            ReleaseView(releaseId: id)
        case .blacklist:
            BlacklistView()
        case .settings:
            SettingsView()
        case .nowPlaying:
            NowPlayingView()
        default:
            Text("Выберите раздел")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}