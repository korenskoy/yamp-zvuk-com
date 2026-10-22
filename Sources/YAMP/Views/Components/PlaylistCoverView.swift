import SwiftUI
import ZvukMusic

/// Обложка плейлиста. Своей обложки нет — собираем её из обложек релизов первых треков.
///
/// Четыре обложки мостят квадрат 2×2; три идут веером по диагонали; одна или две —
/// просто первая на весь квадрат. Треков без обложек нет совсем — остаётся заглушка.
struct PlaylistCoverView: View {
    let image: ZvukMusic.Image?
    let tracks: [SimpleTrack]
    var cornerRadius: CGFloat = 10

    /// Перекрытие соседних обложек в веере: `coverOverlapRatio` мобильного клиента.
    private static let overlapRatio: CGFloat = 0.45

    var body: some View {
        if let src = image?.getURL(width: 400, height: 400), let url = URL(string: src) {
            CachedAsyncImage(url: url) { img in
                img.scaledToFill()
            } placeholder: {
                fallback
            }
        } else {
            fallback
        }
    }

    @ViewBuilder
    private var fallback: some View {
        let covers = Self.trackCovers(tracks)
        switch covers.count {
        case 0:
            CoverPlaceholderView(cornerRadius: cornerRadius)
        case 4:
            mosaic(covers)
        case 3:
            fan(covers)
        default:
            tile(covers[0])
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
    }

    /// Квадрат 2×2 без зазоров: лево-верх, право-верх, лево-низ, право-низ.
    private func mosaic(_ covers: [String]) -> some View {
        GeometryReader { geo in
            let side = geo.size.width / 2
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    tile(covers[0]).frame(width: side, height: side)
                    tile(covers[1]).frame(width: side, height: side)
                }
                HStack(spacing: 0) {
                    tile(covers[2]).frame(width: side, height: side)
                    tile(covers[3]).frame(width: side, height: side)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
        .aspectRatio(1, contentMode: .fit)
    }

    /// Веер по диагонали: лево-верх, центр, право-низ.
    private func fan(_ covers: [String]) -> some View {
        GeometryReader { geo in
            let side = geo.size.width / (1 + CGFloat(covers.count - 1) * Self.overlapRatio)
            let step = side * Self.overlapRatio
            ZStack(alignment: .topLeading) {
                ForEach(Array(covers.enumerated()), id: \.offset) { index, src in
                    tile(src)
                        .frame(width: side, height: side)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                        .shadow(radius: 4, x: -2, y: -2)
                        .offset(x: CGFloat(index) * step, y: CGFloat(index) * step)
                }
            }
            .frame(width: geo.size.width, height: geo.size.width, alignment: .topLeading)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func tile(_ src: String) -> some View {
        CachedAsyncImage(url: URL(string: src)) { img in
            img.scaledToFill()
        } placeholder: {
            Rectangle().fill(.quaternary)
        }
    }

    /// Обложки релизов в порядке треков, без повторов, не больше четырёх.
    static func trackCovers(_ tracks: [SimpleTrack], limit: Int = 4) -> [String] {
        uniqueFirst(tracks.map { $0.release?.image?.src }, limit: limit)
            .map { zvukImageURL(src: $0, width: 400, height: 400) }
    }

    /// Фильтр и дедупликация идут по сырому `src`: у пустой обложки готовый URL
    /// вырождается в `?size=...` — непустую строку, которая прошла бы как настоящая.
    static func uniqueFirst(_ sources: [String?], limit: Int) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for src in sources {
            guard let src, !src.isEmpty, seen.insert(src).inserted else { continue }
            result.append(src)
            if result.count == limit { break }
        }
        return result
    }
}
