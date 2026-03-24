import Foundation

@MainActor
@Observable
final class AuthViewModel {
    var token = ""
    var isLoading = false
    var errorMessage: String?

    func login(appState: AppState) async {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Введите токен"
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await appState.login(token: trimmed)
        } catch {
            errorMessage = "Неверный токен или ошибка сети: \(error.localizedDescription)"
        }
    }
}
