import Foundation

extension TimeInterval {
    var formattedTime: String {
        let totalSeconds = Int(self)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    func formattedTime(negative: Bool) -> String {
        guard isFinite && self >= 0 else { return negative ? "-0:00" : "0:00" }
        let prefix = negative ? "-" : ""
        return "\(prefix)\(formattedTime)"
    }
}
