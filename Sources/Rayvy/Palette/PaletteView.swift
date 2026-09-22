import AppKit
import SwiftUI

@MainActor
final class PaletteViewModel: ObservableObject {
    // Single source of truth for panel layout, shared with PaletteWindowController via
    // `contentHeight` so the window always exactly fits what's currently on screen (the results
    // list, or the ⌘K action menu when one is open).
    static let rowHeight: CGFloat = 32
    static let sectionHeaderHeight: CGFloat = 26
    static let textFieldAreaHeight: CGFloat = 56
    static let dividerAndBottomPadding: CGFloat = 9
    static let maxListHeight: CGFloat = 400

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
    @Published private(set) var contentHeight: CGFloat = PaletteViewModel.textFieldAreaHeight

    private let appIndex: AppIndex
    private let clipboardHistory: ClipboardHistory
    private let onQuitRayvy: () -> Void
    var onActivate: (() -> Void)?

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
        scopedSection = scopedToClipboard ? .clipboard : nil
        recomputeItems()
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
            actions.append(PaletteAction(id: "reveal", title: "Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([app.url])
            })
            actions.append(PaletteAction(id: "copyBundleID", title: "Copy Bundle ID") {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(app.id, forType: .string)
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

        var newSections: [(PaletteSection, [PaletteItem])] = []
        if !filteredApps.isEmpty { newSections.append((.applications, filteredApps)) }
        if !filteredCommands.isEmpty { newSections.append((.commands, filteredCommands)) }
        if !filteredClipboard.isEmpty { newSections.append((.clipboard, filteredClipboard)) }
        applySections(newSections)
    }

    /// Used when the palette was opened via the Clipboard History hotkey: skips indexing apps and
    /// commands entirely, since only the clipboard section can ever be shown.
    private func recomputeClipboardOnlyItems() {
        let filteredClipboard = PaletteSearch.filter(makeClipboardItems(), query: query)
        applySections(filteredClipboard.isEmpty ? [] : [(.clipboard, filteredClipboard)])
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
                action: { self.clipboardHistory.recopy(item) }
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
        onActivate?()
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
        onActivate?()
    }

    private func recomputeContentHeight() {
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

            if viewModel.isActionMenuOpen, let item = viewModel.selectedItem {
                ActionMenuView(
                    item: item,
                    selectedIndex: viewModel.actionMenuSelectedIndex,
                    onSelect: { index in
                        viewModel.moveActionSelection(by: index - viewModel.actionMenuSelectedIndex)
                        viewModel.activateActionMenuSelection()
                    }
                )
            } else {
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
