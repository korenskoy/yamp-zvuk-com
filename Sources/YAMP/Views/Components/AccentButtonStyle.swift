import SwiftUI

/// Замена `.borderedProminent` — сохраняет вид когда окно теряет фокус.
struct AccentButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.controlSize) private var controlSize

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .font(font)
            .foregroundStyle(isEnabled ? .white : Color.white.opacity(0.5))
            .background(backgroundColor(isPressed: configuration.isPressed))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        if !isEnabled {
            return Color.accentColor.opacity(0.4)
        }
        return isPressed ? Color.accentColor.opacity(0.7) : Color.accentColor
    }

    private var horizontalPadding: CGFloat {
        switch controlSize {
        case .large, .extraLarge: 10
        case .small, .mini: 6
        @unknown default: 8
        }
    }

    private var verticalPadding: CGFloat {
        switch controlSize {
        case .large, .extraLarge: 4
        case .small, .mini: 1
        @unknown default: 2
        }
    }

    private var font: Font {
        switch controlSize {
        case .large, .extraLarge: .body
        case .small, .mini: .caption
        @unknown default: .callout
        }
    }

    private var cornerRadius: CGFloat {
        switch controlSize {
        case .large, .extraLarge: 6
        case .small, .mini: 4
        @unknown default: 5
        }
    }
}

extension ButtonStyle where Self == AccentButtonStyle {
    static var accent: AccentButtonStyle { AccentButtonStyle() }
}
