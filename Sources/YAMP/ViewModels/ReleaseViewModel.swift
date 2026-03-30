import Foundation
import ZvukMusic

@MainActor
@Observable
final class ReleaseViewModel {
    let releaseId: String
    var release: Release?
    var isLoading = false
    var appError: AppError?

    init(releaseId: String) {
        self.releaseId = releaseId
    }

    func load(cache: CacheService) async {
        isLoading = true
        appError = nil
        defer { isLoading = false }

        do {
            release = try await cache.getRelease(releaseId)
        } catch {
            self.appError = AppError.from(error)
        }
    }
}
