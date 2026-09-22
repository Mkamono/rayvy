import AppKit
import Foundation

enum PaletteSection: String, CaseIterable {
    case alerts = "Alerts"
    case applications = "Applications"
    case commands = "Commands"
    case clipboard = "Clipboard History"
}

/// A secondary action reachable via ⌘K on a selected item (Raycast-style), for things that don't
/// belong on the primary Enter action. The one action that writes back to `config.toml` is
/// Applications' "Assign Hotkey…" — see CLAUDE.md's "Config as source of truth" before adding
/// another one.
struct PaletteAction: Identifiable {
    let id: String
    let title: String
    /// Whether hiding the palette after this action should reactivate whatever app was frontmost
    /// before the palette opened (the default, Spotlight-style behavior). Set `false` for an
    /// action that hands focus to a specific other app or system pane (e.g. "Reveal in Finder") —
    /// `previouslyActiveApp.activate()` is effectively synchronous, so it otherwise wins the race
    /// against that app's own (often async, e.g. an Apple Event to an already-running process)
    /// activation and steals focus right back.
    var dismissesToPreviousApp: Bool = true
    let perform: () -> Void
}

struct PaletteItem: Identifiable {
    let id: String
    let section: PaletteSection
    let title: String
    let subtitle: String?
    let icon: NSImage?
    var actions: [PaletteAction] = []
    /// See `PaletteAction.dismissesToPreviousApp` — same rationale, for the primary Enter action.
    var dismissesToPreviousApp: Bool = true
    let action: () -> Void
}

enum PaletteSearch {
    /// Plain, case-insensitive substring match against title (and subtitle as a fallback).
    /// Intentionally not a fuzzy matcher — see SPEC's "単純な文字列一致".
    static func matches(_ item: PaletteItem, query: String) -> Bool {
        guard !query.isEmpty else { return true }
        if item.title.range(of: query, options: .caseInsensitive) != nil {
            return true
        }
        if let subtitle = item.subtitle, subtitle.range(of: query, options: .caseInsensitive) != nil {
            return true
        }
        return false
    }

    static func filter(_ items: [PaletteItem], query: String) -> [PaletteItem] {
        items.filter { matches($0, query: query) }
    }
}
