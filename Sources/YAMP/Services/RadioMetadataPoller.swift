import Foundation

/// Опрашивает `metaDataUrl` радиостанции и сообщает, когда в эфире сменился трек.
///
/// Расписание адаптивное, как у веб-клиента zvuk.com: тот берёт из ответа время
/// окончания текущего трека и планирует ровно один запрос на этот момент, а не
/// долбит сервер с постоянным интервалом. Провайдеры, которые расписания не дают,
/// опрашиваются раз в 30 секунд — втрое реже, чем запасные 10 секунд у веб-клиента.
@MainActor
final class RadioMetadataPoller {
    /// Шаг для провайдеров, не сообщающих, когда закончится трек.
    private static let fallbackInterval: Duration = .seconds(30)
    /// Ниже этого порога не опускаемся, даже если расписание говорит «уже пора».
    private static let minimumInterval: Duration = .seconds(10)

    private var task: Task<Void, Never>?
    private var lastId: String?
    private let decoder = JSONDecoder()

    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        config.httpAdditionalHeaders = ["User-Agent": UserAgent.browser]
        return URLSession(configuration: config)
    }()

    /// Начать опрос. Повторный вызов заменяет предыдущий цикл.
    func start(url: URL, onChange: @escaping @MainActor (RadioNowPlaying) -> Void) {
        stop()
        task = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let nowPlaying = await self.fetch(url: url)

                if let nowPlaying, nowPlaying.displayLine != nil, self.isNewEntry(nowPlaying) {
                    onChange(nowPlaying)
                }

                try? await Task.sleep(for: Self.delay(after: nowPlaying))
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        lastId = nil
    }

    /// Смену определяем по идентификатору записи, а когда его нет — по самой паре
    /// «исполнитель — название».
    private func isNewEntry(_ nowPlaying: RadioNowPlaying) -> Bool {
        let key = nowPlaying.id ?? nowPlaying.displayLine
        guard key != lastId else { return false }
        lastId = key
        return true
    }

    /// Ошибки и таймауты гасим молча: метаданные — украшение, из-за них звук
    /// прерываться не должен. Хосты чужие и падают независимо от Zvuk.
    private func fetch(url: URL) async -> RadioNowPlaying? {
        guard let (data, _) = try? await session.data(from: url) else { return nil }
        return try? decoder.decode(RadioNowPlaying.self, from: data)
    }

    private static func delay(after nowPlaying: RadioNowPlaying?) -> Duration {
        guard let nowPlaying else { return fallbackInterval }

        if let endsAt = nowPlaying.endsAt {
            let seconds = endsAt.timeIntervalSinceNow
            return seconds > 0 ? max(minimumInterval, .seconds(seconds)) : minimumInterval
        }
        if let runtime = nowPlaying.runtime, runtime > 0 {
            return max(minimumInterval, .seconds(runtime))
        }
        return fallbackInterval
    }
}
