import XCTest
@testable import RichTextEditorCore

final class RTFTokenizerTests: XCTestCase {
    private func toks(_ s: String) -> [RTFToken] { RTFTokenizer.tokenize(Data(s.utf8)) }

    func test_groupsAndControlWords() {
        XCTAssertEqual(toks("{\\b0 hi}"), [.groupStart, .controlWord("b", 0), .text("hi"), .groupEnd])
    }
    func test_controlWord_spaceDelimiterConsumed_otherDelimiterKept() {
        XCTAssertEqual(toks("\\par x"), [.controlWord("par", nil), .text("x")])         // space consumed
        XCTAssertEqual(toks("\\b{"), [.controlWord("b", nil), .groupStart])             // "{" not consumed
    }
    func test_escapesAndControlSymbol() {
        XCTAssertEqual(toks("\\\\\\{\\}"), [.text("\\"), .text("{"), .text("}")])
        XCTAssertEqual(toks("\\*\\foo"), [.controlSymbol("*"), .controlWord("foo", nil)])
    }
    func test_hexByte_ascii_and_cp1252() {
        XCTAssertEqual(toks("\\'41"), [.text("A")])                                     // 0x41 = 'A'
        XCTAssertEqual(toks("\\'e9"), [.text("é")])                                     // cp1252 0xE9 = é
    }
    func test_unicode_signed_and_skipsFallback() {
        XCTAssertEqual(toks("\\u233?"), [.text("é")])                                   // 233 = é, ? skipped (uc1)
        XCTAssertEqual(toks("\\u-10179?\\u-8704?"), [.text("😀")])                       // surrogate pair recombined
    }
    func test_ignoresRawNewlines() {
        XCTAssertEqual(toks("a\r\nb"), [.text("a"), .text("b")])
    }
}
