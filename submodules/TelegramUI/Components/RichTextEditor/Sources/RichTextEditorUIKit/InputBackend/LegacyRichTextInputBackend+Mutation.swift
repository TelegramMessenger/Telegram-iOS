#if canImport(UIKit)
import UIKit

/// TASK 22b. The document-mutation contract that `BackendMutationContractTests` pins: prepare the
/// mutation, run the four `UITextInputDelegate` notifications, commit, adopt the result, publish.
///
/// **TASK 27b — THE CONTRACT THIS FILE IMPLEMENTS DESCRIBES A BACKEND THAT OWNS ITS MUTATIONS, WHICH
/// THIS ONE IS NOT.** Task 27 measured that routing `DocumentCanvasView.insertText(_:)` onto a
/// `prepareAndRun` body makes typing a silent no-op (it prepares against the backend's own
/// `documentRevision` / `canonicalSelectionStorage`, which nothing kept in step with the canvas until
/// Task 35 [the SELECTION half of that lag is gone as of that task — see that property's declaration
/// for the one normative record; `documentRevision` still lags, and that is what
/// `ensureCanonicalSelectionIsCurrent` keys on], so it rejects every keystroke with `.revisionMismatch`),
/// and that even with that repaired, `runMutation`'s FIXED four-notification bracket cannot reproduce
/// the witness's PER-BRANCH one (its marked-commit branch is text-only). The user ruled deviation
/// **D35** on 2026-08-19: the legacy witnesses become plain `legacyCanvas` forwards, and the mutation
/// contract as written describes **stage 2**.
///
/// So `insertText(_:)`'s body is **gone from this file** — it moved to the test-only reference
/// conformer `ReferenceMutationBackend` (`T/Support/ReferenceMutationBackend.swift`), which is a real
/// `LegacyRichTextInputBackend` for every member EXCEPT the mutation pair, whose bodies it carries and
/// runs through the very machinery below (`prepareAndRun` → `runMutation`). The six contract suites
/// that drive `backend.insertText` construct that conformer from their `makeBackend()`; stage 2
/// replaces it with `IDTextEditorBackend`, for which the contract is a genuine obligation. The
/// machinery itself stays HERE, in production, because that is what those suites exist to pin.
///
/// **TASK 28 did the same for `deleteBackward()`.** Its body is gone from this file too, onto the same
/// conformer, and the member is now a plain `legacyCanvas?.legacyDeleteBackward()` forward
/// (`+Deletion.swift`). The two drive points that reach it (`BackendMutationContractTests`,
/// `BackendSelectionContractTests`) already sat in suites 27b had moved, so no factory and no test body
/// changed. **TASK 29 did the equivalent for `setMarkedText(_:selectedRange:)`** — its Task-22f
/// storage-only body moved to the same conformer and the member is now a plain
/// `legacyCanvas?.legacySetMarkedText(…)` forward (`+MarkedText.swift`). Unlike 27b/28 it DID need a
/// factory change (`BackendMarkedTextPolicyTests`), and no test body changed. `unmarkText()` is named
/// alongside it for symmetry only: it never had a body in this file to move — it was a
/// `+Unwitnessed.swift` stub until Task 29 routed it. **This file therefore defines
/// no `RichTextKeyInputBackend` member at all any more** — only the machinery.
///
/// **`prepareAndRun` / `runMutation` / `ensureCanonicalSelectionIsCurrent` have NO production entry
/// point, and TASK 28 did not create that state — Task 22b's early bodies only ever LOOKED like one**
/// (the "after Task 28" phrasing was an off-by-one-task claim corrected at Task 27b's review, while
/// `deleteBackward()` still lived here). Re-measured after this task, with the comment-excluding form
/// because a doc comment quoting a pattern is part of the corpus that pattern searches (the
/// self-matching-grep defect gate item 11 carried):
/// `grep -rn "prepareAndRun(\|runMutation(" Sources/ | grep -v "///"` → the two definitions plus the one
/// internal `prepareAndRun` → `runMutation` call, and **no caller outside this file**. The routed
/// `deleteBackward()` reaches `legacyCanvas`, never this machinery; `+Editing.swift`'s `.deleteBackward`
/// case now dispatches to `legacyDeleteBackward()` directly. So this whole file is reached only from
/// tests, through `ReferenceMutationBackend`'s two members. Whoever reaches the Phase 6 gate should say
/// so rather than let the mutation suites read as coverage of a live production path.
///
/// The notify/commit/publish bracket below is what Task 26 extracted (under the names
/// `notifyingContentAndSelectionChange` etc.); `runMutation` still calls the four emitters directly,
/// which is equivalent and unchanged.
///
/// DEVIATION D10 (see the plan's deviations table): the four notifications below are UNCONDITIONAL —
/// they do not consult `RichTextInputPreparedMutation.contentWillChange`/`.selectionWillChange` or
/// `RichTextInputMutationResult.contentChanged`/`.selectionChanged` to decide whether to fire. This
/// mirrors `editing(coalescing:_:)`'s real shape (both will-notifications unconditionally before the
/// body, both did-notifications unconditionally after) and matches Task 26's own interface comment
/// for `notifyingContentAndSelectionChange(_:)`, whose signature carries no flags parameter at all —
/// there is nothing for it to gate on. `BackendMutationContractTests
/// .test_preparationFlags_gateTheWillNotificationsIndependently` pins this unconditional shape
/// directly (both notifications fire even when the fake's preparation flags are false), rather than
/// pinning a hypothetical per-flag gate that would contradict Task 26's own documented signature.
///
/// The two `RichTextInputPreparedMutation`/`RichTextInputMutationResult` flag PAIRS are still
/// consulted for a SEPARATE purpose: `RichTextInputDocumentClient.commitPreparedMutation`'s own
/// doc-comment requires a commit to "agree with the preparation's contentWillChange/
/// selectionWillChange flags" — `runMutation` below is the enforcement of that requirement, reporting
/// a `RichTextInputContractViolation` when a client's result disagrees with its own preparation. That
/// is orthogonal to whether the notifications are gated by the flags (they are not).
@available(iOS 13.0, *)
extension LegacyRichTextInputBackend {
    // MARK: - RichTextKeyInputBackend real bodies

