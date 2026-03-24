import SwiftUI
import ZvukMusic

struct WaveGenreSheet: View {
    @Binding var selectedGenres: Set<WaveGenre>
    @Binding var language: WaveLanguage?
    @Binding var instrumental: Bool
    @Environment(\.dismiss) private var dismiss

    @State private var draftGenres: Set<WaveGenre> = []
    @State private var draftLanguage: WaveLanguage?
    @State private var draftInstrumental = false

    private let allGenres: [WaveGenre] = [
        .classical, .ambient, .electronic, .folk, .hipHop,
        .indie, .instrumental, .metal, .pop, .rock, .soundtrack,
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            genresSection
            languageSection
            Spacer()
            actionButtons
        }
        .padding(24)
        .frame(width: 420, height: 380)
        .onAppear {
            draftGenres = selectedGenres
            draftLanguage = language
            draftInstrumental = instrumental
        }
    }

    // MARK: - Genres

    private var genresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Жанры")
                .font(.title2.weight(.medium))
                .foregroundStyle(.secondary)

            FlowLayout(spacing: 8) {
                ForEach(allGenres, id: \.self) { genre in
                    genreChip(genre)
                }
            }
        }
    }

    private func genreChip(_ genre: WaveGenre) -> some View {
        let isSelected = draftGenres.contains(genre)
        return Button {
            if isSelected {
                draftGenres.remove(genre)
            } else {
                draftGenres.insert(genre)
            }
        } label: {
            Text(genre.displayName)
                .font(.callout)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.15))
                .foregroundStyle(isSelected ? Color.accentColor : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Language

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Язык")
                .font(.title2.weight(.medium))
                .foregroundStyle(.secondary)

            FlowLayout(spacing: 8) {
                languageOption("Все языки", isSelected: draftLanguage == nil && !draftInstrumental) {
                    draftLanguage = nil
                    draftInstrumental = false
                }
                languageOption("Зарубежное", isSelected: draftLanguage == .foreign && !draftInstrumental) {
                    draftLanguage = .foreign
                    draftInstrumental = false
                }
                languageOption("Русское", isSelected: draftLanguage == .russian && !draftInstrumental) {
                    draftLanguage = .russian
                    draftInstrumental = false
                }
                languageOption("Без слов", isSelected: draftInstrumental) {
                    draftLanguage = nil
                    draftInstrumental = true
                }
            }
        }
    }

    private func languageOption(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                Image(systemName: isSelected ? "record.circle" : "circle")
                    .font(.caption)
            }
            .font(.callout)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.15))
            .foregroundStyle(isSelected ? Color.accentColor : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private var actionButtons: some View {
        HStack {
            Spacer()

            Button("Сбросить") {
                draftGenres = []
                draftLanguage = nil
                draftInstrumental = false
            }
            .buttonStyle(.bordered)

            Button("Применить") {
                selectedGenres = draftGenres
                language = draftLanguage
                instrumental = draftInstrumental
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - FlowLayout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: ProposedViewSize(subviews[index].sizeThatFits(.unspecified))
            )
        }
    }

    private struct ArrangeResult {
        var size: CGSize
        var positions: [CGPoint]
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> ArrangeResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalHeight = y + rowHeight
        }

        return ArrangeResult(
            size: CGSize(width: maxWidth, height: totalHeight),
            positions: positions
        )
    }
}
