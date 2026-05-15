import SwiftUI
import ZvukMusic

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppSettings.self) private var appSettings
    @Environment(CacheService.self) private var cacheService
    @Environment(LastFMService.self) private var lastFMService
    @Environment(UpdateService.self) private var updateService
    @Environment(\.openURL) private var openURL

    @State private var subscription: Subscription?
    @State private var featuredInfo: FeaturedInfo?
    @State private var subscriptionLoading = false
    @State private var showFeatureFlags = false

    var body: some View {
        @Bindable var settings = appSettings

        Form {
            Section("Аккаунт") {
                if let user = appState.currentUser {
                    LabeledContent("Имя", value: user.name ?? "—")
                    LabeledContent("Email", value: user.email ?? "—")
                }

                Button("Выйти", role: .destructive) {
                    cacheService.invalidateAll()
                    appState.logout()
                }
            }

            Section("Подписка") {
                if subscriptionLoading {
                    ProgressView()
                        .controlSize(.small)
                } else if let sub = subscription {
                    LabeledContent("План", value: sub.title)
                    LabeledContent("Статус", value: sub.status)
                    LabeledContent("Цена", value: String(format: "%.0f ₽", sub.planPrice))
                    LabeledContent("Действует до", value: sub.expirationDate.formatted(.dateTime.day().month(.wide).year()))
                    if sub.isTrial {
                        LabeledContent("Пробный период", value: "Да")
                    }
                    if sub.hasPremium {
                        LabeledContent("Премиум", value: "Да")
                    }
                    if let payment = sub.paymentDetails {
                        LabeledContent("Владелец", value: payment.isOwner ? "Да" : "Нет")
                    }
                } else {
                    Text("Нет активной подписки")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Качество аудио") {
                Picker("Предпочитаемое качество", selection: $settings.preferredQuality) {
                    Text("128 kbps (MP3)").tag(StreamQuality.mid)
                    Text("320 kbps (MP3)").tag(StreamQuality.high)
                    Text("FLAC").tag(StreamQuality.flac)
                }
                .pickerStyle(.radioGroup)

                Text("Высокое качество и FLAC требуют платную подписку Zvuk.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Last.fm") {
                if lastFMService.isConnected {
                    LabeledContent("Аккаунт", value: lastFMService.connectedUsername ?? "—")

                    Toggle("Скробблинг", isOn: $settings.isScrobblingEnabled)

                    Button("Отключить Last.fm", role: .destructive) {
                        lastFMService.disconnect()
                    }
                } else {
                    Button {
                        lastFMService.connect()
                    } label: {
                        if lastFMService.connectionState == .connecting {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Ожидание авторизации...")
                            }
                        } else {
                            Text("Подключить Last.fm")
                        }
                    }
                    .disabled(lastFMService.connectionState == .connecting)
                }

                Text("Скробблинг отправляет информацию о прослушанных треках на Last.fm.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Обновления") {
                updateStatusCard

                Toggle("Проверять при запуске", isOn: Binding(
                    get: { updateService.autoCheckOnLaunch },
                    set: { updateService.autoCheckOnLaunch = $0 }
                ))
            }

            Section("О приложении") {
                LabeledContent("Версия", value: AppVersion.displayString)
                LabeledContent("Исходный код") {
                    Link("GitHub", destination: URL(string: "https://github.com/korenskoy/yamp-zvuk-com")!)
                }
                LabeledContent("Библиотека") {
                    Link("ZvukMusic (Swift)", destination: URL(string: "https://github.com/korenskoy/zvuk-swift")!)
                }

                if let info = featuredInfo {
                    if let country = info.country {
                        LabeledContent("Страна", value: country)
                    }

                    Button("Feature Flags (\(info.features.count))") {
                        showFeatureFlags = true
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .font(.caption)
                }
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: 500)
        .padding(20)
        .task {
            await loadSubscriptionInfo()
        }
        .sheet(isPresented: $showFeatureFlags) {
            featureFlagsSheet
        }
    }

    // MARK: - Update Status Card

    private var updateStatusCard: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(updateStatusColor)
                        .frame(width: 8, height: 8)
                    Text(updateStatusTitle)
                        .font(.system(size: 13, weight: .semibold))
                }
                Text(updateStatusSubtitle)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            updateActionButton
        }
        .padding(.vertical, 4)
    }

    private var updateStatusColor: Color {
        if updateService.availableUpdate != nil { return .orange }
        if updateService.lastCheckedAt != nil { return .green }
        return .secondary
    }

    private var updateStatusTitle: String {
        if let update = updateService.availableUpdate {
            return "Доступно обновление — версия \(update.version)"
        }
        if updateService.lastCheckedAt != nil { return "У вас актуальная версия" }
        return "Ещё не проверялось"
    }

    private var updateStatusSubtitle: String {
        if updateService.isChecking { return "Проверяем GitHub…" }
        let last = UpdateStatusFormatter.lastChecked(at: updateService.lastCheckedAt)
        if let next = UpdateStatusFormatter.nextCheck(
            after: updateService.lastCheckedAt,
            interval: updateService.checkInterval
        ), updateService.autoCheckOnLaunch {
            return "\(last) · \(next)"
        }
        return last
    }

    @ViewBuilder
    private var updateActionButton: some View {
        if let update = updateService.availableUpdate {
            Button {
                openURL(update.url)
            } label: {
                Label("Открыть релиз", systemImage: "arrow.up.right.square")
            }
            .buttonStyle(.accent)
        } else {
            Button {
                Task { await updateService.checkNow() }
            } label: {
                if updateService.isChecking {
                    ProgressView().controlSize(.small)
                } else {
                    Label("Проверить", systemImage: "arrow.clockwise")
                }
            }
            .buttonStyle(.bordered)
            .disabled(updateService.isChecking)
        }
    }

    // MARK: - Feature Flags Sheet

    private var featureFlagsSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Feature Flags")
                    .font(.headline)
                Spacer()
                Button("Закрыть") {
                    showFeatureFlags = false
                }
                .buttonStyle(.bordered)
            }

            if let info = featuredInfo {
                List(info.features, id: \.self) { flag in
                    Text(flag)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
        }
        .padding(16)
        .frame(width: 400, height: 500)
    }

    // MARK: - Data Loading

    private func loadSubscriptionInfo() async {
        guard let client = appState.client else { return }
        subscriptionLoading = true
        defer { subscriptionLoading = false }

        subscription = (try? await client.getSubscription())?.subscription
        featuredInfo = try? await client.getFeaturedInfo()
    }
}
