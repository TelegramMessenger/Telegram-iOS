#if canImport(UIKit)
import UIKit

/// TASK 32 — Family 9 (touch interaction and selection). **FIVE routed backend members, not the nine
/// things the task brief's `Moved:` line names.** The four it also lists —
/// `gestureRecognizerShouldBegin(_:)`, `gestureRecognizer(_:shouldReceive:)`,
/// `selectionContainerViewBelowText(for:)` and the `UIEditMenuInteractionDelegate` conformance — do NOT
/// route and add no symbol; **deviation D36** records that ruling and its reasoning, summarised here
/// because this is the file a reader arrives at looking for them:
///
///   * `RichTextInputInteractionBackend` declares no member for any of the four, so there is nothing to
///     "forward one line into" — the brief's own Interfaces block says both "forward one line into the
///     backend" and "they add no new symbol", and those two clauses contradict each other.
///   * For two of the four, adding one is not available at all.
///     `selectionContainerViewBelowText(for:)` takes a `UITextSelectionDisplayInteraction` (**iOS 17+**)
///     and the edit-menu delegate methods take a `UIEditMenuInteraction` (**iOS 16+**), so either
///     requirement would have to be `@available`-gated above the package's iOS 13 floor, which hard
///     invariant 12 forbids outright. That is the identical reasoning that produced **D3**, where the
///     iOS-18 `isEditable` became the un-gated `isEditableForWritingTools` rather than a gated
///     requirement.
///   * The other two (`gestureRecognizerShouldBegin`, `gestureRecognizer(_:shouldReceive:)`) take only
///     iOS-13-safe types, so invariant 12 does not block them — but they are pure UIKit gesture
///     arbitration on a deliberately backend-neutral contract, and no spec text authorises widening it.
///     The plan's two-stage structure exists so that a needed contract change is treated as evidence the
///     contract is wrong, not as a task-level convenience.
///
/// # The five members, and the routing shape of each
///
///   1. `installInteractions()` -> `legacyCanvas?.installSelectionInteractions()`
///   2. `removeInteractions()` -> `legacyCanvas?.legacyRemoveSelectionInteractions()` (a NEW canvas hook)
///   3. `viewportDidChange()` -> `legacyCanvas?.legacyViewportDidChange()` (a renamed witness body)
///   4. `layoutDidChange(generation:)` -> stores it; forwards nowhere
///   5. `cancelActiveInteraction(reason:)` -> `legacyCanvas?.stopDragAutoScroll()` then
///      `legacyCanvas?.cancelFloatingCursor()`
///
/// **TASK 32 ADDS NO NEW D24 CLAUSE-(b) EXCEPTION**, and it adds no clause-(b) read at all: **four**
/// of the five members above reach the canvas, through **five** calls to **five** distinct callees
/// (member 5 makes two; member 4 reaches nothing), and every one of those calls INVOKES a hook — none
/// reads canvas state. **Three of the five callees** are unprefixed —
/// `installSelectionInteractions()`, `stopDragAutoScroll()`, `cancelFloatingCursor()` —
/// and that is clause (a) under the Task-29 amendment and the Task-30/34 precedent: the `legacy…` prefix
/// is a PROVENANCE marker for a renamed witness body, and a canvas member that is ALREADY narrowly named
/// needs no rename and gets none. The two new hooks (`legacyRemoveSelectionInteractions()`,
/// `legacyViewportDidChange()`) carry the prefix because one is new backend-owned entry-point code and
/// the other IS a renamed witness body.
///
/// # `installInteractions()` cannot be `.canvasForward`, and that is not a defect
///
/// R17's `.canvasForward` shape requires the one statement to contain the literal `legacyCanvas?.legacy`.
/// `installSelectionInteractions()` is clause (a) WITHOUT the prefix, so the correct classification is
/// `.statements(allowed: ["legacyCanvas?.installSelectionInteractions()"])` — an exact-text pin, which is
/// strictly tighter than `.canvasForward` would have been, not a relaxation. Renaming the canvas method to
/// satisfy the shape would invert the D24 rule (rename to please a test, rather than classify honestly).
///
/// # Routing `installInteractions()` MOVES WHEN THE RECOGNIZERS APPEAR — the zero-behaviour-change
/// argument, stated in full at the site
///
/// `attach(to:)` runs SYNCHRONOUSLY inside `DocumentCanvasView.init` (`try self.inputBackend.attach(to: self)`),
/// and `attach` calls `installInteractions()`. The production caller
/// (`RichTextEditorView`, `scrollView.addSubview(canvas)` then `canvas.installSelectionInteractions()`)
/// calls it AFTER the canvas is constructed and added to the scroll view. So from this task on, a real
/// canvas has its three recognizers and its `UIEditMenuInteraction` from `init` rather than from that
/// later line. **Three independent grounds say that is not observable in production, and all three are
/// needed** (the Task-22i precedent: a zero-behaviour-change claim on a genuinely NEW call path carries
/// its whole justification here, not in a report):
///
///   1. **The later call becomes a no-op, so the END STATE of the init sequence is byte-identical.**
///      `installSelectionInteractions()` is idempotent by construction: its recognizer block is guarded
///      by `if gestureRecognizers?.isEmpty ?? true`, and `installEditMenuInteraction()` — which sits
///      OUTSIDE that guard — carries its own `guard editMenuInteraction == nil else { return }`. A second
///      call installs nothing twice. (Checked specifically: a double-installed `UIEditMenuInteraction`
///      would have been a real bug, not a cosmetic one.)
///   2. **There is exactly ONE production `DocumentCanvasView()` construction**, and it is that same
///      facade line — so no other production canvas gains recognizers it did not have.
///   3. **Nothing between `init` and that line consults the recognizers.** The two statements that
///      precede it are `scrollView.canvas = canvas` and then `scrollView.addSubview(canvas)`. The
///      first feeds `GripYieldingScrollView.gestureRecognizerShouldBegin`, which is evaluated at
///      GESTURE time, not at install time; the second consults nothing.
///
/// **It IS observable in the test tree, deliberately stated rather than glossed.** **NINE call sites
/// across SIX files** build a canvas and then call `installSelectionInteractions()` explicitly; those
/// calls become no-ops, which is harmless. The nine:
/// `SelectionInteractionTests` ×3, `ResponderLifecycleCharacterizationTests` ×2,
/// `SelectionDragCoalescingTests`, `CanvasHitTestTests`, `RichTextInputBackendHarness`,
/// `InteractionRouterTests`.
///
/// > Measured 2026-08-20 with
/// > `grep -rn "installSelectionInteractions()" Tests/ | grep -v '"'` (comment and string hits dropped).
/// > **Re-run it rather than trusting this line** — see the box below for why it is spelled this way.
///
/// ┌─ **FIX ROUND 2 (re-review NF2). THE PARENTHETICAL IS THE FINDING, NOT THE NUMBER.** ───────────────
/// │
/// │  This sentence shipped as *"SEVEN call sites across SIX files (counted, not estimated: …)"* with
/// │  an enumeration naming **five** files totalling **seven** sites. It is nine across six, and one of
/// │  the two omitted sites (`InteractionRouterTests`) is one **this task itself added** — so the file
/// │  count was right only by counting a file the evidence list did not name.
/// │
/// │  **The durable observation is about the parenthetical: a claim that advertises its own rigor is
/// │  read LESS carefully, not more.** "Counted, not estimated" is a credibility marker, and its
/// │  measured effect on every subsequent reader — two review passes and the coordinator — was to move
/// │  the claim into the already-verified pile and out of the set anyone re-checks. That is the exact
/// │  opposite of what it was written to do. A reader cannot audit an assertion of diligence; they can
/// │  only audit a procedure.
/// │
/// │  So the marker is **kept and made reproducible**: the date and the exact command replace the claim
/// │  of care. Prefer that shape for every number-bearing sentence in this file — if a count is worth
/// │  asserting, the command that produced it is worth two lines.
/// └─────────────────────────────────────────────────────────────────────────────────────────────────── Two consequences are real and are handled where they land:
/// `BackendAttachmentTests.test_attachIsAtomic_aThrowingAttachLeavesNothingInstalled` compared a
/// failed-attach canvas against an ordinarily-constructed one, and those two counts are no longer both
/// zero (re-based there, with its intent intact); and `presentEditMenu()`'s `guard let interaction =
/// editMenuInteraction` now passes for any FIRST-RESPONDER test canvas that never called the installer,
/// where it used to return early. Production is unaffected by the second for ground 3's reason — the
/// facade installs before the canvas can become first responder.
///
/// # `cancelActiveInteraction(reason:)`: two divergences, both disclosed
///
/// **(a) `reason` is discarded.** The member takes a `RichTextInteractionCancellationReason` and ignores
/// it. Only one case reaches it in stage 1 (`.backendDetach`, from `performDetachSteps()` step 2), and the
/// canvas teardown it forwards to takes no argument, so there is nothing faithful to do with the value.
/// A stage-2 backend, which owns the gesture machinery itself, would branch on it: `.responderLoss` and
/// `.windowDetach` want the display-link teardown WITHOUT committing a marked composition,
/// `.documentReplacement` and `.policyChange` want the in-flight selection drag abandoned rather than
/// settled, and `.backendDetach` wants everything. Recorded so the parameter does not read as an
/// oversight.
///
/// **(b) `+Attachment.swift`'s D18 note overstates what detach tears down — on TWO of its three items,
/// not three.** That comment says detach "also tears down things `resignFirstResponder` leaves alive
/// today — the loupe session, the per-drag `UITextSelectionDisplayInteraction` and the coalescing flag".
/// Measured against the tree:
///
///   * **the loupe session** — **no step of the nine writes `loupeSession`** (checked across all nine,
///     including step 7's callee `legacyTearDownPresentation()`, not just step 2); every writer of its
///     backing store is inside `handleLongPress`. Overstated. *(FIX ROUND 2, NF3: this item first
///     shipped scoped to `stopDragAutoScroll()`/`cancelFloatingCursor()` — i.e. step 2 — one paragraph
///     under a box warning against exactly that narrowing, which makes it the FOURTH instance of this
///     task's central pattern. The box explains the reasoning; this clause is the record that it
///     recurred inside its own correction.)*
///   * **the per-drag `UITextSelectionDisplayInteraction`** — same: created and removed inside
///     `handleLongPress`; **no detach step writes it DIRECTLY.** Overstated.
///
///     *One INDIRECT path exists, and a narrower true claim beats an absolute one with a known
///     exception — the same trade D24's own exception list makes (FIX ROUND 2, NF4).* Step 4 removes an
///     in-flight `loupeLongPress` recognizer; if UIKit delivers `.cancelled` on removal, that branch of
///     `handleLongPress` is what invalidates `loupeSession` and removes the display interaction — so for
///     a canvas with a live loupe drag, detach WOULD tear both down, via the recognizer rather than via
///     a store write. `+Attachment.swift`'s own step-4 reasoning already contemplates this re-entrancy
///     ("the one re-entrancy this could plausibly cause is UIKit cancelling an in-flight touch").
///     **Unreachable in production** — `detach()` runs only at `deinit`, where no drag can be in flight
///     — and not unit-testable (nothing here can make UIKit deliver a real `.cancelled`). Deliberately
///     NOT chased with a test and NOT a behaviour change; recorded because the sentence's subject is
///     "any detach step" while its evidence is "who writes the store", and those are not the same claim.
///   * **the coalescing flag** — **the note is CORRECT here.** There is no canvas-side coalescing store
///     to leave alive: `DocumentCanvasView.coalescingSelectionNotifications` was a Task-26 COMPUTED
///     FORWARDER onto `inputBackend.suppressesSelectionNotifications`, and `performDetachSteps()` resets
///     exactly that store (`suppressesSelectionNotifications = false`, its first hygiene reset).
///     **TASK 43 DELETED THE FORWARDER**, which strengthens the bullet without changing it: the canvas's
///     four use sites now name the backend flag directly, so "there is no canvas-side coalescing store"
///     is true by shape rather than by inspection of a getter.
///
/// The two overstated items are leaks `ResponderLifecycleCharacterizationTests` pins as present-day
/// behaviour under D18; closing them here would be the behaviour change D18 forbids.
///
/// ┌─ **FIX ROUND 1 (review Major 1). THE ROOT CAUSE IS REUSABLE AND IS THE POINT OF THIS BOX.** ──────
/// │
/// │  The third bullet above shipped as its own opposite: this note originally asserted that the
/// │  canvas's "own `coalescingSelectionNotifications` flag" is NOT touched. **The defect was a
/// │  NARROWED SUBJECT, not a missed fact.** The banner's subject is "**this ordering**" — all nine
/// │  detach steps. The correction silently re-scoped it to **step 2** ("It tears down LESS than …
/// │  claims *step 2* does") and then evaluated the banner's three items against that narrower subject.
/// │  Under step 2 alone the coalescing item is false; under the banner's actual subject it is true.
/// │  **A correction that silently narrows what it is correcting will keep producing this.**
/// │
/// │  **This is the THIRD instance of one pattern in this phase: a sentence describing what the code
/// │  does, shipped FALSE in the same commit as the sentence it was written to fix.** Task 31's fix
/// │  round 2 was spent entirely on the first two — `+Responder.swift` and `+Commands.swift`, both
/// │  claiming nothing mechanical checked something R17 had just begun checking. The standing rule
/// │  from that round applies verbatim, and it is quoted rather than paraphrased because the
/// │  paraphrase is what keeps failing:
/// │
/// │      **"Every sentence in this codebase claiming what a rule does or does not check is now a
/// │      TESTABLE claim: apply the substitution it describes and read the result."**
/// │
/// │  The extension this instance forces: **a CORRECTION is such a claim too, and gets the same
/// │  test as the sentence it corrects** — including the test "does my correction still have the same
/// │  subject as the sentence I am correcting?". Here that test was one `grep` for
/// │  `coalescingSelectionNotifications`, which landed on a computed forwarder two lines under its own
/// │  doc comment saying so. **After TASK 43 that grep lands on a deletion note in the same place** —
/// │  the check still works, and the name to grep for now is `suppressesSelectionNotifications`.
/// │
/// │  *What it would have broken:* Task 42 (unifies the two `floatingCursorActive` stores) and Task 43
/// │  (deletes this very forwarder) both arrive at this file. A reader told a canvas-side coalescing
/// │  flag exists and survives detach would either hunt for a store that is not there, or add a
/// │  redundant reset to a nine-step teardown whose ordering already carries three adjudicated notes.
/// └───────────────────────────────────────────────────────────────────────────────────────────────────
///
/// **Statement ORDER: `stopDragAutoScroll()` THEN `cancelFloatingCursor()`, which is NOT the order the
/// task brief's Step 3 specifies.** The two touch disjoint state (`dragAutoScrollLink` + velocities vs
/// `floatingScrollLink` + `floatingCursorActive` + `transientCaretView`), so both orders are equivalent,
/// and detach runs only at `deinit` in production, so neither is observable. The tie is broken by
/// matching the tree: `legacyWillMove(toWindow:)` (Task 31) and `legacyTearDownPresentation()` both run
/// `stopDragAutoScroll()` first. One order in the tree beats two orders plus a note explaining why they
/// differ.
///
/// # The four-axis divergence audit for the family
///
/// Written per member below where it differs; the family-wide answers:
/// 1. *Clamp vs reject* — no clamping surface anywhere in this family.
/// 2. *nil / wrong-type input* — no member takes an optional or a UIKit identity. `generation` is a
///    plain `UInt64` forwarded verbatim.
/// 3. *Which store is read* — the one real divergence, and it is `lastObservedLayoutGeneration`'s: the
///    canvas owns `layoutGeneration` and advances it from MANY sites, while the backend's copy is fed
///    from exactly ONE of them. **The count, the per-site enumeration and the command for re-measuring
///    them live at that property's own declaration (`LegacyRichTextInputBackend.swift`) and nowhere
///    else** — deliberately; see the box under `layoutDidChange(generation:)` for why this sentence
///    carries the shape of the divergence and not its arithmetic.
/// 4. *Which object owns the consulted flag* — `installSelectionInteractions()`'s
///    `gestureRecognizers?.isEmpty` guard is still the CANVAS's, unchanged; what moved is the MOMENT it
///    is consulted (init rather than post-construction), which the three-ground argument above covers.
///
/// **The fifth axis (Task 31, now standing policy): does this family promote a witness-local to backend
/// state, losing re-entrancy-safety-by-construction?** Checked rather than assumed: **no.**
/// `lastObservedLayoutGeneration` is a brand-new field with one writer and no reader, not a promoted
/// local — there is no `hostWill…`/`hostDid…` validity window for a re-entrant frame to clobber, and no
/// decision anywhere depends on its value.
@available(iOS 13.0, *)
extension LegacyRichTextInputBackend {

