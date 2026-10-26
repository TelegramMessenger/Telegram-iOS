import XCTest
import SwiftSignalKit
@testable import TextFormat

/// End-to-end against the real libprisma engine (the grammars ship with the library).
final class SyntaxHighlightLanguageCasingTests: XCTestCase {
    private func entities(language: String, text: String) -> [MessageSyntaxHighlight.Entity] {
        let spec = CachedMessageSyntaxHighlight.Spec(language: language, text: text)
        var result: [MessageSyntaxHighlight.Entity] = []
        let expectation = XCTestExpectation(description: "highlight")
        let disposable = asyncStanaloneSyntaxHighlight(current: nil, specs: [spec]).start(next: { value in
            result = value.values[spec]?.entities ?? []
            expectation.fulfill()
        })
        wait(for: [expectation], timeout: 10.0)
        disposable.dispose()
        return result
    }

    /// The control: the engine works and this text has something to colour.
    func testLowercaseLanguageIsHighlighted() {
        XCTAssertFalse(entities(language: "swift", text: "let x = 1").isEmpty,
                       "precondition: libprisma highlights `swift`")
    }

    /// `LanguageTree::find` is an exact std::map lookup and prisma's grammar keys are lowercase, so a
    /// capitalized language silently produced NO tokens — and the code-block language field stores what
    /// the author typed, so "Swift" reaches this path routinely.
    func testCapitalizedLanguageIsHighlightedTheSame() {
        XCTAssertEqual(entities(language: "Swift", text: "let x = 1").count,
                       entities(language: "swift", text: "let x = 1").count,
                       "a capitalized language must resolve to the same grammar")
    }

    func testSurroundingWhitespaceInTheLanguageIsIgnored() {
        XCTAssertEqual(entities(language: "  swift  ", text: "let x = 1").count,
                       entities(language: "swift", text: "let x = 1").count)
    }
}
