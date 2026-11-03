#if canImport(UIKit)
import UIKit

/// Clipboard and structural commands (`RichTextInputCommandClient`). Commands use the SAME
/// prepare/notify/commit/publish ordering as document mutations, and the transaction discipline is
/// identical: a `.ready` preparation is single-use, belongs to its creating client, and must be
/// committed before returning to the run loop; a foreign or repeated commit is a programmer contract
/// violation reported through `RichTextInputContractViolation` (mirrors `TelegramDocumentInputClient`
/// exactly — see that type's doc comment for the full rationale).
///
/// DEVIATION D14 (plan's deviations table): undo OWNERSHIP stays with the document client —
/// `openUndoRun`, `undoRegistrationCount`, `undoManagerOverride`, and `breakUndoCoalescing()` are
/// `TelegramDocumentInputClient`'s / the canvas's, not this client's. This client only INVOKES undo/
/// redo (via the facade's `undo()`/`redo()`, or directly on the canvas's own undo manager when there is
/// no facade); it owns no undo state of its own.
///
/// Undo/redo initiated through the responder chain (this client, reached via `richTextInputCommand(for:)`
/// below) is a COMMAND. Undo/redo initiated directly by a Telegram host is an EXTERNAL CHANGE
/// synchronized afterward (Task 39b) — this file adds no external-synchronization plumbing.
///
/// Selection-changing commands route through the SAME sanctioned canvas primitives the legacy
/// responder actions use — `selectWord(at:)` / `selectAllText()` — never `canvas.anchor`/`canvas.head`
/// directly (the R7 ratchet).
///
/// **TASK 30 CORRECTION to the sentence above, because it is now only HALF true and the missing half
/// is why `performCommand` does not route these two through this client.** `selectWord(at:)` /
/// `selectAllText()` are the primitives the legacy responder actions *call*, but they are not the
/// whole of what those actions *do*: `select(_:)` and `selectAll(_:)`
/// (`DocumentCanvasView+EditMenu.swift`, now `legacySelect(_:)`/`legacySelectAll(_:)`) each ALSO call
/// `presentEditMenu()`. So this client's `.selectWord`/`.selectAll` commit cases are strictly NARROWER
/// than the responder actions, and routing those witnesses here would have silently deleted the
/// menu re-presentation. They are routed straight to the renamed canvas bodies instead — see
/// `LegacyRichTextInputBackend+Commands.swift`'s header for the full measurement and the same finding
/// for `.paste`. These two cases therefore have **no production caller today**; they remain the
/// client-level definition of the commands (a keyboard-toolbar Select All, stage 2) and stay pinned by
/// `TelegramCommandInputClientTests`.
///
/// **TASK 30 — three call sites in this file were repointed at renamed canvas bodies**
/// (`canvas.copy`/`cut`/`paste` → `canvas.legacyCopy`/`legacyCut`/`legacyPaste`, at `prepare`'s
/// `.copy` branch and `commit`'s `.cut`/`.paste` cases). Those three canvas members are now ROUTED
/// WITNESSES that forward into the backend, so calling them from here would have made this client a
/// leg of a cycle: `canvas.cut` -> `backend.performCommand(.cut)` -> ... -> back into this client.
/// Same shape Task 27a used for `replace` -> `legacyReplace`. The `.copy` leg was the worst of the
/// three: `prepare` returns at its `.copy` branch BEFORE `outstanding`/`pending` are ever assigned,
/// so no token exists on that path at all and no token discipline could ever have broken the loop.
@MainActor
@available(iOS 13.0, *)
final class TelegramCommandInputClient: RichTextInputCommandClient {
    /// `unowned`, deliberately, not `weak` — see `TelegramDocumentInputClient`'s doc comment for the
    /// full rationale (the canvas strictly outlives its clients). A test discarding the canvas via `_`
    /// traps; bind it and use `withExtendedLifetime` instead.
    private unowned let canvas: DocumentCanvasView
    /// `weak`, NOT `unowned` — mirrors `TelegramPresentationInputClient.facade`: the facade does not
    /// strictly outlive this client in every host configuration (`facade: RichTextEditorView?`), and
    /// undo/redo must tolerate a nil/deallocated facade rather than trap (see `performUndo`/`performRedo`).
    private weak var facade: RichTextEditorView?

