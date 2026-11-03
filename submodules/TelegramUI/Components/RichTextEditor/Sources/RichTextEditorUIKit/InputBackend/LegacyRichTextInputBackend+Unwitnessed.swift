#if canImport(UIKit)
import UIKit

/// **TASK 34 RENAMED THIS FILE** from `LegacyRichTextInputBackend+PendingRouting.swift`, and the rename
/// is the whole statement: **there is no pending routing left.** The `pendingRouting(_:)` funnel and the
/// `pendingRoutingInventory` Set are both DELETED; what survives is what the file always also held and
/// what its old name never described — the two PERMANENTLY UNWITNESSED members (deviation D15,
/// `textStyling(at:in:)` and `insertDictationResult(_:)`) — plus one test-recording array and the
/// Phase-4 routing ledger below.
///
/// **The instruction this task was given was "delete the whole file", and it was wrong in three places
/// at once — which is the reusable lesson.** R13's doc comment (Core source-boundary suite),
/// `BackendAttachmentTests.test_everyPendingRoutingStubNamesTheTaskThatDeletesIt`'s doc comment, and
/// Task 33's closing handoff all said Task 34 removes the funnel "along with the whole
/// `+PendingRouting.swift` file". Measured, the file still held two real members with real bodies (one
/// with ~40 lines of adjudicated doc comment), a widely-used test-recording array, and this ledger. Each
/// of the three statements was written by someone reading one of the other two. **A statement repeated
/// in three places is not corroborated; it may just be copied.** What was dead was the FUNNEL, not the
/// file — so the funnel is gone, the Set is gone, the name no longer claims otherwise, and nothing was
/// discarded that a reader still needs.
///
/// **What is gone, precisely.**
///   * `func pendingRouting(_:)` — the funnel. It had ZERO call sites when this task began (Task 33
///     routed the last stubbed family), so deleting it removed no behaviour at all.
///   * `static let pendingRoutingInventory` — EMPTY since Task 33, and after this task it has no reader
///     anywhere: R13 is deleted (see R20, its successor), and the two router suites that asserted
///     `!inventory.contains(member)` were asserting against an empty Set, i.e. asserting nothing.
///     Keeping an empty Set that nothing reads is the "reads as enforcement, enforces nothing" shape
///     this project has now paid for three times.
///
/// **What replaced them**: rule R20 in the Core source-boundary suite
/// (`test_noPendingRoutingResidueRemains_R20` — renamed at Task 34's fix round 1, when the review
/// proved that the name it shipped with, `test_phase4IsOver…`, claimed more than the rule checks:
/// reverting real routing call sites left it GREEN. It checks RESIDUE; the per-family suites in
/// `T/InputBackend/Routers/` are what check that a family routes), which asserts the ABSENCE of a funnel
/// call site, of the inventory identifier, and of the per-stub `routed in Task` comment marker across
/// EVERY file under `S/InputBackend/`. That states **the residue is gone** as a property of the source
/// rather than of a Set someone could repopulate, and — unlike an `inventory.isEmpty` assertion — it
/// survives the property being deleted and cannot pass by finding nothing. **It does NOT state that
/// Phase 4 finished** — its first name claimed that and its fix round retracted it, because reverting a
/// real routing call site leaves it green. What a family ROUTES is the per-family suites' job
/// (`T/InputBackend/Routers/`), plus `RouterWitnessBodyTests` and R17.
///
/// # The Phase-4 routing ledger (historical)
///
/// Everything below this line is the record of how Tasks 24-34 emptied the routing table, kept verbatim.
/// `LegacyRichTextInputBackend` must satisfy every `RichTextInputBackend` sub-protocol — FOUR while
/// this ledger was being written; **FIVE since Task 34 added `RichTextInputCheckingBackend`**
/// (deviation D37), because Family 11 has no UIKit witness and its canvas-side call sites could not
/// otherwise reach the backend. The four this ledger's accounting covers
/// (`RichTextInputTextBackend`, `RichTextKeyInputBackend`, `RichTextInputResponderBackend`,
/// `RichTextInputInteractionBackend`) had to be satisfied from the moment the conformance was declared
/// (Task 20), but the real bodies landed one witness family at a time in Tasks 24-34. Each stub carried a
/// `routed in Task NN` comment marker naming the task that deleted it. (Both mentions on this page
/// deliberately omit the marker's leading slashes: R20 scans for the marker in RAW text — it has to,
/// since the stripper blanks comments — so a doc comment quoting it verbatim would trip the rule that
/// this file's own emptiness is the subject of.)
///
/// Members are emitted in the SAME ORDER the sub-protocols declare them
/// (`RichTextInputBackend.swift`), so a diff against that file stays trivial. That physical order does
/// NOT match the "deleted by" grouping below — protocol declaration interleaves `Selection & delegate` /
/// `Marked text` / `Document` members — so the grouping is documented here instead of via file layout:
///
/// | Section                      | Members                                                                                                                   | Deleted by |
/// | ----------------------------- | -------------------------------------------------------------------------------------------------------------------------- | ---------- |
/// | Document reads & conversion   | `text(in:)`, `beginningOfDocument`, `endOfDocument`, `tokenizer`, `textRange(from:to:)`, `position(from:offset:)`, `position(from:in:offset:)`, `compare(_:to:)`, `offset(from:to:)`, `position(within:farthestIn:)`, `characterRange(byExtending:in:)` | Task 24 |
/// | (`hasText` — the Task-24 brief's authoritative eleven-witness list excluded it; TASK 27a ROUTED IT, see below.) | `hasText` | — (routed) |
/// | Geometry                      | `caretRect(for:)`, `firstRect(for:)`, `selectionRects(for:)`, `closestPosition(to:)`, `closestPosition(to:within:)`, `characterRange(at:)`, `baseWritingDirection(for:in:)`, `setBaseWritingDirection(_:for:)`              | Task 25 |
/// | Selection & delegate          | `inputDelegate` (`selectedTextRange` got a real body early — see below)                                                    | Task 26 |
/// | Insertion                     | (`replace(_:withText:)` — TASK 27a ROUTED IT; `insertText(_:)` — TASK 27b ROUTED IT, as a plain `legacyCanvas` forward per deviation D35: see `+Insertion.swift`'s header) | — (routed) |
/// | Deletion                      | (`deleteBackward()` — TASK 28 ROUTED IT, as a plain `legacyCanvas` forward per deviation D35: see `+Deletion.swift`'s header) | — (routed) |
/// | Marked text                   | (`markedTextRange`, `markedTextStyle`, `setMarkedText(_:selectedRange:)`, `unmarkText()` — TASK 29 ROUTED ALL FOUR; see `+MarkedText.swift`'s header) | — (routed) |
/// | Responder commands            | (`canPerformCommand(_:sender:)`, `performCommand(_:sender:)` — TASK 30 ROUTED BOTH, and added D28's third member `undoManager`; see `+Commands.swift`'s header) | — (routed) |
/// | Responder lifecycle           | (`canBecomeFirstResponder`, `canResignFirstResponder`, the become/resign will/did/did-fail sextet, `hostWillMove(toWindow:)`, `editPolicyDidChange()`, `textInputTraitsDidChange()`, `isEditableForWritingTools` (D3) — TASK 31 ROUTED ALL TWELVE; see `+Responder.swift`'s header) | — (routed) |
/// | Interaction                   | (`installInteractions()`, `removeInteractions()`, `cancelActiveInteraction(reason:)`, `viewportDidChange()`, `layoutDidChange(generation:)` — TASK 32 ROUTED ALL FIVE; see `+Interaction.swift`'s header) | — (routed) |
/// | Floating cursor               | (`beginFloatingCursor(at:)`, `updateFloatingCursor(at:)` (D2), `endFloatingCursor()` — TASK 33 ROUTED ALL THREE; see `+FloatingCursor.swift`'s header) | — (routed) |
/// | Permanently unwitnessed (D15) | `textStyling(at:in:)` → `nil`, `insertDictationResult(_:)` → no-op                                                          | never |
///
/// Three of the interaction stubs were called by TASK 20: `attach(to:)` calls `installInteractions()`,
/// and `performDetachSteps()` calls `cancelActiveInteraction(reason:)` and `removeInteractions()` — as
/// no-ops they made `+Attachment.swift` compile and let `test_detachRunsTheNineStepsInOrder` pass on
/// the steps that WERE implemented. **TASK 32 FILLED THEM IN**, and the consequence for that test is
/// worth recording here rather than only at the test: those two steps stopped writing to
/// `pendingRoutingCalls`, so the sequence it asserted lost two of its four entries and it was re-based
/// onto the canvas effects the routed steps now produce.
///
/// **`insertText(_:)` and `deleteBackward()` were the two exceptions to "every member here is a
/// stub"** — Task 22b (`BackendMutationContractTests`) gave them real bodies ahead of schedule, in
/// `LegacyRichTextInputBackend+Mutation.swift`, because that suite needed something real to pin the
/// prepare/notify/commit/publish contract against using the fake clients. Those bodies build a
/// `RichTextInputMutation` from the backend's own state and run it through the document client rather
/// than forwarding to a `legacy…` canvas hook. **TASK 27b RESOLVED THAT FOR `insertText(_:)`**, under
/// the user's D35 ruling: the member is now a plain `legacyCanvas?.legacyInsertText(text)` forward
/// (`+Insertion.swift`) and the transaction body moved to the TEST-ONLY `ReferenceMutationBackend`
/// (`T/Support/`), which the contract suites build from `makeBackend()`. **TASK 28 RESOLVED IT FOR
/// `deleteBackward()` THE SAME WAY**: the member is now a plain
/// `legacyCanvas?.legacyDeleteBackward()` forward (`+Deletion.swift`), and its transaction body moved
/// to the same conformer. `+Mutation.swift` consequently defines no `RichTextKeyInputBackend` member
/// at all any more — only the machinery both moved bodies run through. Both members remain
/// intentionally absent from `pendingRoutingInventory` below (neither is a stub, and neither ever
/// was — routing them therefore moved no inventory entry and no R13 count).
///
/// **`selectedTextRange`, `beginFloatingCursor(at:)` and `endFloatingCursor()` are three more
/// exceptions**, added by Task 22e for the same reason: `BackendSelectionContractTests` needed
/// something real to pin endpoint identity, the unordered getter, and floating-cursor suppression of
/// the setter against. `selectedTextRange`'s real get/set body now lives on
/// `LegacyRichTextInputBackend` itself (right after `setSelection`, in `LegacyRichTextInputBackend.swift`)
/// rather than here, since it needed the class's stored `floatingCursorActive` (also added by this
/// task) and `canonicalSelectionStorage`. `beginFloatingCursor(at:)`/`endFloatingCursor()` were given
/// MINIMAL real bodies here — set/clear that same flag, nothing else — while `updateFloatingCursor(at:)`
/// stayed a full stub.
///
/// **TASK 33 ROUTED ALL THREE and this file no longer declares any of them.** Their real bodies are in
/// `LegacyRichTextInputBackend+FloatingCursor.swift`: each is a `legacyCanvas` forward onto a renamed
/// witness body, and `begin`/`end` KEEP the flag write (the forward runs first — that order became
/// load-bearing at Task 42, when the canvas guards started reading this flag, and it is now pinned
/// BEHAVIOURALLY: reversing both writes reddens three `FloatingCursorTests` cases. The "no test can
/// currently catch it being reversed" half of this sentence expired with that task; the measurement is
/// in `+FloatingCursor.swift`'s ORDER section). Nothing was re-homed to `ReferenceMutationBackend`:
/// the flag write was not a body to move, it is the member's own remaining half.
///
/// FIX ROUND 1 (review Major 3), kept as the record of WHY the accounting moved the way it did: UNLIKE
/// `insertText(_:)`/`deleteBackward()`/`selectedTextRange` above, `beginFloatingCursor(at:)` and
/// `endFloatingCursor()` were DELIBERATELY KEPT in `pendingRoutingInventory` (only
/// `updateFloatingCursor(at:)` was ever a bare stub), so that Task 33 could not read their absence as
/// "already finished" and skip the forward. It did not: entries −3, call sites −1, exceptions −2, and
/// the inventory is now EMPTY.
///
/// **`markedTextRange` and `setMarkedText(_:selectedRange:)` WERE two more exceptions**, added by Task
/// 22f for the same reason: `BackendMarkedTextPolicyTests` needed a real `markedRangeStorage` to pin
/// the three `synchronizeAfterExternalChange` marked-text policies against. Both moved to
/// `LegacyRichTextInputBackend.swift`'s own "Marked text" section (same rationale as
/// `selectedTextRange`'s move above: they read/write the class's stored `markedRangeStorage` and
/// `canonicalSelectionStorage`). LIKE `beginFloatingCursor(at:)`/`endFloatingCursor()`, these two were
/// DELIBERATELY KEPT in `pendingRoutingInventory` below rather than excluded like
/// `insertText(_:)`/`deleteBackward()`/`selectedTextRange` — their bodies were storage-only (no
/// document-client interaction, no delegate bracket, no undo, no body-paragraph guard, no
/// prediction-vs-composition distinction), so Task 29's real `legacyCanvas` forward was still ALL of
/// its own job, not a replacement of an already-complete body.
///
/// **TASK 29 LANDED, and that reasoning is why the accounting differs from 27b's and 28's.** All four
/// marked-text members are now plain `legacyCanvas` forwards in
/// `LegacyRichTextInputBackend+MarkedText.swift`, and the two storage-only bodies moved VERBATIM to
/// the test-only `ReferenceMutationBackend` (`T/Support/`) that `BackendMarkedTextPolicyTests` now
/// runs against — the same re-homing 27b/28 performed. But where routing `insertText(_:)`/
/// `deleteBackward()` moved NO inventory entry (they were never listed), routing these moved THREE:
/// `markedTextRange` and `setMarkedText(_:selectedRange:)` because the paragraph above had kept them
/// deliberately, and `unmarkText()` — which was untouched by 22f and stayed a full, unmodified stub
/// until now — because its `pendingRouting()` call site went with it. R13's hardcoded exception list
/// dropped from five names to three in the same commit. `markedTextStyle` was never in the inventory
/// at all (a stored property has nothing to record) and Task 29 deleted that storage; see its note in
/// `LegacyRichTextInputBackend.swift`.
///
/// **TASK 30 LANDED for the responder-command family.** `canPerformCommand(_:sender:)` and
/// `performCommand(_:sender:)` are real bodies in `LegacyRichTextInputBackend+Commands.swift`, and both
/// inventory entries plus both `pendingRouting()` call sites are gone. Unlike Tasks 27b/28/29 NOTHING
/// was re-homed to `ReferenceMutationBackend`: neither member ever carried a transaction or a storage
/// body to move — `canPerformCommand`'s Task-22i `.paste` case was a QUERY, and it survives verbatim
/// inside the real member as its `guard` prelude. Five canvas witness BODIES were renamed instead
/// (`legacyCopy`/`legacyCut`/`legacyPaste`/`legacySelect`/`legacySelectAll`), which is the Family-4-6
/// shape. The paragraph below therefore now describes only TWO of Task 22i's three members.
///
/// **TASK 31 LANDED for the responder-lifecycle family, and its accounting has one wrinkle worth
/// naming.** Eleven of its twelve members were ordinary stubs: entry -1 and `pendingRouting()` call
/// site -1 each, so R13's reconciliation moves in step. The TWELFTH, `editPolicyDidChange()`, was NOT
/// a stub — Task 22i gave it a real body (below, and now in `+Responder.swift`) and DELIBERATELY KEPT
/// its inventory entry, deferring to Task 31 the question of whether this member needed anything else.
/// It did not, so Task 31 removed the entry — **and R13 hardcodes `"editPolicyDidChange()"` in its own
/// `exceptions` array, asserting BOTH that the exception is still a quoted inventory entry AND that
/// `entryCount == callSiteCount + exceptions.count`. Removing it from one side only fails; both moved
/// in the same commit.** R13's exception list went from three names to two there (and to ZERO at Task
/// 33, which routed both survivors — R13's own doc comment carries that ending). Unlike
/// Tasks 27b/28/29, NOTHING was re-homed to `ReferenceMutationBackend`: no member of this family ever
/// carried a transaction or a storage body to move. Six canvas witness BODIES were renamed instead
/// (`legacyDidBecomeFirstResponder`, `legacyMarkDidJustBecomeFirstResponder`,
/// `legacyFinishBecomingFirstResponder`, `legacyWillResignFirstResponder`,
/// `legacyDidResignFirstResponder`, `legacyWillMove(toWindow:)`) — six, not the three the task brief
/// named, because two segment boundaries in `becomeFirstResponder()`'s body are load-bearing and
/// `willMove(toWindow:)`'s hook was simply unlisted. `+Responder.swift`'s header has the measurement.
///
/// **`editPolicyDidChange()`, `canPerformCommand(_:sender:)`, and `insertDictationResult(_:)` gained
/// MINIMAL real bodies from Task 22i** (`BackendEditPolicyTests`, the per-operation edit-policy
/// gate), same "ahead of schedule, only what the pinning suite needs" shape as every exception above.
/// `editPolicyDidChange()` USED TO STAY in `pendingRoutingInventory` deliberately (its own doc comment
/// explained why); TASK 31 ANSWERED the question that entry was holding open and removed it, along
/// with the whole member — body and doc comment — to `+Responder.swift`. `canPerformCommand(_:sender:)`
/// kept, AS OF TASK 22i, its `pendingRouting()` call and its inventory entry for every command OTHER
/// than `.paste` — only that one case gained a real, policy-gated body, and `performCommand(_:sender:)`
/// was untouched. (Both statements are historical: Task 30 routed both members, as its own paragraph
/// above records.) `insertDictationResult(_:)` is a
/// separate case: it is NOT in `pendingRoutingInventory` at all (D15 already declared it a permanent,
/// finished body, alongside `textStyling(at:in:)`) — Task 22i does not reopen D15's "never" or give
/// this member the real canvas-forwarding effect D15 permanently withholds; it only adds a policy
/// rejection REPORT on the `allowsDictation == false` path, still never touching the document client
/// or `legacyCanvas` either way (see that member's own doc comment, in the D15 section below).
@available(iOS 13.0, *)
extension LegacyRichTextInputBackend {
    /// **TASK 34 DELETED `pendingRouting(_:)`, the funnel this array was named for**, so NO PRODUCTION
    /// CODE WRITES HERE ANY MORE. The array is kept, and deliberately NOT renamed: it is now a plain
    /// shared recording buffer that the UIKit test target appends to from its own fixtures
    /// (`BackendAttachmentTests`' five fake-client hooks write it and one test reads it back as an
    /// ordering trace), and renaming it would churn ~8 test call sites to say the same thing this
    /// comment says in one place.
    ///
    /// **What that means for anyone writing an assertion against it**: "driving member X records no
    /// `pendingRouting()` call" is no longer a checkable claim — it is true by construction, because the
    /// function it names does not exist. Two suites had exactly that assertion and both are deleted;
    /// see R20 (Core source-boundary suite) for the successor, which checks the SOURCE instead.
    static var pendingRoutingCalls: [String] = []

