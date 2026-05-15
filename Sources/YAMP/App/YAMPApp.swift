import SwiftUI

@main
struct YAMPApp: App {
    init() {
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    @State private var appState = AppState()
    @State private var appSettings = AppSettings()
    @State private var playerService = PlayerService()
    @State private var collectionService = CollectionService()
    @State private var cacheService = CacheService()
    @State private var logStore = LogStore()
    @State private var historyStore = ListeningHistoryStore()
    @State private var lastFMService = LastFMService()
    @State private var updateService = UpdateService()

    var body: some Scene {
        WindowGroup {
            Group {
                if appState.isRestoringSession {
                    SplashView()
                } else if appState.isAuthenticated {
                    ContentView()
                } else {
                    AuthView()
                }
            }
            .environment(appState)
            .environment(appSettings)
            .environment(playerService)
            .environment(collectionService)
            .environment(cacheService)
            .environment(logStore)
            .environment(historyStore)
            .environment(lastFMService)
            .environment(updateService)
            .task {
                // Activate as regular app (show in Dock with icon and menu)
                NSApplication.shared.setActivationPolicy(.regular)
                NSApplication.shared.activate(ignoringOtherApps: true)

                // Use thin overlay scrollbars
                UserDefaults.standard.set("WhenScrolling", forKey: "AppleShowScrollBars")

                updateService.start()

                guard !appState.isAuthenticated else { return }

                lastFMService.configure(logStore: logStore)
                playerService.configure(appState: appState, settings: appSettings, cache: cacheService, history: historyStore, lastFM: lastFMService)
                cacheService.configure(appState: appState)
                collectionService.configure(cache: cacheService, lastFM: lastFMService, settings: appSettings)
                await appState.restoreSession()
                logStore.attach(to: appState.client)
                if appState.isAuthenticated {
                    await collectionService.loadCollection(client: appState.client)
                    await appState.checkUnreadNews()
                    appState.startNewsPolling()
                }
            }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1000, height: 700)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("О Звук [unofficial]") {
                    let paragraphStyle = NSMutableParagraphStyle()
                    paragraphStyle.alignment = .center
                    let credits = NSMutableAttributedString(string: "Все права на контент принадлежат ", attributes: [.paragraphStyle: paragraphStyle])
                    let zvukLink = NSAttributedString(
                        string: "Zvuk.com",
                        attributes: [.link: URL(string: "https://zvuk.com")!, .paragraphStyle: paragraphStyle]
                    )
                    credits.append(zvukLink)
                    credits.append(NSAttributedString(string: ".\nИсходный код находится на ", attributes: [.paragraphStyle: paragraphStyle]))
                    let githubLink = NSAttributedString(
                        string: "GitHub",
                        attributes: [.link: URL(string: "https://github.com/korenskoy/yamp-zvuk-com")!, .paragraphStyle: paragraphStyle]
                    )
                    credits.append(githubLink)
                    credits.append(NSAttributedString(string: ".", attributes: [.paragraphStyle: paragraphStyle]))
                    NSApplication.shared.orderFrontStandardAboutPanel(options: [
                        .applicationName: "Звук [unofficial]",
                        .applicationVersion: AppVersion.marketing,
                        .credits: credits,
                    ])
                }
            }
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .pasteboard) {}
            CommandGroup(replacing: .undoRedo) {}
            CommandGroup(replacing: .toolbar) {}
            CommandGroup(replacing: .sidebar) {}
            CommandGroup(replacing: .windowArrangement) {}
            CommandGroup(replacing: .help) {
                Button("GitHub") {
                    NSWorkspace.shared.open(URL(string: "https://github.com/korenskoy/yamp-zvuk-com")!)
                }
            }
            CommandMenu("Воспроизведение") {
                Button("Пауза / Играть") {
                    playerService.togglePlayPause()
                }
                .keyboardShortcut(" ", modifiers: [])

                Button("Следующий трек") {
                    playerService.next()
                }
                .keyboardShortcut(.rightArrow, modifiers: .command)

                Button("Предыдущий трек") {
                    playerService.previous()
                }
                .keyboardShortcut(.leftArrow, modifiers: .command)

                Divider()

                Button("Громче") {
                    playerService.adjustVolume(by: 0.1)
                }
                .keyboardShortcut(.upArrow, modifiers: .command)

                Button("Тише") {
                    playerService.adjustVolume(by: -0.1)
                }
                .keyboardShortcut(.downArrow, modifiers: .command)
            }
        }
    }
}
