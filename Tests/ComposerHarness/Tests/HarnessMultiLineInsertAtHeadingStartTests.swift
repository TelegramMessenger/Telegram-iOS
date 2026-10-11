import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** On the engine backend, text that STARTS with a newline and arrives in one delivery —
/// dictation's "new line …" (`insertDictationResult`, which the engine hands to `insertText` whole), a
/// text replacement, a hardware keyboard's multi-character insert — at the START of a heading still
/// leaves an EMPTY heading above and demotes the heading's own text to body. That is findings row 36's
/// defect, fixed for a Return typed alone and not for the same newline arriving with text after it:
///
///     [h2 "Heading text"] [p "Body."], caret at 0
///       insertText("\nX") / dictation ["\n", "X"]:  [h2 ""] [p "XHeading text"] [p "Body."]
///       typing Return, then X:                      [p ""] [h2 "XHeading text"] [p "Body."]
///     the same for an h1 after a paragraph and for a heading inside a block quote.
///
/// **How it was seen.** p12 roam, 2026-09-24: dictation and multi-line inserts compared with typing the
/// same characters one at a time.
///
/// **Suspected cause.** The gate's heading-start rule (`decideReturnAtStartOfHeading`,
/// `RichTextEngineEditorView+SurfaceGate.swift`) is asked only for `text == "\n"` with an empty range;
/// any other text containing a newline is forwarded and the engine's split keeps the identity (and the
/// heading style) on the empty upper half, as before the row-36 fix.
///
/// **Tier 1**: `insertText(_:)` and `insertDictationResult(_:)` are the calls dictation and the keyboard
/// make; typing the characters one at a time is the oracle.
@available(iOS 18.4, *)
final class HarnessMultiLineInsertAtHeadingStartTests: XCTestCase {
    private func run(_ content: ChatInputContent, caret: Int, _ body: (EngineFuzzDriver, UIView & UITextInput) -> Void) throws -> String {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer {
            verifier.restore()
            _ = driver.node.resignInputFirstResponder()
        }
        driver.arrange(content)
        driver.setViewSelection(NSRange(location: caret, length: 0))
        driver.settle(0.1)
        XCTAssertEqual(driver.viewSelection(), NSRange(location: caret, length: 0), "precondition: the caret did not land")
        body(driver, try XCTUnwrap(driver.view as? (UIView & UITextInput)))
        driver.settle(0.3)
        return FuzzModel.describe(FuzzModel.normalized(driver.model()))
    }

    private let heading = ChatInputContent(blocks: [
        .paragraph(ChatInputParagraph(style: .heading2, list: nil, runs: [ChatInputRun(text: "Heading text")])),
        HarnessEngine.paragraph("Body."),
    ])

    private func typed(_ content: ChatInputContent, caret: Int) throws -> String {
        return try self.run(content, caret: caret) { driver, input in
            input.insertText("\n")
            driver.settle(0.05)
            input.insertText("X")
        }
    }

    func testANewlineAndTextInsertedAtAHeadingsStartKeepsItsTextAHeading() throws {
        let typed = try self.typed(self.heading, caret: 0)
        XCTAssertEqual(typed, "[p body ] [p heading2 \"XHeading text\"] [p body \"Body.\"]", "control: typing Return then X at the heading's start")
        let inserted = try self.run(self.heading, caret: 0) { _, input in input.insertText("\nX") }
        XCTAssertEqual(inserted, typed, "a newline inserted with text after it at the heading's start demoted the heading")
    }

    func testDictatingANewLineAtAHeadingsStartKeepsItsTextAHeading() throws {
        let typed = try self.typed(self.heading, caret: 0)
        let dictated = try self.run(self.heading, caret: 0) { _, input in
            let phrases = ["\n", "X"].map { text -> UIDictationPhrase in
                let phrase = UIDictationPhrase()
                phrase.setValue(text, forKey: "text")
                return phrase
            }
            input.insertDictationResult?(phrases)
        }
        XCTAssertEqual(dictated, typed, "dictating a new line at the heading's start demoted the heading")
    }

    /// The same delivery through the keyboard's replacement door (an empty range replaced with the
    /// text, as a text replacement does), and a text with a second newline after the first line.
    func testAnEmptyRangeReplacedWithANewlineAndTextKeepsItsTextAHeading() throws {
        let typed = try self.typed(self.heading, caret: 0)
        let replaced = try self.run(self.heading, caret: 0) { _, input in
            if let start = input.position(from: input.beginningOfDocument, offset: 0),
               let range = input.textRange(from: start, to: start) {
                input.replace(range, withText: "\nX")
            }
        }
        XCTAssertEqual(replaced, typed, "an empty-range replacement with a newline and text at the heading's start demoted the heading")
    }

    func testTwoLinesInsertedAtAHeadingsStartMatchTyping() throws {
        let typed = try self.run(self.heading, caret: 0) { driver, input in
            for character in ["\n", "X", "\n", "Y"] {
                input.insertText(character)
                driver.settle(0.05)
            }
        }
        let inserted = try self.run(self.heading, caret: 0) { _, input in input.insertText("\nX\nY") }
        XCTAssertEqual(inserted, typed, "a two-line insert at the heading's start did not do what typing it does")
    }

    func testInsideABlockQuote() throws {
        let quoted = ChatInputContent(blocks: [.blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: [
            HarnessEngine.paragraph("Intro"),
            .paragraph(ChatInputParagraph(style: .heading2, list: nil, runs: [ChatInputRun(text: "Quoted head")])),
        ]), collapsed: false))])
        let typed = try self.typed(quoted, caret: 6)
        let inserted = try self.run(quoted, caret: 6) { _, input in input.insertText("\nX") }
        XCTAssertEqual(inserted, typed, "a newline inserted with text after it at a quoted heading's start demoted the heading")
    }
}
