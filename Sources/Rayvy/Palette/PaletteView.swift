import AppKit
import KeyboardShortcuts
import SwiftUI

@MainActor
final class PaletteViewModel: ObservableObject {
    // Single source of truth for panel layout, shared with PaletteWindowController via
    // `contentHeight` so the window always exactly fits what's currently on screen (the results
    // list, the ⌘K action menu, or the hotkey capture screen when one is open).
    static let rowHeight: CGFloat = 32
    static let sectionHeaderHeight: CGFloat = 26
    static let textFieldAreaHeight: CGFloat = 56
    static let dividerAndBottomPadding: CGFloat = 9
    static let maxListHeight: CGFloat = 400
    static let hotkeyCaptureLineCount = 3

    /// State for the "Assign Hotkey…" screen (opened from an app's ⌘K action menu). Holds the
    /// bundle ID being assigned, its current key spec (if any) for display, and a transient
    /// validation error shown after an unusable key press.
    struct HotkeyCaptureState {
        let bundleID: String
        let appName: String
        var currentKey: String?
        var errorMessage: String?
    }

    @Published var query: String = ""
    @Published private(set) var sections: [(PaletteSection, [PaletteItem])] = []
    @Published var selectedID: String?
    /// Bumped on every `reset()` so the view can re-focus the search field each time the palette
    /// is shown. Needed because the hosting view (and its SwiftUI hierarchy) is created once and
    /// reused across show/hide cycles, so `.onAppear` only fires the first time.
    @Published private(set) var focusToken = UUID()
    /// Non-nil when the palette was opened scoped to a single section (currently: the Clipboard
    /// History hotkey), which limits `recomputeItems()` to that section only.
    @Published private(set) var scopedSection: PaletteSection?
    @Published private(set) var isActionMenuOpen = false
    @Published private(set) var actionMenuSelectedIndex = 0
    @Published private(set) var hotkeyCapture: HotkeyCaptureState?
    @Published private(set) var contentHeight: CGFloat = PaletteViewModel.textFieldAreaHeight

    private let appIndex: AppIndex
    private let clipboardHistory: ClipboardHistory
    private let onQuitRayvy: () -> Void
    /// bundle ID -> configured Direct Hotkey spec, kept in sync with `Config.hotkeys` by
    /// `PaletteWindowController.updateConfig(_:)` so "Assign Hotkey…" can show the current binding.
    private var directHotkeys: [String: String] = [:]
    /// Called after an action fires to dismiss the palette; passes whether the previously
    /// frontmost app should be reactivated (see `PaletteItem.dismissesToPreviousApp`).
    var onActivate: ((Bool) -> Void)?

    init(appIndex: AppIndex, clipboardHistory: ClipboardHistory, onQuitRayvy: @escaping () -> Void) {
        self.appIndex = appIndex
        self.clipboardHistory = clipboardHistory
        self.onQuitRayvy = onQuitRayvy
    }

    /// Call each time the palette becomes visible: resets the query and rebuilds all item lists
    /// (running apps and clipboard history change between openings). Pass `scopedToClipboard: true`
    /// for the Clipboard History hotkey, which opens straight into a clipboard-only view.
    func reset(scopedToClipboard: Bool = false) {
        query = ""
        focusToken = UUID()
        isActionMenuOpen = false
        hotkeyCapture = nil
        scopedSection = scopedToClipboard ? .clipboard : nil
        recomputeItems()
    }

    /// Keeps the "Assign Hotkey…" action's displayed current binding in sync with `Config`.
    /// Called by `PaletteWindowController.updateConfig(_:)` on load and every hot-reload.
    func updateDirectHotkeys(_ entries: [HotkeyEntry]) {
        directHotkeys = Dictionary(entries.map { ($0.bundleID, $0.key) }, uniquingKeysWith: { _, latest in latest })
    }