    // ─────────────────────────────────────────────────────────────────────────────────────────────
    // THE PHASE-4 INVENTORY LEDGER — `static let pendingRoutingInventory: Set<String>` STOOD HERE and
    // was DELETED BY TASK 34 (it had been empty since Task 33 and had no remaining reader). Its
    // per-family accounting notes are kept verbatim below, because they are the only record of HOW the
    // table emptied — which entry moved with a call site, which moved without one, and which was a
    // deliberate keep. Nothing below is live code; a future task adding a routing table starts a new
    // one rather than resurrecting this.
    // ─────────────────────────────────────────────────────────────────────────────────────────────
        // Document reads & conversion — Task 24 routed everything in this section EXCEPT `hasText`,
        // which the Task-24 brief's authoritative eleven-witness list deliberately excluded. TASK 27a
        // ROUTED `hasText`: its real body now lives in `LegacyRichTextInputBackend+Insertion.swift`
        // (through `RichTextInputDocumentClient.utf16Length`), so its entry — and its stub below — are
        // gone, mirroring how Task 24 removed its own eleven.
        // Geometry — Task 25 ROUTED. The eight members formerly listed here
        // (`caretRect(for:)`, `firstRect(for:)`, `selectionRects(for:)`, `closestPosition(to:)`,
        // `closestPosition(to:within:)`, `characterRange(at:)`, `baseWritingDirection(for:in:)`,
        // `setBaseWritingDirection(_:for:)`) are no longer stubs here — their real bodies now live in
        // `LegacyRichTextInputBackend+Geometry.swift`, mirroring how Task 24 removed its eleven from
        // this Set. See that file's own header comment for the routing shapes/deviations.
        // Insertion — TASK 27a ROUTED `replace(_:withText:)`; its real body (a plain D24 forward onto
        // `legacyReplace(globalFrom:globalTo:text:)`, no bracket) is in
        // `LegacyRichTextInputBackend+Insertion.swift`, so its entry and its stub below are gone.
        //
        // `insertText(_:)` was given a REAL body ahead of schedule by Task 22b
        // (`LegacyRichTextInputBackend+Mutation.swift`), so BackendMutationContractTests would have
        // something to pin against the fake clients. It is NOT in this inventory (it is no longer a
        // stub) and **TASK 27b ROUTED IT** — as a plain `legacyCanvas?.legacyInsertText(text)` forward
        // (`+Insertion.swift`), under the user's D35 ruling. Task 27's measurement stands and is why
        // the shape is a forward rather than the document-client transaction: routing the witness onto
        // that transaction makes typing a silent no-op, and no repair reconciles `runMutation`'s fixed
        // four-notification bracket with the witness's per-branch one. The transaction body moved to
        // the test-only `ReferenceMutationBackend` (`T/Support/`). Routing it moved NO entry here and
        // no R13 count, because it was never a stub.
        // Deletion — TASK 28 ROUTED `deleteBackward()`.
        //
        // It was likewise given a real body ahead of schedule by Task 22b, for the same reason as
        // `insertText(_:)` above, so it was never in this inventory and never had a `pendingRouting()`
        // call site. **Task 28 routed it as a plain `legacyCanvas?.legacyDeleteBackward()` forward**
        // (`+Deletion.swift`), under the same D35 ruling and for the same measured reason; the
        // transaction body moved to the test-only `ReferenceMutationBackend` (`T/Support/`). Routing it
        // moved NO entry here and no R13 count, because it was never a stub — exactly like 27b.
        // Marked text — TASK 29 ROUTED THE WHOLE FAMILY, so this group is empty.
        //
        // It held THREE entries. `markedTextRange`/`setMarkedText(_:selectedRange:)` were here on the
        // "kept, not excluded" footing `beginFloatingCursor(at:)`/`endFloatingCursor()` WERE ON UNTIL
        // TASK 33 ROUTED THEM (this file's header no longer describes them as kept, so the present
        // tense that used to stand here forward-referenced a claim that is gone): they recorded no stub
        // call, because Task 22f had given them
        // storage-only bodies, but Task 29's real `legacyCanvas` forward was still its own complete
        // job rather than a stub deletion — which is exactly what happened, so both entries are gone.
        // `unmarkText()` was a genuine, unmodified stub and its `pendingRouting()` call site went with
        // it. `markedTextStyle` was NEVER in this list (a stored property has nothing to record) and
        // Task 29 deleted that storage too. The reasoning is preserved rather than the entries: a
        // future reader looking for why three names vanished at once finds it here.
        // Responder commands — TASK 30 ROUTED THE WHOLE FAMILY, so this group is empty.
        //
        // It held TWO entries, and BOTH were genuine stub call sites, so entries -2 and call sites -2
        // and R13's reconciliation still balances with no change to its hardcoded exception list.
        // `canPerformCommand(_:sender:)` is the nearest thing this family had to an ahead-of-schedule
        // body — Task 22i gave its `.paste` case a real, policy-gated answer — but the OTHER seven
        // commands still ran `pendingRouting()` and returned `false`, so it was a stub on every path
        // that mattered and stayed listed. Task 30 kept that `.paste` gate verbatim (as a `guard`
        // prelude, so rule R17 can see the member as a guard-plus-one-statement forward) and gave
        // every other command a real client answer. `performCommand(_:sender:)` was a bare stub. Both
        // real bodies now live in `LegacyRichTextInputBackend+Commands.swift`, together with the third
        // member of the family, `undoManager` (D28's third member, added by Task 30 — never a stub, so
        // it was never in this list).
        // Responder lifecycle — TASK 31 ROUTED THE WHOLE FAMILY, so this group is empty.
        //
        // It held TWELVE entries. ELEVEN were genuine stub call sites, so entries -11 and call sites
        // -11 and R13's reconciliation balances with no change on their account. The twelfth,
        // `editPolicyDidChange()`, was the deliberate keep this file's header describes: a real Task-22i
        // body with NO `pendingRouting()` call, listed only to hold open the question "does Task 31 need
        // to add anything else to this member". The answer was no, so its entry went too — and because
        // R13 hardcodes that name in its own `exceptions` array AND asserts the name is still a quoted
        // entry here, both sides had to move together or the rule fails. That took R13's exception list
        // to `beginFloatingCursor(at:)`/`endFloatingCursor()` alone — and TASK 33 routed both, so it is
        // now EMPTY; see R13's own doc comment for what that retires and what was kept.
        //
        // `canBecomeFirstResponder`/`canResignFirstResponder`/`isEditableForWritingTools` are worth a
        // sentence of their own: their stubs returned `false`, but every one of them now answers `true`,
        // because `true` is what the witnesses they replaced answered. A routed member is not obliged to
        // agree with the stub it deletes — it is obliged to agree with the WITNESS.
        // Interaction — TASK 32 ROUTED THE WHOLE FAMILY, so this group is empty.
        //
        // It held FIVE entries — `installInteractions()`, `removeInteractions()`,
        // `cancelActiveInteraction(reason:)`, `viewportDidChange()`, `layoutDidChange(generation:)` —
        // and every one was a genuine `pendingRouting()` call site, so entries −5 and call sites −5 and
        // R13's reconciliation balances with no change to its hardcoded exception list (which Task 31
        // already took down to `beginFloatingCursor(at:)`/`endFloatingCursor()` alone). This is the
        // plain shape Task 30 had, not Task 31's `editPolicyDidChange()` wrinkle: none of the five had
        // a real body, ahead of schedule or otherwise.
        //
        // Worth one sentence because a reader will look for it here: the task brief also listed FOUR
        // canvas members as part of this family (`gestureRecognizerShouldBegin(_:)`,
        // `gestureRecognizer(_:shouldReceive:)`, `selectionContainerViewBelowText(for:)`, the
        // `UIEditMenuInteractionDelegate` conformance). They were never in this inventory because they
        // were never contract members, and DEVIATION D36 records why they cannot become ones — two of
        // the four take iOS-16/17 UIKit types, and hard invariant 12 bans an `@available` gate above
        // iOS 13 on a protocol requirement. They stay on the canvas, unrouted.
        // Floating cursor — TASK 33 ROUTED THE WHOLE FAMILY, so this group is empty. **AND SO IS THE
        // WHOLE SET: this is the task at which `pendingRoutingInventory` reaches zero entries and this
        // file's last `pendingRouting()` call site disappears.**
        //
        // It held THREE entries. ONE, `updateFloatingCursor(at:)`, was a genuine `pendingRouting()`
        // call site. The other TWO were the deliberate keeps this file's header describes — Task 22e
        // gave them minimal flag-only bodies with no `pendingRouting()` call and listed them anyway, so
        // that their remaining `legacyCanvas` forward could not be mistaken for finished work. Both were
        // ALSO the two names hardcoded in rule R13's own `exceptions` array, which asserts they are
        // still quoted entries here — so all three sides (this Set, that array, the call site) moved in
        // one commit. Entries −3, call sites −1, exceptions −2.
        //
        // **Two consequences of the Set reaching zero, both handled at R13 rather than here** (see
        // `test_pendingRoutingInventoryCountMatchesTheFileItDescribes_R13`, Core source-boundary suite):
        // its `exceptions` array is now empty, and its `callSiteCount > 0` vacuity guard — written when
        // a nonzero count was the only evidence the scan was reading real code — would have FAILED on a
        // count that is now legitimately zero. R13's doc comment predicted its own death at Task 34
        // (when the funnel function goes with this file) and was one task out. **TASK 34 CORRECTED IT
        // AGAIN**: the funnel went, but the file did not — see this file's header.
        // ─────────────────────────── end of the Phase-4 inventory ledger ───────────────────────────
}

