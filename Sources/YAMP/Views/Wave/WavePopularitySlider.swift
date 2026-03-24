import SwiftUI
import ZvukMusic

struct WavePopularitySlider: View {
    @Binding var popularity: WavePopularity?

    private let options: [(label: String, value: WavePopularity?)] = [
        ("Редкое", .rare),
        ("Любое", nil),
        ("Популярное", .popular),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                Button {
                    popularity = option.value
                } label: {
                    Text(option.label)
                        .font(.callout)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            isSelected(option.value)
                                ? Color.accentColor.opacity(0.2)
                                : Color.clear
                        )
                        .foregroundStyle(isSelected(option.value) ? Color.accentColor : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.quaternary, lineWidth: 1)
        )
    }

    private func isSelected(_ value: WavePopularity?) -> Bool {
        popularity == value
    }
}
