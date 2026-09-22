import XCTest
import TOMLKit
@testable import Rayvy

final class ConfigWriterTests: XCTestCase {
    private var tempFileURL: URL!

    override func setUp() {
        super.setUp()
        tempFileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("rayvy-config-writer-tests-\(UUID().uuidString).toml")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempFileURL)
        tempFileURL = nil
        super.tearDown()
    }

    func testAddsNewHotkeyEntryPreservingRestOfFile() throws {
        let original = """
        [launcher]
        hotkey = "option+space"

        [clipboard]
        enabled = true
        max_items = 50
        """
        try original.write(to: tempFileURL, atomically: true, encoding: .utf8)

        try ConfigWriter.setDirectHotkey(key: "option+t", bundleID: "com.mitchellh.ghostty", fileURL: tempFileURL)

        let config = try TOMLDecoder().decode(Config.self, from: String(contentsOf: tempFileURL, encoding: .utf8))
        XCTAssertEqual(config.launcher.hotkey, "option+space")
        XCTAssertEqual(config.clipboard.maxItems, 50)
        XCTAssertEqual(config.hotkeys, [HotkeyEntry(key: "option+t", bundleID: "com.mitchellh.ghostty")])
    }

    func testUpdatesExistingEntryForSameBundleID() throws {
        let original = """
        [[hotkeys]]
        key = "option+t"
        bundle_id = "com.mitchellh.ghostty"

        [[hotkeys]]
        key = "option+b"
        bundle_id = "com.apple.Safari"
        """
        try original.write(to: tempFileURL, atomically: true, encoding: .utf8)

        try ConfigWriter.setDirectHotkey(key: "cmd+shift+t", bundleID: "com.mitchellh.ghostty", fileURL: tempFileURL)

        let config = try TOMLDecoder().decode(Config.self, from: String(contentsOf: tempFileURL, encoding: .utf8))
        XCTAssertEqual(config.hotkeys, [
            HotkeyEntry(key: "cmd+shift+t", bundleID: "com.mitchellh.ghostty"),
            HotkeyEntry(key: "option+b", bundleID: "com.apple.Safari")
        ])
    }

    func testCreatesFileFromTemplateWhenMissing() throws {
        try ConfigWriter.setDirectHotkey(key: "option+g", bundleID: "com.example.app", fileURL: tempFileURL)

        let config = try TOMLDecoder().decode(Config.self, from: String(contentsOf: tempFileURL, encoding: .utf8))
        XCTAssertTrue(config.hotkeys.contains(HotkeyEntry(key: "option+g", bundleID: "com.example.app")))
    }
}
