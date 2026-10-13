#if canImport(UIKit)
import UIKit
import RichTextEditorCore

@available(iOS 13.0, *)
extension DocumentCanvasView {
    /// Wraps a mutation: snapshots the document + selection, brackets the input-delegate change,
    /// runs `body`, applies the caret claim `body` returns, registers a self-re-registering undo, and
    /// refreshes layout/display. This is the single entry point for every editing operation (typing,
    /// structural, list). The claim is applied by `applyCaretOutcome` after `body()` and before the
    /// bracket's DID notifications; a body that claims nothing returns `.unchanged`, which is NOT
    /// "claims the current selection" (see `RichTextInputCaretOutcome`).
    ///
    /// **TASK 36c — THERE IS ONE `editing` AGAIN.** Task 36a added this closure type as a SECOND
    /// overload named `editingApplyingOutcome`, beside a `Void` form, so that 36b could convert 26
    /// mutation primitives one cluster at a time with the package compiling (and the suite green)
    /// after each. 36c flipped every call site onto it, deleted the `Void` form and the eight
    /// transitional `-> Void` primitive wrappers, and dropped the transitional name. **The overload
    /// no longer exists, so the trap it existed to work around no longer has a place to happen**
    /// — but the trap itself is recorded below, because R22 still guards the half that can.
    ///
    /// **TASK 36b CONVERTED THE PRIMITIVES.** All 30 of this file's convertible `anchor = …; head = …`
    /// sites are gone — the fifteen primitives that own their own bracket call this form and
    /// `return .caret(at:)`, and the eleven that do not return a `RichTextInputCaretOutcome` their
    /// caller applies. The four that remained were `legacyApplyMutation`'s seat-before-dispatch
    /// writes, which `RichTextInputCaretOutcome`'s own doc comment settles as NOT outcomes; the two
    /// in `registerUndo` were never in scope. (The 30/4 split and its arithmetic live there, not
    /// here — Rule 15.)
    ///
    /// **TASK 40a FINISHED THE FILE — as a SPELLING change, not a conversion.** Those last six lines
    /// now read `inputBackend.setCanonicalAnchor(_:)` / `setCanonicalHead(_:)` (and
    /// `target.inputBackend.…` in `registerUndo`) instead of the `anchor`/`head` forwarder setters
    /// Task 40b deletes. That is the *same* non-publishing write — the forwarder setters' bodies are
    /// literally those two calls — so the four seat writes still SEAT the selection at exactly the
    /// moment they always did, which is what `RichTextInputCaretOutcome`'s doc requires. They did not
    /// become caret outcomes, and must not: converting them would be a live bug. Task 40a had to do
    /// this because its Step-4 gate flips both setters to `@available(*, unavailable)`, and Swift has
    /// no per-call-site suppression for that (measured — see the task report).
    ///
    /// **THE COMPILER-INVISIBLE TRAP THIS SHAPE WAS BUILT AROUND, measured rather than suspected.**
    /// While a `Void` overload existed, calling a converted primitive from it silently DISCARDED the
    /// claim: `editing { primitive() }` type-checked, because Swift lets a closure whose body
    /// produces a value satisfy `() -> Void`. That spelling is now a hard error — there is no `Void`
    /// form to bind to — so the trap is closed at THIS level. It is not closed one level down: once a
    /// primitive returns `RichTextInputCaretOutcome`, a caller that ignores the returned value in a
    /// MULTI-statement body still compiles, and the compiler's
    /// `warning: result of call to 'primitive()' is unused` is the ONLY signal — and
    /// **`@discardableResult` on the converted primitive erases it completely** (verified with a
    /// standalone `swiftc` probe: with the attribute the same call compiles clean). So a converted
    /// primitive must NOT be marked `@discardableResult`.
    ///
    /// **This paragraph is not the guard — `R22` is.** A doc comment two hundred
    /// lines from where the attribute gets typed is not a mechanism, and the review's deciding
    /// argument was that even the un-silenced fallback warning is **1 of 1084** and moves no gate any
    /// task in this phase checks. `InputBackendSourceBoundaryTests
    /// .test_noOutcomeReturningDeclarationIsDiscardable_R22` now fails the build's Core suite if
    /// `@discardableResult` appears on any declaration returning `RichTextInputCaretOutcome` under
    /// `Sources/RichTextEditorUIKit`. That rule's own doc comment states precisely what it does NOT
    /// catch (a discarded outcome at a CALL site still only warns); this paragraph stays because it is
    /// the WHY, and R22 is the WHAT.
    func editing(coalescing: UndoCoalescing = .none,
                 _ body: () -> RichTextInputCaretOutcome) {
        performEditing(coalescing: coalescing, body)
    }

