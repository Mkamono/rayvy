import AppKit
import KeyboardShortcuts

/// Converts between config strings like `"option+space"` and `KeyboardShortcuts.Shortcut`.
enum HotkeySpec {
    private static let modifiersByToken: [String: NSEvent.ModifierFlags] = [
        "cmd": .command,
        "command": .command,
        "option": .option,
        "alt": .option,
        "shift": .shift,
        "control": .control,
        "ctrl": .control
    ]

    // Single source of truth for both parsing and describing keys. An `Array`, not a `Dictionary`
    // literal, because several tokens intentionally alias the same Key (e.g. "up"/"uparrow"), and
    // the canonical token used by `describe(_:)` must be deterministic (the first one listed here)
    // rather than depending on Swift's per-process `Dictionary` iteration order.
    private static let keyAliases: [(token: String, key: KeyboardShortcuts.Key)] = [
        ("a", .a), ("b", .b), ("c", .c), ("d", .d), ("e", .e), ("f", .f), ("g", .g), ("h", .h),
        ("i", .i), ("j", .j), ("k", .k), ("l", .l), ("m", .m), ("n", .n), ("o", .o), ("p", .p),
        ("q", .q), ("r", .r), ("s", .s), ("t", .t), ("u", .u), ("v", .v), ("w", .w), ("x", .x),
        ("y", .y), ("z", .z),
        ("0", .zero), ("1", .one), ("2", .two), ("3", .three), ("4", .four),
        ("5", .five), ("6", .six), ("7", .seven), ("8", .eight), ("9", .nine),
        ("space", .space),
        ("return", .return), ("enter", .return),
        ("tab", .tab),
        ("escape", .escape), ("esc", .escape),
        ("delete", .delete), ("backspace", .delete),
        ("up", .upArrow), ("uparrow", .upArrow),
        ("down", .downArrow), ("downarrow", .downArrow),
        ("left", .leftArrow), ("leftarrow", .leftArrow),
        ("right", .rightArrow), ("rightarrow", .rightArrow)
    ]

    // Tokens are unique, so this is safe with `uniqueKeysWithValues`.
    private static let keysByToken: [String: KeyboardShortcuts.Key] =
        Dictionary(uniqueKeysWithValues: keyAliases.map { ($0.token, $0.key) })

    // Keys are not unique (aliases), so this keeps the first token listed above for each Key.
    private static let tokensByKey: [KeyboardShortcuts.Key: String] =
        keyAliases.reduce(into: [:]) { result, alias in
            if result[alias.key] == nil {
                result[alias.key] = alias.token
            }
        }

    private static let tokensByModifier: [(NSEvent.ModifierFlags, String)] = [
        (.command, "cmd"),
        (.option, "option"),
        (.shift, "shift"),
        (.control, "control")
    ]

    /// Parses a string like `"option+space"` into a `Shortcut`. Returns `nil` if the string is
    /// malformed or references an unsupported key.
    static func parse(_ spec: String) -> KeyboardShortcuts.Shortcut? {
        let tokens = spec
            .lowercased()
            .split(separator: "+")
            .map { $0.trimmingCharacters(in: .whitespaces) }

        guard let keyToken = tokens.last, let key = keysByToken[keyToken] else { return nil }

        var modifiers: NSEvent.ModifierFlags = []
        for token in tokens.dropLast() {
            guard let modifier = modifiersByToken[token] else { return nil }
            modifiers.insert(modifier)
        }

        return KeyboardShortcuts.Shortcut(key, modifiers: modifiers)
    }

    /// Renders a `Shortcut` back into config-string form, e.g. `"option+space"`. Used for
    /// diagnostics and tests; not required at runtime.
    static func describe(_ shortcut: KeyboardShortcuts.Shortcut) -> String? {
        guard let key = shortcut.key, let keyToken = tokensByKey[key] else { return nil }

        let modifierTokens = tokensByModifier
            .filter { shortcut.modifiers.contains($0.0) }
            .map(\.1)

        return (modifierTokens + [keyToken]).joined(separator: "+")
    }
}
