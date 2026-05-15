# Contributing

Thanks for your interest in contributing to **yamp-zvuk**. This is a hobby project — a small, unofficial macOS client for zvuk.com — so the process is informal, but a few conventions help keep the codebase consistent.

## Before you start

- **Check open issues and PRs first.** Someone may already be working on the same thing.
- **For non-trivial changes, open an issue first** to discuss the approach. This avoids wasted work on PRs that won't be merged.
- **Small fixes and obvious improvements** can go straight to a PR.

## Development setup

Requirements:

- macOS 15+
- Xcode 16+ (Swift 6)
- [xcodegen](https://github.com/yonaskolb/XcodeGen) (install via `brew install xcodegen`)
- [gh](https://cli.github.com) (optional, for releases)

Clone and bootstrap:

```bash
git clone https://github.com/korenskoy/yamp-zvuk-com.git
cd yamp-zvuk-com
xcodegen generate
open YAMP.xcodeproj
```

The project depends on [ZvukMusic](https://github.com/korenskoy/zvuk-swift) (GraphQL/REST client) and `LastFM.swift`, both resolved via SPM on first build.

## Build & lint

| Task | Command |
|------|---------|
| Regenerate Xcode project after `project.yml` changes | `xcodegen generate` |
| Build a Debug app | open in Xcode and ⌘B, or `xcodebuild -scheme YAMP build` |
| Build a release DMG | `./scripts/build-dmg.sh` (maintainers only — bumps build number) |
| Run linter | `./scripts/lint.sh` |
| Auto-fix lint issues | `./scripts/lint_fix.sh` |

SwiftLint runs automatically on every build via an SPM build-tool plugin. A pre-commit hook also lints staged Swift files and blocks the commit on violations. **New code must pass SwiftLint with zero warnings before being committed.**

Use `// swiftlint:disable:next rule_name` only when there is a real reason (e.g. SVG path literals).

## Code style

### Language

- **UI strings: Russian.** Use «Альбомы» (not «Релизы»).
- **Code: English.** Identifiers, comments, log messages, commit messages, PR descriptions.

### Swift / SwiftUI conventions

These rules come from `CLAUDE.md` (the project's working notes) — please follow them so the codebase stays consistent.

- **DI via `@Environment`.** Services are injected through `@Environment(SomeService.self)`. Don't introduce singletons or global accessors.
- **Observation:** prefer `@Observable` (Swift 6) over the older `ObservableObject` / `@Published` pattern.
- **Buttons on macOS:** never use `.buttonStyle(.borderedProminent)` — it disappears when the window loses focus. Use `.buttonStyle(.accent)` (the project's `AccentButtonStyle`) instead.
- **Colors:** `Color.accentColor` (not `.accent`) with `.foregroundStyle()`.
- **Cached images:** `CachedAsyncImage` — drop-in replacement for `AsyncImage`. Always use it.
- **Grids:** `GridItem(.adaptive(...))` inside `LazyVGrid` — never `GeometryReader` + manual column math inside a `ScrollView`.
- **Liquid Glass effects:** must be gated behind `if #available(macOS 26.0, *)`. The deployment target stays macOS 15.

### Networking

- **Never parallelize requests to the Zvuk API.** No `TaskGroup`, no `async let`. The API is unofficial — concurrent bursts attract attention and can get accounts throttled or banned. Run requests sequentially.
- **Always log API requests** via `LogStore` (`logStore.appendLastFM(...)` etc.). Never silently swallow errors with empty `catch {}`.
- **Cache where the project caches.** `CacheService` handles grids, playlists, releases, artists. `ImageCacheService` handles artwork (file-based, 7-day TTL). Don't bypass them.

### Error handling

- **Never show raw errors to the user.** No `String(describing: error)`, no `error.localizedDescription` directly in UI. Route through `AppError.from(error)` for a Russian message.
- **Use `.errorAlert($viewModel.appError)`** to present errors (native-style Apple Music alert).
- **Validation/status messages are not errors** — store them in `validationMessage` / `statusMessage` and show inline.
- **`CancellationError` is ignored** by `AppError.from`.

### Dead code

- Don't keep unused services, view models, or views. Delete them.
- Don't leave `// TODO` comments without an associated issue.
- Don't add comments that explain *what* the code does (well-named identifiers do that). Comments should only explain non-obvious *why*.

## Commit and PR conventions

### Commits

Look at `git log` for the established style. In short:

- **Imperative mood, capitalised:** `Add Last.fm scrobbling`, `Fix queue advancement on Wave`. Not `added`, not `adds`, not `lowercase`.
- **Subject line under ~70 characters.** Body wraps at ~72 characters if you need one.
- **Body explains *why*** when it isn't obvious from the diff. Skip the body for trivial fixes.
- **One logical change per commit.** Don't bundle a refactor with a bug fix.
- **No `Co-Authored-By:` trailers** unless the change genuinely had multiple human authors.

### Pull requests

- **Base branch: `main`.** There is no `develop` branch.
- **One feature per PR.** Big PRs are slow to review — split them.
- **PR description** should mirror what would go into the release notes for an end user, plus a "How to test" section.
- **Screenshots / screen recordings** for any UI change. macOS-specific (Liquid Glass, dark mode) — show both modes if relevant.
- **CI / lint must pass.** A red build will not be merged.

## Fair use and the Zvuk API

This is an **unofficial** client. It uses the same public GraphQL/REST endpoints that the official zvuk.com web app and mobile apps use. There is no agreement with the company that owns Zvuk; the project is not endorsed by them.

Contributions that affect the API layer (`zvuk-swift` package, `Sources/YAMP/Services/*`) should respect a few principles:

- **Don't be a bad citizen.** Avoid request bursts, parallelism, retry loops without backoff, or anything that looks like scraping. Run API calls sequentially.
- **Don't redistribute Zvuk content.** The client streams audio and shows metadata on the user's own device — it must not download, cache to disk, or re-upload Zvuk's audio or proprietary metadata in a way that goes beyond personal use of the official service.
- **Don't add features that bypass paid-tier checks.** High-quality / FLAC streaming requires a Zvuk subscription on the user's account. The client uses whatever quality the user's account is entitled to and doesn't try to work around that.
- **Authentication uses the user's own Zvuk token.** Don't add features that share tokens, log them, or send them anywhere except to Zvuk's own servers.

PRs that violate these rules will not be merged. Reverse-engineering work that is purely about *consuming* the existing public API on behalf of a logged-in user (the standard mode of this client) is welcome.

## Releases

Releases are cut by the maintainer using `./scripts/build-dmg.sh` and `gh release create`. Version lives in `Configuration/Version.xcconfig` — `MARKETING_VERSION` is bumped manually by the maintainer, `CURRENT_PROJECT_VERSION` is bumped by the build script. Tags follow `vX.Y.Z`. Contributors don't need to touch any of this.

## Code of Conduct

This project adopts the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md). By participating, you agree to abide by its terms.

## Licence

By contributing, you agree that your contributions are licensed under the same licence as this repository — see [LICENSE](LICENSE).