    /// Applies a primitive's caret claim through the backend. **`nil` (`.unchanged`) is NOT "claims
    /// the current selection"** — it means the primitive made no claim at all, and the store is left
    /// exactly as `body()` left it. That distinction is why `RichTextInputCaretOutcome` wraps an
    /// Optional instead of being one.
    ///
    /// # THE SHAPE, AND THE MEASUREMENT THAT CHOSE IT
    ///
    /// **A claim is applied through the RAW, NON-PUBLISHING endpoint writers** —
    /// `setCanonicalAnchor`/`setCanonicalHead`, the same two `RichTextInputBackend` members that back
    /// the deprecated `DocumentCanvasView.anchor`/`.head` forwarders — **and NOT through
    /// `setSelection(_:reason: .command)`**, which is what this task's brief specified.
    ///
    /// **The rejected shape was built and measured, not reasoned about.** THE CONSTRUCTION, as it was
    /// run at Task 36a: put `inputBackend.setSelection(claimed, reason: .command)` on this line, and
    /// temporarily make the (then-existing) `Void` overload return
    /// `RichTextInputCaretOutcome(selection: inputBackend.canonicalSelection)` instead of
    /// `.unchanged`, so every `editing` call site drives the application path at once — the stress a
    /// dormant branch otherwise cannot get. Then run the full `Scripts/iostest.sh`. **TO REPRODUCE IT
    /// TODAY the second half is unnecessary and must not be re-added**: Task 36c deleted the `Void`
    /// overload, and every call site now reaches this method through the one closure type, so the
    /// first edit alone applies the stress the two edits used to apply together.
    ///
    /// **Measured at commit `2bf2727367` (fix round 1; the first pass recorded these against a tree
    /// that predated this task's own nine new tests, so both rows moved):**
    ///
    ///   * **Rejected shape: 10 red across 7 suites, PLUS 2 hard crashes.**
    ///     `AutocorrectOriginCharacterizationTests` (×3), `InsertionRouterTests` (×2),
    ///     `DeletionRouterTests`, `FacadeCallbackTraceCharacterizationTests`,
    ///     `MarkedTextTraceCharacterizationTests`, `RichTextInputEventRecorderTests`,
    ///     `CaretOutcomeTests.test_aClaimReportsExactlyOnce_theSameAsARawWrite`.
    ///   * **Shipped shape (THE CONTROL, same command, same stress): 2243 executed, 5 skipped,
    ///     0 failures, 0 `Fatal error` lines, 0 restarts.** A measurement that only fires on the
    ///     shape under suspicion proves nothing.
    ///
    /// **THERE ARE TWO FAILURE CLASSES, NOT ONE — the first pass claimed "every one is the same
    /// defect" and that is false.**
    ///
    /// **Class 1, the seven trace diffs: a DOUBLING.** `setSelection` publishes (`publishState`), and
    /// a publish delivers exactly two host effects: `presentationClient.apply` →
    /// `canvas.refreshSelectionUI()`, and `lifecycleClient.backendDidPublishState(.selection)` →
    /// `canvas.onSelectionChange?()`. **This method's own caller already delivers both** —
    /// `performEditing`'s tail runs `refreshSelectionUI(); notifyContentSizeChanged();
    /// onSelectionChange?()` under the same `!suppressHostChangeNotification` guard the lifecycle
    /// client uses. So a publishing claim does not merely publish "once per transaction instead of
    /// once per claim" (the shape the task supplement anticipated): it fires a SECOND host selection
    /// report per transaction, INSIDE the delegate bracket. Each affected trace gains **exactly one**
    /// `canvasSelectionChanged` between `selectionWillChange` and `selectionDidChange`, with the
    /// tail's own `canvasContentSizeChanged, canvasSelectionChanged` still present.
    /// `FacadeCallbackTraceCharacterizationTests` is the same root cause showing up as an ORDERING
    /// break rather than a count: its assertion is
    /// `firstIndex(of: .textDidChange) < firstIndex(of: .canvasSelectionChanged)`, and the extra
    /// report lands first, so it reads `("4") is not less than ("2")` — those are ORDINALS. (The first
    /// pass recorded that as "the facade's `onChange` count goes 2 → 4"; that test contains no
    /// `onChange` count, and the two numbers were read out of the assertion message backwards.)
    /// `LegacyRichTextInputBackend.setCanonicalAnchor`'s own note already recorded this as measured
    /// reason 2 for the forwarders ("a publishing forwarder reports twice per call"); it applies here
    /// unchanged, and only the arithmetic differs (one claim per transaction, not one per endpoint).
    ///
    /// **Class 2, and it is the one that changes what Task 40b has to do: the runner DIES.**
    /// `TelegramDocumentInputClientMutationTests
    /// .test_insertTextMutation_dispatchesToTheLegacyBody_notBackThroughTheRoutedWitness` and
    /// `…test_deleteBackwardMutation_…` both `detach()` the backend and then drive a mutation that
    /// reaches `editing`. `setSelection`'s `guard isAttached` fires
    /// `RichTextInputContractViolation.report`, which is `assertionFailure` in DEBUG: **4
    /// `Fatal error: … operation on a detached backend: setSelection(_:reason:)` lines and 2 xctest
    /// restarts**, after which xcodebuild reports those two tests as neither pass nor fail. The two
    /// endpoint writers below carry NO attachment guard, which is exactly why the shipped shape does
    /// not have this class at all. **Whoever flips this line must bring an attachment story** — guard
    /// the call, or rewrite those two probes — because no amount of characterization re-recording
    /// addresses a trapped process. (This class is also why the first pass's "9 red / 6 suites" does
    /// not reproduce: it was a POST-RESTART partial count, the trap `Scripts/iostest.sh`'s own header
    /// comment documents — "summary will include totals from previous launches".)
    ///
    /// **Both rows are stated HERE and only here** (Rule 15). Several other notes in the package
    /// mention this decision — the D33 pair's protocol contract and implementation header, the
    /// `setSelection` policy-gate comment, the `suppressesSelectionNotifications` owner note,
    /// `endTransaction`'s re-entry enumeration, the canvas forwarder note, and three suites — and
    /// every one of them POINTS here rather than carrying a number that would then have to be
    /// maintained in as many places. (The first draft of this change restated the numbers in six of
    /// them, including one sentence that claimed they were "not restated here or anywhere else"
    /// while restating them. Deliberately no count on "several": a count of pointers is one more
    /// number to rot, which is the whole failure mode being avoided.)
    ///
    /// # WHAT THIS COSTS, STATED PLAINLY
    ///
    /// 1. **The claim does NOT enter `setSelection`'s `editPolicy.isSelectable` gate.** A restrictive
    ///    policy would drop a deliberate whole-selection write and does not drop this one. Unobservable
    ///    today — production runs `.legacyUnrestricted` — and it is the SAME gap the raw pair already
    ///    has at the 34 sites this replaces, so no site loses a gate it had.
    /// 2. **`RichTextInputBackend`'s D33 pair gains a second caller**, contradicting its "written by
    ///    `DocumentCanvasView.anchor`'s legacy setter, and by nothing else" clause. That clause is
    ///    corrected in the same commit rather than left to be re-derived. The arithmetic is in this
    ///    change's favour: 36b/36c remove 34 forwarder writes and add this ONE, so Task 40b — which
    ///    deletes the pair — inherits one call site here instead of 34 spread through this file.
    ///    **TASK 36b RESULT: the 30 are gone.** What is left in this file for Task 40b is this
    ///    method's two endpoint calls, `registerUndo`'s two (never in scope), and
    ///    `legacyApplyMutation`'s four seat-before-dispatch pairs. **TASK 36c RESULT: the eight
    ///    transitional wrappers are gone, and with them their eight `applyCaretOutcome` calls — but
    ///    this method is now `internal` and called from FOURTEEN sites that cannot defer their claim
    ///    (its own note above). Task 40b therefore inherits this method plus those fourteen calls,
    ///    still one MECHANISM, and none of them writes `anchor`/`head` directly.**
    /// 3. **The publication decision is DEFERRED, not dodged. It is ONE line to change and MORE than
    ///    one line of work** — the first pass called it "now ONE LINE", and Task 36a's review showed
    ///    that is wrong in three separate ways, all of which belong to whoever flips it (Task 40b is
    ///    the natural owner: it is the commit that removes the raw pair):
    ///    * **the attachment story** — class 2 above; two probes trap the runner;
    ///    * **the tail cannot simply be deleted.** Removing `performEditing`'s tail
    ///      `onSelectionChange?()` to stop the doubling makes the per-transaction host report
    ///      CONDITIONAL on a claim existing, so an `editing { …; return .unchanged }`
    ///      transaction would report ZERO where every editing transaction reports exactly one today.
    ///      **Task 36c made such transactions the MAJORITY** — every formatting, attribute-only and
    ///      still-writes-`anchor`/`head`-itself body returns `.unchanged` — so this is no longer a
    ///      prediction. The existing trace suites catch it, which is a hazard rather than a comfort
    ///      for whoever flips the line, because they would be inclined to RE-RECORD them;
    ///    * **it does not generalise to the bracket's other users.** `notifyingContentAndSelectionChange`
    ///      has exactly three bodies: this one, `registerUndo`'s self-re-registering undo/redo closure,
    ///      and `reload`. Only this one has `onSelectionChange?()` in its tail, so the doubling argument
    ///      is specific to it — and `registerUndo`'s two raw `target.anchor`/`target.head` writes are
    ///      NOT among the 34, so they remain raw-pair writers after 36c regardless.
    ///    Doing any of this HERE would have put the whole phase's behavioural risk into the commit
    ///    whose entire job is to be invisible — verbatim the third measured reason `setCanonicalAnchor`
    ///    gives for the forwarders, and the call Task 35 already made one task ago.
    ///
    /// # WHY TWO ENDPOINT CALLS ARE SAFE HERE
    ///
    /// `setCanonicalAnchor`'s doc names "it publishes a selection that never existed" as measured
    /// reason 1 against routing the forwarders through `setSelection` — the hazard of writing
    /// endpoints one at a time. That hazard is a property of PUBLISHING writes only. Neither call
    /// below publishes, so no intermediate `(new anchor, OLD head)` pair is ever observable: the two
    /// writes are separated by nothing but a store update, inside a bracket whose DID notifications
    /// have not fired yet.
    ///
    /// **What the decomposition DOES lose: affinity.** It takes the two `utf16Offset`s and the
    /// endpoint writers re-wrap them as `.downstream`, so an outcome built through the internal
    /// memberwise init with an `.upstream` position is silently downgraded. Inert today — deviation
    /// D6: this backend emits only `.downstream` and no geometry consults affinity — and identical to
    /// what the raw pair it replaces already did. Recorded because the safety argument above is about
    /// publication only, and because `caret(at:)`/`range(_:_:)` are not the only way to construct the
    /// type. A conformer that ever makes affinity mean something must revisit this line, not just
    /// `setSelection`.
    ///
    /// **TASK 36c — INTERNAL, not `private`, and called from 46 sites besides `performEditing`** (14
    /// at Task 36c; TASK 37 added 9, TASK 38 6, TASK 39 17). All of them apply a claim IMMEDIATELY, on the next instruction,
    /// exactly as the deleted `-> Void` wrappers did, because they cannot let it ride to the end of an
    /// enclosing `editing { }` — for 14 of them because their transaction re-reads the caret, for the
    /// 9 Task 37 added because **there is no enclosing `editing { }` at all**. Widening to `internal`
    /// keeps ONE application mechanism for all of them rather than open-coding the two endpoint writes
    /// at each — which would also multiply what Task 40b inherits here from one mechanism back to two
    /// dozen raw endpoint pairs, undoing cost item 2 above.
    ///
    /// **THIS SET IS NOT THE 14 IN `applyReplaceOutcome`'s READ-BACK TABLE**, and since Task 37 the
    /// two are not even the same size — which removes the confusion the previous wording had to warn
    /// about but not the need to say which is which. Each set is enumerated only where it is stated
    /// (Rule 15). The read-back table lists sites whose transaction re-reads the caret;
    /// `insertDocumentBlocksOutcome` and `replaceRange` are on it but bind the outcome to a `let`
    /// instead of applying it, so they are not here. Conversely `legacySetMarkedText`'s provisional
    /// edit and `dismissPrediction` are here but not there: they run outside any `editing { }` (inside
    /// `notifyingContentChange { }`, a TEXT-ONLY bracket), so there is no body-return for them to use
    /// even though nothing reads their caret back — `legacySetMarkedText`'s is delivered live to the
    /// host by `textDidChange`, and `dismissPrediction`'s is dead in every reachable state (a live
    /// prediction already parks the caret at `m.from`) and reproduced anyway. **Task 37's 9 are on
    /// NEITHER list** for a third reason: they claim a caret they compute themselves, with no
    /// `applyReplaceOutcome` in sight (their sites: `+UITextInput`'s `selectedTextRange` hook, its
    /// container snap and its four object-replacement-range collapses; `legacySetMarkedText`'s
    /// in-composition placement; `legacyBeginFloatingCursor`'s collapse and `moveFloatingCaret`).
    ///
    /// # TASK 37 — THE MEASUREMENT THAT PUT THOSE 9 HERE RATHER THAN ON `setSelection`
    ///
    /// Task 37's brief specified `setSelection(_:reason:)` for all 31 of its warnings. Seven of its
    /// 16 lines sit inside `editing { }` and became `return .caret(at:)` (the 36b/36c shape). The
    /// other 9 could not: six are bare normalization/snap writes the SAME function reads back, and
    /// **three sit inside `notifyingSelectionChangeIgnoringCoalescing { }` — a bracket the Task-36c
    /// hazard note does not name, because it enumerated `editing { }` bodies only.** That bracket
    /// (`+Notifications.swift`) opens NO transaction and sets NO suppression flag, so BOTH of
    /// `setSelection`'s escapes (`!suppressesSelectionNotifications`, `transactionPhase == .idle`)
    /// fall through and it takes the full publish path.
    ///
    /// **Measured by the same construction as above — `cbd7a74cb6` plus all 31 sites converted to a
    /// publishing `setSelection`, full `Scripts/iostest.sh`: 4 red across 4 suites, 0 `Fatal error`
    /// lines, 0 restarts.** The control is the shipped shape on the same command: 2630 test cases, 0
    /// failures. Same total both runs, so the 4 are the whole delta.
    ///   * `MarkedTextTraceCharacterizationTests.test_compositionBeginUpdateCommit_traceAndRevisions`
    ///     — **7 events instead of 6**, the extra `canvasSelectionChanged` landing at index 3, BETWEEN
    ///     `selectionWillChange` and `selectionDidChange`. Class 1 verbatim, in the unsuppressed
    ///     selection bracket. `MarkedTextRouterTests
    ///     .test_setMarkedText_emitsExactlyTheWitnessesOwnTwoBrackets_theBackendAddsNoneOfItsOwn` is
    ///     the same site seen as a bracket-shape diff.
    ///   * `FloatingCursorTests.test_perUpdate_doesNotFireOnSelectionChange_endFiresOnce` — **2 host
    ///     reports instead of 0** across begin + two updates, then 3 instead of 1. Same class, same
    ///     bracket. (Task 37's supplement warned this gate might not see the defect because it asserts
    ///     no golden trace; it asserts an `onSelectionChange` COUNT instead, which is strictly better
    ///     at this — and Rule 16 is satisfied because the same test's second assertion proves the hook
    ///     is live.)
    ///   * `SelectionRouterTests.test_selectedTextRangeSetter_runsTheWholeCanvasBodyThroughTheBackend`
    ///     — **2 instead of 1**. A THIRD hazard shape, named nowhere before:
    ///     `legacyApplySelectedTextRange` is called BY the backend's `selectedTextRange` setter, which
    ///     calls `setSelection(…, reason: .keyboard)` itself three statements later, in the SAME call.
    ///     A `setSelection` in the hook does not double a bracket — it doubles the CALLER's publish,
    ///     and the distance between the two is irrelevant to that. **A site being in no open bracket is
    ///     not what makes it safe; the question is whether its publish would be a SECOND one, which is
    ///     a call-graph question and not a lexical one.**
    ///
    /// **Class 2 does not appear at Task 37's sites (0 traps), and that is not a reprieve** — no
    /// `detach()`-then-drive probe reaches those three files. The class is unchanged everywhere else.
    ///
    /// **THE SHARPEST ROW IS THE GREEN ONE (Rule 24).** Twelve of Task 37's sixteen lines — all seven
    /// `editing`-enclosed ones and five of the six bare ones — produced **no failure at all** under
    /// the publishing construction. Nothing in the suite gates host-report counts on those paths, so
    /// the briefed conversion would have shipped one extra `refreshSelectionUI()` +
    /// `onSelectionChange?()` per site, GREEN. In this phase "the suite stayed green" is not evidence
    /// that a selection conversion preserved behaviour; the construction is.
    ///
    /// # TASK 39 — THE THREE CANVAS FUNNELS WERE THE LAST CANDIDATE FOR `setSelection`, AND THEY LOST
    ///
    /// Task 39's brief kept one clause of the phase's original "raw assignments become `setSelection`"
    /// sentence alive: `setCaret` / `setSelectionHead` / `setSelectionAnchor` are the canvas's
    /// user-facing selection entry points, so "publishing is their POINT". **Measured false, by the
    /// same construction: all 40 of Task 39's warnings converted to a publishing `setSelection`, full
    /// `Scripts/iostest.sh` — 3 red across 3 suites (6 assertion failures), 0 `Fatal error` lines, 0
    /// restarts, out of 2639 executed.** And **the attribution was measured too**, not inferred:
    /// reverting ONLY the three funnels to the raw pair, with **the other 36 warnings** still
    /// publishing, turns all three green (23/0, 10/0, 26/0 — Task 39's review reproduced it as a full
    /// green suite, 2641/0, which is the stronger form). Every failure is those three lines.
    ///   * `SelectionInteractionTests
    ///     .test_setCaret_withReportSuppressed_defersHostReport_untilTheDragEnds` — 3 host reports
    ///     instead of 0 mid-drag, then 5 instead of 1. A publish reaches `onSelectionChange?()` through
    ///     `lifecycleClient.backendDidPublishState(.selection)`, so it **defeats
    ///     `setCaret(global:reportSelectionChange:)`** — the parameter's whole purpose. This is
    ///     `setCanonicalAnchor`'s measured reason 2, landing verbatim.
    ///   * `DelegateTraceCharacterizationTests
    ///     .test_endCoalescedSelectionDrag_emitsExactlyOneBracketWithNoStateChangeBetween` — 3 events
    ///     instead of 2, the extra one at index 0. **A NEW SHAPE worth naming: deferring does not save
    ///     it.** During a coalesced drag `setSelection` sets `pendingCoalescedSelectionPublish` and
    ///     returns; clearing `suppressesSelectionNotifications` then fires that deferred publish from
    ///     the flag's own `didSet`, so the SUPPRESSED path gains an extra publish as well.
    ///   * `MarkedTextTraceCharacterizationTests.test_commitOnSelectionChange_traceAndMarkedState` —
    ///     class 1 verbatim.
    ///
    /// **The other 36 warnings produced NO failure under the publishing shape** — **23 of Task 39's 26
    /// lines**, invisible to the whole suite, exactly as 12 of Task 37's 16 were. The Rule-24 row is now
    /// three tasks long and has never once pointed the other way. (Fix round 1: this said "34 … 17 of
    /// 20". The funnels are **4 warnings on 3 lines**, not six on four; the scope is **40 on 26**. Both
    /// figures come from the compiler — `grep -oE "^/[^ ]+\.swift:[0-9]+:[0-9]+: warning: setter for
    /// '(anchor|head)' is deprecated" /tmp/build.log | sort -u | grep /Sources/`, minus `+Editing.swift`
    /// and `setSelectionForTesting`, counting distinct `file:line` for the line column. The table lives
    /// at `setCaret`; this is a pointer.)
    ///
    /// **AXIS 2 GOT THE SAME TREATMENT AND IT IS THE MORE USEFUL RESULT.** Task 39 built
    /// `.caret(at: <head>)` at each of the seven `.range` claims it produced, one at a time, full suite
    /// each time (mutation confirmed present first). Figures below are TESTS / SUITES, both from the
    /// same command — `grep -E 'Test Case .* failed' <log>` for the first, and that piped through
    /// `sed -E 's/.*\[RichTextEditorUIKitTests\.([A-Za-z]+) .*/\1/' | sort -u | wc -l` for the second;
    /// **the suite column was wrong for the top two until fix round 1 (10 and 9, actually 11 and 7)**,
    /// which is Rule 14's shape — a figure labelled "measured, not cited" is the last one a reader
    /// re-checks, so the command that produced it belongs beside it:
    ///
    ///   * `applySelection` (`+SelectionActions`) — **37 / 11**
    ///   * `setSelectionHead` — **13 / 7**
    ///   * `composerSelectedRange` (`+ComposerSelection`) — 2 / 2
    ///   * `setSelectionAnchor` — 1 / 1
    ///   * **`setBlocks`'s clamp, `selectAcrossBlocks`, `selectAcrossLeafRegions` — 0 / 0.** The clamp
    ///     was pinned in the same commit (`DocumentRevisionTests`), so on any tree after that it reads
    ///     **2 / 1** — the pin working, not a re-measurement disagreeing. The two demo helpers stay at
    ///     zero and are recorded as measured-unpinned at their own sites.
    ///
    /// **A per-site probe distinguishes "safe" from "unwatched"; a whole-population probe does not** —
    /// and that is now a theorem rather than an impression. Arming all seven together gives 53 failing
    /// tests whose SET IS IDENTICAL to the union of the individually-red sites (symmetric difference
    /// empty; reproduced twice, once here and once by the review at 55 on the post-pin tree). **An
    /// aggregate red is exactly the union of the per-site reds: strictly less information, never more,
    /// and the zeros are the information it destroys.**
    func applyCaretOutcome(_ outcome: RichTextInputCaretOutcome) {
        guard let claimed = outcome.selection else { return }
        inputBackend.setCanonicalAnchor(claimed.anchor.utf16Offset)
        inputBackend.setCanonicalHead(claimed.head.utf16Offset)
    }

    /// `editing(coalescing:_:)`'s body, kept as a separate private method. It was extracted at Task
    /// 36a as "the shared body of BOTH `editing` forms"; Task 36c deleted the `Void` form, so there is
    /// one form and one caller now. It stays separate because four doc comments in this package name
    /// `performEditing` as the thing that owns the delegate bracket and the trailing host report, and
    /// because it keeps `editing`'s doc (the contract) apart from this one (the implementation). If a
    /// later task inlines it, those four citations are the sweep. Everything here except the
    /// `applyCaretOutcome` line is the pre-36a `editing(coalescing:_:)` body moved verbatim.
    ///
    /// (That first sentence said "both forms" from Task 36c until its fix round — a sentence true when
    /// written and false after a later commit, with no token or number changing. That class does not
    /// survive a grep for a renamed symbol or a rotted count; it is only found by reading.)
    private func performEditing(coalescing: UndoCoalescing,
                                _ body: () -> RichTextInputCaretOutcome) {
        finalizeMarkedText()   // commit a composition (own undo step) / dismiss a prediction before this edit
        dismissEditMenuForSelectionOrTextChange()   // the text is about to change → close any open menu (native UITextView)
        let before = currentBlocks()
        let beforeAnchor = anchor, beforeHead = head
        // Does this edit CONTINUE the open coalescing run? Same kind, a collapsed caret (not a
        // selection-replace), landing exactly where the last keystroke left off. If so we skip
        // registerUndo entirely — the snapshot taken at the run's START already captures the pre-run
        // document, so one undo reverts the whole run. A caret move / kind switch / selection-replace
        // fails this test and starts a fresh step; see docs/superpowers/specs/2026-07-01-richtext-undo-coalescing-design.md.
        let continuesRun = coalescing != .none && beforeAnchor == beforeHead
            && (openUndoRun.map { $0.kind == coalescing && $0.caret == beforeHead } ?? false)
        // Every edit also moves the caret, so bracket the SELECTION change too — not just the text change.
        // Without this the OS keeps a stale `selectedTextRange` after a programmatic edit (custom emoji
        // keyboard insert / delete), so the caret appears not to advance and the next insert lands at the
        // wrong spot (leaving a stray U+FFFC "service character"). Mirrors `reload`. System-driven keystrokes
        // already let UIKit own the selection; the extra notification there is harmless (matches UITextView).
        // TASK 26: the bracket itself now lives on the backend (`notifyingContentAndSelectionChange`,
        // `LegacyRichTextInputBackend+Notifications.swift`) — the only sender of these notifications
        // in the package. Order and unconditionality are unchanged: all four fire even for a no-op
        // body and even for an edit the body refuses (deviation D10).
        inputBackend.notifyingContentAndSelectionChange {
            let outcome = body()
            // TASK 36a — the caret claim lands HERE: after `body()`, inside the bracket, and BEFORE
            // `bumpDocumentRevision()`. That is the position the raw `anchor = …; head = …` pair
            // occupies today (it runs inside `body()`), so the three things that read the post-body
            // selection below — the undo-caret collapse test, `openUndoRun`, and the delegate
            // bracket's own DID notifications — see the claim exactly as they see a raw write.
            applyCaretOutcome(outcome)
            bumpDocumentRevision()   // one revision per editing transaction, even for a no-op body
        }
        if !continuesRun {
            // Undo caret (iOS-style): a CONTENT edit (typing/deleting/paste) collapses the caret
            // (post-body `anchor == head`) → restore a COLLAPSED caret at the end of the restored span,
            // so undoing a deletion/replacement doesn't re-select the restored text. A selection-
            // preserving edit (formatting: bold/italic/link/style) leaves a range post-body → restore the
            // pre-edit SELECTION so you still see what was un-formatted. See the systematic-debugging note.
            let restoreCaret = max(beforeAnchor, beforeHead)   // end of the pre-edit span
            let undoAnchor = (anchor == head) ? restoreCaret : beforeAnchor
            let undoHead   = (anchor == head) ? restoreCaret : beforeHead
            registerUndo(snapshot: before, anchor: undoAnchor, head: undoHead)   // start a fresh undo step
            undoRegistrationCount += 1
        }   // else: coalesce — the run-start snapshot still stands, so no new registration
        // Open / extend / close the coalescing run for the NEXT edit: a coalescable edit that left a
        // collapsed caret opens (or extends) a run at the new caret; anything else closes it.
        openUndoRun = (coalescing != .none && anchor == head) ? (coalescing, head) : nil
        recomputeDocumentHasSpoilers()   // an edit (toggleSpoiler/delete/paste/insert/structural) may add or remove the last spoiler — refresh the syncSpoilers gate before refreshSelectionUI runs it
        // A structural edit can create a fresh empty paragraph (Enter) or empty an existing one (delete its
        // last char), and an empty paragraph's caret side is driven by its per-box writing-direction hint
        // (render-only). Re-derive it from the typing direction now so a new RTL line opens its caret on the
        // RIGHT — otherwise it would keep the default (left) until the next reload/refocus. Empty-box-only work
        // (restyle no-ops on empty storage); the guard inside makes it a cheap no-op when nothing changed.
        refreshEmptyBoxWritingDirections()
        setNeedsDisplay()
        scheduleSyntaxHighlightPass()   // debounced; a burst of keystrokes fires one pass
        if !suppressHostChangeNotification {
            refreshSelectionUI()   // step 1 of a two-step paste keeps the caret at its prior spot (no caret blink to the raw-text end); step 2 moves it to the final position
            notifyContentSizeChanged()
            onSelectionChange?()   // an edit moves the caret too — ask the host to scroll it into view (like the arrow-key setter)
        }
    }

