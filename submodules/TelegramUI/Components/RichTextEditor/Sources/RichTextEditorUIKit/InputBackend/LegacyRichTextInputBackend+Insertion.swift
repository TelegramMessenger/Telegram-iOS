#if canImport(UIKit)
import UIKit

/// TASK 27a — Family 4's routable half (`replace(_:withText:)`, `hasText`); **TASK 27b — its third
/// witness, `insertText(_:)`.**
///
/// **Why `insertText(_:)` is a plain forward here rather than the document-client transaction that
/// used to live in `+Mutation.swift`.** Task 27 measured both halves of the alternative: routing
/// `canvas.insertText` into that transaction makes typing a silent NO-OP (it prepares against the
/// backend's own `documentRevision` / `canonicalSelectionStorage`, which nothing in `Sources/` kept
/// in step with the canvas until Task 35 [the SELECTION half of that lag is now gone — see
/// `canonicalSelectionStorage`'s declaration; `documentRevision` still lags, so the measurement below
/// still stands], so `ensureCanonicalSelectionIsCurrent` rejects every
/// keystroke with `.revisionMismatch` into a lifecycle client whose `backendDidRejectMutation` is
/// `{}`); and repairing only that exposes the irreducible half — `runMutation`'s FIXED
/// four-notification bracket cannot reproduce the witness's PER-BRANCH one (its marked-commit branch
/// is text-only, pinned by
/// `DelegateTraceCharacterizationTests.test_insertTextWhileMarked_emitsATextOnlyBracket`). The user
/// ruled deviation **D35** on 2026-08-19: Option A, the plain `legacyCanvas` forward, which is also
/// what D27's own row, completion bullet C5 and the Task-22b in-tree comments always described.
///
/// The transaction body that used to be `insertText(_:)`'s did not disappear — it moved to the
/// TEST-ONLY reference conformer `ReferenceMutationBackend` (`T/Support/`), which is what the mutation
/// contract suites now run against. It describes a backend that OWNS its mutations, which is stage 2's
/// shape and not this conformer's.
///
/// All three members below are PLAIN D24 forwards — no transaction, no delegate bracket, no
/// document-client mutation (`hasText` reads through the document client; see its own note). That is
/// the same shape Families 1-3 used, and for `replace(_:withText:)`/`insertText(_:)` it is
/// load-bearing rather than merely convenient: each canvas body already runs its own bracket, so a
/// bracket here would double it (see `legacyReplace`'s and `legacyInsertText`'s own doc comments,
/// `DocumentCanvasView+UITextInput.swift`).
@available(iOS 13.0, *)
extension LegacyRichTextInputBackend {

    // MARK: - `replace(_:withText:)`

    /// Was `DocumentCanvasView.replace(_:withText:)`. The `as?` cast and its early return stay HERE,
    /// not at the canvas router: dropping a non-`LegacyTextRange` write is the backend's decision to
    /// make, exactly as the floating-cursor drop is for `selectedTextRange` (Task 26). A router that
    /// pre-empted the cast would hide the drop from the router-spy tests.
    ///
    /// The range's `from`/`to` are forwarded RAW — unordered and unclamped — because that is precisely
    /// what the pre-seam body received. `legacyReplace` does the `min`/`max` itself, and
    /// `applySelectionReplaceOutcome` clamps; introducing either here would move a decision the canvas body
    /// already owns.
    ///
    /// **DIVERGENCE (axis 2 of the four-axis audit), disclosed — the detached path DROPS AN EDIT.**
    /// Stated separately from the cast above because it is a DIFFERENT INPUT with a DIFFERENT pre-seam
    /// outcome, and an earlier version of this comment wrongly folded the two together: a foreign range
    /// was always dropped, but a **valid** `LegacyTextRange` was always **performed**. The pre-seam
    /// witness ran entirely on canvas state and had no host dependency at all, so it edited the document
    /// even in the windows where `legacyCanvas` is now nil (the five states `+TextReads.swift`'s Task-24
    /// fix note enumerates: a swallowed `attach`, a deallocated-but-attached host, the detach→re-attach
    /// window, `deinit`, and a tokenizer query during interaction teardown). Routed, such a call
    /// silently no-ops — and it loses the autocorrect flag too, which the pre-seam body would also have
    /// lost only if the read failed. Accepted rather than repaired: the alternative is a canvas-side
    /// fallback path, i.e. a second implementation of the body this task exists to move.
    ///
    /// **Still no `RichTextInputContractViolation` on that path**, and NOT on the cast-equivalence
    /// reasoning: `replace(_:withText:)` is UIKit-driven (autocorrect, dictation, and `cut(_:)` —
    /// `DocumentCanvasView+Clipboard.swift`), so a report here would turn a documented teardown window
    /// into a DEBUG trap on a path the OS can drive at any time. Same precedent `text(in:)` follows.
    func replace(_ range: UITextRange, withText text: String) {
        guard let r = range as? LegacyTextRange else { return }
        legacyCanvas?.legacyReplace(globalFrom: r.from.offset, globalTo: r.to.offset, text: text)
    }

