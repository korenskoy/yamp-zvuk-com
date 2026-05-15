import SwiftUI

struct GridSheet<Content: View>: View {
    let title: String
    var minItemWidth: CGFloat = 140
    var maxItemWidth: CGFloat = 180
    @ViewBuilder let content: Content

    @Environment(\.dismiss) private var dismiss

    private let spacing: CGFloat = 16

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(16)

            Divider()

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: minItemWidth, maximum: maxItemWidth), spacing: spacing, alignment: .top)], spacing: spacing) {
                    content
                }
                .padding(20)
            }
        }
        .frame(
            minWidth: 700, idealWidth: 900, maxWidth: 1100,
            minHeight: 400, idealHeight: 650, maxHeight: 800
        )
    }

    private var header: some View {
        HStack {
            Text(title)
                .font(.title2.weight(.bold))

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }
}
