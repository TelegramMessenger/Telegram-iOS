import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** On the engine backend, typing, Backspace, Cut or Paste over a selection that covers a
/// whole TABLE and ends at (or inside) the first line of a following CODE block or DETAILS block — the
/// code block's language line, the details' title — splits the model from the engine. The engine
/// collapses the table to ONE line holding the replacement; the model keeps a table of the same shape,
/// the replacement in its first cell and every other cell empty:
///
///     [p "Top"] [table (a1 | b1) (a2 | b2)] [details title="Title" [p "body"]]
///     select from the start of "a1" to the start of "Title" (4..<16), type "X"
///       engine: "Top\nX\nTitle\nbody"
///       model:  [p "Top"] [table ("X" | ) ( | )] [details title="Title" [p "body"]]
///     the same with a code block after the table; and to 17 (into the title / language line)
///
/// What is sent is the model (a table), not what the user sees (a line of text), and every later edit
/// works on two different documents. The same selection ending in a paragraph or a block quote drops
/// the table as the gate's rule says (a container wholly inside the range is dropped), and a selection
/// ending exactly at the table's last cell does too (controls).
///
/// **How it was seen.** p15 (2026-09-24), the edited-content fuzz with the external-push op, seed 33: a
/// plain-text paste over (8, 18) of the mixed edited document — its table wholly selected up to the
/// details title after it — failed the engine-axis invariant.
///
/// **Suspected cause.** The surface gate's cross-block rule (`applyReplaceOutcome`,
/// `RichTextEngineEditorView+SurfaceGate.swift`): with the END endpoint on a container's first line when
/// that line is a secondary region (a code block's language line, a details' title), the end block does
/// not resolve to a survivor, and the start block — the first table CELL — is taken as the survivor,
/// keeping the table's role on the merged engine block while the other cells' engine blocks are
/// deleted. The roles and the engine then disagree about the table's cells.
///
/// **Tier 1**: the view's `insertText` / `deleteBackward` / `cut:` / `paste:` over a view selection.
@available(iOS 18.4, *)
final class HarnessWholeTableEditIntoSecondaryLineTests: XCTestCase {
    private static func cell(_ text: String) -> ChatInputTableCell {
        return ChatInputTableCell(runs: [ChatInputRun(text: text)])
    }

    private static func document(then next: ChatInputBlock) -> ChatInputContent {
        return ChatInputContent(blocks: [
            HarnessEngine.paragraph("Top"),
            .table(ChatInputTable(columns: [ChatInputColumnSpec(width: 0.0), ChatInputColumnSpec(width: 0.0)], rows: [
                ChatInputTableRow(cells: [Self.cell("a1"), Self.cell("b1")]),
                ChatInputTableRow(cells: [Self.cell("a2"), Self.cell("b2")]),
            ])),
            next,
        ])
    }

    private static let details = ChatInputBlock.details(ChatInputDetails(content: ChatInputContent(blocks: [HarnessEngine.paragraph("body")]), title: [ChatInputRun(text: "Title")], expanded: true))
    private static let code = ChatInputBlock.code(ChatInputCode(language: nil, runs: [ChatInputRun(text: "let x")]))

    // "Top\na1\nb1\na2\nb2\n…": the table's cells are 4..<15; the next block's first line starts at 16.

    /// nil when every op over the range leaves the model and the engine agreeing and the table dropped.
    private func problems(_ next: ChatInputBlock, _ range: (Int, Int)) throws -> [String] {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer {
            verifier.restore()
            _ = driver.node.resignInputFirstResponder()
        }
        var result: [String] = []
        for op in [FuzzOp.insert("X"), .deleteBackward, .cut, .pasteText("one")] {
            HarnessComposerFuzzTests.perform(driver, start: Self.document(then: next), ops: [.select(range.0, range.1), op])
            let model = driver.model()
            let hasTable = model.blocks.contains { if case .table = $0 { return true }; return false }
            if let mismatch = FuzzModel.engineAxisMismatch(model, engineText: driver.viewText()) {
                result.append("\(op) over \(range): \(mismatch); model \(FuzzModel.describe(model))")
            } else if hasTable {
                result.append("\(op) over \(range) kept the wholly selected table: \(FuzzModel.describe(model))")
            }
        }
        return result
    }

    func testAnEditFromATableToADetailsTitleKeepsModelAndEngineTogether() throws {
        let found = try self.problems(Self.details, (4, 16))
        XCTAssertEqual(found, [], found.joined(separator: "\n"))
    }

    func testAnEditFromATableIntoADetailsTitleKeepsModelAndEngineTogether() throws {
        let found = try self.problems(Self.details, (4, 17))
        XCTAssertEqual(found, [], found.joined(separator: "\n"))
    }

    func testAnEditFromATableToACodeLanguageLineKeepsModelAndEngineTogether() throws {
        let found = try self.problems(Self.code, (4, 16))
        XCTAssertEqual(found, [], found.joined(separator: "\n"))
    }

    func testControlAnEditFromATableIntoAParagraphDropsTheTable() throws {
        let found = try self.problems(HarnessEngine.paragraph("After"), (4, 16)) + (try self.problems(HarnessEngine.paragraph("After"), (4, 17)))
        XCTAssertEqual(found, [], found.joined(separator: "\n"))
    }

    func testControlAnEditFromATableIntoABlockQuoteDropsTheTable() throws {
        let quote = ChatInputBlock.blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: [HarnessEngine.paragraph("q")]), collapsed: false))
        let found = try self.problems(quote, (4, 16))
        XCTAssertEqual(found, [], found.joined(separator: "\n"))
    }

    func testControlAnEditOverExactlyTheTableDropsIt() throws {
        let found = try self.problems(Self.details, (4, 15)) + (try self.problems(Self.code, (4, 15)))
        XCTAssertEqual(found, [], found.joined(separator: "\n"))
    }
}
