import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib

/// **What broke.** On the engine backend, Return typed over a selection that spans TWO blocks inserts
/// a soft line break (`U+2028`, read back as a `"\n"` inside one paragraph's run) instead of a
/// paragraph break: the result is one paragraph where Return inside a paragraph gives two.
///
///     [p "First paragraph."] [p "Second paragraph."] → select 2..<20 → Return
///       engine: [p "Fi\nond paragraph."]           (one paragraph, engine text "Fi\u{2028}ond…")
///       legacy: [p "Fi"] [p "ond paragraph."]
///     paragraph → quote: [p "In\next here."]; paragraph → code: [p "Co\n"] [code …]
///     control, a selection inside one paragraph (2..<5): [p "Fi"] [p " paragraph."] …
///
/// The flat text is the same, so a sent message looks alike; but the structure is not what the user
/// typed (a later Quote / list / heading on either line takes both, and Backspace at the second
/// line's start does not join paragraphs).
///
/// **How it was seen.** `HarnessComposerFuzzTests` (engine), 2026-09-23, seed 6 (the model/engine
/// projection had to learn that the bridge maps `"\n"` to `U+2028` inside every block, which is how
/// this surfaced); reduced by replay.
///
/// **Suspected cause.** The surface gate's cross-block replacement (`applyReplaceOutcome` port,
/// `+SurfaceGate.swift`) inserts the replacement text into the survivor through `engineText`, which
/// maps every `"\n"` to a line separator; a Return is meant to be the paragraph split the gate
/// applies for a collapsed caret.
///
/// **Tier 1**: `insertText("\n")` on the engine view is what the Return key sends.
final class HarnessReturnOverCrossBlockSelectionTests: XCTestCase {
    private func engineBlocks(_ start: ChatInputContent, select: (Int, Int)) throws -> [ChatInputBlock] {
        guard #available(iOS 18.4, *) else {
            throw XCTSkip("the engine editor needs iOS 18.4")
        }
        let driver = try EngineFuzzDriver()
        defer { _ = driver.node.resignInputFirstResponder() }
        HarnessComposerFuzzTests.perform(driver, start: start, ops: [.select(select.0, select.1), .insert("\n")])
        return FuzzModel.normalized(driver.model()).blocks
    }

    private static let two = HarnessContent.plainText("First paragraph.\nSecond paragraph.")

    func testReturnOverASelectionAcrossTwoParagraphsSplitsThem() throws {
        let blocks = try self.engineBlocks(Self.two, select: (2, 20))
        XCTAssertEqual(blocks, [HarnessEngine.paragraph("Fi"), HarnessEngine.paragraph("ond paragraph.")],
                       "Return over a two-paragraph selection did not leave two paragraphs: \(FuzzModel.describe(ChatInputContent(blocks: blocks)))")
    }

    func testReturnOverASelectionFromAParagraphIntoAQuoteSplits() throws {
        let start = ChatInputContent(blocks: [
            HarnessEngine.paragraph("Intro line."),
            .blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: [HarnessEngine.paragraph("Quoted text here.")]), collapsed: false)),
        ])
        let blocks = try self.engineBlocks(start, select: (2, 20))
        XCTAssertEqual(blocks.count, 2, "Return over a paragraph→quote selection left one block: \(FuzzModel.describe(ChatInputContent(blocks: blocks)))")
    }

    /// Control: Return over a selection inside one paragraph splits it.
    func testControlReturnOverASelectionInsideOneParagraph() throws {
        let blocks = try self.engineBlocks(Self.two, select: (2, 5))
        XCTAssertEqual(blocks, [HarnessEngine.paragraph("Fi"), HarnessEngine.paragraph(" paragraph."), HarnessEngine.paragraph("Second paragraph.")],
                       "control: Return inside one paragraph did not split it")
    }

    /// Oracle: legacy splits a two-paragraph selection replaced by Return into two paragraphs.
    func testOracleLegacySplits() throws {
        var arranged: HarnessLegacy.Arranged?
        defer { HarnessLegacy.restore(arranged) }
        let value = try HarnessLegacy.arrange(Self.two)
        arranged = value
        HarnessLegacy.select(value, NSRange(location: 2, length: 18))
        value.textView.insertText("\n")
        HarnessEngine.settle(value.root)
        XCTAssertEqual(FuzzModel.normalized(HarnessLegacy.content(value)).blocks,
                       [HarnessEngine.paragraph("Fi"), HarnessEngine.paragraph("ond paragraph.")], "oracle: legacy did not split")
    }
}
