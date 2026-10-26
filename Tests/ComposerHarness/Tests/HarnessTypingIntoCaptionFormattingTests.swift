import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** On the engine backend, TYPING over a selection that crosses a media unit — from a
/// paragraph into a media CAPTION, or from a caption into the next block — gives the typed text the
/// formatting of the selection's END and drops the formatting where it starts. The same edit between
/// paragraphs keeps the start's formatting (a stock text
/// view's rule too: replaced text takes the attributes of the first replaced character), and an IME
/// composition over the very same caption selection does as well — so typing and composing disagree:
///
///     [p "ta" [b]"sk"] [media cap="A caption"], select "sk⏎⎕⏎A " (2..<9), type 漢字
///       typed:    [p "ta漢字"] [media cap="caption"]            the bold is gone
///       composed: [p "ta" [b]"漢字"] [media cap="caption"]
///     [p "task"] [media cap=[s]"A caption"], the same
///       typed:    [p "ta" [s]"漢字"] …                           struck through, from the caption
///       composed: [p "ta漢字"] …
///     the other direction, from a caption across the media unit's end into the next paragraph:
///     [p "x"] [media cap="Two " [b]"Bo" " z"] [p "tail"], select "o z⏎ta" (8..<14), type 漢字
///       typed:    cap="Two 漢字"   composed: cap="Two " [b]"漢字"   (a mention there: the same)
///     controls, the same selections ending in a paragraph: typed = composed = the start's formatting
///
/// **How it was seen.** p15 (2026-09-24), the edited-content fuzz with the external-push op, seeds 74 and
/// 82: the `compose` op's invariant (a composition does what typing its result does) failed over a
/// selection that entered a media caption.
///
/// **Suspected cause.** The surface gate's cross-block replacement (`applyReplaceOutcome`,
/// `RichTextEngineEditorView+SurfaceGate.swift`) inserts the typed text with the attributes of the
/// END endpoint when the range crosses a media unit (atom line + caption, dropped or cut as one unit, so
/// the end's remainder is the survivor the text is typed into) — whereas a
/// composition deletes first (`setMarkedText:` asks the gate for an empty replacement) and then composes
/// at the caret with the start's typing attributes.
///
/// **Tier 1**: `insertText` and `setMarkedText(_:selectedRange:)` / `unmarkText()` over a view selection,
/// the calls the keyboard makes.
@available(iOS 18.4, *)
final class HarnessTypingIntoCaptionFormattingTests: XCTestCase {
    typealias E = HarnessEdited

    private static func media(_ caption: [ChatInputRun]) -> ChatInputBlock {
        return .media(ChatInputMedia(items: [ChatInputMediaItem(media: E.image(1), kind: .image, naturalSize: ChatInputSize(width: 400.0, height: 300.0))], caption: caption))
    }

    private static var bold: ChatInputInlineAttributes {
        var value = ChatInputInlineAttributes()
        value.bold = true
        return value
    }

    private static var strike: ChatInputInlineAttributes {
        var value = ChatInputInlineAttributes()
        value.strikethrough = true
        return value
    }

    /// The model after composing 漢字 (k → か → … → 漢字, committed) over `range`, and after typing 漢字
    /// over the same range, each from a fresh `content`.
    private func composedAndTyped(_ content: ChatInputContent, _ range: (Int, Int)) throws -> (composed: ChatInputContent, typed: ChatInputContent) {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer {
            verifier.restore()
            _ = driver.node.resignInputFirstResponder()
        }
        let input = try XCTUnwrap(driver.view as? (UIView & UITextInput))
        HarnessComposerFuzzTests.arrange(driver, content)
        driver.setViewSelection(NSRange(location: range.0, length: range.1 - range.0))
        driver.settle(0.1)
        for step in FuzzIME.japanese.steps {
            input.setMarkedText(step.text, selectedRange: step.selected)
            driver.settle(0.03)
        }
        input.unmarkText()
        driver.settle(0.2)
        let composed = FuzzModel.normalized(driver.model())
        HarnessComposerFuzzTests.arrange(driver, content)
        driver.setViewSelection(NSRange(location: range.0, length: range.1 - range.0))
        driver.settle(0.1)
        driver.insert("漢字")
        driver.settle(0.2)
        return (composed, FuzzModel.normalized(driver.model()))
    }

