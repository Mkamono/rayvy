# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Rayvy is a small macOS-only launcher (menu-bar-less agent app), built with Swift Package Manager, not Xcode. It's the implementation of `SPEC.md` — read that file for the full product spec, config format, and (importantly) the explicit **out-of-scope list** (no fuzzy search, no GUI settings, no plugin/extension system, no cloud sync, no shell command execution, etc.). Treat `SPEC.md` as binding: don't add features it lists as out of scope, and don't reach for Go/Rust — Swift only.

Design philosophy: smallness over feature growth. The core flow is intentionally just `Global Hotkey → Command Palette → Apps / Clipboard / System`.

## Commands

```bash
swift build                    # debug build
swift build -c release         # release build
swift test                     # run all tests
swift test --filter ClipboardHistoryTests            # run one test class
swift test --filter ClipboardHistoryTests/testAddInsertsAtFront   # run one test method
./scripts/build-app.sh          # assembles dist/Rayvy.app (release build + Info.plist + ad-hoc codesign)
```

CI (`.github/workflows/ci.yml`) runs `swift build -v` and `swift test -v` on `macos-latest` for pushes to `main` and PRs. Releases (`.github/workflows/release.yml`) trigger on `v*.*.*` tags, run `scripts/build-app.sh` with `VERSION` set from the tag, and publish a zipped `Rayvy.app` to GitHub Releases.

There is no lint step configured.

## Architecture

Entry point is `Sources/Rayvy/main.swift`, which creates `AppDelegate` and calls `NSApplication.run()`. `AppDelegate` (`App/AppDelegate.swift`) wires together the app's few long-lived singletons and owns config reload propagation — it's the best starting point for understanding how pieces fit together.

Directory layout mirrors `SPEC.md`'s "実装構成" section:

- **App/** — `AppDelegate` (lifecycle, wiring, config hot-reload dispatch) and `PaletteWindowController` (owns the borderless `NSPanel` that hosts the palette; handles show/hide choreography — activates Rayvy and restores the previously-frontmost app on hide, Spotlight-style — panel resizing to fit content, and all palette keyboard handling: arrows, Return, Escape, ⌘K).
- **Palette/** — `PaletteView`/`PaletteViewModel` (SwiftUI, the palette UI and its state machine), `PaletteItem` (result-row model + `PaletteSearch`, a plain case-insensitive substring matcher — deliberately not fuzzy, per spec), `SystemCommand` (builds the "Commands" section: power actions, per-app quit, quit Rayvy).
- **Applications/** — `AppIndex` (scans `/Applications`, `/System/Applications`, `/System/Applications/Utilities`, `~/Applications` for `.app` bundles; caches in memory, `refresh()` to rebuild) and `AppLauncher` (thin wrapper over `NSWorkspace.openApplication`).
- **Hotkeys/** — `HotkeyManager` (registers the palette hotkey and per-bundle-ID Direct Hotkeys via the `KeyboardShortcuts` package; re-registering on config reload reuses existing `KeyboardShortcuts.Name`s rather than re-registering handlers, to avoid double-firing) and `HotkeySpec` (parses/describes strings like `"option+space"`; the token tables there are the single source of truth for both directions — see its doc comments before adding new key aliases).
- **Clipboard/** — `ClipboardMonitor` (polls `NSPasteboard.general` every 0.5s for changes; skips concealed/transient pasteboard types used by password managers, and copies made while an excluded app is frontmost) and `ClipboardHistory` (in-memory list persisted as JSON at `~/Library/Application Support/Rayvy/clipboard.json`; dedupes by text, trims to `maxItems`).
- **Config/** — `Config` (Decodable structs mirroring the TOML schema, each with manual `init(from:)` so missing keys fall back to per-field defaults rather than failing the whole decode), `ConfigLoader` (loads `~/.config/rayvy/config.toml` via TOMLKit, creates a default file on first run, never throws — falls back to `.default`), `ConfigWatcher` (watches `config.toml` itself via `DispatchSourceFileSystemObject`, catching in-place saves; on a rename/delete event — most editors replace the file on save rather than writing in place — it re-opens a fresh descriptor on the new file so it keeps watching after the replacement; debounces reload by 0.3s).
- **System/** — `SystemActions` (sleep/restart/shutdown via AppleScript `System Events`; running-app enumeration/quit, excluding Rayvy itself).

### Config as source of truth

Per `SPEC.md`, `~/.config/rayvy/config.toml` is the *sole* source of truth for settings — there is no general GUI settings surface. The one carved-out exception is Direct Hotkey assignment: an app's ⌘K action menu has an "Assign Hotkey…" action that captures a key combo and writes it back to `config.toml`'s `[[hotkeys]]` array via `ConfigWriter` (`Config/ConfigWriter.swift`), which parses the file with TOMLKit's mutable `TOMLTable` so the rest of the document is preserved. It doesn't call back into `AppDelegate` directly — writing the file is enough, since `ConfigWatcher` picks up the change and hot-reloads it exactly like a manual edit, keeping the one-way reload flow intact. Don't extend `PaletteAction` beyond this one case (e.g. no editing `launcher.hotkey` or `clipboard.*` from the UI) — keep that boundary when adding new actions.

Config hot-reload flows one way: `ConfigWatcher` → `ConfigLoader.reload()` → `AppDelegate.applyConfig(_:)`, which re-applies clipboard settings, calls `appIndex.refresh()`, and re-registers hotkeys. There's no reverse path.

### Panel sizing

`PaletteWindowController` anchors the panel's top-left position once per `show()` and only ever changes its height (driven by `PaletteViewModel.$contentHeight` via Combine) — this keeps the search field from jumping around as results change. If you touch palette layout constants (row height, section header height, etc.), they live as `static let`s on `PaletteViewModel` and are shared between the view model's height math and the SwiftUI view itself.

### Dependencies

Two external packages, pinned deliberately narrow:
- `KeyboardShortcuts` — pinned below 1.16.0 because newer releases require Xcode's PreviewsMacros plugin, which isn't available under plain Command Line Tools + `swift build` (see the comment in `Package.swift`).
- `TOMLKit` — TOML parsing for config.

Keep new dependencies minimal, per `SPEC.md`'s "外部依存はできるだけ少なくする".
