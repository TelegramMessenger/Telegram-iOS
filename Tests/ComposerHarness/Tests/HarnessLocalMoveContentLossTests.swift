import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke (CORRUPTS THE SENT MODEL).** A local drag-and-drop move can DESTROY content — text,
/// structure and media that were neither the moved range nor meant to be replaced. A move relocates
/// characters; it must neither create nor lose any (the fuzz's new `move` op asserts exactly that, on
/// letters and atoms).
///
///     (1) [p "Top"] [pull "body" author="Author name here"], move 1..<12 ("op⏎body⏎Aut", from the
///         paragraph into the author line) to 20 (later in the same author line)
///           → [p "T"]: the pull quote, its body and its whole author line are gone.
///     (2) [p "Before"] [media "Cap"] [p "After"] [media "Second"], move 3..<15 ("ore⏎￼⏎Cap⏎Af", over the
///         first unit) into the second caption (24)
///           → [p "Befter"] [media cap="Secore  Afond"]: the first PHOTO is gone (the caption can hold
///             only text; a Copy + Paste to the same caret keeps the original, so only the move loses it).
///     (3) [p "Top"] [table ("a" | "b")] [p "one"] [p "two"], move 8..<11 ("one") into cell "a" (5)
///           → [p "Top"] [p "one"] [p ""] [p "two"]: the TABLE is gone (see
///             `HarnessFragmentPasteIntoTableCellTests` — a paste into a cell does the same).
///     (4) [table ("a" | pill)] [p "x"] [table ("c" | "d")], move "a" (0..<1) after "c" (7)
///           → [p "x"] [table ("a" | pill)] [p ""]: the whole first table moved and the second was replaced.
///
/// Controls: moves between plain paragraphs, and within one author line, relocate exactly the moved text.
///
/// **How it was seen.** p19 roam, 2026-09-25: the fuzz's new `move` op (edited-content seeds 8, 54, 56,
/// 57, 67, 84 of 1-90 reported "the move … changed the number of atoms"), each replayed and shrunk.
///
/// **Suspected cause.** `performLocalMove` (`RichTextEngineEditorView+DragAndDrop.swift`) composes delete-
/// source + insert-at-target purely (`replacingRangePlacingCaret`) and sets the result once. When the target
/// can hold only text (a caption, a one-line field, a code body) the inserted fragment's units are dropped
/// while the source's deletion still removes them; when the target is a cell the insert replaces the table
/// (the paste defect); and when target and source share an owned line (an author) the second edit is
/// applied at an offset the first one already moved. A move whose destination cannot hold what it carries
/// should be refused, as a partly covered table already is.
///
/// **Tier 1**: the move's own entry points, as `HarnessTextDropTests` drives them.
@available(iOS 18.4, *)
final class HarnessLocalMoveContentLossTests: XCTestCase {
    private typealias E = HarnessEdited

    private func table(_ rows: [[[ChatInputRun]]]) -> ChatInputBlock {
        return .table(ChatInputTable(columns: rows[0].map { _ in ChatInputColumnSpec(width: 0.0) }, rows: rows.map { ChatInputTableRow(cells: $0.map { ChatInputTableCell(runs: $0) }) }))
    }

    /// Letters and digits of the engine text, sorted: a move relocates them, so the multiset is invariant
    /// (spaces and line breaks are not counted, since a one-line field turns a break into a space).
    private func letters(_ text: String) -> String {
        return String(text.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.map(Character.init).sorted())
    }

    private func assertMovePreservesContent(_ content: ChatInputContent, _ source: NSRange, to target: Int, file: StaticString = #filePath, line: UInt = #line) throws {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer { verifier.restore(); _ = driver.node.resignInputFirstResponder() }
        HarnessComposerFuzzTests.arrange(driver, content)
        let before = FuzzModel.normalized(driver.model())
        let lettersBefore = self.letters(driver.viewText())
        driver.setViewSelection(source)
        driver.settle(0.1)
        let context = try XCTUnwrap(driver.editor.makeTextDragContext(), "nothing to lift", file: file, line: line)
        guard driver.editor.performLocalMove(context, toFlatOffset: target) else {
            return // a refused move loses nothing
        }
        driver.settle(0.3)
        let after = FuzzModel.normalized(driver.model())
        XCTAssertEqual(self.letters(driver.viewText()), lettersBefore, "the move changed the text it did not move:\n  before \(E.describe(before))\n  after  \(E.describe(after))", file: file, line: line)
        XCTAssertEqual(HarnessComposerFuzzTests.atomCount(after), HarnessComposerFuzzTests.atomCount(before), "the move changed the number of atoms:\n  before \(E.describe(before))\n  after  \(E.describe(after))", file: file, line: line)
    }

    func testAMoveFromAParagraphIntoAnAuthorLineKeepsThePullQuote() throws {
        let content = ChatInputContent(blocks: [E.paragraph([E.run("Top")]), .pullQuote(ChatInputPullQuote(runs: [E.run("body")], author: [E.run("Author name here")]))])
        try self.assertMovePreservesContent(content, NSRange(location: 1, length: 11), to: 20)
    }

    func testAMoveOfAMediaUnitIntoACaptionKeepsTheMedium() throws {
        let content = ChatInputContent(blocks: [E.paragraph([E.run("Before")]), E.media(1, caption: "Cap"), E.paragraph([E.run("After")]), E.media(2, caption: "Second")])
        try self.assertMovePreservesContent(content, NSRange(location: 3, length: 12), to: 24)
    }

    func testAMoveOfAParagraphIntoATableCellKeepsTheTable() throws {
        let content = ChatInputContent(blocks: [E.paragraph([E.run("Top")]), self.table([[[E.run("a")], [E.run("b")]]]), E.paragraph([E.run("one")]), E.paragraph([E.run("two")])])
        try self.assertMovePreservesContent(content, NSRange(location: 8, length: 3), to: 5)
    }

    func testAMoveOfACellsTextIntoAnotherTablesCellKeepsBothTables() throws {
        let content = ChatInputContent(blocks: [self.table([[[E.run("a")], [E.pill("P")]]]), E.paragraph([E.run("x")]), self.table([[[E.run("c")], [E.run("d")]]])])
        try self.assertMovePreservesContent(content, NSRange(location: 0, length: 1), to: 7)
    }

    // Controls.

    func testControlAMoveBetweenParagraphsKeepsEverything() throws {
        try self.assertMovePreservesContent(HarnessContent.plainText("abc\ndef\nghi"), NSRange(location: 6, length: 3), to: 0)
    }

    func testControlAMoveWithinAnAuthorLineKeepsEverything() throws {
        let content = ChatInputContent(blocks: [E.paragraph([E.run("Top")]), .pullQuote(ChatInputPullQuote(runs: [E.run("body")], author: [E.run("Author name here")]))])
        try self.assertMovePreservesContent(content, NSRange(location: 9, length: 3), to: 20)
    }
}
