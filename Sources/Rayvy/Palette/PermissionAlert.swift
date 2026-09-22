import AppKit
import Foundation

/// Palette items surfaced when Rayvy is missing a permission one of its features depends on.
/// Currently just Accessibility, which `PasteSimulator` needs to paste Clipboard History
/// selections. Recomputed each time the palette opens (permission can be granted/revoked in
/// System Settings at any time outside Rayvy) and, unlike other sections, never filtered out by
/// the search query — the point is to stay visible at the top until the user deals with it.
enum PermissionAlert {
    static func makeItems() -> [PaletteItem] {
        guard !PasteSimulator.isAccessibilityTrusted else { return [] }

        return [
            PaletteItem(
                id: "alert.accessibility",
                section: .alerts,
                title: "Grant Accessibility Permission",
                subtitle: "Required to paste Clipboard History selections \u{2014} opens System Settings",
                icon: NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: nil),
                dismissesToPreviousApp: false,
                action: {
                    guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
                    NSWorkspace.shared.open(url)
                }
            )
        ]
    }
}
