import Foundation
import KeyboardShortcuts

/// Registers the Command Palette hotkey, the Clipboard History hotkey, and the per-app Direct
/// Hotkeys from `Config`, and re-registers everything when the config is hot-reloaded.
///
/// `KeyboardShortcuts.Name`s are created once per logical hotkey (palette, clipboard history, or
/// a given bundle ID) and cached; reloading only calls `setShortcut`, so `onKeyDown` handlers are
/// never registered twice for the same key (which would otherwise double-fire an action). A
/// bundle ID removed from the config gets its shortcut cleared so it stops responding.
@MainActor
final class HotkeyManager {
    private var paletteName: KeyboardShortcuts.Name?
    private var clipboardHistoryName: KeyboardShortcuts.Name?
    private var directHotkeyNames: [String: KeyboardShortcuts.Name] = [:] // bundle ID -> Name

    func register(config: Config, onTogglePalette: @escaping () -> Void, onToggleClipboardHistory: @escaping () -> Void) {
        registerSingleHotkey(
            config.launcher.hotkey,
            name: &paletteName,
            identifier: "rayvy.palette",
            logContext: "launcher.hotkey",
            action: onTogglePalette
        )
        registerSingleHotkey(
            config.clipboard.hotkey,
            name: &clipboardHistoryName,
            identifier: "rayvy.clipboardHistory",
            logContext: "clipboard.hotkey",
            action: onToggleClipboardHistory
        )
        registerDirectHotkeys(config.hotkeys)
    }

    func unregisterAll() {
        if let paletteName {
            KeyboardShortcuts.setShortcut(nil, for: paletteName)
        }
        if let clipboardHistoryName {
            KeyboardShortcuts.setShortcut(nil, for: clipboardHistoryName)
        }
        for name in directHotkeyNames.values {
            KeyboardShortcuts.setShortcut(nil, for: name)
        }
    }

    private func registerSingleHotkey(
        _ spec: String,
        name: inout KeyboardShortcuts.Name?,
        identifier: String,
        logContext: String,
        action: @escaping () -> Void
    ) {
        guard let shortcut = HotkeySpec.parse(spec) else {
            logInvalid(spec: spec, context: logContext)
            // Config is the source of truth: an edit that makes the spec invalid should clear
            // whatever was bound before, not leave the last-valid shortcut silently active.
            if let existing = name {
                KeyboardShortcuts.setShortcut(nil, for: existing)
            }
            return
        }

        let resolvedName: KeyboardShortcuts.Name
        if let existing = name {
            resolvedName = existing
        } else {
            resolvedName = KeyboardShortcuts.Name(identifier)
            name = resolvedName
            KeyboardShortcuts.onKeyDown(for: resolvedName, action: action)
        }
        KeyboardShortcuts.setShortcut(shortcut, for: resolvedName)
    }

    private func registerDirectHotkeys(_ entries: [HotkeyEntry]) {
        var configuredBundleIDs = Set<String>()

        for entry in entries {
            configuredBundleIDs.insert(entry.bundleID)

            guard let shortcut = HotkeySpec.parse(entry.key) else {
                logInvalid(spec: entry.key, context: entry.bundleID)
                // The bundle ID stays in `configuredBundleIDs`, so the cleanup loop below won't
                // catch this one — clear it here instead of leaving the last-valid key active.
                if let existing = directHotkeyNames[entry.bundleID] {
                    KeyboardShortcuts.setShortcut(nil, for: existing)
                }
                continue
            }

            let name: KeyboardShortcuts.Name
            if let existing = directHotkeyNames[entry.bundleID] {
                name = existing
            } else {
                let bundleID = entry.bundleID
                let newName = KeyboardShortcuts.Name("rayvy.hotkey.\(bundleID)")
                directHotkeyNames[bundleID] = newName
                KeyboardShortcuts.onKeyDown(for: newName) {
                    AppLauncher.toggle(bundleID: bundleID)
                }
                name = newName
            }
            KeyboardShortcuts.setShortcut(shortcut, for: name)
        }

        for (bundleID, name) in directHotkeyNames where !configuredBundleIDs.contains(bundleID) {
            KeyboardShortcuts.setShortcut(nil, for: name)
        }
    }

    private func logInvalid(spec: String, context: String) {
        FileHandle.standardError.write(Data("[Rayvy] hotkeys: invalid hotkey \"\(spec)\" (\(context))\n".utf8))
    }
}
