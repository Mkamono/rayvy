import Foundation

/// Watches `~/.config/rayvy/config.toml` for changes and notifies a callback with the reloaded
/// config. Watches the file itself (so in-place saves, which don't touch the containing
/// directory's entries, are seen), and on a rename/delete event — which most editors do on save,
/// replacing the file's inode rather than writing into it — re-opens a fresh descriptor on the
/// new file so it keeps watching after the replacement.
final class ConfigWatcher {
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: CInt = -1
    private var debounceWorkItem: DispatchWorkItem?
    private let onChange: (Config) -> Void

    init(onChange: @escaping (Config) -> Void) {
        self.onChange = onChange
    }

    func start() {
        stop()

        let directoryURL = ConfigLoader.configDirectoryURL
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        openSource()
    }

    func stop() {
        source?.setEventHandler {}
        source?.cancel()
        source = nil
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
    }

    private func openSource() {
        let fileURL = ConfigLoader.configFileURL
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }

        let fd = open(fileURL.path, O_EVTONLY)
        guard fd >= 0 else { return }
        fileDescriptor = fd

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete],
            queue: DispatchQueue.main
        )
        source.setEventHandler { [weak self] in
            guard let self else { return }
            self.scheduleReload()
            if source.data.contains(.rename) || source.data.contains(.delete) {
                self.reopenAfterReplace()
            }
        }
        source.setCancelHandler { [weak self] in
            if let self, self.fileDescriptor >= 0 {
                close(self.fileDescriptor)
                self.fileDescriptor = -1
            }
        }
        source.resume()
        self.source = source
    }

    /// The old descriptor now points at a stale/unlinked inode (the editor replaced the file
    /// rather than writing into it), so drop it and attach a fresh one to the file at the same
    /// path. A short delay gives a write-temp-then-rename save time to finish before we reopen.
    private func reopenAfterReplace() {
        source?.setEventHandler {}
        source?.cancel()
        source = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.openSource()
        }
    }

    private func scheduleReload() {
        debounceWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, let config = ConfigLoader.reload() else { return }
            self.onChange(config)
        }
        debounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }

    deinit {
        stop()
    }
}
