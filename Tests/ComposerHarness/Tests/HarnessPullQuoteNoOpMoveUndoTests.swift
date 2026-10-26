import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke (p20, 2026-09-30):** a local drag-and-drop move inside a PULL QUOTE that leaves the text
/// unchanged (a chunk of repeated text dragged onto an identical chunk: `"ab ab ab …"`, move 9..<18 to 0)
/// registers NO undo step, so the next ⌘Z takes back the edit BEFORE the move (a typed `Z` vanishes). The
/// same move in a body paragraph registers its step and one undo returns to the state before the move
/// (control), and a move in a pull quote that changes the text is one step as it should be (control).
///
/// **How it was seen:** default and edited fuzz seed 68 (p20 sweep 46-90), at the end-of-sequence local-move
/// round trip over a pull quote of 40 repeated sentences (`"one undo did not revert the move 330..<660 -> 0"`,
/// the undo emptying the pull quote); reduced here.
///
/// **Suspected:** `performLocalMove` (`+DragAndDrop.swift`) wraps Cut + Paste in `performAsOneUndoStep`, which
/// registers a step only when the snapshot changed; in a pull quote the snapshot comparison (text + roles)
/// sees no change, where for a paragraph something (a block identity) does. A move the user made should be
/// one undo step whether or not the text differs, as in a stock text view.
///
/// **Tier 1.**
@available(iOS 18.4, *)
final class HarnessPullQuoteNoOpMoveUndoTests: XCTestCase {
    private var driver: EngineFuzzDriver!
    private var verifier: FuzzEngineVerifier?

    override func setUpWithError() throws {
        self.driver = try EngineFuzzDriver()
        self.verifier = FuzzEngineVerifier.nonFatal()
    }

    override func tearDown() {
        self.verifier?.restore()
        _ = self.driver.node.resignInputFirstResponder()
        self.driver = nil
    }

    /// Arranges `block`, types `Z` at the end of its text, moves `range` to 0, undoes once. Returns (the
    /// model with Z, after the move, after the undo).
    private func typeMoveUndo(_ block: ChatInputBlock, textLength: Int, _ range: NSRange) -> (withZ: ChatInputContent, moved: ChatInputContent, undone: ChatInputContent)? {
        self.driver.arrange(ChatInputContent(blocks: [block]))
        self.driver.undoManager?.removeAllActions()
        self.driver.setViewSelection(NSRange(location: textLength, length: 0))
        self.driver.settle()
        self.driver.insert("Z")
        self.driver.settle()
        let withZ = FuzzModel.normalized(self.driver.model())
        self.driver.setViewSelection(range)
        self.driver.settle()
        guard let context = self.driver.editor.makeTextDragContext(), self.driver.editor.performLocalMove(context, toFlatOffset: 0) else {
            XCTFail("precondition: the move was refused")
            return nil
        }
        self.driver.settle()
        let moved = FuzzModel.normalized(self.driver.model())
        XCTAssertTrue(self.driver.undoManager?.canUndo == true, "precondition")
        self.driver.undoManager?.undo()
        self.driver.settle()
        return (withZ, moved, FuzzModel.normalized(self.driver.model()))
    }

    private static let repeated = String(repeating: "ab ", count: 20)

    func testATextPreservingMoveInAPullQuoteIsItsOwnUndoStep() {
        guard let result = self.typeMoveUndo(.pullQuote(ChatInputPullQuote(runs: [ChatInputRun(text: Self.repeated)])), textLength: 60, NSRange(location: 9, length: 9)) else { return }
        XCTAssertEqual(result.moved, result.withZ, "precondition: the move leaves the text as it was")
        XCTAssertEqual(FuzzModel.describe(result.undone), FuzzModel.describe(result.withZ), "one undo after the move took back the typing before it")
    }

    /// Control: the same move in a body paragraph is its own step.
    func testControlTheSameMoveInAParagraphIsItsOwnUndoStep() {
        guard let result = self.typeMoveUndo(HarnessEngine.paragraph(Self.repeated), textLength: 60, NSRange(location: 9, length: 9)) else { return }
        XCTAssertEqual(FuzzModel.describe(result.undone), FuzzModel.describe(result.withZ))
    }

    /// Control: a move that changes a pull quote's text is one step.
    func testControlATextChangingMoveInAPullQuoteIsOneUndoStep() {
        guard let result = self.typeMoveUndo(.pullQuote(ChatInputPullQuote(runs: [ChatInputRun(text: "abcdefghijklmnopqrstuvwxyz")])), textLength: 26, NSRange(location: 9, length: 9)) else { return }
        XCTAssertNotEqual(result.moved, result.withZ, "precondition")
        XCTAssertEqual(FuzzModel.describe(result.undone), FuzzModel.describe(result.withZ))
    }
}
