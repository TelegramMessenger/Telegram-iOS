#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

@available(iOS 13.0, *)
@MainActor
final class TelegramCommandInputClientTests: XCTestCase {
    // MARK: Fixtures

    /// A minimal fake pasteboard — the simulator's `UIPasteboard.general` can be unauthorized/hang on
    /// reads. Mirrors `CanvasClipboardTests.FakePasteboard` exactly, duplicated per-file as a
    /// deliberate isolation convention: each suite owns its fixtures so a change made for one cannot
    /// silently alter another's setup. (TASK 30 CORRECTION, re-review N1: this used to justify the
    /// duplication by saying the original is "a private nested fake". It is not —
    /// `CanvasClipboardTests.FakePasteboard` is a non-private nested type, reachable from any file in
    /// this target, so the duplication is a choice and not a necessity. The same false claim was fixed
    /// in `CommandRouterTests` and `BackendAttachmentTests`; this fourth copy is where it started.)
    final class FakePasteboard: TextPasteboard {
        var items: [String: Any] = [:]
        var string: String? {
            get { items["public.utf8-plain-text"] as? String }
            set {
                if let v = newValue { items = ["public.utf8-plain-text": v] } else { items = [:] }
            }
        }
        var hasStrings: Bool { !((string ?? "").isEmpty) }
        func data(forPasteboardType type: String) -> Data? { items[type] as? Data }
        func setItems(_ newItems: [[String: Any]], options: [UIPasteboard.OptionsKey: Any]) {
            items = newItems.first ?? [:]
        }
        func contains(pasteboardTypes: [String]) -> Bool { pasteboardTypes.contains { items[$0] != nil } }
    }

