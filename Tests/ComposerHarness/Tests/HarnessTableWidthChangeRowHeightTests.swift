import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** On the engine backend, after a WIDTH change (rotation, Split View) a table whose cell
/// text wraps re-wraps that text for the new width, but the rows BELOW keep the row height of the
/// PREVIOUS width. The table's row layout lags the width by one change, so rows overlap or leave a gap:
///
///     [p "Top"] [table ("a very long cell text … and more" | "") ("pha" | "1")] [p "After"]
///                            first cell's last line   row 2 ("pha")   fresh layout at that width
///     402pt (fresh)                y 156             y 203            203
///     → 700pt                      y  96             y 203            143   (a 60pt gap)
///     → back to 402pt              y 156             y 143            203   (row 2 drawn OVER row 1)
///     402 → 300 → 402: row 2 at 243 (the 300pt height), 40pt too low
///
/// A fresh content set at the same width lays the table out right, so the document's geometry depends
/// on the width history. Short cells (no wrapping) and a wrapping PARAGRAPH are unaffected (controls).
///
/// **How it was seen.** p15 (2026-09-24), fuzz seed 40 of the 31-60 sweep with the external-push op: the
/// end-of-sequence width round trip (300, 700, 402) found 22 caret rects 20pt higher than before it, all
/// after a table whose first cell held a pasted code fence.
///
/// **Suspected cause.** The table's row heights are measured from the cells' layout at the width the
/// grid last saw, and the width change re-lays the cells out after the grid has placed its rows (the
/// engine's cell blocks vs. the host's `syncTableFrames` / table layout pass,
/// `RichTextEngineEditorView+TableLayout.swift`), so the grid needs a second pass it never gets.
///
/// **Tier 1**: the width change is the panel's own `updateLayout(width:)`, driven by the root's frame as a
/// rotation does (see the manual); geometry is `caretRect(for:)` on the engine's `UITextInput`.
@available(iOS 18.4, *)
final class HarnessTableWidthChangeRowHeightTests: XCTestCase {
    private static let longText = "a very long cell text that surely wraps at three hundred points of width and more"

    private static func content(_ first: String) -> ChatInputContent {
        func cell(_ text: String) -> ChatInputTableCell {
            return ChatInputTableCell(runs: [ChatInputRun(text: text)])
        }
        return ChatInputContent(blocks: [
            HarnessEngine.paragraph("Top"),
            .table(ChatInputTable(columns: [ChatInputColumnSpec(width: 0.0), ChatInputColumnSpec(width: 0.0)], rows: [
                ChatInputTableRow(cells: [cell(first), cell("")]),
                ChatInputTableRow(cells: [cell("pha"), cell("1")]),
            ])),
            HarnessEngine.paragraph("After"),
        ])
    }

    private func resize(_ driver: EngineFuzzDriver, _ width: CGFloat) {
        driver.root.view.frame = CGRect(x: 0.0, y: 0.0, width: width, height: 874.0)
        driver.root.view.setNeedsLayout()
        driver.settle(0.3)
        driver.root.view.layoutIfNeeded()
    }

    /// The caret's top at `offset` after walking `widths`, and at the same offset after a fresh set at the
    /// last width.
    private func afterWidths(_ content: ChatInputContent, offset: Int, _ widths: [CGFloat]) throws -> (walked: CGFloat, fresh: CGFloat) {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer {
            verifier.restore()
            _ = driver.node.resignInputFirstResponder()
            self.resize(driver, 402.0)
        }
        let input = try XCTUnwrap(driver.view as? (UIView & UITextInput))
        func top() -> CGFloat {
            let position = input.position(from: input.beginningOfDocument, offset: offset)!
            return input.caretRect(for: position).minY
        }
        self.resize(driver, 402.0)
        HarnessComposerFuzzTests.arrange(driver, content)
        for width in widths {
            self.resize(driver, width)
        }
        let walked = top()
        driver.host.setInputContent(ChatInputContent())
        driver.settle(0.1)
        driver.host.setInputContent(content)
        driver.settle(0.3)
        return (walked, top())
    }

    /// Offset of "pha", the second row's first cell: "Top\n" + the first cell + "\n" + "" + "\n".
    private static func rowTwo(_ first: String) -> Int {
        return 4 + (first as NSString).length + 2
    }

    func testTheRowBelowAWrappingCellFollowsAWidening() throws {
        let result = try self.afterWidths(Self.content(Self.longText), offset: Self.rowTwo(Self.longText), [700.0])
        XCTAssertEqual(result.walked, result.fresh, "at 700pt the second row sits at y \(result.walked); a fresh layout at 700pt puts it at \(result.fresh)")
    }

    func testTheRowBelowAWrappingCellFollowsARoundTrip() throws {
        let result = try self.afterWidths(Self.content(Self.longText), offset: Self.rowTwo(Self.longText), [700.0, 402.0])
        XCTAssertEqual(result.walked, result.fresh, "back at 402pt after 700pt the second row sits at y \(result.walked) (over the first row's text); a fresh layout puts it at \(result.fresh)")
    }

    func testTheRowBelowAWrappingCellFollowsANarrowing() throws {
        let result = try self.afterWidths(Self.content(Self.longText), offset: Self.rowTwo(Self.longText), [300.0, 402.0])
        XCTAssertEqual(result.walked, result.fresh, "back at 402pt after 300pt the second row sits at y \(result.walked); a fresh layout puts it at \(result.fresh)")
    }

    func testControlShortCellsFollowAWidthChange() throws {
        let result = try self.afterWidths(Self.content("short"), offset: Self.rowTwo("short"), [700.0, 402.0])
        XCTAssertEqual(result.walked, result.fresh)
    }

    func testControlAWrappingParagraphFollowsAWidthChange() throws {
        let content = ChatInputContent(blocks: [HarnessEngine.paragraph(Self.longText), HarnessEngine.paragraph("After")])
        let offset = (Self.longText as NSString).length + 1
        let widened = try self.afterWidths(content, offset: offset, [700.0])
        XCTAssertEqual(widened.walked, widened.fresh)
        let back = try self.afterWidths(content, offset: offset, [700.0, 402.0])
        XCTAssertEqual(back.walked, back.fresh)
    }
}