    // `insertText(_:)` USED TO LIVE HERE, and TASK 27b moved it — see this file's header. Its
    // transaction body is now `ReferenceMutationBackend.insertText(_:)` (`T/Support/`), and the
    // witness of that name on THIS conformer is a plain `legacyCanvas` forward (`+Insertion.swift`).
    // `deleteBackward()` USED TO LIVE HERE TOO, and TASK 28 moved it the same way: its transaction
    // body is now `ReferenceMutationBackend.deleteBackward()`, and the member of that name on THIS
    // conformer is a plain `legacyCanvas?.legacyDeleteBackward()` forward (`+Deletion.swift`).
    //
    // So this file no longer defines ANY `RichTextKeyInputBackend` member. What remains below is the
    // MACHINERY those bodies run through — `prepareAndRun`, `runMutation`,
    // `ensureCanonicalSelectionIsCurrent` — which stays HERE, in production, because pinning it is
    // exactly what the mutation contract suites exist to do. TASK 29 DID the equivalent for
    // `setMarkedText(_:selectedRange:)`, whose storage-only body is likewise now
    // `ReferenceMutationBackend`'s and whose routed member is a plain forward in `+MarkedText.swift`.
    // (`unmarkText()` never had a body here to move — it was a `+Unwitnessed.swift` stub.)

    // MARK: - Revision safety (Task 22c): at-most-one rebase before a mutation is prepared
    //
    // Spec: "a stale object is explicitly rebased or rejected; its integer offset is not silently
    // reinterpreted against a new document" + "the backend may request one synchronous rebase and
    // retry once — it may not loop." Deviation D32: `rebase(_:fromRevision:)` is identity-or-nil —
    // there is no offset-mapping algorithm, so a NON-collapsed selection whose anchor and head differ
    // needs its own rebase call per distinct offset (never more than the two endpoints, and never a
    // second call for either endpoint — no loop).

