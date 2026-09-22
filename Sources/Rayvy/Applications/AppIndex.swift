import AppKit
import Foundation

struct InstalledApp: Identifiable, Equatable {
    let id: String // bundle identifier
    let name: String
    let url: URL

    static func == (lhs: InstalledApp, rhs: InstalledApp) -> Bool {
        lhs.id == rhs.id
    }

    var icon: NSImage {
        NSWorkspace.shared.icon(forFile: url.path)
    }
}

/// Enumerates installed applications by scanning the standard application directories.
/// Results are cached in memory; call `refresh()` to rebuild (e.g. on config reload).
final class AppIndex {
    private static let searchDirectories: [URL] = [
        URL(fileURLWithPath: "/Applications"),
        URL(fileURLWithPath: "/System/Applications"),
        URL(fileURLWithPath: "/System/Applications/Utilities"),
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
    ]

    private(set) var apps: [InstalledApp] = []

    init() {
        refresh()
    }

    func refresh() {
        var seen = Set<String>()
        var results: [InstalledApp] = []

        for directory in Self.searchDirectories {
            // The URL-based `contentsOfDirectory(at:includingPropertiesForKeys:options:)` silently
            // omits `/Applications/Safari.app` (a symlink into a cryptex-mounted system volume) on
            // recent macOS, even though it's a perfectly normal entry to `ls` or the path-string
            // API below. Enumerate by name instead and build URLs ourselves.
            guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else { continue }

            for name in names where name.hasSuffix(".app") {
                let entryURL = directory.appendingPathComponent(name)
                guard let app = Self.makeInstalledApp(at: entryURL) else { continue }
                guard seen.insert(app.id).inserted else { continue }
                results.append(app)
            }
        }

        results.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        apps = results
    }

    private static func makeInstalledApp(at url: URL) -> InstalledApp? {
        guard let bundle = Bundle(url: url), let bundleID = bundle.bundleIdentifier else { return nil }
        let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent
        return InstalledApp(id: bundleID, name: name, url: url)
    }
}
