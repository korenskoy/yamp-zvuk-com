import SwiftUI

struct ProgressBarView: View {
    @Environment(PlayerService.self) private var playerService
    @Binding var isExpanded: Bool
    @State private var isHovered = false
    @State private var isSeeking = false
    @State private var seekValue: Double = 0
    @State private var hoverTask: Task<Void, Never>?

    private var currentDisplayTime: Double {
        isSeeking ? seekValue : playerService.currentTime
    }

    private var progress: Double {
        guard playerService.duration > 0 else { return 0 }
        return min(max(currentDisplayTime / playerService.duration, 0), 1)
    }

    private var showExpanded: Bool { isExpanded || isSeeking }

    var body: some View {
        GeometryReader { geo in
            // Thin bar (collapsed)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.secondary.opacity(0.15))
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: geo.size.width * progress)
            }
            .frame(height: 2)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .opacity(showExpanded ? 0 : 1)

            // Expanded bar — overlay anchored to bottom, grows upward
            .overlay(alignment: .bottom) {
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.secondary.opacity(0.15))
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: geo.size.width * progress)
                }
                .frame(height: 8)
                .opacity(showExpanded ? 1 : 0)
            }

            // Drag gesture on entire area
            .contentShape(Rectangle().inset(by: -8))
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        if !isSeeking {
                            isSeeking = true
                            seekValue = playerService.currentTime
                        }
                        let fraction = max(0, min(1, value.location.x / geo.size.width))
                        seekValue = fraction * playerService.duration
                    }
                    .onEnded { _ in
                        playerService.seek(to: seekValue)
                        isSeeking = false
                    }
            )
        }
        .frame(height: 2)
        .onHover { hovering in
            hoverTask?.cancel()
            if hovering {
                hoverTask = Task {
                    try? await Task.sleep(for: .milliseconds(200))
                    guard !Task.isCancelled else { return }
                    isExpanded = true
                }
            } else {
                isExpanded = false
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showExpanded)
    }

    // MARK: - Helpers

    private func formatTime(_ time: Double, negative: Bool = false) -> String {
        guard time.isFinite && time >= 0 else { return negative ? "-0:00" : "0:00" }
        let total = Int(time)
        let prefix = negative ? "-" : ""
        if total >= 3600 {
            return String(format: "%@%d:%02d:%02d", prefix, total / 3600, (total % 3600) / 60, total % 60)
        }
        return String(format: "%@%d:%02d", prefix, total / 60, total % 60)
    }
}