    // MARK: - `insertText(_:)`

    /// Was `DocumentCanvasView.insertText(_:)`, now `legacyInsertText(_:)`. Forwarded **BARE** — no
    /// `notifyingContentAndSelectionChange`, no `publishState`, no transaction and therefore no
    /// `endTransaction()`. The hook brackets itself, and PER BRANCH: read the Phase-4 preamble's
    /// corrected "forwards to `legacyX`" rule before changing this shape.
    ///
    /// **The four-axis divergence audit, per axis.**
    /// 1. *Clamp vs reject* — N/A. The witness clamped nothing of its own; every branch reads the live
    ///    `selFrom`/`selTo`/`head`, and it still does, inside the moved body.
    /// 2. *nil / wrong-type input* — the parameter is a non-optional `String`, so there is no
    ///    ill-formed input to resolve. **The DETACHED path is a real axis-2 divergence, and it is the
    ///    same one `replace(_:withText:)` carries: a keystroke arriving while `legacyCanvas` is nil is
    ///    now DROPPED.** The pre-seam witness ran entirely on canvas state with no host dependency, so
    ///    it typed even in the five windows `+TextReads.swift`'s Task-24 fix note enumerates (a
    ///    swallowed `attach`, a deallocated-but-attached host, the detach→re-attach window, `deinit`,
    ///    and a tokenizer query during interaction teardown). Accepted rather than repaired: the
    ///    alternative is a canvas-side fallback, i.e. a second copy of the body this routing exists to
    ///    move. **No `RichTextInputContractViolation` is reported on that path** — `insertText` is the
    ///    OS's per-keystroke entry point, so a report would turn a documented teardown window into a
    ///    DEBUG trap on the hottest path in the editor. Same precedent `text(in:)` and
    ///    `replace(_:withText:)` follow, and the precedent the Phase-4 preamble's Task-27a correction
    ///    states for OS-driven members: drop silently, do not report.
    /// 3. *Which store is read* — none here, which is the whole point. The moved body reads the LIVE
    ///    canvas selection, exactly as before. The rejected shape read `canonicalSelectionStorage`
    ///    instead, which lagged the canvas until Task 35 — measured at `(0,0)` against a live caret of
    ///    8 (D35 finding 1). **TASK 35 collapsed the two stores**, so that measurement is history and
    ///    the two shapes now read the same value; the conclusion is unchanged and now trivially true
    ///    (the live canvas selection IS `canonicalSelectionStorage`). See its declaration.
    /// 4. *Which object owns a consulted flag* — the marked-commit branch keys on the CANVAS's
    ///    `markedRange`, and still does. The backend's parallel `markedRangeStorage` is a DIFFERENT
    ///    store that this member must not consult, and a backend-side re-implementation that consulted
    ///    it would have taken the wrong branch. A plain forward consults nothing and cannot.
    ///
    ///    **TASK 29 CORRECTION — two clauses here had gone false and this is a divergence audit, so
    ///    they mattered.** It said `markedRangeStorage` "is written only by
    ///    `runMutation`/`setMarkedText`/`synchronizeAfterExternalChange`" and that "`canvas.setMarkedText`
    ///    is not routed until Task 29". Task 29 routed it, and in doing so REMOVED
    ///    `setMarkedText(_:selectedRange:)` from that store's writers entirely (the storage body moved
    ///    to `ReferenceMutationBackend`). The store's live writers are now `runMutation`,
    ///    `reconcileMarkedTextForExternalChange`, `clearCompositionState()` and
    ///    `finalizeMarkedTextForDetach()` — the inventory at `markedRangeStorage`'s own declaration is
    ///    the record; do not re-derive it here. The CONCLUSION above is unchanged and in fact
    ///    strengthened: after Task 29 no routed member writes that store at all, so the gap between it
    ///    and `canvas.markedRange` is wider, not narrower (see `+MarkedText.swift`'s two-store header,
    ///    which Task 41 closes).
    ///
    ///    **TASK 41 CLOSED IT, and this axis-4 clause is now trivially true rather than a warning.**
    ///    `canvas.markedRange` is a read-only projection of `markedRangeStorage`, so the two are one
    ///    value: "the parallel store is a DIFFERENT store" no longer describes anything. What survives
    ///    is the conclusion, unchanged — a plain forward consults nothing and therefore cannot consult
    ///    the wrong thing.
    ///
    /// **Who now reaches the canvas body through this member**, so the drop above is not read as
    /// hypothetical: UIKit itself, the public facade (`RichTextEditorView.insertText(_:)`), and three
    /// canvas-internal callers that call the WITNESS and therefore bounce out through here and back —
    /// `DocumentCanvasView+MarkedText.swift`'s composition commit, `DocumentCanvasView.swift`'s
    /// hardware-Return handler, and `DocumentCanvasView+Formula.swift`'s LaTeX insert. They are left
    /// calling the witness deliberately, following `cut(_:)`→`replace(_:withText:)`'s Task-27a
    /// precedent; `legacyApplyMutation` is the one caller that must NOT (see its ⚠️ note).
    func insertText(_ text: String) {
        legacyCanvas?.legacyInsertText(text)
    }

