import SwiftUI

struct WaveXYPadView: View {
    @Binding var energy: Double
    @Binding var fun: Double

    @State private var isDragging = false

    private let gridSpacing: CGFloat = 16
    private let dotSize: CGFloat = 3
    private let handleSize: CGFloat = 36

    var body: some View {
        GeometryReader { geo in
            let size = geo.size

            ZStack {
                background
                dotGrid(in: size)
                cornerLabels(in: size)
                handle(in: size)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        let x = max(0, min(1, value.location.x / size.width))
                        let y = max(0, min(1, 1 - value.location.y / size.height))
                        fun = x
                        energy = y
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
        }
        .aspectRatio(1.6, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Background

    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.08, green: 0.12, blue: 0.28),
                Color(red: 0.10, green: 0.16, blue: 0.35),
                Color(red: 0.12, green: 0.18, blue: 0.38),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Dot Grid

    private func dotGrid(in size: CGSize) -> some View {
        Canvas { context, canvasSize in
            let cols = Int(canvasSize.width / gridSpacing)
            let rows = Int(canvasSize.height / gridSpacing)
            let offsetX = (canvasSize.width - CGFloat(cols - 1) * gridSpacing) / 2
            let offsetY = (canvasSize.height - CGFloat(rows - 1) * gridSpacing) / 2

            for row in 0..<rows {
                for col in 0..<cols {
                    let x = offsetX + CGFloat(col) * gridSpacing
                    let y = offsetY + CGFloat(row) * gridSpacing
                    let rect = CGRect(
                        x: x - dotSize / 2,
                        y: y - dotSize / 2,
                        width: dotSize,
                        height: dotSize
                    )
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(.white.opacity(0.15))
                    )
                }
            }
        }
    }

    // MARK: - Corner Labels

    private func cornerLabels(in size: CGSize) -> some View {
        ZStack {
            Text("ЭНЕРГИЧНОЕ")
                .position(x: 70, y: 16)

            Text("ВЕСЁЛОЕ")
                .position(x: size.width - 50, y: 16)

            Text("ГРУСТНОЕ")
                .position(x: 55, y: size.height - 16)

            Text("СПОКОЙНОЕ")
                .position(x: size.width - 60, y: size.height - 16)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.white.opacity(0.7))
        .allowsHitTesting(false)
    }

    // MARK: - Handle

    private func handle(in size: CGSize) -> some View {
        let x = fun * size.width
        let y = (1 - energy) * size.height

        return ZStack {
            // Glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            .white.opacity(0.6),
                            .white.opacity(0.15),
                            .clear,
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: handleSize * 1.8
                    )
                )
                .frame(width: handleSize * 3.5, height: handleSize * 3.5)

            // Circle
            Circle()
                .fill(.white)
                .frame(width: handleSize, height: handleSize)
                .shadow(color: .white.opacity(0.8), radius: 12)
        }
        .position(x: x, y: y)
        .animation(.interactiveSpring(duration: 0.15), value: isDragging)
    }
}
