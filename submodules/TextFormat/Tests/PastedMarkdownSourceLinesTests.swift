import XCTest
import TextFormat

/// What `MarkdownSourceLineBreaks.keep` (BrowserMarkdown, the markdown-on-paste parse) reads from Foundation's
/// markdown parser: soft breaks, and blank lines between top-level blocks from their source positions (#70: a
/// ChatGPT reply copied with its Copy button, joined into one line and stripped of its blank lines).
@available(iOS 16.0, *)
final class PastedMarkdownSourceLinesTests: XCTestCase {
    private func parse(_ markdown: String) throws -> NSAttributedString {
        var options = AttributedString.MarkdownParsingOptions()
        options.appliesSourcePositionAttributes = true
        return try NSAttributedString(markdown: Data(markdown.utf8), options: options, baseURL: nil)
    }

    /// The top-level blocks in document order, each with its source lines.
    private func topLevelBlockLines(_ string: NSAttributedString) -> [ClosedRange<Int>?] {
        let lines = markdownTopLevelBlockSourceLines(string)
        var order: [Int] = []
        string.enumerateAttribute(NSAttributedString.Key("NSPresentationIntent"), in: NSRange(location: 0, length: string.length), options: []) { value, _, _ in
            if let root = (value as? PresentationIntent)?.components.last, !order.contains(root.identity) {
                order.append(root.identity)
            }
        }
        return order.map { lines[$0] }
    }

    func test_keyValueLines_areSoftBreaks() throws {
        let string = try parse("**Position:** Private Household Butler\n**Employment:** Full-time\n**Working Hours:** Flexible")
        var softBreaks = 0
        string.enumerateAttributes(in: NSRange(location: 0, length: string.length), options: []) { attributes, range, _ in
            if markdownRunIsSoftBreak(attributes, text: (string.string as NSString).substring(with: range)) {
                softBreaks += 1
            }
        }
        XCTAssertEqual(softBreaks, 2)
        XCTAssertEqual(string.string, "Position: Private Household Butler Employment: Full-time Working Hours: Flexible")
    }

    func test_plainSpace_isNotASoftBreak() throws {
        let string = try parse("Position: Butler")
        var softBreaks = 0
        string.enumerateAttributes(in: NSRange(location: 0, length: string.length), options: []) { attributes, range, _ in
            if markdownRunIsSoftBreak(attributes, text: (string.string as NSString).substring(with: range)) {
                softBreaks += 1
            }
        }
        XCTAssertEqual(softBreaks, 0)
    }

    func test_chatGPTReply_blankLinesBetweenBlocks() throws {
        let markdown = """
        ### Position Summary

        **Position:** Private Household Butler
        **Employment:** Full-time

        They should have a good understanding of:
        - Formal table setting.
        - Silver Service techniques.



        ```
        code
        ```
        We are looking for a candidate.
        """
        let lines = topLevelBlockLines(try parse(markdown))
        XCTAssertEqual(lines.count, 6)
        // Heading; paragraph after a blank line; paragraph after a blank line; the list right after it; the
        // code block after three blank lines (one blank line); the paragraph right after the fence.
        XCTAssertEqual(markdownBlankLineBeforeBlocks(lines), [false, true, true, false, true, false])
    }

    func test_blankLineBeforeBlocks_unknownLinesAddNone() {
        XCTAssertEqual(markdownBlankLineBeforeBlocks([1 ... 1, nil, 5 ... 5]), [false, false, false])
        XCTAssertEqual(markdownBlankLineBeforeBlocks([1 ... 2, 4 ... 4, 5 ... 6]), [false, true, false])
        XCTAssertEqual(markdownBlankLineBeforeBlocks([]), [])
    }
}
