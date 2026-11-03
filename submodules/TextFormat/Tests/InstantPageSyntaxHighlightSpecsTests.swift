import XCTest
import TelegramCore
@testable import TextFormat

final class InstantPageSyntaxHighlightSpecsTests: XCTestCase {
    private func code(_ text: String, _ language: String?) -> InstantPageBlock {
        return .preformatted(text: .plain(text), language: language)
    }

    func testCollectsATopLevelCodeBlock() {
        let specs = instantPageSyntaxHighlightSpecs(for: [code("let x = 1", "Swift")])
        XCTAssertEqual(specs.count, 1)
        XCTAssertEqual(specs[0].language, "swift")   // normalized: trimmed + lowercased
        XCTAssertEqual(specs[0].text, "let x = 1")
    }

    func testSkipsBlocksWithNoUsableLanguage() {
        XCTAssertTrue(instantPageSyntaxHighlightSpecs(for: [code("let x = 1", nil)]).isEmpty)
        XCTAssertTrue(instantPageSyntaxHighlightSpecs(for: [code("let x = 1", "")]).isEmpty)
        XCTAssertTrue(instantPageSyntaxHighlightSpecs(for: [code("let x = 1", "   ")]).isEmpty)
        XCTAssertTrue(instantPageSyntaxHighlightSpecs(for: [code("", "swift")]).isEmpty)
    }

    func testDeduplicatesIdenticalSpecs() {
        let specs = instantPageSyntaxHighlightSpecs(for: [code("a", "swift"), code("a", "swift"), code("b", "swift")])
        XCTAssertEqual(specs.count, 2)
    }

    // Nesting. `blockQuote` is the case the private BrowserUI copy never handled — its `collect` ended in
    // `default: break` — so code inside a quote was collected by nobody, and rich messages nest code in
    // quotes routinely.
    func testCollectsCodeNestedInContainers() {
        let blocks: [InstantPageBlock] = [
            .details(title: .plain("d"), blocks: [code("inDetails", "swift")], expanded: false),
            .list(items: [.blocks([code("inList", "python")], nil, nil)], ordered: false),
            .blockQuote(blocks: [code("inQuote", "ruby")], caption: .empty, collapsed: nil),
        ]
        let specs = instantPageSyntaxHighlightSpecs(for: blocks)
        XCTAssertEqual(Set(specs.map(\.text)), Set(["inDetails", "inList", "inQuote"]))
    }
}
