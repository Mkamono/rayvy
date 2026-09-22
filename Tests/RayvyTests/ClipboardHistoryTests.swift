import XCTest
@testable import Rayvy

final class ClipboardHistoryTests: XCTestCase {
    private func makeHistory(maxItems: Int) -> ClipboardHistory {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("rayvy-tests-\(UUID().uuidString).json")
        return ClipboardHistory(maxItems: maxItems, storageURL: url)
    }

    func testAddInsertsAtFront() {
        let history = makeHistory(maxItems: 10)
        history.add(text: "first")
        history.add(text: "second")
        XCTAssertEqual(history.items.map(\.text), ["second", "first"])
    }

    func testDuplicateTextMovesToFrontInsteadOfDuplicating() {
        let history = makeHistory(maxItems: 10)
        history.add(text: "a")
        history.add(text: "b")
        history.add(text: "a")
        XCTAssertEqual(history.items.map(\.text), ["a", "b"])
    }

    func testTrimsToMaxItems() {
        let history = makeHistory(maxItems: 3)
        for text in ["a", "b", "c", "d", "e"] {
            history.add(text: text)
        }
        XCTAssertEqual(history.items.map(\.text), ["e", "d", "c"])
    }

    func testSearchIsCaseInsensitiveSubstring() {
        let history = makeHistory(maxItems: 10)
        history.add(text: "Hello World")
        history.add(text: "Goodbye")
        XCTAssertEqual(history.search("hello").map(\.text), ["Hello World"])
        XCTAssertEqual(history.search("").count, 2)
    }

    func testIgnoresEmptyText() {
        let history = makeHistory(maxItems: 10)
        history.add(text: "")
        XCTAssertTrue(history.items.isEmpty)
    }

    func testRemoveDeletesOnlyTheGivenItem() {
        let history = makeHistory(maxItems: 10)
        history.add(text: "keep")
        history.add(text: "delete-me")
        let toRemove = history.items.first { $0.text == "delete-me" }!
        history.remove(toRemove)
        XCTAssertEqual(history.items.map(\.text), ["keep"])
    }
}
