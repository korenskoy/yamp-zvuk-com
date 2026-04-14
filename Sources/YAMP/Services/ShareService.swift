import AppKit
import Foundation

enum ShareTarget {
    case artist(id: String)
    case release(id: String)
    case playlist(id: String)
    case track(id: String)
}

enum ShareService {
    static func url(for target: ShareTarget) -> URL {
        switch target {
        case .artist(let id):
            URL(string: "https://zvuk.com/artist/\(id)")!
        case .release(let id):
            URL(string: "https://zvuk.com/release/\(id)")!
        case .playlist(let id):
            URL(string: "https://zvuk.com/playlist/\(id)")!
        case .track(let id):
            URL(string: "https://zvuk.com/track/\(id)")!
        }
    }

    static func copyToPasteboard(_ url: URL) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(url.absoluteString, forType: .string)
    }
}
