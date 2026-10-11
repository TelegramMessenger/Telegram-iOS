import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** On the engine backend, a table wider than the composer scrolls sideways in its own run
/// scroll view, but nothing scrolls that run to the CARET. When the caret is in a column past the right
/// edge, typing lands there with the cursor off screen, and the run stays at offset 0:
///
///     5-column table, composer 317pt wide, table content 556pt
///     landscape (615pt, every column visible), caret at the end of column 5
///     → portrait: the caret is off the right edge (cursor at window x 557, the field ends at 383)
///     → type "Q": "…long longQ" lands in column 5, the run is still at offset 0, the cursor at x 540
///     Tab from column 4 into column 5, or → across the boundary: the caret moves there, the run does not follow
///
/// The typed text is right; the user just cannot see where it goes. Vertically the composer reveals the
/// caret after every edit (`RichTextCaretRevealSolver`); horizontally that reveal is documented as the run
/// scroll view's job (`RichTextEditorCore/CaretReveal.swift`: "horizontal reveal belongs to a table cell's
/// own run scroll view, which this never touches"), and the run scroll view has no caret logic.
///
/// **How it was seen.** p14 roam, 2026-09-24 (width changes mid-edit): a probe read the run's
/// `contentOffset` and the drawn cursor's window frame after a width change with the caret in a table.
///
/// **Suspected cause.** `IDPlacedRunScrollView` (`RichTextInputDecUpstream/TextView/IDBlockStackCanvasView.m`)
/// only clamps its offset on layout; the only callers of `setPlacedRunContentOffset` restore a remembered
/// offset around a table edit (`RichTextEngineEditorView+TableEdits.swift`). Neither the engine's
/// `id_scrollCaretToVisibleIfNeeded` (now a flag for the host's vertical solver) nor the host moves a run.
///
/// **Fixed (p14, 2026-09-24):** `revealSelectionEndInPlacedRun` (`RichTextEngineEditorView+RunCaretReveal.swift`),
/// from `performCaretReveal` when a change asked or the width changed.
///
/// **Not a harness artifact**: the table, its run scroll view and the reveal are all the engine's; the
/// width reaches the panel through its own `updateLayout(width:)`, as a rotation delivers it.
///
/// **Tier 1**: the drawn cursor is read off the public `UITextSelectionDisplayInteraction` and compared with
/// the text view's on-screen frame in window coordinates.
@available(iOS 18.4, *)
final class HarnessTableCaretRevealTests: XCTestCase {
    private static func cell(_ text: String) -> ChatInputTableCell {
        return ChatInputTableCell(runs: [ChatInputRun(text: text)])
    }

    private static let wide = ChatInputContent(blocks: [
        HarnessEngine.paragraph("Wide:"),
        .table(ChatInputTable(columns: Array(repeating: ChatInputColumnSpec(width: 0.0), count: 5), rows: [
            ChatInputTableRow(isHeader: true, cells: (1 ... 5).map { HarnessTableCaretRevealTests.cell("Header column number \($0)") }),
            ChatInputTableRow(cells: (1 ... 5).map { HarnessTableCaretRevealTests.cell("value in cell \($0) long long") }),
        ])),
        HarnessEngine.paragraph("After."),
    ])

    private static func setWidth(_ driver: EngineFuzzDriver, _ width: CGFloat) {
        driver.root.view.frame = CGRect(x: 0.0, y: 0.0, width: width, height: 874.0)
        driver.root.view.setNeedsLayout()
        driver.settle(0.3)
    }

    /// The drawn cursor, and whether it lies inside the text view's on-screen frame.
    private static func cursorOnScreen(_ driver: EngineFuzzDriver) throws -> (Bool, String) {
        let display = try XCTUnwrap(driver.view.interactions.compactMap { $0 as? UITextSelectionDisplayInteraction }.first, "precondition: no selection display interaction")
        let cursor = display.cursorView.convert(display.cursorView.bounds, to: nil)
        let field = driver.view.convert(driver.view.bounds, to: nil)
        return (field.insetBy(dx: -1.0, dy: -1.0).contains(cursor), "cursor \(cursor) in window, field \(field)")
    }

    private func run(_ body: (EngineFuzzDriver, UIView & UITextInput, NSString) throws -> Void) throws {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer {
            verifier.restore()
            Self.setWidth(driver, 402.0)
            _ = driver.node.resignInputFirstResponder()
        }
        driver.arrange(Self.wide)
        try body(driver, try XCTUnwrap(driver.view as? (UIView & UITextInput)), driver.viewText() as NSString)
    }

