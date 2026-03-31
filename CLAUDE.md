# CLAUDE.md

This file provides guidance to Claude Code when working with the yamp-zvuk codebase.

## Project Overview

**yamp-zvuk** is an unofficial macOS desktop client for zvuk.com, built with SwiftUI.

- **Platform**: macOS 15+, Swift 6
- **UI Framework**: SwiftUI with `@Observable` pattern
- **Bundle ID**: `ru.korenskoy.zvuk-unofficial`
- **API**: GraphQL + REST via `ZvukMusic` Swift package (`../zvuk-swift`, v0.2.0+)

## Build Commands

```bash
# Generate Xcode project (after changing project.yml)
xcodegen generate

# Build DMG (only on explicit user request!)
./scripts/build-dmg.sh

# Lint
./scripts/lint.sh

# Lint with auto-fix
./scripts/lint_fix.sh
```

## Architecture

- `Sources/YAMP/App/` — App entry point, AppState (navigation, auth)
- `Sources/YAMP/Services/` — PlayerService, CacheService, CollectionService, ImageCacheService, LastFMService, ListeningHistoryStore, LyricsService
- `Sources/YAMP/Views/` — SwiftUI views organized by feature
- `Sources/YAMP/ViewModels/` — View models (`@Observable`)
- `Sources/YAMP/Models/` — NavigationDestination, etc.

### Key Patterns

- **DI via `@Environment`**: Services injected as `@Environment(PlayerService.self)`
- **Navigation**: `AppState.selectedDestination` enum (home, popular, search, collection, history, wave, artist, release, playlist, etc.), history stack for back/forward
- **Search**: `.searchable(placement: .toolbar)` on ContentView's detail, `SearchViewModel` owned by ContentView and passed to SearchView
- **Caching**: API responses via `CacheService` (grids, playlists, releases, artists), images via `ImageCacheService` (file-based, 7-day TTL)
- **Grid API**: `CacheService.getGrid(name:)` loads CMS-managed page structure (sections with playlists, releases, artists). `PopularViewModel` parses grid sections and loads data per type. Sections listed in `ignoredGridSections` are skipped. Per-section error handling — one failing section doesn't break the page
- **Image loading**: `CachedAsyncImage` — drop-in replacement for `AsyncImage`, always use it
- **Generated covers**: `GeneratedCoverView(seed:)` — deterministic `MeshGradient` for items without artwork (e.g. recommendation playlists)

## UI Style Guide

### Buttons

Consistent button styling across the entire app:

- **Primary action** (Play, Create, Save): `.borderedProminent` + `.controlSize(.large)`
- **Icon buttons** (like, shuffle, subscribe, delete, edit): `.buttonStyle(.plain)` + `.font(.title2)` + `.foregroundStyle(.secondary)`
- **Dialog buttons** (Cancel): `.bordered`; (Confirm): `.borderedProminent`

### Track Lists

Compact layout — `VStack(spacing: 4)` with `TrackRowView`:
- 36x36 cover, cornerRadius 4
- Highlight current track with accent background
- Play/speaker icon overlay on current track's cover

### Grids (Albums, Playlists, Podcasts)

Use `GridItem(.adaptive(...))` — **never** `GeometryReader` + manual column calculation inside `ScrollView` (it has no intrinsic height, causes layout bugs and wrong tap targets):
```swift
LazyVGrid(columns: [GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 16, alignment: .top)], spacing: 16) {
    ...
}
```

- **`alignment: .top`** is required — without it, cards with different text lengths misalign images
- **`.contentShape(Rectangle())`** on each card — ensures tap target matches the visible area
- Cards: square image with `GeometryReader` + `.aspectRatio(1, contentMode: .fit)` + `.clipped()` + `.clipShape(RoundedRectangle(cornerRadius: 10))`, center-aligned labels below (`.caption` title + `.caption2` subtitle)

### Hover Play Overlay

Covers with play-on-hover (ReleaseThumbnailView, PlayableCoverView, RecommendedPlaylistCardView, EditorialPlaylistCardView) must animate the overlay:
```swift
.animation(.easeInOut(duration: 0.2), value: isHovered)
```

### Horizontal Carousels

For "related" / "top" sections — `ScrollView(.horizontal)` + `HStack(spacing: 12)` with fixed-size thumbnails (`size: 160`).
Every horizontal carousel must include an expand button (`arrow.up.left.and.arrow.down.right`) in the section header that opens a `GridSheet` with all items in a grid layout.

### Header Views (Release, Playlist, Artist)

- Cover: 160x160, cornerRadius 12, shadow, clickable (opens full-size sheet)
- Layout: `HStack` — cover left, metadata + buttons right

### PlayerBar Components