    // MARK: - `hasText`

    /// Was `DocumentCanvasView.hasText` (`documentSize > 0`). Routed through the DOCUMENT CLIENT, not
    /// `legacyCanvas`, because this is exactly the case Task 24 reserved the client for: "a pure
    /// document-length value read where the client's value is provably identical to the canvas's own
    /// `documentSize` with no differing bounds-rejection semantics to worry about". Verified, not
    /// assumed: `TelegramDocumentInputClient.utf16Length` is `canvas.documentSizeValue`
    /// (`Clients/TelegramDocumentInputClient.swift`), and `documentSizeValue` is literally
    /// `documentSize` (`DocumentCanvasView.swift`). Same storage, one hop apart.
    ///
    /// **RECORDED DEVIATION from Task 27a's own ruling, which said "route both as plain D24 forwards".**
    /// The client path is used instead, and the ruling's author accepted it on review: that phrasing was
    /// aimed at `replace`'s bracket hazard and over-applied to a pure READ, where the client path is the
    /// shape Families 1-2 already established and the only one that makes progress against completion
    /// bullet C5. Recorded here rather than left implicit — an accepted deviation that goes unrecorded
    /// reads as drift.
    ///
    /// DIVERGENCE, disclosed (axis 2 of the four-axis audit): with no attached document client this
    /// answers `false`, where the pre-seam witness kept answering `documentSize > 0` from canvas state
    /// that is still alive during the documented "attached but host gone" / detach→re-attach windows.
    /// `false` is both the pre-Task-24 stub's own answer (`+Unwitnessed.swift`, removed by this
    /// task) and the safe one — "no text" disables the keyboard's delete affordance rather than
    /// promising content the backend cannot reach.
    ///
    /// **Who reads it, so the divergence is not mistaken for hypothetical**: besides UIKit itself, two
    /// in-tree production readers gate edit-menu items on it —
    /// `DocumentCanvasView+EditMenu.swift`'s `canPerformAction` (the `select` and `selectAll` cases) and
    /// `TelegramCommandInputClient`'s `.selectWord`/`.selectAll` cases. Both are responder/menu
    /// evaluations the OS can make at times this code does not choose. Whether any of them can run while
    /// `document` is nil is NOT determinable from this source tree — I could not find a path that does,
    /// which is not the same as there being none.
    ///
    /// **TASK 30 COLLAPSED THOSE TWO READERS INTO ONE, and the conclusion is unchanged.**
    /// `canPerformAction` no longer has `select`/`selectAll` cases at all: it maps the selector and asks
    /// `canPerformCommand`, which asks the command client — so the client's `.selectWord`/`.selectAll`
    /// cases are now the ONLY in-tree production readers, and the OS-driven menu evaluation reaches them
    /// THROUGH this member rather than beside it. One reader, same read, same window.
    ///
    /// No `RichTextInputContractViolation` is reported: UIKit polls `hasText` on the keyboard's
    /// per-keystroke evaluation path, where an unthrottled report would flood, so this follows
    /// `text(in:)`'s precedent rather than `beginningOfDocument`'s.
    var hasText: Bool {
        guard let document = self.document else { return false }
        return document.utf16Length > 0
    }
}
#endif
