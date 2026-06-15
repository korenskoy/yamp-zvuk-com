import SwiftUI

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @State private var nsImage: NSImage?

    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let nsImage {
                content(Image(nsImage: nsImage).resizable())
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            guard let url else { return }
            let image = await ImageCacheService.shared.image(for: url)
            // Задача отменяется при смене url — не затираем картинку нового url результатом старого.
            guard !Task.isCancelled else { return }
            nsImage = image
        }
    }
}
