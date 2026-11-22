import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib

/// **What broke.** On the engine backend, a plain-text paste over a selection that runs from a
/// paragraph INTO a pull quote (top-level, or a block quote's child) destroys the pull quote: its
/// surviving text is merged into the pasted paragraph and, inside a quote, the quote is left with no
/// children at all — the model reads `[quote author=]` while the screen shows an empty line:
///
///     [p "l1"] [quote [p "l3"] [pull "The quick brown fox."]] → select 1..<17 → paste "xx\nyy"
///       engine: [p "l xx"] [p "yy rown fox."] [quote  author=]   (model and screen disagree)
///       expected: [p "l xx"] [p "yy"] [quote [pull "rown fox."]]
///     [p "l1"] [pull "The quick brown fox."] → select 1..<10 → paste "xx\nyy"
///       engine: [p "l xx"] [p "yy ck brown fox."]                (the pull quote is gone)
///     control: typing Return over the same selection keeps the pull quote
///
/// **How it was seen.** `HarnessComposerFuzzTests` (engine), 2026-09-23, seeds 2 and 18 (the fuzz's
/// model/engine projection check); reduced by replay to the paste.
///
/// **Cause.** UIKit's paste replaces the selection through its input controller's own text-storage
/// edit, which never reaches the surface gate's cross-block rule, so the engine merged the two ends
/// by identity. Fixed by deleting a cross-block selection through the gate before the engine's paste
/// (`deleteCrossBlockSelectionBeforeEnginePaste`, `+Clipboard.swift`).
///
/// **Tier 1**: `paste(_:)` on the engine view is what the edit menu calls; the pasteboard is this
/// process's own, written before it is read.
final class HarnessPasteOverCrossBlockSelectionTests: XCTestCase {
    private func paste(_ start: ChatInputContent, select: (Int, Int), _ op: FuzzOp) throws -> (model: ChatInputContent, engineText: String) {
        guard #available(iOS 18.4, *) else {
            throw XCTSkip("the engine editor needs iOS 18.4")
        }
        let driver = try EngineFuzzDriver()
        defer { _ = driver.node.resignInputFirstResponder() }
        HarnessComposerFuzzTests.perform(driver, start: start, ops: [.select(select.0, select.1), op])
        driver.settle(0.3)
        return (driver.model(), driver.viewText())
    }

    private static let quoted = ChatInputContent(blocks: [
        HarnessEngine.paragraph("l1"),
        .blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: [
            HarnessEngine.paragraph("l3"),
            .pullQuote(ChatInputPullQuote(runs: [ChatInputRun(text: "The quick brown fox.")])),
        ]), collapsed: false)),
    ])

    private static let topLevel = ChatInputContent(blocks: [
        HarnessEngine.paragraph("l1"),
        .pullQuote(ChatInputPullQuote(runs: [ChatInputRun(text: "The quick brown fox.")])),
    ])

    private static func pullQuoteText(in blocks: [ChatInputBlock]) -> String? {
        for block in blocks {
            switch block {
            case let .pullQuote(quote):
                return quote.text
            case let .blockQuote(quote):
                if let text = pullQuoteText(in: quote.content.blocks) {
                    return text
                }
            default:
                break
            }
        }
        return nil
    }

    func testAPasteFromAParagraphIntoAQuotedPullQuoteKeepsBoth() throws {
        let result = try self.paste(Self.quoted, select: (1, 17), .pasteText("xx\nyy"))
        XCTAssertNil(FuzzModel.engineAxisMismatch(result.model, engineText: result.engineText),
                     "the model and the screen disagree: \(FuzzModel.describe(result.model))")
        // 17 is 11 into the pull quote's text ("l1\nl3\n" is 6), after "The quick b".
        XCTAssertEqual(Self.pullQuoteText(in: result.model.blocks), "rown fox.",
                       "the pull quote did not survive the paste: \(FuzzModel.describe(result.model))")
        for block in result.model.blocks {
            if case let .blockQuote(quote) = block {
                XCTAssertFalse(quote.content.blocks.isEmpty, "a quote with no children: \(FuzzModel.describe(result.model))")
            }
        }
    }

    func testAPasteFromAParagraphIntoAPullQuoteKeepsThePullQuote() throws {
        let result = try self.paste(Self.topLevel, select: (1, 10), .pasteText("xx\nyy"))
        XCTAssertNil(FuzzModel.engineAxisMismatch(result.model, engineText: result.engineText),
                     "the model and the screen disagree: \(FuzzModel.describe(result.model))")
        XCTAssertEqual(Self.pullQuoteText(in: result.model.blocks), "ck brown fox.",
                       "the pull quote did not survive the paste: \(FuzzModel.describe(result.model))")
    }

    /// Control: Return over the same selection keeps the pull quote and adds no empty line.
    func testControlReturnOverTheSameSelection() throws {
        let result = try self.paste(Self.topLevel, select: (1, 10), .insert("\n"))
        XCTAssertEqual(FuzzModel.normalized(result.model).blocks.count, 2,
                       "control: Return over paragraph→pull quote: \(FuzzModel.describe(result.model))")
        XCTAssertEqual(Self.pullQuoteText(in: result.model.blocks), "ck brown fox.")
    }
}
