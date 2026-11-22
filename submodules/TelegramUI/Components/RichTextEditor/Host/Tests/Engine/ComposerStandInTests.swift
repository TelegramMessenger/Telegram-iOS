import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// R6's terminal gate — a stand-in for `RichTextEditorChatInputNode`, which lives in TelegramUI
/// and cannot be hosted here. It holds `any RichTextEditor` and drives every member of the
/// protocol against BOTH implementations, asserting an observable consequence for each. This
/// proves the PROTOCOL SURFACE answers the same way for both backends; it does not, and cannot,
/// prove the real chat composer works end-to-end — that needs the real composer, which this
/// package cannot host.
///
/// Coverage, member by member (17 of 17 — the protocol has 17 members: `document`, `onChange`,
/// `height(forWidth:)`, four inline toggles, `setParagraphStyle`, `setAlignment`, `setList`,
/// `indent`, `outdent`, `composerSelectedRange`, `composerCaretRect()`, `isEditorFirstResponder`,
/// `resignEditorFirstResponder()`, `selectedText()`):
///   `document`, `height(forWidth:)`, `composerSelectedRange`, `selectedText()`,
///   `setParagraphStyle`: exercised in the first half of `exercise(...)` (this file's original
///   version).
///   `onChange`, `toggleBold`, `toggleItalic`, `toggleUnderline`, `toggleStrikethrough`,
///   `setAlignment`, `setList`, `indent`, `outdent`, `composerCaretRect()`,
///   `isEditorFirstResponder`, `resignEditorFirstResponder()`: added in Task 9 fix round 1, after
///   review found the original `exercise(...)` invoked only 6 of these 17 members while this very
///   comment claimed "whatever passes here is what the composer would get" — a coverage claim the
///   test did not back up. (Fix round 3 corrected this comment's own tally, which undercounted the
///   protocol as 14 members instead of 17 — a miscount in the finding text, not in the coverage
///   itself: all 17 were, and remain, genuinely exercised.)
///
/// **`onChange` is now checked individually around EVERY mutation that can fire it — all four
/// inline toggles (`toggleBold`, `toggleItalic`, `toggleUnderline`, `toggleStrikethrough`) and each
/// of the five structural mutators (`setParagraphStyle`, `setAlignment`, `setList`, `indent`,
/// `outdent`) — asserting exactly one firing per call, for both backends.** This was not always
/// true. Fix round 1 found, by direct measurement (a throwaway diagnostic probe, not assumed), that
/// the engine fired `onChange` for `toggleBold`/`toggleItalic` but NOT for any of the five
/// structural mutators, while Legacy fired it for all seven — a genuine divergence, at the time
/// reported here rather than papered over by scoping this gate's `onChange` coverage to only the
/// symmetric member (`toggleBold`). Fix round 2's ruling was that this was a DEFECT in the engine
/// path, not a real divergence to keep documenting: the five structural mutators are user-initiated
/// edits that merely happen to be *implemented* via the engine's host-document-set idiom, and that
/// idiom's `isApplyingHostDocument` guard — meant only to silence a document a host LOADS wholesale
/// — was silencing them as collateral damage. A composer's content-height update, draft persistence
/// and send-button state all key off `onChange`, so shipping the old behaviour would have left all
/// three stale after e.g. a heading or bullet-list toggle, invisibly. `RichTextEngineEditorView+
/// Paragraph.swift`'s `mutateTouchedParagraphs` now fires `onChange?()` itself once the mutation
/// (document re-application + selection restore) is fully settled — see that file's header comment
/// for the exact mechanics, the "fire after the selection restore" ordering, and how it avoids
/// double-firing against a pending list-continuation reconciliation. Fix round 3 added
/// `toggleItalic`/`toggleUnderline`/`toggleStrikethrough` to the exact-count set (they previously
/// rested on a throwaway round-1 diagnostic, not a persisted assertion) and added
/// `test_aStructuralMutationDuringAPendingReconciliationFiresOnChangeExactlyOnce` (engine-only,
/// below), which drives the ONE interaction none of the above exercises: a structural mutator
/// invoked WHILE a list-continuation reconciliation is still pending. The original findings, the
/// measurements, and the fixes are recorded in `task-9-report.md`'s "Fix round 1"/"Fix round
/// 2"/"Fix round 3" sections; this comment states only where coverage stands now.
final class ComposerStandInTests: XCTestCase {
    private var window: UIWindow!
    override func setUp() {
        super.setUp()
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
    }
    override func tearDown() { window.isHidden = true; window = nil; super.tearDown() }

