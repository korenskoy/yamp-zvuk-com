import SwiftUI
import ZvukMusic

private struct GlassBottomPanelModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: .rect(cornerRadius: 12))
        } else {
            content.background(.bar)
        }
    }
}

struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @Environment(CacheService.self) private var cacheService
    @Environment(CollectionService.self) private var collectionService
    @Environment(UpdateService.self) private var updateService
    @Environment(LastFMService.self) private var lastFMService
    @State private var playlistsVM = PlaylistsViewModel()
    @AppStorage("playlistOrder") private var playlistOrderRaw = ""

    // Сохранённый вручную порядок; новые плейлисты добавляются в конец.
    private var orderedPlaylists: [SimplePlaylist] {
        let byId = Dictionary(playlistsVM.playlists.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let order = playlistOrderRaw.split(separator: "\n").map(String.init)
        let known = Set(order)
        return order.compactMap { byId[$0] } + playlistsVM.playlists.filter { !known.contains($0.id) }
    }

    private func movePlaylists(from source: IndexSet, to destination: Int) {
        var items = orderedPlaylists
        items.move(fromOffsets: source, toOffset: destination)
        playlistOrderRaw = items.map(\.id).joined(separator: "\n")
    }

    var body: some View {
        @Bindable var state = appState

        List(selection: $state.selectedDestination) {
            Section {
                Label("Главная", systemImage: "music.note")
                    .tag(NavigationDestination.home)

                Label("Популярное", systemImage: "flame")
                    .tag(NavigationDestination.popular)

                Label("Поиск", systemImage: "magnifyingglass")
                    .tag(NavigationDestination.search)

                Label("Моя коллекция", systemImage: "heart.fill")
                    .tag(NavigationDestination.collection)

                Label("История", systemImage: "clock")
                    .tag(NavigationDestination.history)

                Label("Волна", systemImage: "waveform")
                    .tag(NavigationDestination.wave)
            }

            Section("Плейлисты") {
                if playlistsVM.isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else if playlistsVM.appError != nil {
                    Text("Не удалось загрузить")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                } else if playlistsVM.playlists.isEmpty {
                    Text("Нет плейлистов")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                } else {
                    ForEach(orderedPlaylists) { playlist in
                        Label(playlist.title, systemImage: "music.note.list")
                            .tag(NavigationDestination.playlist(id: playlist.id))
                            .contextMenu {
                                Button(role: .destructive) {
                                    Task {
                                        await playlistsVM.deletePlaylist(playlist.id, client: appState.client, cache: cacheService)
                                    }
                                } label: {
                                    Label("Удалить", systemImage: "trash")
                                }
                            }
                    }
                    .onMove(perform: movePlaylists)
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 180)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                if #unavailable(macOS 26.0) {
                    Divider()
                }
                VStack(spacing: 2) {
                    sidebarButton(
                        "Новости",
                        icon: "bell",
                        destination: .news,
                        badge: appState.hasUnreadNews
                    )
                    sidebarButton(
                        "Чёрный список",
                        icon: "hand.thumbsdown",
                        destination: .blacklist
                    )
                    sidebarButton(
                        "Настройки",
                        icon: "gearshape",
                        destination: .settings,
                        badge: updateService.availableUpdate != nil || lastFMService.sessionInvalidated
                    )
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
            }
            .modifier(GlassBottomPanelModifier())
        }
        .task(id: collectionService.playlistsVersion) {
            await playlistsVM.load(cache: cacheService)
        }
    }

    private func sidebarButton(_ title: String, icon: String, destination: NavigationDestination, badge: Bool = false) -> some View {
        Button {
            appState.selectedDestination = destination
        } label: {
            HStack {
                Label(title, systemImage: icon)
                Spacer()
                if badge {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(
                appState.selectedDestination == destination
                    ? AnyShapeStyle(.selection)
                    : AnyShapeStyle(.clear)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}
