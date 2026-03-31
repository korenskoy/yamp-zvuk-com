import SwiftUI
import ZvukMusic

struct WaveView: View {
    @Environment(AppState.self) private var appState
    @Environment(PlayerService.self) private var playerService
    @State private var viewModel = WaveViewModel()
    @State private var showGenreSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Персональная волна")
                    .font(.largeTitle.weight(.bold))

                WaveXYPadView(energy: $viewModel.energy, fun: $viewModel.fun)

                // Popularity
                HStack {
                    Text("Популярность")
                        .font(.callout.weight(.medium))

                    Spacer()

                    WavePopularitySlider(popularity: $viewModel.popularity)
                        .frame(maxWidth: 300)
                }

                // Genre + Language
                HStack {
                    Text("Жанры и Язык")
                        .font(.callout.weight(.medium))

                    Spacer()

                    Button {
                        showGenreSheet = true
                    } label: {
                        Text(viewModel.filterSummary)
                            .font(.callout)
                            .lineLimit(1)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.secondary.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                // Actions
                HStack(spacing: 12) {
                    Spacer()

                    Button("Сбросить фильтры") {
                        viewModel.resetFilters()
                    }
                    .buttonStyle(.bordered)

                    Button {
                        Task {
                            await viewModel.launchWave(client: appState.client, playerService: playerService)
                        }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label("Запустить волну", systemImage: "play.fill")
                        }
                    }
                    .buttonStyle(.accent)
                    .controlSize(.large)
                    .disabled(viewModel.isLoading)
                }

                if let statusMessage = viewModel.statusMessage {
                    Text(statusMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)
        }
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .errorAlert($viewModel.appError)
        .sheet(isPresented: $showGenreSheet) {
            WaveGenreSheet(
                selectedGenres: $viewModel.selectedGenres,
                language: $viewModel.language,
                instrumental: $viewModel.instrumental
            )
        }
    }
}
