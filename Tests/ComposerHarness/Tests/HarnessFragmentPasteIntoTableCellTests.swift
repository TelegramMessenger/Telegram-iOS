import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke (CORRUPTS THE SENT MODEL).** Pasting the editor's OWN clipboard (anything copied or cut in
/// the composer) with the caret in a TABLE CELL deletes the whole table and puts the pasted blocks in its
/// place.
///
///     [p "Top"] [table ("a" | "b")] [p "one"]      engine "Top\na\nb\none"
///     select "one" (8..<11), Copy, caret at the end of cell "a" (5), Paste
///       got      [p "Top"] [p "one"] [p "one"]                 — the table is gone
///       expected [p "Top"] [table ("aone" | "b")] [p "one"]    (a cell holds one line of runs, as a
///                                                               caption or a details title does)
///
/// And because a copy of ANY range inside a cell takes the whole table (an endpoint inside a table
/// "takes the whole block", `Document.expandingRangeOverNonTextBlocks` — the rule a caption was given an
/// exception from in p13), copying one word from a cell and pasting it into another table's cell REPLACES
/// that other table with a copy of the first: `[table ("a" | pill)] [p "x"] [table ("c" | "d")]`, copy
/// "a", paste after "c" → `[table (a|pill)] [p x] [table (a|pill)] [p ""]`; "c" and "d" are gone.
///
/// Controls: a plain-text paste at the same caret types into the cell, and the same fragment pasted into
/// a paragraph splices inline.
///
/// **How it was seen.** p19 roam, 2026-09-25: the fuzz's new local-move op reported moves into a cell
/// losing atoms (edited-content seeds 56, 57, 67); reducing them showed Copy + Paste to the same caret
/// does the same. The fuzz's per-step invariants cannot see it: the table is gone from the model AND the
/// engine, consistently.
///
/// **Suspected cause.** `pasteFragment(from:)` (`RichTextEngineEditorView+Clipboard.swift`) →
/// `Document.replacingRange` / `replacingRangeInsideOneContainer` (Core, `DocumentFragment.swift`) has
/// arms for a range inside one code block, pull quote, block quote, details and caption, and none for a
/// table cell; the general complement path then takes the collapsed range as reaching the table's
/// span. The copy side is `writeSelectionToPasteboard()`'s expansion, which has no one-cell text rule.
///
/// **Tier 1**: `copy:` / `paste:` on the engine view.
@available(iOS 18.4, *)
final class HarnessFragmentPasteIntoTableCellTests: XCTestCase {
    private typealias E = HarnessEdited

    private func table(_ rows: [[[ChatInputRun]]]) -> ChatInputBlock {
        return .table(ChatInputTable(columns: rows[0].map { _ in ChatInputColumnSpec(width: 0.0) }, rows: rows.map { ChatInputTableRow(cells: $0.map { ChatInputTableCell(runs: $0) }) }))
    }

    private func tables(_ content: ChatInputContent) -> [String] {
        return content.blocks.compactMap { block -> String? in
            guard case let .table(table) = block else { return nil }
            return table.rows.map { $0.cells.map { $0.runs.map(\.text).joined() }.joined(separator: "|") }.joined(separator: "/")
        }
    }

    private func run(_ start: ChatInputContent, _ ops: [FuzzOp]) throws -> ChatInputContent {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer { verifier.restore(); _ = driver.node.resignInputFirstResponder() }
        HarnessComposerFuzzTests.perform(driver, start: start, ops: ops)
        return FuzzModel.normalized(driver.model())
    }

    private var oneTable: ChatInputContent {
        return ChatInputContent(blocks: [E.paragraph([E.run("Top")]), self.table([[[E.run("a")], [E.run("b")]]]), E.paragraph([E.run("one")])])
    }

    func testPastingACopiedParagraphIntoACellKeepsTheTable() throws {
        let got = try self.run(self.oneTable, [.select(8, 11), .copy, .select(5, 5), .paste])
        XCTAssertEqual(self.tables(got), ["aone|b"], "the paste into the cell: \(E.describe(got))")
    }

    func testPastingOneCellsCopyIntoAnotherTablesCellKeepsThatTable() throws {
        let start = ChatInputContent(blocks: [self.table([[[E.run("a")], [E.pill("P")]]]), E.paragraph([E.run("x")]), self.table([[[E.run("c")], [E.run("d")]]])])
        // "a\n\u{FFFC}\nx\nc\nd": copy "a" (0..<1), paste after "c" (7).
        let got = try self.run(start, [.select(0, 1), .copy, .select(7, 7), .paste])
        XCTAssertEqual(self.tables(got).count, 2, E.describe(got))
        XCTAssertEqual(self.tables(got).last, "ca|d", "the second table after pasting a word copied from the first: \(E.describe(got))")
    }

    // Controls.

    func testControlAPlainTextPasteIntoACellTypesIntoIt() throws {
        let got = try self.run(self.oneTable, [.select(5, 5), .pasteText("zz")])
        // UIKit's smart insert adds the space a stock text view adds too ("a zz").
        XCTAssertEqual(self.tables(got).count, 1, E.describe(got))
        XCTAssertTrue(self.tables(got).first?.hasPrefix("a") == true && self.tables(got).first?.contains("zz|b") == true, E.describe(got))
    }

    func testControlTheSameFragmentPastedIntoAParagraphSplicesInline() throws {
        let got = try self.run(self.oneTable, [.select(8, 11), .copy, .select(2, 2), .paste])
        XCTAssertEqual(self.tables(got), ["a|b"], E.describe(got))
        XCTAssertEqual(got.blocks.count, 3, E.describe(got))
    }
}
