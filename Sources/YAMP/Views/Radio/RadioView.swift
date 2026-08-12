import SwiftUI
import ZvukMusic

/// Каталог интернет-радио: сетка логотипов с локальным поиском по названию.
///
/// Каталог невелик и грузится целиком одним запросом, поэтому фильтрация идёт
/// по загруженному массиву и в сеть не ходит.
struct RadioView: View {
    @Environment(CacheService.self) private var cacheService

    @State private var stations: [RadioStation] = []
    @State private var searchText = ""
    @State private var isLoading = true
    @State private var appError: AppError?

    private var filteredStations: [RadioStation] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return stations }
        return stations.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                catalogue
            }
        }
        .task { await loadStations() }
        .errorAlert($appError)
    }

    private var catalogue: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 16, alignment: .top)],
                    spacing: 16
                ) {
                    ForEach(filteredStations) { station in
                        RadioStationCard(station: station)
                    }
                }

                if filteredStations.isEmpty {
                    Text("Ничего не найдено")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 40)
                }
            }
            .padding(20)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Радио")
                .font(.largeTitle.weight(.bold))

            Spacer()

            TextField("Поиск станции", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 240)
        }
    }

    private func loadStations() async {
        guard stations.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            stations = try await cacheService.getRadioStations()
        } catch {
            appError = AppError.from(error)
        }
    }
}