    /// FIX ROUND 1 (review §9/"smaller items"): a single CHOKEPOINT for every mutation entry point,
    /// not duplicated per-caller. Both `insertText`/`deleteBackward` used to inline
    /// "`guard ensureCanonicalSelectionIsCurrent(...) else { construct-a-rejection-mutation; report;
    /// return }` / construct-the-real-mutation; `runMutation`" — a shape a future entry point could
    /// easily reproduce WITHOUT the guard, silently bypassing revision safety. (TASK 29 CORRECTION:
    /// this named "Task 27's `replace(_:withText:)`, Task 29's `setMarkedText`" as the anticipated
    /// future entry points. NEITHER became one — both landed as plain `legacyCanvas` forwards under
    /// D35, and `prepareAndRun` still has no production caller at all. The chokepoint argument is
    /// unaffected; only its worked examples were wrong, and a future `prepareAndRun` caller — Task 41
    /// is the candidate — is who it is really for.) Routing every caller through this one method makes
    /// that impossible: nothing may reach `runMutation` except through here. `build` is called EXACTLY
    /// ONCE per invocation — either to report the rejection (with the STALE, un-rebased selection; the
    /// reviewed prior code path constructed a DIFFERENT, attribute-less mutation for this case, which
    /// this refactor also fixes: `build` is the same closure the success path uses, so a rejected
    /// `insertText` now reports the SAME attributed text a successful one would have) or to run the
    /// real mutation (with the now-current selection).
    ///
    /// FIX ROUND 2: `internal`, not `private` — so that a mutation entry point defined in ANOTHER
    /// `LegacyRichTextInputBackend+*.swift` file (per this class's file-scope-access convention — see
    /// `LegacyRichTextInputBackend.swift`'s "ACCESS LEVEL IS LOAD-BEARING" comment) can call it. A
    /// `private` chokepoint is invisible outside this file, so such an entry point would have no
    /// choice but to re-implement the guard/reject bracket itself — exactly the duplication this
    /// method exists to prevent.
    ///
    /// **TASK 29 CORRECTION — the reason above used to be stated as "so Task 27's
    /// `replace(_:withText:)` / Task 29's `setMarkedText` can call it", and neither does.** Both landed
    /// as plain `legacyCanvas` forwards (D35), so the two members this access level was widened FOR
    /// never materialised. The `internal` level is nonetheless still load-bearing today for a different
    /// reason, and that is why it is not being narrowed back: the test-only `ReferenceMutationBackend`
    /// (`T/Support/`) calls `inner.prepareAndRun(document:host:build:)` from another module entirely,
    /// under `@testable import`, for all three of its re-homed bodies.
    /// TASK 22g ADDITION — the reentrancy half of this chokepoint's job: "New mutation begins only
    /// from `.idle`" (spec) / "Mutating reentry from client or facade callbacks is rejected" (spec).
    /// A client or facade callback fired from INSIDE an in-flight transaction (the realistic cases:
    /// the lifecycle client's `backendDidPublishState`, or the presentation client's `apply`, both
    /// called from `publishState` below) can call back into `insertText`/`deleteBackward` — every
    /// mutation entry point that exists today, and (per this chokepoint's own established role) every
    /// future one Tasks 27/29 add. Guarding HERE, not per-caller, is the same reasoning the chokepoint
    /// itself was built on: a future entry point cannot forget a guard it never has to write.
    ///
    /// This is a REJECTION, not a deferral (unlike `synchronizeAfterExternalChange`'s own reentrant
    /// handling, `LegacyRichTextInputBackend.swift`) — a queued, reentrant KEYSTROKE has no obvious
    /// "apply it once we're idle" semantics the way a host-driven external change does (which
    /// keystroke would it be relative to?), and the spec's own wording for this half is "rejected",
    /// not "deferred". `build` is deliberately NOT called on this path (unlike the revision-mismatch
    /// rejection below, which calls it to report the attempted mutation) — the whole point of
    /// rejecting BEFORE `ensureCanonicalSelectionIsCurrent`/`runMutation` run is that nothing about
    /// this attempt touches the document client at all, so there is nothing genuine to describe back
    /// to the lifecycle client; a `RichTextInputContractViolation` report is the correct channel (spec
    /// failure class 1: a programmer/caller contract violation), not `backendDidRejectMutation` (which
    /// is reserved for a mutation that legitimately reached the document client and was turned down).
    ///
    /// SCOPE, disclosed: this guard does not extend to `setSelection`/`clearCompositionState` (each has
    /// its own single-bracket `transactionPhase = .publishingState … endTransaction()` shape,
    /// `LegacyRichTextInputBackend.swift`) — REJECTING a reentrant call to
    /// either stays a later task's (Task 26 for `setSelection`,
    /// Task 41 for `clearCompositionState` — see the normative note on
    /// `endTransaction()`, `+Attachment.swift`, which is the one place this is now recorded; do not
    /// restate the gap here again). (TASK 29 CORRECTION: this list named `setMarkedText` as a third
    /// such member, owned by Task 29. That member is no longer on this class — Task 29 routed it as a
    /// plain forward and its single-bracket storage body moved to `ReferenceMutationBackend`, carrying
    /// the Task-26 `guard transactionPhase == .idle` guard with it. There is no per-member reentrancy
    /// gap left on THIS class for marked text.) What 22g's own fix round DOES own, because the guard being
    /// defeated is the guard 22g shipped: making the SHARED bracket-exit (`endTransaction()`)
    /// nesting-aware, so a nested (unrejected) call to one of those three cannot end THIS guard's
    /// outer transaction early and reopen the window this guard exists to close.
    /// TASK 22i ADDITION — the per-operation edit-policy gate for the mutation family
    /// (`insertText`/`deleteBackward`, and any future `prepareAndRun` caller). TASK 29 CORRECTION: the
    /// two examples this parenthesis used to give — "Task 27's `replace(_:withText:)`, Task 29's
    /// `setMarkedText` real forward" — both landed as plain `legacyCanvas` forwards instead, so neither
    /// is gated by this and neither ever will be; the real callers today are
    /// `ReferenceMutationBackend`'s re-homed bodies. Read HERE, fresh on every
    /// call — never cached at `attach(to:)` — so a policy change mid-session takes effect on the
    /// very next mutation (`BackendEditPolicyTests
    /// .test_editPolicyIsReadAtOperationTime_notCachedAtAttach`). A not-editable policy blocks the
    /// mutation BEFORE `ensureCanonicalSelectionIsCurrent` ever runs — no rebase call, no
    /// `prepareMutation`, no delegate notification — reported through the SAME
    /// `backendDidRejectMutation` channel a real document-level rejection uses, with `build()`
    /// called (once) to describe the attempt, mirroring the `revisionMismatch` branch immediately
    /// below (same "report the same attributed mutation a successful call would have" shape this
    /// chokepoint's own doc comment already establishes for that branch).
    ///
    /// FIX ROUND 1 (task-22i-review.md Major 2, disclosed rather than removed): this DUPLICATES an
    /// EXISTING gate. `TelegramDocumentInputClient.prepareMutation`
    /// (`Clients/TelegramDocumentInputClient.swift`) already has `guard canvas.editPolicy.isEditable
    /// else { return terminal(.notEditable) }`, immediately after its own revision-mismatch guard —
    /// the identical policy, the identical rejection reason, read from the identical source
    /// (`canvas.editPolicy`, the same value `TelegramLifecycleInputClient.editPolicy` forwards).
    /// `runMutation` below already forwards a `.terminal(.rejected(_))` disposition from
    /// `prepareMutation` to `backendDidRejectMutation` (see its own `.terminal` case) — so THAT
    /// channel already carried `.notEditable` before this task. KEPT ANYWAY, deliberately, because the
    /// two gates serve different architectural purposes even though they agree today: this one lives
    /// at the BACKEND layer and therefore applies to ANY `RichTextInputDocumentClient` plugged in
    /// under `RichTextInputHost` — including `FakeInputDocumentClient` (the contract suite's own
    /// fixture, which has NO policy concept of its own) and, more importantly, whatever document
    /// client Task 41/stage-2's `IDTextEditorBackend` ends up paired with, which is not guaranteed to
    /// reimplement this guard correctly (or at all) inside its own `prepareMutation`. Two disclosed
    /// consequences of keeping both:
    /// 1. **`.notEditable` now has two indistinguishable producers on ONE channel.** Nothing
    ///    downstream of `backendDidRejectMutation` can tell whether the BACKEND'S gate (here) or the
    ///    CLIENT'S gate (`TelegramDocumentInputClient.prepareMutation`) rejected a given mutation —
    ///    both report the identical `(mutation, .notEditable)` shape. This is harmless only because
    ///    nothing currently discriminates on the producer.
    /// 2. **Against the REAL client, this backend-level gate makes the client's own `.notEditable`
    ///    branch UNREACHABLE, not merely redundant.** Because this guard runs BEFORE
    ///    `ensureCanonicalSelectionIsCurrent`/`runMutation`, a not-editable policy is caught here and
    ///    `document.prepareMutation` is never called at all — so once `editPolicy.isEditable` is ever
    ///    `false` in production (it never is today — see `editPolicyDidChange()`'s own doc comment,
    ///    `+Unwitnessed.swift`, for why), the client's identical guard becomes dead code on this
    ///    path. No owning task is named for resolving this (removing the now-redundant client-side
    ///    guard, or giving the two producers distinct reasons) — flagged for whoever next touches
    ///    either gate.
    ///
    /// FIX ROUND 1 (task-22i-review.md Minor 7, recorded): "no rebase call, no `prepareMutation`, no
    /// delegate notification" above is accurate but must not be over-read as "no document-client
    /// contact at all" — `build()` IS still called once here, and the `insertText` builder (since
    /// TASK 27b, `ReferenceMutationBackend.insertText(_:)`'s closure, `T/Support/`) calls
    /// `document.typingAttributes(at:)` to resolve the rejected
    /// mutation's attributed text, exactly as it would for a successful call. That single read is part
    /// of DESCRIBING the attempt (the same "report the same attributed mutation a successful call
    /// would have" shape cited above), not a preparation or commit step — `documentPrepare`/
    /// `documentCommit` correctly never appear, which is what `BackendEditPolicyTests
    /// .test_notEditable_rejectsInsertText_...` actually asserts.
    func prepareAndRun(document: any RichTextInputDocumentClient,
                       host: any LegacyRichTextInputHost,
                       build: () -> RichTextInputMutation) {
        guard transactionPhase == .idle else {
            // FIX ROUND 1 (review Focal Point 3): `transactionPhase` reads `.publishingState` for
            // FOUR distinct call sites (this project's own convention — see
            // `LegacyRichTextInputBackend.swift`'s resolution note near `document.rebase`), not only
            // "the backend is mid-publish" — a reentrant mutation from inside
            // `synchronizeAfterExternalChange`'s nested `rebase` callout, for instance, would report
            // this exact phase too. The clause below keeps the message from reading as more specific
            // than it is.
            //
            // FIX ROUND 1 (review Minor 5) — NAMED CHECK FOR TASKS 27/28, added for real this fix
            // round (the round 1 report claimed this note existed; it did not — see `task-22g-report.md`'s
            // "Fix round 2" section for the correction). `RichTextInputContractViolation.report`
            // (`RichTextInputContractViolation.swift`) calls `assertionFailure` in DEBUG builds when no
            // `reporter` is installed (production has none — only this test suite installs one). So
            // a mutation entry point reachable from a LIVE `legacyCanvas` callback path — this guard
            // rejecting it being exactly what the guard intends — would become a DEBUG TRAP, not a
            // graceful rejection, in any DEBUG build.
            //
            // **TASK 27a DISCHARGED THIS CHECK for the two members it touched; TASK 27b discharged it
            // for `insertText(_:)`; TASK 28 discharged it for `deleteBackward()`; TASK 29 DISCHARGED IT
            // for `setMarkedText(_:selectedRange:)`/`unmarkText()` — the ledger is now closed for every
            // routed witness.** `replace(_:withText:)`, `insertText(_:)` (`+Insertion.swift`),
            // `deleteBackward()` (`+Deletion.swift`) and `setMarkedText(_:selectedRange:)`/
            // `unmarkText()` (`+MarkedText.swift`) are PLAIN D24 forwards: none of them calls
            // `prepareAndRun`, so none can reach this guard at all, in either direction — the routed
            // keystroke, Backspace and IME-composition paths do not touch the transaction machinery.
            // Discharged by SHAPE, not by an audit of callback paths: there is no path from a
            // legacy-canvas callback to this guard when the member that callback would re-enter never
            // opens a transaction. Today the guard is exercised only by the contract suites, through
            // the test-only `ReferenceMutationBackend`'s members, under their overridden `reporter`.
            //
            // Task 29's discharge used this ledger's OWN escape clause, which the previous entry stated
            // in advance: "unless it too lands as a plain forward, in which case the same shape argument
            // discharges it". It did land as a plain forward (D35, Option A), so the shape argument
            // applies unchanged — no live legacy-canvas callback path can reenter a mutation entry point
            // while one is already in flight (the realistic shape: a UIKit responder-chain callback fired
            // synchronously from inside the legacy body), because the routed members open no transaction
            // to be in flight. The storage body that DID open one moved to `ReferenceMutationBackend`,
            // which no legacy-canvas callback can reach.
            //
            // **A future task adding a NEW `prepareAndRun` caller re-opens this ledger and owes the
            // original named check.** Task 41 is the candidate: it moves composition state onto the
            // backend, at which point a marked-text member may stop being a plain forward.
            RichTextInputContractViolation.report(
                "mutating reentry rejected: a new mutation was requested while transactionPhase is " +
                "\(transactionPhase) (this label covers several non-idle call sites, not only an " +
                "in-progress publish) — the outer transaction must return to .idle first")
            return
        }
        guard host.lifecycleClient.editPolicy.isEditable else {
            host.lifecycleClient.backendDidRejectMutation(build(), reason: .notEditable)
            return
        }
        guard ensureCanonicalSelectionIsCurrent(document: document) else {
            host.lifecycleClient.backendDidRejectMutation(build(), reason: .revisionMismatch)
            return
        }
        runMutation(build(), document: document, host: host)
    }

