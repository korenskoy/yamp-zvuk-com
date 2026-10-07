import Foundation
import ZvukMusic

@MainActor
@Observable
final class AuthService {
    private(set) var isValidating = false

    private static let tokenKey = "zvuk_token"

    /// Returns `nil` when the token is valid but the profile is unavailable —
    /// Zvuk's anti-bot protection sits in front of the REST profile endpoint.
    func validateToken(_ token: String) async throws -> ProfileResult? {
        isValidating = true
        defer { isValidating = false }

        let client = ZvukClient(token: token, userAgent: UserAgent.browser)
        do {
            let profile = try await client.getProfile()

            guard let result = profile.result else {
                throw ZvukError.unauthorized(message: "Invalid token")
            }

            return result
        } catch ZvukError.botDetected {
            // ponytail: same fallback as ZvukClient.isAuthorized() in 0.4.2 — verify the
            // token through GraphQL. A rejected token still throws .unauthorized.
            _ = try await client.getCollection()
            return nil
        }
    }

    func saveToken(_ token: String) {
        KeychainHelper.save(key: Self.tokenKey, value: token)
    }

    func loadToken() -> String? {
        KeychainHelper.load(key: Self.tokenKey)
    }

    func clearToken() {
        KeychainHelper.delete(key: Self.tokenKey)
    }
}