    /// Restores a whole-document snapshot, then re-registers the inverse for redo (Phase 1 trick).
    func registerUndo(snapshot blocks: [Block], anchor: Int, head: Int,
                      reason: RichTextInputExternalChangeReason = .undo) {
        effectiveUndoManager?.registerUndo(withTarget: self) { target in
            // A system Cmd-Z / shake-undo can fire while composing (the public undo()/redo() finalize first,
            // but the responder path doesn't). Drop any marked-text view state so the snapshot restore can't
            // leave a stale markedRange pointing into the replaced document.
            //
            // **TASK 41 — the two composition assignments became ONE backend call; the third
            // (`ghostStyledLayout`) stays, because D13 keeps it canvas-side.** Task 39b's note here
            // said these assignments must stay until "Task 41 collapses the two stores, THAT is the
            // commit that may delete these" — this is that commit, and it does not delete them so much
            // as re-home them: `clearCompositionState()` is the backend's own name for exactly this
            // operation and Task 41 widened it to clear the composition-start snapshot too.
            //
            // **NOT folded into the `.discard` policy below, and the reason is TIMING rather than
            // stores.** With one store, `.discard` really would clear the same state — but it runs
            // AFTER `body()`, i.e. after `setBlocks` has already replaced the document, whereas the
            // hazard this line exists to prevent is a marked range surviving INTO that replacement.
            // The policy declaration and this call are not redundant: one describes the change to the
            // backend, the other orders the canvas's own state ahead of it.
            //
            // This is the ONE `clearCompositionState()` call site in `Sources/` — the PUBLISHING door.
            // The three composition-lifecycle bodies in `+MarkedText.swift` use the raw non-publishing
            // pair instead, because they emit their own brackets; see that member's contract.
            //
            // **AND THE PUBLISH IS SILENCED TOWARD THE HOST, for a reason specific to this site.**
            // `clearCompositionState()` ends in `publishState(reason: .markedText)`, which
            // `TelegramLifecycleInputClient` maps onto `canvas.notifyContentSizeChanged()`. MEASURED:
            // without this, `ExternalSynchronizationTests.test_noSiteAddsAHostContentSizeNotification`
            // reads 3 for a responder undo and 3 for a redo where BASE reads 2 — a new host callback
            // per undo, which is the exact regression class that test was written to catch. And it
            // would be a callback carrying a STALE answer: it fires BEFORE `setBlocks` restores the
            // snapshot, so the host would read the pre-restore `intrinsicContentSize` and then be
            // notified again a few statements later with the real one.
            //
            // Save-and-restore, never `= false`, so an outer suppression (`pasteMarkdownTwoStep` step 1
            // holds one) is not cleared — the same idiom, for the same reason, as
            // `synchronizingExternalChange` (`DocumentCanvasView.swift`).
            //
            // **RECORDED AS EVIDENCE, not just as a fix: this is the FIFTH item of exactly the kind
            // the coordinator's supplement §5 says the checkpoint list is a symptom of.** Task 41's
            // deferral of that broader change, with its owner and its cost, is written up at
            // `synchronizingExternalChange`'s four-item `defer`.
            let wasSuppressingHostChangeNotification = target.suppressHostChangeNotification
            target.suppressHostChangeNotification = true
            target.inputBackend.clearCompositionState()
            target.suppressHostChangeNotification = wasSuppressingHostChangeNotification
            target.ghostStyledLayout = nil
            let redo = target.currentBlocks()
            let redoAnchor = target.anchor, redoHead = target.head
            // TASK 26: the bracket is the BACKEND's (see `editing` above). It is reached through
            // `target.inputBackend`, never through a captured delegate — this closure re-registers
            // itself for redo, so a captured delegate would outlive any later `inputDelegate` change.
            target.inputBackend.notifyingContentAndSelectionChange {   // undo moves the caret too — keep the OS in sync (see editing)
                // TASK 39b — the ONE emission point for BOTH undo entry paths. `reason` is `.undo` on
                // this registration and `.redo` on the inverse re-registered below, so a redo declares
                // itself. `.discard` DECLARES, to the backend, the intent the three raw marked-state
                // assignments at the top of this closure already carry on the canvas — it does not
                // REPLACE them, and they are not folded in: they clear a DIFFERENT store. See the note
                // at those three lines before deleting any of them.
                //
                // **`RichTextEditorView.undo()`/`redo()` deliberately do NOT wrap** (coordinator
                // supplement RULING 2): the facade's `effectiveUndoManager?.undo()` INVOKES this
                // closure, so a second bracket there would emit two external changes for one
                // user-visible undo. The facade's `canvas.finalizeMarkedText()` has already run by the
                // time this executes, so `.commitBeforeChange` and `.discard` describe the identical
                // state on that path — the policy is a DESCRIPTION of what happened to the marked
                // range, and on the facade path the answer is "already finalized upstream".
                target.synchronizingExternalChange(reason: reason, markedTextPolicy: .discard) {
                    target.setBlocks(blocks, width: target.effectiveWidth)
                    // TASK 40a: spelling only. `target.anchor = …`/`target.head = …` WERE these two
                    // calls — the forwarder setters' bodies are exactly `inputBackend.setCanonicalAnchor`/
                    // `setCanonicalHead` — so this is the same non-publishing write it always was, said
                    // without the setter Task 40b deletes. (`anchor`/`head` here are registerUndo's
                    // PARAMETERS, not the canvas's endpoints; only the receiver changed.)
                    target.inputBackend.setCanonicalAnchor(min(anchor, target.documentSize))
                    target.inputBackend.setCanonicalHead(min(head, target.documentSize))
                }
            }
            // The inverse restores what this undo just replaced — running it is a REDO, so it says so.
            target.registerUndo(snapshot: redo, anchor: redoAnchor, head: redoHead,
                                reason: reason == .undo ? .redo : .undo)
            target.notifyContentSizeChanged()
            target.setNeedsDisplay(); target.refreshSelectionUI()
        }
    }

    /// The structural-edit engine, now operating on the `BlockStack` that owns the selection (the
    /// root stack, or a table cell's stack — resolved via `activeStack`). Replaces the global range
    /// `[from, to)` with `text` WITHIN that one stack. Same-block: in-place. Cross-block: split/merge
    /// (paragraph↔paragraph) or truncate (image endpoint), dropping covered middle boxes. The endpoints
    /// MUST live in the same stack — callers guarantee this (top-level OR same-cell); a cross-stack
    /// range goes to `applyMultiRegionClearOutcome` instead. NOT wrapped in undo — call inside `editing { … }`.
    /// Precondition: `text` must not contain a newline — callers split paragraphs first (see
    /// `insertParagraphBreak`); multi-line paste is deferred (Phase 2c).
    ///
    /// **TASK 36b — the caret is RETURNED, not written. THIS COMMENT IS THE ONE DESCRIPTION OF THE
    /// SHAPE**; the ten other converted primitives say "see `applyReplaceOutcome`". (It lived on the
    /// transitional `applyReplace` wrapper until Task 36c deleted that wrapper along with the other
    /// seven; the parts that were about the wrapper itself went with it.)
    ///
    /// # HOW A CALLER APPLIES THE CLAIM — and the shape it does NOT use
    ///
    /// Through the enclosing `editing { }`'s own return value, or — at the fourteen sites below —
    /// through `applyCaretOutcome(_:)` (same file) on the very next instruction. Either way the claim
    /// reaches the RAW, NON-PUBLISHING endpoint pair. **NOT `inputBackend.setSelection(_:reason:
    /// .command)`,** which is what the phase's brief specified: Task 36a built that shape and measured
    /// it at 10 red across 7 suites plus 2 hard crashes, against a green control. Those numbers and
    /// the two failure classes behind them live at `applyCaretOutcome` and are deliberately not
    /// restated here (Rule 15) — but one half of the reasoning belongs with the CALL SITES rather than
    /// with the mechanism: three of them (`legacySetMarkedText`'s provisional edit,
    /// `dismissPrediction`, `legacyInsertText`'s marked-commit branch) run inside
    /// `notifyingContentChange { }`, a TEXT-ONLY bracket that fires no selection notification at all,
    /// so a publishing application would ADD selection host effects there rather than double existing
    /// ones.
    ///
    /// # WHY THE APPLICATION IS IMMEDIATE AT FOURTEEN SITES, AND WHY THAT IS NOT A DETAIL
    ///
    /// Those fourteen READ THE CARET BACK before their transaction ends, so the claim has to land at
    /// exactly the position the deleted `anchor = caret; head = caret` occupied. Letting it ride to
    /// the end of the enclosing `editing { }` would hand every one of them a stale caret, and a stale
    /// caret here does not merely misplace the cursor — it re-resolves the EDIT, silently producing a
    /// different document. Worked example: select `bc` in `abcd`, then Insert ▸ Details. Applied, the
    /// re-resolved `active.local == 1` in the 2-character `ad` and the paragraph SPLITS. Deferred,
    /// `head` no longer lies in the shrunken region, `active.local` clamps to `p.textLength`, and the
    /// details block is APPENDED after `ad`. **Anything added here that reaches `anchor`/`head`
    /// mid-body is a fifteenth candidate.**
    ///
    /// **The list is the enumeration; there is no separate magnitude to keep in step with it** (an
    /// earlier draft said "six" over a list of five — Rule 15's failure mode in miniature). Derived by
    /// sweeping all 34 wrapper call sites under `Sources/` for a caret read reachable before the
    /// enclosing transaction's outcome would land — so it is exhaustive, not a floor:
    ///
    /// | site | the read |
    /// |---|---|
    /// | `insertCodeBlockNewline`, `insertPullQuoteNewline`, `insertParagraphBreak`, `insertMedia` (this file) | re-resolve `activeStack(at: head)` after a nested `applySelectionReplaceOutcome` |
    /// | `insertDocumentBlocksOutcome`, `replaceRange` (this file) | read back their OWN write — both were `head = anchor`, both are a `let` now |
    /// | `+Buttons.swift`, `+Details.swift`, `+Tables.swift` | `activeStack(at: head)` on the next statement |
    /// | `+Emoji.swift`, `+Formula.swift` | the container-snap and `leafRegion(containingGlobal: head)` |
    /// | `+Clipboard.swift` ×2 | `let caret = head` one line later; and `return (caret, head)` |
    /// | `+UITextInput.swift`'s marked-commit | `commitMarkedText`'s `inputBackend.compositionSnapshot ?? (anchor, head)` (was `compositionAnchorHead` before TASK 41 moved the store) — **across a function boundary**, so no grep of that body reveals it |
    ///
    /// Each of the eight sites outside this file carries its own in-source note saying so. Five are
    /// pinned by tests written for the purpose (`CaretLandingCharacterizationTests`' call-site
    /// section); `+Clipboard.swift` ×2 and `+Tables.swift` were already pinned by `CanvasClipboardTests`
    /// and `CanvasInsertTableTests` (2 red each under a simulated defer, measured). **The other suites
    /// covering these paths were measured GREEN under the same simulated defer, so a broad green run
    /// is not evidence about this class.**
    func applyReplaceOutcome(globalFrom: Int, globalTo: Int, text: String) -> RichTextInputCaretOutcome {
        guard !boxes.isEmpty else { return .unchanged }
        let lo = clampGlobal(min(globalFrom, globalTo))
        let hi = clampGlobal(max(globalFrom, globalTo))
        guard let start = activeStack(at: lo), let end = activeStack(at: hi), start.stack === end.stack else { return .unchanged }
        let stack = start.stack

        if start.index == end.index {
            let b = start.box
            let attrs = typingAttributesAtGlobal(b.textStart + start.local)
            // A replace whose range covers a CODE block's whole node — its LEADING language line as well as
            // its code — must not strand the old language on the block. `activeStack`/`resolveBox` collapse
            // both endpoints onto the code region (the language is a second leaf region, off their radar),
            // so the replace below only touches the code layout and the language survives a selection the
            // user made over it. Same failure the pull/block-quote author has in
            // `applySelectionReplaceOutcome`'s exact-content-span branch, from the other end of the box.
            // Delete is already covered there and by the whole-document reset; this is the type-over case.
            if let code = b as? CodeBlockBox, lo <= coverableContentStart(b), hi >= coverableContentEnd(b) {
                code.languageLayout.replace(start: 0, end: code.languageLength,
                                            with: NSAttributedString(string: ""))
            }
            b.textLayout.replace(start: start.local, end: end.local,
                                 with: NSAttributedString(string: text, attributes: attrs))
            recomputeSpans()
            let caret = b.textStart + start.local + (text as NSString).length
            return .caret(at: caret)
        }

        // Cross-block. A media (image/video) or code endpoint is REMOVED only when the selection covers
        // its whole node (the leading gap + the entire text); a selection that ends/starts PARTWAY through
        // the text keeps the block, truncated (the Phase 2c partial behavior — see the truncate branch).
        // Select-All over a document whose first/last block is an image/code fully covers it, so it is
        // dropped here exactly as a covered MIDDLE block already is.
        func endpointFullyCovered(_ box: CanvasBlock) -> Bool {
            (box is MediaBlockBox || box is CodeBlockBox || box is PullQuoteBox) && lo <= coverableContentStart(box) && hi >= coverableContentEnd(box)
        }
        let keepStartMedia = (start.box is MediaBlockBox || start.box is CodeBlockBox || start.box is PullQuoteBox) && !endpointFullyCovered(start.box)
        let keepEndMedia = (end.box is MediaBlockBox || end.box is CodeBlockBox || end.box is PullQuoteBox) && !endpointFullyCovered(end.box)

        // Merge path: each endpoint is a paragraph OR a fully-covered media/code block (which contributes
        // nothing and is dropped). The surviving paragraph is startPrefix + text + endSuffix; replaceSubrange
        // over [start.index ... end.index] drops every box between the endpoints — including a fully-covered
        // endpoint image or code block. (Paragraph↔paragraph is the original 2b split/merge, unchanged.)
        if !keepStartMedia && !keepEndMedia {
            let headPart = (start.box as? BlockBox)?.currentParagraph().split(at: start.local, newID: BlockID.generate()).0
            let tailPart = (end.box as? BlockBox)?.currentParagraph().split(at: end.local, newID: BlockID.generate()).1
            var headRuns = headPart?.runs ?? []
            if !text.isEmpty {
                let ca = mapper.characterAttributes(from: typingAttributesAtGlobal(start.box.textStart + start.local), style: (start.box as? BlockBox)?.style ?? .body)
                headRuns.append(TextRun(text: text, attributes: ca))
            }
            // Base paragraph carries the start paragraph's identity/style when present (preserving the
            // upper block's style across the merge), else the end paragraph's, else a fresh body paragraph
            // (both endpoints were fully-covered media — e.g. Select-All over [image, image]).
            var merged = headPart ?? tailPart ?? ParagraphBlock(id: BlockID.generate(), runs: [])
            merged.runs = headRuns
            if let tailPart { merged = merged.merging(tailPart) }
            // Inherit the endpoints' mapper (both share the stack) so a table cell keeps its smaller
            // base font across the merge — `mapper` is the canvas (document-body) mapper.
            let mergedBox = BlockBox(paragraph: merged, mapper: start.box.mapper, width: effectiveWidth)
            var newBoxes = stack.boxes
            newBoxes.replaceSubrange(start.index...end.index, with: [mergedBox])
            stack.boxes = newBoxes
            recomputeSpans()
            let caret = mergedBox.textStart + (headPart?.utf16Count ?? 0) + (text as NSString).length
            return .caret(at: caret)
        }
        // A media or code endpoint is only PARTIALLY covered (selection starts/ends partway through its
        // caption/body): TRUNCATE each endpoint's text region (start keeps [0, start.local) + inserted text;
        // end keeps [end.local, …)) and drop ONLY the strictly-covered middle boxes. Do NOT remove the
        // endpoint boxes — a selection ending inside an image/code block keeps that image/code block with
        // its surviving suffix.
        start.box.textLayout.replace(start: start.local, end: start.box.textLength,
                                     with: NSAttributedString(string: text,
                                         attributes: typingAttributesAtGlobal(start.box.textStart + start.local)))
        end.box.textLayout.replace(start: 0, end: end.local, with: NSAttributedString(string: ""))
        if end.index > start.index + 1 {
            var newBoxes = stack.boxes
            newBoxes.removeSubrange((start.index + 1)..<end.index)
            stack.boxes = newBoxes
        }
        recomputeSpans()
        let caret = start.box.textStart + start.local + (text as NSString).length
        return .caret(at: caret)
    }

