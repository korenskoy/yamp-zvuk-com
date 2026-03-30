import Foundation
import ZvukMusic

@MainActor
@Observable
final class WaveViewModel {
    private static let stateKey = "waveFilters"

    // XY pad state (0.0...1.0)
    var energy: Double = 0.5 { didSet { saveFilters() } }
    var fun: Double = 0.5 { didSet { saveFilters() } }

    // Popularity filter
    var popularity: WavePopularity? { didSet { saveFilters() } }

    // Genre + language filters
    var selectedGenres: Set<WaveGenre> = [] { didSet { saveFilters() } }
    var language: WaveLanguage? { didSet { saveFilters() } }
    var instrumental = false { didSet { saveFilters() } }

    // State
    var isLoading = false
    var appError: AppError?
    var statusMessage: String?

    init() {
        restoreFilters()
    }

    var filterSummary: String {
        if selectedGenres.isEmpty && language == nil && !instrumental {
            return "Все"
        }
        var parts: [String] = []
        for genre in selectedGenres {
            parts.append(genre.displayName)
        }
        if instrumental {
            parts.append("Без слов")
        } else if let lang = language {
            parts.append(lang == .russian ? "Русское" : "Зарубежное")
        }
        return parts.joined(separator: ", ")
    }

    func launchWave(client: ZvukClient?, playerService: PlayerService) async {
        guard let client else { return }
        isLoading = true
        appError = nil
        statusMessage = nil
        defer { isLoading = false }

        do {
            let params = PlaybackContext.WaveParams(
                energy: (energy * 100).rounded() / 100,
                fun: (fun * 100).rounded() / 100,
                genres: Array(selectedGenres),
                language: language,
                instrumental: instrumental,
                popularity: popularity
            )
            let simple = try await params.fetchTracks(client: client)
            guard !simple.isEmpty else {
                statusMessage = "Треки не найдены"
                return
            }
            playerService.playQueue(simple, context: .wave(params: params))
        } catch {
            self.appError = AppError.from(error)
        }
    }

    func resetFilters() {
        energy = 0.5
        fun = 0.5
        popularity = nil
        selectedGenres = []
        language = nil
        instrumental = false
    }

    // MARK: - Persistence

    private struct SavedFilters: Codable {
        var energy: Double
        var fun: Double
        var popularity: WavePopularity?
        var selectedGenres: [WaveGenre]
        var language: WaveLanguage?
        var instrumental: Bool
    }

    private func saveFilters() {
        let saved = SavedFilters(
            energy: energy, fun: fun,
            popularity: popularity,
            selectedGenres: Array(selectedGenres),
            language: language,
            instrumental: instrumental
        )
        if let data = try? JSONEncoder().encode(saved) {
            UserDefaults.standard.set(data, forKey: Self.stateKey)
        }
    }

    private func restoreFilters() {
        guard let data = UserDefaults.standard.data(forKey: Self.stateKey),
              let saved = try? JSONDecoder().decode(SavedFilters.self, from: data) else { return }
        energy = saved.energy
        fun = saved.fun
        popularity = saved.popularity
        selectedGenres = Set(saved.selectedGenres)
        language = saved.language
        instrumental = saved.instrumental
    }
}

extension WaveGenre {
    var displayName: String {
        switch self {
        case .classical: "Классика"
        case .ambient: "Эмбиент"
        case .electronic: "Электроника"
        case .folk: "Фолк"
        case .hipHop: "Хип-хоп"
        case .indie: "Инди"
        case .instrumental: "Инструментал"
        case .metal: "Метал"
        case .pop: "Поп"
        case .rock: "Рок"
        case .soundtrack: "Саундтреки"
        }
    }
}