    func recomputeItems() {
        if scopedSection == .clipboard {
            recomputeClipboardOnlyItems()
            return
        }

        let runningBundleIDs = Set(SystemActions.runningApplications().compactMap(\.bundleIdentifier))

        let appItems = appIndex.apps.map { app -> PaletteItem in
            var actions: [PaletteAction] = []
            if runningBundleIDs.contains(app.id) {
                actions.append(PaletteAction(id: "quit", title: "Quit \(app.name)") {
                    guard let running = SystemActions.runningApplications().first(where: { $0.bundleIdentifier == app.id }) else { return }
                    SystemActions.quit(running)
                })
            }
            actions.append(PaletteAction(id: "reveal", title: "Reveal in Finder", dismissesToPreviousApp: false) {
                NSWorkspace.shared.activateFileViewerSelecting([app.url])
            })
            actions.append(PaletteAction(id: "copyBundleID", title: "Copy Bundle ID") {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(app.id, forType: .string)
            })
            let hotkeyActionTitle = directHotkeys[app.id].map { "Change Hotkey (\($0))\u{2026}" } ?? "Assign Hotkey\u{2026}"
            actions.append(PaletteAction(id: "assignHotkey", title: hotkeyActionTitle) { [weak self] in
                self?.beginHotkeyCapture(bundleID: app.id, appName: app.name)
            })

            return PaletteItem(
                id: "app.\(app.id)",
                section: .applications,
                title: app.name,
                subtitle: nil,
                icon: app.icon,
                actions: actions,
                action: { AppLauncher.launch(app) }
            )
        }

        let commandItems = SystemCommand.makeItems(onQuitRayvy: onQuitRayvy)
        let clipboardItems = makeClipboardItems()

        let filteredApps = PaletteSearch.filter(appItems, query: query)
        let filteredCommands = PaletteSearch.filter(commandItems, query: query)
        let filteredClipboard = PaletteSearch.filter(clipboardItems, query: query)

        let alertItems = PermissionAlert.makeItems()

        var newSections: [(PaletteSection, [PaletteItem])] = []
        if !alertItems.isEmpty { newSections.append((.alerts, alertItems)) }
        if !filteredApps.isEmpty { newSections.append((.applications, filteredApps)) }
        if !filteredCommands.isEmpty { newSections.append((.commands, filteredCommands)) }
        if !filteredClipboard.isEmpty { newSections.append((.clipboard, filteredClipboard)) }
        applySections(newSections)
    }

    /// Used when the palette was opened via the Clipboard History hotkey: skips indexing apps and
    /// commands entirely, since only the clipboard section can ever be shown.
    private func recomputeClipboardOnlyItems() {
        let filteredClipboard = PaletteSearch.filter(makeClipboardItems(), query: query)
        let alertItems = PermissionAlert.makeItems()

        var newSections: [(PaletteSection, [PaletteItem])] = []
        if !alertItems.isEmpty { newSections.append((.alerts, alertItems)) }
        if !filteredClipboard.isEmpty { newSections.append((.clipboard, filteredClipboard)) }
        applySections(newSections)
    }

