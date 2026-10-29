import XCTest
import UIKit
import TextFormat

/// `attributedStringWithParagraphSpacingAsBlankLines`: pasted rich text whose paragraph gaps exist only as
/// paragraph spacing (WebKit's `<p>` margins, a ChatGPT reply copied in Safari) gains a blank line per gap.
final class PastedRichTextParagraphGapsTests: XCTestCase {
    /// One paragraph and the attributes of its text and its terminating newline, as an RTF/HTML import gives them.
    private func paragraph(_ text: String, spacingAfter: CGFloat = 0.0, spacingBefore: CGFloat = 0.0) -> (text: String, attributes: [NSAttributedString.Key: Any]) {
        let style = NSMutableParagraphStyle()
        style.paragraphSpacing = spacingAfter
        style.paragraphSpacingBefore = spacingBefore
        return (text, [.paragraphStyle: style])
    }

    private func joined(_ parts: [(text: String, attributes: [NSAttributedString.Key: Any])]) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for (index, part) in parts.enumerated() {
            result.append(NSAttributedString(string: index == parts.count - 1 ? part.text : part.text + "\n", attributes: part.attributes))
        }
        return result
    }

    func test_spacingAfter_becomesBlankLine() {
        let string = joined([paragraph("Heading", spacingAfter: 14.0), paragraph("Body", spacingAfter: 15.0), paragraph("Last", spacingAfter: 15.0)])
        XCTAssertEqual(attributedStringWithParagraphSpacingAsBlankLines(string).string, "Heading\n\nBody\n\nLast")
    }

    func test_spacingBefore_becomesBlankLine() {
        let string = joined([paragraph("a"), paragraph("b", spacingBefore: 12.0)])
        XCTAssertEqual(attributedStringWithParagraphSpacingAsBlankLines(string).string, "a\n\nb")
    }

    func test_smallSpacing_isKept() {
        let string = joined([paragraph("a", spacingAfter: 6.0), paragraph("b")])
        XCTAssertEqual(attributedStringWithParagraphSpacingAsBlankLines(string).string, "a\nb")
    }

    func test_existingBlankLine_isNotDoubled() {
        let string = joined([paragraph("a", spacingAfter: 15.0), paragraph("", spacingAfter: 15.0), paragraph("b", spacingAfter: 15.0)])
        XCTAssertEqual(attributedStringWithParagraphSpacingAsBlankLines(string).string, "a\n\nb")
    }

    /// A spacer paragraph (`<p>&nbsp;</p>`, `<p><br></p>`) already is the blank line: none is added beside it.
    func test_whitespaceOnlySpacer_isABlankLine() {
        let nbsp = joined([paragraph("a", spacingAfter: 15.0), paragraph("\u{00A0}", spacingAfter: 15.0), paragraph("b", spacingAfter: 15.0)])
        XCTAssertEqual(attributedStringWithParagraphSpacingAsBlankLines(nbsp).string, "a\n\u{00A0}\nb")
        let lineBreak = joined([paragraph("a", spacingAfter: 15.0), paragraph("\u{2028}", spacingAfter: 15.0), paragraph("b", spacingAfter: 15.0)])
        XCTAssertEqual(attributedStringWithParagraphSpacingAsBlankLines(lineBreak).string, "a\n\u{2028}\nb")
    }

    func test_lineSeparator_isNotAParagraphBreak() {
        let string = joined([paragraph("Position: Butler\u{2028}Employment: Full-time", spacingAfter: 15.0), paragraph("Next", spacingAfter: 15.0)])
        XCTAssertEqual(attributedStringWithParagraphSpacingAsBlankLines(string).string, "Position: Butler\u{2028}Employment: Full-time\n\nNext")
    }

    func test_plainText_isUnchanged() {
        let string = NSAttributedString(string: "a\nb\n\nc\n")
        XCTAssertEqual(attributedStringWithParagraphSpacingAsBlankLines(string).string, "a\nb\n\nc\n")
    }

    func test_insertedBlankLine_carriesNoInlineFormatting() {
        let style = NSMutableParagraphStyle()
        style.paragraphSpacing = 15.0
        let string = NSMutableAttributedString(string: "bold\nnext", attributes: [.paragraphStyle: style])
        string.addAttribute(ChatTextInputAttributes.bold, value: true as NSNumber, range: NSRange(location: 0, length: 5))
        let result = attributedStringWithParagraphSpacingAsBlankLines(string)
        XCTAssertEqual(result.string, "bold\n\nnext")
        XCTAssertNil(result.attribute(ChatTextInputAttributes.bold, at: 5, effectiveRange: nil))
    }

    /// The route `chatInputStateStringFromRTF` takes: iOS's own RTF import of what Safari copies from a
    /// ChatGPT-shaped page with no list (`\saN` on every paragraph, `<br>` as U+2028).
    func test_webKitRTF_throughNSAttributedStringImport() throws {
        let rtf = """
        {\\rtf1\\ansi\\ansicpg1252\\cocoartf2907
        {\\fonttbl\\f0\\fnil\\fcharset0 .SFUI-Bold;\\f1\\fnil\\fcharset0 .SFUI-Regular;}
        \\pard\\pardeftab720\\sa280\\partightenfactor0

        \\f0\\b\\fs42 \\cf0 Position Summary\\
        \\pard\\pardeftab720\\sa300\\partightenfactor0

        \\fs46 \\cf0 Position:
        \\f1\\b0  Private Household Butler
        \\fs30 \\uc0\\u8232 
        \\f0\\b\\fs46 Employment:
        \\f1\\b0  Full-time\\
        We are looking for a candidate.\\
        }
        """
        let imported = try NSAttributedString(data: Data(rtf.utf8), options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
        XCTAssertEqual(attributedStringWithParagraphSpacingAsBlankLines(imported).string, "Position Summary\n\nPosition: Private Household Butler\u{2028}Employment: Full-time\n\nWe are looking for a candidate.\n")
    }
}
