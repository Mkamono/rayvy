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

    private static func launch(at url: URL) {
        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
            if let error {
                FileHandle.standardError.write(Data("[Rayvy] failed to launch \(url.path): \(error)\n".utf8))
            }
        }
    }
}
