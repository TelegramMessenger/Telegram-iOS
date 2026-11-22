#if canImport(UIKit)
import UIKit

/// TASK 28 — Family 5 (backward deletion). One witness, `deleteBackward()`, and it is a PLAIN D24
/// forward, exactly the shape Task 27b gave `insertText(_:)` under the user's D35 ruling (Option A,
/// 2026-08-19).
///
/// **Why a plain forward rather than the `prepareAndRun` transaction that used to live in
/// `+Mutation.swift`.** Task 27 measured both halves on the sibling witness: routing a mutation
/// witness onto that transaction prepares against the backend's OWN `documentRevision` /
/// `canonicalSelectionStorage`, which nothing in `Sources/` keeps in step with the canvas until Task
/// 35, so `ensureCanonicalSelectionIsCurrent` rejects the operation with `.revisionMismatch` into a
/// lifecycle client whose `backendDidRejectMutation` is `{}`; and repairing only that exposes the
/// irreducible half — `runMutation`'s FIXED four-notification bracket cannot reproduce a witness's
/// PER-BRANCH one. For `deleteBackward` the per-branch spread is the widest in the package: **24**
/// `editing { … }` call sites (18 bare, 6 `editing(coalescing: .deleting)`) plus branches that emit
/// nothing at all (the media-gap no-ops, the caret-only `setCaret` arm, the `guard !boxes.isEmpty`
/// early return) and branches that emit through a self-bracketing helper (`unwrapBlockQuoteLevel()`,
/// `deleteTableRow()`, `deleteTableColumn()`).
///
/// The transaction body that used to be `deleteBackward()`'s did not disappear — it moved to the
/// TEST-ONLY reference conformer `ReferenceMutationBackend` (`T/Support/`), which is what the mutation
/// contract suites now run against. It describes a backend that OWNS its mutations, which is stage 2's
/// shape and not this conformer's.
@available(iOS 13.0, *)
extension LegacyRichTextInputBackend {

    // MARK: - `deleteBackward()`

