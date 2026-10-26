#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

@available(iOS 16.0, *)
final class DocumentRevisionTests: XCTestCase {
    private func makeCanvas(_ texts: [String] = ["Alpha", "Beta"]) -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setParagraphs(texts.enumerated().map {
            ParagraphBlock(id: BlockID("p\($0.offset)"), runs: [TextRun(text: $0.element)])
        }, width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 300); v.layoutIfNeeded()
        return v
    }

    // MARK: revision

    func test_editingBlock_bumpsRevisionExactlyOnce_evenForANoOpBody() {
        let v = makeCanvas()
        let before = v.documentRevision
        v.editing { .unchanged }
        XCTAssertEqual(v.documentRevision, before + 1)
    }

    func test_insertText_bumpsRevisionExactlyOnce() {
        let v = makeCanvas()
        v.setCaret(global: v.boxes[0].textStart + 1)
        let before = v.documentRevision
        v.insertText("x")
        XCTAssertEqual(v.documentRevision, before + 1)
    }

    func test_setBlocks_bumpsRevision() {
        let v = makeCanvas()
        let before = v.documentRevision
        v.setBlocks([.paragraph(ParagraphBlock(id: BlockID("q"), runs: [TextRun(text: "Gamma")]))], width: 300)
        XCTAssertEqual(v.documentRevision, before + 1)
    }

    /// TASK 39 — the Step-2 gate did not cover the Step-2 SITE, so this adds the coverage.
    /// `setBlocks`'s selection clamp is a PER-ENDPOINT clamp: the raw pair it replaces was
    /// `anchor = min(anchor, documentSize); head = min(head, documentSize)`, so an endpoint that still
    /// fits is left alone and a surviving RANGE stays a range. The mechanical simplification
    /// `.caret(at: min(head, documentSize))` collapses it, and — measured, full `Scripts/iostest.sh`
    /// with that spelling built — **NOTHING in the suite failed**. It was axis 2 of the plan's
    /// blind-axes block with no pin at all; these two tests are the pin.
    ///
    /// The distinguishing state needs ONE endpoint inside the shrunken document and one outside it
    /// (Rule 16): with both outside, the two spellings agree, and the test would be vacuous. The two
    /// `XCTAssert{Less,Greater}Than` lines assert exactly that precondition rather than assuming it.
    func test_setBlocks_clampsEachSelectionEndpointIndependently_soASurvivingRangeSurvives() {
        let v = makeCanvas(["AlphaAlphaAlpha", "BetaBetaBeta"])
        let bigHead = v.documentSize
        v.setSelectionForTesting(anchor: 1, head: bigHead)
        v.setBlocks([.paragraph(ParagraphBlock(id: BlockID("q"), runs: [TextRun(text: "Gamma")]))], width: 300)
        XCTAssertLessThan(1, v.documentSize, "the anchor must still fit, else both endpoints clamp alike")
        XCTAssertGreaterThan(bigHead, v.documentSize, "the head must NOT still fit, else nothing clamps")
        XCTAssertEqual(v.anchor, 1, "an endpoint that still fits is left alone")
        XCTAssertEqual(v.head, v.documentSize, "an endpoint past the new end is clamped to it")
        XCTAssertNotEqual(v.anchor, v.head, "the surviving selection is a RANGE, not a collapsed caret")
    }

    /// The reversed twin: the clamp does not normalize, so `anchor > head` stays that way.
    func test_setBlocks_clampPreservesAReversedSelection() {
        let v = makeCanvas(["AlphaAlphaAlpha", "BetaBetaBeta"])
        let bigAnchor = v.documentSize
        v.setSelectionForTesting(anchor: bigAnchor, head: 1)
        v.setBlocks([.paragraph(ParagraphBlock(id: BlockID("q"), runs: [TextRun(text: "Gamma")]))], width: 300)
        XCTAssertGreaterThan(bigAnchor, v.documentSize)
        XCTAssertEqual(v.anchor, v.documentSize)
        XCTAssertEqual(v.head, 1)
    }

    func test_setMarkedText_bumpsRevision() {
        let v = makeCanvas()
        v.setCaret(global: v.boxes[0].textStart + 1)
        let before = v.documentRevision
        v.setMarkedText("か", selectedRange: NSRange(location: 1, length: 0))
        XCTAssertEqual(v.documentRevision, before + 1)
    }

    func test_dismissPrediction_bumpsRevision() {
        let v = makeCanvas()
        v.setCaret(global: v.boxes[0].textStart + 1)
        v.setMarkedText("ing", selectedRange: NSRange(location: 0, length: 0))   // prediction shape
        XCTAssertTrue(v.markedTextIsPrediction)
        let before = v.documentRevision
        v.dismissPrediction()
        XCTAssertEqual(v.documentRevision, before + 1)
    }

    func test_insertTextWhileMarked_commitsAndBumpsRevisionExactlyOnce() {
        let v = makeCanvas()
        v.setCaret(global: v.boxes[0].textStart + 1)
        v.setMarkedText("か", selectedRange: NSRange(location: 1, length: 0))
        let before = v.documentRevision
        v.insertText("。")
        XCTAssertEqual(v.documentRevision, before + 1)
    }

    /// D16: character formatting DOES go through `editing { }` (+CharacterFormat.swift:40),
    /// so it is covered by the `editing` bump. There is no revision gap here.
    func test_boldToggle_bumpsRevision() {
        let v = makeCanvas()
        v.setSelectionForTesting(anchor: v.boxes[0].textStart, head: v.boxes[0].textStart + 3)
        let before = v.documentRevision
        v.toggleBold()
        XCTAssertEqual(v.documentRevision, before + 1)
    }

    // MARK: the two documented DOUBLE-bump paths (deviation D31)

    /// `replaceRange` calls `setBlocks` from INSIDE `editing { }` (+Editing.swift:840-846), so the
    /// two bump sites both fire for one logical mutation. Pinned, not repaired: the revision's
    /// contract is "strictly increasing per content mutation", never "exactly one per mutation".
    func test_replaceRange_bumpsRevisionTwice_documented() {
        let v = makeCanvas()
        let s = v.boxes[0].textStart
        let before = v.documentRevision
        v.replaceRange(globalFrom: s, globalTo: s + 3,
                       with: Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("r"),
                                                                         runs: [TextRun(text: "Zed")]))]))
        XCTAssertEqual(v.documentRevision, before + 2,
                       "editing{} bumps once and the nested setBlocks bumps again — deviation D31")
    }

    /// Same shape via the clipboard splice: `pasteFragment` is `editing { _ = spliceFragmentInEditing(fragment) }`
    /// (+Clipboard.swift:105-108) whose body calls `setBlocks` (+Clipboard.swift:133 or :140).
    func test_pasteFragment_bumpsRevisionTwice_documented() {
        let v = makeCanvas()
        v.setCaret(global: v.boxes[0].textStart + 1)
        let before = v.documentRevision
        v.pasteFragment(Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("f"),
                                                                    runs: [TextRun(text: "Frag")]))]))
        XCTAssertEqual(v.documentRevision, before + 2, "deviation D31")
    }

    // MARK: what must NOT bump the revision

    func test_pureSelectionMove_doesNotBumpRevision() {
        let v = makeCanvas()
        let before = v.documentRevision
        v.setCaret(global: v.boxes[1].textStart)
        XCTAssertEqual(v.documentRevision, before)
    }

    func test_widthOnlyReflow_doesNotBumpRevision() {
        let v = makeCanvas()
        let before = v.documentRevision
        v.setParagraphsWidthIfNeeded(260)
        XCTAssertEqual(v.documentRevision, before)
    }

    func test_layoutContent_doesNotBumpRevision() {
        let v = makeCanvas()
        let before = v.documentRevision
        v.layoutContent()
        XCTAssertEqual(v.documentRevision, before)
    }

    func test_revisionIsMonotonicAcrossManyEdits() {
        let v = makeCanvas()
        v.setCaret(global: v.boxes[0].textStart)
        var last = v.documentRevision
        for _ in 0..<200 {
            v.insertText("a")
            XCTAssertGreaterThan(v.documentRevision, last)
            last = v.documentRevision
        }
    }

    // MARK: layout generation

    func test_layoutContent_bumpsLayoutGeneration() {
        let v = makeCanvas()
        let before = v.layoutGeneration
        v.layoutContent()
        XCTAssertGreaterThan(v.layoutGeneration, before)
    }

    func test_viewportDidChange_bumpsLayoutGeneration() {
        let v = makeCanvas()
        let before = v.layoutGeneration
        v.viewportDidChange()
        XCTAssertGreaterThan(v.layoutGeneration, before)
    }

    func test_contentMutation_alsoBumpsLayoutGeneration() {
        let v = makeCanvas()
        v.setCaret(global: v.boxes[0].textStart)
        let before = v.layoutGeneration
        v.insertText("z")
        XCTAssertGreaterThan(v.layoutGeneration, before)
    }
}
#endif
