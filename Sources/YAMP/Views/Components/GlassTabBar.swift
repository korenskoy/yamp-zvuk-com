import SwiftUI

struct GlassTabBar<Tab: Hashable & CaseIterable & RawRepresentable>: View where Tab.RawValue == String, Tab.AllCases: RandomAccessCollection {
    @Binding var selection: Tab
    var onChanged: (() -> Void)?

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    selection = tab
                    onChanged?()
                } label: {
                    Text(tab.rawValue)
                        .font(.callout.weight(selection == tab ? .semibold : .regular))
                        .foregroundStyle(selection == tab ? .primary : .secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            selection == tab
                                ? AnyShapeStyle(.tint.opacity(0.15))
                                : AnyShapeStyle(.clear)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .modifier(GlassTabBarContainerModifier())
    }
}

private struct GlassTabBarContainerModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: .capsule)
        } else {
            content
        }
    }
}