    /// Called for real by `attach(to:)` (`+Attachment.swift`), as the last step before `isAttached`
    /// flips — and by the catch path's sibling `removeInteractions()` if `installInitialState(from:)`
    /// threw first.
    ///
    /// A plain optional-chained forward with NO `isAttached` prelude, which is the shape the family
    /// standard requires here rather than a preference: `attach(to:)` calls this BEFORE it sets
    /// `isAttached = true`, so an `isAttached` guard would make it a permanent no-op and the editor
    /// would install no gesture recognizers at all. Stated because the guard reads as free hygiene
    /// everywhere else in this class.
    ///
    /// **Axis-2 note (detached):** `legacyCanvas` is nil only when `host` is, which inside `attach` it
    /// never is. Reached with a nil host only through the catch path's `removeInteractions()`, not here.
    func installInteractions() {
        legacyCanvas?.installSelectionInteractions()
    }

    /// Called for real by `performDetachSteps()` (`+Attachment.swift`, step 4) and by `attach(to:)`'s
    /// catch path. **DEVIATION D18: it must NEVER be wired into `resignFirstResponder()`** — the canvas
    /// keeps its documented teardown gaps there, and closing them is a behaviour change, not an
    /// extraction.
    ///
    /// **Axis-2 note (detached), and it is the sharp one for this member:** `performDetachSteps()` runs
    /// this at step 4, while `host` is still non-nil (step 9 releases it), so the forward lands. The
    /// catch path in `attach(to:)` runs it while `self.host` IS set (it is cleared on the next line), so
    /// that lands too. A THIRD call with a nil host would silently do nothing — which is correct: there
    /// is no canvas to remove anything from.
    func removeInteractions() {
        legacyCanvas?.legacyRemoveSelectionInteractions()
    }

