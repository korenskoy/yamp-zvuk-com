import AppKit
import SwiftUI
import ZvukMusic

/// Элемент плеера в строке меню. Каждый — отдельный `NSStatusItem`:
/// SwiftUI `MenuBarExtra` рисует label целиком некликабельным, кнопки в нём невозможны.
enum MenuBarElement: String, CaseIterable, Identifiable {
    case logo, shuffle, previous, playPause, next, repeatMode, love, title

    var id: String { rawValue }

    var label: String {
        switch self {
        case .logo: "Логотип"
        case .shuffle: "Перемешать"
        case .previous: "Предыдущий трек"
        case .playPause: "Играть / Пауза"
        case .next: "Следующий трек"
        case .repeatMode: "Повтор"
        case .love: "В любимые"
        case .title: "Название трека"
        }
    }

    static let defaults: [Self] = [.logo, .previous, .playPause, .next, .title]
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

    static let titleLimitKey = "menuBarTitleLimit"
    static let defaultTitleLimit = 30

    /// Сколько символов показывать в названии трека: строка меню делится с меню активного
    /// приложения, и длинный заголовок вытесняет все иконки разом.
    static var titleLimit: Int {
        UserDefaults.standard.object(forKey: titleLimitKey) as? Int ?? defaultTitleLimit
    }
}

@MainActor
final class MenuBarController {
    /// Идентификатор главного окна: по нему `openWindow` пересоздаёт закрытую сцену.
    static let mainWindowID = "main"

    /// Пробрасывается из SwiftUI: `openWindow` живёт только в окружении `View`.
    var openMainWindow: (() -> Void)?

    private var items: [MenuBarElement: NSStatusItem] = [:]
    private var popover: NSPopover?
    /// Настройки, уже применённые к строке меню.
    private var appliedSettings: Settings?

    private var player: PlayerService?
    private var collection: CollectionService?
    private weak var appState: AppState?

    /// Снимок настроек, влияющих на строку меню.
    ///
    /// `UserDefaults.didChangeNotification` — это поток *всех* записей в
    /// defaults: громкость, состояние плеера, порядок плейлистов. Сравнение со
    /// снимком отсекает чужие записи, а заодно делает рекурсию невозможной —
    /// `isVisible` ниже пишет в defaults, но в снимок не входит.
    private struct Settings: Equatable {
        let isEnabled = MenuBarSettings.isEnabled
        let elements = MenuBarSettings.elements
        let titleLimit = MenuBarSettings.titleLimit
    }

