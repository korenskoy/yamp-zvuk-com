import SwiftUI
import ZvukMusic

struct SettingsView: View {
    @Environment(AppState.self) private var appState

    @State private var subscription: Subscription?
    @State private var featuredInfo: FeaturedInfo?
    @State private var subscriptionLoading = false
    @State private var showFeatureFlags = false

    var body: some View {
        Form {
            AccountSection()
            SubscriptionSection(subscription: subscription, isLoading: subscriptionLoading)
            AudioQualitySection()
            MenuBarSection()
            LastFMSection()
            UpdatesSection()
            AboutSection(featuredInfo: featuredInfo, showFeatureFlags: $showFeatureFlags)
        }
        .formStyle(.grouped)
        .frame(maxWidth: 500)
        .padding(20)
        .task {
            await loadSubscriptionInfo()
        }
        .sheet(isPresented: $showFeatureFlags) {
            FeatureFlagsSheet(features: featuredInfo?.features ?? [])
        }
    }

    private func loadSubscriptionInfo() async {
        guard let client = appState.client else { return }
        subscriptionLoading = true
        defer { subscriptionLoading = false }

        subscription = (try? await client.getSubscription())?.subscription
        featuredInfo = try? await client.getFeaturedInfo()
    }
}

// MARK: - Account

private struct AccountSection: View {
    @Environment(AppState.self) private var appState
    @Environment(CacheService.self) private var cacheService

    var body: some View {
        Section("Аккаунт") {
            if let user = appState.currentUser {
                LabeledContent("Имя", value: user.name ?? "—")
                LabeledContent("Email", value: user.email ?? "—")
            }

            Button("Выйти", role: .destructive, action: logout)
        }
    }

    private func logout() {
        cacheService.invalidateAll()
        appState.logout()
    }
}

// MARK: - Subscription

private struct SubscriptionSection: View {
    let subscription: Subscription?
    let isLoading: Bool

    var body: some View {
        Section("Подписка") {
            if isLoading {
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
    }
}

// MARK: - Audio Quality

private struct AudioQualitySection: View {
    @Environment(AppSettings.self) private var appSettings

    var body: some View {
        @Bindable var settings = appSettings

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
    }
}

// MARK: - Menu Bar

private struct MenuBarSection: View {
    @AppStorage(MenuBarSettings.enabledKey) private var isMenuBarPlayerEnabled = true
    @AppStorage(MenuBarSettings.elementsKey)
    private var menuBarElementsRaw = MenuBarElement.defaults.map(\.rawValue).joined(separator: ",")
    @AppStorage(MenuBarSettings.titleLimitKey) private var menuBarTitleLimit = MenuBarSettings.defaultTitleLimit

    var body: some View {
        Section("Строка меню") {
            Toggle("Показывать плеер в строке меню", isOn: $isMenuBarPlayerEnabled)

            if isMenuBarPlayerEnabled {
                ForEach(MenuBarElement.allCases) { element in
                    Toggle(element.label, isOn: binding(for: element))
                }
                .padding(.leading, 20)

                Stepper(value: $menuBarTitleLimit, in: 10...60, step: 5) {
                    Text("Длина названия: \(menuBarTitleLimit) символов")
                }
                .padding(.leading, 20)

                Text("Строка меню делится с меню активного приложения — длинное название вытесняет иконки.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 20)
            }
        }
    }

    private func binding(for element: MenuBarElement) -> Binding<Bool> {
        Binding(
            get: { menuBarElementsRaw.split(separator: ",").contains(Substring(element.rawValue)) },
            set: { isOn in
                var selected = Set(menuBarElementsRaw.split(separator: ",").map(String.init))
                if isOn { selected.insert(element.rawValue) } else { selected.remove(element.rawValue) }
                menuBarElementsRaw = MenuBarElement.allCases
                    .filter { selected.contains($0.rawValue) }
                    .map(\.rawValue)
                    .joined(separator: ",")
            }
        )
    }
}

// MARK: - Last.fm

private struct LastFMSection: View {
    @Environment(AppSettings.self) private var appSettings
    @Environment(LastFMService.self) private var lastFMService

    var body: some View {
        @Bindable var settings = appSettings

        Section("Last.fm") {
            if lastFMService.sessionInvalidated {
                Label("Сессия Last.fm недействительна — вас разлогинило. Переподключитесь.",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.red)

                Button("Переподключить Last.fm") {
                    lastFMService.connect()
                }
                .disabled(lastFMService.connectionState == .connecting)
            } else if lastFMService.isConnected {
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

            if lastFMService.pendingScrobbleCount > 0 {
                Label("Ждут отправки: \(lastFMService.pendingScrobbleCount)", systemImage: "clock.arrow.circlepath")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Скробблинг отправляет информацию о прослушанных треках на Last.fm.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Updates

private struct UpdatesSection: View {
    @Environment(UpdateService.self) private var updateService
    @Environment(\.openURL) private var openURL

    private var statusColor: Color {
        if updateService.availableUpdate != nil { return .orange }
        if updateService.lastCheckedAt != nil { return .green }
        return .secondary
    }

    private var statusTitle: String {
        if let update = updateService.availableUpdate {
            return "Доступно обновление — версия \(update.version)"
        }
        if updateService.lastCheckedAt != nil { return "У вас актуальная версия" }
        return "Ещё не проверялось"
    }

    private var statusSubtitle: String {
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

    var body: some View {
        @Bindable var updateService = updateService

        Section("Обновления") {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                        Text(statusTitle)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    Text(statusSubtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                actionButton
            }
            .padding(.vertical, 4)

            Toggle("Проверять при запуске", isOn: $updateService.autoCheckOnLaunch)
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if let update = updateService.availableUpdate {
            Button {
                openURL(update.url)
            } label: {
                Label("Открыть релиз", systemImage: "arrow.up.right.square")
            }
            .buttonStyle(.accent)
        } else {
            Button(action: checkNow) {
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

    private func checkNow() {
        Task { await updateService.checkNow() }
    }
}

// MARK: - About

private struct AboutSection: View {
    let featuredInfo: FeaturedInfo?
    @Binding var showFeatureFlags: Bool

    var body: some View {
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
}

// MARK: - Feature Flags Sheet

private struct FeatureFlagsSheet: View {
    @Environment(\.dismiss) private var dismiss

    let features: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Feature Flags")
                    .font(.headline)
                Spacer()
                Button("Копировать", action: copyFlags)
                    .buttonStyle(.bordered)
                    .disabled(features.isEmpty)

                Button("Закрыть") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }

            List(features, id: \.self) { flag in
                Text(flag)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
            }
        }
        .padding(16)
        .frame(width: 400, height: 500)
    }

    private func copyFlags() {
        ShareService.copyToPasteboard(features.joined(separator: "\n"))
    }
}
