#if canImport(UIKit)
import UIKit

@available(iOS 13.0, *)
extension LegacyRichTextInputBackend {
    /// Atomic: on throw, no delegate, recognizer, observer, timer, display link or presentation
    /// object may remain attached.
    ///
    /// The parameter type is the contract's `any RichTextInputHost` (the protocol declares it that
    /// way, and stage 2's backend must satisfy the same signature). This backend narrows it once,
    /// here, and reports `.incompatibleHost` otherwise — that check is the only host-shape
    /// assumption the legacy backend makes, and it is exactly the failure the spec's failure
    /// class 2 requires a backend to "report a precise construction/attachment error" for.
    func attach(to host: any RichTextInputHost) throws {
        guard !isAttached else { throw RichTextInputBackendAttachmentError.alreadyAttached }
        guard let legacyHost = host as? any LegacyRichTextInputHost else {
            throw RichTextInputBackendAttachmentError.incompatibleHost(
                "LegacyRichTextInputBackend requires a LegacyRichTextInputHost, got \(type(of: host))")
        }
        self.host = legacyHost
        // TASK 24 FIX ROUND 1 (Critical, reviewer Focal Point 1) — `tokenizer` (`+TextReads.swift`)
        // built EAGERLY here, while `legacyHost` is known non-nil by construction, so that read path
        // never needs to reach through the weak `host` at all. Cleared in `performDetachSteps()`
        // (Major 1) and here in the throw path, so a failed/torn-down attach never leaves a tokenizer
        // referencing a canvas this backend no longer considers attached.
        //
        // TASK 43 — the construction itself moved HERE, from the canvas's `legacyMakeTokenizer()` D24
        // hook (now deleted). Nothing about the lifetime changed; what changed is that the type whose
        // lifetime this method governs is now named in this method. `DocumentTokenizer` holds its
        // canvas `unowned`, so "who mints it" and "who clears it" being the same body is the property
        // Task 24's Major 1 was about. Naming a canvas type here is legitimate: R1's ban on
        // implementation types covers the SHARED contract files, and this file is `Legacy*`.
        tokenizerStorage = DocumentTokenizer(canvas: legacyHost.legacyCanvas)
        do {
            try installInitialState(from: legacyHost)   // revision + canonical selection
            installInteractions()
            isAttached = true
            legacyHost.lifecycleClient.backendDidAttach()
        } catch {
            removeInteractions()
            self.host = nil
            tokenizerStorage = nil
            isAttached = false
            throw error
        }
    }

    /// Terminal and idempotent. The nine steps are spec-fixed and identical for every backend.
    ///
    /// DEVIATION D18: this ordering also tears down things `resignFirstResponder` (DocumentCanvasView)
    /// leaves alive today — the loupe session, the per-drag `UITextSelectionDisplayInteraction` and
    /// the coalescing flag. That is safe ONLY because detach runs at `deinit`, where nothing can
    /// observe the difference. `removeInteractions()` and `cancelActiveInteraction(_:)` must NEVER be
    /// wired into `resignFirstResponder`: fixing those leaks is a behavior change.
    func detach() {
        guard isAttached else { return }
        // The spec's transaction-phase rule: "Detach requested during mutation runs at the
        // TRANSACTION BOUNDARY." A client or facade callback fired from inside a mutation (the
        // lifecycle client's `backendDidPublishState` is the realistic one) can call `detach`.
        // Tearing presentation down mid-transaction would leave the outer notify/publish steps
        // running against a half-dismantled backend. Latch instead, and let `endTransaction()`
        // drain it.
        guard transactionPhase == .idle else {
            detachRequested = true
            return
        }
        performDetachSteps()
    }