    /// Removes the image box at `index` and RETURNS a caret at the end of the previous block's text
    /// (or the start of the new first block's text region). Caller wraps this in `editing { … }` and
    /// applies the returned outcome.
    ///
    /// **TASK 36b — the caret is RETURNED, not written.** Shape: see `applyReplaceOutcome`. **No transitional
    /// wrapper, because this primitive has NO CALLERS** — a repo-wide grep finds prose mentions only.
    /// It is converted rather than left alone so Task 36c inherits no odd one out, and the un-suffixed
    /// name is deliberately NOT kept as a wrapper — a deprecated twin nobody calls is noise Task 36c
    /// would only delete.
    ///
    /// **THIS IS THE ONE PLACE THE PROSE MENTIONS ARE DESCRIBED, AND THEIR COUNT IS DELIBERATELY NOT
    /// STATED.** It has been wrong at every pass — "three in `CLAUDE.md`, one in `+Media.swift`" at
    /// Task 36b, "six" at 36c's supplement, "four surviving" at 36c's review — which is Rule 15's case
    /// for describing the CLASS and letting a reader re-derive the members (`grep -rn deleteImageBox`).
    /// The class: every one of them attributes a media-delete path to this function, and **none of
    /// them is a caller.** The real paths are `deleteMediaBlock(id:)` (whole block: removes it from its
    /// OWN stack, appends an empty paragraph only if that stack would otherwise be empty, caret at the
    /// previous block's text end) and `deleteMediaItem(blockID:itemIndex:)` (one album cell). Two
    /// `CLAUDE.md` mentions are legitimately HISTORICAL ("the old …", "Previously the image branch
    /// called …") and must stay; anything present-tense is wrong.
    func deleteImageBoxOutcome(at index: Int) -> RichTextInputCaretOutcome {
        guard boxes.indices.contains(index) else { return .unchanged }
        var newBoxes = boxes
        newBoxes.remove(at: index)
        if newBoxes.isEmpty {   // a document must never be zero blocks — leave an empty paragraph behind
            newBoxes.append(BlockBox(paragraph: ParagraphBlock(id: BlockID.generate()), mapper: mapper, width: effectiveWidth))
        }
        boxes = newBoxes
        recomputeSpans()
        let caret = index > 0 ? boxes[index - 1].textStart + boxes[index - 1].textLength
                              : (boxes.first?.textStart ?? 0)
        return .caret(at: caret)
    }

    /// Removes the media block identified by its occurrence `BlockID` — NOT by `mediaID`, which may be shared
    /// by several blocks. Removes the block from its OWN stack (top-level OR a details / block-quote body, via
    /// `owningStack`), parks the caret at the previous block's text end (else the new first block's start), and
    /// never leaves a stack with zero blocks. No-op when no block has `id`. Owns its own `editing { }` (one undo
    /// step). Stack-aware equivalent of the top-level index-based `deleteImageBoxOutcome`.
    ///
    /// **TASK 36b — a KIND-B primitive** (owns its `editing { }`); see `insertParagraphBreak`.
    func deleteMediaBlock(id: BlockID) {
        guard let (stack, index) = owningStack(ofBlockID: id) else { return }
        editing {
            stack.boxes.remove(at: index)
            // A stack must never be empty — the root document AND a container body each need an editable slot.
            // (A details body always retains its title box at index 0, so this only fires for the root or a
            // block-quote body that held the media as its sole child.)
            if stack.boxes.isEmpty {
                stack.boxes.append(BlockBox(paragraph: ParagraphBlock(id: BlockID.generate()), mapper: self.mapper, width: self.effectiveWidth))
            }
            self.recomputeSpans()
            let target = index > 0 ? stack.boxes[index - 1] : stack.boxes.first
            let caret = target.map { $0.textStart + $0.textLength } ?? 0
            return .caret(at: caret)
        }
    }

    /// Replaces the media block at `index` with a fresh EMPTY body paragraph and RETURNS a caret in it.
    /// Backspace on a (tap-selected, object-replacement-selected, or caption-start) media block turns the
    /// media into an empty paragraph IN PLACE — distinct from `deleteImageBoxOutcome`, which removes the block and
    /// merges the caret up into the previous block. A fresh `BlockID` gives the replacement its own view
    /// (the repaint gate keys on box instance/id). Caller wraps this in `editing { … }`.
    ///
    /// **TASK 36b — the caret is RETURNED, not written.** Shape: see `applyReplaceOutcome`.
    func replaceMediaWithEmptyParagraphOutcome(at index: Int) -> RichTextInputCaretOutcome {
        guard boxes.indices.contains(index) else { return .unchanged }
        let empty = BlockBox(paragraph: ParagraphBlock(id: BlockID.generate(), style: .body, runs: []),
                             mapper: mapper, width: effectiveWidth)
        var newBoxes = boxes
        newBoxes.replaceSubrange(index...index, with: [empty])
        boxes = newBoxes
        recomputeSpans()
        return .caret(at: empty.textStart)
    }

    /// Stack-aware equivalent of `replaceMediaWithEmptyParagraphOutcome(at:)`: replaces the media block with `id` in
    /// its OWN stack (top-level OR a details / block-quote body, via `owningStack`) with a fresh empty body
    /// paragraph, caret there. Lets a Backspace-deletes-media path replace a NESTED media in place instead of
    /// falling through to a generic remove-and-merge. No-op if `id` isn't a media block. Caller wraps in `editing`.
    ///
    /// **TASK 36b — the caret is RETURNED, not written.** Shape: see `applyReplaceOutcome`.
    func replaceMediaWithEmptyParagraphOutcome(id: BlockID) -> RichTextInputCaretOutcome {
        guard let (stack, index) = owningStack(ofBlockID: id), stack.boxes[index] is MediaBlockBox else { return .unchanged }
        let empty = BlockBox(paragraph: ParagraphBlock(id: BlockID.generate(), style: .body, runs: []),
                             mapper: mapper, width: effectiveWidth)
        stack.boxes[index] = empty
        recomputeSpans()
        return .caret(at: empty.textStart)
    }

    /// True for a block that is NOT an editable text paragraph — an image, a table, a block quote
    /// container, or a code block. A backspace at the start of the paragraph AFTER one of these can't
    /// merge text into it, so it removes an empty paragraph instead of the block (and never deletes
    /// the block). A `BlockBox` (body / heading / quote / list paragraph) is text and merges normally.
    func isNonParagraphAtom(_ box: CanvasBlock) -> Bool {
        box is MediaBlockBox || box is TableBlockBox || box is BlockQuoteBox || box is CodeBlockBox || box is PullQuoteBox || box is DetailsBox
    }

    /// The position just past a media/code block's coverable content, for the Select-All / covered-range
    /// delete checks. Captioned media and code end at their caption/text end; a caption-less block (audio or
    /// document) has no text region, so its coverable content ends just after the media atom
    /// (`nodeStart + 1`) — NOT at the collapsed `textStart + textLength` (which equals `nodeStart` there).
    /// NOTE: for a `PullQuoteBox` this deliberately only reaches the END OF THE PULL TEXT, not the trailing
    /// author region — `textStart`/`textLength` are the pull-text-only convenience members (see `PullQuoteBox`).
    /// That is fine for the CROSS-BLOCK drop (a fully-covered endpoint quote is removed wholesale, author and
    /// all). A LONE quote whose entire content (incl. author) is selected is dropped separately by the
    /// exact-content-span branch in `applySelectionReplaceOutcome` (Task 5), which uses the box's full `leafRegions()`.
    func coverableContentEnd(_ box: CanvasBlock) -> Int {
        if let m = box as? MediaBlockBox, m.isCaptionless { return box.nodeStart + 1 }
        // A button row is text-free, so `textStart + textLength` collapses to `nodeStart` and every
        // selection would read as fully covering it. Its content is the atom span: one atom per pill,
        // minimum one (matching `nodeSize`), so the last content position is `nodeStart + atomCount`.
        if let r = box as? ButtonRowBox { return box.nodeStart + max(1, r.buttons.count) }
        return box.textStart + box.textLength
    }

    /// The position at or before which a selection must start to cover a media/code/pull-quote block's
    /// LEADING edge, for the Select-All / covered-range delete checks (paired with `coverableContentEnd`).
    /// A media atom's leading gap (`nodeStart`) is itself a reachable/renderable caret stop (`isGapPosition`),
    /// so `lo <= nodeStart` is achievable via a real selection. A `PullQuoteBox`'s `nodeStart` is NOT reachable
    /// — it sits on the structural token that opens the `.blockQuote` container wrapping the pull/author
    /// paragraphs (added for the author region), one token before the pull text's own `textStart` — so the
    /// true leading edge a real selection can reach is `textStart`. Code blocks and non-audio/audio media have
    /// no such wrapper (`textStart == nodeStart` there already), so this is a no-op for them.
    func coverableContentStart(_ box: CanvasBlock) -> Int {
        if box is PullQuoteBox { return box.textStart }
        return box.nodeStart
    }

    /// Removes the block at `index` and RETURNS the explicit global caret position the caller computed
    /// BEFORE the removal (positions before the removed block are unaffected by it). Used by backspace at
    /// the start of an empty trailing paragraph that follows a non-text block (image / table / code), which
    /// the caller parks at that block's nearest text slot. Caller wraps this in `editing { … }`.
    ///
    /// **TASK 36b — the caret is RETURNED, not written.** Shape: see `applyReplaceOutcome`.
    func removeBlockOutcome(at index: Int, parkingCaretAt caret: Int) -> RichTextInputCaretOutcome {
        guard boxes.indices.contains(index) else { return .unchanged }
        var newBoxes = boxes
        newBoxes.remove(at: index)
        boxes = newBoxes
        recomputeSpans()
        return .caret(at: caret)
    }

    /// Resolves a global position to the innermost owning `BlockStack` — recursing through `BlockQuoteBox`
    /// children by token span, routing table cells through `cellStack`, and matching leaf boxes by their
    /// single leaf region. Handles top-level, in-cell, in-quote (incl. nested quotes), and
    /// quote-inside-table scenarios in one uniform recursive descent. Table selection is preserved:
    /// a table still resolves via `cellStack(containing:)`.
    ///
    /// For positions that fall outside all leaf regions (document start/end boundary, structural gap),
    /// falls back to `resolveBox`'s snapping behaviour — preserving the pre-Task-5 snapping that
    /// callers relied on. Container-structural boundary positions (at a `TableBlockBox` or
    /// `BlockQuoteBox` boundary) are filtered out of the fallback and return nil, so callers that
    /// handle them separately (`caretSnappedIntoContainer`, `selectionEndpointsEditableTopLevel`) still
    /// own that routing.
    func activeStack(at pos: Int) -> (stack: BlockStack, box: CanvasBlock, local: Int, index: Int)? {
        func descend(_ stack: BlockStack) -> (stack: BlockStack, box: CanvasBlock, local: Int, index: Int)? {
            for (i, b) in stack.boxes.enumerated() {
                // A block-quote child stack: descend by TOKEN SPAN (pos strictly inside the container).
                if let bq = b as? BlockQuoteBox, pos > b.nodeStart, pos < b.nodeStart + b.nodeSize {
                    return descend(bq.children)
                }
                // A detail (folding) block child stack: descend by TOKEN SPAN, exactly like a block quote.
                // Its title is children[0] and its body is children[1...], so both resolve to real leaf boxes.
                if let d = b as? DetailsBox, pos > b.nodeStart, pos < b.nodeStart + b.nodeSize {
                    return descend(d.children)
                }
                // A table: keep the existing per-cell resolver (cells hold no nested containers in v1).
                if let t = b as? TableBlockBox, pos > b.nodeStart, pos < b.nodeStart + b.nodeSize {
                    return t.cellStack(containing: pos)
                }
                // A leaf text box (paragraph/code/pullQuote/media-caption): match by its PRIMARY text
                // region — the one starting at `textStart` — NOT by `leafRegions().first`. A code box's
                // FIRST region is its LANGUAGE line, and resolving a language position here would hand
                // every caller a language-relative `local` to apply to the box's CODE layout
                // (`insertCodeBlockNewline` would splice a newline into the code at the wrong offset —
                // demonstrated, not hypothesised). Selecting by `textStart` makes a language position
                // return nil instead, exactly as a quote-author position already does (see the fallback's
                // note below), which leaves every existing `box is CodeBlockBox` branch inert in the
                // language line by construction rather than by each site remembering to ask.
                //
                // NB the naive `pos >= b.textStart, pos <= b.textStart + b.textLength` is NOT equivalent:
                // container boxes (block quote / details / table) report a degenerate
                // `textStart == nodeStart, textLength == 0`, so that form would newly match them at
                // exactly `nodeStart` and return a container with `local == 0`, where today that position
                // correctly falls through to the fallback (which refuses containers).
                if let primary = b.leafRegions().first(where: { $0.globalStart == b.textStart }),
                   pos >= primary.globalStart, pos <= primary.globalStart + primary.length {
                    return (stack, b, pos - primary.globalStart, i)
                }
            }
            return nil
        }
        if let hit = descend(root) { return hit }
        // Fallback: snap structural/document-boundary positions (before first leaf, past last leaf,
        // inter-block gaps) the same way the old resolveBox-based code did. A position INSIDE a container
        // (table cell or block quote) that `descend` couldn't reach — notably a quote/pull-quote AUTHOR
        // region, which is a second leaf region off the child stack — must return nil, NOT the following
        // top-level block that `resolveBox` mis-resolves it to. Genuine top-level boundaries pass through.
        guard !isInsideBlockQuote(pos), !isInsideTable(pos), !isInsideDetails(pos),
              let r = resolveBox(at: pos), !(r.box is TableBlockBox), !(r.box is BlockQuoteBox), !(r.box is DetailsBox) else { return nil }
        // The fallback snaps STRUCTURAL boundaries (before the first leaf, past the last, inter-block
        // gaps). A position inside one of the box's own NON-PRIMARY regions — a code block's language
        // line — is not a boundary, and `resolveBox` maps it to the box with a clamped `local` that
        // callers would apply to `box.textLayout`, the PRIMARY (code) layout. Refuse it, so such a
        // position resolves to no active stack at all, as a quote author's already does.
        if let (region, _) = leafRegion(containingGlobal: pos),
           region.globalStart != r.box.textStart,
           r.box.leafRegions().contains(where: { $0.globalStart == region.globalStart }) {
            return nil
        }
        return (root, r.box, r.local, r.index)
    }