    private func seed() -> Document {
        Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "alpha")]))])
    }

    private func paragraph(_ editor: any RichTextEditor, _ label: String, file: StaticString = #filePath,
                           line: UInt = #line) -> ParagraphBlock? {
        guard case let .paragraph(pb) = editor.document.blocks[0] else {
            XCTFail("\(label): expected a paragraph", file: file, line: line)
            return nil
        }
        return pb
    }

    private func exercise(_ editor: any RichTextEditor, view: UIView, label: String) {
        window.addSubview(view)
        window.makeKeyAndVisible()
        editor.document = seed()
        XCTAssertEqual(editor.document.blocks.count, 1, "\(label): document round-trip")
        XCTAssertGreaterThan(editor.height(forWidth: 320), 0, "\(label): height")
        editor.composerSelectedRange = NSRange(location: 0, length: 5)
        XCTAssertEqual(editor.selectedText(), "alpha", "\(label): selectedText")

        // onChange — checked individually around every mutation that should fire it, asserting
        // EXACTLY one firing per call (not merely "at least one"). See this file's header comment
        // for why every one of these seven calls is now expected to fire it, symmetrically.
        func measuringOnChange(_ member: String, _ body: () -> Void) {
            var count = 0
            editor.onChange = { count += 1 }
            body()
            XCTAssertEqual(count, 1, "\(label): \(member) must fire onChange exactly once")
        }

        measuringOnChange("toggleBold") { editor.toggleBold() }

        measuringOnChange("setParagraphStyle") { editor.setParagraphStyle(.heading1) }
        guard let afterStyle = paragraph(editor, label) else { return }
        XCTAssertEqual(afterStyle.style, .heading1, "\(label): style")

        // toggleItalic / toggleUnderline / toggleStrikethrough — each attribute must reach
        // `document`, mirroring what `toggleBold` above (and the mixed-selection test below)
        // already proves for bold. Each also fires onChange exactly once (fix round 3 — this
        // used to rest only on a throwaway round-1 diagnostic, never a persisted assertion).
        measuringOnChange("toggleItalic") { editor.toggleItalic() }
        measuringOnChange("toggleUnderline") { editor.toggleUnderline() }
        measuringOnChange("toggleStrikethrough") { editor.toggleStrikethrough() }
        guard let afterInline = paragraph(editor, label) else { return }
        XCTAssertTrue(afterInline.runs.allSatisfy { $0.attributes.italic },
                      "\(label): italic did not reach document")
        XCTAssertTrue(afterInline.runs.allSatisfy { $0.attributes.underline },
                      "\(label): underline did not reach document")
        XCTAssertTrue(afterInline.runs.allSatisfy { $0.attributes.strikethrough },
                      "\(label): strikethrough did not reach document")

        // setAlignment — the paragraph's alignment changes in `document`.
        measuringOnChange("setAlignment") { editor.setAlignment(.center) }
        guard let afterAlignment = paragraph(editor, label) else { return }
        XCTAssertEqual(afterAlignment.paragraph.alignment, .center,
                       "\(label): alignment did not reach document")

        // setList — list membership appears in `document`, starting at level 0.
        measuringOnChange("setList") { editor.setList(.bullet) }
        guard let afterList = paragraph(editor, label) else { return }
        XCTAssertEqual(afterList.list?.marker, .bullet, "\(label): list membership did not appear")
        XCTAssertEqual(afterList.list?.level, 0, "\(label): a freshly-listed paragraph starts at level 0")

        // indent / outdent — the level rises, and outdent clamps at zero rather than going
        // negative. Both outdent calls (the real decrement and the clamping no-op) must still
        // fire onChange exactly once each — the mutation ran either way.
        measuringOnChange("indent") { editor.indent() }
        guard let afterIndent = paragraph(editor, label) else { return }
        XCTAssertEqual(afterIndent.list?.level, 1, "\(label): indent did not raise the list level")

        measuringOnChange("outdent (to zero)") { editor.outdent() }
        measuringOnChange("outdent (clamped past zero)") { editor.outdent() }
        guard let afterOutdent = paragraph(editor, label) else { return }
        XCTAssertEqual(afterOutdent.list?.level, 0, "\(label): outdent must clamp at level 0")

        // isEditorFirstResponder / resignEditorFirstResponder() — focus is acquired (via the
        // concrete `view`, since acquiring is not itself a protocol member), reported, and
        // released, entirely through the protocol thereafter.
        XCTAssertFalse(editor.isEditorFirstResponder, "\(label): should not be first responder yet")
        XCTAssertTrue(view.becomeFirstResponder(), "\(label): becomeFirstResponder failed")
        XCTAssertTrue(editor.isEditorFirstResponder, "\(label): focus was acquired but not reported")

        // composerCaretRect() — a real, non-zero-height rect for a collapsed selection.
        editor.composerSelectedRange = NSRange(location: 5, length: 0)
        guard let caretRect = editor.composerCaretRect() else {
            return XCTFail("\(label): composerCaretRect returned nil while first responder")
        }
        XCTAssertGreaterThan(caretRect.height, 0, "\(label): composerCaretRect reported a zero-height rect")

        XCTAssertTrue(editor.resignEditorFirstResponder(), "\(label): resignEditorFirstResponder failed")
        XCTAssertFalse(editor.isEditorFirstResponder, "\(label): still first responder after resigning")

        view.removeFromSuperview()
    }

    func test_theEngineEditorAnswersTheComposerSurface() {
        let editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        exercise(editor, view: editor, label: "engine")
    }

    func test_theLegacyEditorAnswersTheSameSurface() {
        let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 240),
                                        inputBackend: .legacy)
        exercise(editor, view: editor, label: "legacy")
    }

    // MARK: - The tri-state → Bool collapse (Task 9 decision)

    /// R3 established the engine's inline-trait state as a genuine tri-state (`off`/`on`/`mixed`),
    /// deliberately NOT collapsed to `Bool` at that layer — see
    /// `RichTextEngineEditorView+Formatting.swift`'s `InlineTraitState` doc comment, which names
    /// this task as the place that collapse must happen. It is not exposed as a new protocol
    /// member (the composer, `RichTextEditorChatInputNode`, never calls `currentState()` /
    /// `EditorState` — only `toggleBold()` itself — so nothing here is "transcribed from a
    /// canvas"); the collapse instead lives INSIDE `toggleBold()`'s own behaviour, and both
    /// backends already make the same choice natively:
    ///   - Legacy: `DocumentCanvasView+CharacterFormat.swift`'s `applyCharacterToggle` computes
    ///     `allOn = covered.allSatisfy(isSet)` — a selection that is only PARTLY bold is `allOn ==
    ///     false`, so the toggle turns the WHOLE selection on.
    ///   - Engine: `IDInlineTextFormattingController.m`'s `toggleTrait:` computes `shouldEnable =
    ///     [self stateForTrait:trait] != IDInlineTextTraitStateOn` — `.mixed` is not `.on`, so
    ///     `shouldEnable` is true and the toggle turns the WHOLE selection on too.
    /// So the rule this task DELIBERATELY adopts — matching what both backends already do, rather
    /// than inheriting it silently — is: **`mixed` collapses to `off`, so a bold toggle over a
    /// mixed selection turns the entire selection bold.** This test pins that through the
    /// `RichTextEditor` protocol surface alone (`document`, `composerSelectedRange`, `toggleBold`)
    /// for both implementations, so it would catch either backend silently changing its own
    /// mixed-selection policy.
    private func exerciseMixedSelectionToggleCollapsesToOff(_ editor: any RichTextEditor,
                                                            view: UIView, label: String) {
        window.addSubview(view)
        window.makeKeyAndVisible()
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(
            id: BlockID("p0"), runs: [TextRun(text: "alpha beta")]))])
        // Bold only "alpha" (the first 5 UTF-16 units) so "beta" stays plain — a genuinely MIXED
        // selection once both are selected together below.
        editor.composerSelectedRange = NSRange(location: 0, length: 5)
        editor.toggleBold()
        // Select the whole paragraph — spanning the now-bold "alpha" and the still-plain "beta".
        editor.composerSelectedRange = NSRange(location: 0, length: 10)
        editor.toggleBold()
        guard case let .paragraph(paragraph) = editor.document.blocks[0] else {
            return XCTFail("\(label): expected a paragraph")
        }
        XCTAssertTrue(paragraph.runs.allSatisfy { $0.attributes.bold },
                      "\(label): a bold toggle over a MIXED selection must turn the WHOLE " +
                      "selection on (the chosen collapse: mixed behaves as off), not toggle each " +
                      "run independently")
        view.removeFromSuperview()
    }

    func test_engineToggleBoldOnAMixedSelectionTurnsTheWholeSelectionOn() {
        let editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        exerciseMixedSelectionToggleCollapsesToOff(editor, view: editor, label: "engine")
    }

    func test_legacyToggleBoldOnAMixedSelectionTurnsTheWholeSelectionOn() {
        let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 240),
                                        inputBackend: .legacy)
        exerciseMixedSelectionToggleCollapsesToOff(editor, view: editor, label: "legacy")
    }
}

