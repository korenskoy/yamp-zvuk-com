import SwiftUI
import ZvukMusic

struct HistoryView: View {
    @Environment(AppState.self) private var appState
    @Environment(PlayerService.self) private var playerService
    @Environment(CollectionService.self) private var collectionService
    @Environment(ListeningHistoryStore.self) private var historyStore

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let isoFallbackFormatter = ISO8601DateFormatter()

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    var body: some View {
        ZStack {
            if historyStore.entries.isEmpty {
                ContentUnavailableView(
                    "История пуста",
                    systemImage: "clock",
                    description: Text("Прослушанные треки появятся здесь")
                )
            } else {
                historyContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var historyContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("История прослушивания")
                        .font(.title.weight(.bold))

                    Spacer()

                    Button("Очистить") {
                        historyStore.clear()
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                VStack(spacing: 4) {
                    let tracks = historyStore.entries.map(\.track)
                    ForEach(Array(historyStore.entries.enumerated()), id: \.element.id) { index, entry in
                        TrackRowView(
                            track: entry.track,
                            trailing: {
                                if let dttm = entry.lastListeningDttm {
                                    Text(formatDate(dttm))
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                        .frame(width: 50, alignment: .trailing)
                                }

                                Button {
                                    Task {
                                        await collectionService.toggleTrackLike(entry.track, client: appState.client)
                                    }
                                } label: {
                                    Image(systemName: collectionService.isTrackLiked(entry.track.id) ? "heart.fill" : "heart")
                                        .font(.caption)
                                        .foregroundStyle(collectionService.isTrackLiked(entry.track.id) ? .red : .secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        ) {
                            playerService.playQueue(
                                tracks,
                                context: .search,
                                startAt: index
                            )
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    private func formatDate(_ iso: String) -> String {
        guard let date = Self.isoFormatter.date(from: iso)
                ?? Self.isoFallbackFormatter.date(from: iso) else {
            return ""
        }
        return Self.relativeFormatter.localizedString(for: date, relativeTo: Date())
    }
}
