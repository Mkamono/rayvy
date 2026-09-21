import Foundation
import KeyboardShortcuts

/// Registers the Command Palette hotkey and the per-app Direct Hotkeys from `Config`, and
/// re-registers everything when the config is hot-reloaded.
///
/// `KeyboardShortcuts.Name`s are created once per logical hotkey (palette, or a given bundle ID)
/// and cached; reloading only calls `setShortcut`, so `onKeyDown` handlers are never registered
/// twice for the same key (which would otherwise double-fire an action). A bundle ID removed from
/// the config gets its shortcut cleared so it stops responding.
@MainActor
final class HotkeyManager {
    private var paletteName: KeyboardShortcuts.Name?
    private var directHotkeyNames: [String: KeyboardShortcuts.Name] = [:] // bundle ID -> Name

    func register(config: Config, onTogglePalette: @escaping () -> Void) {
        registerPaletteHotkey(config.launcher.hotkey, action: onTogglePalette)
        registerDirectHotkeys(config.hotkeys)
    }

    func unregisterAll() {
        if let paletteName {
            KeyboardShortcuts.setShortcut(nil, for: paletteName)
        }
        for name in directHotkeyNames.values {
            KeyboardShortcuts.setShortcut(nil, for: name)
        }
    }

    private func registerPaletteHotkey(_ spec: String, action: @escaping () -> Void) {
        guard let shortcut = HotkeySpec.parse(spec) else {
            logInvalid(spec: spec, context: "launcher.hotkey")
            return
        }

        let name: KeyboardShortcuts.Name
        if let existing = paletteName {
            name = existing
        } else {
            name = KeyboardShortcuts.Name("rayvy.palette")
            paletteName = name
            KeyboardShortcuts.onKeyDown(for: name, action: action)
        }
        KeyboardShortcuts.setShortcut(shortcut, for: name)
    }

    private func registerDirectHotkeys(_ entries: [HotkeyEntry]) {
        var configuredBundleIDs = Set<String>()

        for entry in entries {
            configuredBundleIDs.insert(entry.bundleID)

            guard let shortcut = HotkeySpec.parse(entry.key) else {
                logInvalid(spec: entry.key, context: entry.bundleID)
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
                    AppLauncher.launch(bundleID: bundleID)
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
