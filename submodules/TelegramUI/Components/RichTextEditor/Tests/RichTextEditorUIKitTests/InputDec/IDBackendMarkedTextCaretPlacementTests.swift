#if canImport(UIKit)
import RichTextInputDecObjC
import UIKit
import XCTest
@testable import RichTextEditorUIKit

/// Task D4d — **`setMarkedText(_:selectedRange:)`'s `selectedRange` argument must reach the
/// document.**
///
/// D4b's differential corpus found a UNIFORM `+2` selection offset at the `offered` checkpoint of
/// every one of the nine `inline-prediction-ios26.5-v1` scenarios: stock UIKit reports the caret at
/// 33 (the START of the just-offered marked text "to"), `.inputDec` reports 35 (its END). `+2` in
/// all nine — including the three `interior-*` ones, which cross no paragraph boundary — because
/// the marked text is the literal 2-character string `"to"` every time. A structural-vs-plain-text
/// axis fault compounds PER BOUNDARY and would have differed between the `interior-*` and
/// `*-boundary-*` scenarios; a constant equal to the marked text's own length is a dropped
/// `selectedRange`, not an axis error.
///
/// **The mechanism, with the file:line:** `IDTextEditorBackendIntent.mutation(for:range:text:
/// selection:)` built its `.setMarkedText` case with
/// `selectedRangeInMarkedText: NSRange(location: text.utf16.count, length: 0)` — a FABRICATED
/// end-of-marked-text caret, because the real `selectedRange` never travelled that far. It could
/// not: `+TextBackend.swift`'s `setMarkedText(_:selectedRange:)` forwards it into
/// `kernelInput?.setMarkedText(text, selectedRange:)`, the private controller then drives the edit
/// back through `TGRichTextInputDecTextStorageFacade.replaceCharactersInRange:withString:` — a RAW
/// range replace that carries no marked-text-relative caret at all — and the bridge reconstructs
/// the mutation from `(range, text, intent)` alone. `DocumentCanvasView.legacySetMarkedText`
/// (`+MarkedText.swift`) honours whatever it is handed, placing the caret at
/// `lo + selectedRange.location`, so the fabricated `{2, 0}` landed the caret 2 past the start.
///
/// The value is doubly load-bearing: `legacySetMarkedText` also derives
/// `isPrediction: selectedRange.location == 0 && selectedRange.length == 0` from it, which is what
/// `refreshPredictionStyling()` paints the grey inline-prediction ghost from. Fabricating
/// `{count, 0}` made every system inline prediction look like a CJK composition.
///
/// The fix carries the argument down as a latched value beside the `.markedText` intent
/// (`IDTextEditorBackend.latchMarkedTextIntent(selectedRange:)`), exactly like the intent itself
/// travels; the fabricated end-of-text value survives ONLY as the fallback for a `.markedText`
/// transaction that arrives with no latch, which is what CJK composition wants anyway.
///
/// Gated like every other `.inputDec` suite: `isSupported()` is false off the certified band.
@available(iOS 17.0, *)
@MainActor
final class IDBackendMarkedTextCaretPlacementTests: XCTestCase {
    override func setUpWithError() throws {
        try XCTSkipUnless(IDTextEditorBackend.isSupported())
    }

    /// Places the caret through the REAL `position(from:offset:)` + `selectedTextRange` pair rather
    /// than `setSelectionForTesting` — same deviation, same reason, as
    /// `IDBackendFormattingThenDeleteTests`/`IDBackendDifferentialTraceTests`: the raw test seam
    /// never touches `state.documentRevision`, which silently rejects every subsequent `.inputDec`
    /// mutation and would make this suite pass by no-oping.
    private func caret(_ canvas: DocumentCanvasView, _ offset: Int) {
        let p = canvas.position(from: canvas.beginningOfDocument, offset: offset)!
        canvas.selectedTextRange = canvas.textRange(from: p, to: p)
    }

    /// The live selection as a `(location, length)` pair on the axis `position(from:offset:)` walks
    /// — the same idiom `DIVERGENCES.md` records for every marked-text assertion in this package
    /// (`offset(from:to:)` against a real `UITextRange`, never a hardcoded number).
    private func selectionOffsets(_ canvas: DocumentCanvasView) -> (location: Int, length: Int)? {
        guard let range = canvas.selectedTextRange else { return nil }
        let location = canvas.offset(from: canvas.beginningOfDocument, to: range.start)
        let length = canvas.offset(from: range.start, to: range.end)
        return (location, length)
    }

