#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

@available(iOS 13.0, *)
final class DetailsBoxFoldTests: XCTestCase {
    private func seeded(_ expanded: Bool) -> DocumentCanvasView {
        let v = DocumentCanvasView()
        let d = DetailsBlock(id: BlockID("d"), title: [TextRun(text: "T")],
                             children: [.paragraph(ParagraphBlock(id: BlockID("b"), runs: [TextRun(text: "body")]))],
                             expanded: expanded)
        v.setBlocks([.details(d)], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 600); v.layoutIfNeeded()
        return v
    }
    private func detailsBox(_ v: DocumentCanvasView) -> DetailsBox { v.boxes.first { $0 is DetailsBox } as! DetailsBox }

    func test_toggleFold_preservesBody_flipsExpanded_asOneUndoStep() {
        let v = seeded(true)
        let um = UndoManager(); um.groupsByEvent = false; v.undoManagerOverride = um
        um.beginUndoGrouping(); v.toggleDetailsExpanded(box: detailsBox(v)); um.endUndoGrouping()
        guard case .details(let folded) = v.currentBlocks()[0] else { return XCTFail() }
        XCTAssertFalse(folded.expanded)
        XCTAssertEqual(folded.children.count, 1)                          // body preserved when folded
        guard case .paragraph(let p) = folded.children[0] else { return XCTFail() }
        XCTAssertEqual(p.text, "body")
        um.undo()
        guard case .details(let back) = v.currentBlocks()[0] else { return XCTFail() }
        XCTAssertTrue(back.expanded)                                      // single undo restores expanded
    }

    func test_toggleFold_expandsAFoldedBlock() {
        let v = seeded(false)
        XCTAssertEqual(detailsBox(v).children.boxes.count, 1)             // folded → title only (body off-axis)
        v.toggleDetailsExpanded(box: detailsBox(v))
        guard case .details(let d) = v.currentBlocks()[0] else { return XCTFail() }
        XCTAssertTrue(d.expanded)
        XCTAssertEqual(detailsBox(v).children.boxes.count, 2)             // expanded → title + body box realized
    }

    /// A details box FOLLOWED by a body paragraph, so a selection can sit outside the folded box and
    /// the fold's size delta actually moves it. `DetailsBoxFoldTests`' other helper seeds the box alone.
    private func seededWithFollowingParagraph(_ expanded: Bool) -> DocumentCanvasView {
        let v = DocumentCanvasView()
        let d = DetailsBlock(id: BlockID("d"), title: [TextRun(text: "T")],
                             children: [.paragraph(ParagraphBlock(id: BlockID("b"), runs: [TextRun(text: "body")]))],
                             expanded: expanded)
        v.setBlocks([.details(d), .paragraph(ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "after text")]))],
                    width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 600); v.layoutIfNeeded()
        return v
    }

    /// TASK 39 STEP 0a — the PIN Task 38 owed. `toggleDetailsExpanded`'s caret-outside arm returns
    /// `.range(remap(beforeAnchor), remap(beforeHead))`, and the mechanical simplification
    /// `.caret(at: remap(beforeHead))` compiles, reads plausibly, and passed the WHOLE 2630-case suite
    /// byte-identically when Task 38 built it (recorded at the arm itself, in `+Details.swift`).
    ///
    /// **This is a CHARACTERIZATION test, not a design decision.** The oracle is `e626bbd2fc`, the
    /// pre-conversion tree, where this arm was the raw pair `anchor = remap(beforeAnchor);
    /// head = remap(beforeHead)` — so the expectation below is what that pair produced, read off that
    /// commit, not a judgement about what folding ought to do (Global Constraint 1).
    ///
    /// **The two spellings differ in EXACTLY ONE state** — a NON-COLLAPSED selection lying OUTSIDE the
    /// folded box — so a test that seeds a collapsed caret, or a selection inside the box, passes under
    /// both and is vacuous (Rule 16). Hence: a following paragraph, a range in it, and BOTH endpoints
    /// asserted. The `XCTAssertNotEqual` is not decoration: without a real size delta the `remap` half
    /// of the arm would be untested even though the `.caret` mutation still failed.
    ///
    /// Proven red against `return .caret(at: remap(beforeHead))` (Task 39; the mutation was confirmed
    /// present in `+Details.swift` before the red was believed — Rule 19).
    func test_fold_withARangeSelectionOutsideTheBox_preservesBOTHEndpoints() {
        let v = seededWithFollowingParagraph(true)
        let beforeStart = v.boxes[1].textStart
        v.setSelectionForTesting(anchor: beforeStart + 1, head: beforeStart + 4)
        v.toggleDetailsExpanded(box: detailsBox(v))
        let newStart = v.boxes[1].textStart
        XCTAssertNotEqual(newStart, beforeStart, "folding must shift the following block, else remap() is untested")
        XCTAssertEqual(v.anchor, newStart + 1, "the ANCHOR is remapped and kept — not collapsed onto the head")
        XCTAssertEqual(v.head, newStart + 4)
    }

    /// `.range` does not normalize (see `RichTextInputCaretOutcome.range`), and neither did the raw pair:
    /// a reversed drag stays reversed. This also fails under any normalizing spelling, not just `.caret`.
    func test_fold_withAReversedRangeOutsideTheBox_keepsItReversed() {
        let v = seededWithFollowingParagraph(true)
        let beforeStart = v.boxes[1].textStart
        v.setSelectionForTesting(anchor: beforeStart + 4, head: beforeStart + 1)
        v.toggleDetailsExpanded(box: detailsBox(v))
        let newStart = v.boxes[1].textStart
        XCTAssertNotEqual(newStart, beforeStart)
        XCTAssertEqual(v.anchor, newStart + 4)
        XCTAssertEqual(v.head, newStart + 1)
    }

    func test_chevronTap_togglesFold() {
        let v = seeded(true)
        v.becomeFirstResponder()
        let box = detailsBox(v)
        let chevron = box.chevronRect()
        v.performSingleTapForTesting(at: CGPoint(x: chevron.midX, y: chevron.midY))
        guard case .details(let d) = v.currentBlocks()[0] else { return XCTFail() }
        XCTAssertFalse(d.expanded)                                        // a chevron tap folded it
    }
}
#endif
