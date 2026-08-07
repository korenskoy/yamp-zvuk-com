import AppKit
import SwiftUI
import ZvukMusic

/// Элемент плеера в строке меню. Каждый — отдельный `NSStatusItem`:
/// SwiftUI `MenuBarExtra` рисует label целиком некликабельным, кнопки в нём невозможны.
enum MenuBarElement: String, CaseIterable, Identifiable {
    case shuffle, previous, playPause, next, repeatMode, love, title

    var id: String { rawValue }

    var label: String {
        switch self {
        case .shuffle: "Перемешать"
        case .previous: "Предыдущий трек"
        case .playPause: "Играть / Пауза"
        case .next: "Следующий трек"
        case .repeatMode: "Повтор"
        case .love: "В любимые"
        case .title: "Название трека"
        }
    }

    static let defaults: [Self] = [.previous, .playPause, .next, .title]
}

/// Чтение/запись списка включённых элементов. Хранится одной CSV-строкой в `UserDefaults`,
/// чтобы не заводить по ключу на каждую кнопку.
enum MenuBarSettings {
    static let elementsKey = "menuBarElements"
    static let enabledKey = "menuBarPlayerEnabled"

    static var elements: [MenuBarElement] {
        get {
            guard let raw = UserDefaults.standard.string(forKey: elementsKey) else {
                return MenuBarElement.defaults
            }
            let selected = Set(raw.split(separator: ",").map(String.init))
            return MenuBarElement.allCases.filter { selected.contains($0.rawValue) }
        }
        set {
            UserDefaults.standard.set(newValue.map(\.rawValue).joined(separator: ","), forKey: elementsKey)
        }
    }

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }
}

@MainActor
final class MenuBarController {
    private var entries: [(element: MenuBarElement, item: NSStatusItem)] = []
    private var popover: NSPopover?

    private var player: PlayerService?
    private var collection: CollectionService?
    private weak var appState: AppState?

    func configure(player: PlayerService, collection: CollectionService, appState: AppState) {
        self.player = player
        self.collection = collection
        self.appState = appState

        rebuild()
        observePlayer()

        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.rebuildIfSettingsChanged() }
        }
    }

    // MARK: - Building

    private func rebuildIfSettingsChanged() {
        let wanted = MenuBarSettings.isEnabled ? MenuBarSettings.elements : []
        guard wanted != entries.map(\.element) else { return }
        rebuild()
    }

    private func rebuild() {
        for entry in entries {
            NSStatusBar.system.removeStatusItem(entry.item)
        }
        entries = []

        guard MenuBarSettings.isEnabled else { return }

        // NSStatusItem'ы выстраиваются справа налево, поэтому создаём в обратном порядке.
        for element in MenuBarSettings.elements.reversed() {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            item.button?.target = self
            item.button?.action = #selector(handleClick(_:))
            item.button?.tag = MenuBarElement.allCases.firstIndex(of: element) ?? 0
            entries.insert((element, item), at: 0)
        }

        refresh()
    }

    // MARK: - Rendering

    private func refresh() {
        guard let player else { return }

        for entry in entries {
            guard let button = entry.item.button else { continue }
            button.image = nil
            button.title = ""
            button.alphaValue = 1
            button.isEnabled = true
            button.toolTip = entry.element.label
            render(entry.element, into: button, player: player)
        }
    }

    private func render(_ element: MenuBarElement, into button: NSStatusBarButton, player: PlayerService) {
        let track = player.currentTrack

        switch element {
        case .shuffle:
            button.image = symbol("shuffle")
            button.alphaValue = player.isShuffled ? 1 : 0.5

        case .previous:
            button.image = symbol("backward.fill")
            button.isEnabled = player.hasPrevious

        case .playPause:
            button.image = symbol(player.isPlaying ? "pause.fill" : "play.fill")
            button.isEnabled = track != nil

        case .next:
            button.image = symbol("forward.fill")
            button.isEnabled = player.hasNext

        case .repeatMode:
            button.image = symbol(player.repeatMode == .one ? "repeat.1" : "repeat")
            button.alphaValue = player.repeatMode == .off ? 0.5 : 1

        case .love:
            let isLiked = track.map { collection?.isTrackLiked($0.id) ?? false } ?? false
            button.image = symbol(isLiked ? "heart.fill" : "heart")
            button.isEnabled = track != nil

        case .title:
            if let track {
                button.title = Self.titleText(for: track)
                button.toolTip = "\(track.artists.map(\.title).joined(separator: ", ")) — \(track.title)"
            } else {
                button.image = symbol("music.note")
            }
        }
    }

    private func symbol(_ name: String) -> NSImage? {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
        image?.isTemplate = true
        return image
    }

    /// ponytail: обрезаем по фиксированной длине, чтобы плеер не съедал строку меню.
    /// Если понадобится — вынести лимит в настройки.
    private static func titleText(for track: SimpleTrack) -> String {
        let artists = track.artists.map(\.title).joined(separator: ", ")
        let full = artists.isEmpty ? track.title : "\(artists) — \(track.title)"
        return full.count > 45 ? full.prefix(44).trimmingCharacters(in: .whitespaces) + "…" : full
    }

    // MARK: - Actions

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard let element = MenuBarElement.allCases[safe: sender.tag], let player else { return }

        switch element {
        case .shuffle: player.toggleShuffle()
        case .previous: player.previous()
        case .playPause: player.togglePlayPause()
        case .next: player.next()
        case .repeatMode: player.cycleRepeatMode()
        case .love: toggleLove()
        case .title: togglePopover(from: sender)
        }
    }

    private func toggleLove() {
        guard let track = player?.currentTrack, let collection else { return }
        Task {
            await collection.toggleTrackLike(track, client: appState?.client)
        }
    }

    private func togglePopover(from button: NSStatusBarButton) {
        if let popover, popover.isShown {
            popover.performClose(nil)
            return
        }

        guard let player, let collection, let appState else { return }
        let popover = self.popover ?? NSPopover()
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: MenuBarPlayerView()
                .environment(player)
                .environment(collection)
                .environment(appState)
        )
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
        self.popover = popover
    }

    // MARK: - Observation

    /// `@Observable` вне SwiftUI: подписка одноразовая, поэтому переустанавливаем её после каждого срабатывания.
    private func observePlayer() {
        withObservationTracking {
            _ = player?.currentTrack
            _ = player?.isPlaying
            _ = player?.isShuffled
            _ = player?.repeatMode
            _ = player?.queueIndex
            _ = collection?.likedTrackIDs
        } onChange: {
            Task { @MainActor [weak self] in
                self?.refresh()
                self?.observePlayer()
            }
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
