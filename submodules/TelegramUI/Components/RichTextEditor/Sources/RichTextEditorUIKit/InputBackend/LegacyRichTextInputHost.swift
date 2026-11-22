#if canImport(UIKit)
import UIKit

/// DEVIATION D24 — the backend-private host refinement.
///
/// The spec's Phase 3 says the legacy backend "initially forwards to narrowly named legacy hooks",
/// and Phase 4 keeps the large structural-dispatch bodies on the canvas behind `legacy…` hooks — the
/// marked-text bodies, the checking lifecycle and the responder pre/post work. (This sentence used to
/// name "~400 lines of `legacyDeleteBackward`, ~150 of `legacyInsertText`" as though both hooks
/// existed; TASK 27a corrected it, and TASK 27b made half of it true — `legacyInsertText` (~147 lines)
/// now exists and the backend forwards to it, under the user's D35 ruling. `legacyDeleteBackward` is
/// still Task 28's; `legacyReplace`, added by Task 27a, is the third such hook.) The
/// composite contract vends only the six clients, so without this refinement every Phase-4 backend
/// member would need an undocumented `host.hostInputView as? DocumentCanvasView` downcast.
///
/// Rules, all enforced by the source-boundary suite:
///   * ONLY `LegacyRichTextInputBackend` may reference this protocol or `legacyCanvas`. The shared
///     contract files (everything under `S/InputBackend/` not named `Legacy*` and not under
///     `Clients/`) may not name `DocumentCanvasView` at all.
///   * **`legacyCanvas` may be used for two things and nothing else.** (a) **Invoking a narrowly
///     named canvas hook.** The `legacy…` prefix is how a *renamed witness body* earns that status —
///     it marks "this used to be the witness; the backend now owns the entry point". A canvas member
///     that is ALREADY narrowly named needs no rename and gets none: `commitMarkedText`,
///     `dismissPrediction`, `finalizeMarkedText` (Task 29; Task 34's brief makes the same call for its
///     three). So the prefix is a *provenance marker*, not a magic string, and an unprefixed callee is
///     not automatically a violation — a callee that is broad, or that the backend is not meant to own,
///     is. (b) **Reading canvas-owned state that the backend will own after Phase 5**, where the read
///     is a plain property access with NO branch and NO side effect.
///   * **The current clause-(b) exceptions, named so the list is auditable rather than implied** —
///     `markedRange` (`+MarkedText.swift`, Task 29), `typingWritingDirection` (`+Geometry.swift`,
///     Task 25). Both are stores Phase 5 moves onto the backend; each read expires when its store
///     does (Task 41 owns `markedRange`). **Adding another means adding it to this list.**
///   * **TASK 35 RETIRED TWO AT ONCE — `anchor` and `head` — which is the largest test the list's
///     premise has had.** They were here for the `selectedTextRange` getter
///     (`LegacyRichTextInputBackend.swift`), which read `legacyCanvas.anchor`/`.head` because the
///     canvas, not the backend, was the live selection authority. Task 35 moved that storage: the
///     canvas properties are now computed forwarders over `canonicalSelectionStorage`, so leaving
///     the reads would have made the getter a round trip out to the canvas and straight back into
///     this backend's own stored property — on the hottest path in the editor. Unlike Task 33's
///     `floatingCursorActive`, which expired because a bridging read COLLAPSED, these expired for the
///     list's stated reason: the store they read moved. The list is down to two.
///   * **TASK 33 RETIRED THE FIFTH READ — `floatingCursorActive` — and it is the first entry ever to
///     leave, which is the list's own premise finally being tested.** It was here because the
///     `selectedTextRange` setter (`LegacyRichTextInputBackend.swift`) consulted the CANVAS's flag
///     alongside the backend's, as Task 26's deliberate bridge until the backend became the gesture's
///     writer. Task 33 made it the writer and collapsed the read, so the entry expired on schedule.
///     Two things are recorded rather than left implicit: the retirement had to happen in the SAME
///     commit in both copies of this rule (the other is on `legacyCanvas` itself in
///     `LegacyRichTextInputBackend.swift`), and **the ordinal is deleted from the bullet above** —
///     "adding a sixth" had been correct for five tasks and would have been wrong from this one on,
///     which is the restated-count failure this codebase has now paid for in three separate files.
///     Count the list; do not number it.
///   * **TASK 30 ADDED NO NEW ENTRY, and the near-miss is worth recording because the obvious routing
///     would have.** Its `undoManager` member could have answered `legacyCanvas?.effectiveUndoManager`
///     — a plain, branchless property read, i.e. clause (b) on its face. It does not: it goes through
///     `RichTextInputCommandClient.undoManager` instead, because `effectiveUndoManager` fails the
///     list's actual criterion — it is NOT a store Phase 5 moves onto the backend. Deviation D14 keeps
///     undo ownership with the canvas / document client indefinitely, so that read would never have
///     expired, and a permanent entry on a list whose every member is temporary is how a documented
///     exception becomes a precedent. Task 30's own five hooks (`legacyCopy`, `legacyCut`,
///     `legacyPaste`, `legacySelect`, `legacySelectAll`) are all clause (a), the plain renamed-witness
///     kind.
///   * **TASK 31 ADDED NONE EITHER, and its near-miss is sharper than Task 30's because the BRIEF
///     MANDATED THE WRONG READ.** `hostWillBecomeFirstResponder()`/`hostWillResignFirstResponder()`
///     must capture whether the canvas was first responder before `super` flips it, and the task
///     brief's own snippet spelled that `canvas.isFirstResponder` — a plain, branchless property read,
///     i.e. clause (b) on its face. It fails the list's ACTUAL criterion: `isFirstResponder` is
///     `UIResponder`'s own state and will never be a store Phase 5 moves onto the backend, in stage 1
///     or stage 2, so the entry could never expire. Both captures read
///     `host.hostInputView.isFirstResponder` instead — the spelling `publishState`
///     (`LegacyRichTextInputBackend.swift`) already uses, whose own comment records that reading a
///     plain `UIView`/`UIResponder` is an ordinary UIKit query, not an escape-hatch use. **TASK 33
///     LIKEWISE ADDED NONE**: its three members forward through clause (a) onto renamed witness
///     bodies (`legacyBeginFloatingCursor`, `legacyUpdateFloatingCursor`, `legacyEndFloatingCursor`)
///     and write the backend's OWN flag; the canvas flag they used to consult is the entry retired
///     above. Task 31's six new hooks (`legacyDidBecomeFirstResponder`, `legacyMarkDidJustBecomeFirstResponder`,
///     `legacyFinishBecomingFirstResponder`, `legacyWillResignFirstResponder`,
///     `legacyDidResignFirstResponder`, `legacyWillMove(toWindow:)`) are all clause (a).
///   * **ONE site of this list is now mechanically enforced — and only one, so read the next bullet
///     as still in force.** R17's `.statements(allowed:)` shape pins
///     `hostWillBecomeFirstResponder()`'s single statement to the exact text
///     `wasFirstResponderAtWill = host.hostInputView.isFirstResponder`, so substituting the
///     `legacyCanvas` read reddens the source-boundary suite (measured). That is a property of THAT
///     ENTRY, not of the rule, and it does not generalise. Task 31's fix round 1 additionally made
///     R17's `.client` case reject a body that names `legacyCanvas` at all, which covers the members
///     whose whole correctness argument is "must not reach the canvas" (`hasText`,
///     `canPerformCommand(_:sender:)`, `undoManager`, `editPolicyDidChange()`) — **the exact
///     `undoManager` -> `legacyCanvas?.effectiveUndoManager` mutation the bullet above describes was
///     GREEN under the rule until then**, which is why that bullet was worth writing and why it was
///     not enough on its own.
///   * **Both clauses above, and that exception list, are PROSE-ENFORCED WHEREVER R17 DOES NOT REACH —
///     which is still most places, and the exact boundary was MEASURED at Task 31's fix round 2 rather
///     than reasoned about.** R9 (the first bullet) confines only WHERE `legacyCanvas` may be *named*;
///     it says nothing about WHAT may be reached through it. So a new clause-(b) read added to a
///     member R17 does not name compiles, passes every source-boundary rule, and is invisible until
///     someone re-reads this comment — measured on `finalizeMarkedTextForDetach()`: **GREEN**, and an
///     unprefixed clause-(a) call there is **GREEN** too. What changed is only the pinned members: a
///     clause-(b) substitution into `hostWillBecomeFirstResponder()` (an exact-text `.statements` pin)
///     or into any `.client` member is **RED**. Stated here so the list is neither mistaken for
///     something a test protects nor written off as unprotected now that part of it is. **Every
///     sentence in this codebase claiming what a rule does or does not check is now a TESTABLE claim:
///     apply the substitution it describes and read the result. Two review passes read the
///     `+Responder.swift` copy of this claim without testing it, and it was false.** (Recorded in
///     `LegacyRichTextInputBackend.swift`'s copy of this rule too; Task 29's fix round 1 claimed both
///     copies carried it when only that one did — its re-review caught the asymmetry.)
///   * TASK 29 AMENDMENT, recorded rather than silently applied. This rule used to read: "`legacyCanvas`
///     is a read-only accessor for invoking `legacy…` hooks. It is NOT a licence to read or write
///     canonical selection, marked state or the input delegate." That was already contradicted by four
///     call sites when Task 29 began (the clause-(b) list above, minus `markedRange`), and Task 29 broke
///     it twice more: it added the fifth read, and — brief-mandated — the FIRST unprefixed *writes*
///     (`commitMarkedText`/`dismissPrediction`/`finalizeMarkedText` all mutate). A rule stated
///     absolutely and honoured nowhere is worse than a rule with a written exception list, so the rule
///     above is the one actually in force. What it still forbids, and what the original sentence was
///     really protecting: the backend must not reach through this accessor to *write* canonical
///     selection, marked state or the input delegate directly — after Phase 5 those have no writable
///     canvas surface at all.
///   * Stage 2's `IDTextEditorBackend` never sees it. That is the point of the refinement: the
///     temporary forwarding has an unambiguous eventual authority and a single named conformer.
@MainActor
@available(iOS 13.0, *)
protocol LegacyRichTextInputHost: RichTextInputHost {
    var legacyCanvas: DocumentCanvasView { get }
}
#endif
