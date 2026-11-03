import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** On the engine backend, a PASTE over a selection that covers a TABLE only in part
/// (from a cell out into the paragraph after the table, or from a paragraph into a cell) wrecks the
/// table. The same selection refuses typed text, which is the gate's rule ("a range with an endpoint
/// inside a table it covers only in part is refused").
///
///     [p "Intro"] [table x y z / 1 2 3] [p "after"], select from the start of cell "y" to after "af"
///     (8..<20 on the engine axis)
///       paste plain "plain"    → model [table ("x" | "plain ter" |  ) ( |  |  )]; the engine has only
///                                "Intro", "x", "plain ter": four cells are gone from the screen but
///                                not from the model, and the paragraph "after" is swallowed
///       paste markdown ``` fence, or "l1\nl2" → the same
///       paste the editor's own copy ("Int") → [p "Intro"] [p "Intter"]: the whole table is gone
///     select from "tro" into cell "y" (2..<9), paste "plain" → model [p "In plain"]
///       [table ( |  | "z") …]; the engine drops the emptied cells
///     control: typing "X" over the same 8..<20 is refused, and nothing changes
///
/// **How it was seen.** `HarnessComposerFuzzTests` with the extended op mix (pipe-table pastes),
/// 2026-09-23, seed 3 (step 33 `.pasteText("```\nlet x = 1\n```")` over a selection that ran from a
/// cell to the paragraph after it; reported as an engine-axis mismatch); reduced by probe.
///
/// **Suspected cause.** The paste paths do not go through the gate's cross-block decision. For a
/// plain or RTF paste, `deleteCrossBlockSelectionBeforeEnginePaste` (`+Clipboard.swift`) deletes the
/// selection first and never meets the partial-table refusal. The per-cell deletion then empties
/// cells in the roles while the engine's text loses them. A fragment paste goes through
/// `Document.replacingRange`, which drops the table.
///
/// **Tier 1**: `paste:` on the engine view, as the edit menu and ⌘V send it.
@available(iOS 18.4, *)
final class HarnessPasteOverPartialTableSelectionTests: XCTestCase {
    private static let table = "| x | y | z |\n|---|---|---|\n| 1 | 2 | 3 |"

    /// Arranges `[p "Intro"] [table] [p "after"]`, then runs `ops`; returns the model before and after
    /// `ops`, and any engine-axis mismatch.
    private func run(_ ops: [FuzzOp], withAfterParagraph: Bool = true) throws -> (before: ChatInputContent, after: ChatInputContent, mismatch: String?) {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer {
            verifier.restore()
            _ = driver.node.resignInputFirstResponder()
        }
        var arrange: [FuzzOp] = [.select(5, 5), .pasteText(Self.table)]
        if withAfterParagraph {
            arrange.append(.insert("after"))
        }
        HarnessComposerFuzzTests.perform(driver, start: HarnessContent.plainText("Intro"), ops: arrange)
        let before = FuzzModel.normalized(driver.model())
        guard case .table? = before.blocks.dropFirst().first else {
            XCTFail("precondition: the pasted table is not the second block: \(FuzzModel.describe(before))")
            return (before, before, nil)
        }
        for op in ops {
            HarnessComposerFuzzTests.execute(op, on: driver)
            driver.settle(0.1)
        }
        driver.settle(0.3)
        let after = FuzzModel.normalized(driver.model())
        return (before, after, FuzzModel.engineAxisMismatch(after, engineText: driver.viewText()))
    }

    private func assertRefused(_ result: (before: ChatInputContent, after: ChatInputContent, mismatch: String?), _ what: String) {
        XCTAssertNil(result.mismatch, "\(what): the model and the engine disagree")
        XCTAssertEqual(FuzzModel.describe(result.after), FuzzModel.describe(result.before), "\(what) over a selection covering the table in part changed the document")
    }

    func testPlainPasteFromACellIntoTheParagraphAfterIsRefused() throws {
        self.assertRefused(try self.run([.select(8, 20), .pasteText("plain")]), "a plain paste")
    }

    func testMultiLinePasteFromACellIntoTheParagraphAfterIsRefused() throws {
        self.assertRefused(try self.run([.select(8, 20), .pasteText("l1\nl2")]), "a two-line paste")
    }

    func testMarkdownPasteFromACellIntoTheParagraphAfterIsRefused() throws {
        self.assertRefused(try self.run([.select(8, 20), .pasteText("```\nlet x = 1\n```")]), "a markdown paste")
    }

    func testPlainPasteFromAParagraphIntoACellIsRefused() throws {
        self.assertRefused(try self.run([.select(2, 9), .pasteText("plain")], withAfterParagraph: false), "a plain paste")
    }

    func testFragmentPasteFromACellIntoTheParagraphAfterIsRefused() throws {
        self.assertRefused(try self.run([.select(0, 3), .copy, .select(8, 20), .paste]), "a paste of the editor's own copy")
    }

    /// Control: typing over the same selection is refused by the gate.
    func testControlTypingOverTheSameSelectionIsRefused() throws {
        self.assertRefused(try self.run([.select(8, 20), .insert("X")]), "typing")
    }
}