    /// Brings `canonicalSelectionStorage` (and `documentRevision`) up to date with `document`'s own
    /// revision before a mutation is constructed. Returns `true` immediately when nothing is stale
    /// (the common case). When stale, attempts EXACTLY ONE rebase per distinct offset in the current
    /// selection — a collapsed selection (anchor == head) needs only one `document.rebase` call, its
    /// result reused for both endpoints, rather than two redundant calls for the identical position.
    ///
    /// On success, adopts `targetRevision` — the ONE snapshot of `document.revision` taken before any
    /// rebase call ran — as the new `documentRevision`, never a live re-read afterward: the whole
    /// point of committing to one snapshot is that this method fires its rebase(s) once and settles,
    /// rather than chasing a document that might keep moving.
    ///
    /// Returns `false` when a stale position could not be rebased (`document.rebase` returned `nil`
    /// for either endpoint) — the caller must not proceed to `prepareMutation` in that case; nothing
    /// is mutated (selection/revision are left exactly as they were).
    ///
    /// FIX ROUND 1 — recording review §10: against the REAL `TelegramDocumentInputClient`
    /// (`Clients/TelegramDocumentInputClient.swift:67-69`, `rebase(_:fromRevision:) =
    /// fromRevision == revision ? position : nil`), this method's rebase is called ONLY when
    /// `fromRevision (documentRevision) != revision (document.revision)` — i.e. exactly the condition
    /// under which the real client's identity-or-nil rule returns `nil`. So the "adopt and proceed"
    /// success path below is UNREACHABLE against production: every real staleness is a rejection, by
    /// D32 construction, not a defect — D32 deliberately has no offset-mapping algorithm, so there is
    /// no cross-revision position to hand back. `test_realDocumentClient_rebaseAlwaysRejectsAStaleSelection_byD32Construction`
    /// pins this; the success path below is exercised only by the fakes' `rebaseResult` knob.
    func ensureCanonicalSelectionIsCurrent(document: any RichTextInputDocumentClient) -> Bool {
        let targetRevision = document.revision
        guard targetRevision != documentRevision else { return true }
        let fromRevision = documentRevision
        // Named `current…`, not bare `anchor`/`head` — R7's selection-write ratchet greps for
        // `(anchor|head)\s*=` as a proxy for a second writable selection authority, and a bare
        // `let anchor = …`/`let head = …` local would once have tripped it despite being read-only.
        // **TASK 40b: the rename is no longer load-bearing, twice over.** R7 is now
        // `test_exactlyOneWritableSelectionAuthority`, which (a) skips
        // `Sources/RichTextEditorUIKit/InputBackend/` entirely — this file IS the authority — and
        // (b) no longer matches `let`/`var` declarations at all, so the false-positive class this
        // rename dodged does not exist any more. Kept because `currentAnchor`/`currentHead` reads
        // better next to `canonicalSelectionStorage.anchor`, not because a test requires it.
        let currentAnchor = canonicalSelectionStorage.anchor
        let currentHead = canonicalSelectionStorage.head

        guard let rebasedAnchor = document.rebase(currentAnchor, fromRevision: fromRevision) else {
            return false
        }
        let rebasedHead: RichTextInputPosition
        if currentHead == currentAnchor {
            rebasedHead = rebasedAnchor
        } else if let rebasedOther = document.rebase(currentHead, fromRevision: fromRevision) {
            rebasedHead = rebasedOther
        } else {
            return false
        }

        canonicalSelectionStorage = RichTextCanonicalSelection(anchor: rebasedAnchor, head: rebasedHead)
        documentRevision = targetRevision
        return true
    }

