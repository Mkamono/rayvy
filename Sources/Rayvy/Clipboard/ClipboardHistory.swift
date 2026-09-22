import AppKit
import Foundation

/// Holds clipboard history in memory and persists it as JSON. Deduplicates by text (moving the
/// existing entry to the front instead of adding a second copy) and trims to `maxItems`.
final class ClipboardHistory {
    private(set) var items: [ClipboardItem] = []
    var maxItems: Int
    private let storageURL: URL

    static var defaultStorageURL: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Rayvy", isDirectory: true)
            .appendingPathComponent("clipboard.json", isDirectory: false)
    }

    init(maxItems: Int = 100, storageURL: URL = ClipboardHistory.defaultStorageURL) {
        self.maxItems = maxItems
        self.storageURL = storageURL
        self.items = Self.load(from: storageURL)
        trim()
    }

    func add(text: String) {
        guard !text.isEmpty else { return }
        items.removeAll { $0.text == text }
        items.insert(ClipboardItem(text: text), at: 0)
        trim()
        save()
    }

    func search(_ query: String) -> [ClipboardItem] {
        guard !query.isEmpty else { return items }
        return items.filter { $0.text.range(of: query, options: .caseInsensitive) != nil }
    }

    func recopy(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.text, forType: .string)
    }

    func remove(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
        save()
    }

    private func trim() {
        if items.count > maxItems {
            items.removeLast(items.count - maxItems)
        }
    }

    private func save() {
        do {
            let directory = storageURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(items)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            FileHandle.standardError.write(Data("[Rayvy] clipboard: failed to save history: \(error)\n".utf8))
        }
    }

    private static func load(from storageURL: URL) -> [ClipboardItem] {
        guard let data = try? Data(contentsOf: storageURL) else { return [] }
        return (try? JSONDecoder().decode([ClipboardItem].self, from: data)) ?? []
    }
}
