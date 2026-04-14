import SwiftUI

struct ShareButton: View {
    let target: ShareTarget?
    var font: Font = .title2
    @State private var copied = false

    var body: some View {
        Button(action: copy) {
            Image(systemName: copied ? "checkmark" : "square.and.arrow.up")
                .font(font)
                .foregroundStyle(iconColor)
                .contentTransition(.symbolEffect(.replace))
                .offset(y: copied ? 0 : -2)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .disabled(target == nil)
        .help(target == nil ? "" : (copied ? "Ссылка скопирована" : "Копировать ссылку"))
        .accessibilityLabel("Поделиться")
    }

    private var iconColor: Color {
        if target == nil { return .secondary.opacity(0.35) }
        return copied ? Color.accentColor : .secondary
    }

    private func copy() {
        guard let target else { return }
        ShareService.copyToPasteboard(ShareService.url(for: target))
        withAnimation(.easeInOut(duration: 0.2)) { copied = true }
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            withAnimation(.easeInOut(duration: 0.2)) { copied = false }
        }
    }
}