    /// True when a range can be safely edited by the top-level cross-block engine: neither endpoint
    /// is inside a cell or block-quote child, and neither endpoint resolves to a table or block-quote box.
    /// (Spanning a table or block quote as a covered middle box is fine — the merge drops it.)
    func selectionEndpointsEditableTopLevel(_ a: Int, _ b: Int) -> Bool {
        if isInsideTable(a) || isInsideBlockQuote(a) || isInsideDetails(a) || isInsideTable(b) || isInsideBlockQuote(b) || isInsideDetails(b) { return false }
        if let ra = resolveBox(at: a), ra.box is TableBlockBox { return false }
        if let ra = resolveBox(at: a), ra.box is BlockQuoteBox { return false }
        if let ra = resolveBox(at: a), ra.box is DetailsBox { return false }
        if let rb = resolveBox(at: b), rb.box is TableBlockBox { return false }
        if let rb = resolveBox(at: b), rb.box is BlockQuoteBox { return false }
        if let rb = resolveBox(at: b), rb.box is DetailsBox { return false }
        return true
    }

    /// The stack, box and index of the `CodeBlockBox` with `id`, searched recursively (a code block can sit
    /// inside a block quote, a detail block, or a table cell). Needed because a caret in a code block's
    /// LANGUAGE line resolves to no `activeStack` — by design — so a language-line branch cannot get at its
    /// own box the usual way.
    func stackContainingCodeBox(id: BlockID) -> (stack: BlockStack, box: CodeBlockBox, index: Int)? {
        func search(_ stack: BlockStack) -> (stack: BlockStack, box: CodeBlockBox, index: Int)? {
            for (i, b) in stack.boxes.enumerated() {
                if let c = b as? CodeBlockBox, c.id == id { return (stack, c, i) }
                if let bq = b as? BlockQuoteBox, let hit = search(bq.children) { return hit }
                if let d = b as? DetailsBox, let hit = search(d.children) { return hit }
                if let t = b as? TableBlockBox {
                    for cell in t.cells.flatMap({ $0 }) { if let hit = search(cell) { return hit } }
                }
            }
            return nil
        }
        return search(root)
    }

    /// True when both positions resolve to the **same** owning `BlockStack` — either the same table
    /// cell's stack, or the same block-quote child stack — so the full (stack-scoped) `applyReplaceOutcome`
    /// engine can edit within that container, exactly like top-level. Generalizes the former
    /// table-only `bothInSameCellStack`.
    func sameOwningStack(_ a: Int, _ b: Int) -> Bool {
        guard let sa = owningStack(at: a), let sb = owningStack(at: b) else { return false }
        return sa === sb
    }

    /// The `BlockStack` that owns `pos`, tolerating a NON-PRIMARY leaf region — a quote author, a code
    /// block's language line. `activeStack` deliberately refuses those (its `local` would be meaningless
    /// against the box's PRIMARY layout), but stack ownership is well-defined for every region, and a
    /// caller that only needs "which stack is this position in" must not inherit that refusal. Select-All
    /// over a pull quote lands its end endpoint on the (empty) author region, which is how this surfaced.
    func owningStack(at pos: Int) -> BlockStack? {
        if let active = activeStack(at: pos) { return active.stack }
        func search(_ stack: BlockStack) -> BlockStack? {
            for b in stack.boxes {
                // Containers first, so a NESTED box's region reports its own stack rather than the outer
                // one (a container's `leafRegions()` includes its children's).
                if let bq = b as? BlockQuoteBox, let hit = search(bq.children) { return hit }
                if let d = b as? DetailsBox, let hit = search(d.children) { return hit }
                if let t = b as? TableBlockBox {
                    for cell in t.cells.flatMap({ $0 }) { if let hit = search(cell) { return hit } }
                }
                if b.leafRegions().contains(where: { pos >= $0.globalStart && pos <= $0.globalStart + $0.length }) {
                    return stack
                }
            }
            return nil
        }
        return search(root)
    }

    /// THE single routing point for replacing a (non-empty) selection `[from, to)` with `text`. A
    /// selection whose endpoints share a stack (both top-level, or both in one cell) goes to the
    /// stack-scoped `applyReplaceOutcome`; a selection that crosses stack boundaries (cross-cell, cell↔body,
    /// cross-table, or an endpoint resting on a table box) goes to the structure-preserving
    /// `applyMultiRegionClearOutcome`. Every selection-replacing edit (typing, delete, paste, replace-witness,
    /// insert-image's pre-clear) MUST route through here so none drives a cross-stack range into
    /// `applyReplaceOutcome`'s same-stack guard (which would silently no-op). Caller wraps in `editing { … }`.
    ///
    /// **TASK 36b — the caret is RETURNED, not written.** Shape: see `applyReplaceOutcome`.
    ///
    /// **CORRECTION TO THE TASK BRIEF, which called for "multiple early `return`s, each becomes
    /// `return .unchanged`".** Not one of them does. Every path out of this router either claims a
    /// caret of its own (the whole-document reset) or hands back the claim of the primitive it
    /// delegates to; none of the five returns is a no-claim exit. `.unchanged` reaches a caller of
    /// THIS method only when a DELEGATE refuses the edit — `applyReplaceOutcome`'s empty-document /
    /// cross-stack guards, `applyLeafReplaceOutcome`'s no-region guard,
    /// `applyMultiRegionClearOutcome`'s empty-range guard,
    /// `replaceMediaWithEmptyParagraphOutcome`'s bounds guard — which is the correct meaning: the
    /// edit did not happen, so nothing claims the caret. Writing `.unchanged` at any of the five
    /// returns below would silently drop a real caret landing.
    func applySelectionReplaceOutcome(globalFrom: Int, globalTo: Int, text: String) -> RichTextInputCaretOutcome {
        // Never delete/replace a PARTIAL surrogate pair (one half of an astral scalar, which the OS can
        // request on backspace as a 1-unit range) — expand to the whole scalar so no stray code unit is left.
        // (Combining-mark clusters like the Tamil consonant+virama are NOT expanded — a composing IME edits
        // the lone mark to recompose the syllable; see `rangeExpandedToScalarBoundaries`.)
        let (globalFrom, globalTo) = rangeExpandedToScalarBoundaries(globalFrom: globalFrom, globalTo: globalTo)
        // A delete covering the WHOLE document (Select-All → Backspace) resets to a single empty BODY paragraph,
        // dropping ALL block formatting/containers (heading style, quote, list, code, table, media) — not just
        // the text. Without this the cross-block merge/clear paths keep the FIRST block's style/container: an
        // empty heading stays a heading, a leading quote survives. Detected as the range spanning from the first
        // renderable text position to the last.
        // Skip the reset ONLY for a PARTIAL selection within a single table (a cross-cell delete keeps its
        // per-cell clear behavior — clear the covered cells, keep the table). A genuine whole-document Select-All
        // still resets: whether it covers a paragraph before/after the table, OR covers the ENTIRE content of a
        // lone/all-table document (which the old `!isInsideTable` guard — and its first cut — wrongly skipped
        // because a Select-All endpoint lands inside a cell).
        if text.isEmpty, !isPartialSelectionWithinOneTable(globalFrom, globalTo),
           min(globalFrom, globalTo) <= snapToRenderable(0, forward: true),
           max(globalFrom, globalTo) >= snapToRenderable(documentSizeValue, forward: false) {
            let body = BlockBox(paragraph: ParagraphBlock(id: BlockID.generate(), style: .body, runs: []),
                                mapper: mapper, width: effectiveWidth)
            root.boxes = [body]
            recomputeSpans()
            return .caret(at: body.textStart)
        }
        // A delete whose selection EXACTLY covers one media block's node span — UIKit expands a collapsed caret
        // at an image's empty caption / right after the image into [nodeStart, captionEnd], the "object
        // replacement" atom — resolves BOTH endpoints to that one media box, so the same-stack `applyReplaceOutcome`
        // below would compute a zero-length edit and silently no-op (the "backspace on an empty caption does
        // nothing" bug). Replace the media with an empty body paragraph in place. A selection that also covers
        // adjacent text doesn't match (its endpoints differ from the node bounds) and falls through to the
        // normal cross-block drop path.
        if text.isEmpty, let i = boxes.firstIndex(where: {
            $0 is MediaBlockBox && globalFrom == $0.nodeStart && globalTo == coverableContentEnd($0)
        }) {
            return replaceMediaWithEmptyParagraphOutcome(at: i)
        }
        // A delete whose selection covers EXACTLY one (expanded) pull/block quote's entire content — every
        // leaf region including the trailing author line, and nothing outside it (e.g. Select-All over a lone
        // quote). Without this, `activeStack`/`resolveBox` collapse the author position back onto the
        // pull-text / last-child region, so the same-stack `applyReplaceOutcome` clears only that region's text and
        // STRANDS the box together with its author (the author line survives). Drop the whole quote here,
        // replacing it with an empty body paragraph in place — the exact-span guard means a wider selection
        // (a quote plus a neighbour) still falls through to the normal cross-block path. (`replaceMedia…` is
        // reused generically: it just swaps boxes[i] for an empty body paragraph.)
        if text.isEmpty, let i = boxes.firstIndex(where: { box in
            guard box is PullQuoteBox || box is BlockQuoteBox else { return false }
            let regions = box.leafRegions()   // collapsed quote → [] (handled by the gap/atom paths, not here)
            guard let first = regions.first, let last = regions.last else { return false }
            return globalFrom == first.globalStart && globalTo == last.globalStart + last.length
        }) {
            return replaceMediaWithEmptyParagraphOutcome(at: i)
        }
        // A replace whose (expanded) range lies entirely within ONE region the top-level engine cannot
        // resolve — a quote AUTHOR line, or a code block's LANGUAGE line. Both are a SECOND leaf region on
        // their box, off `activeStack`'s radar, so `applyReplaceOutcome` below either mis-resolves both
        // endpoints to the following block or refuses them outright and returns `.unchanged`. Either way
        // the edit silently does nothing: iOS delivers a backspace inside such a field as a RANGE, so the
        // character was selected and then never deleted. Route it region-aware, like a cell.
        if let (rf, _) = leafRegion(containingGlobal: clampGlobal(min(globalFrom, globalTo))),
           regionIsOffTheTopLevelEngine(rf),
           let (rt, _) = leafRegion(containingGlobal: clampGlobal(max(globalFrom, globalTo))),
           rt.globalStart == rf.globalStart {
            return applyLeafReplaceOutcome(globalFrom: globalFrom, globalTo: globalTo, text: text)
        }
        if selectionEndpointsEditableTopLevel(globalFrom, globalTo) || sameOwningStack(globalFrom, globalTo) {
            return applyReplaceOutcome(globalFrom: globalFrom, globalTo: globalTo, text: text)
        } else {
            return applyMultiRegionClearOutcome(globalFrom: globalFrom, globalTo: globalTo, text: text)
        }
    }

    /// True for a leaf region the TOP-LEVEL replace engine cannot resolve: a second region on its box,
    /// outside the box's primary `textStart`/`textLength` extent and off `activeStack`'s radar. A range
    /// inside one must be edited through `applyLeafReplaceOutcome` or it silently no-ops.
    ///
    /// Exhaustive on purpose — no `default`. A new `TextNodeRef` case must state which side it is on here,
    /// because getting it wrong produces an edit that quietly does nothing rather than a build error.
    func regionIsOffTheTopLevelEngine(_ region: LeafTextRegion) -> Bool {
        switch region.ref {
        case .quoteAuthor, .codeLanguage:
            return true
        case .paragraph, .caption, .code, .pullQuote, .detailsTitle:
            return false
        }
    }

    /// If a collapsed caret resolves to a table or block-quote box — a structural boundary such as the
    /// position just before/after one of these containers — returns the nearest in-container text start
    /// so the edit routes through that container's stack. Returns `pos` unchanged when it is not at such
    /// a boundary (or the container has no reachable text). Prevents writing through a container's
    /// degenerate `textLayout` (which would silently drop the keystroke).
    func caretSnappedIntoContainer(_ pos: Int) -> Int {
        guard let r = resolveBox(at: pos) else { return pos }
        if !isInsideTable(pos), let table = r.box as? TableBlockBox {
            let snap = pos <= table.nodeStart
                ? table.cellTextStart(row: 0, column: 0)
                : table.cellTextStart(row: table.rowCount - 1, column: table.columnCount - 1)
            return snap ?? pos
        }
        if !isInsideBlockQuote(pos), let bq = r.box as? BlockQuoteBox,
           let first = bq.children.boxes.first?.leafRegions().first {
            return first.globalStart
        }
        return pos
    }

    /// Inserts a literal newline inside the caret's code block (no paragraph split), replacing any
    /// selection first. Caller checks the caret/selection `head` resolves to a `CodeBlockBox`.
    /// Wraps itself in `editing { }`.
    ///
    /// **TASK 36b — a KIND-B primitive** (owns its `editing { }`); see `insertParagraphBreak`.
    func insertCodeBlockNewline() {
        guard activeStack(at: head)?.box is CodeBlockBox else { return }
        let newline = "\n"
        editing {
            if selFrom != selTo {
                // Applied IMMEDIATELY, not returned: the next statement re-resolves
                // `activeStack(at: head)` and would otherwise read the pre-delete caret.
                applyCaretOutcome(applySelectionReplaceOutcome(globalFrom: selFrom, globalTo: selTo, text: ""))
            }
            // Re-resolve after a possible delete (the caret moved); only insert if still in a code block.
            guard let active = activeStack(at: head), active.box is CodeBlockBox else { return .unchanged }
            active.box.textLayout.replace(start: active.local, end: active.local,
                                          with: NSAttributedString(string: newline, attributes: CodeBlockBox.codeAttributes(textColor: self.mapper.theme.primaryText)))
            recomputeSpans()
            let caret = active.box.textStart + active.local + (newline as NSString).length
            return .caret(at: caret)
        }
    }

    /// Removes a code block's trailing "\n" (if present) and inserts an empty body paragraph after it;
    /// caret lands in the new paragraph. Wraps itself in `editing { }`. Mirrors the quote escape hatch
    /// (`insertEmptyBodyParagraph`) — the only way to start a normal paragraph after a code block that
    /// ends the document.
    ///
    /// **TASK 36b — a KIND-B primitive** (owns its `editing { }`); see `insertParagraphBreak`.
    func exitCodeBlockToBodyParagraph(_ active: (stack: BlockStack, box: CanvasBlock, local: Int, index: Int)) {
        editing {
            let s = active.box.textLayout.attributedString.string as NSString
            if s.hasSuffix("\n") {
                active.box.textLayout.replace(start: s.length - 1, end: s.length, with: NSAttributedString(string: ""))
            }
            let body = BlockBox(paragraph: ParagraphBlock(id: BlockID.generate(), style: .body, runs: []),
                                mapper: mapper, width: effectiveWidth)
            var newBoxes = active.stack.boxes
            newBoxes.insert(body, at: active.index + 1)
            active.stack.boxes = newBoxes
            recomputeSpans()
            return .caret(at: body.textStart)
        }
    }

