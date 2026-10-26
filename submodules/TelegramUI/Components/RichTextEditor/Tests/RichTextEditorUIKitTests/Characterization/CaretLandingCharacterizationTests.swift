#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// TASK 36b, STEP 2 — the primitive callers whose caret comes from the primitive rather than from an
/// `anchor =` of their own, so the Task-35 deprecation worklist cannot see them. (On the base commit
/// it arrived as `applyReplace`'s SIDE EFFECT; since Task 36c the primitive returns it and the caller
/// applies it with `applyCaretOutcome` on the next instruction. The landing is byte-identical, which
/// is what these tests exist to hold.)
/// Written and run BEFORE the conversion; every expectation below records what the code did on the
/// base commit, not what it "should" do.
///
/// **THERE ARE THREE, NOT TWO.** The task brief names `dismissPrediction()` and `insertText`'s
/// marked-commit branch. The third is `legacySetMarkedText`'s provisional text edit
/// (`+MarkedText.swift`, inside `notifyingContentChange`) — the IME composition path — which carries
/// the same in-source marker (`bumpDocumentRevision()   // applyReplaceOutcome here is OUTSIDE editing { }`)
/// the brief used to find the other two. All three kept working unchanged through Task 36b because
/// the transitional wrapper applied the outcome itself. **TASK 36c RESULT: all three now call
/// `applyCaretOutcome(applyReplaceOutcome(…))` explicitly, and this suite is what says their landings
/// did not move.**
///
/// # THE THREE ARE NOT EQUIVALENT, and the difference decides what can be asserted
///
/// `dismissPrediction` and the marked-commit branch leave `applyReplaceOutcome`'s caret STANDING — nothing
/// downstream writes it — so a post-hoc `v.head` assertion pins them, PROVIDED the fixture puts the
/// caret somewhere else first. The brief's two snippets did not, and both were vacuous when run:
///
///   * `dismissPrediction` — a live PREDICTION always has the caret AT the ghost start already
///     (`markedTextIsPrediction` is *defined* as `selectedRange == {0,0}`, and `legacySetMarkedText`
///     then seats the caret at `lo + selectedRange.location == lo == m.from`). So the brief's
///     `XCTAssertEqual(v.head, ghostStart)` reads 3 == 3 before the call as well as after. **The
///     measured control failed exactly there**, which is how this was found rather than argued.
///     Reachable app states cannot separate the two, so the discriminating arm below seeds the
///     caret through the silent test seam — a state the app does not produce, constructed for the
///     one purpose of proving the write exists (Rule 19).
///   * the marked commit — the brief composes one character and commits one character, so
///     `m.from + 1` is both the pre-call caret and the post-call caret. A TWO-character composition
///     committed by ONE character separates them, and is an ordinary IME sequence.
///
/// `legacySetMarkedText` does **not**: four statements after the content bracket it opens an
/// unconditional selection bracket that writes BOTH endpoints from `lo + selectedRange.location`,
/// deriving nothing from the value `applyReplaceOutcome` left. A post-hoc `v.head` there would pin the
/// SELECTION BRACKET and would pass against a build in which `applyReplaceOutcome` claimed nothing at all —
/// Rule 16, one step removed. The intermediate caret is observable only from INSIDE the content
/// bracket, so that case is pinned through the recorder at `textDidChange`.
///
/// **And it is already pinned there.** `MarkedTextTraceCharacterizationTests
/// .test_compositionBeginUpdateCommit_traceAndRevisions` asserts the same fact as part of a six-event
/// golden trace, and its own comment (1) states the mechanism. This test is not that test's duplicate:
/// it isolates the one fact, names the caller Task 36c has to convert, and would survive that golden
/// trace being re-recorded for an unrelated reason.
@available(iOS 16.0, *)
final class CaretLandingCharacterizationTests: XCTestCase {
    private func makeCanvas() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setParagraphs([ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "Alpha")])], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 300); v.layoutIfNeeded()
        return v
    }

    /// `applyReplaceOutcome(globalFrom: m.from, globalTo: m.to, text: "")` — deleting the ghost leaves the
    /// caret at the start of what it removed.
    ///
    /// **CHARACTERIZATION FIRST, then the discriminating arm.** Arm 1 records the reachable truth:
    /// the caret is at the ghost start before the call and at the ghost start after it, so **this
    /// caller's caret write is unobservable in every state the app can reach**. Task 36c still has
    /// to convert it — arm 2 constructs the state in which the write is visible and pins where it
    /// lands, so a 36c that drops the claim fails here instead of passing by coincidence.
    func test_dismissPredictionLandsTheCaretAtTheGhostStart() {
        // Arm 1 — the reachable state.
        let v = makeCanvas()
        let s = v.boxes[0].textStart
        v.setCaret(global: s + 2)
        v.setMarkedText("XYZ", selectedRange: NSRange(location: 0, length: 0))   // prediction shape
        XCTAssertTrue(v.markedTextIsPrediction, "control: the fixture must actually be a PREDICTION — " +
                      "dismissPrediction is a no-op for a plain composition")
        guard let ghost = v.markedRange else { return XCTFail("control: a ghost must be showing") }
        XCTAssertEqual(v.head, ghost.from,
                       "a live prediction ALREADY parks the caret at the ghost start — recorded so " +
                       "the assertion after the call is not mistaken for a discriminating one")
        v.dismissPrediction()
        XCTAssertEqual(v.head, ghost.from, "caret -> m.from (+MarkedText.swift, dismissPrediction)")
        XCTAssertEqual(v.anchor, v.head, "and collapsed")

        // Arm 2 — the same call from a caret the app never produces, so the write is visible.
        let w = makeCanvas()
        let t = w.boxes[0].textStart
        w.setCaret(global: t + 2)
        w.setMarkedText("XYZ", selectedRange: NSRange(location: 0, length: 0))
        guard let ghost2 = w.markedRange else { return XCTFail("control: a ghost must be showing") }
        w.setSelectionForTesting(anchor: t, head: t)   // silent seam — no finalize, the ghost stays live
        XCTAssertNotEqual(w.head, ghost2.from, "control: the caret is now somewhere else")
        w.dismissPrediction()
        XCTAssertEqual(w.head, ghost2.from,
                       "the caret claim is real and lands at m.from — Task 36c reproduced it when " +
                       "it deleted the transitional wrapper, and this arm is what says so")
        XCTAssertEqual(w.anchor, w.head)
    }

    /// `applyReplaceOutcome(globalFrom: m.from, globalTo: m.to, text: text)` — committing a composition with
    /// a confirming keystroke leaves the caret at the END of the replacement, which for a TWO-character
    /// composition committed by ONE character is one unit BEFORE where the caret already stood.
    func test_markedCommitLandsTheCaretAtTheEndOfTheCommittedText() {
        let v = makeCanvas()
        let s = v.boxes[0].textStart
        v.setCaret(global: s + 5)
        v.setMarkedText("\u{304B}\u{304D}", selectedRange: NSRange(location: 2, length: 0))
        guard let marked = v.markedRange else { return XCTFail("control: a composition must be live") }
        XCTAssertEqual(v.head, marked.from + 2,
                       "control: the composition parks the caret at its END (2 units in), so the " +
                       "post-commit expectation of +1 below is a value the caret does not already hold")

        v.insertText("\u{3002}")

        XCTAssertEqual(v.head, marked.from + 1,
                       "caret -> end of the replacement (+UITextInput.swift, legacyInsertText's " +
                       "marked-commit branch)")
        XCTAssertEqual(v.anchor, v.head, "and collapsed")
        XCTAssertNil(v.markedRange, "control: the composition really was committed")
    }

    /// THE THIRD CALLER. The provisional composition edit's caret is visible only for the width of the
    /// `notifyingContentChange` bracket, so it is read off the recorder's `textDidChange` event rather
    /// than off the canvas afterwards. See the header for why a post-hoc read would be vacuous here —
    /// and the last assertion constructs that vacuity explicitly (Rule 19).
    func test_setMarkedTextProvisionalEditLandsTheCaretAtTheEndOfTheProvisionalText() {
        let v = makeCanvas()
        let s = v.boxes[0].textStart
        v.setCaret(global: s + 5)
        let recorder = RichTextInputEventRecorder()
        recorder.attach(canvas: v)
        recorder.reset()

        v.setMarkedText("\u{304B}", selectedRange: NSRange(location: 0, length: 0))

        guard let textDid = recorder.events.first(where: { $0.kind == .textDidChange }) else {
            return XCTFail("expected a textDidChange from the provisional edit\n\(recorder.trace())")
        }
        XCTAssertEqual(textDid.head, s + 6,
                       "inside the content bracket the caret has ALREADY moved to the end of the " +
                       "provisional text — that is the primitive's claim, applied by the caller on the " +
                       "next instruction, and it is the whole of this caller's caret " +
                       "(+MarkedText.swift, legacySetMarkedText)\n\(recorder.trace())")
        XCTAssertEqual(textDid.anchor, s + 6)
        XCTAssertEqual(v.head, s + 5,
                       "…and it does NOT survive: the selection bracket four statements later writes " +
                       "lo + selectedRange.location = s+5 over it. An assertion on v.head after the " +
                       "call would therefore pin the SELECTION BRACKET and pass against a build in " +
                       "which the provisional edit claimed nothing at all")
    }
    // MARK: - FIX ROUND 1 — the call-site landings, and the four that no suite could see

    /// A paragraph `abcd` with `bc` selected: the shape that separates "the delete's caret was
    /// applied" from "it was deferred", because after the delete the paragraph is `ad` and the caret
    /// is MID-paragraph (local 1). The pre-existing suites all select the WHOLE paragraph — e.g.
    /// `EmojiEditingTests.test_insertEmoji_replacesNonEmptySelection` selects `ab` out of `ab` — which
    /// leaves a length-0 paragraph where a stale caret clamps to the same place the live one would
    /// reach. That is exactly why they stayed green under the reviewer's simulated defer.
    private func canvasWithBCSelected() -> (DocumentCanvasView, Int) {
        let v = DocumentCanvasView()
        v.setBlocks([.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "abcd")]))], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 600); v.layoutIfNeeded()
        let s = v.boxes[0].textStart
        v.setSelectionForTesting(anchor: s + 1, head: s + 3)   // select "bc"
        return (v, s)
    }

    private func paragraphTexts(_ v: DocumentCanvasView) -> [String] {
        v.currentBlocks().map { block in
            if case let .paragraph(p) = block { return p.text }
            return "<\(String(describing: block).prefix(12))>"
        }
    }

    /// **THE PATH THE REVIEWER WORKED OUT END TO END, now pinned.** `insertDetailsBlock` deletes the
    /// selection and then re-resolves `activeStack(at: head)` to decide replace / SPLIT / insert-before
    /// / insert-after. With the delete's caret applied it sees `local == 1` in a 2-character paragraph
    /// and SPLITS. With it deferred, `head` is still `s+3`, which no longer lies in the shrunken
    /// paragraph's region, so `active.local` clamps to `p.textLength`, `active.local < p.textLength`
    /// is false, and the block is APPENDED AFTER `ad` instead of landing between `a` and `d`.
    ///
    /// A silent, user-visible wrong outcome. `DetailsBoxInsertTests` does not catch it: every one of
    /// its selection cases is on an empty or wholly-selected paragraph.
    func test_insertDetailsBlockOverAMidParagraphSelectionSplitsTheParagraph() {
        let (v, _) = canvasWithBCSelected()
        v.insertDetailsBlock()
        let blocks = v.currentBlocks()
        XCTAssertEqual(blocks.count, 3, "split, not append — got \(paragraphTexts(v))")
        guard blocks.count == 3 else { return }
        guard case .paragraph(let first) = blocks[0] else { return XCTFail("blocks[0] must be the head half") }
        guard case .details = blocks[1] else { return XCTFail("the details block must land BETWEEN the halves") }
        guard case .paragraph(let last) = blocks[2] else { return XCTFail("blocks[2] must be the tail half") }
        XCTAssertEqual(first.text, "a")
        XCTAssertEqual(last.text, "d")
    }

    /// `insertButtonRow` shares `insertDetailsBlock`'s idiom verbatim. `ButtonRowBoxTests` is green
    /// under the simulated defer for the same reason.
    func test_insertButtonRowOverAMidParagraphSelectionSplitsTheParagraph() {
        let (v, _) = canvasWithBCSelected()
        v.insertButtonRow()
        let blocks = v.currentBlocks()
        XCTAssertEqual(blocks.count, 3, "split, not append — got \(paragraphTexts(v))")
        guard blocks.count == 3 else { return }
        guard case .paragraph(let first) = blocks[0] else { return XCTFail("blocks[0] must be the head half") }
        guard case .buttonRow = blocks[1] else { return XCTFail("the button row must land BETWEEN the halves") }
        guard case .paragraph(let last) = blocks[2] else { return XCTFail("blocks[2] must be the tail half") }
        XCTAssertEqual(first.text, "a")
        XCTAssertEqual(last.text, "d")
    }

    /// `insertEmoji` reads the caret back differently — `leafRegion(containingGlobal: head)` and an
    /// `snapToRenderable` fallback rather than `activeStack` — so a stale caret lands the atom at the
    /// paragraph END instead of between `a` and `d`. Same class, different symptom.
    func test_insertEmojiOverAMidParagraphSelectionLandsBetweenTheHalves() {
        let (v, _) = canvasWithBCSelected()
        v.insertEmoji(id: "star", altText: nil)
        XCTAssertEqual(paragraphTexts(v), ["a\u{FFFC}d"],
                       "the emoji atom replaces the selection IN PLACE; \"ad\u{FFFC}\" is the deferred-caret answer")
    }

    /// `insertFormula` shares `insertEmoji`'s idiom. **This is the fourth unpinned site and the review
    /// names three** — `+Formula.swift:31` has no suite of its own; its only tests live in
    /// `EmojiEditingTests`, which the reviewer measured green under the simulated defer, so the
    /// formula path was covered by that same negative result without being named.
    func test_insertFormulaOverAMidParagraphSelectionLandsBetweenTheHalves() {
        let (v, _) = canvasWithBCSelected()
        v.mapper.formulaRenderer = { context in
            let size = CGSize(width: max(12.0, CGFloat((context.latex as NSString).length) * 4.0), height: 14.0)
            let image = UIGraphicsImageRenderer(size: size).image { _ in }
            return RichTextFormulaRenderResult(image: image, size: size, ascent: 10.0, descent: 4.0)
        }
        v.insertFormula(latex: "x^2")
        XCTAssertEqual(paragraphTexts(v), ["a\u{FFFC}d"],
                       "the formula atom replaces the selection IN PLACE; \"ad\u{FFFC}\" is the deferred-caret answer")
    }

    // MARK: - FIX ROUND 1, Ruling 2 — the Select-All -> Backspace caret, which no suite asserted

    /// **`applySelectionReplaceOutcome`'s exit 1, whose LANDING the entire suite left unpinned.** The
    /// reviewer applied the brief's `return .unchanged` to exits 1-4 and only exit 2 was caught: every
    /// Select-All -> Backspace test in the package (`CanvasSelectAllTableDeleteTests
    /// .assertSingleEmptyParagraph`, `BlockQuoteEditTests.test_selectAll_backspace_*`) asserts DOCUMENT
    /// STRUCTURE and never touches the caret.
    ///
    /// What `.unchanged` would have left: the pre-edit RANGE (`0 … oldDocumentSize`) standing over a
    /// document that is now one empty paragraph — an uncollapsed, out-of-range selection. Structure
    /// assertions cannot see it. This is the test that can.
    func test_selectAllBackspaceCollapsesTheCaretIntoTheResettingParagraph() {
        let v = DocumentCanvasView()
        v.setBlocks([.paragraph(ParagraphBlock(id: BlockID("h"), style: .heading1, runs: [TextRun(text: "Title")])),
                     .paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Body text")]))], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 600); v.layoutIfNeeded()
        let sizeBefore = v.documentSize
        v.setSelectionForTesting(anchor: 0, head: sizeBefore)
        XCTAssertGreaterThan(sizeBefore, 2, "control: the pre-edit selection must be a real, wide range")

        v.deleteBackward()

        XCTAssertEqual(v.currentBlocks().count, 1, "control: the reset really happened (what the suite already pinned)")
        let landing = v.boxes[0].textStart
        XCTAssertEqual(v.head, landing, "the caret collapses INTO the fresh empty body paragraph")
        XCTAssertEqual(v.anchor, landing,
                       "…and it is COLLAPSED. `.unchanged` here would leave the pre-edit range " +
                       "(0…\(sizeBefore)) standing over a one-paragraph document")
    }
}
#endif
