#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// `replace(_:withText:)` calls detectAutocorrection(oldText:newText:) (+Autocorrect.swift:12,
/// invoked at +UITextInput.swift:56) because UIKit does not declare the origin of a replacement.
/// This heuristic is exactly what RichTextInputMutationOrigin.autocorrection must reproduce in
/// Phase 2 — pin it before the mutation intent enum exists. This suite adds the (trace, revision)
/// sequence around `replace(_:withText:)` that `T/AutocorrectUnderlineTests.swift` never records.
@available(iOS 16.0, *)
final class AutocorrectOriginCharacterizationTests: XCTestCase {
    private var recorder: RichTextInputEventRecorder!

    private func makeCanvas(_ text: String) -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setParagraphs([ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: text)])], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 300); v.layoutIfNeeded()
        // No `undoManagerOverride` here (unlike the marked-text suite): these tests don't need
        // `groupsByEvent = false` fixture semantics, and `replace(_:withText:)` runs through
        // `editing{}` which registers undo via the canvas's default `ownUndoManager`
        // (`groupsByEvent == true`, Foundation's default) — no explicit undo-group bracket needed.
        recorder = RichTextInputEventRecorder(); recorder.attach(canvas: v); recorder.reset()
        return v
    }

    // Pure-classification coverage of detectAutocorrection(oldText:newText:) already exists and is not
    // duplicated here: AutocorrectUnderlineTests.test_detectAutocorrection_singleTokenDiffer_returnsOriginal
    // (:20-23) and .test_detectAutocorrection_identical_isNil (:24-27). This suite pins only what those
    // cannot: the trace/revision sequence around a correction.

    /// Overlaps (but does not duplicate) `AutocorrectUnderlineTests.test_applyCorrectionFlag_flagsAndStashesOriginal_bypassingCaretWord`
    /// (:33-40) and `.test_replace_autocorrect_flagsCorrection_endToEnd` (:49-56) on the `spellResults`
    /// assertion — that part is kept only as a precondition for the value this test actually adds: the
    /// recorder trace around the correction. `replace(_:withText:)` really does run an `editing{}` bracket
    /// (+UITextInput.swift:50-67), so — unlike the pure-classification tests above — it CAN carry trace
    /// value, and does: the trace is byte-identical to a plain (non-autocorrecting) editing{} bracket (see
    /// `test_replaceWithText_bumpsTheRevisionExactlyOnce_andTracesAsAPlainEditingBracket` below and
    /// `test_replaceWithIdenticalText_stillEditsButFlagsNoCorrection`) — `applyCorrectionFlag` (called AFTER
    /// `editing{}` returns) leaves no additional recorder-visible event even though it mutates `spellResults`.
    func test_replaceWithText_flagsTheCorrectedRange() {
        let v = makeCanvas("teh cat")
        let s = v.boxes[0].textStart
        v.replace(DocumentTextRange(DocumentTextPosition(s), DocumentTextPosition(s + 3)), withText: "the")
        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "the cat")
        XCTAssertFalse(v.spellResults.isEmpty, "an autocorrection records a correction flag")
        XCTAssertEqual(recorder.kinds, [.textWillChange, .selectionWillChange, .selectionDidChange,
                                         .textDidChange, .canvasContentSizeChanged, .canvasSelectionChanged],
                       "the correction flag adds no trace event beyond the plain editing{} bracket")
    }

    func test_replaceWithText_bumpsTheRevisionExactlyOnce_andTracesAsAPlainEditingBracket() {
        let v = makeCanvas("teh cat")
        let s = v.boxes[0].textStart
        let before = v.documentRevision
        v.replace(DocumentTextRange(DocumentTextPosition(s), DocumentTextPosition(s + 3)), withText: "the")
        XCTAssertEqual(v.documentRevision, before + 1)
        // `replace(_:withText:)` is `editing { applySelectionReplaceOutcome(...) }` — the standard six-event
        // editing{} bracket (established fact from Task 3/6) — followed by `applyCorrectionFlag`, which
        // sets no recorder-visible state (only `spellResults` + `setNeedsSpellUnderlineDisplay`). So the
        // trace ends at the editing{} bracket; the correction flag leaves NO additional trace event, even
        // though it DOES mutate `spellResults` (pinned separately above via `test_replaceWithText_flagsTheCorrectedRange`).
        XCTAssertEqual(recorder.kinds, [.textWillChange, .selectionWillChange, .selectionDidChange,
                                         .textDidChange, .canvasContentSizeChanged, .canvasSelectionChanged])
    }

    /// `replace(_:withText:)` on a NON-autocorrection-shaped replacement (identical text) still routes
    /// through the same `editing{}` bracket and bumps the revision — `detectAutocorrection` only gates
    /// the correction FLAG (`spellResults`), never the edit itself. Pins the boundary between "this
    /// replace is classified as an autocorrection" and "this replace happened at all".
    func test_replaceWithIdenticalText_stillEditsButFlagsNoCorrection() {
        let v = makeCanvas("the cat")
        let s = v.boxes[0].textStart
        let before = v.documentRevision
        v.replace(DocumentTextRange(DocumentTextPosition(s), DocumentTextPosition(s + 3)), withText: "the")
        XCTAssertEqual(v.documentRevision, before + 1, "editing{} still runs and bumps the revision")
        XCTAssertTrue(v.spellResults.isEmpty, "an identical replace is not classified as an autocorrection, so no flag is recorded")
        XCTAssertEqual(recorder.kinds, [.textWillChange, .selectionWillChange, .selectionDidChange,
                                         .textDidChange, .canvasContentSizeChanged, .canvasSelectionChanged])
    }
}
#endif