// MARK: - RichTextInputTextBackend

@available(iOS 13.0, *)
extension LegacyRichTextInputBackend {
    // `inputDelegate` / `selectedTextRange` / the lazy `tokenizer` backing are STORED — Swift
    // extensions cannot declare stored properties, so despite conceptually belonging to this file's
    // routing table (Selection & delegate group, deleted by Task 26) they are declared on the class
    // itself, in `LegacyRichTextInputBackend.swift`'s "Pending-routing stored witnesses" section.
    // `markedTextStyle` USED to be in that list; TASK 29 routed it and DELETED the storage (routing a
    // `get { nil } set { }` witness onto a stored property would change its behaviour).
    //
    // TASK 24 REMOVED eleven stubs from this file (Family 1: document reads & position/range
    // conversion — `tokenizer`, `beginningOfDocument`, `endOfDocument`, `text(in:)`,
    // `textRange(from:to:)`, `position(from:offset:)`, `position(from:in:offset:)`,
    // `compare(_:to:)`, `offset(from:to:)`, `position(within:farthestIn:)`,
    // `characterRange(byExtending:in:)`) — their real bodies now live in
    // `LegacyRichTextInputBackend+TextReads.swift`, not here. `hasText` was a DELIBERATE EXCEPTION:
    // the Task-24 brief's authoritative eleven-witness list excluded it, so it stayed a stub one family
    // longer. **TASK 27a ROUTED IT** — its real body is in
    // `LegacyRichTextInputBackend+Insertion.swift`, alongside `replace(_:withText:)`.