    /// Routed from `DocumentCanvasView.viewportDidChange()`, whose body is now
    /// `legacyViewportDidChange()`. The host still calls the canvas member
    /// (`RichTextEditorView.scrollViewDidScroll`), so the entry point the facade knows is unchanged.
    ///
    /// **Axis-2 note (detached):** a scroll arriving at a detached backend re-realizes nothing, where
    /// the pre-seam witness would have re-realized block views from canvas state alone. Unreachable
    /// today for the single reason every member of this phase relies on — `detach()` has exactly one
    /// caller, `DocumentCanvasView.deinit` — and SILENT, on `hostWillMove(toWindow:)`'s precedent: this
    /// is a scroll-driven callback UIKit can deliver at arbitrary times, and a DEBUG `assertionFailure`
    /// on a documented teardown window would be a trap.
    func viewportDidChange() {
        legacyCanvas?.legacyViewportDidChange()
    }

    /// Notification-only: it stores the announced generation and does nothing else. It must NEVER
    /// trigger a relayout — the canvas has ALREADY laid out by the time it calls this (the notification
    /// is the last statement of `layoutContent()`), so a relayout here would be an unbounded
    /// notify -> layout -> notify loop, not merely redundant work.
    ///
    /// **No `isAttached` / `legacyCanvas` guard, deliberately.** There is no canvas to reach and nothing
    /// to drop: a detached backend storing a number nobody reads is indistinguishable from one that
    /// refuses to. Adding a guard would be the only thing in this member that could be wrong.
    ///
    /// See `lastObservedLayoutGeneration` (`LegacyRichTextInputBackend.swift`) for the divergence this
    /// member creates and does not fix: the field lags the canvas's real counter, because **this member
    /// is that counter's ONLY notifier** — every other site that advances it does so silently. The
    /// count of those sites, and their enumeration, live at that property's declaration.
    ///
    /// ┌─ **FIX ROUNDS 2 AND 3 (re-review NF1, then its own sequel). THE PARAGRAPH ABOVE USED TO CARRY
    /// │  A COUNT; IT NO LONGER DOES, AND THAT DELETION IS THE LESSON.** ──────────────────────────────
    /// │
    /// │  This sentence said "two of that counter's THREE bump sites", and the axis-3 sentence in this
    /// │  file's header said "three places". Both survived the fix round that corrected the same fact
    /// │  at `lastObservedLayoutGeneration`'s declaration — **the round's own instruction, "re-run that
    /// │  grep", was applied to one copy of the paragraph and not to the other two, in the very file
    /// │  the round had open.** So a reader following this member's pointer met two different numbers
    /// │  for one fact, with the wrong one attached to the member the correction was about.
    /// │
    /// │  **This instance differed in kind from the passes before it.** Those were successive passes
    /// │  each correcting the last (3 → 3 → 5 → 8); this was **the correcting commit failing to
    /// │  propagate its own correction**. The general form, which is not about this number:
    /// │
    /// │      **A corrected fact is only durable if EVERY copy of it is corrected in the same commit.**
    /// │
    /// │  **That is the same rule Task 29 arrived at from the other direction, and the two are recorded
    /// │  together deliberately rather than as separate lessons.** Its version — at
    /// │  `markedRangeStorage`'s declaration in `LegacyRichTextInputBackend.swift`, under "TASK 29
    /// │  CORRECTION — the durability claim above did NOT hold" — is *"a duplicated record is only
    /// │  durable if every task that touches either copy touches both"*, learned when a mutator
    /// │  inventory at a "durable spot" went stale in the same commit that rewrote the section it
    /// │  described. Task 29 found it across two records that disagreed; this task found it across
    /// │  three copies of one number. **Same rule. Two independent discoveries of it should not sit in
    /// │  two places pretending to be different lessons** — read that note with this one.
    /// │
    /// │  **FIX ROUND 3 — the STRONGER form, and where this thread ends.** Round 2 fixed the two
    /// │  survivors and, in the same breath, added a NEW wrong restatement: an ordinal clause on the
    /// │  paragraph above ("— this member is the thirteenth"), wrong twice over: `layoutDidChange`
    /// │  calls neither bump function, so it is not one of the advance sites at all; and read instead
    /// │  as an index into the enumeration, it named the wrong position.
    /// │  **A sixth iteration of one number, inside the fix for the fifth.** The ruling was to DELETE
    /// │  it rather than correct it:
    /// │
    /// │      **When a fact has been restated more times than it can be maintained, the durable fix is
    /// │      FEWER COPIES, not another correct number.**
    /// │
    /// │  A seventh correct ordinal would have been the same bet the previous six lost. So round 3 did
    /// │  not stop at that clause — it audited every restatement in this file and kept none of them:
    /// │  **this file now asserts the count in NO place at all.** The two sites that genuinely need the
    /// │  fact (axis 3 in the header, and the paragraph directly above) state the SHAPE — many advance
    /// │  sites, exactly one notifier — which is load-bearing at those sites and cannot drift, and both
    /// │  point at the single authority. The numbers, the per-site enumeration and the re-measuring
    /// │  command live only at `lastObservedLayoutGeneration`'s declaration
    /// │  (`LegacyRichTextInputBackend.swift`). **If you find yourself adding a number back into this
    /// │  file, you are re-opening this thread: add a pointer instead.** The cheapest copy to keep in
    /// │  sync is the one that does not exist.
    /// └──────────────────────────────────────────────────────────────────────────────────────────────
    func layoutDidChange(generation: UInt64) {
        lastObservedLayoutGeneration = generation
    }

