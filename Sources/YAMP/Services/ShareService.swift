import AppKit
import Foundation

enum ShareTarget {
    case artist(id: String)
    case release(id: String)
    case playlist(id: String)
    case track(id: String)
}

enum ShareService {
    static func url(for target: ShareTarget) -> URL? {
        let path: String
        let id: String
        switch target {
        case .artist(let value): (path, id) = ("artist", value)
        case .release(let value): (path, id) = ("release", value)
        case .playlist(let value): (path, id) = ("playlist", value)
        case .track(let value): (path, id) = ("track", value)
        }
        guard let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return nil }
        return URL(string: "https://zvuk.com/\(path)/\(encoded)")
    }

    static func copyToPasteboard(_ url: URL) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(url.absoluteString, forType: .string)
    }
}