    // TASK 27a REMOVED the `replace(_:withText:)` stub from this file — its real body now lives in
    // `LegacyRichTextInputBackend+Insertion.swift`. Same treatment Tasks 24/25 gave their families.

    // TASK 29 REMOVED the `unmarkText()` stub from this file, and with it the last marked-text entry.
    // `markedTextRange`/`setMarkedText(_:selectedRange:)` had already moved OUT of this file to
    // `LegacyRichTextInputBackend.swift` (Task 22f, storage-only bodies) before Task 29 replaced them
    // with real ones; all four marked-text members — those two plus `markedTextStyle` and
    // `unmarkText()` — now live in `LegacyRichTextInputBackend+MarkedText.swift`.

    // TASK 25 REMOVED eight stubs from this file (Family 2: geometry — `baseWritingDirection(for:in:)`,
    // `setBaseWritingDirection(_:for:)`, `firstRect(for:)`, `caretRect(for:)`, `selectionRects(for:)`,
    // `closestPosition(to:)`, `closestPosition(to:within:)`, `characterRange(at:)`) — their real bodies
    // now live in `LegacyRichTextInputBackend+Geometry.swift`, not here. Same treatment Task 24 gave its
    // own eleven (see that removal's note just above the `RichTextInputTextBackend` extension header).