    /// Where double-return (Enter on an empty line of a code block) exits: `.after` for the trailing blank
    /// line, `.before` for the first blank line, `.uncode` for a wholly-empty code block. `nil` for a
    /// non-empty line or a MIDDLE blank line — which just inserts another newline (no exit).
    enum CodeBlockDoubleReturnExit { case after, before, uncode }

    func codeBlockDoubleReturnExit(_ active: (stack: BlockStack, box: CanvasBlock, local: Int, index: Int)) -> CodeBlockDoubleReturnExit? {
        guard active.box is CodeBlockBox else { return nil }
        let s = active.box.textLayout.attributedString.string as NSString
        let nl = unichar(10)   // "\n"
        // A wholly-empty code block (a single blank line) must NOT un-code on a single Return — the escape
        // requires a double Return. The first Return inserts a newline (→ a wholly-BLANK two-line block); a
        // wholly-blank block then un-codes on the next Return.
        if s.length == 0 { return nil }
        var allBlank = true
        for i in 0..<s.length where s.character(at: i) != nl { allBlank = false; break }
        if allBlank { return .uncode }
        let local = active.local
        // Trailing blank line (caret at the end, last line empty) → after.
        if local == s.length, s.character(at: s.length - 1) == nl { return .after }
        // First blank line → before: the caret is ON it (local 0) OR at the start of the content right after
        // it (local 1) — so Enter at the very beginning, then Enter again, exits (the first Enter lands the
        // caret past the new "\n" on the content line, so the second is at local 1).
        if s.character(at: 0) == nl, local <= 1 { return .before }
        return nil                                    // a non-empty line or a MIDDLE blank line → normal newline
    }

    /// Removes a code block's leading "\n" and inserts an empty body paragraph BEFORE it (caret there) —
    /// the mirror of `exitCodeBlockToBodyParagraph` for double-return on the first line.
    ///
    /// **TASK 36b — a KIND-B primitive** (owns its `editing { }`); see `insertParagraphBreak`.
    func exitCodeBlockToBodyParagraphBefore(_ active: (stack: BlockStack, box: CanvasBlock, local: Int, index: Int)) {
        editing {
            let s = active.box.textLayout.attributedString.string as NSString
            if s.hasPrefix("\n") {
                active.box.textLayout.replace(start: 0, end: 1, with: NSAttributedString(string: ""))
            }
            let body = BlockBox(paragraph: ParagraphBlock(id: BlockID.generate(), style: .body, runs: []),
                                mapper: mapper, width: effectiveWidth)
            var newBoxes = active.stack.boxes
            newBoxes.insert(body, at: active.index)
            active.stack.boxes = newBoxes
            recomputeSpans()
            return .caret(at: body.textStart)
        }
    }

    /// Replaces a wholly-empty code block with an empty body paragraph (caret there) — double-return on an
    /// empty code block exits it cleanly (mirrors the empty-quote exit and Backspace-in-empty-code).
    ///
    /// **TASK 36b — a KIND-B primitive** (owns its `editing { }`); see `insertParagraphBreak`.
    func uncodeEmptyCodeBlock(_ active: (stack: BlockStack, box: CanvasBlock, local: Int, index: Int)) {
        editing {
            let body = BlockBox(paragraph: ParagraphBlock(id: BlockID.generate(), style: .body, runs: []),
                                mapper: mapper, width: effectiveWidth)
            var newBoxes = active.stack.boxes
            newBoxes.replaceSubrange(active.index...active.index, with: [body])
            active.stack.boxes = newBoxes
            recomputeSpans()
            return .caret(at: body.textStart)
        }
    }

    // MARK: - Pull-quote in-block editing (mirrors the code-block editing affordances)

    /// Where double-return (Enter on an empty line of a pull quote) exits: `.after` for the trailing blank
    /// line, `.before` for the first blank line, `.unmake` for a wholly-empty pull quote. `nil` for a
    /// non-empty line or a MIDDLE blank line — which just inserts another interior newline (no exit).
    enum PullQuoteDoubleReturnExit { case after, before, unmake }

    /// Inserts a literal newline inside the caret's pull quote (no paragraph split), replacing any selection
    /// first. The inserted newline carries pull-quote attributes (italic/centered). Caller checks the caret
    /// resolves to a `PullQuoteBox`. Wraps itself in `editing { }`.
    ///
    /// **TASK 36b — a KIND-B primitive** (owns its `editing { }`); see `insertParagraphBreak`.
    func insertPullQuoteNewline() {
        guard activeStack(at: head)?.box is PullQuoteBox else { return }
        editing {
            // Applied IMMEDIATELY, not returned — see `insertCodeBlockNewline` above.
            if selFrom != selTo { applyCaretOutcome(applySelectionReplaceOutcome(globalFrom: selFrom, globalTo: selTo, text: "")) }
            guard let active = activeStack(at: head), active.box is PullQuoteBox else { return .unchanged }
            active.box.textLayout.replace(start: active.local, end: active.local,
                with: NSAttributedString(string: "\n", attributes: PullQuoteBox.pullQuoteTypingAttributes(mapper)))
            recomputeSpans()
            let caret = active.box.textStart + active.local + 1
            return .caret(at: caret)
        }
    }

    func pullQuoteDoubleReturnExit(_ active: (stack: BlockStack, box: CanvasBlock, local: Int, index: Int)) -> PullQuoteDoubleReturnExit? {
        guard active.box is PullQuoteBox else { return nil }
        let s = active.box.textLayout.attributedString.string as NSString
        let nl = unichar(10)   // "\n"
        // A wholly-empty pull quote must NOT un-make on a single Return — the escape requires a double Return.
        // The first Return inserts a newline (→ a wholly-BLANK two-line quote); a wholly-blank quote then
        // un-makes on the next Return.
        if s.length == 0 { return nil }
        var allBlank = true
        for i in 0..<s.length where s.character(at: i) != nl { allBlank = false; break }
        if allBlank { return .unmake }
        let local = active.local
        if local == s.length, s.character(at: s.length - 1) == nl { return .after }
        if s.character(at: 0) == nl, local <= 1 { return .before }
        return nil
    }

    /// Removes a pull quote's trailing "\n" (if present) and inserts an empty body paragraph after it;
    /// caret lands in the new paragraph. Mirrors `exitCodeBlockToBodyParagraph`.
    ///
    /// **TASK 36b — a KIND-B primitive** (owns its `editing { }`); see `insertParagraphBreak`.
    func exitPullQuoteToBodyParagraph(_ active: (stack: BlockStack, box: CanvasBlock, local: Int, index: Int)) {
        editing {
            let s = active.box.textLayout.attributedString.string as NSString
            if s.hasSuffix("\n") {
                active.box.textLayout.replace(start: s.length - 1, end: s.length, with: NSAttributedString(string: ""))
            }
            let body = BlockBox(paragraph: ParagraphBlock(id: BlockID.generate(), style: .body, runs: []),
                                mapper: mapper, width: effectiveWidth)
            var newBoxes = active.stack.boxes
            newBoxes.insert(body, at: active.index + 1)
            active.stack.boxes = newBoxes
            recomputeSpans()
            return .caret(at: body.textStart)
        }
    }

    /// Removes a pull quote's leading "\n" and inserts an empty body paragraph BEFORE it (caret there).
    /// Mirrors `exitCodeBlockToBodyParagraphBefore`.
    ///
    /// **TASK 36b — a KIND-B primitive** (owns its `editing { }`); see `insertParagraphBreak`.
    func exitPullQuoteToBodyParagraphBefore(_ active: (stack: BlockStack, box: CanvasBlock, local: Int, index: Int)) {
        editing {
            let s = active.box.textLayout.attributedString.string as NSString
            if s.hasPrefix("\n") {
                active.box.textLayout.replace(start: 0, end: 1, with: NSAttributedString(string: ""))
            }
            let body = BlockBox(paragraph: ParagraphBlock(id: BlockID.generate(), style: .body, runs: []),
                                mapper: mapper, width: effectiveWidth)
            var newBoxes = active.stack.boxes
            newBoxes.insert(body, at: active.index)
            active.stack.boxes = newBoxes
            recomputeSpans()
            return .caret(at: body.textStart)
        }
    }

    /// Replaces a wholly-empty pull quote with an empty body paragraph (caret there). Mirrors
    /// `uncodeEmptyCodeBlock`.
    ///
    /// **TASK 36b — a KIND-B primitive** (owns its `editing { }`); see `insertParagraphBreak`.
    func unmakeEmptyPullQuote(_ active: (stack: BlockStack, box: CanvasBlock, local: Int, index: Int)) {
        editing {
            let body = BlockBox(paragraph: ParagraphBlock(id: BlockID.generate(), style: .body, runs: []),
                                mapper: mapper, width: effectiveWidth)
            var newBoxes = active.stack.boxes
            newBoxes.replaceSubrange(active.index...active.index, with: [body])
            active.stack.boxes = newBoxes
            recomputeSpans()
            return .caret(at: body.textStart)
        }
    }

    // MARK: - Table header-cell double-return (exit ABOVE the table)

    /// True when Return should EXIT a header (first-row) table cell to a new body paragraph ABOVE the
    /// table: a collapsed caret at the START of the cell's SECOND block, whose FIRST block is an empty
    /// paragraph (the leading-blank case). The table analog of the code block's "two newlines at the
    /// beginning exits before". Header rows only; a trailing blank (previous block non-empty), a
    /// non-leading blank, or a body-row cell falls through to the normal in-cell split. The `activeTable()`
    /// guard also confirms the caret is in a table, so this can't misfire on a top-level paragraph.
    func headerCellDoubleReturnExitsAbove(_ active: (stack: BlockStack, box: CanvasBlock, local: Int, index: Int)) -> Bool {
        guard active.box is BlockBox, active.index == 1, active.local == 0,
              let first = active.stack.boxes.first as? BlockBox, first.textLength == 0 else { return false }
        guard let table = activeTable(), table.box.isHeaderRow(table.row) else { return false }
        return true
    }

    /// Exits a header cell's leading-blank double-return: drops the empty first block from the cell and
    /// inserts an empty body paragraph immediately BEFORE the table (caret there). Mirrors
    /// `exitCodeBlockToBodyParagraphBefore`. Wraps itself in `editing { }`.
    ///
    /// **TASK 36b — a KIND-B primitive** (owns its `editing { }`); see `insertParagraphBreak`.
    func exitHeaderCellToBodyParagraphBefore(_ active: (stack: BlockStack, box: CanvasBlock, local: Int, index: Int)) {
        guard let table = activeTable() else { return }
        editing {
            // Drop the empty leading block from the cell (active.index == 1 ⇒ index 0 is that empty block;
            // the cell keeps its remaining ≥1 block). The table box itself is unchanged, so its index in its
            // OWN stack (`table.stack`) — and the `active.stack` cell reference — stay valid.
            var cellBoxes = active.stack.boxes
            cellBoxes.remove(at: 0)
            active.stack.boxes = cellBoxes
            // Insert an empty body paragraph immediately before the table, in the TABLE's own stack (top-level
            // OR a container body), 17pt canvas mapper (not the cell's 15pt variant).
            let body = BlockBox(paragraph: ParagraphBlock(id: BlockID.generate(), style: .body, runs: []),
                                mapper: mapper, width: effectiveWidth)
            table.stack.boxes.insert(body, at: table.index)
            recomputeSpans()
            return .caret(at: body.textStart)
        }
    }

    /// Splits the caret's paragraph at the caret, within whatever `BlockStack` owns the caret (root
    /// or a cell). Deletes any selection first (bounded if it touches a table). Caret → new block start.
    ///
    /// **TASK 36b — a KIND-B primitive: it owns its own `editing { }`, so there is no caller to
    /// return an outcome to.** Its three brackets take the outcome-returning closure, its caret writes
    /// become `return .caret(at:)` and its in-bracket `guard … else { return }` exits become
    /// `return .unchanged`. Signature, name and every call site are untouched — a wrapper here would
    /// wrap nothing. (The task brief modelled all sixteen primitives as the Kind-A shape; fifteen of
    /// them, this one included, are Kind B. See the report's Step-1 enumeration.)
    func insertParagraphBreak() {
        guard !boxes.isEmpty else { return }
        // Return on an EMPTY list item does NOT continue the list: a nested item outdents one level, a
        // top-level (level 0) one ends the list (becomes a body paragraph — or, inside a quote, an empty
        // quote line). The caret stays put. Matches the placeholder hint; a non-empty list item or plain
        // paragraph falls through to a normal split.
        if selFrom == selTo, let active = activeStack(at: head), let p = active.box as? BlockBox,
           let list = p.listMembership, p.textLength == 0 {
            if list.level > 0 {
                outdent()
            } else {
                editing {
                    p.listMembership = nil
                    p.style = .body
                    restyle(p)
                    recomputeSpans()
                    return .unchanged   // "the caret stays put" — and that is a NO CLAIM, not a claim of `head`
                }
            }
            return
        }
        // Enter in a media caption (image / video / location) splits it: the head stays as the caption,
        // the tail becomes a new body paragraph immediately after the media (caret there). A caret at the
        // end produces an empty new paragraph; a caret at the start moves the whole caption down. Audio and
        // document are caption-less and excluded — their Enter fires the gap-caret branch in insertText
        // before we reach here.
        if selFrom == selTo, let active = activeStack(at: head),
           let mediaBox = active.box as? MediaBlockBox, !mediaBox.isCaptionless {
            editing {
                guard case .media(let mediaBlock) = mediaBox.currentBlock() else { return .unchanged }
                let tmpCaption = ParagraphBlock(id: BlockID.generate(), style: .caption, runs: mediaBlock.caption)
                let parts = tmpCaption.split(at: active.local, newID: BlockID.generate())
                // Rebuild via the CONTAINER initializer (`items:`), not the legacy single-media one — the
                // legacy init wraps only `mediaBlock.mediaID`/`kind`/`naturalSize` (the FIRST item), which
                // silently drops items[1...] for a multi-item (mosaic) container. See docs/superpowers/sdd
                // task-7 notes.
                let newMedia = MediaBlock(id: mediaBlock.id, items: mediaBlock.items, displayWidth: mediaBlock.displayWidth,
                                          alignment: mediaBlock.alignment, caption: parts.0.runs)
                let newMediaBox = MediaBlockBox(media: newMedia, mapper: mediaBox.mapper, width: effectiveWidth,
                                                horizontalBleed: mediaBox.horizontalBleed)
                let bodyBox = BlockBox(paragraph: ParagraphBlock(id: BlockID.generate(), style: .body, runs: parts.1.runs),
                                       mapper: mediaBox.mapper, width: effectiveWidth)
                var newBoxes = active.stack.boxes
                let replacement: [any CanvasBlock] = [newMediaBox, bodyBox]
                newBoxes.replaceSubrange(active.index...active.index, with: replacement)
                active.stack.boxes = newBoxes
                recomputeSpans()
                return .caret(at: bodyBox.textStart)
            }
            return
        }
        editing {
            if selFrom != selTo {
                // Applied IMMEDIATELY, not returned: the next statement re-resolves
                // `activeStack(at: head)` and would otherwise read the pre-delete caret.
                applyCaretOutcome(applySelectionReplaceOutcome(globalFrom: selFrom, globalTo: selTo, text: ""))
            }
            guard let active = activeStack(at: head), let p = active.box as? BlockBox else { return .unchanged }
            let split = p.currentParagraph().split(at: active.local, newID: BlockID.generate())
            let upper = split.0
            var lower = split.1
            // A heading is a single-line title: the paragraph AFTER a Return is a body paragraph, not another
            // heading (matches word processors' "next paragraph style"). Applies to the split-off lower half —
            // empty when Return is at the heading's end, or carrying the tail text when mid-heading.
            switch upper.style {
            case .heading1, .heading2, .heading3, .heading4, .heading5, .heading6:
                lower.style = .body
                // `currentParagraph()` PINS the rendered font size into each run on read-back, so the tail
                // carries the heading's large size; drop it so the now-body tail inherits the body style size.
                lower.runs = lower.runs.map { var r = $0; r.attributes.fontSize = nil; return r }
            default: break
            }
            if lower.list?.marker == .checklist { lower.list?.checked = false }   // a new checklist item is never pre-checked
            // Both halves inherit `p`'s mapper so an in-cell split keeps the cell's smaller base font
            // (including the new EMPTY half, whose later first-typed character reads its box's mapper).
            let upperBox = BlockBox(paragraph: upper, mapper: p.mapper, width: effectiveWidth)
            let lowerBox = BlockBox(paragraph: lower, mapper: p.mapper, width: effectiveWidth)
            var newBoxes = active.stack.boxes
            newBoxes.replaceSubrange(active.index...active.index, with: [upperBox, lowerBox])
            active.stack.boxes = newBoxes
            recomputeSpans()
            return .caret(at: lowerBox.textStart)
        }
    }

