import Foundation
import ZvukMusic

@MainActor
@Observable
final class BlacklistViewModel {
    var artists: [Artist] = []
    var tracks: [Track] = []
    var isLoading = false
    var appError: AppError?

    func load(client: ZvukClient?, cache: CacheService) async {
        guard client != nil else { return }
        isLoading = true
        appError = nil
        defer { isLoading = false }

        do {
            let hidden = try await cache.getHiddenCollection()

            let artistIDs = hidden.artists.compactMap(\.id)
            if !artistIDs.isEmpty {
                artists = try await cache.getArtists(artistIDs)
            }

            let trackIDs = hidden.tracks.compactMap(\.id)
            if !trackIDs.isEmpty {
                tracks = try await cache.getTracks(trackIDs)
            }
        } catch {
            self.appError = AppError.from(error)
        }
    }

    func unhideArtist(_ id: String, client: ZvukClient?, cache: CacheService) async {
        guard let client else { return }
        do {
            _ = try await client.removeFromHidden(id, type: .artist)
            artists.removeAll { $0.id == id }
            cache.invalidateHiddenCollection()
        } catch {
            self.appError = AppError.from(error)
        }
    }

    func unhideTrack(_ id: String, client: ZvukClient?, cache: CacheService) async {
        guard let client else { return }
        do {
            _ = try await client.removeFromHidden(id, type: .track)
            tracks.removeAll { $0.id == id }
            cache.invalidateHiddenCollection()
        } catch {
            self.appError = AppError.from(error)
        }
    }
}