- **ProgressBarView**: Thin 2pt progress line at the bottom of PlayerBar. On hover (200ms delay), expands to 8pt capsule growing upward (overlay, no layout shift). Time labels + gradient overlay appear over PlayerBar content via `progressOverlay` in PlayerBarView. Drag gesture for seeking. `isExpanded` is a `@Binding` controlled by PlayerBarView's `showProgress` state.
- **VolumeControlView**: Icon button (speaker with dynamic wave count) opens a vertical slider in a `.popover`. Icon uses `.frame(width: 20)` to prevent layout shift between speaker icons of different widths.
- **Wave auto-continue**: When queue ends during Wave playback, `PlayerService.loadMoreWave` fetches the next batch via `WaveParams.fetchTracks(client:)` — shared method that eliminates duplication between WaveViewModel and PlayerService.

### Liquid Glass (macOS 26+)

All Liquid Glass effects are behind `if #available(macOS 26.0, *)` via private `ViewModifier`s (deployment target stays macOS 15):

- **PlayerBarView**: `.glassEffect(.regular.interactive())` replaces `.background(.bar)`, `Divider` hidden
- **PlayerControlsView**: Play/Pause button gets `.glassEffect` in `.circle`
- **SidebarView**: Bottom panel gets `.glassEffect(.regular)` replaces `.background(.bar)`
- **GlassTabBar**: Reusable tab bar component (`Views/Components/GlassTabBar.swift`) — `.glassEffect(.regular)` in `.capsule` on macOS 26, plain on macOS 15. Used in SearchView, CollectionView
- **CoverSheetView**: `.glassEffect(.regular)` replaces `.ultraThinMaterial`
- **NowPlayingView**: Cover image gets `.glassEffect` frame

Pattern for new glass effects:
```swift
private struct MyGlassModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: .rect(cornerRadius: 12))
        } else {
            content.background(.bar) // fallback
        }
    }
}
```

## Linting

SwiftLint integrated via SPM Build Tool Plugin (`SwiftLintBuildToolPlugin`). Runs automatically on every build. Config: `.swiftlint.yml`.

- **Pre-commit hook**: lints only staged `.swift` files, blocks commit on violations
- **Scripts**: `scripts/lint.sh` (check), `scripts/lint_fix.sh` (auto-fix)
- **Binary location**: `.build/artifacts/swiftlint/SwiftLintBinary/SwiftLintBinary.artifactbundle/macos/swiftlint` (resolved via `swift package resolve`)
- New code must pass SwiftLint with zero warnings before commit
- Use `// swiftlint:disable:next rule_name` only for justified cases (e.g. SVG path data in Shape)

## Code Style and important notes

- **Language**: Russian for UI strings, English for code. Use "Альбомы" (not "Релизы") in UI
- **SwiftUI color**: Use `Color.accentColor` (not `.accent`) with `.foregroundStyle()`
- **Кнопки**: Не использовать `.buttonStyle(.borderedProminent)` — на macOS кнопка пропадает когда окно теряет фокус. Использовать `.buttonStyle(.accent)` (`AccentButtonStyle`) вместо этого
- **ProgressView centering**: Full-page spinners must be outside `ScrollView` (wrapped in `Group`), not inside — `ScrollView` doesn't expand to fill available height
- **No DMG auto-build**: Only build DMG when explicitly requested
- **Do not forget about CacheService**
- **All requests to API must be logged** (look at LogStore) — never use empty `catch {}`, always surface or log errors
- **Last.fm integration**: `LastFMService` handles auth (Keychain), now playing, scrobble, and track love/unlove sync via `LastFM.swift` package. When a track is liked/unliked in Zvuk, `CollectionService` automatically calls `loveTrack`/`unloveTrack` on Last.fm (if scrobbling is enabled). API calls go through `LastFMAPIClient` (nonisolated wrapper for Swift 6 Sendable). All Last.fm requests are logged via `LogStore.appendLastFM`
- **No dead code**: Do not keep unused services/view models
- **Version/build**: Use `$(MARKETING_VERSION)` / `$(CURRENT_PROJECT_VERSION)` from project.yml in Info.plist, not hardcoded values
- **About panel**: Uses `orderFrontStandardAboutPanel` with credits linking to Zvuk.com; version read from `Bundle.main`
- **Removed menus**: Edit, View (tab bar, fullscreen), Help — removed via `CommandGroup(replacing:)`

### Error Display

- **Никогда не показывать сырые ошибки** пользователю (`String(describing:)`, `error.localizedDescription`). Все ошибки в UI проходят через `AppError.from(error)` → русскоязычное сообщение
- **Использовать `.errorAlert($viewModel.appError)`** для показа ошибок (Apple Music-стиль нативный алерт)
- **Свойство ошибки в ViewModel** — `var appError: AppError?`, не `String?`
- **`CancellationError`** игнорируется (`AppError.from()` возвращает `nil`)
- **Валидационные сообщения** (напр. "Введите токен") — НЕ ошибки, хранятся в отдельном `var validationMessage: String?` и отображаются inline
- **Статусные сообщения** (напр. "Треки не найдены") — НЕ ошибки, хранятся в `var statusMessage: String?`