    /// D15: intentionally unwitnessed — the canvas witnesses neither of these two `UITextInput`
    /// members today (grep: zero hits), so there is nothing to route to. It was never a stub and was
    /// never in the Phase-4 inventory (both of which Task 34 deleted outright) — this is the real,
    /// permanent body.
    func textStyling(at position: UITextPosition, in direction: UITextStorageDirection) -> [NSAttributedString.Key: Any]? {
        nil
    }

    /// D15: intentionally unwitnessed, same rationale as `textStyling(at:in:)` — this body NEVER
    /// reaches the document client or `legacyCanvas`, allowed or not; D15 is permanent and this task
    /// does not un-stub it.
    ///
    /// TASK 22i ADDITION (self-disclosed, not spec-dictated — see `BackendEditPolicyTests
    /// .test_allowsDictationFalse_rejectsInsertDictationResult`): when the CURRENT policy disallows
    /// dictation, report a rejection through the same `backendDidRejectMutation` channel a real
    /// mutation rejection uses — built (the joined phrase text, `origin: .dictation`, the one
    /// `RichTextInputMutationOrigin` case that exists for exactly this member) but NEVER run through
    /// `document.prepareMutation`/`commitPreparedMutation`, mirroring how `prepareAndRun`'s own
    /// rejection branches report an attempted mutation without touching the document client. Reason
    /// `.unsupportedOperation`: no dedicated `RichTextInputMutationRejection` case exists for
    /// "dictation disallowed by policy" and this task adds no case to that enum (Task 11 already
    /// fixed it) — `.unsupportedOperation` is the closest existing fit and is a genuine, disclosed
    /// interpretive choice, not a dictated one. When dictation IS allowed, the member stays exactly
    /// the silent no-op it always was — no report, no document-client touch, matching D15 verbatim.
    ///
    /// FIX ROUND 1 (task-22i-review.md Major 2 / Focal Point 2, disclosed rather than removed):
    /// `.unsupportedOperation` is NOT exclusive to this producer. `TelegramDocumentInputClient
    /// .commitPreparedMutation` (`Clients/TelegramDocumentInputClient.swift`) already emits the same
    /// case for a foreign/already-consumed preparation token. The two do not collide TODAY only
    /// because `runMutation` (`+Mutation.swift`) forwards a `RichTextInputMutationResult.disposition`
    /// to `backendDidRejectMutation` exclusively from `prepareMutation`'s `.terminal` branch — this
    /// member never reaches `prepareMutation` at all. But the merge mechanism already exists with NO
    /// further code change: any document client that rejects `.unsupportedOperation` from
    /// `prepareMutation` becomes indistinguishable, on the `backendDidRejectMutation` channel, from a
    /// dictation-disallowed rejection from HERE. No owning task is named yet for disambiguating the
    /// two meanings (policy denial of a specific capability vs. a foreign/consumed token) — flag this
    /// for whichever lands first: a future reopening of `RichTextInputMutationRejection`, or Tasks
    /// 27/28's own rejection forwarding, since either is a natural point to add a dedicated case.
    ///
    /// FIX ROUND 1 (task-22i-review.md Minor 3, recorded): this guard reports a
    /// `RichTextInputContractViolation` when detached — CONSISTENT with the rest of this class's
    /// content/selection-mutating members (`insertText`, `deleteBackward`, `setSelection`,
    /// `clearCompositionState`, `setMarkedText`, `synchronizeAfterExternalChange`), all of which
    /// already report on the same detached guard. `editPolicyDidChange()` — which TASK 31 MOVED to
    /// `+Responder.swift`, so it is no longer "above" — returns SILENTLY when detached instead: that
    /// member's own pre-22i body had no detached guard at all (a silent `pendingRouting()` no-op), so
    /// silence there preserves ITS prior behavior, exactly as reporting here preserves the convention
    /// this member's siblings already established. Two different, independently behavior-preserving
    /// choices, not an unstated inconsistency. Task 31 re-examined that silence against a written
    /// instruction to flip it and UPHELD it; `+Responder.swift`'s header records the supersession, and
    /// its reason (3) — that a report is a DEBUG `assertionFailure` when no reporter is installed —
    /// is the same fact this member's own choice trades on, in the opposite direction.
    func insertDictationResult(_ dictationResult: [UIDictationPhrase]) {
        guard isAttached, let host else {
            RichTextInputContractViolation.report("operation on a detached backend: \(#function)")
            return
        }
        guard host.lifecycleClient.editPolicy.allowsDictation else {
            let joinedText = dictationResult.map { $0.text }.joined()
            // TASK 35, disclosed rather than left silent: `canonicalSelectionStorage` used to be a
            // PARALLEL store that lagged the canvas — in practice `(0, 0)` on this path — and is now
            // the live selection. So the payload of this rejection report changed value, in a task
            // whose contract is "no behaviour change". It is the one such change, it is strictly more
            // correct, and it is unobservable in this tree: the value reaches only
            // `backendDidRejectMutation`, whose real implementation
            // (`TelegramLifecycleInputClient`) is `{}` — "no rejection concept exists today". Recorded
            // because "no behaviour change" claims are worth less when the exceptions go unlisted.
            let mutation = RichTextInputMutation.insertText(
                text: NSAttributedString(string: joinedText),
                replacing: canonicalSelectionStorage,
                origin: .dictation)
            host.lifecycleClient.backendDidRejectMutation(mutation, reason: .unsupportedOperation)
            return
        }
    }
}

