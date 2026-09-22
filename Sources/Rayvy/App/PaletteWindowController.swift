import AppKit
import Combine
import SwiftUI

/// A borderless `NSPanel` normally can't become the key window (Apple's default is `false` unless
/// the panel is titled), which would leave the search field unable to receive keyboard focus.
private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// Owns the borderless floating panel that hosts the Command Palette, and the show/hide
/// choreography: activate Rayvy + focus the search field and switch to Roman input on show,
/// restore the previously frontmost app and input source on hide (Spotlight-style).
@MainActor
final class PaletteWindowController {
    private static let panelWidth: CGFloat = 640

    private let panel: NSPanel
    private let viewModel: PaletteViewModel
    private var previouslyActiveApp: NSRunningApplication?
    private var previousInputSourceID: String?
    private var keyEventMonitor: Any?
    private var cancellables = Set<AnyCancellable>()

    // The panel's on-screen position is fixed once per `show()` and only its height changes as
    // results come and go, so it grows/shrinks downward from a stable top edge instead of
    // re-centering (which would make the search field jump around while typing).
    private var anchorX: CGFloat?
    private var anchorTopY: CGFloat?

    var isVisible: Bool { panel.isVisible }

    init(appIndex: AppIndex, clipboardHistory: ClipboardHistory, onQuitRayvy: @escaping () -> Void) {
        let viewModel = PaletteViewModel(
            appIndex: appIndex,
            clipboardHistory: clipboardHistory,
            onQuitRayvy: onQuitRayvy
        )
        self.viewModel = viewModel

        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: Self.panelWidth, height: PaletteViewModel.textFieldAreaHeight),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: PaletteView(viewModel: viewModel))
        self.panel = panel

        viewModel.onActivate = { [weak self] dismissesToPreviousApp in
            self?.hide(restorePreviousApp: dismissesToPreviousApp)
        }

        viewModel.$contentHeight
            .sink { [weak self] height in
                self?.resize(to: height)
            }
            .store(in: &cancellables)
    }

    /// Forwards `Config.hotkeys` to the view model so "Assign Hotkey…" can show the current
    /// binding. Called on initial load and every hot-reload — see `AppDelegate`.
    func updateConfig(_ config: Config) {
        viewModel.updateDirectHotkeys(config.hotkeys)
    }

    func toggle() {
        if panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    /// Toggles the palette scoped straight to Clipboard History (the Clipboard History hotkey).
    func toggleClipboardHistory() {
        if panel.isVisible {
            hide()
        } else {
            showClipboardHistory()
        }
    }

    func show() {
        present(scopedToClipboard: false)
    }

    func showClipboardHistory() {
        present(scopedToClipboard: true)
    }

    private func present(scopedToClipboard: Bool) {
        previouslyActiveApp = NSWorkspace.shared.frontmostApplication
        previousInputSourceID = InputSourceSwitcher.switchToAlphabetInput()

        if let screenFrame = NSScreen.main?.visibleFrame {
            anchorX = screenFrame.midX - Self.panelWidth / 2
            anchorTopY = screenFrame.midY + screenFrame.height * 0.15 + PaletteViewModel.textFieldAreaHeight / 2
        }

        // Triggers `viewModel.$contentHeight`, which resizes the panel to fit before it's shown.
        viewModel.reset(scopedToClipboard: scopedToClipboard)

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        installKeyEventMonitor()
    }

    /// `restorePreviousApp: false` skips reactivating the app that was frontmost before the
    /// palette opened — for an action that handed focus to a specific other app or system pane
    /// (see `PaletteItem.dismissesToPreviousApp`), so that app keeps the foreground instead of
    /// losing a race against this (effectively synchronous) reactivation.
    func hide(restorePreviousApp: Bool = true) {
        removeKeyEventMonitor()
        panel.orderOut(nil)
        if restorePreviousApp {
            previouslyActiveApp?.activate()
        }
        previouslyActiveApp = nil
        InputSourceSwitcher.restore(to: previousInputSourceID)
        previousInputSourceID = nil
    }

    private func resize(to height: CGFloat) {
        guard let anchorX, let anchorTopY else { return }

        let newFrame = NSRect(
            x: anchorX,
            y: anchorTopY - height,
            width: Self.panelWidth,
            height: height
        )
        panel.setFrame(newFrame, display: panel.isVisible)
    }

    private func installKeyEventMonitor() {
        removeKeyEventMonitor()
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }

            if self.viewModel.hotkeyCapture != nil {
                if event.keyCode == 53 { // Escape
                    self.viewModel.cancelHotkeyCapture()
                } else {
                    self.viewModel.handleHotkeyCapture(event: event)
                }
                return nil
            }

            if event.keyCode == 40, event.modifierFlags.contains(.command) { // ⌘K
                self.viewModel.toggleActionMenu()
                return nil
            }

            switch event.keyCode {
            case 53: // Escape
                if self.viewModel.isActionMenuOpen {
                    self.viewModel.closeActionMenu()
                } else {
                    self.hide()
                }
                return nil
            case 125: // Down arrow
                if self.viewModel.isActionMenuOpen {
                    self.viewModel.moveActionSelection(by: 1)
                } else {
                    self.viewModel.moveSelection(by: 1)
                }
                return nil
            case 126: // Up arrow
                if self.viewModel.isActionMenuOpen {
                    self.viewModel.moveActionSelection(by: -1)
                } else {
                    self.viewModel.moveSelection(by: -1)
                }
                return nil
            case 36: // Return
                if self.viewModel.isActionMenuOpen {
                    self.viewModel.activateActionMenuSelection()
                } else {
                    self.viewModel.activateSelected()
                }
                return nil
            default:
                return event
            }
        }
    }

    private func removeKeyEventMonitor() {
        if let keyEventMonitor {
            NSEvent.removeMonitor(keyEventMonitor)
        }
        keyEventMonitor = nil
    }
}
