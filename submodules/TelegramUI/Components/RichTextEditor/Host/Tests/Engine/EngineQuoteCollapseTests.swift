import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// R7-collapse §6. A folded quote is an ATOM UNIT, and joining that family is what gives it its
/// caret, deletion and navigation behaviour — there are no rules of its own.
@available(iOS 18.4, *)
final class EngineQuoteCollapseTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!
    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window.addSubview(editor); window.makeKeyAndVisible()
    }
    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }

    private func para(_ id: String, _ text: String) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), runs: text.isEmpty ? [] : [TextRun(text: text)]))
    }
    private func quote(_ id: String, _ children: [Block],
                       collapsed: Bool = false, author: String = "") -> Block {
        .blockQuote(BlockQuote(id: BlockID(id), children: children, collapsed: collapsed,
                               author: author.isEmpty ? [] : [TextRun(text: author)]))
    }
    private func load(_ blocks: [Block]) {
        editor.document = Document(blocks: blocks)
        XCTAssertTrue(editor.engine.becomeFirstResponder())
    }
    private func caret(_ at: Int) { editor.engineSelectedRange = NSRange(location: at, length: 0) }
    private func strings() -> [String] { editor.engine.attributedBlocks.map(\.string) }
    private func turn() {
        let expectation = expectation(description: "run loop")
        DispatchQueue.main.async { expectation.fulfill() }
        wait(for: [expectation], timeout: 1.0)
    }

    func test_aFoldedQuoteIsItsOwnAtomUnit() {
        load([quote("q", [para("a", "one")], collapsed: true)])
        XCTAssertEqual(editor.atomUnitIndex(forRoleAt: 0), 0)
        XCTAssertNil(editor.atomUnitCompanionIndex(ofAtomAt: 0),
                     "no companion line — a folded quote is captionless, like a button row")
    }

    func test_backspacePastTheAtomsStartSelectsItRatherThanDeletingIt() {
        load([quote("q", [para("a", "one")], collapsed: true)])
        caret(1)
        XCTAssertTrue(editor.consumeBackspaceAtACollapsedCaret())
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 0, length: 1),
                       "step one of two: select, then a second Backspace deletes")
        XCTAssertEqual(editor.document.blocks.count, 1, "nothing is gone yet")
    }

    /// Backspace at the start of the block after a folded quote PARKS the caret at the atom's end —
    /// it does not select, and it does not merge.
    ///
    /// Parking is the shared atom rule, pinned for a captionless medium by
    /// `EngineAtomBackspaceGoldenTests.test_aCaretAtTheStartOfTheBlockAfterAnAtomParksAtTheUnitsEnd`,
    /// and a folded quote answering identically is the whole point of joining that family. The
    /// two-step deletion is still there, one press further along: parked at the atom's end the next
    /// Backspace is "a caret inside an atom", which selects.
    ///
    /// It is also what keeps the region-boundary WALL's `false` answer honest. If the atom rules did
    /// not claim this keystroke first, the wall would let the block merge INTO the atom's engine
    /// block — text joined onto an attachment character whose shape ignores runs, so it would vanish
    /// on the next read-back.
    func test_backspaceAtTheStartOfTheBlockAfterAFoldedQuoteParksAtTheAtomsEnd() {
        load([quote("q", [para("a", "one")], collapsed: true), para("after", "zzz")])
        guard let after = editor.currentRoles.firstIndex(where: { $0.blockID == BlockID("after") }) else {
            return XCTFail("precondition: the block after the atom is on the axis")
        }
        caret(editor.flatOffset(ofRoleAt: after))
        XCTAssertTrue(editor.consumeBackspaceAtACollapsedCaret())
        let atomEnd = editor.flatOffset(ofRoleAt: 0) + editor.flatLength(ofRoleAt: 0)
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: atomEnd, length: 0),
                       "parked at the atom's end, never merged into it")
        XCTAssertEqual(strings(), ["\u{FFFC}", "zzz"], "nothing merged, nothing deleted")

        // …and the press after that selects, which is step one of the deletion.
        XCTAssertTrue(editor.consumeBackspaceAtACollapsedCaret())
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 0, length: 1))
    }

    func test_typingAtTheAtomsGapMintsAParagraphBeforeItRatherThanTypingIntoIt() {
        load([quote("q", [para("a", "one")], collapsed: true)])
        caret(0)
        editor.engine.insertText("x")
        turn()
        XCTAssertEqual(strings(), ["x", "\u{FFFC}"],
                       "the folded body is content the user hid; a keystroke must not replace it")
        guard editor.document.blocks.count == 2,
              case let .blockQuote(read) = editor.document.blocks[1] else {
            return XCTFail("quote lost: \(editor.document.blocks)")
        }
        XCTAssertEqual(read.children.first?.asParagraph?.runs.first?.text, "one")
    }

    // MARK: - The toggle (R7-collapse §5)

    /// Counts deliveries over a WINDOW rather than waiting for the first — a wait cannot see a
    /// duplicate landing a turn later. The setup's own delivery is drained by the `turn()` before the
    /// counter is installed, or every case reads as one more than it should.
    private func deliveries(_ act: () -> Void) -> Int {
        turn()
        var calls = 0
        editor.onChange = { calls += 1 }
        act()
        turn()
        editor.onChange = nil
        return calls
    }

    func test_foldingTakesTheBodyOffTheAxisAndKeepsItInTheModel() {
        load([quote("q", [para("a", "one"), para("b", "two")])])
        editor.toggleQuoteCollapsed(id: BlockID("q"))
        XCTAssertEqual(strings(), ["\u{FFFC}"])
        guard case let .blockQuote(read) = editor.document.blocks[0] else { return XCTFail("not a quote") }
        XCTAssertTrue(read.collapsed)
        XCTAssertEqual(read.children.count, 2, "the body is still there, in the model")
    }

    func test_unfoldingPutsTheBodyBack() {
        load([quote("q", [para("a", "one"), para("b", "two")], collapsed: true)])
        editor.toggleQuoteCollapsed(id: BlockID("q"))
        XCTAssertEqual(strings(), ["one", "two", ""], "two children and the author line")
    }

    func test_foldAndUnfoldRoundTripsTheBody() {
        load([quote("q", [para("a", "one"), para("b", "two")], author: "Ada")])
        editor.toggleQuoteCollapsed(id: BlockID("q"))
        editor.toggleQuoteCollapsed(id: BlockID("q"))
        XCTAssertEqual(strings(), ["one", "two", "Ada"])
    }

    /// Arm 1. The caret cannot stay in a body that is no longer on the engine's axis.
    func test_foldingWithTheCaretInTheBodyLandsItOnTheAtom() {
        load([quote("q", [para("a", "one")]), para("after", "zzz")])
        caret(2)
        editor.toggleQuoteCollapsed(id: BlockID("q"))
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 0, length: 0))
    }

    /// Arm 2, and the reason arm 1 is tested FIRST: for a folded quote the atom's end IS the span's
    /// end, so an arm-2-first ordering claims a caret that belongs to arm 1.
    func test_unfoldingShiftsACaretAfterTheQuoteByTheBodyItRevealed() {
        load([quote("q", [para("a", "one")], collapsed: true), para("after", "zzz")])
        guard let before = editor.currentRoles.firstIndex(where: { $0.blockID == BlockID("after") }) else {
            return XCTFail("precondition: a block after the quote")
        }
        caret(editor.flatOffset(ofRoleAt: before) + 1)   // one character into "zzz"
        editor.toggleQuoteCollapsed(id: BlockID("q"))
        guard let after = editor.currentRoles.firstIndex(where: { $0.blockID == BlockID("after") }) else {
            return XCTFail("the block after the quote survived the unfold")
        }
        XCTAssertEqual(editor.engineSelectedRange,
                       NSRange(location: editor.flatOffset(ofRoleAt: after) + 1, length: 0),
                       "the caret keeps the same place in the same text, not the same absolute offset")
    }

    /// THE boundary case, and the one that makes the arms' order mean anything.
    ///
    /// A folded quote's atom END is also its span's end, and the atom's end is exactly where
    /// Backspace parks a caret arriving from the block below (`…ParksAtTheAtomsEnd` above). So a
    /// caret there is ON the quote: unfolding must leave it at the quote, not treat it as a caret
    /// that merely sat after the block and shift it by the whole revealed body.
    ///
    /// This is `+Details.swift`'s recorded K3 defect one container kind over, and it was found here
    /// by a NEUTER that refused to go red: with `inside` written to exclude `after` the two arms
    /// were mutually exclusive, the order could not matter, and this caret was flung to the end of
    /// the body the unfold had just revealed.
    func test_unfoldingFromACaretParkedAtTheAtomsEndKeepsItOnTheQuote() {
        load([quote("q", [para("a", "one")], collapsed: true), para("after", "zzz")])
        let atomEnd = editor.flatOffset(ofRoleAt: 0) + editor.flatLength(ofRoleAt: 0)
        caret(atomEnd)
        editor.toggleQuoteCollapsed(id: BlockID("q"))
        guard let firstChild = editor.currentRoles.firstIndex(where: { $0.blockID == BlockID("a") }) else {
            return XCTFail("the body came back: \(editor.currentRoles.map(\.blockID))")
        }
        XCTAssertEqual(editor.engineSelectedRange,
                       NSRange(location: editor.flatOffset(ofRoleAt: firstChild), length: 0),
                       "the caret was ON the quote, so it lands in the quote — not past the body")
    }

    /// Arm 3. A selection that lies entirely before the quote is untouched — and it stays a RANGE.
    func test_aSelectionBeforeTheQuoteIsUntouched() {
        load([para("before", "abcd"), quote("q", [para("a", "one")])])
        editor.engineSelectedRange = NSRange(location: 1, length: 2)
        editor.toggleQuoteCollapsed(id: BlockID("q"))
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 1, length: 2))
    }

    func test_oneToggleDeliversExactlyOneChange() {
        load([quote("q", [para("a", "one")])])
        XCTAssertEqual(deliveries { editor.toggleQuoteCollapsed(id: BlockID("q")) }, 1)
    }

    func test_undoRestoresTheOpenQuote() {
        load([quote("q", [para("a", "one")])])
        editor.toggleQuoteCollapsed(id: BlockID("q"))
        editor.engine.undoManager?.undo()
        turn()
        guard case let .blockQuote(read) = editor.document.blocks[0] else { return XCTFail("not a quote") }
        XCTAssertFalse(read.collapsed)
    }

    func test_togglingAnIdThatIsNotAQuoteDoesNothing() {
        load([para("a", "one")])
        editor.toggleQuoteCollapsed(id: BlockID("a"))
        XCTAssertEqual(strings(), ["one"])
    }
}