    /// Merges `stack.boxes[upperIndex+1]` into `stack.boxes[upperIndex]` (both paragraphs), within the
    /// given stack. RETURNS a caret at the join; the caller wraps in `editing { }` and applies it.
    ///
    /// **TASK 36b — the caret is RETURNED, not written.** Shape: see `applyReplaceOutcome`.
    func mergeParagraphsOutcome(in stack: BlockStack, upperIndex: Int) -> RichTextInputCaretOutcome {
        guard stack.boxes.indices.contains(upperIndex), stack.boxes.indices.contains(upperIndex + 1),
              let upper = stack.boxes[upperIndex] as? BlockBox,
              let lower = stack.boxes[upperIndex + 1] as? BlockBox else { return .unchanged }
        let joinLocal = upper.currentParagraph().utf16Count
        // `merging` drops the lower paragraph's pinned font size on a cross-style merge (body→heading etc.),
        // so the merged text inherits the surviving upper style's size. See ParagraphBlock.merging.
        let merged = upper.currentParagraph().merging(lower.currentParagraph())
        // Inherit `upper`'s mapper (same stack as `lower`) so an in-cell merge keeps the cell's base font.
        let mergedBox = BlockBox(paragraph: merged, mapper: upper.mapper, width: effectiveWidth)
        var newBoxes = stack.boxes
        newBoxes.replaceSubrange(upperIndex...(upperIndex + 1), with: [mergedBox])
        stack.boxes = newBoxes
        recomputeSpans()
        let caret = mergedBox.textStart + joinLocal
        return .caret(at: caret)
    }

    /// Inserts a media block (`kind`, with the given `caption`, empty by default) at the caret, splitting the caret's paragraph
    /// if mid-text. The host resolves `mediaID` to a view via the canvas's `mediaViewProvider` (each
    /// occurrence gets its own view, keyed by the new block's `BlockID`). Caret lands in the new caption.
    /// Inserts `document`'s blocks at the caret. If the caret's top-level block is an empty paragraph (any
    /// empty `BlockBox`, regardless of style), that block is REPLACED by the inserted blocks; otherwise they
    /// are inserted AFTER the caret's top-level block (the current block is never split). One undo step; the
    /// caret lands at the end of the inserted content (RETURNED by `insertDocumentBlocksOutcome`, applied by
    /// this method's own `editing`). A no-op for an empty document. Mirrors `insertMedia`'s
    /// splice, building boxes with the same `makeBox` factory `setBlocks` uses.
    ///
    /// **TASK 36b — a KIND-B primitive** (owns its `editing { }`); see `insertParagraphBreak`.
    func insertDocument(_ document: Document) {
        guard !document.blocks.isEmpty else { return }
        editing { insertDocumentBlocksOutcome(document.blocks) }
    }

    /// Box-level insert of `blocks` at the caret (NO `editing{}` — the caller owns the undo step): the caret's
    /// block is REPLACED if it's an empty paragraph, otherwise the blocks are inserted AFTER it (never
    /// splitting it). RETURNS a caret at the end of the inserted content. Shared by `insertDocument` and by
    /// `replaceRange`'s non-text-gap fallback.
    ///
    /// **TASK 36b — the caret is RETURNED, not written.** Shape: see `applyReplaceOutcome`. No transitional
    /// wrapper: its only caller anywhere is `insertDocument` immediately above, converted in the
    /// same commit. (The doc comment above still describes `replaceRange`'s "non-text-gap fallback"
    /// as a second caller; that call no longer exists — `replaceRange` goes through
    /// `Document.replacingRange` — and the claim is left as found rather than silently corrected,
    /// since it is not this task's to verify.)
    func insertDocumentBlocksOutcome(_ blocks: [Block]) -> RichTextInputCaretOutcome {
        let newBoxes = blocks.compactMap {
            makeBox(for: $0, mapper: mapper, quoteStyle: quoteStyle, pullQuoteStyle: pullQuoteStyle,
                    expandImage: quoteCollapseIcons?.expand, collapseImage: quoteCollapseIcons?.collapse,
                    horizontalBleed: mediaBlockStyle.horizontalBleed, width: effectiveWidth)
        }
        guard !newBoxes.isEmpty else { return .unchanged }
        var updated = boxes
        let firstInserted: Int
        // Find the TOP-LEVEL block whose structural span contains the caret. This uses `nodeStart`/`nodeSize`
        // (which cover nested content) rather than `resolveBox`, whose text-span loop mis-resolves a caret
        // INSIDE a quote/table to the FOLLOWING top-level block — see the note in `insertMedia`.
        if let index = boxes.firstIndex(where: { head >= $0.nodeStart && head < $0.nodeStart + $0.nodeSize }) {
            if let p = boxes[index] as? BlockBox, p.textLength == 0 {
                updated.replaceSubrange(index...index, with: newBoxes)           // empty paragraph → replace it
                firstInserted = index
            } else {
                updated.insert(contentsOf: newBoxes, at: index + 1)              // else insert AFTER the block
                firstInserted = index + 1
            }
        } else {
            updated.append(contentsOf: newBoxes)                                 // caret past the last block → append
            firstInserted = updated.count - newBoxes.count
        }
        boxes = updated
        recomputeSpans()
        let last = boxes[firstInserted + newBoxes.count - 1]                      // caret at end of inserted content
        return .caret(at: last.textStart + last.textLength)
    }

    /// Replaces the global range `[globalFrom, globalTo)` with `document`'s blocks as ONE undo step, via the
    /// pure-Core `Document.replacingRange` (structural delete of the complement + the tested `insertingFragment`
    /// splice). Because the delete is computed structurally rather than through a caret-based cross-block walk,
    /// a fully-covered table/media is dropped at EITHER end of a mixed range — unlike `applySelectionReplaceOutcome`,
    /// whose `resolveBox` routing mishandles a leading-edge container (the documented degenerate-container tech
    /// debt). An empty `document` deletes the range. The caret collapses to the end of the inserted content.
    ///
    /// **TASK 36b — a KIND-B primitive** (owns its `editing { }`); see `insertParagraphBreak`. The
    /// old `head = anchor` read back the endpoint it had just written one statement earlier; it is a
    /// `let` now, which is the only way that spelling survives the split.
    func replaceRange(globalFrom: Int, globalTo: Int, with document: Document) {
        editing {
            let (newDoc, caret) = Document(blocks: currentBlocks())
                .replacingRange(globalFrom: globalFrom, globalTo: globalTo, with: document)
            setBlocks(newDoc.blocks, width: effectiveWidth)
            return .caret(at: min(caret, documentSize))
        }
    }

    func insertMedia(mediaID: String, naturalSize: CGSize, kind: MediaKind, caption: [TextRun] = []) {
        // `!isInsideBlockQuote(head)` is load-bearing: a caret inside a quote has no degenerate-container-safe
        // resolveBox, so `resolveBox(at: head)` below mis-resolves to the FOLLOWING top-level block and the media
        // would be inserted there. Media isn't supported inside quotes (v1) → no-op.
        guard !boxes.isEmpty, !isInsideBlockQuote(head) else { return }
        // Inserts into the caret's OWN stack (top level OR a detail block's body) via container-aware
        // `activeStack` (NOT `resolveBox`, which mis-resolves a container-interior caret to the following block).
        // Deliberately do NOT becomeFirstResponder here: inserting media (typically picked while the editor
        // is unfocused) must not steal focus / pop the keyboard. The caret is still placed at/after the new
        // media below (model caret), so a later tap/focus lands there. When already focused, that caret is
        // scrolled into view synchronously (FR-gated `scrollCaretIntoView`); when unfocused, the new block is
        // laid out by the host's async `update()` on `onChange`. (Was: unconditional becomeFirstResponder —
        // removed 2026-07-21 so an unfocused insert no longer forces focus.)
        editing {
            // Applied IMMEDIATELY, not returned — see `insertCodeBlockNewline` above.
            if selFrom != selTo { applyCaretOutcome(applySelectionReplaceOutcome(globalFrom: selFrom, globalTo: selTo, text: "")) }
            guard let pos = activeStack(at: head) else { return .unchanged }
            let mediaBlock = MediaBlock(id: BlockID.generate(), mediaID: mediaID, kind: kind,
                                        naturalSize: Size2D(width: Double(naturalSize.width),
                                                            height: Double(naturalSize.height)),
                                        caption: caption)
            let mediaBox = MediaBlockBox(media: mediaBlock, mapper: mapper, width: effectiveWidth,
                                         horizontalBleed: mediaBlockStyle.horizontalBleed)
            var newBoxes = pos.stack.boxes
            if let p = pos.box as? BlockBox, p.textLength == 0 {
                newBoxes.replaceSubrange(pos.index...pos.index, with: [mediaBox])   // empty paragraph → replace it
            } else if let p = pos.box as? BlockBox, pos.local > 0, pos.local < p.textLength {
                // split the paragraph and insert the media between the halves
                let (upper, lower) = p.currentParagraph().split(at: pos.local, newID: BlockID.generate())
                let upperBox = BlockBox(paragraph: upper, mapper: mapper, width: effectiveWidth)
                let lowerBox = BlockBox(paragraph: lower, mapper: mapper, width: effectiveWidth)
                let replacement: [any CanvasBlock] = [upperBox, mediaBox, lowerBox]
                newBoxes.replaceSubrange(pos.index...pos.index, with: replacement)
            } else if pos.local == 0 {
                newBoxes.insert(mediaBox, at: pos.index)        // before the caret's block
            } else {
                newBoxes.insert(mediaBox, at: pos.index + 1)    // after the caret's block
            }
            pos.stack.boxes = newBoxes
            recomputeSpans()
            if kind.isCaptionless {
                // Audio/document are caption-less: land the caret in the body paragraph AFTER the block,
                // appending an empty one when it is last or is followed by a non-paragraph atom, so typing
                // continues. (Captioned media lands the caret in its caption.) All within the SAME stack.
                let stackBoxes = pos.stack.boxes
                let mediaIndex = stackBoxes.firstIndex(where: { $0.id == mediaBox.id }) ?? stackBoxes.count - 1
                let following = mediaIndex + 1 < stackBoxes.count ? stackBoxes[mediaIndex + 1] : nil
                if let nextParagraph = following as? BlockBox {
                    return .caret(at: nextParagraph.textStart)
                } else {
                    let trailing = BlockBox(paragraph: ParagraphBlock(id: BlockID.generate(), style: .body, runs: []),
                                            mapper: mapper, width: effectiveWidth)
                    var withTrailing = pos.stack.boxes
                    withTrailing.insert(trailing, at: mediaIndex + 1)
                    pos.stack.boxes = withTrailing
                    recomputeSpans()
                    return .caret(at: trailing.textStart)
                }
            } else {
                return .caret(at: mediaBox.textStart)
            }
        }
    }

    /// Inserts a new body paragraph immediately before the (top-level) ATOM box at `index` — currently a
    /// media block — containing `text` (empty for a bare newline). The caret lands at the end of the
    /// inserted text — RETURNED, not written. Used when a keystroke arrives with the caret on an atom's leading gap, so it opens a
    /// normal paragraph there instead of falling into the atom's (display-only) layout. Mirrors `insertMedia`'s
    /// block-insert. Caller wraps this in `editing { … }`.
    ///
    /// **TASK 36b — the caret is RETURNED, not written.** Shape: see `applyReplaceOutcome`.
    func insertBodyParagraphOutcome(beforeBoxAt index: Int, text: String) -> RichTextInputCaretOutcome {
        guard boxes.indices.contains(index) else { return .unchanged }
        let runs = text.isEmpty ? [] : [TextRun(text: text)]
        let newBox = BlockBox(paragraph: ParagraphBlock(id: BlockID.generate(), runs: runs),
                              mapper: mapper, width: effectiveWidth)
        var newBoxes = boxes
        newBoxes.insert(newBox, at: index)
        boxes = newBoxes
        recomputeSpans()
        let caret = newBox.textStart + (text as NSString).length
        return .caret(at: caret)
    }

    /// Inserts an empty body paragraph at `insertIndex` (shifting later boxes down), placing the caret in
    /// it. The escape hatch for a quote (tap below it / Shift+Return) — there is otherwise no way to start
    /// a normal paragraph adjacent to a quote at the document's edge. Undoable.
    ///
    /// **TASK 36b — a KIND-B primitive** (owns its `editing { }`); see `insertParagraphBreak`.
    func insertEmptyBodyParagraph(at insertIndex: Int) {
        guard insertIndex >= 0, insertIndex <= boxes.count else { return }
        editing {
            let newBox = BlockBox(paragraph: ParagraphBlock(id: BlockID.generate(), style: .body, runs: []),
                                  mapper: mapper, width: effectiveWidth)
            var newBoxes = boxes
            newBoxes.insert(newBox, at: insertIndex)
            boxes = newBoxes
            recomputeSpans()
            return .caret(at: newBox.textStart)
        }
    }

    /// In-place text replace within the leaf region's layout (used for typing inside cells, and as
    /// the same-leaf fast path generally). Recomputes spans. Caller wraps in `editing { }`.
    ///
    /// **TASK 36b — the caret is RETURNED, not written.** Shape: see `applyReplaceOutcome`.
    func applyLeafReplaceOutcome(globalFrom: Int, globalTo: Int, text: String) -> RichTextInputCaretOutcome {
        guard let (region, _) = leafRegion(containingGlobal: clampGlobal(min(globalFrom, globalTo))) else { return .unchanged }
        let lo = clampGlobal(min(globalFrom, globalTo)) - region.globalStart
        let hi = min(clampGlobal(max(globalFrom, globalTo)) - region.globalStart, region.length)
        guard lo >= 0, hi >= lo else { return .unchanged }
        let attrs = typingAttributeDict(region: region, atLocal: lo)
        region.layout.replace(start: lo, end: hi, with: NSAttributedString(string: text, attributes: attrs))
        recomputeSpans()
        let caret = region.globalStart + lo + (text as NSString).length
        return .caret(at: caret)
    }

