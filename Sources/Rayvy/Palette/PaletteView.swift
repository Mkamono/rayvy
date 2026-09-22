import AppKit
import SwiftUI

@MainActor
final class PaletteViewModel: ObservableObject {
    @Published var query: String = ""
    @Published private(set) var sections: [(PaletteSection, [PaletteItem])] = []
    @Published var selectedID: String?
    /// Bumped on every `reset()` so the view can re-focus the search field each time the palette
    /// is shown. Needed because the hosting view (and its SwiftUI hierarchy) is created once and
    /// reused across show/hide cycles, so `.onAppear` only fires the first time.
    @Published private(set) var focusToken = UUID()

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
    /// (running apps and clipboard history change between openings).
    func reset() {
        query = ""
        focusToken = UUID()
        recomputeItems()
    }

    func recomputeItems() {
        let appItems = appIndex.apps.map { app in
            PaletteItem(
                id: "app.\(app.id)",
                section: .applications,
                title: app.name,
                subtitle: nil,
                icon: app.icon,
                action: { AppLauncher.launch(app) }
            )
        }

        let commandItems = SystemCommand.makeItems(onQuitRayvy: onQuitRayvy)

        let clipboardItems = clipboardHistory.items.map { item in
            PaletteItem(
                id: "clipboard.\(item.id)",
                section: .clipboard,
                title: item.text,
                subtitle: nil,
                icon: NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: nil),
                action: { self.clipboardHistory.recopy(item) }
            )
        }

        let filteredApps = PaletteSearch.filter(appItems, query: query)
        let filteredCommands = PaletteSearch.filter(commandItems, query: query)
        let filteredClipboard = PaletteSearch.filter(clipboardItems, query: query)

        var newSections: [(PaletteSection, [PaletteItem])] = []
        if !filteredApps.isEmpty { newSections.append((.applications, filteredApps)) }
        if !filteredCommands.isEmpty { newSections.append((.commands, filteredCommands)) }
        if !filteredClipboard.isEmpty { newSections.append((.clipboard, filteredClipboard)) }
        sections = newSections

        let flatIDs = newSections.flatMap { $0.1.map(\.id) }
        if let selectedID, flatIDs.contains(selectedID) {
            // Keep current selection.
        } else {
            selectedID = flatIDs.first
        }
    }

    private var flatItems: [PaletteItem] {
        sections.flatMap { $0.1 }
    }

    func moveSelection(by offset: Int) {
        let items = flatItems
        guard !items.isEmpty else { return }
        let currentIndex = items.firstIndex { $0.id == selectedID } ?? 0
        let newIndex = min(max(currentIndex + offset, 0), items.count - 1)
        selectedID = items[newIndex].id
    }

    func activateSelected() {
        guard let selectedID, let item = flatItems.first(where: { $0.id == selectedID }) else { return }
        item.action()
        onActivate?()
    }
}

struct PaletteView: View {
    @ObservedObject var viewModel: PaletteViewModel
    @FocusState private var searchFieldIsFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            TextField("Search apps, commands, clipboard\u{2026}", text: $viewModel.query)
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
            .frame(maxHeight: 400)
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
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
    }
}
