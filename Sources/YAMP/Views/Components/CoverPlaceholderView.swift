import SwiftUI

/// Заглушка обложки для элемента без картинки.
struct CoverPlaceholderView: View {
    var icon: String = "music.note.list"
    var cornerRadius: CGFloat = 10
    var iconSize: CGFloat = 34

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(.quaternary)
            .overlay {
                Image(systemName: icon)
                    .font(.system(size: iconSize))
                    .foregroundStyle(.secondary)
            }
    }
}
