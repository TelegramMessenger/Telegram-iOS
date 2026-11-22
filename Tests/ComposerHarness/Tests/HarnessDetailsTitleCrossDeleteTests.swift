import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** On the engine backend, deleting (Backspace, Cut) or typing over a selection that
/// runs from a paragraph INTO a details block's TITLE removes the title line from the editor but not
/// from the model. The engine is left with a details body and no title line above it, while the model
/// has `[details title="" …]`. A details block always has exactly one title line (R7-details).
///
///     [p "tails:"] [details title "Summary" [p "body"]], select "ils:\nSum" (2..<10), Backspace
///       model  [p "tamary"] [details title="" [p "body"]]
///       engine "tamary" / "body"   ← no title line
///     inside a block quote (with or without an author), and Cut or typed "X" instead of Backspace:
///       the same
///     controls: the same selection over three plain paragraphs merges cleanly; a selection that
///       reaches into the details BODY (2..<17) dissolves the details, and model and engine agree
///
/// **How it was seen.** `HarnessComposerFuzzTests` with the extended op mix (a details starting
/// document), 2026-09-23, seed 21 (step 23 `.cut` over 38..<60, from a quoted paragraph into the title
/// of a details inside the quote; reported as an engine-axis mismatch); reduced by probe.
///
/// **Suspected cause.** The gate's cross-block rule (`replaceAcrossBlocks`, `+SurfaceGate.swift`)
/// treats the title as a leaf covered in part and merges its remainder into the survivor paragraph.
/// Nothing then re-mints the title line. Settle does that for a code body left without its language
/// line (`+Settle.swift`), and it does not do it for a details body left without its title.
///
/// **Tier 1**: `deleteBackward` / `cut:` / `insertText` on the engine view.
@available(iOS 18.4, *)
final class HarnessDetailsTitleCrossDeleteTests: XCTestCase {
    private static func details(_ title: String, _ body: String) -> ChatInputBlock {
        return .details(ChatInputDetails(content: ChatInputContent(blocks: [HarnessEngine.paragraph(body)]), title: [ChatInputRun(text: title)], expanded: true))
    }

    private static func quoted(_ blocks: [ChatInputBlock], author: String = "") -> ChatInputContent {
        return ChatInputContent(blocks: [.blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: blocks), collapsed: false, author: author.isEmpty ? [] : [ChatInputRun(text: author)]))])
    }

    private func mismatch(_ start: ChatInputContent, _ ops: [FuzzOp]) throws -> String? {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer {
            verifier.restore()
            _ = driver.node.resignInputFirstResponder()
        }
        HarnessComposerFuzzTests.perform(driver, start: start, ops: ops)
        return FuzzModel.engineAxisMismatch(driver.model(), engineText: driver.viewText())
    }

    func testBackspaceFromAParagraphIntoADetailsTitleKeepsTheTitleLine() throws {
        XCTAssertNil(try self.mismatch(ChatInputContent(blocks: [HarnessEngine.paragraph("tails:"), Self.details("Summary", "body")]), [.select(2, 10), .deleteBackward]))
    }

    func testBackspaceInsideAQuoteKeepsTheTitleLine() throws {
        XCTAssertNil(try self.mismatch(Self.quoted([HarnessEngine.paragraph("tails:"), Self.details("Summary", "body")]), [.select(2, 10), .deleteBackward]))
    }

    func testBackspaceInsideAnAuthoredQuoteKeepsTheTitleLine() throws {
        XCTAssertNil(try self.mismatch(Self.quoted([HarnessEngine.paragraph("tails:"), Self.details("Summary", "body")], author: "Ann"), [.select(2, 10), .deleteBackward]))
    }

    func testCutKeepsTheTitleLine() throws {
        XCTAssertNil(try self.mismatch(Self.quoted([HarnessEngine.paragraph("tails:"), Self.details("Summary", "body")]), [.select(2, 10), .cut]))
    }

    func testTypingOverKeepsTheTitleLine() throws {
        XCTAssertNil(try self.mismatch(Self.quoted([HarnessEngine.paragraph("tails:"), Self.details("Summary", "body")]), [.select(2, 10), .insert("X")]))
    }

    /// Control: the same selection over plain paragraphs.
    func testControlPlainParagraphs() throws {
        XCTAssertNil(try self.mismatch(Self.quoted([HarnessEngine.paragraph("tails:"), HarnessEngine.paragraph("Summary"), HarnessEngine.paragraph("body")]), [.select(2, 10), .deleteBackward]))
    }

    /// Control: a selection reaching into the details BODY dissolves the details cleanly.
    func testControlIntoTheDetailsBody() throws {
        XCTAssertNil(try self.mismatch(Self.quoted([HarnessEngine.paragraph("tails:"), Self.details("Summary", "body")]), [.select(2, 17), .deleteBackward]))
    }

    /// A range from a paragraph through an OUTER details' title and first body child into a NESTED
    /// details' title (twelfth wave, fuzz seed 38, reduced). The nested title truncates; the outer
    /// details, whose title the range took, dissolves — before, the model kept an outer details with
    /// an empty title that had no line in the engine.
    ///     engine: "tails:" 0..<6, "Outer" 7..<12, "in" 13..<15, "Summary" 16..<23, "body" 24..<28
    func testBackspaceThroughAnOuterTitleIntoANestedTitleKeepsModelAndEngineTogether() throws {
        let nested = ChatInputBlock.details(ChatInputDetails(content: ChatInputContent(blocks: [HarnessEngine.paragraph("in"), Self.details("Summary", "body")]), title: [ChatInputRun(text: "Outer")], expanded: true))
        XCTAssertNil(try self.mismatch(ChatInputContent(blocks: [HarnessEngine.paragraph("tails:"), nested]), [.select(2, 19), .deleteBackward]))
    }

    /// Control's sibling: a range from a paragraph into the body of a details whose body has TWO
    /// paragraphs. The title goes, the details dissolves, the second paragraph stays.
    ///     engine: "tails:" 0..<6, "Summary" 7..<14, "one" 15..<18, "two" 19..<22
    func testBackspaceIntoATwoParagraphBodyKeepsModelAndEngineTogether() throws {
        let details = ChatInputBlock.details(ChatInputDetails(content: ChatInputContent(blocks: [HarnessEngine.paragraph("one"), HarnessEngine.paragraph("two")]), title: [ChatInputRun(text: "Summary")], expanded: true))
        XCTAssertNil(try self.mismatch(ChatInputContent(blocks: [HarnessEngine.paragraph("tails:"), details]), [.select(2, 17), .deleteBackward]))
    }
}