    private func assertTypingMatchesComposing(_ content: ChatInputContent, _ range: (Int, Int), file: StaticString = #filePath, line: UInt = #line) throws {
        let result = try self.composedAndTyped(content, range)
        XCTAssertEqual(FuzzModel.describe(result.typed), FuzzModel.describe(result.composed), "typing and composing 漢字 over \(range) disagree", file: file, line: line)
    }

    func testTypingFromABoldRunIntoACaptionKeepsTheBold() throws {
        let content = ChatInputContent(blocks: [E.paragraph([E.run("ta"), ChatInputRun(text: "sk", attributes: Self.bold)]), Self.media([E.run("A caption")])])
        let result = try self.composedAndTyped(content, (2, 9))
        XCTAssertEqual(FuzzModel.describe(result.typed), "[p body \"ta\"+[b]\"\\u{6F22}\\u{5B57}\"] [media image x1 cap=\"caption\"]", "typing over a selection from bold text into a caption dropped the bold")
        XCTAssertEqual(FuzzModel.describe(result.typed), FuzzModel.describe(result.composed), "typing and composing disagree")
    }

    func testTypingIntoAStruckCaptionDoesNotStrikeTheText() throws {
        let content = ChatInputContent(blocks: [E.paragraph([E.run("task")]), Self.media([ChatInputRun(text: "A caption", attributes: Self.strike)])])
        let result = try self.composedAndTyped(content, (2, 9))
        XCTAssertEqual(FuzzModel.describe(result.typed), "[p body \"ta\\u{6F22}\\u{5B57}\"] [media image x1 cap=[s]\"caption\"]", "typing over a selection into a struck-through caption struck the typed text")
        XCTAssertEqual(FuzzModel.describe(result.typed), FuzzModel.describe(result.composed), "typing and composing disagree")
    }

    /// The other direction: from a caption, across the rest of the media unit, into the paragraph after.
    func testTypingFromABoldCaptionRunIntoTheNextParagraphMatchesComposing() throws {
        // "x\n\u{FFFC}\nTwo Bo z\ntail": "Bo" is 7..<9 in the caption, "tail" starts at 12.
        let content = ChatInputContent(blocks: [E.paragraph([E.run("x")]), Self.media([E.run("Two "), ChatInputRun(text: "Bo", attributes: Self.bold), E.run(" z")]), E.paragraph([E.run("tail")])])
        try self.assertTypingMatchesComposing(content, (8, 14))
    }

    func testTypingFromACaptionMentionIntoTheNextParagraphMatchesComposing() throws {
        let content = ChatInputContent(blocks: [E.paragraph([E.run("x")]), Self.media([E.run("Two "), E.mention("Bo"), E.run(" z")]), E.paragraph([E.run("tail")])])
        try self.assertTypingMatchesComposing(content, (8, 14))
    }

    func testControlTypingFromABoldRunIntoAParagraphKeepsTheBold() throws {
        try self.assertTypingMatchesComposing(ChatInputContent(blocks: [E.paragraph([E.run("ta"), ChatInputRun(text: "sk", attributes: Self.bold)]), E.paragraph([E.run("A caption")])]), (2, 7))
    }

    func testControlTypingIntoAStruckParagraph() throws {
        try self.assertTypingMatchesComposing(ChatInputContent(blocks: [E.paragraph([E.run("task")]), E.paragraph([ChatInputRun(text: "A caption", attributes: Self.strike)])]), (2, 7))
    }
}
