import AppKit
import Foundation

enum SystemActions {
    static func sleep() {
        runSystemEvents(command: "sleep")
    }

    static func restart() {
        runSystemEvents(command: "restart")
    }

    static func shutdown() {
        runSystemEvents(command: "shut down")
    }

    /// Running, regular (non-background-agent) applications, excluding Rayvy itself.
    static func runningApplications() -> [NSRunningApplication] {
        let ownBundleID = Bundle.main.bundleIdentifier
        return NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .filter { $0.bundleIdentifier != ownBundleID }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }

    static func quit(_ app: NSRunningApplication) {
        if !app.terminate() {
            _ = app.forceTerminate()
        }
    }

    static func quitAll() {
        for app in runningApplications() {
            quit(app)
        }
    }

    private static func runSystemEvents(command: String) {
        let source = "tell application \"System Events\" to \(command)"
        guard let script = NSAppleScript(source: source) else { return }
        var errorInfo: NSDictionary?
        script.executeAndReturnError(&errorInfo)
        if let errorInfo {
            FileHandle.standardError.write(Data("[Rayvy] system: \(command) failed: \(errorInfo)\n".utf8))
        }
    }
}