    /// Structure-preserving clear of a selection that crosses `BlockStack` boundaries (cross-cell,
    /// cell↔body, cross-table). Clears the covered text in EVERY touched leaf region (paragraph or
    /// image caption), and lands any replacement `text` in the region owning **selFrom** (its kept
    /// prefix + text), exactly as a single-region replace would. Never removes a box, cell, row, or the
    /// grid — a fully-covered cell keeps an empty paragraph; a covered image keeps its atom (only its
    /// caption clears). One `recomputeSpans()`; the RETURNED caret always collapses to selFrom (+ text length), even
    /// when the selection covered only empty regions (so a keystroke is never lost / the selection never
    /// sticks). Mirrors `selectionRects` so what clears == what was highlighted. Caller wraps in `editing { … }`.
    ///
    /// **TASK 36b — the caret is RETURNED, not written.** Shape: see `applyReplaceOutcome`. This primitive
    /// gets NO transitional wrapper: its only caller anywhere is `applySelectionReplaceOutcome`
    /// below, which this task converts, so a deprecated `-> Void` twin would be dead on arrival and
    /// Task 36c would inherit it only to delete it.
    func applyMultiRegionClearOutcome(globalFrom: Int, globalTo: Int, text: String) -> RichTextInputCaretOutcome {
        let lo = clampGlobal(min(globalFrom, globalTo))
        let hi = clampGlobal(max(globalFrom, globalTo))
        guard lo < hi else { return .unchanged }
        // The region owning selFrom is where replacement text lands (it may be empty, hence not in
        // `touched`). Capture its attrs before any clearing mutates it.
        let anchorRegion = leafRegion(containingGlobal: lo)
        let insertAttrs = anchorRegion.map { typingAttributeDict(region: $0.region, atLocal: $0.local) } ?? [:]
        let touched: [(region: LeafTextRegion, rLo: Int, rHi: Int)] = allLeafRegions().compactMap { r in
            let a = max(lo, r.globalStart), b = min(hi, r.globalStart + r.length)
            guard a < b else { return nil }
            return (r, a - r.globalStart, b - r.globalStart)
        }
        var insertedIntoAnchor = false
        for t in touched {
            let isAnchor = (anchorRegion?.region.layout) === t.region.layout
            let s = isAnchor ? text : ""
            let attrs: [NSAttributedString.Key: Any] = isAnchor ? insertAttrs : [:]
            t.region.layout.replace(start: t.rLo, end: t.rHi, with: NSAttributedString(string: s, attributes: attrs))
            if isAnchor { insertedIntoAnchor = true }
        }
        // The selFrom region had no covered text (e.g. an empty start cell), so it wasn't cleared
        // above — insert `text` there directly so the keystroke isn't lost.
        if !insertedIntoAnchor, !text.isEmpty, let a = anchorRegion {
            a.region.layout.replace(start: a.local, end: a.local,
                                    with: NSAttributedString(string: text, attributes: insertAttrs))
        }
        recomputeSpans()
        // selFrom's region start is unaffected by the edit (nothing before lo changed), so this is
        // valid post-recompute. With no owning region (range in a structural gap), just collapse to lo.
        let caret = anchorRegion.map { $0.region.globalStart + $0.local + (text as NSString).length } ?? clampGlobal(lo)
        return .caret(at: caret)
    }

    /// True if `pos` is inside a table (its owning top-level box is a `TableBlockBox`).
    func isInsideTable(_ pos: Int) -> Bool {
        return owningTable(pos) != nil
    }

    /// The `TableBlockBox` whose leaf regions contain `pos`, or nil if `pos` is not inside any table.
    func owningTable(_ pos: Int) -> TableBlockBox? {
        func find(_ stack: [CanvasBlock]) -> TableBlockBox? {
            for box in stack {
                if let table = box as? TableBlockBox {
                    for r in table.leafRegions() where pos >= r.globalStart && pos <= r.globalStart + r.length { return table }
                } else if let d = box as? DetailsBox {
                    if let hit = find(d.children.boxes) { return hit }   // a table nested in a details body
                } else if let bq = box as? BlockQuoteBox, !bq.collapsed {
                    if let hit = find(bq.children.boxes) { return hit }   // a table nested in a quote body
                }
            }
            return nil
        }
        return find(boxes)
    }

    /// True when `[a, b]` is a PARTIAL selection within a SINGLE table — both endpoints in the same table AND the
    /// range does NOT cover the table's entire content (first leaf region → last leaf region). The Select-All →
    /// empty-paragraph reset skips this case so a partial cross-cell delete keeps its per-cell clear behavior
    /// (clear the covered cells, keep the table). A selection that covers the table's WHOLE content — a genuine
    /// Select-All of a lone/all-table document — is NOT partial, so it resets to an empty paragraph like any other
    /// whole-document select; likewise a selection that also covers non-table content (owningTable == nil at an
    /// endpoint) is not "within one table" and resets.
    func isPartialSelectionWithinOneTable(_ a: Int, _ b: Int) -> Bool {
        let lo = clampGlobal(min(a, b)), hi = clampGlobal(max(a, b))
        guard let ta = owningTable(lo), let tb = owningTable(hi), ta === tb else { return false }
        let regions = ta.leafRegions()
        if let first = regions.first, let last = regions.last,
           lo <= first.globalStart, hi >= last.globalStart + last.length {
            return false   // covers the table's whole content → a full-table select, let it reset
        }
        return true
    }

    /// True if `pos` is inside a block-quote container (its owning top-level box is a `BlockQuoteBox`).
    /// Mirrors `isInsideTable` over `BlockQuoteBox` leaf regions. Because `BlockQuoteBox.leafRegions()`
    /// recurses into nested quotes, checking the top-level `BlockQuoteBox`es is sufficient.
    func isInsideBlockQuote(_ pos: Int) -> Bool {
        for box in boxes where box is BlockQuoteBox {
            for r in box.leafRegions() where pos >= r.globalStart && pos <= r.globalStart + r.length { return true }
        }
        return false
    }

    /// Every `BlockBox` whose text span overlaps the current selection, INCLUDING boxes nested in a detail
    /// block's body — so paragraph-style / list operations apply inside a details body, not only at top level.
    /// (Block quotes and table cells are intentionally NOT descended here; those stay top-level-only for these
    /// operations in v1.)
    func selectedBlockBoxes() -> [BlockBox] {
        let lo = min(selFrom, selTo), hi = max(selFrom, selTo)
        var result: [BlockBox] = []
        func walk(_ stack: [CanvasBlock]) {
            for b in stack {
                if let p = b as? BlockBox {
                    let bLo = p.textStart, bHi = p.textStart + p.textLength
                    if lo <= bHi && hi >= bLo { result.append(p) }
                } else if let d = b as? DetailsBox {
                    walk(d.children.boxes)
                }
            }
        }
        walk(boxes)
        return result
    }

    /// Every box in document order, recursing into details + expanded block-quote bodies (NOT table cells —
    /// a `TableBackingView` owns its cell content). Matches `reconcileBlockViews`' descent, so the per-block
    /// sync passes (list markers, media, checkbox views) cover the same nested boxes that get backing views.
    func allBoxesRecursive() -> [CanvasBlock] {
        var result: [CanvasBlock] = []
        func walk(_ stack: [CanvasBlock]) {
            for b in stack {
                result.append(b)
                if let d = b as? DetailsBox { walk(d.children.boxes) }
                else if let bq = b as? BlockQuoteBox, !bq.collapsed { walk(bq.children.boxes) }
            }
        }
        walk(boxes)
        return result
    }

    /// The `BlockStack` (and the index within it) that DIRECTLY contains the box with `id`, recursing into
    /// details / expanded block-quote bodies (NOT table cells — a cell rebuild is a separate path). Lets the
    /// by-blockID media mutators splice a rebuilt box into its OWN stack, so an image/album action works on a
    /// media block nested in a container, not only at top level. `stack.boxes[index]` is the found box.
    func owningStack(ofBlockID id: BlockID) -> (stack: BlockStack, index: Int)? {
        func search(_ stack: BlockStack) -> (stack: BlockStack, index: Int)? {
            for (i, b) in stack.boxes.enumerated() {
                if b.id == id { return (stack, i) }
                if let d = b as? DetailsBox, let r = search(d.children) { return r }
                else if let bq = b as? BlockQuoteBox, !bq.collapsed, let r = search(bq.children) { return r }
            }
            return nil
        }
        return search(root)
    }

    /// True if `pos` is inside a detail (folding) block (its owning top-level box is a `DetailsBox`).
    /// Mirrors `isInsideBlockQuote`; `DetailsBox.leafRegions()` recurses into nested detail blocks, so
    /// checking the top-level `DetailsBox`es is sufficient.
    func isInsideDetails(_ pos: Int) -> Bool {
        for box in boxes where box is DetailsBox {
            for r in box.leafRegions() where pos >= r.globalStart && pos <= r.globalStart + r.length { return true }
        }
        return false
    }
}

@available(iOS 13.0, *)
extension DocumentCanvasView {
    /// The single legacy entry point every semantic mutation intent lands on. Each case dispatches
    /// to the primitive the corresponding UIKit witness uses today, so behavior is identical.
    ///
    /// ⚠️ RECURSION HAZARD — every case must dispatch to the LEGACY BODY, never to the UIKit
    /// witness of the same name. **As of TASK 29 every witness-backed case is routed**, so every one of
    /// them names a `legacy…` body below (`legacyInsertText`, `legacyDeleteBackward`,
    /// `legacySetMarkedText`, `legacyUnmarkText`); no case is left pointing at a witness. A FUTURE task
    /// that adds a witness-backed case here must rename that witness's body and point the case at the
    /// renamed body IN THE SAME COMMIT. Miss it and the cycle is
    ///
    ///     canvas.insertText → backend.insertText → document.commitPreparedMutation
    ///       → canvas.legacyApplyMutation → canvas.insertText → …
    ///
    /// which recurses until the stack dies — and the router-spy tests would still pass, because
    /// the spy backend never reaches the real document client.
    ///
    /// **TASK 27a — TWO CORRECTIONS to the paragraph above, both measured.** (1) The cycle does NOT
    /// recurse until the stack dies: `prepareAndRun`'s `guard transactionPhase == .idle`
    /// (`LegacyRichTextInputBackend+Mutation.swift`) rejects the re-entrant call at depth 2, while the
    /// phase is `.mutatingDocument`. What you get is a `RichTextInputContractViolation` — a DEBUG
    /// `assertionFailure` when no reporter is installed — and a keystroke that silently vanishes, not a
    /// stack overflow. (2) Consequently a `documentCommit` COUNT cannot detect the cycle either (it
    /// stays at 1); only the companion `documentRevision == before + 1` assertion can.
    ///
    /// **TASK 27b — `.insertText` now dispatches to `legacyInsertText(_:)`.** The witness was routed
    /// (as a PLAIN D24 forward, per the user's D35 ruling), and this case was repointed in the same
    /// commit. Note the repoint is NOT what prevents a cycle here: a plain forward never re-enters
    /// `legacyApplyMutation`, so there is no recursion to break. It is required because of this
    /// method's own rule — every case dispatches to the LEGACY BODY, never to the UIKit witness of the
    /// same name — and because leaving it on the witness would bounce the dispatcher out through the
    /// backend and back for nothing, silently dropping the mutation whenever `legacyCanvas` is nil.
    /// **TASK 28 — `.deleteBackward` now dispatches to `legacyDeleteBackward()`,** for exactly the same
    /// reasons and with the same non-reason: the witness was routed as a plain D24 forward, so there is
    /// no recursion to break here either; the repoint is required by this method's own rule (every case
    /// dispatches to the LEGACY BODY, never to the UIKit witness of the same name) and because leaving
    /// it on the witness would bounce the dispatcher out through the backend and back for nothing,
    /// silently dropping the mutation whenever `legacyCanvas` is nil.
    /// **TASK 29 — `.setMarkedText` now dispatches to `legacySetMarkedText(_:selectedRange:)` and
    /// `.unmarkText` to `legacyUnmarkText()`,** closing the last two, for exactly the same reasons and
    /// with the same non-reason: both witnesses were routed as plain D24 forwards, so there is no
    /// recursion to break here either; the repoint is required by this method's own rule and because
    /// leaving either on its witness would bounce the dispatcher out through the backend and back for
    /// nothing, silently dropping the mutation whenever `legacyCanvas` is nil.
    ///
    /// (Was a `TODO(Task 26)` saying `editing { }` still emits the `UITextInputDelegate` bracket
    /// itself. **Task 26 landed**: `editing { }` now goes through
    /// `inputBackend.notifyingContentAndSelectionChange`, and rule R16 makes the backend the package's
    /// only emitter. Corrected by Task 27a, which found the note still promising a future state.)
    func legacyApplyMutation(_ mutation: RichTextInputMutation)
        -> (revision: UInt64, anchor: Int, head: Int, markedRange: NSRange?,
            affectedRange: NSRange?, contentChanged: Bool) {
        let revisionBefore = documentRevision
        var affected: NSRange?
        switch mutation {
        case .insertText(let text, let replacing, _):
            let r = replacing.normalizedRange
            affected = NSRange(location: r.location, length: (text.string as NSString).length)
            inputBackend.setCanonicalAnchor(r.location)
            inputBackend.setCanonicalHead(r.location + r.length)
            legacyInsertText(text.string)        // TASK 27b routed the witness and repointed this case
                                                 // at the renamed body in the same commit — see the
                                                 // ⚠️ note above.
        case .insertParagraphBreak(let replacing, _):
            let r = replacing.normalizedRange
            inputBackend.setCanonicalAnchor(r.location)
            inputBackend.setCanonicalHead(r.location + r.length)
            affected = NSRange(location: r.location, length: 1)
            editing { insertParagraphBreak(); return .unchanged }   // a structural primitive, not a witness — never renamed
        case .replaceText(let range, let text, _):
            affected = NSRange(location: range.location, length: (text.string as NSString).length)
            editing { applySelectionReplaceOutcome(globalFrom: range.location,
                                                                  globalTo: range.location + range.length,
                                                                  text: text.string) }   // primitive, not a witness
        case .deleteBackward(let selection, _):
            let r = selection.normalizedRange
            inputBackend.setCanonicalAnchor(r.location)
            inputBackend.setCanonicalHead(r.location + r.length)
            legacyDeleteBackward()               // TASK 28 routed the witness and repointed this case
                                                 // at the renamed body in the same commit — see the
                                                 // ⚠️ note above.
            affected = NSRange(location: min(head, r.location), length: 0)
        case .deleteForward(let selection, _):
            // No forward-delete primitive exists; UIKit never sends it to this canvas today.
            let r = selection.normalizedRange
            affected = NSRange(location: r.location, length: 0)
        case .setBaseWritingDirection:
            break   // deliberate no-op, mirroring +UITextInput.swift:232
        case .setMarkedText(let text, let replacing, let selectedRangeInMarkedText):
            inputBackend.setCanonicalAnchor(replacing.location)
            inputBackend.setCanonicalHead(replacing.location + replacing.length)
            legacySetMarkedText(text.string, selectedRange: selectedRangeInMarkedText)
                                                 // TASK 29 routed the witness and repointed this case
                                                 // at the renamed body in the same commit — see the
                                                 // ⚠️ note above.
            affected = markedRange.map { NSRange(location: $0.from, length: $0.to - $0.from) }
        case .unmarkText:
            legacyUnmarkText()                   // TASK 29 routed the witness and repointed this case
                                                 // at the renamed body in the same commit — see the
                                                 // ⚠️ note above.
        }
        return (revision: documentRevision, anchor: anchor, head: head,
                markedRange: markedRange.map { NSRange(location: $0.from, length: $0.to - $0.from) },
                affectedRange: affected,
                contentChanged: documentRevision != revisionBefore)
    }
}
#endif
