import SwiftUI
import ZvukMusic

struct NewsView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = NewsViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(NewsTab.allCases, id: \.self) { tab in
                        Button {
                            viewModel.selectedTab = tab
                        } label: {
                            Text(tab.rawValue)
                                .font(.callout.weight(.medium))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(viewModel.selectedTab == tab
                                              ? Color.primary.opacity(0.15)
                                              : Color.clear)
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }

            Divider()

            ZStack {
                if viewModel.isLoading {
                    ProgressView()
                } else if viewModel.notifications.isEmpty {
                    ContentUnavailableView(
                        "Нет новостей",
                        systemImage: "bell",
                        description: Text("Подпишитесь на артистов, чтобы получать уведомления о новых релизах")
                    )
                } else {
                    newsContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .errorAlert($viewModel.appError)
        .task(id: viewModel.selectedTab) {
            await viewModel.load(client: appState.client)
        }
        .onAppear {
            if appState.hasUnreadNews {
                appState.hasUnreadNews = false
                Task {
                    try? await appState.client?.readAllNotifications()
                }
            }
        }
    }

    private var newsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Новости")
                    .font(.title.weight(.bold))

                Text("Последние релизы артистов, подкастов и обновления друзей, на которых вы подписаны")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                let grouped = groupByDate(viewModel.notifications)
                ForEach(grouped, id: \.label) { group in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(group.label)
                            .font(.headline)
                            .padding(.top, 8)

                        ForEach(Array(group.items.enumerated()), id: \.offset) { _, notification in
                            NotificationRowView(notification: notification) { destination in
                                appState.selectedDestination = destination
                            }
                        }
                    }
                }

                if viewModel.hasNextPage {
                    HStack {
                        Spacer()
                        if viewModel.isLoadingMore {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Button("Загрузить ещё") {
                                Task {
                                    await viewModel.loadMore(client: appState.client)
                                }
                            }
                            .font(.callout)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
            }
            .padding(20)
        }
    }

    private struct DateGroup {
        let label: String
        let items: [ZvukNotification]
    }

    private func groupByDate(_ notifications: [ZvukNotification]) -> [DateGroup] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallback = ISO8601DateFormatter()

        let calendar = Calendar.current
        let now = Date()

        var groups: [(label: String, items: [ZvukNotification])] = []
        var currentLabel = ""
        var currentItems: [ZvukNotification] = []

        for notification in notifications {
            let date = formatter.date(from: notification.createdAt)
                ?? fallback.date(from: notification.createdAt)
                ?? now

            let label: String
            if calendar.isDateInToday(date) {
                label = "Сегодня"
            } else if calendar.isDateInYesterday(date) {
                label = "Вчера"
            } else {
                let df = DateFormatter()
                df.locale = Locale(identifier: "ru_RU")
                df.dateFormat = "d MMMM"
                label = df.string(from: date)
            }

            if label != currentLabel {
                if !currentItems.isEmpty {
                    groups.append((label: currentLabel, items: currentItems))
                }
                currentLabel = label
                currentItems = [notification]
            } else {
                currentItems.append(notification)
            }
        }
        if !currentItems.isEmpty {
            groups.append((label: currentLabel, items: currentItems))
        }

        return groups.map { DateGroup(label: $0.label, items: $0.items) }
    }
}
