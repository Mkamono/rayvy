# Rayvy

Lightweight macOS launcher. `⌥Space` → Command Palette → apps, clipboard history, system actions.

## Overview

Rayvy is a small, always-running (Dock/menu-bar-less) macOS app built around one flow:

```text
Global Hotkey → Command Palette → Apps / Clipboard History / System Commands
```

It deliberately stays small — no fuzzy search, no GUI settings screen, no plugins, no cloud sync.
See [`SPEC.md`](SPEC.md) for the full design and the explicit out-of-scope list.

## Installation

Via [mise](https://mise.jdx.dev):

```bash
cp mise.example.toml mise.toml   # or merge the [bootstrap.packages] entry into your own
mise bootstrap
```

Or download `Rayvy-<version>-arm64.zip` from [Releases](https://github.com/Mkamono/rayvy/releases), unzip, and
move `Rayvy.app` to `/Applications`.

Rayvy.app is ad-hoc signed (not notarized), so macOS Gatekeeper will refuse to open it on first launch — see
[Troubleshooting](#troubleshooting).

## Usage

Press the launcher hotkey (`⌥Space` by default) to open the Command Palette. Type to search apps, System
Commands, and Clipboard History together (plain substring match, not fuzzy). Use the arrow keys and Return to
select, Escape to close.

Selecting an item with secondary actions (apps, Clipboard History entries) shows a `⌘K` hint — press `⌘K` to
open its action menu (Quit, Reveal in Finder, Copy Bundle ID, Assign Hotkey…, etc).

While the palette is open, Rayvy switches the system input source to a Roman/alphabet layout so typing a query
doesn't fight with an IME, and restores your previous input source when it closes.

## Configuration

Settings live in a single TOML file, created with defaults on first run:

```text
~/.config/rayvy/config.toml
```

It's hot-reloaded on save — no restart needed. Example:

```toml
[launcher]
hotkey = "option+space"

[clipboard]
enabled = true
max_items = 100
excluded_bundle_ids = []
hotkey = "cmd+shift+v"

[[hotkeys]]
key = "option+t"
bundle_id = "com.mitchellh.ghostty"
```

Hotkey strings combine modifiers (`cmd`/`command`, `option`/`alt`, `shift`, `control`/`ctrl`) with a key,
joined by `+` (e.g. `"cmd+shift+t"`). An invalid value clears whatever was previously bound rather than leaving
the old shortcut active.

## Direct Hotkeys

`[[hotkeys]]` entries bind a global shortcut straight to an app by bundle ID, without opening the palette
first. Pressing it launches the app if it isn't running, activates it if it's running in the background, and
hides it if it's already frontmost.

Two ways to set one:

- **In the app**: select the app in the Command Palette, press `⌘K`, choose "Assign Hotkey…" (or "Change
  Hotkey…" if one's already set), then press the key combination. This is the one setting Rayvy will write to
  `config.toml` on your behalf.
- **By hand**: add a `[[hotkeys]]` entry to `config.toml` yourself. Use the app's `⌘K` → "Copy Bundle ID" action
  to get its bundle ID.

## Clipboard History

Rayvy watches the system pasteboard and keeps a deduplicated, in-memory history (persisted to
`~/Library/Application Support/Rayvy/clipboard.json`), text only. Press its hotkey (`cmd+shift+v` by default) to
jump straight into a clipboard-only view of the palette; selecting an entry recopies it and pastes it into
whatever app was frontmost.

Configurable via `[clipboard]`: `enabled`, `max_items`, `excluded_bundle_ids` (copies made while one of these
apps is frontmost — e.g. a password manager — are ignored), and `hotkey`.

Pasting requires Accessibility permission (see [Troubleshooting](#troubleshooting)); without it, the item still
lands on the pasteboard for a manual `⌘V`.

## System Commands

Available from the palette's "Commands" section: Sleep, Restart, Shut Down, Quit All Applications, Quit
`<running app>` (per running app), Open Rayvy Settings (opens `config.toml`), Rayvy Docs (opens this README on
GitHub), and Quit Rayvy.

## Troubleshooting

**Gatekeeper blocks the first launch** ("Rayvy.app is damaged and can't be opened" or similar) — Rayvy.app is
ad-hoc signed, not notarized. Right-click the app in Finder and choose Open, or clear the quarantine flag:

```bash
xattr -d com.apple.quarantine /Applications/Rayvy.app
```

**Granted Accessibility permission, but Clipboard History still won't paste** — the permission check only
re-evaluates when Rayvy launches. Quit and reopen Rayvy after granting it in System Settings → Privacy &
Security → Accessibility.

**A hotkey stopped working after editing `config.toml`** — check for a typo in the hotkey string; an
unrecognized modifier or key silently clears that binding instead of keeping the old one active (see
Configuration above).