    /// Вызывается из `.task` главного окна, а окно пересоздаётся пунктом «Показать» —
    /// без этой защиты каждое новое окно вешало бы ещё один наблюдатель настроек
    /// и ещё одну цепочку слежения за плеером.
    func configure(player: PlayerService, collection: CollectionService, appState: AppState) {
        guard self.player == nil else { return }

        self.player = player
        self.collection = collection
        self.appState = appState

        applySettings()
        observePlayer()

        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.applySettings() }
        }
    }

    /// Перерисовывает строку меню, только если поменялись именно её настройки.
    private func applySettings() {
        let settings = Settings()
        guard settings != appliedSettings else { return }
        appliedSettings = settings
        refresh()
    }

    // MARK: - Building

    /// Все элементы создаются один раз и живут до конца сессии, вкл/выкл — через `isVisible`.
    /// Пересоздание при каждом изменении настроек ломает сохранённые позиции: macOS хранит их
    /// по порядковому номеру создания, нумерация съезжает, и элемент подхватывает чужую позицию
    /// (в том числе с отключённого монитора) — уезжает за пределы строки меню и пропадает.
    ///
    /// Пока плеер в строке меню выключен, не создаём ничего: каждый `NSStatusItem` — это окно
    /// в оконном сервере, держать восемь штук ради выключенной функции незачем.
    private func build() {
        guard items.isEmpty else { return }
        // NSStatusItem'ы выстраиваются справа налево, поэтому создаём в обратном порядке.
        for element in MenuBarElement.allCases.reversed() {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            // Без autosaveName менеджеры строки меню (Ice, Bartender) при каждом запуске
            // считают элемент новым и прячут обратно.
            item.autosaveName = "YAMP.\(element.rawValue)"
            item.button?.target = self
            item.button?.action = #selector(handleClick(_:))
            // Правая кнопка приходит тем же действием: назначить `item.menu` нельзя,
            // иначе меню перехватит и обычный клик, и кнопки перестанут работать.
            item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
            item.button?.tag = MenuBarElement.allCases.firstIndex(of: element) ?? 0
            items[element] = item
        }
    }

    // MARK: - Rendering

    private func refresh() {
        guard let player else { return }

        let visible = MenuBarSettings.isEnabled ? Set(MenuBarSettings.elements) : []
        if !visible.isEmpty { build() }

        // Порядок здесь не важен: позиции задаёт build(), а элементы независимы.
        for (element, item) in items {
            let isWanted = visible.contains(element)
            // Присваивание пишет в UserDefaults, а лишняя запись дёргает диск и наблюдателей.
            if item.isVisible != isWanted { item.isVisible = isWanted }

            guard isWanted, let button = item.button else { continue }
            button.image = nil
            button.title = ""
            button.alphaValue = 1
            button.isEnabled = true
            button.toolTip = element.label
            render(element, into: button, player: player)
        }
    }

    /// Набор элементов настраивается пользователем и стоит на фиксированных местах,
    /// поэтому в эфире трековые кнопки не прячутся, а гаснут: иначе строка меню
    /// перекладывалась бы при каждом включении радио.
    private func render(_ element: MenuBarElement, into button: NSStatusBarButton, player: PlayerService) {
        let track = player.currentTrack
        let isRadio = player.currentStation != nil

        switch element {
        case .logo:
            button.image = Self.logoImage
            button.toolTip = "Плеер"

        case .shuffle:
            button.image = symbol("shuffle")
            button.isEnabled = !isRadio
            button.alphaValue = isRadio ? 0.3 : (player.isShuffled ? 1 : 0.5)

        case .previous:
            button.image = symbol("backward.fill")
            button.isEnabled = !isRadio && player.hasPrevious

        case .playPause:
            button.image = symbol(player.isPlaying ? "pause.fill" : "play.fill")
            button.isEnabled = track != nil || isRadio

        case .next:
            button.image = symbol("forward.fill")
            button.isEnabled = !isRadio && player.hasNext

        case .repeatMode:
            button.image = symbol(player.repeatMode == .one ? "repeat.1" : "repeat")
            button.isEnabled = !isRadio
            button.alphaValue = isRadio ? 0.3 : (player.repeatMode == .off ? 0.5 : 1)

        case .love:
            let isLiked = !isRadio && track.map { collection?.isTrackLiked($0.id) ?? false } ?? false
            button.image = symbol(isLiked ? "heart.fill" : "heart")
            button.isEnabled = !isRadio && track != nil

        case .title:
            if let station = player.currentStation {
                let onAir = player.onAir?.displayLine
                button.title = Self.titleText(onAir ?? station.name)
                button.toolTip = onAir.map { "\($0) · \(station.name)" } ?? station.name
            } else if let track {
                button.title = Self.titleText(for: track)
                button.toolTip = "\(track.artists.map(\.title).joined(separator: ", ")) — \(track.title)"
            } else {
                button.image = symbol("music.note")
            }
        }
    }

    /// SVG в ассетах отдаётся в исходных 1024×1024 — ужимаем под соседние SF Symbols.
    private static let logoImage: NSImage? = {
        guard let image = NSImage(named: "MenuBarLogo")?.copy() as? NSImage else { return nil }
        image.isTemplate = true
        image.size = NSSize(width: 16, height: 16)
        return image
    }()

    private func symbol(_ name: String) -> NSImage? {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
        image?.isTemplate = true
        return image
    }

    private static func titleText(for track: SimpleTrack) -> String {
        let artists = track.artists.map(\.title).joined(separator: ", ")
        return titleText(artists.isEmpty ? track.title : "\(artists) — \(track.title)")
    }

    /// Строка меню делится с меню активного приложения, поэтому длинное
    /// название подрезается по настроенному лимиту.
    private static func titleText(_ full: String) -> String {
        let limit = MenuBarSettings.titleLimit
        guard full.count > limit else { return full }
        return full.prefix(limit - 1).trimmingCharacters(in: .whitespaces) + "…"
    }

    // MARK: - Actions

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        // Меню общее для всех кнопок и плеера не касается, поэтому проверяем до guard.
        if isContextClick {
            showContextMenu(from: sender)
            return
        }

        guard let element = MenuBarElement.allCases[safe: sender.tag], let player else { return }

        switch element {
        case .shuffle: player.toggleShuffle()
        case .previous: player.previous()
        case .playPause: player.togglePlayPause()
        case .next: player.next()
        case .repeatMode: player.cycleRepeatMode()
        case .love: toggleLove()
        case .logo, .title: togglePopover(from: sender)
        }
    }

    private func toggleLove() {
        // В эфире лайкать нечего, а в очереди мог остаться трек с прошлого прослушивания.
        guard player?.currentStation == nil else { return }
        guard let track = player?.currentTrack, let collection else { return }
        Task {
            await collection.toggleTrackLike(track, client: appState?.client)
        }
    }

    // MARK: - Context menu

    /// Правый клик или Ctrl+клик — на macOS это одно и то же приглашение к меню.
    /// Кнопка подписана только на `leftMouseUp`/`rightMouseUp`, других типов не придёт.
    private var isContextClick: Bool {
        guard let event = NSApp.currentEvent else { return false }
        return event.type == .rightMouseUp || event.modifierFlags.contains(.control)
    }

    private func showContextMenu(from button: NSStatusBarButton) {
        let menu = NSMenu()

        let show = NSMenuItem(title: "Показать", action: #selector(showMainWindow), keyEquivalent: "")
        show.target = self
        menu.addItem(show)

        menu.addItem(.separator())

        // Выход — стандартное действие приложения, отдельная обёртка ему не нужна.
        let quit = NSMenuItem(
            title: "Выйти", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)

        // Поповер перекрыл бы меню — он `.transient` и сам не закроется.
        popover?.performClose(nil)
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }

    @objc private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)

        // Поповер плеера — тоже окно, но главным стать не может, поэтому не спутаем.
        if let window = NSApp.windows.first(where: { $0.canBecomeMain }) {
            if window.isMiniaturized { window.deminiaturize(nil) }
            window.makeKeyAndOrderFront(nil)
            return
        }
        // Закрытое окно `WindowGroup` уничтожается вместе со сценой, и вернуть его
        // может только сам SwiftUI. `applicationShouldHandleReopen` для этого не
        // годится: делегат отвечает `true`, но окно не создаётся — проверено.
        //
        // Сцена именно `WindowGroup`, хотя окно одно: у `Window` система включает
        // `applicationShouldTerminateAfterLastWindowClosed`, и закрытие окна убивало бы
        // приложение вместе со строкой меню.
        openMainWindow?()
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
            _ = player?.currentStation
            _ = player?.onAir
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

/// Отдаёт контроллеру строки меню действие открытия главного окна.
///
/// `openWindow` доступен только через окружение `View`, а контроллер — обычный
/// класс, поэтому действие приходится передавать ему отсюда.
struct MainWindowOpener: ViewModifier {
    @Environment(\.openWindow) private var openWindow
    let controller: MenuBarController

    func body(content: Content) -> some View {
        content.onAppear {
            controller.openMainWindow = { openWindow(id: MenuBarController.mainWindowID) }
        }
    }
}
