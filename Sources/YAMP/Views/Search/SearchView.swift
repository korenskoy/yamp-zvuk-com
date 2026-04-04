import SwiftUI
import ZvukMusic

struct SearchView: View {
    @Environment(AppState.self) private var appState
    @Environment(PlayerService.self) private var playerService
    @Bindable var viewModel: SearchViewModel

    var body: some View {
        VStack(spacing: 0) {
            GlassTabBar(selection: $viewModel.selectedTab) {
                viewModel.onTabChanged(client: appState.client)
            }
            .padding(.vertical, 8)
            .opacity(viewModel.hasSearched ? 1 : 0)

            searchContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .errorAlert($viewModel.appError)
    }

    @ViewBuilder
    private var searchContent: some View {
        if viewModel.isLoading && viewModel.hasSearched {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if !viewModel.hasSearched {
            ContentUnavailableView(
                "Начните поиск",
                systemImage: "magnifyingglass",
                description: Text("Введите название трека, артиста или альбома")
            )
        } else if viewModel.isEmpty {
            ContentUnavailableView(
                "Ничего не найдено",
                systemImage: "magnifyingglass",
                description: Text("Попробуйте другой запрос")
            )
        } else {
            SearchResultsView(viewModel: viewModel)
        }
    }
}
