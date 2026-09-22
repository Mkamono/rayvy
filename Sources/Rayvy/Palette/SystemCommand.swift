import AppKit
import Foundation

enum SystemCommand {
    /// Builds the "Commands" section: system power actions, running-app management, and quitting
    /// Rayvy itself. Recomputed each time the palette opens so the running-app list is current.
    static func makeItems(onQuitRayvy: @escaping () -> Void) -> [PaletteItem] {
        var items: [PaletteItem] = [
            PaletteItem(
                id: "system.sleep",
                section: .commands,
                title: "Sleep",
                subtitle: nil,
                icon: NSImage(systemSymbolName: "moon.fill", accessibilityDescription: nil),
                action: SystemActions.sleep
            ),
            PaletteItem(
                id: "system.restart",
                section: .commands,
                title: "Restart",
                subtitle: nil,
                icon: NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: nil),
                action: SystemActions.restart
            ),
            PaletteItem(
                id: "system.shutdown",
                section: .commands,
                title: "Shut Down",
                subtitle: nil,
                icon: NSImage(systemSymbolName: "power", accessibilityDescription: nil),
                action: SystemActions.shutdown
            ),
            PaletteItem(
                id: "system.quitAll",
                section: .commands,
                title: "Quit All Applications",
                subtitle: nil,
                icon: NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: nil),
                action: SystemActions.quitAll
            ),
            PaletteItem(
                id: "system.openSettings",
                section: .commands,
                title: "Open Rayvy Settings",
                subtitle: ConfigLoader.configFileURL.path,
                icon: NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil),
                action: { NSWorkspace.shared.open(ConfigLoader.configFileURL) }
            ),
            PaletteItem(
                id: "system.openDocs",
                section: .commands,
                title: "Rayvy Docs",
                subtitle: "Opens the README on GitHub in your default browser",
                icon: NSImage(systemSymbolName: "book", accessibilityDescription: nil),
                action: {
                    guard let url = URL(string: "https://github.com/Mkamono/rayvy#readme") else { return }
                    NSWorkspace.shared.open(url)
                }
            ),
            PaletteItem(
                id: "system.quitRayvy",
                section: .commands,
                title: "Quit Rayvy",
                subtitle: nil,
                icon: NSImage(systemSymbolName: "xmark.circle", accessibilityDescription: nil),
                action: onQuitRayvy
            )
        ]

        for app in SystemActions.runningApplications() {
            items.append(
                PaletteItem(
                    id: "system.quit.\(app.bundleIdentifier ?? app.processIdentifier.description)",
                    section: .commands,
                    title: "Quit \(app.localizedName ?? "Unknown")",
                    subtitle: nil,
                    icon: app.icon,
                    action: { SystemActions.quit(app) }
                )
            )
        }

        return items
    }
}
