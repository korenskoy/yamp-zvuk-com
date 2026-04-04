import Foundation
import ZvukMusic

@MainActor
@Observable
final class AuthService {
    private(set) var isValidating = false

    private static let tokenKey = "zvuk_token"

    func validateToken(_ token: String) async throws -> ProfileResult {
        isValidating = true
        defer { isValidating = false }

        let client = ZvukClient(token: token)
        let profile = try await client.getProfile()

        guard let result = profile.result else {
            throw ZvukError.unauthorized(message: "Invalid token")
        }

        return result
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