    func testTypingAfterARotationToPortraitRevealsTheCaretInAFarColumn() throws {
        try self.run { driver, input, text in
            Self.setWidth(driver, 700.0)
            driver.setViewSelection(NSRange(location: NSMaxRange(text.range(of: "value in cell 5 long long")), length: 0))
            driver.settle(0.3)
            let landscape = try Self.cursorOnScreen(driver)
            XCTAssertTrue(landscape.0, "precondition: the caret is not visible in landscape: \(landscape.1)")
            Self.setWidth(driver, 402.0)
            input.insertText("Q")
            driver.settle(0.3)
            XCTAssertTrue(FuzzModel.describe(driver.model()).contains("\"value in cell 5 long longQ\""), "precondition: the letter did not land in column 5")
            let (visible, detail) = try Self.cursorOnScreen(driver)
            XCTAssertTrue(visible, "typing in column 5 left the caret off screen: \(detail)")
        }
    }

    func testTabIntoAFarColumnRevealsIt() throws {
        try self.run { driver, _, text in
            driver.setViewSelection(NSRange(location: NSMaxRange(text.range(of: "value in cell 3 long long")), length: 0))
            driver.settle(0.3)
            // Tab twice: column 3 → 4 → 5 (the editor's own key command, as a hardware keyboard sends it).
            driver.pressTab(shift: false)
            driver.settle(0.2)
            driver.pressTab(shift: false)
            driver.settle(0.3)
            let selection = driver.viewSelection()
            let column5 = text.range(of: "value in cell 5 long long")
            XCTAssertTrue(selection.location >= column5.location && NSMaxRange(selection) <= NSMaxRange(column5), "precondition: Tab did not move into column 5 (selection \(selection), column 5 \(column5))")
            // Tab may select the cell; its END is where typing goes, so that is what must be on screen.
            let input = try XCTUnwrap(driver.view as? (UIView & UITextInput))
            let end = try XCTUnwrap(input.selectedTextRange?.end)
            let caret = driver.view.convert(input.caretRect(for: end), to: nil)
            let field = driver.view.convert(driver.view.bounds, to: nil)
            XCTAssertTrue(field.insetBy(dx: -1.0, dy: -1.0).contains(caret), "Tab into column 5 left the selection's end off screen: caret \(caret) in window, field \(field), selection \(selection)")
        }
    }

    func testArrowIntoAFarColumnRevealsIt() throws {
        try self.run { driver, input, text in
            let column5 = text.range(of: "value in cell 5 long long")
            driver.setViewSelection(NSRange(location: NSMaxRange(text.range(of: "value in cell 4 long long")), length: 0))
            driver.settle(0.3)
            // → (UIKit's hardware-arrow action) until the caret is inside column 5.
            var presses = 0
            while driver.viewSelection().location < column5.location + 3 && presses < 40 {
                FuzzKeyMove.perform("_moveRight:withHistory:", on: driver.view, extending: false)
                driver.settle(0.02)
                presses += 1
            }
            driver.settle(0.3)
            let selection = driver.viewSelection()
            XCTAssertTrue(selection.location >= column5.location && selection.location <= NSMaxRange(column5), "precondition: → did not reach column 5 (selection \(selection), column 5 \(column5))")
            let end = try XCTUnwrap(input.selectedTextRange?.end)
            let caret = driver.view.convert(input.caretRect(for: end), to: nil)
            let field = driver.view.convert(driver.view.bounds, to: nil)
            XCTAssertTrue(field.insetBy(dx: -1.0, dy: -1.0).contains(caret), "→ into column 5 left the caret off screen: caret \(caret) in window, field \(field)")
        }
    }

    /// The width change alone reveals it (p14 fix): the pass that re-lays the table out at the new
    /// width is the host moving the caret, as it is for the vertical reveal.
    func testAWidthChangeAloneRevealsTheCaretInAFarColumn() throws {
        try self.run { driver, _, text in
            Self.setWidth(driver, 700.0)
            driver.setViewSelection(NSRange(location: NSMaxRange(text.range(of: "value in cell 5 long long")), length: 0))
            driver.settle(0.3)
            XCTAssertTrue(try Self.cursorOnScreen(driver).0, "precondition: the caret is not visible in landscape")
            Self.setWidth(driver, 402.0)
            let (visible, detail) = try Self.cursorOnScreen(driver)
            XCTAssertTrue(visible, "the width change left the caret in column 5 off screen: \(detail)")
        }
    }