    /// The nine steps, run exactly once. Called from `detach()` when idle, and from
    /// `endTransaction()` when a detach was latched during a transaction.
    private func performDetachSteps() {
        isAttached = false                                       // 1. reject new operations
        detachRequested = false
        transactionPhase = .detaching
        // FIX ROUND 1 (review Major 1): D18 declares this teardown kills "the coalescing flag" —
        // flip it off here, BEFORE the rest of teardown, so a latch left over from an in-flight
        // suppressed run does not survive into a fresh `attach()`. `isAttached` is already `false`
        // (step 1, above), so `suppressesSelectionNotifications`'s own `didSet` guard drops any
        // pending flush silently instead of publishing to a host mid-detach.
        suppressesSelectionNotifications = false
        // TASK 22e ADDITION, **MOVED BY TASK 42 to after step 2 — see the block below the
        // `cancelActiveInteraction(reason:)` line.** The floating-cursor hygiene reset used to sit
        // HERE, borrowing `suppressesSelectionNotifications`'s spot; it cannot any more, and the
        // reason is the whole of Task 42.
        //
        // FIX ROUND 1 (review Minor 2 correction): `deferredExternalChange` is NOT guaranteed empty
        // here under the new "at most one drain per outer `endTransaction()` call" rule (see that
        // method's own doc comment) — the ONE drained change's own publish can stash a fresh one.
        // Harmless if left (nothing reads it again once `isAttached` is false), but cleared anyway,
        // for the same hygiene reason as the two flags immediately above.
        deferredExternalChange = nil
        // FIX ROUND 2 (review Major — new finding): `activeTransactionDepth` gets the SAME hygiene
        // reset, for the SAME reason the review named explicitly: a leaked bump (a bracket that
        // returns early after incrementing, without going through `withTransaction`/`endTransaction`)
        // would otherwise survive detach into a fresh `attach()`, wedging every future transaction
        // (`endTransaction()` would see a permanently-nonzero depth and never again do its real work).
        // This reset does not paper over a leak — `withTransaction` (below) is what prevents one from
        // happening in the first place — it only stops an already-leaked value from crossing a
        // detach/reattach boundary.
        activeTransactionDepth = 0
        // TASK 24 FIX ROUND 1 (Major 1, reviewer) — `tokenizerStorage` is cache state exactly like the
        // four resets above, and Family 1 (Task 24) is what moved this cache OFF the canvas (where one
        // canvas had one tokenizer by construction) and ONTO this backend, which can be reattached to a
        // DIFFERENT canvas. Left uncleared, a post-reattach `tokenizer` read would vend a
        // `DocumentTokenizer` still holding `unowned` the PREVIOUS (now-dead) canvas — a trap on first
        // use, not merely a stale cache. `attach(to:)` rebuilds it eagerly, so this reset only ever
        // widens the documented "no canvas attached" window `tokenizer`'s own fallback already handles.
        //
        // TASK 24 RE-REVIEW (Minor, reviewer) — OWNER: TASK 32. This reset sits BEFORE step 2/step 4, the
        // same placement the adjacent `floatingCursorActive` note flags and tells Tasks 32/42 not to copy.
        // While those steps are no-op stubs it is inert; once Task 32 gives them real bodies, a `tokenizer`
        // read arriving from UIKit teardown between this line and step 4 would take the reporting fallback
        // and so assert in a DEBUG app build. No live defect today — recorded here so Task 32 orders it
        // against its own teardown rather than rediscovering it.
        //
        // **TASK 32 DISCHARGED THIS by tracing the window rather than by moving the line, and the trace
        // is written down so the next owner can re-run it instead of re-deriving it.** Steps 2-4 now
        // execute real canvas code; the question is whether any of it can synchronously re-enter the
        // `tokenizer` witness. Enumerated:
        //   * step 2 -> `stopDragAutoScroll()`: invalidates a `CADisplayLink` and zeroes four scalars.
        //   * step 2 -> `cancelFloatingCursor()`: `stopFloatingAutoScroll()` (a second link) plus
        //     `transientCaretView.hide(animated: false)`, which sets `alpha`/`isHidden` and nothing else.
        //   * step 3 -> `finalizeMarkedTextForDetach()`: unchanged by Task 32.
        //   * step 4 -> `legacyRemoveSelectionInteractions()`: three `removeGestureRecognizer(_:)` calls
        //     plus three nils. The one re-entrancy this could plausibly cause is UIKit cancelling an
        //     in-flight touch, and all three canvas handlers' cancellation paths
        //     (`+Interaction.swift`) end in selection/auto-scroll bookkeeping — none reads `tokenizer`.
        // So the window is still empty and the placement is behaviour-neutral. **This is a trace, not a
        // proof about UIKit**: the reset is a one-line move (to after step 4) for whoever finds a real
        // reader, and moving it is not free — it would change the detached `tokenizer` answer from the
        // reporting fallback to the live tokenizer on any path that DOES land in the window, which is a
        // behaviour change and therefore out of scope for an extraction commit.
        tokenizerStorage = nil
        // FIX ROUND 2 (re-review NF3): the step NAME below is the spec's, and it is NOT a description of
        // what this step's body does — read literally it reads as the claim the Major-1 adjudication
        // found false. What step 2 actually does is `stopDragAutoScroll()` + `cancelFloatingCursor()`:
        // the two display links and the floating-cursor state. **Gestures come off at step 4**, and the
        // loupe session is never written by any of the nine (see `cancelActiveInteraction(reason:)`'s
        // own doc comment, `+Interaction.swift`, for the item-by-item measurement and the one indirect
        // path). Kept as the spec's name so the nine steps still map onto the spec one-for-one.
        cancelActiveInteraction(reason: .backendDetach)          // 2. spec step name: "gestures/loupe/floating/autoscroll"
        // **TASK 42 MOVED THIS RESET HERE, from step 1's hygiene block, and it is the one behaviour
        // change in an otherwise mechanical state move.** Task 22e's hygiene reset (a floating-cursor
        // session left active must not survive detach/reattach) sat above `suppressesSelectionNotifications`
        // in step 1; Task 24's fix round flagged that placement, and Task 32 answered its half by
        // measuring that the hazard was NOT yet live — step 2 forwards to
        // `DocumentCanvasView.cancelFloatingCursor()`, whose guard is `guard floatingCursorActive`, and
        // that read a DIFFERENT store from this one. Task 32's note ended: *"The note above becomes
        // correct at TASK 42, which unifies them; at that point the reset must move to after step 2, or
        // the transient shadow caret survives detach exactly as described."*
        //
        // **It does, and it was MEASURED rather than taken on trust** (this branch has had three
        // prescribed fixes falsified by building them). With the stores unified and this line still at
        // step 1, `FloatingCursorStateAuthorityTests.test_detachHidesTheTransientCaret` is RED:
        // `XCTAssertTrue failed - detach must hide the transient shadow caret` plus
        // `XCTAssertEqualWithAccuracy failed: ("1.0") is not equal to ("0.0")` on the alpha. The
        // mechanism is exactly as predicted — the early reset makes the cancel's guard return before
        // `transientCaretView.hide(animated: false)`, leaving a stuck BRIGHT caret on a detached canvas.
        // Nothing else looks wrong: `stopFloatingAutoScroll()` sits ABOVE that guard, so the display
        // link is still torn down, and the flag itself still reads `false`.
        //
        // The reset is not redundant with step 2's own clear even here: `cancelActiveInteraction`'s
        // clear is a property of THAT member, and a detached backend whose `legacyCanvas` is already
        // nil reaches neither canvas body. Keeping both is the same defence-in-depth the three Task-33
        // mirror clears carry, and for the same reason.
        floatingCursorActive = false
        // FIX ROUND 1 (review Minor 4) — the OTHER two moved fields get the same hygiene reset, for the
        // reason the sibling `tokenizerStorage = nil` four lines up carries verbatim: this backend "can
        // be reattached to a DIFFERENT canvas", and a stale non-zero velocity carried across that
        // boundary would be an auto-scroll step with no link to consume it — the exact state
        // `setFloatingScrollVelocity(_:)`'s contract sentence says cannot exist. **Unreachable today**
        // and recorded as such: `detach()`'s only production caller is `DocumentCanvasView.deinit`, and
        // a scheduled `CADisplayLink` retains the canvas, so `deinit` cannot run while a link is alive —
        // which means the velocity is already zero by the time detach runs. This makes the contract
        // sentence true by construction instead of by that argument.
        floatingCursorPoint = .zero
        floatingScrollVelocity = 0
        finalizeMarkedTextForDetach()                            // 3. commit or discard marked text
        removeInteractions()                                     // 4. observers and interactions
                                                                  // 5. private delegates — none (legacy)
                                                                  // 6. associated references — none (legacy)
        host?.presentationClient.tearDownPresentation()          // 7.
        host?.lifecycleClient.backendWillDetach()                // 8. host still valid, nothing active
        host = nil                                                // 9. release the weak host
        transactionPhase = .idle
    }

