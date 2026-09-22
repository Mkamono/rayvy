import AppKit
import Foundation

enum AppLauncher {
    static func launch(_ app: InstalledApp) {
        launch(at: app.url)
    }

    static func launch(bundleID: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            FileHandle.standardError.write(Data("[Rayvy] hotkeys: no application found for bundle id \(bundleID)\n".utf8))
            return
        }
        launch(at: url)
    }

    /// Direct Hotkey behavior: if the app isn't running, launch it. If it's running but not
    /// frontmost, bring it to the front. If it's already frontmost, hide it (⌘H-equivalent) so a
    /// second press of the same hotkey acts as a toggle.
    static func toggle(bundleID: String) {
        guard let running = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleID }) else {
            launch(bundleID: bundleID)
            return
        }
        if running.isActive {
            running.hide()
        } else {
            running.activate()
        }
    }

    private static func launch(at url: URL) {
        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
            if let error {
                FileHandle.standardError.write(Data("[Rayvy] failed to launch \(url.path): \(error)\n".utf8))
            }
        }
    }
}
