import Foundation

enum UpdateStatusFormatter {
    static func lastChecked(at date: Date?, now: Date = Date()) -> String {
        guard let date else { return "Ещё не проверялось" }
        let elapsed = now.timeIntervalSince(date)
        if elapsed < 30 { return "Проверено только что" }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.unitsStyle = .full
        let relative = formatter.localizedString(for: date, relativeTo: now)
        return "Проверено \(relative)"
    }

    static func nextCheck(after lastCheckedAt: Date?,
                          interval: TimeInterval,
                          now: Date = Date()) -> String? {
        guard let lastCheckedAt else { return nil }
        let elapsed = now.timeIntervalSince(lastCheckedAt)
        let remaining = max(0, interval - elapsed)
        if remaining <= 0 { return "следующая проверка скоро" }
        return "следующая через \(approximateDuration(remaining))"
    }

    static func approximateDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        if minutes < 1 { return "~1 мин" }
        if minutes < 60 { return "~\(minutes) мин" }
        let hours = Int(seconds / 3600)
        if hours < 24 { return "~\(hours) ч" }
        let days = Int(seconds / 86_400)
        return days == 1 ? "~1 день" : "~\(days) дн"
    }
}