    /// Returns the backend to `.idle` and drains a latched detach. EVERY mutating member's exit
    /// path (including its error paths) goes through this; a member that returns without it leaves
    /// the phase machine wedged and a latched detach never runs.
    ///
    /// TASK 22g ADDITION: also drains a `deferredExternalChange` — BEFORE checking `detachRequested`,
    /// not after (FIX ROUND 1, review Minor 3: reasoned, and now PINNED by
    /// `BackendReentrancyTests.test_deferredExternalChangeDrainsBeforeALatchedDetach_soItIsAppliedNotDropped`
    /// — a change deferred in the SAME transaction as a requested detach is still applied, and
    /// published, to a backend that has already been asked to tear down, rather than silently dropped
    /// by the detach that raced it; judged the friendlier choice, since the alternative is to drop a
    /// change the caller was told would eventually apply).
    ///
    /// FIX ROUND 1 (review Major 2 — **22g's own defect**, not a later task's): this method used to be
    /// UNCONDITIONAL — it set `.idle`, drained, and fired a latched detach on EVERY call, regardless
    /// of nesting. `setSelection`, `clearCompositionState`, and `setMarkedText` each still have their
    /// OWN single-bracket `transactionPhase = .publishingState … endTransaction()` shape with no
    /// member-level reentrancy guard (see each member's own one-line pointer back to this note; the
    /// SCOPE paragraph on `prepareAndRun`, `+Mutation.swift`, also points here rather than restating
    /// this). A client/facade callback fired from an OUTER transaction's own `publishState` (the
    /// realistic sites: `presentationClient.apply`, `lifecycleClient.backendDidPublishState`) can call
    /// one of those three REENTRANTLY, and — because none of them is rejected — its OWN
    /// `endTransaction()` call used to end the OUTER transaction too. Three concrete, reviewer-traced
    /// consequences of that: (1) a latched detach draining MID-bracket, so `tearDownPresentation`/
    /// `backendWillDetach` land inside the outer `publishState` and the outer's own publish is
    /// delivered AFTER `backendWillDetach` — exactly what
    /// `BackendReentrancyTests.test_detachDuringMutation_runsAtTheTransactionBoundary` forbids, reached
    /// WITHOUT even calling `detach()` directly; (2) `transactionPhase` reading `.idle` again for the
    /// REST of the outer bracket, defeating `prepareAndRun`'s own mutating-reentry guard for anything
    /// that runs after the nested call returns; (3) a stale, out-of-order publish even with NO detach
    /// involved, since `publishState` captures its snapshot before the nested callout runs, so a
    /// nested `setSelection(S2)` publishes S2 fully and the outer's OWN (pre-nested, now-stale) publish
    /// still lands after it.
    ///
    /// Fixed with `activeTransactionDepth` (`LegacyRichTextInputBackend.swift`): incremented at the
    /// START of every top-level bracket this class owns, decremented here. Only the call that takes
    /// the counter from 1 back to 0 — the OUTERMOST bracket — does the real work below; a nested call
    /// (depth still > 0 after its own decrement) returns immediately, leaving `transactionPhase`,
    /// `deferredExternalChange`, and `detachRequested` exactly as the outer transaction left them, for
    /// the outer transaction's OWN `endTransaction()` call to resolve. This closes consequences 1 and 2
    /// above (pinned by `test_nestedSetSelectionAfterALatchedDetach_doesNotEndTheOuterTransactionEarly`
    /// and `test_nestedSetSelection_doesNotDefeatTheMutatingReentryGuardForTheOuterBracket`). It does
    /// NOT close consequence 3 (the stale out-of-order publish) — `publishState`'s captured snapshot is
    /// unrelated to `endTransaction`'s nesting depth, and fixing THAT needs a per-member change (skip
    /// the bracket / re-read state fresh) this fix round deliberately does not make; see
    /// `test_nestedSetSelection_publishesTheFreshStateNotAStaleSnapshot` for the companion fix this
    /// round DOES make to `publishState` itself (freshening only the LIFECYCLE client's delivered
    /// state, not the presentation client's, and not by rejecting or skipping any bracket).
    ///
    /// FIX ROUND 2 (review Minor, on the `publishState` fresh-read companion fix): recorded here,
    /// the one normative site, rather than on `publishState` itself, because it is about that fix's
    /// EXPIRY, which is this note's job to track. It said "**Task 26 should REMOVE the freshening**",
    /// on the reasoning that once a nested `setSelection`/`clearCompositionState`/`setMarkedText` is
    /// rejected (or skips its own bracket) instead of running, ONLY the outer bracket ever publishes
    /// and re-reading `state` a second time inside that one publish is a no-op.
    ///
    /// **TASK 26 RESOLUTION — the member-level guard LANDED, and the freshening STAYS.** The two
    /// halves of that reasoning come apart under the shape the review itself recommended. "Only the
    /// outer bracket ever publishes" is now TRUE (see the three `guard transactionPhase == .idle`
    /// lines in `LegacyRichTextInputBackend.swift`). "Re-reading `state` is therefore a no-op" is
    /// FALSE: the recommended shape "performs the storage write and skips the bracket", so a nested
    /// call still MUTATES `canonicalSelectionStorage`/`markedRangeStorage` — and it does so between
    /// `publishState`'s `let snapshot = state` and its lifecycle delivery, which is exactly the window
    /// the freshening exists to cover. Verified empirically, not reasoned only: with the member-level
    /// guards in place, reverting the lifecycle delivery to the captured `snapshot` still turns
    /// `BackendReentrancyTests.test_nestedSetSelection_publishesTheFreshStateNotAStaleSnapshot` red.
    /// The freshening therefore becomes obsolete only under one of TWO other shapes, neither of which
    /// Task 26 was asked to build:
    ///   * **HARD rejection** — reject the nested call and DROP its write. Behavior-changing: it
    ///     silently discards a legitimate adjustment a client makes from a publish callback, and it
    ///     contradicts `test_nestedSetSelection_publishesTheFreshStateNotAStaleSnapshot`, which pins
    ///     that the nested value WINS.
    ///   * **DEFER-AND-REPLAY** — queue the nested selection and apply it once `transactionPhase`
    ///     returns to `.idle`, exactly as `synchronizeAfterExternalChange` already queues via
    ///     `deferredExternalChange` (the machinery exists; `endTransaction()`'s drain below is the
    ///     model, including its "at most one per outer call" bound). Then storage is NOT mutated inside
    ///     `publishState`'s window, the freshening becomes a genuine no-op and can go, and the nested
    ///     value still wins — through its own follow-up publish instead of by mutating the outer one.
    ///     Not free either: it changes WHEN and IN HOW MANY publishes the nested value is delivered, so
    ///     it too requires rewriting that pinned test. Recorded because it is the shape Task 26 did not
    ///     consider and the one most likely to be right.
    /// Either way, whoever revisits this must change that test in the same commit, deliberately.
    ///
    /// **OWNER: TASK 35** (canonical-selection storage unification), with Tasks 36a-39 as the fallback
    /// if 35's scope does not reach it. Reason: the whole cost of leaving the freshening in place is
    /// LATENT, because no client callback can re-enter a selection write today — Task 26 walked every
    /// path out of `publishState` (`presentationClient.apply` → `canvas.refreshSelectionUI()`;
    /// `lifecycleClient.backendDidPublishState(.selection)` → `canvas.onSelectionChange?()` → the
    /// facade's `scrollCaretIntoView()` + coalesced `onChange`) and none of them writes a selection.
    /// **TASK 35 CORRECTION — this paragraph used to predict "Task 35 makes `setSelection` the single
    /// selection authority … which is the point the re-entry stops being hypothetical", and that is the
    /// OPPOSITE of what Task 35 did.** It made the backend the single selection STORE, and deliberately
    /// routed the canvas `anchor`/`head` forwarders around `setSelection` (to the raw
    /// `setCanonicalAnchor`/`setCanonicalHead`), so no new re-entry became reachable. Corrected here
    /// rather than left to be re-derived, because the enumeration block immediately below concludes
    /// exactly that, and a reader going top-down would otherwise take the wrong premise into it.
    /// **Tasks 32-34/36-39 remain the tasks where the re-entry stops being hypothetical** — 36a-39
    /// because they convert those sites TO `setSelection`.
    /// **TASK 36a NARROWED THAT: 36a-36c do NOT.** They funnel `+Editing.swift`'s 34 sites into one
    /// application point that uses the raw, non-publishing pair (measurement at `applyCaretOutcome`,
    /// `DocumentCanvasView+Editing.swift`), so no new path into `setSelection` — and therefore no new
    /// re-entry — became reachable at 36a either. The enumeration below is still ZERO at this commit.
    ///
    /// **The evidence that settles it there**, so the next owner does not re-derive it: enumerate, AT
    /// THAT COMMIT, every client-callback path reachable from `publishState` that can SYNCHRONOUSLY
    /// write a selection. If the answer is still zero, remove the freshening and delete the pinned
    /// test's reentrancy premise. If it is non-zero, choose explicitly between
    /// nested-value-wins-via-outer-publish (keep the freshening, and promote it from "temporary
    /// mitigation" to documented contract, costs (a) and (b) included) and defer-and-replay (remove it,
    /// rewrite the pinned test in the same commit). **Until that happens this mitigation is live,
    /// undocumented-as-permanent semantics — that is the risk this note exists to keep visible, and it
    /// does not go away by having been explained at length.**
    ///
    /// **TASK 35 RAN THE ENUMERATION AND THE ANSWER IS STILL ZERO — recorded here so the next owner
    /// does not repeat it, and so the reason it is zero is not mistaken for a property of the code.**
    /// Every client-callback path out of `publishState`, walked at this commit:
    ///   * `presentationClient.visibleBounds` → `canvas.viewportRect()` — geometry read;
    ///   * `host.hostInputView.isFirstResponder` — a plain UIKit query;
    ///   * `presentationClient.apply(_:)` → `canvas.refreshSelectionUI()` → `updateCaretView()`,
    ///     `updateSelectionHandleViews()`, `syncSpoilers()`, `inputBackend.checkOnSelectionChange()` →
    ///     `canvas.nativeCheckOnSelectionChange()` (which READS `head`/`selFrom`/`selTo` and writes
    ///     only `spellResults`/`lastCheckedCaret`);
    ///   * `lifecycleClient.backendDidPublishState` → `.selection`/`.interaction` →
    ///     `canvas.onSelectionChange?()` → the facade's `scrollCaretIntoView()` (a scroll) +
    ///     `scheduleSelectionDrivenOnChange()` (ASYNC, so not a synchronous re-entry);
    ///     `.content`/`.markedText`/`.externalSynchronization` → `canvas.notifyContentSizeChanged()` →
    ///     the facade's `onChange` relay, i.e. out to the host.
    /// None writes a selection synchronously. Cross-checked against the canvas's own selection-write
    /// inventory: the seven writing functions are `setSelectionForTesting`, `setBlocks`, `setCaret`,
    /// `setSelectionHead`, `setSelectionAnchor`, `selectAcrossBlocks`, `selectAcrossLeafRegions`, and
    /// none of them is on any path above.
    ///
    /// **So the decision is DEFERRED to the fallback owner this note already names (Tasks 36a-39), and
    /// deliberately, not for lack of scope.** The reason: Task 35 is zero only BECAUSE it routed the
    /// canvas `anchor`/`head` forwarders to the raw, non-publishing `setCanonicalAnchor`/
    /// `setCanonicalHead` rather than through `setSelection` (see their doc comment). Nothing that
    /// could re-enter became reachable here, so removing the freshening now would be a change made at
    /// the one commit that has no evidence for it, and it would require rewriting a pinned reentrancy
    /// test inside a task whose whole contract is "no behaviour change". **Tasks 36a-39 are the commits
    /// where a host callback CAN reach `setSelection` — re-run the enumeration above there, not the
    /// reasoning.**
    ///
    /// **TASK 36a RE-RAN IT AND THE ANSWER IS STILL ZERO — for the same structural reason as Task 35,
    /// not by coincidence.** 36a routes its caret-outcome application to the raw pair rather than to
    /// `setSelection` (measured; see `applyCaretOutcome` in `DocumentCanvasView+Editing.swift`), so it
    /// added no new path into `publishState` at all. The enumeration's own list is unchanged: no
    /// client-callback path out of `publishState` writes a selection synchronously. **The owner is now
    /// TASK 40b** — the commit that deletes the raw pair and therefore has no choice but to send the
    /// funnel through `setSelection`. **TASK 37 RE-RAN IT AND THE ANSWER IS STILL ZERO, for the same
    /// structural reason a third time**: it too routed all 31 of its sites to the raw pair through
    /// `applyCaretOutcome`, adding no new path into `publishState`. **TASKS 38 AND 39 RE-RAN IT AND THE
    /// ANSWER IS STILL ZERO, for the same structural reason a fourth and fifth time** — neither
    /// converted a single site to `setSelection` (Task 39 built that shape for all 40 of its warnings
    /// and measured it red; see `applyCaretOutcome`), so no new path into `publishState` exists and the
    /// enumeration's list above is unchanged. **The owner is Task 40b**, unambiguously now: it is the
    /// only remaining commit that must send a canvas selection write through `setSelection`, and it is
    /// the one that has to re-run the enumeration rather than this reasoning.
    ///
    /// The two costs of the mitigation stand as recorded, unchanged by Task 26: (a) a client that
    /// treats `presentationClient.apply(_:)` and `lifecycleClient.backendDidPublishState(_:reason:)`
    /// as ONE atomic publish can observe them disagree during a nested callout (presentation sees the
    /// PRE-nested snapshot, lifecycle the POST-nested one); (b) the outer delivery's `reason` can
    /// mis-attribute its payload — an outer `.externalSynchronization` publish can end up carrying a
    /// selection a nested LOCAL `setSelection` wrote, labelled as if the external change itself
    /// produced it.
    ///
    /// **The REMAINING gap this note tracked is CLOSED (Task 26).** Member-level reentrancy for
    /// `setSelection`/`clearCompositionState`/`setMarkedText` is implemented as the reviewer's own
    /// Focal-Point-1 recommendation words it — "a per-member entry guard that performs the storage
    /// write and skips the bracket … letting the outer bracket's publish carry the state" — silent
    /// rather than violation-reporting, because a reentrant selection/marked write HAS an obvious
    /// "apply it later" semantics (the outer publish, still undelivered) that a reentrant MUTATION
    /// does not. Pinned by
    /// `BackendReentrancyTests.test_nestedSetSelection_writesItsStorageButOpensNoBracketOfItsOwn`.
    /// **TASK 29 DISCHARGED its half of that**: it did rewrite `setMarkedText`'s body wholesale, and it
    /// carried the guard forward — into `ReferenceMutationBackend` (`T/Support/`), with the body. The
    /// member on THIS class is now a plain `legacyCanvas` forward that opens no bracket, so it has no
    /// guard to carry and cannot be a reentrancy surface. `clearCompositionState` is the one member of
    /// the original three still on this class with its own bracket; Task 41 owns it. D31 is
    /// not implicated: it bans an `editing`-*depth* flag on the legacy CANVAS suppressing a revision
    /// bump; `activeTransactionDepth` is an internal backend bracket-nesting counter that suppresses
    /// no revision bump and stamps no revision anywhere.
    func endTransaction() {
        // FIX ROUND 2 (review MAJOR — new finding): the entry/exit pair was unenforced in BOTH
        // directions, each silently. Over-decrement: the old `max(0, activeTransactionDepth - 1)`
        // CLAMPED a missing entry bump to 0 — the guard below then passed, and this method behaved
        // EXACTLY like the pre-Major-2 unconditional body, silently reinstating the defect the
        // counter exists to prevent, with no signal anything was wrong. That is now a reported
        // contract violation instead: a caller reaching `endTransaction()` with the counter ALREADY
        // at 0 has, by construction (see `withTransaction(_:)` below), called it without a matching
        // bump — a programmer error, not a race, so it is reported and the call is a no-op (NOT
        // clamped-and-proceed), rather than let it silently masquerade as a legitimate outermost exit.
        guard activeTransactionDepth > 0 else {
            RichTextInputContractViolation.report(
                "endTransaction() called with activeTransactionDepth already 0 — an entry bump is " +
                "missing; ignoring this call rather than clamping it, which would silently reinstate " +
                "the nested-transaction defect this counter exists to prevent")
            return
        }
        activeTransactionDepth -= 1
        guard activeTransactionDepth == 0 else { return }
        transactionPhase = .idle
        if let deferred = deferredExternalChange {
            deferredExternalChange = nil
            // FIX ROUND 1 (review Minor 2): drain AT MOST ONE deferred change per OUTER
            // `endTransaction()` call — not a recursive/looping drain. `synchronizeAfterExternalChange`'s
            // own publish can stash ANOTHER deferred change (a client that reacts to every publish by
            // requesting a new external sync); a recursive shape ("its own `endTransaction()` drains
            // again") would let such a client recurse this method without bound.
            //
            // FIX ROUND 2: deliberately does NOT go through `withTransaction(_:)` below, even though
            // that is now every OTHER bracket's entry point — `withTransaction` unconditionally calls
            // the FULL `endTransaction()` on exit, and a full `endTransaction()` call would re-run
            // THIS drain block again for anything freshly stashed during `synchronizeAfterExternalChange`'s
            // own publish, chaining without bound (exactly the recursion this fix round's bound
            // exists to prevent — verified by tracing it: `withTransaction { synchronizeAfterExternalChange(deferred) }`
            // would call a BRAND NEW `endTransaction()` invocation after the nested bracket's own
            // `withTransaction` unwinds, and that new invocation's own drain block would see whatever
            // the nested publish just re-stashed and try to drain IT too). The manual bump/unbump pair
            // immediately below is the ONE deliberate exception to "always go through the chokepoint",
            // and it stays manual for exactly that reason: it must NOT trigger a second full
            // `endTransaction()` pass. Bumping the depth counter across the call makes the drained
            // call's OWN trailing `endTransaction()` (reached via ITS internal `withTransaction`) a
            // no-op (depth stays > 0 through it), so any freshly-stashed change is simply left in
            // `deferredExternalChange` for the NEXT, independent top-level transaction to drain — never
            // chained here. The explicit `transactionPhase = .idle` afterward restores what that
            // suppressed inner reset would otherwise have done.
            //
            // FIX ROUND 3 (review item 1): SAVE/RESTORE, not `+= 1` / `-= 1`. With round 2's clamp
            // removed from `endTransaction()`'s main guard, this raw `-= 1` became the ONE remaining
            // site that can drive the counter negative if anything beneath it ever assigns the
            // counter ABSOLUTELY rather than by delta (today only `performDetachSteps()`'s `= 0`
            // does that, and it is not reachable inside this exact window — so this is hardening, not
            // a live bug). Capturing the depth before the call and restoring the CAPTURED value
            // afterward is correct regardless of what happens in between, and does not depend on
            // arithmetic symmetry the way a bare `+= 1` / `-= 1` pair does.
            let depthBeforeDrain = activeTransactionDepth
            activeTransactionDepth += 1
            synchronizeAfterExternalChange(deferred)
            activeTransactionDepth = depthBeforeDrain
            transactionPhase = .idle
        }
        if detachRequested { performDetachSteps() }
    }

