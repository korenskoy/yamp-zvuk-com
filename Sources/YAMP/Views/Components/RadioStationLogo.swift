import SwiftUI
import ZvukMusic

/// Логотип радиостанции или заглушка, если его нет.
///
/// Размер, обрезку и оверлеи задаёт вызывающая сторона — в каталоге это
/// квадрат во всю ширину карточки, в плеере маленькая иконка. Размер значка
/// заглушки берётся из окружения, так что задаётся обычным `.font()`.
struct RadioStationLogo: View {
    let station: RadioStation

    var body: some View {
        if let source = station.logoColored?.png, let url = URL(string: source) {
            CachedAsyncImage(url: url) { image in
                image.scaledToFill()
            } placeholder: {
                placeholder
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        Rectangle()
            .fill(.quaternary)
            .overlay {
                Image(systemName: "radio")
                    .foregroundStyle(.secondary)
            }
    }
}