    private func makeClipboardItems() -> [PaletteItem] {
        clipboardHistory.items.map { item -> PaletteItem in
            PaletteItem(
                id: "clipboard.\(item.id)",
                section: .clipboard,
                title: item.text,
                subtitle: nil,
                icon: NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: nil),
                actions: [
                    PaletteAction(id: "remove", title: "Remove from History") { [weak self] in
                        self?.clipboardHistory.remove(item)
                        self?.recomputeItems()
                    }
                ],
                action: { [weak self] in
                    self?.clipboardHistory.recopy(item)
                    PasteSimulator.pasteIntoFrontmostApp()
                }
            )
        }
    }

    private func applySections(_ newSections: [(PaletteSection, [PaletteItem])]) {
        sections = newSections

        let flatIDs = newSections.flatMap { $0.1.map(\.id) }
        if let selectedID, flatIDs.contains(selectedID) {
            // Keep current selection.
        } else {
            selectedID = flatIDs.first
            isActionMenuOpen = false
        }

        recomputeContentHeight()
    }

    private var flatItems: [PaletteItem] {
        sections.flatMap { $0.1 }
    }

    var selectedItem: PaletteItem? {
        flatItems.first { $0.id == selectedID }
    }

    func moveSelection(by offset: Int) {
        let items = flatItems
        guard !items.isEmpty else { return }
        let currentIndex = items.firstIndex { $0.id == selectedID } ?? 0
        let newIndex = min(max(currentIndex + offset, 0), items.count - 1)
        selectedID = items[newIndex].id
    }

    func activateSelected() {
        guard let item = selectedItem else { return }
        item.action()
        onActivate?(item.dismissesToPreviousApp)
    }

    /// Opens (or closes, if already open) the ⌘K action menu for the selected item. No-ops for
    /// items with no secondary actions (currently: system commands).
    func toggleActionMenu() {
        guard let item = selectedItem, !item.actions.isEmpty else { return }
        isActionMenuOpen.toggle()
        actionMenuSelectedIndex = 0
        recomputeContentHeight()
    }

    func closeActionMenu() {
        isActionMenuOpen = false
        recomputeContentHeight()
    }

    func moveActionSelection(by offset: Int) {
        guard let item = selectedItem, !item.actions.isEmpty else { return }
        let count = item.actions.count
        actionMenuSelectedIndex = min(max(actionMenuSelectedIndex + offset, 0), count - 1)
    }

    func activateActionMenuSelection() {
        guard let item = selectedItem, item.actions.indices.contains(actionMenuSelectedIndex) else { return }
        let action = item.actions[actionMenuSelectedIndex]
        isActionMenuOpen = false
        action.perform()
        // "Assign Hotkey…" leaves the palette open in capture mode instead of dismissing it, so
        // skip the usual close-on-action behavior when it just opened the capture screen.
        if hotkeyCapture == nil {
            onActivate?(action.dismissesToPreviousApp)
        }
    }

    /// Opens the "Assign Hotkey…" screen in place of the results list, replacing the ⌘K action
    /// menu. `PaletteWindowController`'s key monitor routes the next key event to
    /// `handleHotkeyCapture(event:)` instead of normal palette navigation while this is non-nil.
    func beginHotkeyCapture(bundleID: String, appName: String) {
        isActionMenuOpen = false
        hotkeyCapture = HotkeyCaptureState(bundleID: bundleID, appName: appName, currentKey: directHotkeys[bundleID], errorMessage: nil)
        recomputeContentHeight()
    }

    func cancelHotkeyCapture() {
        hotkeyCapture = nil
        recomputeContentHeight()
    }

    /// Validates the pressed key combo and, if usable, writes it to `config.toml` as `bundleID`'s
    /// Direct Hotkey. An unusable combo (no modifier, or a key `HotkeySpec` doesn't recognize)
    /// shows an inline error and keeps capturing rather than closing the screen.
    func handleHotkeyCapture(event: NSEvent) {
        guard var capture = hotkeyCapture else { return }

        guard let shortcut = KeyboardShortcuts.Shortcut(event: event) else { return }

        guard !shortcut.modifiers.isEmpty else {
            capture.errorMessage = "Add a modifier key (\u{2318}\u{2325}\u{2303}\u{21e7})"
            hotkeyCapture = capture
            return
        }

        guard let spec = HotkeySpec.describe(shortcut) else {
            capture.errorMessage = "Unsupported key"
            hotkeyCapture = capture
            return
        }

        do {
            try ConfigWriter.setDirectHotkey(key: spec, bundleID: capture.bundleID)
            directHotkeys[capture.bundleID] = spec
            hotkeyCapture = nil
            recomputeItems()
        } catch {
            capture.errorMessage = "Failed to save config.toml"
            hotkeyCapture = capture
        }
    }

    private func recomputeContentHeight() {
        if hotkeyCapture != nil {
            let captureHeight = Self.sectionHeaderHeight
                + CGFloat(Self.hotkeyCaptureLineCount) * Self.rowHeight
                + Self.dividerAndBottomPadding
            contentHeight = Self.textFieldAreaHeight + captureHeight
            return
        }

        if isActionMenuOpen, let item = selectedItem, !item.actions.isEmpty {
            let menuHeight = Self.sectionHeaderHeight
                + CGFloat(item.actions.count) * Self.rowHeight
                + Self.dividerAndBottomPadding
            contentHeight = Self.textFieldAreaHeight + menuHeight
            return
        }

        let rawListHeight = sections.reduce(CGFloat(0)) { partial, section in
            partial + Self.sectionHeaderHeight + CGFloat(section.1.count) * Self.rowHeight
        }
        let listHeight = sections.isEmpty ? 0 : min(Self.maxListHeight, rawListHeight)
        let extra: CGFloat = sections.isEmpty ? 0 : Self.dividerAndBottomPadding
        contentHeight = Self.textFieldAreaHeight + listHeight + extra
    }
}

