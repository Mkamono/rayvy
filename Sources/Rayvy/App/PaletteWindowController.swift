import AppKit
import Combine
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
    private static let panelWidth: CGFloat = 640
    private static let textFieldAreaHeight: CGFloat = 56
    private static let sectionHeaderHeight: CGFloat = 26
    private static let rowHeight: CGFloat = 32
    private static let dividerAndBottomPadding: CGFloat = 9
    private static let maxListHeight: CGFloat = 400

    private let panel: NSPanel
    private let viewModel: PaletteViewModel
    private var previouslyActiveApp: NSRunningApplication?
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
            contentRect: NSRect(x: 0, y: 0, width: Self.panelWidth, height: Self.textFieldAreaHeight),
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

        viewModel.$sections
            .sink { [weak self] sections in
                self?.resize(for: sections)
            }
            .store(in: &cancellables)
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

        if let screenFrame = NSScreen.main?.visibleFrame {
            anchorX = screenFrame.midX - Self.panelWidth / 2
            anchorTopY = screenFrame.midY + screenFrame.height * 0.15 + Self.textFieldAreaHeight / 2
        }

        // Triggers `viewModel.$sections`, which resizes the panel to fit before it's shown.
        viewModel.reset()

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

    private func resize(for sections: [(PaletteSection, [PaletteItem])]) {
        guard let anchorX, let anchorTopY else { return }

        let rawListHeight = sections.reduce(CGFloat(0)) { partial, section in
            partial + Self.sectionHeaderHeight + CGFloat(section.1.count) * Self.rowHeight
        }
        let listHeight = sections.isEmpty ? 0 : min(Self.maxListHeight, rawListHeight)
        let extra: CGFloat = sections.isEmpty ? 0 : Self.dividerAndBottomPadding
        let totalHeight = Self.textFieldAreaHeight + listHeight + extra

        let newFrame = NSRect(
            x: anchorX,
            y: anchorTopY - totalHeight,
            width: Self.panelWidth,
            height: totalHeight
        )
        panel.setFrame(newFrame, display: panel.isVisible)
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
