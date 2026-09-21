import AppKit
import Foundation

enum PaletteSection: String, CaseIterable {
    case applications = "Applications"
    case commands = "Commands"
    case clipboard = "Clipboard History"
}

struct PaletteItem: Identifiable {
    let id: String
    let section: PaletteSection
    let title: String
    let subtitle: String?
    let icon: NSImage?
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
