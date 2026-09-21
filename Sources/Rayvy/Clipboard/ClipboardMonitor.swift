import AppKit
import Foundation

/// Polls `NSPasteboard.general` for changes and forwards new text to `ClipboardHistory`.
/// Skips items marked concealed/transient (password managers) and copies made while an
/// excluded app is frontmost.
final class ClipboardMonitor {
    private static let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
    private static let transientType = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")

    private let history: ClipboardHistory
    private var timer: Timer?
    private var lastChangeCount: Int
    var isEnabled: Bool
    var excludedBundleIDs: Set<String>

    init(history: ClipboardHistory, isEnabled: Bool, excludedBundleIDs: [String]) {
        self.history = history
        self.isEnabled = isEnabled
        self.excludedBundleIDs = Set(excludedBundleIDs)
        self.lastChangeCount = NSPasteboard.general.changeCount
    }

    func start() {
        stop()
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.pollPasteboard()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func pollPasteboard() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        guard isEnabled else { return }

        if let frontmostBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
           excludedBundleIDs.contains(frontmostBundleID) {
            return
        }

        guard let item = pasteboard.pasteboardItems?.first else { return }
        if item.types.contains(Self.concealedType) || item.types.contains(Self.transientType) {
            return
        }

        guard let text = item.string(forType: .string), !text.isEmpty else { return }
        history.add(text: text)
    }
}