    /// Was `DocumentCanvasView.deleteBackward()`, now `legacyDeleteBackward()`. Forwarded **BARE** — no
    /// `notifyingContentAndSelectionChange`, no `publishState`, no transaction and therefore no
    /// `endTransaction()`. The hook brackets itself, and PER BRANCH: read the Phase-4 preamble's
    /// corrected "forwards to `legacyX`" rule before changing this shape. (The task brief's Step 5 still
    /// asks for the bracket; its own banner corrects that, and
    /// `DeletionRouterTests.test_deleteBackward_emitsExactlyTheWitnessesOwnBracket_theBackendAddsNoneOfItsOwn`
    /// pins the corrected shape — verified red against the bracket, six recorded events becoming ten.)
    ///
    /// **The four-axis divergence audit, per axis.**
    /// 1. *Clamp vs reject* — N/A / no divergence. The pre-seam witness clamped nothing of its own and
    ///    received no offsets to clamp: it takes no parameters at all. Every branch reads the live
    ///    `selFrom`/`selTo`/`head`, and it still does, inside the moved body. The one place bounds are
    ///    resolved — `rangeExpandedToScalarBoundaries` / `graphemeClusterLengthBeforeCaret` — is inside
    ///    that body and moved with it.
    /// 2. *nil / wrong-type input* — there is no input, so there is no ill-formed input. **The DETACHED
    ///    path is a real axis-2 divergence, and it is the same one `replace(_:withText:)` and
    ///    `insertText(_:)` carry: a Backspace arriving while `legacyCanvas` is nil is now DROPPED.** The
    ///    pre-seam witness ran entirely on canvas state with no host dependency, so it deleted even in
    ///    the five windows `+TextReads.swift`'s Task-24 fix note enumerates (a swallowed `attach`, a
    ///    deallocated-but-attached host, the detach→re-attach window, `deinit`, and a tokenizer query
    ///    during interaction teardown). Accepted rather than repaired: the alternative is a canvas-side
    ///    fallback, i.e. a second copy of the 404-line body this routing exists to move. **No
    ///    `RichTextInputContractViolation` is reported on that path** — and the reason is **PRECEDENT,
    ///    not OS-drivenness**, which is a criterion this member does not actually meet (corrected at
    ///    Task 28's review). The Phase-4 preamble's clause reads "report only where a *PROGRAMMATIC*
    ///    caller could reach the member", and `RichTextEditorView.deleteBackward()` is literally one —
    ///    the public facade the emoji keyboard drives. So the clause's own test does not settle this
    ///    member; what settles it is that **`insertText(_:)` has the IDENTICAL shape** — a UIKit
    ///    entry point plus a public facade forwarder (`RichTextEditorView.insertText(_:)`) — and Task
    ///    27b ruled it silent, reviewed and accepted. Diverging here would give the two halves of one
    ///    keystroke pair opposite detached behaviour for no reason anyone could state. The underlying
    ///    cost is still what makes silence right: a report is a DEBUG `assertionFailure` with no
    ///    reporter installed, so reporting turns a documented teardown window into a trap — and UIKit
    ///    reaches this member far more often than the facade does. **This is a CHANGE from the body that
    ///    used to sit here**, which DID report `"operation on a detached backend: deleteBackward()"`;
    ///    that report moved to `ReferenceMutationBackend` with the transaction it guarded, where it
    ///    still fires — see `BackendAttachmentTests`' detached-drop pair.
    /// 3. *Which store is read* — none here, which is the whole point. The moved body reads the LIVE
    ///    canvas selection and the live `boxes`/`tableSelection`/`imageObjectDeletePending`, exactly as
    ///    before. The rejected shape synthesized the mutation from `canonicalSelectionStorage`, which
    ///    lagged the canvas until Task 35 (D35 finding 1) — that task collapsed the two stores, so the
    ///    two shapes now read the same value and the conclusion is unchanged. See that property's
    ///    declaration for the one normative record of the collapse.
    /// 4. *Which object owns a consulted flag* — every flag this body branches on is the CANVAS's:
    ///    `markedRange` (the composition commit at the top), `tableSelection` (the structural-delete
    ///    branch), `imageObjectDeletePending` (the object-replacement media delete), `imageSelection`.
    ///    The backend's parallel `markedRangeStorage` is a DIFFERENT store that this body must not
    ///    consult — a backend-side re-implementation that consulted it would have taken the wrong
    ///    branch on the very first one. A plain forward consults nothing and cannot.
    ///
    ///    **TASK 29 CORRECTION**, identical to the one on `insertText(_:)`'s axis 4
    ///    (`+Insertion.swift`) — this clause said the store "is written only by
    ///    `runMutation`/`setMarkedText`/`synchronizeAfterExternalChange`, and `canvas.setMarkedText` is
    ///    not routed until Task 29". Task 29 routed it and thereby REMOVED
    ///    `setMarkedText(_:selectedRange:)` from that store's writers (the storage body moved to
    ///    `ReferenceMutationBackend`). The live inventory is at `markedRangeStorage`'s own declaration;
    ///    do not re-derive it here. The conclusion is unchanged and strengthened: after Task 29 no
    ///    routed member writes that store at all.
    ///
    ///    **TASK 41 CLOSED THE SPLIT**: `canvas.markedRange` is a read-only projection of
    ///    `markedRangeStorage`, so "a DIFFERENT store" no longer describes anything and the hazard this
    ///    clause warned about cannot occur. The conclusion stands for the reason it always did.
    ///
    /// **The family-specific axis, and what actually survives routing.** The table structural-selection
    /// delete (`deleteTableStructuralSelection()`) is hooked near the top of the body and was described
    /// as "a command, so it routes through `commandClient`, while everything else routes through
    /// `documentClient`". Under a plain forward that split has nothing to route: NEITHER branch consults
    /// a client — the structural branch runs `deleteTableRow()`/`deleteTableColumn()`/an in-place
    /// `editing { }` entirely on the canvas, and the generic branch runs `applyReplaceOutcome` the same way.
    /// What survives routing is the BRANCH ORDER — the structural arm must keep firing before the
    /// in-cell text branch, since the caret is parked INSIDE a cell while a structural selection is live
    /// — and that is pinned by
    /// `DeletionRouterTests.test_deleteBackward_withATableStructuralSelection_takesTheStructuralBranchFirst`.
    ///
    /// **Who now reaches the canvas body through this member**, so the drop above is not read as
    /// hypothetical. Measured, not assumed — `grep -rn "deleteBackward()" Sources/` outside
    /// `InputBackend/`, comments excluded, is exactly TWO lines: the router itself, and the public
    /// facade `RichTextEditorView.deleteBackward()` (the host input hook the emoji keyboard drives).
    /// Plus UIKit, which calls the witness as `UIKeyInput`. Unlike `insertText(_:)` there are NO
    /// canvas-internal callers of the witness to bounce back out through here. `legacyApplyMutation` is
    /// the one caller that must NOT reach the witness, and Task 28 repointed it (see its ⚠️ note).
    func deleteBackward() {
        legacyCanvas?.legacyDeleteBackward()
    }
}
#endif
