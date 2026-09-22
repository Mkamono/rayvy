import AppKit
import SwiftUI

/// A borderless `NSPanel` normally can't become the key window (Apple's default is `false` unless
/// the panel is titled), which would leave the search field unable to receive keyboard focus.
private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// Owns the borderless floating panel that hosts the Command Palette, and the show/hide
/// choreography: activate Rayvy + focus the search field on show, restore the previously
/// frontmost app on hide (Spotlight-style).
@MainActor
final class PaletteWindowController {
    private let panel: NSPanel
    private let viewModel: PaletteViewModel
    private var previouslyActiveApp: NSRunningApplication?
    private var keyEventMonitor: Any?

    var isVisible: Bool { panel.isVisible }

    init(appIndex: AppIndex, clipboardHistory: ClipboardHistory, onQuitRayvy: @escaping () -> Void) {
        let viewModel = PaletteViewModel(
            appIndex: appIndex,
            clipboardHistory: clipboardHistory,
            onQuitRayvy: onQuitRayvy
        )
        self.viewModel = viewModel

        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 80),
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

        viewModel.onActivate = { [weak self] in
            self?.hide()
        }
    }

    func toggle() {
        if panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        previouslyActiveApp = NSWorkspace.shared.frontmostApplication
        viewModel.reset()

        if let screenFrame = NSScreen.main?.visibleFrame {
            let size = panel.frame.size
            let origin = NSPoint(
                x: screenFrame.midX - size.width / 2,
                y: screenFrame.midY - size.height / 2 + screenFrame.height * 0.15
            )
            panel.setFrameOrigin(origin)
        }

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        installKeyEventMonitor()
    }

    func hide() {
        removeKeyEventMonitor()
        panel.orderOut(nil)
        previouslyActiveApp?.activate()
        previouslyActiveApp = nil
    }

    private func installKeyEventMonitor() {
        removeKeyEventMonitor()
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            switch event.keyCode {
            case 53: // Escape
                self.hide()
                return nil
            case 125: // Down arrow
                self.viewModel.moveSelection(by: 1)
                return nil
            case 126: // Up arrow
                self.viewModel.moveSelection(by: -1)
                return nil
            case 36: // Return
                self.viewModel.activateSelected()
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
