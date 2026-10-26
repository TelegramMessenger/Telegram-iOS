import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** On the engine backend, the copy loses a DETAILS block, or its title text, when the
/// block is at the document's end or the selection only enters its title:
///
///     [p "a"] [details "T" [p "body"]] → Select All → Copy → Paste → [p "a"]   ← the details is gone
///     the same with an empty body → [p "a"]
///     [p "a"] [details "Title" …], copy "a\nTitl" (0..<5), paste at 1 → [p "aa"] [details …]:
///       only "a" was copied, and the title text entered by the selection is lost
///     control: a details block BETWEEN two paragraphs survives Select All → Copy → Paste
///
/// **How it was seen.** `HarnessComposerFuzzTests` with the extended op mix (details starting
/// document), 2026-09-23, seed 215: the end-of-sequence copy → paste-back lost the trailing
/// `[details title=… [p body ]]`. Reduced by probe.
///
/// **Suspected cause.** `Document.extractFragment` (`+Clipboard.swift`'s `writeSelectionToPasteboard()`)
/// keeps a details block only when the selection covers its whole span, closing edge included, which a
/// selection ending at the document's end does not reach. A selection that only enters the title keeps
/// nothing of it. The eighth wave fixed the same shape for block quotes (`HarnessQuoteCopyTests`).
///
/// **Tier 1**: `selectAll:` / `copy:` / `paste:` on the engine view.
///
/// **Changed 2026-09-23 (twelfth wave), with the controller's approval, for two wrong assertions:**
/// the at-the-end cases compared the round trip for strict equality, but a paste whose content ends
/// in a non-body block at the document's end adds EXACTLY ONE trailing empty body paragraph with the
/// caret in it — a documented product rule (RichTextEditor `CLAUDE.md`, "The caret goes after
/// everything inserted, and the document grows a line if it must", 2026-09-17), the shape
/// `HarnessContainerCutPasteRoundTripTests` pins. They now assert that shape exactly: the original
/// blocks intact, one empty trailing line, the caret in it — a second line or a changed block still
/// fails. And the title case selected `0..<5`, which is "a\nTit", while asserting "Titl" was copied:
/// an off-by-one; it selects `0..<6` now.
@available(iOS 18.4, *)
final class HarnessDetailsCopyPasteTests: XCTestCase {
    private static func details(_ title: String, _ body: String) -> ChatInputBlock {
        return .details(ChatInputDetails(content: ChatInputContent(blocks: [HarnessEngine.paragraph(body)]), title: [ChatInputRun(text: title)], expanded: true))
    }

    private func selectAllCopyPaste(_ start: ChatInputContent) throws -> (before: String, after: String, afterBlocks: [ChatInputBlock], caretAtEnd: Bool) {
        let driver = try EngineFuzzDriver()
        defer { _ = driver.node.resignInputFirstResponder() }
        HarnessComposerFuzzTests.perform(driver, start: start, ops: [])
        let before = FuzzModel.describe(FuzzModel.normalized(driver.model()))
        _ = driver.view.perform(#selector(UIResponderStandardEditActions.selectAll(_:)), with: nil)
        driver.settle(0.1)
        HarnessComposerFuzzTests.execute(.copy, on: driver)
        driver.settle(0.1)
        HarnessComposerFuzzTests.execute(.paste, on: driver)
        driver.settle(0.3)
        let after = FuzzModel.normalized(driver.model())
        let caretAtEnd = driver.viewSelection() == NSRange(location: (driver.viewText() as NSString).length, length: 0)
        return (before, FuzzModel.describe(after), after.blocks, caretAtEnd)
    }

    /// The round trip of a document ENDING in a details: its blocks intact, then exactly one empty
    /// body paragraph (the documented trailing line), with the caret in it.
    private func assertIntactWithOneTrailingLine(_ start: ChatInputContent, file: StaticString = #filePath, line: UInt = #line) throws {
        let result = try self.selectAllCopyPaste(start)
        let kept = FuzzModel.describe(FuzzModel.normalized(ChatInputContent(blocks: Array(result.afterBlocks.dropLast()))))
        XCTAssertEqual(kept, result.before, "the original blocks did not survive the round trip: \(result.after)", file: file, line: line)
        guard case let .paragraph(trailing)? = result.afterBlocks.last else {
            return XCTFail("no trailing line after the pasted details: \(result.after)", file: file, line: line)
        }
        XCTAssertEqual(trailing.style, .body, "the trailing line is not a body paragraph: \(result.after)", file: file, line: line)
        XCTAssertTrue(trailing.runs.allSatisfy { $0.text.isEmpty }, "the trailing line is not empty: \(result.after)", file: file, line: line)
        XCTAssertTrue(result.caretAtEnd, "the caret is not in the trailing line: \(result.after)", file: file, line: line)
    }

    func testADetailsBlockAtTheEndSurvivesCopyPaste() throws {
        try self.assertIntactWithOneTrailingLine(ChatInputContent(blocks: [HarnessEngine.paragraph("a"), Self.details("T", "body")]))
    }

    func testADetailsBlockWithAnEmptyBodyAtTheEndSurvivesCopyPaste() throws {
        try self.assertIntactWithOneTrailingLine(ChatInputContent(blocks: [HarnessEngine.paragraph("a"), Self.details("T", "")]))
    }

    func testCopyingIntoADetailsTitleKeepsTheTitleText() throws {
        let driver = try EngineFuzzDriver()
        defer { _ = driver.node.resignInputFirstResponder() }
        HarnessComposerFuzzTests.perform(driver, start: ChatInputContent(blocks: [HarnessEngine.paragraph("a"), Self.details("Title", "body")]),
                                         // Engine axis: "a" is 0, its separator 1, the title "Title" 2..<7,
                                         // so 0..<6 is "a\nTitl" (the original 0..<5 stopped at "Tit").
                                         ops: [.select(0, 6), .copy, .select(1, 1), .paste])
        // "Titl" appears once in the details title; the paste must add a second copy somewhere.
        let described = FuzzModel.describe(driver.model())
        XCTAssertGreaterThanOrEqual(described.components(separatedBy: "Titl").count - 1, 2,
                      "the copied title text was lost: \(FuzzModel.describe(driver.model()))")
    }

    /// Control: a details block between two paragraphs.
    func testControlADetailsBlockBetweenParagraphs() throws {
        let result = try self.selectAllCopyPaste(ChatInputContent(blocks: [HarnessEngine.paragraph("a"), Self.details("T", "body"), HarnessEngine.paragraph("b")]))
        XCTAssertEqual(result.after, result.before)
    }
}
