import Foundation
import ZvukMusic

/// User-Agent, которым приложение представляется всем внешним хостам.
///
/// Zvuk отбивает не-браузерные агенты, а метаданные радио мы запрашиваем у
/// инфраструктуры самих станций, где нас окружают браузеры их веб-плееров, —
/// в обоих случаях выделяться незачем. Держим строку здесь, а не полагаемся
/// на дефолт внутри `ZvukMusic`: там она устаревает от релиза к релизу.
enum UserAgent {
    static let browser =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " +
        "(KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36"
}

/// Второй профиль сессии: мобильная строка клиента плюс заголовки `X-Timestamp`,
/// `X-App-Instance` и `X-Session-UID`.
///
/// Выключен по умолчанию. Польза против ограничения доступа не доказана: в замерах
/// без блокировки оба профиля отвечали 200, а под блокировкой сравнить ещё не удалось.
/// Тумблер нужен, чтобы менять один фактор за раз.
enum SessionProfile {
    static let enabledKey = "MobileSessionEnabled"
    private static let instanceKey = "MobileSessionInstanceId"

    static let userAgent = "OpenPlay|4.118.0|Android|16|Google Pixel 8"

    /// Идентификатор установки живёт между запусками: клиент создаёт его один раз.
    static var instanceId: String {
        if let saved = UserDefaults.standard.string(forKey: instanceKey), !saved.isEmpty {
            return saved
        }
        let created = UUID().uuidString.lowercased()
        UserDefaults.standard.set(created, forKey: instanceKey)
        return created
    }

    /// `nil`, когда профиль выключен — тогда уходят прежние браузерные заголовки.
    static var current: MobileClientProfile? {
        guard UserDefaults.standard.bool(forKey: enabledKey) else { return nil }
        return MobileClientProfile(
            instanceId: instanceId,
            userAgent: MobileClientProfile.asciiSafe(userAgent)
        )
    }
}
