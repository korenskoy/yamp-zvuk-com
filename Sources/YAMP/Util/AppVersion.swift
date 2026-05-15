import Foundation

enum AppVersion {
    static let marketing: String =
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"

    static let build: String =
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"

    static let displayString: String = "\(marketing) (\(build))"
}
