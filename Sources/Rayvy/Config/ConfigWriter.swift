import Foundation
import TOMLKit

/// Writes a single Direct Hotkey assignment back to `config.toml`, for the "Assign Hotkey…"
/// palette action — the one exception to the config file otherwise being edited only by hand
/// (see CLAUDE.md's "Config as source of truth"). Parses the file with TOMLKit's mutable
/// `TOMLTable` rather than round-tripping through `Config`/`Encodable`, so untouched keys, tables,
/// and formatting are preserved.
enum ConfigWriter {
    enum WriteError: Error {
        case parseFailed
        case writeFailed
    }

    /// Adds or updates the `[[hotkeys]]` entry for `bundleID` to `key`. Reads and writes
    /// `fileURL` (defaults to the real config file; overridable for tests).
    static func setDirectHotkey(key: String, bundleID: String, fileURL: URL = ConfigLoader.configFileURL) throws {
        let contents = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ConfigDefaults.template

        let table: TOMLTable
        do {
            table = try TOMLTable(string: contents)
        } catch {
            throw WriteError.parseFailed
        }

        // Assigning `table["hotkeys"] = TOMLArray()` inserts a *copy* into the table's tree, so a
        // locally-held reference to that array would go stale before `.append` below ever runs.
        // Insert the empty array first, then re-fetch the live one from the table.
        if table["hotkeys"]?.array == nil {
            table["hotkeys"] = TOMLArray()
        }
        guard let hotkeysArray = table["hotkeys"]?.array else { throw WriteError.parseFailed }

        if let existingEntry = hotkeysArray.first(where: { $0.table?["bundle_id"]?.string == bundleID })?.table {
            existingEntry["key"] = key
        } else {
            let newEntry = TOMLTable()
            newEntry["key"] = key
            newEntry["bundle_id"] = bundleID
            hotkeysArray.append(newEntry)
        }

        do {
            try table.convert().write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            throw WriteError.writeFailed
        }
    }
}