    /// The single outstanding preparation, if any — mirrors `TelegramDocumentInputClient.outstanding`.
    private var outstanding: RichTextInputPreparedCommand?
    /// The command `outstanding` was prepared from, plus the `sender` it was prepared with (unused by
    /// every canvas responder action today, but carried through rather than silently dropped). Always
    /// non-nil exactly when `outstanding` is non-nil; consumed together in `commit`.
    private var pending: RichTextInputCommand?
    private var pendingSender: Any?

    init(canvas: DocumentCanvasView, facade: RichTextEditorView?) {
        self.canvas = canvas
        self.facade = facade
    }

    /// The current selection, in the seam's canonical shape. Read-through, like every other client —
    /// duplicated per-client rather than shared, matching `TelegramDocumentInputClient.currentSelection()`.
    private func currentSelection() -> RichTextCanonicalSelection {
        RichTextCanonicalSelection(anchor: .downstream(canvas.anchor), head: .downstream(canvas.head))
    }

    /// A terminal, unperformed, no-change result — the shared shape for "unavailable" and for the
    /// foreign/repeated-commit violation path.
    private func unperformedResult() -> RichTextInputCommandResult {
        RichTextInputCommandResult(performed: false, revision: canvas.documentRevision,
                                   selection: currentSelection(), contentChanged: false, selectionChanged: false)
    }

    /// INVENTED policy (not dictated by the brief — pinned by
    /// `TelegramCommandInputClientTests.test_undoAndRedoRouteThroughTheFacade` /
    /// `…_withoutFacade_fallsBackToDirectCanvasInvocation`): prefer the facade's `undo()`/`redo()` (which
    /// finalizes marked text, drives the undo manager, AND fires a trailing `onChange` once the manager
    /// settles — `RichTextEditorView.swift:440-441`), so a host watching `onChange` sees the same
    /// notification it would from a nav-bar undo pill. When there is no facade, fall back to the same
    /// two operations directly on the canvas, minus the notification nothing is listening for.
    private func performUndo() {
        if let facade {
            facade.undo()
        } else {
            canvas.finalizeMarkedText()
            canvas.effectiveUndoManager?.undo()
        }
    }
    private func performRedo() {
        if let facade {
            facade.redo()
        } else {
            canvas.finalizeMarkedText()
            canvas.effectiveUndoManager?.redo()
        }
    }

    /// TASK 30 — the manager the routed `DocumentCanvasView.undoManager` override answers with.
    ///
    /// `canvas.effectiveUndoManager`, which is `undoManagerOverride ?? ownUndoManager`
    /// (`DocumentCanvasView.swift`) — the SAME expression the pre-seam override returned, so the
    /// routing is value-identical while attached. NOT the facade: the brief's phrase "`command`'s
    /// facade-held manager" describes something that does not exist — `RichTextEditorView` holds no
    /// undo manager at all, its `undo()`/`redo()` reach straight through to
    /// `canvas.effectiveUndoManager` (`RichTextEditorView.swift`). Answering from the facade would
    /// therefore have to invent one.
    ///
    /// D14 is intact: this READS the canvas's manager, exactly as `canPerform(.undo)` and
    /// `performUndo()` above already do. No undo state moves here.
    var undoManager: UndoManager? { canvas.effectiveUndoManager }

    /// Whether this command's `.ready` preparation should declare `contentWillChange`. Selection-only
    /// commands (`selectWord`/`selectAll`) never touch content; `cut`/`paste`/`undo`/`redo` may.
    /// `copy` and `delete` never reach this — see `prepare`/`canPerform`.
    private func commandMutatesContent(_ command: RichTextInputCommand) -> Bool {
        switch command {
        case .cut, .paste, .undo, .redo: return true
        case .selectWord, .selectAll, .copy, .delete: return false
        }
    }
}

