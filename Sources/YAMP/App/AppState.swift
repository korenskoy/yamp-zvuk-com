import Foundation
import ZvukMusic

@MainActor
@Observable
final class AppState {
    var isAuthenticated = false
    var isRestoringSession = true
    var currentUser: ProfileResult?
    var selectedDestination: NavigationDestination? = .search {
        didSet {
            if !isNavigatingHistory {
                // Push to history stack when navigating normally
                if let oldValue = oldValue {
                    backStack.append(oldValue)
                    forwardStack.removeAll()
                }
            }
            saveDestination()
        }
    }

    private(set) var backStack: [NavigationDestination] = []
    private(set) var forwardStack: [NavigationDestination] = []
    private var isNavigatingHistory = false

    var hasUnreadNews = false

    var canGoBack: Bool { !backStack.isEmpty }
    var canGoForward: Bool { !forwardStack.isEmpty }

    func goBack() {
        guard let previous = backStack.popLast() else { return }
        if let current = selectedDestination {
            forwardStack.append(current)
        }
        isNavigatingHistory = true
        selectedDestination = previous
        isNavigatingHistory = false
    }

    func goForward() {
        guard let next = forwardStack.popLast() else { return }
        if let current = selectedDestination {
            backStack.append(current)
        }
        isNavigatingHistory = true
        selectedDestination = next
        isNavigatingHistory = false
    }

    private(set) var client: ZvukClient?
    private let authService = AuthService()
    private var newsPollingTask: Task<Void, Never>?
    private static let newsPollingInterval: Duration = .seconds(6 * 60 * 60)

    func restoreSession() async {
        guard !isAuthenticated else { return }

        isRestoringSession = true
        defer { isRestoringSession = false }

        restoreDestination()

        guard let token = authService.loadToken() else { return }

        do {
            let profile = try await authService.validateToken(token)
            self.client = ZvukClient(token: token, rateLimit: 5)
            self.currentUser = profile
            self.isAuthenticated = true
        } catch is URLError {
            // Network unreachable — keep token, authenticate optimistically
            self.client = ZvukClient(token: token, rateLimit: 5)
            self.isAuthenticated = true
        } catch let error as ZvukError {
            switch error {
            case .unauthorized:
                authService.clearToken()
            case .network, .timedOut:
                // Transient network error — keep token, authenticate optimistically
                self.client = ZvukClient(token: token, rateLimit: 5)
                self.isAuthenticated = true
            default:
                // Other API errors — keep token but don't authenticate
                break
            }
        } catch {
            // Unknown error — keep token, don't clear
            print("[AppState] Session restore failed: \(error)")
        }
    }

    func login(token: String) async throws {
        let profile = try await authService.validateToken(token)
        authService.saveToken(token)
        self.client = ZvukClient(token: token, rateLimit: 5)
        self.currentUser = profile
        self.isAuthenticated = true
        await checkUnreadNews()
        startNewsPolling()
    }

    func logout() {
        stopNewsPolling()
        authService.clearToken()
        self.client = nil
        self.currentUser = nil
        self.isAuthenticated = false
        self.hasUnreadNews = false
        self.selectedDestination = .search
    }

    // MARK: - Unread News

    func checkUnreadNews() async {
        guard let client else { return }
        hasUnreadNews = (try? await client.hasUnreadNotifications()) ?? false
    }

    func startNewsPolling() {
        newsPollingTask?.cancel()
        newsPollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.newsPollingInterval)
                guard !Task.isCancelled else { return }
                await self?.checkUnreadNews()
            }
        }
    }

    func stopNewsPolling() {
        newsPollingTask?.cancel()
        newsPollingTask = nil
    }

    // MARK: - Destination Persistence

    private func saveDestination() {
        guard let dest = selectedDestination,
              let data = try? JSONEncoder().encode(dest) else {
            UserDefaults.standard.removeObject(forKey: "lastDestination")
            return
        }
        UserDefaults.standard.set(data, forKey: "lastDestination")
    }

    private func restoreDestination() {
        guard let data = UserDefaults.standard.data(forKey: "lastDestination"),
              let dest = try? JSONDecoder().decode(NavigationDestination.self, from: data) else { return }
        selectedDestination = dest
    }
}
