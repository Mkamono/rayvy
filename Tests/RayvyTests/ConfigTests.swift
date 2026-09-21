import XCTest
import TOMLKit
@testable import Rayvy

final class ConfigTests: XCTestCase {
    func testParsesFullConfig() throws {
        let toml = """
        [launcher]
        hotkey = "option+space"

        [clipboard]
        enabled = true
        max_items = 50
        excluded_bundle_ids = ["com.apple.SecurityAgent"]

        [[hotkeys]]
        key = "option+t"
        bundle_id = "com.mitchellh.ghostty"

        [[hotkeys]]
        key = "option+b"
        bundle_id = "com.apple.Safari"
        """

        let config = try TOMLDecoder().decode(Config.self, from: toml)

        XCTAssertEqual(config.launcher.hotkey, "option+space")
        XCTAssertEqual(config.clipboard.enabled, true)
        XCTAssertEqual(config.clipboard.maxItems, 50)
        XCTAssertEqual(config.clipboard.excludedBundleIDs, ["com.apple.SecurityAgent"])
        XCTAssertEqual(config.hotkeys.count, 2)
        XCTAssertEqual(config.hotkeys[0], HotkeyEntry(key: "option+t", bundleID: "com.mitchellh.ghostty"))
        XCTAssertEqual(config.hotkeys[1], HotkeyEntry(key: "option+b", bundleID: "com.apple.Safari"))
    }

    func testMissingSectionsFallBackToDefaults() throws {
        let toml = """
        [launcher]
        hotkey = "cmd+space"
        """

        let config = try TOMLDecoder().decode(Config.self, from: toml)

        XCTAssertEqual(config.launcher.hotkey, "cmd+space")
        XCTAssertEqual(config.clipboard, ClipboardConfig())
        XCTAssertEqual(config.hotkeys, [])
    }

    func testEmptyDocumentUsesAllDefaults() throws {
        let config = try TOMLDecoder().decode(Config.self, from: "")
        XCTAssertEqual(config, Config.default)
    }

    func testDefaultTemplateParsesSuccessfully() throws {
        let config = try TOMLDecoder().decode(Config.self, from: ConfigDefaults.template)
        XCTAssertEqual(config.launcher.hotkey, "option+space")
        XCTAssertEqual(config.hotkeys.count, 2)
    }
}
