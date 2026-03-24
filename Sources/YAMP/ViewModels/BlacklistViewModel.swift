import Foundation
import ZvukMusic

@MainActor
@Observable
final class BlacklistViewModel {
    var artists: [Artist] = []
    var tracks: [Track] = []
    var isLoading = false
    var errorMessage: String?

    func load(client: ZvukClient?, cache: CacheService) async {
        guard client != nil else { return }
        isLoading = true
        errorMessage = nil
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
            errorMessage = "Ошибка загрузки: \(error.localizedDescription)"
        }
    }

    func unhideArtist(_ id: String, client: ZvukClient?, cache: CacheService) async {
        guard let client else { return }
        do {
            _ = try await client.removeFromHidden(id, type: .artist)
            artists.removeAll { $0.id == id }
            cache.invalidateHiddenCollection()
        } catch {
            errorMessage = "Не удалось убрать: \(error.localizedDescription)"
        }
    }

    func unhideTrack(_ id: String, client: ZvukClient?, cache: CacheService) async {
        guard let client else { return }
        do {
            _ = try await client.removeFromHidden(id, type: .track)
            tracks.removeAll { $0.id == id }
            cache.invalidateHiddenCollection()
        } catch {
            errorMessage = "Не удалось убрать: \(error.localizedDescription)"
        }
    }
}
