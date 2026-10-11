import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke (CORRUPTS THE SENT MODEL).** On the engine backend, an IME composition over a
/// selection that starts in RIGHT-TO-LEFT text of a LIST ITEM inside a BLOCK QUOTE and runs to the
/// quote's (empty) author line leaves the composition's FIRST candidate behind as committed text —
/// the romaji "k" of a Japanese composition, the jamo "ㅎ" of a Korean one — before the converted
/// text. Typing the final candidate over the same selection does not (the oracle).
///
///     [quote [• "twمرحبا "]], select "حبا ⏎" (4..<9, into the empty author line), compose k → … → 漢字
///       composed: [quote [• "twمرk漢字"]]
///       typed:    [quote [• "twمر漢字"]]
///     Hebrew the same; Korean leaves "ㅎ".
///     Controls (all behave): the same with Latin text; an Arabic PARAGRAPH (not an item) in the quote;
///     an Arabic item at the top level; the selection inside the item; the quote followed by a
///     paragraph the selection reaches.
///
/// **How it was seen.** p17 roam fuzz sweep, edited-content seeds 1-90, seed 77: the `compose` op's
/// typing oracle. Reduced by a greedy op reducer to 20 ops, then by a block-level reducer over the
/// content SET (it reproduces from a set) to the one quoted item.
///
/// **Suspected cause.** The composition's selection is resolved first
/// (`TGIDObservingBlockTextView tgid_resolveSelectionBeforeComposition`, p11) as the gate's cross-block
/// deletion; with the caret then at the end of an RTL run whose line is a quoted list item, the next
/// candidate's replacement range no longer covers the first candidate — either the caret the
/// resolution leaves (RTL affinity at the item's end) or the list-continuation reconciliation that the
/// deletion schedules (`performScheduledListContinuationReconciliation`, `+Lists.swift`) landing between
/// candidates and moving the marked range. Tell the two apart by logging `markedTextRange` per candidate.
///
/// **Tier 1**: `setMarkedText(_:selectedRange:)` / `unmarkText` are the keyboard's entry points. The
/// oracle is the fuzz's own `HarnessComposerFuzzTests.composeViolation` (compose, undo once, type the
/// final candidate over the same selection, compare the models).
@available(iOS 18.4, *)
final class HarnessCompositionAcrossQuoteEndTests: XCTestCase {
    private func compose(_ content: ChatInputContent, select range: NSRange, _ ime: FuzzIME = .japanese, _ commit: FuzzCommit = .unmark) throws -> String? {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer {
            verifier.restore()
            _ = driver.node.resignInputFirstResponder()
        }
        HarnessComposerFuzzTests.arrange(driver, content)
        driver.setViewSelection(range)
        driver.settle()
        let selected = (driver.viewText() as NSString).substring(with: range)
        return HarnessComposerFuzzTests.composeViolation(ime, commit, selecting: nil, on: driver).map { "selected \(fuzzEscaped(selected)): \($0)" }
    }

    private func quote(_ blocks: [ChatInputBlock]) -> ChatInputBlock {
        return .blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: blocks), collapsed: false))
    }

    private func item(_ text: String) -> ChatInputBlock {
        return HarnessP16.item(text)
    }

    private let arabic = "tw\u{645}\u{631}\u{62D}\u{628}\u{627} "
    private let hebrew = "tw\u{5E9}\u{5DC}\u{5D5}\u{5DD} "

    func testJapaneseFromAQuotedArabicItemIntoTheAuthorLine() throws {
        let content = ChatInputContent(blocks: [self.quote([self.item(self.arabic)])])
        XCTAssertNil(try self.compose(content, select: NSRange(location: 4, length: 5)))
    }

    func testKoreanFromAQuotedArabicItemIntoTheAuthorLine() throws {
        let content = ChatInputContent(blocks: [self.quote([self.item(self.arabic)])])
        XCTAssertNil(try self.compose(content, select: NSRange(location: 4, length: 5), .korean))
    }

    func testJapaneseFromAQuotedHebrewItemIntoTheAuthorLine() throws {
        let content = ChatInputContent(blocks: [self.quote([self.item(self.hebrew)])])
        XCTAssertNil(try self.compose(content, select: NSRange(location: 3, length: 5)))
    }

    // MARK: - Controls

    func testControlLatinQuotedItemIntoTheAuthorLine() throws {
        let content = ChatInputContent(blocks: [self.quote([self.item("hello world")])])
        XCTAssertNil(try self.compose(content, select: NSRange(location: 6, length: 6)))
    }

    func testControlArabicQuotedParagraphIntoTheAuthorLine() throws {
        let content = ChatInputContent(blocks: [self.quote([HarnessP16.paragraph(self.arabic)])])
        XCTAssertNil(try self.compose(content, select: NSRange(location: 4, length: 5)))
    }

    func testControlArabicTopLevelItemIntoAnEmptyParagraph() throws {
        let content = ChatInputContent(blocks: [self.item(self.arabic), HarnessP16.paragraph("")])
        XCTAssertNil(try self.compose(content, select: NSRange(location: 4, length: 5)))
    }

    func testControlArabicWithinTheQuotedItem() throws {
        let content = ChatInputContent(blocks: [self.quote([self.item(self.arabic)])])
        XCTAssertNil(try self.compose(content, select: NSRange(location: 4, length: 3)))
    }

    func testControlQuotedItemIntoTheParagraphAfter() throws {
        let content = ChatInputContent(blocks: [self.quote([self.item("hello world")]), HarnessP16.paragraph("after")])
        XCTAssertNil(try self.compose(content, select: NSRange(location: 6, length: 7)))
    }
}