    // MARK: - The shared prepare/notify/commit/publish bracket

    /// Spec steps 1-9, in order. `document`/`host` are passed in already-unwrapped by the two callers
    /// above (both already checked `isAttached`) — this is not itself a public contract member, so it
    /// does not re-guard.
    private func runMutation(_ mutation: RichTextInputMutation,
                             document: any RichTextInputDocumentClient,
                             host: any LegacyRichTextInputHost) {
        switch document.prepareMutation(mutation, expectedRevision: documentRevision) {
        case .terminal(let result):
            // Spec step 2: a terminal rejection or no-change stops HERE — no delegate notification,
            // no commit, no publication. A REJECTION is still reported to the lifecycle client
            // (`backendDidRejectMutation` is a dedicated signal, distinct from both the
            // `UITextInputDelegate` notifications and `backendDidPublishState`'s publication, per
            // that protocol's own doc comment); a NO-CHANGE has no rejection reason to report, so it
            // is silent.
            if case .rejected(let reason) = result.disposition {
                host.lifecycleClient.backendDidRejectMutation(mutation, reason: reason)
            }
            return

        case .ready(let prepared):
            // FIX ROUND 2 (review Major): routed through `withTransaction(_:)` (`+Attachment.swift`)
            // instead of a hand-paired `activeTransactionDepth += 1` / `endTransaction()` — see that
            // method's own doc comment for why the pair must not be hand-paired at each call site.
            withTransaction {
                transactionPhase = .notifyingWillChange
                notifyTextWillChange()
                notifySelectionWillChange()

                transactionPhase = .mutatingDocument
                let result = document.commitPreparedMutation(prepared)

                // `commitPreparedMutation`'s doc comment: "must agree with the preparation's
                // contentWillChange/selectionWillChange flags." A client that changed content/selection
                // it had preflighted as NOT changing is a programmer contract violation, not a silent
                // acceptance.
                if result.contentChanged, !prepared.contentWillChange {
                    RichTextInputContractViolation.report(
                        "commitPreparedMutation for \(mutation) reported contentChanged=true, but its " +
                        "own preparation's contentWillChange was false")
                }
                if result.selectionChanged, !prepared.selectionWillChange {
                    RichTextInputContractViolation.report(
                        "commitPreparedMutation for \(mutation) reported selectionChanged=true, but its " +
                        "own preparation's selectionWillChange was false")
                }

                documentRevision = result.revision
                canonicalSelectionStorage = result.selection
                markedRangeStorage = result.markedRange

                transactionPhase = .notifyingDidChange
                notifySelectionDidChange()
                notifyTextDidChange()

                transactionPhase = .publishingState
                publishState(reason: .content)
            }
        }
    }

    // MARK: - The four `UITextInputDelegate` emitters
    //
    // MOVED to `+Notifications.swift` by TASK 26, which formalized them under the same names for the
    // whole package (as the note they carried here predicted). `runMutation` above still calls all
    // four; only their declaration site changed.
}
#endif
