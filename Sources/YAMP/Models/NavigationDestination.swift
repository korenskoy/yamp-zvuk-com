import Foundation

enum NavigationDestination: Hashable, Codable {
    case home
    case popular
    case search
    case news
    case collection
    case history
    case wave
    case radio
    case playlists
    case artist(id: String)
    case release(id: String)
    case playlist(id: String)
    case blacklist
    case settings
    case nowPlaying
}