// MARK: - RichTextKeyInputBackend

@available(iOS 13.0, *)
extension LegacyRichTextInputBackend {
    // TASK 27a REMOVED the `hasText` stub from this file — its real body now lives in
    // `LegacyRichTextInputBackend+Insertion.swift`, answered through the document client.
    //
    // `insertText(_:)` and `deleteBackward()` are NOT here — Task 22b gave them real bodies ahead of
    // schedule (`LegacyRichTextInputBackend+Mutation.swift`) so `BackendMutationContractTests` had
    // something real to pin. BOTH are now routed as plain forwards — `insertText(_:)` by Task 27b
    // (`+Insertion.swift`), `deleteBackward()` by TASK 28 (`+Deletion.swift`) — and neither belonged
    // in the inventory in either state, so R13's count did not move for either.
}

// MARK: - RichTextInputResponderBackend
//
// EMPTY, and deliberately kept as a signpost rather than deleted outright. TASK 30 removed
// `canPerformCommand(_:sender:)`/`performCommand(_:sender:)` (their real bodies, plus D28's third
// member `undoManager`, are in `LegacyRichTextInputBackend+Commands.swift`), and TASK 31 removed the
// remaining TWELVE — the three Bool getters, the become/resign will/did/did-fail sextet,
// `hostWillMove(toWindow:)`, `editPolicyDidChange()` and `textInputTraitsDidChange()` — to
// `LegacyRichTextInputBackend+Responder.swift`. `editPolicyDidChange()` moved with its BODY
// byte-for-byte and its ~60-line doc comment intact (that comment's own header lists the four places
// Task 31 annotated it): it had a real Task-22i body and four adjudicated review findings recorded on
// it, so "delete the Responder lifecycle section" had to mean RELOCATE, not discard.
// Nothing in this protocol's surface is a stub any more.

