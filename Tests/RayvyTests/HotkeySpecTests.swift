import XCTest
import KeyboardShortcuts
@testable import Rayvy

final class HotkeySpecTests: XCTestCase {
    func testParsesSingleModifier() {
        let shortcut = HotkeySpec.parse("option+space")
        XCTAssertEqual(shortcut?.key, .space)
        XCTAssertEqual(shortcut?.modifiers, [.option])
    }

    func testParsesMultipleModifiers() {
        let shortcut = HotkeySpec.parse("cmd+shift+t")
        XCTAssertEqual(shortcut?.key, .t)
        XCTAssertEqual(shortcut?.modifiers, [.command, .shift])
    }

    func testIsCaseInsensitive() {
        let shortcut = HotkeySpec.parse("OPTION+B")
        XCTAssertEqual(shortcut?.key, .b)
        XCTAssertEqual(shortcut?.modifiers, [.option])
    }

    func testRejectsUnknownKey() {
        XCTAssertNil(HotkeySpec.parse("option+notakey"))
    }

    func testRejectsUnknownModifier() {
        XCTAssertNil(HotkeySpec.parse("hyper+t"))
    }

    func testRoundTrip() {
        for spec in ["option+space", "cmd+t", "option+b", "control+shift+z"] {
            let shortcut = HotkeySpec.parse(spec)
            XCTAssertNotNil(shortcut, "failed to parse \(spec)")
            let described = shortcut.flatMap(HotkeySpec.describe)
            XCTAssertEqual(HotkeySpec.parse(described ?? ""), shortcut, "round trip failed for \(spec)")
        }
    }
}
