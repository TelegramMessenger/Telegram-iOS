import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** A local drag-and-drop MOVE whose source runs from a paragraph INTO the container after it
/// (a block quote, a details block) leaves the source's two halves apart, where Cut + Paste of the same
/// range — and Backspace or typing over it — joins them by the gate's cross-block rule. The paragraph break
/// the user dragged is therefore copied rather than moved: the document gains a line.
///
///     [p "Intro line."] [quote [p "Quoted text here."]]   engine "Intro line.\nQuoted text here.\n"
///     move 11..<22 ("⏎Quoted tex") to 6 ("Intro |line.")
///       move       [p "Intro "] [quote "Quoted tex"] [p "line."] [quote "t here."]     4 blocks
///       cut+paste  [p "Intro "] [quote "Quoted tex"] [p "line.t here."]                3 blocks
///       (a stock text view: "Intro \nQuoted texline.t here." — the dragged break is moved, not copied)
///     move 8..<16 ("ne.⏎Quot") to 0 → [p "ne."] [quote "Quot"] [p "Intro li"] [quote "ed text here."]
///       cut+paste                     [p "ne."] [quote "Quot"] [p "Intro lied text here."]
///     [p "Details:"] [details "Summary" [p "Hidden body."]], move 7..<19 to 0 leaves "Details" and
///       "dden body." as two paragraphs where cut+paste joins them.
///
/// Controls: the same moves between plain paragraphs equal Cut + Paste (`"abc⏎def⏎ghi"`, 6..<9 → 0 gives
/// `[p "f"] [p "gabc"] [p "dehi"]` both ways).
///
/// **How it was seen.** p19 roam, 2026-09-25: a probe comparing `performLocalMove` with Cut + Paste over
/// random ranges of the fuzz's starting documents (220 trials): 11 disagreements, 7 of this shape (quotes,
/// nested quotes, details). The others differ in how the INSERTED piece is shaped (a pull-quote or
/// language-line fragment inserted inline by the move and as a block by the paste) and are not filed.
///
/// **Suspected cause.** `performLocalMove` (`RichTextEngineEditorView+DragAndDrop.swift`) deletes the
/// source with Core's `replacingRangePlacingCaret` — the complement model, which keeps the prefix's and the
/// suffix's blocks as they are when they belong to different containers — while Cut and Backspace go
/// through the surface gate's `replaceAcrossBlocks`, whose rule merges the survivor. One user operation,
/// two rules for "delete this range".
///
/// **Tier 1**: the move's entry point (`makeTextDragContext` + `performLocalMove`) against `cut:` /
/// `paste:` on the same document, as `HarnessTextDropTests` drives it.
@available(iOS 18.4, *)
final class HarnessLocalMoveSourceJoinTests: XCTestCase {
    private func compare(_ content: ChatInputContent, _ source: NSRange, to target: Int, file: StaticString = #filePath, line: UInt = #line) throws {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer { verifier.restore(); _ = driver.node.resignInputFirstResponder() }
        HarnessComposerFuzzTests.arrange(driver, content)
        driver.setViewSelection(source)
        driver.settle(0.1)
        let context = try XCTUnwrap(driver.editor.makeTextDragContext(), "nothing to lift", file: file, line: line)
        XCTAssertTrue(driver.editor.performLocalMove(context, toFlatOffset: target), "the move was refused", file: file, line: line)
        driver.settle(0.3)
        let moved = FuzzModel.normalized(driver.model())

        HarnessComposerFuzzTests.arrange(driver, content)
        driver.setViewSelection(source)
        driver.settle(0.1)
        _ = driver.view.perform(#selector(UIResponderStandardEditActions.cut(_:)), with: nil)
        HarnessComposerFuzzTests.notePasteboardWritten()
        driver.settle(0.1)
        driver.setViewSelection(NSRange(location: target > source.location ? target - source.length : target, length: 0))
        driver.settle(0.1)
        _ = driver.view.perform(#selector(UIResponderStandardEditActions.paste(_:)), with: nil)
        driver.settle(0.3)
        let cutPaste = FuzzModel.normalized(driver.model())
        XCTAssertEqual(HarnessEdited.describe(moved), HarnessEdited.describe(cutPaste), "the move differs from Cut + Paste of the same range", file: file, line: line)
    }

    func testAMoveFromAParagraphIntoAQuoteJoinsTheHalvesAsCutAndPasteDo() throws {
        try self.compare(HarnessComposerFuzzTests.startingContents()[3], NSRange(location: 11, length: 11), to: 6)
    }

    func testAMoveToTheStartFromAParagraphIntoAQuoteJoinsTheHalves() throws {
        try self.compare(HarnessComposerFuzzTests.startingContents()[3], NSRange(location: 8, length: 8), to: 0)
    }

    func testAMoveFromAParagraphIntoADetailsBlockJoinsTheHalves() throws {
        try self.compare(HarnessComposerFuzzTests.extendedStartingContents()[4], NSRange(location: 7, length: 12), to: 0)
    }

    // Controls: between plain paragraphs the move is Cut + Paste.

    func testControlAMoveBackwardsAcrossParagraphs() throws {
        try self.compare(HarnessContent.plainText("abc\ndef\nghi"), NSRange(location: 6, length: 3), to: 0)
    }

    func testControlAMoveForwardsAcrossParagraphs() throws {
        try self.compare(HarnessContent.plainText("abc\ndef\nghi"), NSRange(location: 2, length: 3), to: 11)
    }
}