// MARK: - The reconciliation/structural-mutator coincidence (Task 9 fix round 3)

/// Engine-only: Legacy has no list-continuation reconciliation to coincide with (that mechanism
/// exists specifically because `EngineDocumentBridge`'s reverse mapping mints DEFAULT structure —
/// no list — for any block beyond the reused array's length; see
/// `RichTextEngineEditorView+Paragraph.swift`'s "List continuation" section).
///
/// This is the highest-risk interaction in fix round 2's `onChange` fix, named explicitly by the
/// coordinator: "a gate that prevents a double-fire by producing a no-fire is a worse bug than the
/// one it replaced." A structural mutator invoked WHILE a reconciliation from an earlier edit is
/// still pending must not fire `onChange` itself (it would expose the not-yet-reconciled
/// intermediate `document`) — but the deferred reconciliation's own trailing, unconditional
/// `onChange?()` must still land exactly once, once it runs. Getting this wrong in either
/// direction is silent: a suppressed `onChange` would leave a composer's content-height/draft/
/// send-button state stale with NO error, and a doubled `onChange` would just look like two
/// harmless redundant callbacks — neither failure mode throws, crashes, or shows up as a visibly
/// wrong document, which is exactly why this needs its own test rather than trusting a manual
/// trace.
final class ComposerStandInReconciliationCoincidenceTests: XCTestCase {
    private var window: UIWindow!
    override func setUp() { super.setUp(); window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480)) }
    override func tearDown() { window.isHidden = true; window = nil; super.tearDown() }

    /// Reaches the coincidence window DETERMINISTICALLY, not by racing a timer: `insertText`
    /// synchronously drives `engineDidChangeDocument()` (R1's own funnel — see
    /// `RichTextEngineEditorView.swift`), which schedules the reconciliation and flips
    /// `isListContinuationReconciliationScheduled` to `true` before `insertText` returns to this
    /// test — asserted below, not assumed, so a change to that synchronicity would redden this
    /// test rather than silently stop covering the window it targets.
    func test_aStructuralMutationDuringAPendingReconciliationFiresOnChangeExactlyOnce() {
        let editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        window.addSubview(editor)
        window.makeKeyAndVisible()

        var seededParagraph = ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "alpha")])
        seededParagraph.list = ListMembership(marker: .bullet, level: 0)
        editor.document = Document(blocks: [.paragraph(seededParagraph)])
        XCTAssertTrue(editor.engine.becomeFirstResponder())

        // Caret at the end of "alpha", then Return: splits into a bulleted "alpha" and a fresh,
        // list-less second paragraph — exactly the shape `blockIDsNeedingListContinuation`
        // schedules a reconciliation for.
        let end = editor.engine.position(from: editor.engine.beginningOfDocument, offset: 5)!
        editor.engine.selectedTextRange = editor.engine.textRange(from: end, to: end)

        var changeCount = 0
        editor.onChange = { changeCount += 1 }
        editor.engine.insertText("\n")

        XCTAssertTrue(editor.isListContinuationReconciliationScheduled,
                      "the Return split did not schedule a pending reconciliation — this test did " +
                      "not reach the coincidence window it targets")
        XCTAssertEqual(changeCount, 0,
                       "the split's own onChange must be suppressed while reconciliation is pending")

        // THE COINCIDENCE: a structural mutator, invoked while that reconciliation is still
        // pending. It must not fire onChange itself (the guard added in fix round 2).
        editor.setParagraphStyle(.heading1)
        XCTAssertEqual(changeCount, 0,
                       "the structural mutator's onChange must ALSO be suppressed here — firing " +
                       "now would expose the not-yet-reconciled intermediate document")

        // Let the deferred reconciliation's own main-queue turn land. Scheduled AFTER the
        // reconciliation's own `DispatchQueue.main.async` (queued by the Return split above), so
        // FIFO ordering on the serial main queue — not wall-clock timing — guarantees the
        // reconciliation has already run by the time this fulfills.
        let reconciled = expectation(description: "deferred list-continuation reconciliation")
        DispatchQueue.main.async { reconciled.fulfill() }
        wait(for: [reconciled], timeout: 1.0)

        XCTAssertFalse(editor.isListContinuationReconciliationScheduled,
                       "the reconciliation should have completed by now")
        XCTAssertEqual(changeCount, 1,
                       "onChange must fire EXACTLY once overall for the coincidence — the split " +
                       "and the structural mutator were both suppressed, so the deferred " +
                       "reconciliation's own trailing call must be the ONE firing, not zero and " +
                       "not two")

        // The final document must reflect BOTH the list continuation and the structural change.
        XCTAssertEqual(editor.document.blocks.count, 2, "expected the Return split's two paragraphs")
        guard case let .paragraph(first) = editor.document.blocks[0],
              case let .paragraph(second) = editor.document.blocks[1] else {
            return XCTFail("expected two paragraphs")
        }
        XCTAssertEqual(first.list?.marker, .bullet,
                       "the original paragraph's own list membership must survive the split")
        XCTAssertEqual(second.style, .heading1,
                       "the structural mutation (targeting the new paragraph, where the caret " +
                       "landed) did not survive")
        XCTAssertEqual(second.list?.marker, .bullet,
                       "the list continuation did not apply to the new split-off paragraph")
    }
}
