import XCTest
import TelegramCore
@testable import TextFormat

final class CodeBlockMarkersTests: XCTestCase {
    func testCodeBlockAttributeIsBlockKindCode() {
        let (key, value) = chatInputCodeBlockAttribute(language: "swift")
        XCTAssertEqual(key, ChatTextInputAttributes.block)
        let q = value as? ChatTextInputTextQuoteAttribute
        XCTAssertNotNil(q)
        if case let .code(language) = q!.kind { XCTAssertEqual(language, "swift") } else { XCTFail("expected .code kind") }
        XCTAssertFalse(q!.isCollapsed)
    }

    func testCodeBlockAttributeNilLanguage() {
        let (_, value) = chatInputCodeBlockAttribute(language: nil)
        let q = value as? ChatTextInputTextQuoteAttribute
        if case let .code(language) = q!.kind { XCTAssertNil(language) } else { XCTFail("expected .code kind") }
    }

    func testCodeBlockRangesFindsContiguousCodeIncludingNewlines() {
        // "ab\ncd" with the WHOLE string carrying a .block/.code attribute → one region, language "py".
        let s = NSMutableAttributedString(string: "ab\ncd")
        s.addAttribute(ChatTextInputAttributes.block,
                       value: ChatTextInputTextQuoteAttribute(kind: .code(language: "py"), isCollapsed: false),
                       range: NSRange(location: 0, length: 5))
        let regions = codeBlockRanges(in: s)
        XCTAssertEqual(regions.count, 1)
        XCTAssertEqual(regions[0].range, NSRange(location: 0, length: 5))
        XCTAssertEqual(regions[0].language, "py")
    }

    func testCodeBlockRangesIgnoresQuoteBlocks() {
        let s = NSMutableAttributedString(string: "ab")
        s.addAttribute(ChatTextInputAttributes.block,
                       value: ChatTextInputTextQuoteAttribute(kind: .quote, isCollapsed: false),
                       range: NSRange(location: 0, length: 2))
        XCTAssertTrue(codeBlockRanges(in: s).isEmpty)
    }
}
