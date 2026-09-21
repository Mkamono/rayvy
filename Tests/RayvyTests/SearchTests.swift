import XCTest
@testable import Rayvy

final class SearchTests: XCTestCase {
    private func makeItem(id: String, title: String, subtitle: String? = nil) -> PaletteItem {
        PaletteItem(id: id, section: .applications, title: title, subtitle: subtitle, icon: nil, action: {})
    }

    func testEmptyQueryMatchesEverything() {
        let item = makeItem(id: "1", title: "Safari")
        XCTAssertTrue(PaletteSearch.matches(item, query: ""))
    }

    func testSubstringMatchIsCaseInsensitive() {
        let item = makeItem(id: "1", title: "Ghostty")
        XCTAssertTrue(PaletteSearch.matches(item, query: "host"))
        XCTAssertTrue(PaletteSearch.matches(item, query: "GHOST"))
        XCTAssertFalse(PaletteSearch.matches(item, query: "zzz"))
    }

    func testMatchesFallsBackToSubtitle() {
        let item = makeItem(id: "1", title: "Quit App", subtitle: "com.example.app")
        XCTAssertTrue(PaletteSearch.matches(item, query: "example"))
    }

    func testFilterKeepsOnlyMatchingItems() {
        let items = [
            makeItem(id: "1", title: "Safari"),
            makeItem(id: "2", title: "Terminal"),
            makeItem(id: "3", title: "Ghostty")
        ]
        let result = PaletteSearch.filter(items, query: "t")
        XCTAssertEqual(Set(result.map(\.id)), Set(["2", "3"]))
    }
}