    /// FIX ROUND 2 (review MAJOR): the chokepoint that makes the `activeTransactionDepth`
    /// entry/exit pair impossible to half-implement — the shape the review named as the one this
    /// codebase has been burned by repeatedly ("a pair a caller can half-implement"), and the one the
    /// plan's own Task 27/28 text (`:6339`, `:6389`, "exit through `endTransaction()`") does not even
    /// mention the entry half of. A caller cannot bump `activeTransactionDepth` without this method
    /// also calling `endTransaction()` afterward — both happen in the SAME stack frame, so a `return`
    /// inside `body` only exits the closure, never skips the trailing `endTransaction()` call. Every
    /// top-level bracket this class owns (`setSelection`, `clearCompositionState`, `setMarkedText`,
    /// `synchronizeAfterExternalChange`'s real branch, the `suppressesSelectionNotifications` didSet
    /// flush, and `runMutation`'s `.ready` branch in `+Mutation.swift`) now calls this instead of
    /// manually bumping the counter and calling `endTransaction()` itself. `internal`, not `private`,
    /// for the same file-scope reason as `prepareAndRun` (`+Mutation.swift`): its callers live in
    /// OTHER `LegacyRichTextInputBackend+*.swift` family files.
    ///
    /// The ONE deliberate exception is `endTransaction()`'s OWN deferred-change drain, immediately
    /// above — see its comment for why going through this chokepoint there would reintroduce the
    /// unbounded-recursion risk Minor 2 (fix round 1) closed.
    func withTransaction(_ body: () -> Void) {
        activeTransactionDepth += 1
        body()
        endTransaction()
    }
}
#endif