// MARK: - RichTextInputInteractionBackend

@available(iOS 13.0, *)
extension LegacyRichTextInputBackend {
    // TASK 32 ROUTED FOUR OF THIS SECTION'S FIVE STUBS OUT OF THIS FILE — `installInteractions()`,
    // `removeInteractions()`, `viewportDidChange()` and `layoutDidChange(generation:)`. Their real
    // bodies are in `LegacyRichTextInputBackend+Interaction.swift`; the fifth,
    // `cancelActiveInteraction(reason:)`, went with them (it was declared last in this section, after
    // the floating-cursor trio, and is gone from below too). All five were GENUINE stubs — one
    // inventory entry and one `pendingRouting()` call site each — so R13's reconciliation moves in
    // step, entries −5 and call sites −5, with no change to its hardcoded `exceptions` array.
    //
    // Nothing was re-homed to `ReferenceMutationBackend`: no member of this family ever carried a
    // transaction or a storage body to move (contrast Tasks 27b/28/29). TWO canvas hooks were added
    // instead — `legacyViewportDidChange()` (a renamed witness body) and
    // `legacyRemoveSelectionInteractions()` (NEW code; install has been one-way since it was written) —
    // and ONE canvas witness became a one-line router (`viewportDidChange()`).
    //
    // The floating-cursor trio that used to sit below was UNTOUCHED by Task 32 and was Task 33's;
    // **TASK 33 TOOK IT**, together with the two Task-22e minimal bodies. See the note where it stood.

    // The floating-cursor trio was declared here. **TASK 33 ROUTED ALL THREE** to
    // `LegacyRichTextInputBackend+FloatingCursor.swift`, taking Task 22e's two minimal flag-only bodies
    // (`beginFloatingCursor(at:)`, `endFloatingCursor()`) and one genuine stub
    // (`updateFloatingCursor(at:)`) with them. Task 22e's three FIX-ROUND-1 notes went with the members
    // rather than being discarded: the load-bearing forward-then-flag ORDER (Major 3b) and the
    // re-entrancy question (Major 3c) are both answered in that file's header, the latter DISCHARGED —
    // the renamed canvas bodies bring their own guards, and the forward running first is what makes the
    // idempotence structural instead of accidental.
    //
    // `cancelActiveInteraction(reason:)` was declared here too. TASK 32 ROUTED IT — see the note at the
    // top of this section.
}
#endif
