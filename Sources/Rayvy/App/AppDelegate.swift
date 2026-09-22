import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var config: Config = .default
    private let appIndex = AppIndex()
    private lazy var clipboardHistory = ClipboardHistory(maxItems: config.clipboard.maxItems)
    private lazy var clipboardMonitor = ClipboardMonitor(
        history: clipboardHistory,
        isEnabled: config.clipboard.enabled,
        excludedBundleIDs: config.clipboard.excludedBundleIDs
    )
    private let hotkeyManager = HotkeyManager()
    private var configWatcher: ConfigWatcher?
    private lazy var paletteWindowController = PaletteWindowController(
        appIndex: appIndex,
        clipboardHistory: clipboardHistory,
        onQuitRayvy: { NSApp.terminate(nil) }
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        config = ConfigLoader.loadOrCreateDefault()

        // Force lazy properties (which capture `config`) to initialize with the loaded config
        // before anything else touches them.
        _ = clipboardHistory
        _ = clipboardMonitor
        _ = paletteWindowController

        paletteWindowController.updateConfig(config)
        clipboardMonitor.start()
        hotkeyManager.register(
            config: config,
            onTogglePalette: { [weak self] in self?.paletteWindowController.toggle() },
            onToggleClipboardHistory: { [weak self] in self?.paletteWindowController.toggleClipboardHistory() }
        )

        let watcher = ConfigWatcher { [weak self] newConfig in
            self?.applyConfig(newConfig)
        }
        watcher.start()
        configWatcher = watcher
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardMonitor.stop()
        hotkeyManager.unregisterAll()
        configWatcher?.stop()
    }

    private func applyConfig(_ newConfig: Config) {
        config = newConfig

        clipboardHistory.maxItems = newConfig.clipboard.maxItems
        clipboardMonitor.isEnabled = newConfig.clipboard.enabled
        clipboardMonitor.excludedBundleIDs = Set(newConfig.clipboard.excludedBundleIDs)

        appIndex.refresh()
        paletteWindowController.updateConfig(newConfig)

        hotkeyManager.register(
            config: newConfig,
            onTogglePalette: { [weak self] in self?.paletteWindowController.toggle() },
            onToggleClipboardHistory: { [weak self] in self?.paletteWindowController.toggleClipboardHistory() }
        )
    }
}
