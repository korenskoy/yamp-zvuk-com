import Foundation

final class AtomFeedParser: NSObject, XMLParserDelegate {
    struct LatestEntry {
        let version: String
        let url: URL
    }

    static func parseLatestStable(data: Data) -> LatestEntry? {
        let delegate = AtomFeedParser()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        // Явно запрещаем внешние сущности (XXE) и DTD из недоверенного фида.
        parser.shouldResolveExternalEntities = false
        // При обрыве/мусоре не используем частично распарсенные данные.
        guard parser.parse() else { return nil }
        // Берём первую стабильную запись с пригодной версией и валидной ссылкой,
        // а не только самую первую — иначе один битый элемент отключит проверку обновлений.
        for entry in delegate.entries where !isPrerelease(entry.tag) {
            guard let version = extractVersion(fromTag: entry.tag) ?? extractVersion(fromTitle: entry.title),
                  let url = entry.url, isTrustedReleaseURL(url) else { continue }
            return LatestEntry(version: version, url: url)
        }
        return nil
    }

    /// Принимаем только https-ссылки на github.com — фид/аккаунт может быть скомпрометирован.
    private static func isTrustedReleaseURL(_ url: URL) -> Bool {
        guard url.scheme == "https", let host = url.host else { return false }
        return host == "github.com" || host.hasSuffix(".github.com")
    }

    private struct RawEntry {
        var title: String
        var tag: String
        var url: URL?
    }

    private var entries: [RawEntry] = []
    private var insideEntry = false
    private var currentElement: String?
    private var titleBuffer = ""

    func parser(_ parser: XMLParser,
                didStartElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?,
                attributes attributeDict: [String: String]) {
        if elementName == "entry" {
            insideEntry = true
            entries.append(RawEntry(title: "", tag: "", url: nil))
            titleBuffer = ""
            return
        }
        guard insideEntry else { return }
        currentElement = elementName
        if elementName == "link", entries.last?.url == nil {
            let rel = attributeDict["rel"] ?? "alternate"
            if rel == "alternate", let href = attributeDict["href"], let url = URL(string: href) {
                entries[entries.count - 1].url = url
                entries[entries.count - 1].tag = url.lastPathComponent
            }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard insideEntry, currentElement == "title" else { return }
        titleBuffer += string
    }

    func parser(_ parser: XMLParser,
                didEndElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?) {
        if elementName == "title", insideEntry, entries.last?.title.isEmpty == true {
            entries[entries.count - 1].title = titleBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
            titleBuffer = ""
        }
        if elementName == "entry" {
            insideEntry = false
        }
        currentElement = nil
    }

    static func extractVersion(fromTag tag: String) -> String? {
        let stripped = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        return matchVersion(in: stripped)
    }

    static func extractVersion(fromTitle title: String) -> String? {
        matchVersion(in: title)
    }

    // swiftlint:disable:next force_try
    private static let versionRegex = try! NSRegularExpression(pattern: #"(\d+(?:\.\d+){0,3})"#)

    // Letter-boundary lookarounds — "rc1" и "-beta" попадают,
    // "developer", "march", "preview-er-wrong-context" — нет.
    // swiftlint:disable:next force_try
    private static let prereleaseRegex = try! NSRegularExpression(
        pattern: #"(?<![a-z])(alpha|beta|rc|preview|dev|nightly)(?![a-z])"#,
        options: .caseInsensitive
    )

    static func isPrerelease(_ raw: String) -> Bool {
        let range = NSRange(raw.startIndex..., in: raw)
        return prereleaseRegex.firstMatch(in: raw, range: range) != nil
    }

    private static func matchVersion(in raw: String) -> String? {
        let range = NSRange(raw.startIndex..., in: raw)
        guard let match = versionRegex.firstMatch(in: raw, range: range),
              let matchRange = Range(match.range(at: 1), in: raw) else { return nil }
        return String(raw[matchRange])
    }
}
