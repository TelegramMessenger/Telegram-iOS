import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** On the engine backend, a replacement from a top-level pull quote's AUTHOR line into
/// the author line of a pull quote nested in a block quote left the block quote with NO children:
/// the model read `[quote author=]` while the screen showed an empty line.
///
///     [pull "\t?" author "#abc"] [p ""] [quote [pull "" author "q"]] → select 4..<11 ("abc" … "q")
///     → type "Z"
///       engine: [pull "\t?" author "#Z"] [quote  author=]    (model and screen disagree)
///     control: a replacement from a paragraph into a quoted pull quote removes the quote cleanly
///
/// **How it was seen.** `HarnessComposerFuzzTests` (engine), 2026-09-23, seed 18 (the model/engine
/// projection check); reduced by replay and then by hand.
///
/// **Cause.** Settle's orphan rule (`settleOrphanedSecondaryLines`, `+Settle.swift`) ran one pass: it
/// removed the inner pull quote's orphaned author line, and that line was what had kept the quote
/// holding a child when the pass asked about the quote's own author line. Fixed by repeating the
/// pass until nothing is orphaned.
///
/// **Tier 1**: selection and typing are the UITextInput calls the keyboard makes.
@available(iOS 18.4, *)
final class HarnessNestedOrphanedLineTests: XCTestCase {
    private func replace(_ start: ChatInputContent, select: (Int, Int)) throws -> (model: ChatInputContent, engineText: String) {
        let driver = try EngineFuzzDriver()
        defer { _ = driver.node.resignInputFirstResponder() }
        HarnessComposerFuzzTests.perform(driver, start: start, ops: [.select(select.0, select.1), .insert("Z")])
        return (driver.model(), driver.viewText())
    }

    func testAReplacementIntoAQuotedPullQuotesAuthorLeavesNoEmptyQuote() throws {
        let start = ChatInputContent(blocks: [
            .pullQuote(ChatInputPullQuote(runs: [ChatInputRun(text: "\t?")], author: [ChatInputRun(text: "#abc")])),
            HarnessEngine.paragraph(""),
            .blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: [
                .pullQuote(ChatInputPullQuote(runs: [], author: [ChatInputRun(text: "q")])),
            ]), collapsed: false)),
        ])
        let result = try self.replace(start, select: (4, 11))
        XCTAssertNil(FuzzModel.engineAxisMismatch(result.model, engineText: result.engineText),
                     "the model and the screen disagree: \(FuzzModel.describe(result.model))")
        for block in result.model.blocks {
            if case let .blockQuote(quote) = block {
                XCTAssertFalse(quote.content.blocks.isEmpty, "a quote with no children: \(FuzzModel.describe(result.model))")
            }
        }
    }

    /// Control: from a paragraph into a quoted pull quote.
    func testControlFromAParagraph() throws {
        let start = ChatInputContent(blocks: [
            HarnessEngine.paragraph("First"),
            .blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: [
                .pullQuote(ChatInputPullQuote(runs: [ChatInputRun(text: "pq")])),
            ]), collapsed: false)),
        ])
        let result = try self.replace(start, select: (2, 8))
        XCTAssertNil(FuzzModel.engineAxisMismatch(result.model, engineText: result.engineText))
        XCTAssertEqual(FuzzModel.describe(result.model), FuzzModel.describe(ChatInputContent(blocks: [HarnessEngine.paragraph("FiZ")])))
    }
}