struct PaletteView: View {
    @ObservedObject var viewModel: PaletteViewModel
    @FocusState private var searchFieldIsFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            TextField(
                viewModel.scopedSection == .clipboard ? "Search clipboard history\u{2026}" : "Search apps, commands, clipboard\u{2026}",
                text: $viewModel.query
            )
                .textFieldStyle(.plain)
                .font(.system(size: 20))
                .padding(14)
                .focused($searchFieldIsFocused)
                .onChange(of: viewModel.query) { _ in
                    viewModel.recomputeItems()
                }
                .onChange(of: viewModel.focusToken) { _ in
                    searchFieldIsFocused = true
                }

            Divider()

            if let capture = viewModel.hotkeyCapture {
                HotkeyCaptureView(state: capture)
            } else if viewModel.isActionMenuOpen, let item = viewModel.selectedItem {
                ActionMenuView(
                    item: item,
                    selectedIndex: viewModel.actionMenuSelectedIndex,
                    onSelect: { index in
                        viewModel.moveActionSelection(by: index - viewModel.actionMenuSelectedIndex)
                        viewModel.activateActionMenuSelection()
                    }
                )
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(viewModel.sections, id: \.0) { section, items in
                                Text(section.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 14)
                                    .padding(.top, 8)
                                    .padding(.bottom, 2)

                                ForEach(items) { item in
                                    PaletteRow(item: item, isSelected: item.id == viewModel.selectedID)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            viewModel.selectedID = item.id
                                            viewModel.activateSelected()
                                        }
                                }
                            }
                        }
                        .padding(.bottom, 8)
                    }
                    .frame(maxHeight: PaletteViewModel.maxListHeight)
                    .onChange(of: viewModel.selectedID) { newValue in
                        guard let newValue else { return }
                        proxy.scrollTo(newValue, anchor: nil)
                    }
                }
            }
        }
        .frame(width: 640)
        .background(.ultraThinMaterial)
        .onAppear {
            searchFieldIsFocused = true
        }
    }
}

private struct PaletteRow: View {
    let item: PaletteItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            if let icon = item.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 20, height: 20)
            } else {
                Color.clear.frame(width: 20, height: 20)
            }
            Text(item.title)
                .lineLimit(1)
            Spacer()
            if isSelected, !item.actions.isEmpty {
                Text("\u{2318}K")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
    }
}

/// The ⌘K secondary-actions menu for the currently selected item, shown in place of the results
/// list (not as an overlay) so the panel's height stays exactly `contentHeight`.
private struct ActionMenuView: View {
    let item: PaletteItem
    let selectedIndex: Int
    let onSelect: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(item.title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.top, 8)
                .padding(.bottom, 2)

            ForEach(Array(item.actions.enumerated()), id: \.element.id) { index, action in
                HStack {
                    Text(action.title)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(index == selectedIndex ? Color.accentColor.opacity(0.2) : Color.clear)
                .contentShape(Rectangle())
                .onTapGesture {
                    onSelect(index)
                }
            }
        }
        .padding(.bottom, 8)
    }
}

/// The "Assign Hotkey…" screen, shown in place of the results list while `PaletteViewModel`
/// waits for the next key event (see `PaletteWindowController`'s key monitor).
private struct HotkeyCaptureView: View {
    let state: PaletteViewModel.HotkeyCaptureState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Hotkey for \(state.appName)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(state.errorMessage ?? "Press a key combination\u{2026}")
                .foregroundStyle(state.errorMessage == nil ? Color.primary : Color.red)

            Text(state.currentKey.map { "Current: \($0)" } ?? "No hotkey assigned yet")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Esc to cancel")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }
}
