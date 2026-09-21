import AppKit

// Top-level code in `main.swift` isn't implicitly @MainActor-isolated, even though it always
// runs on the main thread at process startup (before the run loop starts).
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