    /// Called for real by `performDetachSteps()` (`+Attachment.swift`, step 2). Same D18 prohibition as
    /// `removeInteractions()`: never wire it into `resignFirstResponder()`.
    ///
    /// The header records the two divergences in full — `reason` is discarded, and this tears down less
    /// than `+Attachment.swift`'s D18 note claims — plus why the first two statements are in this order
    /// rather than the task brief's.
    ///
    /// **TASK 33 ADDED THE THIRD STATEMENT.** `cancelFloatingCursor()` clears the CANVAS's
    /// `floatingCursorActive`; since Task 33 the BACKEND's separate flag is what the `selectedTextRange`
    /// setter consults, so every backend member that reaches that canvas method mirrors the clear
    /// (`+FloatingCursor.swift`'s header enumerates all four cancel paths).
    ///
    /// **In production this clear is REDUNDANT, and it is here anyway on purpose — and the redundancy
    /// changed hands at TASK 42, which is the interesting part.** When this was written the only caller
    /// was `performDetachSteps()` step 2 and step 1's hygiene block had already set
    /// `floatingCursorActive = false`; this note said relying on that would make the invariant a
    /// property of the CALLER'S ORDERING and "would silently break if the hygiene reset ever moved after
    /// step 2, which `+Attachment.swift`'s note says Task 42 must do". **Task 42 moved it, and this
    /// clear is what made that move safe to reason about.** The redundancy now comes from the OTHER
    /// side: with one store, the `legacyCanvas?.cancelFloatingCursor()` on the line above clears the
    /// same flag. That forward is optional, so a backend whose host has been released still reaches
    /// only this line — which is the whole argument for keeping it, unchanged in substance.
    ///
    /// **FIX ROUND 1 (review Major 1) — the pin named here was masked and is replaced.**
    /// `FloatingCursorRouterTests.test_cancelActiveInteractionClearsTheBackendsFlag` calls this member
    /// directly rather than through detach, which is why it is not vacuous about the MEMBER — but
    /// since the store collapse the canvas's own clear satisfies it whether or not this line exists
    /// (measured: deleting all three mirror clears left the whole suite green). The pins that
    /// actually reach this line are
    /// `FloatingCursorStateAuthorityTests.test_theMirrorClearsAreTheOnlyClearOnACanvaslessBackend`,
    /// which drives this member with `host` released so the forward is a no-op, and the source-level
    /// `InputBackendSourceBoundaryTests.test_theFloatingCursorMirrorClearsArePresent_R21`.
    func cancelActiveInteraction(reason: RichTextInteractionCancellationReason) {
        legacyCanvas?.stopDragAutoScroll()
        legacyCanvas?.cancelFloatingCursor()
        floatingCursorActive = false
    }
}
#endif
