import SwiftUI
import ZvukMusic

struct QueueView: View {
    @Environment(PlayerService.self) private var playerService

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Очередь воспроизведения")
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.top, 12)

            if playerService.queue.isEmpty {
                Text("Очередь пуста")
                    .foregroundStyle(.secondary)
                    .padding(16)
            } else {
                queueList
            }
        }
        .frame(width: 350, height: 400)
    }

    private var queueList: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(playerService.queue) { item in
                    QueueRowView(
                        item: item,
                        isCurrent: item.id == playerService.queue[safe: playerService.queueIndex]?.id,
                        onTap: {
                            if let idx = playerService.queue.firstIndex(where: { $0.id == item.id }) {
                                playerService.playQueue(
                                    playerService.queue.map(\.track),
                                    context: item.context,
                                    startAt: idx
                                )
                            }
                        }
                    )
                }
            }
        }
    }
}

private struct QueueRowView: View {
    let item: QueueItem
    let isCurrent: Bool
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            if isCurrent {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.caption)
                    .foregroundStyle(.tint)
                    .frame(width: 16)
            } else {
                Image(systemName: "music.note")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(item.track.title)
                    .font(.callout)
                    .lineLimit(1)

                Text(item.track.artistsString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(item.track.durationString)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isCurrent ? Color.accentColor.opacity(0.15) : isHovered ? Color.primary.opacity(0.08) : .clear)
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture { onTap() }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
