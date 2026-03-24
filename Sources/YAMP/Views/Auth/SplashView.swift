import SwiftUI

struct SplashView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Звук")
                .font(.system(size: 48, weight: .bold, design: .rounded))

            Text("[unofficial]")
                .font(.title3)
                .foregroundStyle(.secondary)

            ProgressView()
                .controlSize(.regular)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