    /// A bare canvas + client (no facade) with one paragraph "p0" = "Hello world", plus its fake
    /// pasteboard. `c` holds the canvas `unowned` (by design, see the client's doc comment) — a
    /// discard-pattern `_` for the canvas would release it immediately; always bind it.
    private func makeClient(_ text: String = "Hello world", width: CGFloat = 300)
        -> (DocumentCanvasView, TelegramCommandInputClient, FakePasteboard) {
        let v = DocumentCanvasView()
        v.setParagraphs([ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: text)])], width: width)
        v.frame = CGRect(x: 0, y: 0, width: width, height: 300); v.layoutIfNeeded()
        let pb = FakePasteboard()
        v.pasteboard = pb
        return (v, TelegramCommandInputClient(canvas: v, facade: nil), pb)
    }

    private func region(_ v: DocumentCanvasView, _ id: String = "p0") -> LeafTextRegion {
        v.allLeafRegions().first { $0.ref == .paragraph(BlockID(id)) }!
    }

    private func text(_ v: DocumentCanvasView, _ id: String = "p0") -> String {
        for b in v.currentBlocks() { if case .paragraph(let p) = b, p.id == BlockID(id) { return p.text } }
        return ""
    }

    // MARK: richTextInputCommand(for:) selector table

    /// Six selectors are actually mappable through `UIResponderStandardEditActions` — see the "NOTE on
    /// the brief vs. reality" doc comment on `richTextInputCommand(for:)`: that protocol has NO
    /// `undo(_:)`/`redo(_:)` selectors at all (confirmed against the SDK's `UIResponder.h`), so there is
    /// no seventh selector for this table to map. `.undo`/`.redo` are reached only by a caller that
    /// already holds the `RichTextInputCommand` value directly.
    func test_selectorTableMapsTheSixResponderChainActions() {
        XCTAssertEqual(richTextInputCommand(for: #selector(UIResponderStandardEditActions.copy(_:))), .copy)
        XCTAssertEqual(richTextInputCommand(for: #selector(UIResponderStandardEditActions.cut(_:))), .cut)
        XCTAssertEqual(richTextInputCommand(for: #selector(UIResponderStandardEditActions.paste(_:))), .paste)
        XCTAssertEqual(richTextInputCommand(for: #selector(UIResponderStandardEditActions.select(_:))), .selectWord)
        XCTAssertEqual(richTextInputCommand(for: #selector(UIResponderStandardEditActions.selectAll(_:))), .selectAll)
        XCTAssertEqual(richTextInputCommand(for: #selector(UIResponderStandardEditActions.delete(_:))), .delete)
    }

    /// `DocumentCanvasView.legacyBold` etc. are `private` to `+EditMenu.swift`, so a cross-file
    /// `#selector(DocumentCanvasView.legacyBold)` (the brief's literal phrasing) does not compile — a
    /// raw `Selector(_:)` string reaches the same Objective-C selector regardless of Swift access
    /// control, which is what every assertion below uses instead.
    func test_selectorTableReturnsNilForTheLegacyMenuItemSelectors() {
        // The 5 legacy UIMenuItem actions (+EditMenu.swift:140-144).
        XCTAssertNil(richTextInputCommand(for: Selector(("legacyBold"))))
        XCTAssertNil(richTextInputCommand(for: Selector(("legacyItalic"))))
        XCTAssertNil(richTextInputCommand(for: Selector(("legacyUnderline"))))
        XCTAssertNil(richTextInputCommand(for: Selector(("legacyLookUp"))))
        XCTAssertNil(richTextInputCommand(for: Selector(("legacyShare"))))
        // The 6 spelling-menu selectors (+EditMenu.swift:166-174).
        XCTAssertNil(richTextInputCommand(for: Selector(("spellNoop"))))
        XCTAssertNil(richTextInputCommand(for: Selector(("spellRevert"))))
        XCTAssertNil(richTextInputCommand(for: Selector(("spellGuess0"))))
        XCTAssertNil(richTextInputCommand(for: Selector(("spellGuess1"))))
        XCTAssertNil(richTextInputCommand(for: Selector(("spellGuess2"))))
        XCTAssertNil(richTextInputCommand(for: Selector(("spellGuess3"))))
    }

    // MARK: canPerform

    func test_canPerformCopyRequiresARangedSelection() {
        let (v, c, _) = makeClient()
        let r = region(v)
        v.setSelectionForTesting(anchor: r.globalStart, head: r.globalStart)   // collapsed
        XCTAssertFalse(c.canPerform(.copy, sender: nil))
        v.setSelectionForTesting(anchor: r.globalStart, head: r.globalStart + 3)   // ranged
        XCTAssertTrue(c.canPerform(.copy, sender: nil))
    }

    func test_canPerformCutRequiresARangedSelection() {
        let (v, c, _) = makeClient()
        let r = region(v)
        v.setSelectionForTesting(anchor: r.globalStart, head: r.globalStart)
        XCTAssertFalse(c.canPerform(.cut, sender: nil))
        v.setSelectionForTesting(anchor: r.globalStart, head: r.globalStart + 3)
        XCTAssertTrue(c.canPerform(.cut, sender: nil))
    }

    func test_canPerformPasteFollowsTheClipboardPredicate() {
        // `v` MUST be bound (not `_`): the client holds it `unowned`, and discarding it via `_` released
        // it immediately in an earlier revision of this test — the exact footgun
        // `TelegramDocumentInputClient`'s own doc comment warns about.
        let (v, c, pb) = makeClient()
        withExtendedLifetime(v) {
            pb.string = nil
            XCTAssertFalse(c.canPerform(.paste, sender: nil))
            pb.string = "hi"
            XCTAssertTrue(c.canPerform(.paste, sender: nil))
        }
    }

    /// "Measures against renderable bounds" per `+EditMenu.swift:89-91`: available while the selection
    /// does not already cover the whole renderable document, unavailable once it does — NOT simply
    /// "always true while there is text."
    func test_canPerformSelectAllMeasuresAgainstRenderableBounds() {
        let (v, c, _) = makeClient()
        XCTAssertTrue(c.canPerform(.selectAll, sender: nil), "not yet fully selected → available")
        v.selectAllText()
        XCTAssertFalse(c.canPerform(.selectAll, sender: nil), "already fully selected → unavailable")
    }

    /// INVENTED policy (the brief does not dictate this): the legacy canvas implements no `delete(_:)`
    /// responder action at all, so `.delete` must be unconditionally unavailable — matching the `false`
    /// the pre-seam path produced. (TASK 30 CORRECTION, re-review N2: that used to read "matching
    /// `super.canPerformAction(delete:)`'s existing `false`", which names only half the mechanism.
    /// `UIResponder.canPerformAction` returns true if the RECEIVER implements the action and otherwise
    /// asks the NEXT RESPONDER — so the pre-seam answer was the responder CHAIN's, not the canvas's. It
    /// is `false` for every chain this package can produce, so the conclusion is unchanged; but nobody
    /// should "verify" it by re-reading the canvas alone. This site expressed the identical defect in
    /// different words from the three fixed in fix round 1, which is exactly why the claim-keyed grep
    /// that found those missed this one.) Checked both with and without a
    /// selection, since a naïve "mirror cut's predicate" mistake would make this test red only in the
    /// ranged-selection case.
    func test_canPerformDeleteIsAlwaysFalse() {
        let (v, c, _) = makeClient()
        let r = region(v)
        v.setSelectionForTesting(anchor: r.globalStart, head: r.globalStart)
        XCTAssertFalse(c.canPerform(.delete, sender: nil), "collapsed selection")
        v.setSelectionForTesting(anchor: r.globalStart, head: r.globalStart + 3)
        XCTAssertFalse(c.canPerform(.delete, sender: nil), "ranged selection — still unavailable")
    }

    // MARK: prepare — terminal no-change

    /// Copy PERFORMS (writes the pasteboard) but never changes content or selection, so `prepare` must
    /// resolve it as `.terminal` directly rather than a `.ready` token needing a later `commit`.
    func test_copyIsATerminalNoChange() {
        let (v, c, pb) = makeClient()
        let r = region(v)
        v.setSelectionForTesting(anchor: r.globalStart, head: r.globalStart + 5)   // "Hello"
        let revisionBefore = v.documentRevision

        guard case .terminal(let result) = c.prepare(.copy, sender: nil) else {
            return XCTFail("expected .terminal")
        }
        XCTAssertTrue(result.performed, "copy WAS available and must have actually run")
        XCTAssertFalse(result.contentChanged)
        XCTAssertFalse(result.selectionChanged)
        XCTAssertEqual(result.revision, revisionBefore)
        XCTAssertEqual(v.documentRevision, revisionBefore, "copy must not touch the document")
        XCTAssertEqual(pb.string, "Hello", "copy must actually have run and written the pasteboard")
    }

    /// The unavailable-copy branch: no selection → `prepare` still returns `.terminal`, but `performed`
    /// is false and the pasteboard is left untouched (copy never ran).
    func test_copyUnavailableIsATerminalNoChangeThatNeverRuns() {
        let (v, c, pb) = makeClient()
        let r = region(v)
        v.setSelectionForTesting(anchor: r.globalStart, head: r.globalStart)   // collapsed → copy unavailable
        pb.string = "untouched"

        guard case .terminal(let result) = c.prepare(.copy, sender: nil) else {
            return XCTFail("expected .terminal")
        }
        XCTAssertFalse(result.performed)
        XCTAssertFalse(result.contentChanged)
        XCTAssertFalse(result.selectionChanged)
        XCTAssertEqual(pb.string, "untouched", "an unavailable copy must never write the pasteboard")
    }

    /// The high-value transaction-discipline assertion: a refused (unavailable) command leaves the
    /// document, the selection, AND the undo stack all three unchanged — checked before and after.
    func test_anUnavailableCommandIsATerminalNoChange() {
        let (v, c, pb) = makeClient()
        let um = UndoManager(); um.groupsByEvent = false
        v.undoManagerOverride = um
        pb.string = nil   // empty pasteboard → paste unavailable

        let textBefore = text(v)
        let anchorBefore = v.anchor, headBefore = v.head
        let revisionBefore = v.documentRevision
        let undoRegistrationsBefore = v.undoRegistrationCount
        let canUndoBefore = um.canUndo, canRedoBefore = um.canRedo

        guard case .terminal(let result) = c.prepare(.paste, sender: nil) else {
            return XCTFail("expected .terminal")
        }
        XCTAssertFalse(result.performed)
        XCTAssertFalse(result.contentChanged)
        XCTAssertFalse(result.selectionChanged)

        XCTAssertEqual(text(v), textBefore, "document must be unchanged")
        XCTAssertEqual(v.anchor, anchorBefore, "selection anchor must be unchanged")
        XCTAssertEqual(v.head, headBefore, "selection head must be unchanged")
        XCTAssertEqual(v.documentRevision, revisionBefore, "revision must be unchanged")
        XCTAssertEqual(v.undoRegistrationCount, undoRegistrationsBefore, "undo registrations must be unchanged")
        XCTAssertEqual(um.canUndo, canUndoBefore, "undo availability must be unchanged")
        XCTAssertEqual(um.canRedo, canRedoBefore, "redo availability must be unchanged")
    }

    // MARK: prepare/commit — ready commands

    func test_cutRemovesTheSelectionAndReportsContentChanged() {
        let (v, c, pb) = makeClient()
        let um = UndoManager(); um.groupsByEvent = false
        v.undoManagerOverride = um
        let r = region(v)
        v.setSelectionForTesting(anchor: r.globalStart, head: r.globalStart + 6)   // "Hello "

        guard case .ready(let prepared) = c.prepare(.cut, sender: nil) else {
            return XCTFail("expected .ready")
        }
        XCTAssertTrue(prepared.contentWillChange)
        XCTAssertTrue(prepared.selectionWillChange)
        // `um.groupsByEvent = false` needs an explicit bracket around the commit, or `editing`'s
        // `registerUndo` throws "must begin a group before registering undo" (the established
        // convention — `CanvasEditingTests.swift:25`, `TelegramDocumentInputClientMutationTests`'
        // fixture note).
        um.beginUndoGrouping(); let result = c.commit(prepared); um.endUndoGrouping()

        XCTAssertTrue(result.performed)
        XCTAssertTrue(result.contentChanged)
        XCTAssertEqual(pb.string, "Hello ", "cut must write the cut text to the pasteboard")
        XCTAssertEqual(text(v), "world")
        XCTAssertEqual(result.revision, v.documentRevision)
        XCTAssertEqual(result.selection.head.utf16Offset, v.head)
    }

    func test_selectWordSelectsTheWordUnderTheCaretAndReportsSelectionChanged() {
        let (v, c, _) = makeClient()
        let r = region(v)
        v.setSelectionForTesting(anchor: r.globalStart + 1, head: r.globalStart + 1)   // caret inside "Hello"
        let revisionBefore = v.documentRevision

        guard case .ready(let prepared) = c.prepare(.selectWord, sender: nil) else {
            return XCTFail("expected .ready")
        }
        XCTAssertFalse(prepared.contentWillChange)
        XCTAssertTrue(prepared.selectionWillChange)
        let result = c.commit(prepared)

        XCTAssertTrue(result.performed)
        XCTAssertFalse(result.contentChanged)
        XCTAssertTrue(result.selectionChanged)
        XCTAssertEqual(v.documentRevision, revisionBefore, "selecting a word must not touch the document")
        XCTAssertEqual(v.selFrom, r.globalStart)
        XCTAssertEqual(v.selTo, r.globalStart + 5, "\"Hello\" bounds")
    }

    func test_selectAllSelectsTheWholeRenderableDocument() {
        let (v, c, _) = makeClient()
        guard case .ready(let prepared) = c.prepare(.selectAll, sender: nil) else {
            return XCTFail("expected .ready")
        }
        let result = c.commit(prepared)

        XCTAssertTrue(result.performed)
        XCTAssertFalse(result.contentChanged)
        XCTAssertTrue(result.selectionChanged)
        let begin = (v.beginningOfDocument as! DocumentTextPosition).offset
        let end = (v.endOfDocument as! DocumentTextPosition).offset
        XCTAssertEqual(v.selFrom, begin)
        XCTAssertEqual(v.selTo, end)
    }

    // MARK: token discipline

    func test_aCommandTokenCanOnlyBeCommittedOnce() {
        let (v, c, _) = makeClient()
        var violations: [String] = []
        RichTextInputContractViolation.reporter = { violations.append($0) }
        defer { RichTextInputContractViolation.reporter = nil }

        guard case .ready(let prepared) = c.prepare(.selectAll, sender: nil) else {
            return XCTFail("expected .ready")
        }
        let first = c.commit(prepared)
        XCTAssertTrue(first.performed)
        XCTAssertTrue(violations.isEmpty, "the first, legitimate commit must not itself report a violation")

        let selFromAfterFirst = v.selFrom, selToAfterFirst = v.selTo
        let second = c.commit(prepared)

        XCTAssertFalse(second.performed, "a repeated commit of the same token must not re-perform the command")
        XCTAssertFalse(violations.isEmpty, "a repeated commit must report a contract violation")
        XCTAssertEqual(second.selection, first.selection, "the repeated commit must not move the selection again")
        XCTAssertEqual(v.selFrom, selFromAfterFirst, "the repeated commit must not act on the document/selection a second time")
        XCTAssertEqual(v.selTo, selToAfterFirst)
    }

    /// The third of the three transaction-discipline paths (fix round 1): `prepare` is implemented to
    /// discard a stale `outstanding` token and report a violation when called again before the first is
    /// committed (`TelegramCommandInputClient.swift`'s `prepare`, mirroring
    /// `TelegramDocumentInputClient.prepareMutation` / `TelegramDocumentInputClientMutationTests.
    /// test_onlyOneOutstandingPreparationIsRetained` exactly) — but nothing exercised it. Asserts BOTH
    /// halves: the violation is reported, AND the first token is genuinely invalidated (its commit is
    /// rejected) while the second (the one actually retained) remains committable.
    func test_aSecondPreparationWhileOneIsOutstandingReportsAViolationAndInvalidatesTheFirst() {
        let (v, c, _) = makeClient()
        var violations: [String] = []
        RichTextInputContractViolation.reporter = { violations.append($0) }
        defer { RichTextInputContractViolation.reporter = nil }

        guard case .ready(let first) = c.prepare(.selectAll, sender: nil) else {
            return XCTFail("expected .ready")
        }
        XCTAssertTrue(violations.isEmpty, "the first preparation alone must not itself report a violation")

        guard case .ready(let second) = c.prepare(.selectAll, sender: nil) else {
            return XCTFail("expected .ready")
        }
        XCTAssertFalse(violations.isEmpty,
                       "preparing a second command while one is outstanding must report a violation")

        let firstCommit = c.commit(first)
        XCTAssertFalse(firstCommit.performed, "the discarded FIRST token must be rejected, not silently retried")

        let secondCommit = c.commit(second)
        XCTAssertTrue(secondCommit.performed, "the retained SECOND token must remain genuinely committable")
        XCTAssertTrue(secondCommit.selectionChanged)
        let begin = (v.beginningOfDocument as! DocumentTextPosition).offset
        let end = (v.endOfDocument as! DocumentTextPosition).offset
        XCTAssertEqual(v.selFrom, begin, "the second token's commit must have actually run select-all")
        XCTAssertEqual(v.selTo, end)
    }

    func test_aForeignCommandTokenIsRejected() {
        let (v, c, _) = makeClient()
        RichTextInputContractViolation.reporter = { _ in }
        defer { RichTextInputContractViolation.reporter = nil }

        let textBefore = text(v)
        let anchorBefore = v.anchor, headBefore = v.head
        let foreign = RichTextInputPreparedCommand(token: UUID(), contentWillChange: true, selectionWillChange: true)

        let result = c.commit(foreign)

        XCTAssertFalse(result.performed)
        XCTAssertFalse(result.contentChanged)
        XCTAssertFalse(result.selectionChanged)
        XCTAssertEqual(text(v), textBefore, "a foreign token must not touch the document")
        XCTAssertEqual(v.anchor, anchorBefore, "a foreign token must not touch the selection")
        XCTAssertEqual(v.head, headBefore)
    }

    // MARK: undo / redo

    /// `prepare`/`commit` route `.undo`/`.redo` through the FACADE's `undo()`/`redo()`, which — on top of
    /// driving the undo manager (also reachable directly) — finalizes marked text and fires its OWN
    /// trailing `onChange` once the manager settles (`RichTextEditorView.swift:440-441`). Naively
    /// asserting a fixed `onChange` call count is wrong here: `registerUndo`'s restore closure ALSO
    /// relays through `canvas.onContentSizeChange` on its own (via `setBlocks` + its own explicit
    /// `notifyContentSizeChanged()` — see the "layout convention" note in this package's `CLAUDE.md`),
    /// so that relay fires whether or not a facade is involved. The comparison below isolates exactly
    /// what routing through the facade ADDS on top of that shared relay: its own one extra trailing call.
    func test_undoAndRedoRouteThroughTheFacade() {
        // Facade-backed run.
        let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 300, height: 300))
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "Alpha")]))])
        editor.layoutIfNeeded()
        let v = editor.canvasForTesting
        let um = UndoManager(); um.groupsByEvent = false
        v.undoManagerOverride = um
        v.setSelectionForTesting(anchor: v.boxes[0].textStart + 5, head: v.boxes[0].textStart + 5)   // end of "Alpha"
        um.beginUndoGrouping(); v.insertText("!"); um.endUndoGrouping()
        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "Alpha!")
        XCTAssertTrue(um.canUndo, "precondition: there must be something to undo")

        var facadeChangeCalls = 0
        editor.onChange = { facadeChangeCalls += 1 }
        let client = TelegramCommandInputClient(canvas: v, facade: editor)

        guard case .ready(let undoPrepared) = client.prepare(.undo, sender: nil) else {
            return XCTFail("expected .ready")
        }
        let undoResult = client.commit(undoPrepared)
        XCTAssertTrue(undoResult.performed)
        XCTAssertTrue(undoResult.contentChanged)
        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "Alpha")
        XCTAssertFalse(um.canUndo, "the undo stack must have moved")
        XCTAssertTrue(um.canRedo)
        XCTAssertGreaterThan(facadeChangeCalls, 0, "routing through the facade must notify the host")
        let facadeUndoCalls = facadeChangeCalls

        // Direct-canvas comparison run: the IDENTICAL edit + undo, with the SAME `onContentSizeChange`
        // relay wired manually (no facade) — isolating what `facade.undo()` adds on top of the shared
        // relay: its own trailing `onChange?()`.
        let (v2, _, _) = makeClient("Alpha")
        let um2 = UndoManager(); um2.groupsByEvent = false
        v2.undoManagerOverride = um2
        v2.setSelectionForTesting(anchor: v2.boxes[0].textStart + 5, head: v2.boxes[0].textStart + 5)
        um2.beginUndoGrouping(); v2.insertText("!"); um2.endUndoGrouping()
        var directRelayCalls = 0
        v2.onContentSizeChange = { directRelayCalls += 1 }
        let directClient = TelegramCommandInputClient(canvas: v2, facade: nil)
        guard case .ready(let directPrepared) = directClient.prepare(.undo, sender: nil) else {
            return XCTFail("expected .ready")
        }
        let directResult = directClient.commit(directPrepared)
        XCTAssertTrue(directResult.performed)
        XCTAssertTrue(directResult.contentChanged)
        XCTAssertEqual(text(v2), "Alpha", "the no-facade fallback must still actually undo")

        XCTAssertEqual(facadeUndoCalls, directRelayCalls + 1,
                       "routing through the facade must fire exactly ONE more onChange than driving the " +
                       "undo manager directly — the facade's own trailing notification")

        // Redo, facade side only (the delta was already isolated above for undo; redo shares the same
        // `facade.undo()`/`redo()` shape at `RichTextEditorView.swift:440-441`).
        guard case .ready(let redoPrepared) = client.prepare(.redo, sender: nil) else {
            return XCTFail("expected .ready")
        }
        let redoResult = client.commit(redoPrepared)
        XCTAssertTrue(redoResult.performed)
        XCTAssertTrue(redoResult.contentChanged)
        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "Alpha!")
        XCTAssertGreaterThan(facadeChangeCalls, facadeUndoCalls, "redo must also route through the facade and notify the host")
        XCTAssertTrue(um.canUndo)
        XCTAssertFalse(um.canRedo, "the redo stack must have moved")
    }

    /// INVENTED fallback policy (not dictated by the brief): with no facade, `.undo`/`.redo` still work,
    /// driving `canvas.effectiveUndoManager` directly (no `onChange` to fire, since there is no facade).
    func test_undoRedo_withoutFacade_fallsBackToDirectCanvasInvocation() {
        let (v, _, _) = makeClient("Alpha")
        let um = UndoManager(); um.groupsByEvent = false
        v.undoManagerOverride = um
        v.setSelectionForTesting(anchor: v.boxes[0].textStart + 5, head: v.boxes[0].textStart + 5)   // end of "Alpha"
        um.beginUndoGrouping(); v.insertText("!"); um.endUndoGrouping()
        XCTAssertEqual(text(v), "Alpha!")

        let client = TelegramCommandInputClient(canvas: v, facade: nil)
        guard case .ready(let prepared) = client.prepare(.undo, sender: nil) else {
            return XCTFail("expected .ready")
        }
        let result = client.commit(prepared)
        XCTAssertTrue(result.performed)
        XCTAssertTrue(result.contentChanged)
        XCTAssertEqual(text(v), "Alpha", "undo must still work without a facade")
        XCTAssertFalse(um.canUndo)
    }

    // MARK: two-step markdown paste

    /// `pasteMarkdownTwoStep` (`+Clipboard.swift:162`) deliberately spans TWO run-loop events for two
    /// undo groups — step 1 (raw plain text) runs synchronously inside `paste(_:)`, step 2 (the rich
    /// replace) is scheduled via `DispatchQueue.main.async`. `commit` must NOT pump the run loop to wait
    /// for step 2: it reports the STEP-ONE revision, with `contentChanged: true` (the raw text WAS
    /// spliced in), and the document must still read the RAW plain text at that point — proving step 2
    /// has not (yet) run.
    func test_pasteMarkdownTwoStepReportsTheStepOneRevision() {
        let (v, c, pb) = makeClient()
        v.plainTextFragmentTransformer = { s in
            Document(blocks: [.paragraph(ParagraphBlock(id: .generate(),
                runs: [TextRun(text: s, attributes: CharacterAttributes(bold: true))]))])
        }
        pb.string = "RAWMARK"   // plain text only — no fragment/RTF rep, so the two-step path is taken
        let r = region(v)
        v.setSelectionForTesting(anchor: r.globalStart + 5, head: r.globalStart + 5)   // caret right after "Hello"
        let revisionBeforePaste = v.documentRevision

        guard case .ready(let prepared) = c.prepare(.paste, sender: nil) else {
            return XCTFail("expected .ready")
        }
        let result = c.commit(prepared)

        XCTAssertTrue(result.performed)
        XCTAssertTrue(result.contentChanged, "step 1 (the raw splice) must have already happened")
        XCTAssertNotEqual(result.revision, revisionBeforePaste)
        XCTAssertEqual(result.revision, v.documentRevision, "commit must report exactly the step-1 revision")
        XCTAssertTrue(text(v).contains("RAWMARK"),
                     "the document must still hold the RAW plain text — step 2 (the rich replace) has not run yet")
    }
}
#endif
