import Foundation

@MainActor
@Observable
final class AuthViewModel {
    var token = ""
    var isLoading = false
    var appError: AppError?
    var validationMessage: String?

    func login(appState: AppState) async {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            validationMessage = "Введите токен"
            return
        }

        isLoading = true
        appError = nil
        validationMessage = nil
        defer { isLoading = false }

        do {
            try await appState.login(token: trimmed)
        } catch {
            self.appError = AppError.from(error)
        }
    }
}