    /// **The corpus's own `offered` checkpoint, reduced to one assertion.** A system inline
    /// prediction offers its ghost with `selectedRange {0, 0}` — per `UITextInput`, the caret goes
    /// at offset 0 WITHIN the marked text, i.e. at its START, so the ghost trails the caret. Stock
    /// UIKit reports 33 where the corpus places the caret at 33; this backend reported 35.
    func test_setMarkedTextWithSelectedRangeAtZero_leavesTheCaretAtTheStartOfTheMarkedText() {
        let h = makeBackendHarness(backend: .inputDec, paragraphs: ["Alpha"], width: 300)
        defer { h.tearDown() }
        let canvas = h.canvas

        caret(canvas, 5)   // end of "Alpha"
        canvas.setMarkedText("to", selectedRange: NSRange(location: 0, length: 0))

        XCTAssertEqual(canvas.differentialTopLevelBlockTexts(), ["Alphato"],
                       "the provisional text itself must still land at the caret")
        guard let selection = selectionOffsets(canvas) else {
            return XCTFail("no selection after setMarkedText")
        }
        XCTAssertEqual(selection.location, 5,
                       "selectedRange {0, 0} means the caret goes at offset 0 WITHIN the marked "
                       + "text — its START (5), not its end (7)")
        XCTAssertEqual(selection.length, 0)
    }

    /// **The CONTROL, and the thing that makes the test above about `selectedRange` rather than
    /// about a swapped constant.** CJK/IME composition offers its provisional text with the caret
    /// at the END (`selectedRange {count, 0}`) — the exact value the pre-fix code fabricated
    /// unconditionally — and that placement must be preserved. `cjk-compose-commit`
    /// (`IDBackendDifferentialTraceTests`) drives this same call with this same argument.
    func test_setMarkedTextWithSelectedRangeAtTheEnd_leavesTheCaretAtTheEndOfTheMarkedText() {
        let h = makeBackendHarness(backend: .inputDec, paragraphs: ["Alpha"], width: 300)
        defer { h.tearDown() }
        let canvas = h.canvas

        caret(canvas, 5)
        canvas.setMarkedText("にほ", selectedRange: NSRange(location: 2, length: 0))

        guard let selection = selectionOffsets(canvas) else {
            return XCTFail("no selection after setMarkedText")
        }
        XCTAssertEqual(selection.location, 7,
                       "selectedRange {2, 0} on 2 marked characters is the END of the composition — "
                       + "a CJK composition must keep the caret there")
        XCTAssertEqual(selection.length, 0)
    }

    /// A `selectedRange` with a non-zero LENGTH selects INSIDE the composition. Pins that the whole
    /// range travels, not just its location — `legacySetMarkedText` ends with
    /// `applyCaretOutcome(.range(selStart, selStart + selectedRange.length))`.
    func test_setMarkedTextWithANonEmptySelectedRange_selectsInsideTheMarkedText() {
        let h = makeBackendHarness(backend: .inputDec, paragraphs: ["Alpha"], width: 300)
        defer { h.tearDown() }
        let canvas = h.canvas

        caret(canvas, 5)
        canvas.setMarkedText("abc", selectedRange: NSRange(location: 1, length: 2))

        guard let selection = selectionOffsets(canvas) else {
            return XCTFail("no selection after setMarkedText")
        }
        XCTAssertEqual(selection.location, 6, "1 unit into the composition, which starts at 5")
        XCTAssertEqual(selection.length, 2, "the composition's own selection length must survive")
    }

    /// The corpus's `before-boundary-*` shape: the caret sits at the END of the first paragraph,
    /// immediately before a top-level boundary. The `+2` was IDENTICAL here and in the
    /// single-paragraph case above, which is what ruled out the structural-vs-plain-text axis class
    /// — this test keeps that ruling honest by pinning the boundary-crossing case separately.
    func test_setMarkedTextAtAParagraphBoundary_stillLeavesTheCaretAtTheStartOfTheMarkedText() {
        let h = makeBackendHarness(backend: .inputDec, paragraphs: ["Alpha", "Beta"], width: 300)
        defer { h.tearDown() }
        let canvas = h.canvas

        caret(canvas, 5)   // end of "Alpha", immediately before the paragraph boundary
        canvas.setMarkedText("to", selectedRange: NSRange(location: 0, length: 0))

        XCTAssertEqual(canvas.differentialTopLevelBlockTexts(), ["Alphato", "Beta"],
                       "the composition must not have merged or crossed the boundary")
        guard let selection = selectionOffsets(canvas) else {
            return XCTFail("no selection after setMarkedText")
        }
        XCTAssertEqual(selection.location, 5,
                       "the offset must be the START of the marked text here too — the pre-fix "
                       + "error was a constant +2 (the marked text's length), not a per-boundary "
                       + "axis drift")
        XCTAssertEqual(selection.length, 0)
    }
}
#endif