    /// The other half of the rule: a pass that neither moves the caret nor changes the width leaves a
    /// run the user scrolled by hand where they put it (the vertical reveal's
    /// `test_aPassThatChangesNothingLeavesAUserScrollAlone`, sideways). A height-only change (the
    /// keyboard's) is such a pass.
    func testAManualScrollAwaySurvivesPassesThatDoNotMoveTheCaret() throws {
        try self.run { driver, _, text in
            driver.setViewSelection(NSRange(location: NSMaxRange(text.range(of: "value in cell 5 long long")), length: 0))
            driver.settle(0.3)
            let editor = driver.editor
            let cell = try XCTUnwrap(editor.currentRoles.firstIndex { $0.owningTable != nil }, "precondition: no table cell")
            XCTAssertGreaterThan(editor.engine.id_placedRunContentOffsetForBlock(at: UInt(cell)), 0.5, "precondition: the caret in column 5 did not scroll the run")
            // The user drags the table back to its start; the caret stays in column 5, off screen.
            editor.engine.id_setPlacedRunContentOffset(0.0, forBlockAt: UInt(cell))
            driver.settle(0.2)
            XCTAssertFalse(try Self.cursorOnScreen(driver).0, "precondition: the manual scroll did not take the caret off screen")
            driver.root.view.setNeedsLayout()
            driver.root.view.layoutIfNeeded()
            driver.settle(0.2)
            driver.host.maxHeight = 150.0
            driver.root.view.setNeedsLayout()
            driver.settle(0.3)
            driver.host.maxHeight = 400.0
            driver.root.view.setNeedsLayout()
            driver.settle(0.3)
            XCTAssertEqual(editor.engine.id_placedRunContentOffsetForBlock(at: UInt(cell)), 0.0, accuracy: 0.5, "a pass that did not move the caret scrolled the table back to it")
        }
    }

    /// An undo that puts the caret back in a far column reveals it, after the user had scrolled the table
    /// back to its start: the undo's own document replay is a change that asks. (Written while reducing
    /// fuzz seed 34; this shorter shape did NOT reproduce that seed's stale pass, which is pinned by
    /// `HarnessComposerFuzzTests.testEngineFuzzSeed34WidthRoundTrip` instead.)
    func testUndoIntoAFarColumnRevealsIt() throws {
        try self.run { driver, input, text in
            driver.setViewSelection(NSRange(location: NSMaxRange(text.range(of: "value in cell 5 long long")), length: 0))
            driver.settle(0.3)
            input.insertText("Q")
            driver.settle(0.3)
            let editor = driver.editor
            let cell = try XCTUnwrap(editor.currentRoles.firstIndex { $0.owningTable != nil }, "precondition: no table cell")
            // The user drags the table back to its start, then moves the caret to the first column.
            editor.engine.id_setPlacedRunContentOffset(0.0, forBlockAt: UInt(cell))
            driver.setViewSelection(NSRange(location: text.range(of: "Header column number 1").location, length: 0))
            driver.settle(0.3)
            XCTAssertEqual(editor.engine.id_placedRunContentOffsetForBlock(at: UInt(cell)), 0.0, accuracy: 0.5, "precondition: the run is not at its start")
            let undoManager = try XCTUnwrap(driver.undoManager)
            XCTAssertTrue(undoManager.canUndo, "precondition: nothing to undo")
            undoManager.undo()
            driver.settle(0.3)
            XCTAssertFalse(FuzzModel.describe(driver.model()).contains("longQ"), "precondition: the undo did not remove the letter")
            let selection = driver.viewSelection()
            let column5 = (driver.viewText() as NSString).range(of: "value in cell 5 long long")
            XCTAssertTrue(selection.location >= column5.location && selection.location <= NSMaxRange(column5), "precondition: the undo did not put the caret back in column 5 (selection \(selection), column 5 \(column5))")
            let (visible, detail) = try Self.cursorOnScreen(driver)
            XCTAssertTrue(visible, "the undo put the caret in column 5 off screen: \(detail)")
        }
    }

    /// Control: a caret in the first column, which is on screen, stays visible when typing.
    func testTypingInAVisibleColumnKeepsTheCaretOnScreen() throws {
        try self.run { driver, input, text in
            driver.setViewSelection(NSRange(location: text.range(of: "Header column number 1").location + 3, length: 0))
            driver.settle(0.3)
            input.insertText("Q")
            driver.settle(0.3)
            let (visible, detail) = try Self.cursorOnScreen(driver)
            XCTAssertTrue(visible, detail)
        }
    }
}