@available(iOS 13.0, *)
extension TelegramCommandInputClient {
    /// Consults the existing predicates directly (never `canvas.canPerformAction(_:withSender:)`
    /// itself — that is Task 30's ROUTING TARGET, calling INTO this client; consulting it here would be
    /// circular). The clipboard trio defers to `clipboardCanPerformAction(_:)`
    /// (`DocumentCanvasView+Clipboard.swift`).
    ///
    /// `selectWord`/`selectAll` USED TO duplicate predicates that lived inline in the witness's own
    /// `select:`/`selectAll:` cases (`DocumentCanvasView+EditMenu.swift`) — there was no
    /// separately-callable canvas method to defer to, so the client copied them. **FIX ROUND 1
    /// (Min-3): that is no longer true, and the sentence this replaces was actively misleading.** Task
    /// 30 routed `canPerformAction(_:withSender:)`, which DELETED those two `case`s: the selector now
    /// maps to `.selectWord`/`.selectAll` and comes straight here. **The two predicates below are
    /// therefore the SOLE definition** — there is no second copy anywhere in the package to keep in
    /// sync, and the old `+EditMenu.swift:85-91` citation now points at
    /// `dismissEditMenuForSelectionOrTextChange()`. Change them here and the edit menu changes; nothing
    /// else needs touching. The corresponding consumer-side fact — that `hasText`'s two in-tree readers
    /// collapsed into one — is recorded at `LegacyRichTextInputBackend+Insertion.swift`'s `hasText`.
    ///
    /// **TASK 30 RE-VERIFIED BOTH LEGS OF THAT, rather than assuming them.** (1)
    /// `canPerformAction(_:withSender:)` IS now routed — it maps the selector with
    /// `richTextInputCommand(for:)` and asks `inputBackend.canPerformCommand`, which lands here — and
    /// this method still does not call it back, so the loop the comment above predicts is still not
    /// closed. (2) `clipboardCanPerformAction(_:)` is a DIFFERENT, UNROUTED canvas method (it has no
    /// `override`, no `UIResponder` witness, and Task 30 did not touch it), so the three clipboard
    /// cases are terminal too. (3) The `.selectWord`/`.selectAll` predicates are inline duplicates and
    /// call nothing routed. The one thing they DO reach that is routed is `canvas.hasText` (Task 27a)
    /// and `canvas.beginningOfDocument`/`endOfDocument` (Task 24) — each a one-way hop into the
    /// backend's document client, never back into this client.
    ///
    /// INVENTED (not dictated by the brief): `.delete` is unconditionally unavailable. The legacy canvas
    /// implements no `delete(_:)` responder action at all (confirmed against the UIKit SDK header —
    /// `UIResponderStandardEditActions` has no `undo(_:)`/`redo(_:)` either, see `richTextInputCommand`'s
    /// doc comment below), and `super.canPerformAction(delete:)` therefore **consults the NEXT RESPONDER
    /// and answers `false` for every chain this package can produce**. Returning
    /// `false` here — rather than inventing a NEW capability the legacy backend never had — is what keeps
    /// this a zero-behavior-change seam.
    ///
    /// **FIX ROUND 1 (Min-8) — that sentence used to read "so `super.canPerformAction(delete:)` already
    /// answers `false` today", which is only half the mechanism, and the half it omitted is the half
    /// someone would re-verify wrongly.** `UIResponder.canPerformAction(_:withSender:)`'s default
    /// returns `true` if the RECEIVER implements the action and **otherwise asks the next responder**,
    /// so the pre-seam answer was the responder CHAIN's, not the canvas's. In a unit test (nil next
    /// responder) it is `false`; in the app it depends on whatever sits above `DocumentCanvasView`, and
    /// nothing in Telegram's chain plausibly implements `delete:`. Stated chain-dependently so nobody
    /// later "verifies" it by re-reading the canvas alone and concludes the disclosure is settled.
    /// **This also corrects the Task-30 coordinator supplement §5**, which asserted the same
    /// chain-independent reason ("nothing implements `delete(_:)`, so `super` says false too") — the
    /// conclusion holds, the justification did not, and the new unconditional `false` is if anything
    /// SAFER: the old composition could have made the canvas the `target(forAction:)` for an action it
    /// cannot perform. **TASK 30 LANDED and it does reproduce that `false` exactly**
    /// — the routed `canPerformAction(_:withSender:)` maps `delete:` (which it never had a `case` for)
    /// and asks this client instead of `super`, and both answer `false`. The DECIDER moved, the answer
    /// did not; filed as this family's one axis-4 divergence (`+EditMenu.swift`,
    /// `LegacyRichTextInputBackend+Commands.swift`). Pinned by `test_canPerformDeleteIsAlwaysFalse` and,
    /// from the witness side, by
    /// `CommandRouterTests.test_canPerformAction_deleteIsStillFalse_thoughTheDeciderMoved`.
    /// `.undo`/`.redo` consult the same source `EditorState.canUndo`/`canRedo` read
    /// (`DocumentCanvasView+State.swift:70-71`) — `canvas.effectiveUndoManager?.canUndo`/`canRedo`.
    func canPerform(_ command: RichTextInputCommand, sender: Any?) -> Bool {
        switch command {
        case .copy:
            return canvas.clipboardCanPerformAction(#selector(DocumentCanvasView.copy(_:)))
        case .cut:
            return canvas.clipboardCanPerformAction(#selector(DocumentCanvasView.cut(_:)))
        case .paste:
            return canvas.clipboardCanPerformAction(#selector(DocumentCanvasView.paste(_:)))
        case .selectWord:
            return canvas.hasText && canvas.selFrom == canvas.selTo
                && canvas.leafRegion(containingGlobal: canvas.head) != nil
        case .selectAll:
            let begin = (canvas.beginningOfDocument as? LegacyTextPosition)?.offset ?? 0
            let end = (canvas.endOfDocument as? LegacyTextPosition)?.offset ?? canvas.documentSize
            return canvas.hasText && !(canvas.selFrom <= begin && canvas.selTo >= end)
        case .delete:
            return false
        case .undo:
            return canvas.effectiveUndoManager?.canUndo ?? false
        case .redo:
            return canvas.effectiveUndoManager?.canRedo ?? false
        }
    }

    /// `.copy` is ALWAYS resolved as `.terminal` (the spec's canonical terminal-no-change example): it
    /// performs — writing the pasteboard — exactly when available, but never mutates content or
    /// selection, so there is nothing left for a later `commit` to do. Any other unavailable command is
    /// likewise terminal, `performed: false`. An available non-copy command becomes `.ready` with a
    /// fresh, single-use token (Task 14's discipline, mirrored exactly): a second preparation while one
    /// is outstanding is a contract violation that discards the stale one.
    func prepare(_ command: RichTextInputCommand, sender: Any?) -> RichTextInputCommandPreparation {
        if command == .copy {
            let available = canPerform(.copy, sender: sender)
            if available { canvas.legacyCopy(sender) }
            return .terminal(RichTextInputCommandResult(
                performed: available, revision: canvas.documentRevision,
                selection: currentSelection(), contentChanged: false, selectionChanged: false))
        }
        guard canPerform(command, sender: sender) else {
            return .terminal(unperformedResult())
        }
        if outstanding != nil {
            RichTextInputContractViolation.report(
                "a second command preparation was requested while one was outstanding")
            outstanding = nil
        }
        let prepared = RichTextInputPreparedCommand(
            token: UUID(), contentWillChange: commandMutatesContent(command), selectionWillChange: true)
        outstanding = prepared
        pending = command
        pendingSender = sender
        return .ready(prepared)
    }

    /// Runs the command's existing action and reports `(performed, revision, selection, contentChanged,
    /// selectionChanged)`. `contentChanged`/`selectionChanged` are derived by diffing
    /// `documentRevision`/the selection around the call — exactly how `contentChanged` is already
    /// defined elsewhere in this legacy path (`+Editing.swift:1181`:
    /// `contentChanged: documentRevision != revisionBefore`), not a new definition invented for this
    /// client. INVENTED (not dictated by the brief): this diffing approach itself, since none of
    /// `cut`/`paste`/`selectWord(at:)`/`selectAllText()`/undo/redo return a structured before/after —
    /// pinned by every commit test below that asserts `contentChanged`/`selectionChanged`.
    ///
    /// Token discipline mirrors `TelegramDocumentInputClient.commitPreparedMutation` exactly: a foreign
    /// or already-consumed token reports a contract violation and a `performed: false`, no-change result.
    func commit(_ prepared: RichTextInputPreparedCommand) -> RichTextInputCommandResult {
        guard let outstanding, outstanding == prepared, let command = pending else {
            RichTextInputContractViolation.report(
                "commit of a foreign or already-consumed command preparation token")
            return unperformedResult()
        }
        self.outstanding = nil
        self.pending = nil
        let sender = pendingSender
        self.pendingSender = nil

        let revisionBefore = canvas.documentRevision
        let selectionBefore = currentSelection()

        switch command {
        case .cut:
            canvas.legacyCut(sender)
        case .paste:
            canvas.legacyPaste(sender)
        case .selectWord:
            canvas.selectWord(at: canvas.head)
        case .selectAll:
            canvas.selectAllText()
        case .undo:
            performUndo()
        case .redo:
            performRedo()
        case .copy, .delete:
            // Unreachable: `.copy` is always resolved as `.terminal` in `prepare` (above), and `.delete`
            // is never available in this legacy backend (see `canPerform`), so neither is ever prepared
            // as `.ready` — `pending` can never hold one of these at this point.
            RichTextInputContractViolation.report(
                "commit received a command that `prepare` should never have made `.ready`")
        }

        let selectionAfter = currentSelection()
        return RichTextInputCommandResult(
            performed: true,
            revision: canvas.documentRevision,
            selection: selectionAfter,
            contentChanged: canvas.documentRevision != revisionBefore,
            selectionChanged: selectionAfter != selectionBefore)
    }
}

/// Nil means "not a backend command": the canvas keeps its existing handling and falls through to
/// `super` (the legacy `UIMenuItem` actions at `+EditMenu.swift:140-174` — `legacyBold`/`legacyItalic`/
/// `legacyUnderline`/`legacyLookUp`/`legacyShare` — and the 6 spelling-menu selectors `spellGuess0…3`/
/// `spellNoop`/`spellRevert`).
///
/// NOTE on the brief vs. reality: `UIResponderStandardEditActions` (checked against the iOS SDK's
/// `UIResponder.h`) declares NO `undo(_:)`/`redo(_:)` selectors at all — hardware ⌘Z/⌘⇧Z, shake-to-undo,
/// and the system Edit-menu Undo/Redo all act directly on the responder chain's `undoManager` (see this
/// package's own `CLAUDE.md`), never through a `UIResponderStandardEditActions` witness. So this table
/// maps exactly SIX selectors (`copy:`/`cut:`/`paste:`/`select:`/`selectAll:`/`delete:`), not seven —
/// there is no `undo:`/`redo:` selector for it to map. `RichTextInputCommand.undo`/`.redo` are reached
/// only by a caller that already holds the command value directly (e.g. a keyboard-toolbar Undo/Redo
/// button), never via this selector translation. **TASK 30 CONFIRMED THAT AND BUILT FOR IT**: its
/// `performCommand(_:sender:)` routes `.undo`/`.redo`/`.delete` — the three commands with no canvas
/// witness — through this client, and the other five straight to the renamed canvas bodies. So a
/// future toolbar button reaches `performUndo()`/`performRedo()` here; nothing else does today.
@available(iOS 13.0, *)
func richTextInputCommand(for action: Selector) -> RichTextInputCommand? {
    switch action {
    case #selector(UIResponderStandardEditActions.copy(_:)): return .copy
    case #selector(UIResponderStandardEditActions.cut(_:)): return .cut
    case #selector(UIResponderStandardEditActions.paste(_:)): return .paste
    case #selector(UIResponderStandardEditActions.select(_:)): return .selectWord
    case #selector(UIResponderStandardEditActions.selectAll(_:)): return .selectAll
    case #selector(UIResponderStandardEditActions.delete(_:)): return .delete
    default: return nil
    }
}
#endif
