import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** On the engine backend, a keyboard replacement whose text contains a NEWLINE — a user
/// text replacement expanding to two lines (Settings ▸ Keyboard ▸ Text Replacement allows them), a
/// Writing Tools rewrite, a dictation correction — gives the replaced word's attributes to the whole
/// replacement, INCLUDING the text after the newline, which is a new paragraph:
///
///     [p "The " [sp]"quick" " fox"], replace "quick" with "a⏎b"
///       engine:  [p "The " [sp]"a"] [p [sp]"b" " fox"]       ← b is hidden in the next paragraph
///       typing the same over the selection:  [p "The a"] [p "b fox"]
///     monospace and bold the same ("b" in the next paragraph is inline code / bold)
///     [h2 "Heading text"], replace "text" with "a⏎b"
///       model [h2 "Heading a"] [p "b"], but "b" is DRAWN in the heading's face: the engine's own verifier
///       reports presentation drift (IDInlineTextBaseFont, NSFont, NSParagraphStyle) on the body line;
///       typing over the same selection, or inserting the same text, is clean. The next keystroke heals it.
///
/// **How it was seen.** p12 roam, 2026-09-24: text replacements driven as the keyboard applies them,
/// `replace(_:withText:)` on the engine's `UITextInput`, compared with typing over the same selection.
///
/// **Suspected cause.** `TGIDObservingBlockTextView.replaceRange:withText:` asks
/// `tgid_replacementAttributesHandler` for the replaced range's attributes (the autocorrect fix, findings
/// row 48) and `tgid_attributeReplacement:` then writes them over `NSMakeRange(replaced.location,
/// forwarded.length)` — a range that runs across the block separator the replacement just inserted, into
/// the new paragraph.
///
/// **Tier 1**: `replace(_:withText:)` is the call the keyboard makes for a replacement; typing over the
/// same selection (`insertText` per character) is the oracle.
@available(iOS 18.4, *)
final class HarnessMultiLineReplacementAttributesTests: XCTestCase {
    private func run(_ content: ChatInputContent, range: NSRange, text: String, typing: Bool) throws -> (model: String, violations: [String]) {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer {
            verifier.restore()
            _ = driver.node.resignInputFirstResponder()
        }
        driver.arrange(content)
        driver.settle(0.1)
        let input = try XCTUnwrap(driver.view as? (UIView & UITextInput))
        if typing {
            driver.setViewSelection(range)
            driver.settle(0.1)
            for character in text {
                input.insertText(String(character))
                driver.settle(0.03)
            }
        } else {
            let start = try XCTUnwrap(input.position(from: input.beginningOfDocument, offset: range.location))
            let end = try XCTUnwrap(input.position(from: start, offset: range.length))
            input.replace(try XCTUnwrap(input.textRange(from: start, to: end)), withText: text)
        }
        driver.settle(0.3)
        return (FuzzModel.describe(FuzzModel.normalized(driver.model())), driver.engineVerifierViolations())
    }

    private func sentence(_ attributes: ChatInputInlineAttributes) -> ChatInputContent {
        return ChatInputContent(blocks: [.paragraph(ChatInputParagraph(style: .body, list: nil, runs: [
            ChatInputRun(text: "The "), ChatInputRun(text: "quick", attributes: attributes), ChatInputRun(text: " fox"),
        ]))])
    }

    private func assertReplacementMatchesTyping(_ attributes: ChatInputInlineAttributes, _ what: String) throws {
        let content = self.sentence(attributes)
        let range = NSRange(location: 4, length: 5)
        let typed = try self.run(content, range: range, text: "a\nb", typing: true)
        let replaced = try self.run(content, range: range, text: "a\nb", typing: false)
        // The second paragraph is what the replacement must not have formatted.
        let typedSecond = typed.model.components(separatedBy: "] [").last
        let replacedSecond = replaced.model.components(separatedBy: "] [").last
        XCTAssertEqual(replacedSecond, typedSecond,
                       "a two-line replacement of a \(what) word carried the word's attributes into the next paragraph: replaced \(replaced.model), typed \(typed.model)")
    }

    func testASpoileredWordReplacedWithTwoLinesLeavesTheNextParagraphRevealed() throws {
        var attributes = ChatInputInlineAttributes()
        attributes.spoiler = true
        try self.assertReplacementMatchesTyping(attributes, "spoilered")
    }

    func testAnInlineCodeWordReplacedWithTwoLinesLeavesTheNextParagraphPlain() throws {
        var attributes = ChatInputInlineAttributes()
        attributes.monospace = true
        try self.assertReplacementMatchesTyping(attributes, "inline-code")
    }

    func testAHeadingWordReplacedWithTwoLinesDrawsTheNewLineAsBody() throws {
        let content = ChatInputContent(blocks: [
            .paragraph(ChatInputParagraph(style: .heading2, list: nil, runs: [ChatInputRun(text: "Heading text")])),
            HarnessEngine.paragraph("Body."),
        ])
        let replaced = try self.run(content, range: NSRange(location: 8, length: 4), text: "a\nb", typing: false)
        XCTAssertEqual(replaced.model, "[p heading2 \"Heading a\"] [p body \"b\"] [p body \"Body.\"]", "precondition: the replacement did not land")
        XCTAssertEqual(replaced.violations, [], "the replacement's new body line is drawn in the heading's face")
    }

    /// Control: typing the same over the same selection leaves the new line drawn as body.
    func testControlTypingOverAHeadingWordIsClean() throws {
        let content = ChatInputContent(blocks: [
            .paragraph(ChatInputParagraph(style: .heading2, list: nil, runs: [ChatInputRun(text: "Heading text")])),
            HarnessEngine.paragraph("Body."),
        ])
        let typed = try self.run(content, range: NSRange(location: 8, length: 4), text: "a\nb", typing: true)
        XCTAssertEqual(typed.model, "[p heading2 \"Heading a\"] [p body \"b\"] [p body \"Body.\"]")
        XCTAssertEqual(typed.violations, [])
    }

    /// Control: a one-line replacement of a spoilered word stays spoilered (the autocorrect rule).
    func testControlAOneLineReplacementKeepsTheWordsAttributes() throws {
        var attributes = ChatInputInlineAttributes()
        attributes.spoiler = true
        let replaced = try self.run(self.sentence(attributes), range: NSRange(location: 4, length: 5), text: "slow", typing: false)
        XCTAssertEqual(replaced.model, "[p body \"The \"+[sp]\"slow\"+\" fox\"]")
    }
}
