import Foundation

/// Данные «сейчас в эфире», которые отдаёт `RadioStation.metaDataUrl`.
///
/// Формат у каждого провайдера свой: `emgsound` и `meta.fmgid.com` присылают
/// `uniqueid`/`artist`/`title`/`cover`, `volna.top` — те же смыслы под другими
/// ключами плюс расписание, детские потоки Zvuk добавляют `runtime`. Один и тот
/// же адрес может ответить и полным набором, и одним `uniqueid`, поэтому
/// обязательных полей здесь нет вовсе: отсутствие данных — норма, а не ошибка.
struct RadioNowPlaying: Equatable, Sendable {
    /// Идентификатор записи в эфире; по нему определяется смена трека.
    let id: String?
    let artist: String?
    let title: String?
    let coverURL: String?
    let album: String?
    /// Длительность трека в секундах, если провайдер её сообщил.
    let runtime: Int?
    /// Момент окончания текущего трека, если провайдер сообщил расписание.
    let endsAt: Date?

    /// Строка для плеера: «исполнитель — название».
    ///
    /// `nil` означает, что показывать нечего: станция прислала пустые поля
    /// (так выглядит реклама и техническая пауза) либо один только `uniqueid`.
    var displayLine: String? {
        let parts = [artist, title]
            .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " — ")
    }
}

extension RadioNowPlaying: Decodable {
    private enum CodingKeys: String, CodingKey {
        case uniqueid, id, artist, title, album, runtime
        case cover, coverURL = "cover_url"
        case stopNow = "stop_now"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = Self.string(from: container, forKey: .uniqueid) ?? Self.string(from: container, forKey: .id)
        artist = Self.string(from: container, forKey: .artist)
        title = Self.string(from: container, forKey: .title)
        album = Self.string(from: container, forKey: .album)
        coverURL = Self.string(from: container, forKey: .cover) ?? Self.string(from: container, forKey: .coverURL)

        if let seconds = try? container.decodeIfPresent(Int.self, forKey: .runtime) {
            runtime = seconds
        } else {
            runtime = Self.string(from: container, forKey: .runtime).flatMap(Int.init)
        }

        endsAt = Self.string(from: container, forKey: .stopNow).flatMap(Self.scheduleFormatter.date(from:))
    }

    /// Провайдеры смешивают строки и числа в одних и тех же полях.
    private static func string(from container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> String? {
        if let value = try? container.decodeIfPresent(String.self, forKey: key) { return value }
        if let value = try? container.decodeIfPresent(Int.self, forKey: key) { return String(value) }
        return nil
    }

    /// `volna.top` отдаёт время как «2026-08-12 09:00:57» в московской зоне.
    private static let scheduleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Europe/Moscow")
        return formatter
    }()
}
