import ApplicationServices
import Foundation

/// Synthesizes a ⌘V keystroke into whatever app is frontmost, used so selecting a Clipboard
/// History item pastes it immediately instead of just leaving it on the pasteboard for the user to
/// paste themselves.
enum PasteSimulator {
    private static let vKeyCode: CGKeyCode = 9 // ANSI "v"

    /// Set once `ensureAccessibilityTrust()` has shown the OS permission prompt, so a paste
    /// attempted again later in the same run (still untrusted) doesn't keep popping it back up —
    /// `PermissionAlert`'s palette item is the reminder from then on.
    private static var hasPromptedForAccessibility = false

    /// Whether Rayvy currently has Accessibility permission, which posting synthetic keyboard
    /// events into another app requires. `PermissionAlert` surfaces a palette item to grant it
    /// when this is false.
    static var isAccessibilityTrusted: Bool { AXIsProcessTrusted() }

    /// If Accessibility permission hasn't been granted, this triggers the OS's own permission
    /// dialog the first time (mirroring how `SystemActions`' AppleScript calls trigger their own
    /// Automation prompt automatically on first use) and otherwise does nothing — the item is
    /// still on the pasteboard, so a manual ⌘V still works.
    static func pasteIntoFrontmostApp() {
        guard ensureAccessibilityTrust() else { return }

        // The palette's hide (which restores focus to the app the paste should land in) is still
        // settling when the caller's action runs, so give it a moment before posting the keys.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            guard let source = CGEventSource(stateID: .hidSystemState) else { return }

            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true)
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
            keyDown?.flags = .maskCommand
            keyUp?.flags = .maskCommand

            keyDown?.post(tap: .cghidEventTap)
            keyUp?.post(tap: .cghidEventTap)
        }
    }

    private static func ensureAccessibilityTrust() -> Bool {
        if isAccessibilityTrusted { return true }
        guard !hasPromptedForAccessibility else { return false }

        hasPromptedForAccessibility = true
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
