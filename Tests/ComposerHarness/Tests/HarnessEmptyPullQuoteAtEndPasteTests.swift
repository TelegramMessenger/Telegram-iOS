import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** On the engine backend, Select All → Copy → Paste over a document that ENDS in an
/// EMPTY pull quote (no author) or an EMPTY code block DUPLICATES that block. The copy carries it (the
/// twelfth wave's empty-container rule), but the paste does not replace it:
///
///     [p ""]  [pull "" author=""]   → [p ""]  [pull] [pull]
///     [p "a"] [pull "" author=""]   → [p "a"] [pull] [pull]
///     [p ""]  [code ""]             → [p ""]  [code] [code]
///     controls: the same pull quote WITH an author, a NON-empty pull quote and an empty BLOCK quote
///     round-trip (modulo the documented trailing line)
///
/// The message goes out with an extra empty pull quote or code block, and each further paste-back
/// adds another.
///
/// **How it was seen.** p18 fuzz sweep, default and edited content, seed 6: the end-of-sequence copy
/// → paste-back. Both tips reduced to `[p ""] [pull  author=]`.
///
/// **Cause.** Not Select All's range: that ends at the empty region's start, which is where the
/// document's last text position IS. `extractFragment` carries an empty code block / pull quote at the
/// document's end when a range ends exactly there (the twelfth wave's copy rule, which is right), and
/// `Document.replacingRange` took its complement's suffix from that same position, where the region
/// was covered AGAIN — so it was in both halves. **Fixed (2026-09-25)** in Core: `replacingRange`
/// measures its range with the copy's own rule (`carriedEmptyEndRegionStart`), so a range ending at a
/// carried empty region covers the rest of the document. Core pin:
/// `DocumentCarriedEmptyEndRegionReplaceTests`.
///
/// **Tier 1**: `selectAll:` / `copy:` / `paste:` on the engine view, as the edit menu sends them.
@available(iOS 18.4, *)
final class HarnessEmptyPullQuoteAtEndPasteTests: XCTestCase {
    private func roundTrip(_ start: ChatInputContent) throws -> (before: ChatInputContent, after: ChatInputContent) {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer {
            verifier.restore()
            _ = driver.node.resignInputFirstResponder()
        }
        HarnessComposerFuzzTests.perform(driver, start: start, ops: [])
        let before = FuzzModel.normalized(driver.model())
        _ = driver.view.perform(#selector(UIResponderStandardEditActions.selectAll(_:)), with: nil)
        driver.settle(0.1)
        _ = driver.view.perform(#selector(UIResponderStandardEditActions.copy(_:)), with: nil)
        driver.settle(0.1)
        _ = driver.view.perform(#selector(UIResponderStandardEditActions.paste(_:)), with: nil)
        driver.settle(0.3)
        let after = FuzzModel.normalized(driver.model())
        return (before, after)
    }

    private func assertRoundTrip(_ blocks: [ChatInputBlock], file: StaticString = #filePath, line: UInt = #line) throws {
        let result = try self.roundTrip(ChatInputContent(blocks: blocks))
        XCTAssertTrue(HarnessComposerFuzzTests.equalModuloTrailingLine(result.after, result.before),
                      "Select All → Copy → Paste changed the document:\n  before \(FuzzModel.describe(result.before))\n  after  \(FuzzModel.describe(result.after))",
                      file: file, line: line)
    }

    private static let emptyPull = ChatInputBlock.pullQuote(ChatInputPullQuote(runs: []))

    func testEmptyParagraphThenEmptyPullQuote() throws {
        try self.assertRoundTrip([HarnessEngine.paragraph(""), Self.emptyPull])
    }

    /// Control: with an author the range reaches the end.
    func testControlEmptyParagraphThenEmptyPullQuoteWithAuthor() throws {
        try self.assertRoundTrip([HarnessEngine.paragraph(""), .pullQuote(ChatInputPullQuote(runs: [], author: [ChatInputRun(text: "x")]))])
    }

    func testEmptyParagraphThenEmptyCode() throws {
        try self.assertRoundTrip([HarnessEngine.paragraph(""), .code(ChatInputCode(language: nil, runs: []))])
    }

    /// Control: a non-empty pull quote.
    func testControlEmptyParagraphThenNonEmptyPullQuote() throws {
        try self.assertRoundTrip([HarnessEngine.paragraph(""), .pullQuote(ChatInputPullQuote(runs: [ChatInputRun(text: "p")]))])
    }

    func testNonEmptyParagraphThenEmptyPullQuote() throws {
        try self.assertRoundTrip([HarnessEngine.paragraph("a"), Self.emptyPull])
    }

    /// Control: an empty block quote (its empty child paragraph is a block of its own).
    func testControlEmptyParagraphThenEmptyQuote() throws {
        try self.assertRoundTrip([HarnessEngine.paragraph(""), .blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: [HarnessEngine.paragraph("")]), collapsed: false))])
    }
}
