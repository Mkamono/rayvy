import Carbon
import Foundation

/// Switches the system text input source to a standard Roman/alphabet keyboard layout (e.g. ABC)
/// while the palette is open, and restores whatever was active before. This exists because typing
/// a search query while an IME like Kotoeri or Google Japanese Input is active tends to fight with
/// `PaletteSearch`'s plain substring matching (composed/uncommitted text, unexpected candidate
/// windows), so the palette forces Roman input for the duration it's visible.
enum InputSourceSwitcher {
    /// Switches to a Roman keyboard layout, returning the previous input source's ID so it can be
    /// passed to `restore(to:)` later. Returns `nil` if there's nothing to restore (lookup failed,
    /// or the current source is already a Roman layout).
    @discardableResult
    static func switchToAlphabetInput() -> String? {
        guard let current = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let currentID = inputSourceID(current) else {
            return nil
        }
        guard let alphabetSource = findAlphabetInputSource(), let alphabetID = inputSourceID(alphabetSource) else {
            return nil
        }
        if currentID == alphabetID {
            return nil
        }

        TISSelectInputSource(alphabetSource)
        return currentID
    }

    static func restore(to sourceID: String?) {
        guard let sourceID, let source = findInputSource(id: sourceID) else { return }
        TISSelectInputSource(source)
    }

    /// Prefers the plain "ABC" layout if it's enabled; otherwise falls back to the first enabled,
    /// selectable keyboard layout (as opposed to an input method / IME), which is always some
    /// Roman layout (US, ABC, British, etc).
    private static func findAlphabetInputSource() -> TISInputSource? {
        if let abc = findInputSource(id: "com.apple.keylayout.ABC") {
            return abc
        }
        return enabledInputSources().first { source in
            isSelectCapable(source) && inputSourceType(source) == (kTISTypeKeyboardLayout as String)
        }
    }

    private static func findInputSource(id: String) -> TISInputSource? {
        enabledInputSources().first { inputSourceID($0) == id }
    }

    private static func enabledInputSources() -> [TISInputSource] {
        (TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource]) ?? []
    }

    private static func inputSourceID(_ source: TISInputSource) -> String? {
        stringProperty(source, kTISPropertyInputSourceID)
    }

    private static func inputSourceType(_ source: TISInputSource) -> String? {
        stringProperty(source, kTISPropertyInputSourceType)
    }

    private static func isSelectCapable(_ source: TISInputSource) -> Bool {
        guard let ptr = TISGetInputSourceProperty(source, kTISPropertyInputSourceIsSelectCapable) else {
            return false
        }
        return CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(ptr).takeUnretainedValue())
    }

    private static func stringProperty(_ source: TISInputSource, _ key: CFString) -> String? {
        guard let ptr = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
    }
}
