import Foundation

/// Watches `~/.config/rayvy/config.toml` for changes and notifies a callback with the reloaded
/// config. Uses a `DispatchSourceFileSystemObject` on the containing directory so it survives
/// editors that replace the file via rename-on-save (which invalidates a descriptor opened
/// directly on the file).
final class ConfigWatcher {
    private var source: DispatchSourceFileSystemObject?
    private var directoryFileDescriptor: CInt = -1
    private var debounceWorkItem: DispatchWorkItem?
    private let onChange: (Config) -> Void

    init(onChange: @escaping (Config) -> Void) {
        self.onChange = onChange
    }

    func start() {
        stop()

        let directoryURL = ConfigLoader.configDirectoryURL
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let fd = open(directoryURL.path, O_EVTONLY)
        guard fd >= 0 else { return }
        directoryFileDescriptor = fd

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete],
            queue: DispatchQueue.main
        )
        source.setEventHandler { [weak self] in
            self?.scheduleReload()
        }
        source.setCancelHandler { [weak self] in
            if let self, self.directoryFileDescriptor >= 0 {
                close(self.directoryFileDescriptor)
                self.directoryFileDescriptor = -1
            }
        }
        source.resume()
        self.source = source
    }

    func stop() {
        source?.cancel()
        source = nil
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
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
