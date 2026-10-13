#if canImport(UIKit)
import UIKit

/// The first (and, for stage 1, only) `RichTextInputBackend` conformer: it forwards to
/// `DocumentCanvasView` via the six Telegram clients (Tasks 12-19) and the `legacyCanvas` escape
/// hatch (deviation D24). Constructed and attached once per canvas
/// (`DocumentCanvasView.init(mapper:inputBackend:)`), torn down at `deinit`.
///
/// **TASK 34 CLOSED PHASE 4: every witness family now routes.** This paragraph used to read "No
/// witnesses route yet (Task 20) … every `UITextInput`/`UIKeyInput`/responder/interaction witness in
/// `+PendingRouting.swift` is a temporary stub Tasks 24-34 replace one family at a time." Tasks 24-33
/// replaced them one family at a time, and Task 34 deleted the routing machinery itself — the
/// `pendingRouting(_:)` funnel and the `pendingRoutingInventory` Set are gone, and that file is now
/// `+Unwitnessed.swift`, holding only the two PERMANENTLY unwitnessed members (D15). The absence is
/// enforced by rule R20 in the Core source-boundary suite, not by this sentence.
@MainActor
@available(iOS 13.0, *)
final class LegacyRichTextInputBackend: RichTextInputBackend {
    // MARK: - Stored state
    //
    // ACCESS LEVEL IS LOAD-BEARING (see the interface doc in the task brief): this class is split
    // across `LegacyRichTextInputBackend.swift`, `+Attachment.swift`, `+Unwitnessed.swift`, and
    // (from Task 24 on) eleven Phase-4 family files. Swift's `private`/`private(set)` are FILE-scoped,
    // so a `private var isAttached` here would make `+Attachment.swift`'s `isAttached = true` a
    // compile error. Every member below is plain `internal` (module-scoped, the package default);
    // confinement comes from `final` + internal + source-boundary rule R9, not from `private`.

    /// The attached host. Retained WEAKLY (the backend must never keep the canvas alive) — set by
    /// `attach(to:)`, cleared by `performDetachSteps()`.
    weak var host: (any LegacyRichTextInputHost)?

    var isAttached: Bool = false
    var transactionPhase: RichTextInputTransactionPhase = .idle
    var detachRequested: Bool = false

    /// TASK 22g ADDITION. Spec: "No callback between preparation and commit may publish an external
    /// document change. Such a request is deferred until the transaction returns to `.idle`."
    /// `synchronizeAfterExternalChange` stashes an arriving change here instead of processing it
    /// inline whenever `transactionPhase != .idle` (a reentrant call from a client/facade callback
    /// fired mid-transaction); `endTransaction()` (`+Attachment.swift`) drains it.
    ///
    /// FIX ROUND 1 (review Minor 4) — AT MOST ONE pending change is held: a second call while one is
    /// already stashed OVERWRITES it. The LATEST stashed change survives; an earlier one, if any, is
    /// silently dropped. No test in this tree exercises two external changes queued in the same
    /// transaction — this is a minimal, behavior-preserving default (nothing before Task 22g could
    /// ever have more than zero), disclosed rather than pinned for the multi-pending case.
    ///
    /// FIX ROUND 1 (review Minor 2) — CORRECTED, was over-claimed: this is NOT guaranteed to be
    /// cleared by the time `performDetachSteps()` runs. `endTransaction()`'s drain is now "AT MOST ONE
    /// per outer call" (not recursive) — if the ONE drained change's own publish stashes a NEW one
    /// (a client that reacts to every publish by requesting another external sync), that new value
    /// can still be present when `detachRequested` is checked immediately afterward. Harmless if left
    /// (a stashed change is never read again once `isAttached` is false — `synchronizeAfterExternalChange`'s
    /// own guard rejects before ever consulting this), but `performDetachSteps()` clears it anyway,
    /// for the same hygiene reason it resets `suppressesSelectionNotifications`/`floatingCursorActive`.
    var deferredExternalChange: RichTextInputExternalChange? = nil

    /// TASK 22g FIX ROUND 1 (review Major 2 — 22g's own defect, not a later task's). Nesting depth for
    /// the shared bracket-exit `endTransaction()`: incremented at the START of every top-level bracket
    /// this class owns, decremented by `endTransaction()`. Only the call that takes the counter from 1
    /// back to 0 — the OUTERMOST bracket — actually returns `transactionPhase` to `.idle`, drains a
    /// deferred external change, or fires a latched detach. See `endTransaction()`'s own doc comment
    /// (`+Attachment.swift`) for the defect this closes and why it is THIS task's to fix (the guard
    /// being defeated is the guard 22g shipped).
    ///
    /// FIX ROUND 2 (review MAJOR — new finding): this entry/exit pair used to be HAND-PAIRED at each
    /// of the six call sites (`activeTransactionDepth += 1` written directly before the bracket body,
    /// `endTransaction()` written directly after) — unenforced in both directions: a missing entry
    /// bump made `endTransaction()`'s old `max(0, … - 1)` clamp silently pass, reinstating the exact
    /// defect this counter exists to prevent; a bracket that returned early after bumping (without
    /// reaching its own `endTransaction()`) leaked the bump permanently, wedging every later
    /// transaction. Both are now closed: `withTransaction(_:)` (`+Attachment.swift`) is the ONE place
    /// that bumps this counter and calls `endTransaction()`, so a caller cannot do one without the
    /// other; `endTransaction()` reports a contract violation (rather than clamping) if it is ever
    /// reached with this counter already at 0; and `performDetachSteps()` resets this to 0 as a
    /// hygiene backstop, the same treatment `deferredExternalChange` already got. All six real
    /// bracket-entry sites (`synchronizeAfterExternalChange`'s real branch, `setSelection`,
    /// `clearCompositionState`, `setMarkedText`, the `suppressesSelectionNotifications` didSet flush,
    /// and `runMutation`'s `.ready` branch in `+Mutation.swift`) now call `withTransaction(_:)` instead
    /// of touching this property directly. The ONE remaining direct read/write of this property
    /// outside `withTransaction`/`endTransaction`/`performDetachSteps` is `endTransaction()`'s own
    /// deferred-change drain, which manually bumps/unbumps around a nested call BY DESIGN (see that
    /// drain's own comment for why it must not go through `withTransaction`).
    var activeTransactionDepth: Int = 0

    /// The document revision this backend has adopted. Seeded from the host's document client at
    /// attach; updated only by `synchronizeAfterExternalChange` (never by `.layoutOnly` changes).
    var documentRevision: UInt64 = 0

    /// **THE canonical selection — as of TASK 35, the ONE stored copy in the package.** It was a
    /// PARALLEL value from Task 20 until now (the canvas's own `var anchor = 0` / `var head = 0` were
    /// the live authority and this lagged every direct write to them, which is what
    /// `+Insertion.swift`/`+Deletion.swift`/`+MarkedText.swift`'s "lags the canvas until Task 35"
    /// notes were about). Task 35 deleted that storage: `DocumentCanvasView.anchor`/`.head` are now
    /// computed forwarders over this property, reached through the D33 contract members below.
    ///
    /// Writers, in full: `setSelection(_:reason:)` (the spec's one whole-selection spelling),
    /// `synchronizeAfterExternalChange`, `installInitialState(from:)` at attach, and the two
    /// single-endpoint D33 setters `setCanonicalAnchor`/`setCanonicalHead`. Those two used to back
    /// the canvas `anchor`/`head` SETTERS, which Task 40b deleted; they survive with seven `Sources/`
    /// callers of their own and are a permanent primitive of the contract, not scaffolding (the
    /// decision is recorded at their declaration in `RichTextInputBackend.swift`). The pair writes
    /// this property DIRECTLY and publishes nothing — see their own doc comment for why routing them
    /// through `setSelection` would have been a behaviour change at every pre-seam canvas write site
    /// in one commit.
    var canonicalSelectionStorage: RichTextCanonicalSelection = .caret(at: .downstream(0))

    /// The marked (IME composing) range, in the same coordinate space as `canonicalSelectionStorage`.
    /// `nil` = not composing.
    ///
    /// **MUTATOR INVENTORY — TASK 29 CORRECTION, and this list must be changed together with the one
    /// in the "Marked text — ROUTED BY TASK 29" MARK block below.** The two are deliberately
    /// duplicated (see the durability note further down), which means they can disagree; when they do,
    /// the bug is here. As of Task 29 the writers are exactly:
    ///
    ///   * `runMutation` (`+Mutation.swift`, `markedRangeStorage = result.markedRange`) — since Task 22b;
    ///   * `reconcileMarkedTextForExternalChange` (the three `RichTextMarkedTextPolicy` branches of
    ///     `synchronizeAfterExternalChange`) — Task 22f;
    ///   * `finalizeMarkedTextForDetach()` — Task 22f;
    ///   * `clearCompositionState()` — one mutator among several, not "the only" one.
    ///
    /// **`setMarkedText(_:selectedRange:)` is NO LONGER a writer of this store**, and the section this
    /// comment used to point at ("see its own section below") no longer exists. Task 22f had given that
    /// member a real-but-storage-only body here; TASK 29 replaced it with the plain `legacyCanvas`
    /// forward it was always a placeholder for (`+MarkedText.swift`) and moved the storage body to the
    /// test-only `ReferenceMutationBackend` (`T/Support/`). So the ONLY writer of this store that a
    /// composition can reach is the test conformer — and the routed `markedTextRange` reads
    /// `legacyCanvas.markedRange` instead. That two-store split is the divergence Task 29 disclosed and
    /// Task 41 closes; `+MarkedText.swift`'s header states it in full.
    ///
    /// **TASK 41 — THIS IS NOW THE ONE STORE, AND THE INVENTORY ABOVE IS OUT OF DATE IN ONE ENTRY.**
    /// The writers are `reconcileMarkedTextForExternalChange`'s three branches (through
    /// `clearCompositionStorage()`), `finalizeMarkedTextForDetach()`, `clearCompositionState()`, the
    /// raw `setCompositionMarkedRange(_:isPrediction:)` — which is the one the canvas's three
    /// composition-lifecycle bodies use, and therefore the one a real IME composition reaches — and
    /// `runMutation`, still dead for want of a `prepareAndRun` caller.
    /// `DocumentCanvasView.markedRange` is a READ-ONLY projection of this property.
    ///
    /// FIX ROUND 2 (review, prediction/`selectedRange` finding) — this WAS a DELIBERATELY PARTIAL
    /// representation of the canvas's composition state, missing `markedTextIsPrediction` BY DESIGN
    /// until Task 41 moved all four composition properties (`markedRange`, `markedTextIsPrediction`,
    /// `compositionUndoSnapshot`, `compositionAnchorHead`, `plan:7483-7493`) into the backend TOGETHER.
    /// It did; the companions are declared immediately below.
    /// Recorded HERE, at the declaration, rather than only in the marked-text section's own comments
    /// below, because Task 29 rewrites those comments (it keeps the canvas authoritative for
    /// composition state — `plan:6409`, "State does not move yet — that is Task 41"); this declaration
    /// is the durable spot that survives that rewrite.
    ///
    /// **TASK 29 CORRECTION — the durability claim above did NOT hold, and that is worth recording
    /// rather than quietly repairing.** Task 29 rewrote the section below exactly as predicted, and the
    /// mutator inventory at this "durable spot" went stale in the same commit: it kept naming
    /// `setMarkedText(_:selectedRange:)` as a writer and pointing at a deleted section, while the
    /// replacement MARK block carried a different, correct list. One file, two disagreeing inventories
    /// of the fact the task existed to disclose, with the stale one at the declaration a future auditor
    /// reads first. Fixed in Task 29's fix round 1. A duplicated record is only durable if every task
    /// that touches either copy touches both — hence the explicit instruction at the top of the
    /// inventory above.
    ///
    /// (The forward-gating claim in the original sentence — that Task 29's forward "is already gated by
    /// `test_finalizeMarkedTextDismissesAPredictionButCommitsAComposition`" — was also optimistic and is
    /// dropped: that test drives `DocumentCanvasView.finalizeMarkedText()`, not any backend member, so
    /// it characterizes pre-existing canvas behaviour and nothing Task 29 changed can redden it. Task
    /// 29's review recorded the same.) A backend-side
    /// `markedTextIsPrediction` must NOT be added ahead of Task 41 — it would be a SECOND writable
    /// composition authority, which R7 forbids (`test_exactlyOneWritableSelectionAuthority`,
    /// `plan:7577`, already gates this). **TASK 41 added it, which is the same rule read the other
    /// way round: the canvas's copy went away in the same commit, so there is still exactly one.**
    var markedRangeStorage: NSRange?

    /// TASK 41 — the second of the four composition properties that used to live on
    /// `DocumentCanvasView`. Storage only; **read it through `isComposingPrediction`**, which ANDs it
    /// with `markedRangeStorage != nil` so a stale `true` can never be observed while nothing is
    /// composing. That is not defensive padding: `runMutation` (`+Mutation.swift`) writes
    /// `markedRangeStorage` directly from a mutation result and has no prediction flag to write, so
    /// the two stores genuinely can disagree — the accessor is where that is made unobservable rather
    /// than at four call sites that would each have to remember.
    var markedTextIsPredictionStorage: Bool = false

    /// TASK 41 — the third and fourth, collapsed into ONE value (see `RichTextCompositionSnapshot`'s
    /// own doc comment for why they are not two members).
    var compositionSnapshotStorage: RichTextCompositionSnapshot?

    /// Task 26's coalescing forwarder — a plain stored `Bool`, per D33. FIX ROUND 2: corrected from
    /// "Task 31" — the plan (`:6210, :6242-6247, :6280`) gives this member to Task 26 (family 3:
    /// selected range / input delegate / delegate emission); Task 31 is unrelated (responder
    /// lifecycle, edit policy, traits notification, `:6520`).
    ///
    /// TASK 22d ADDITION (self-disclosed policy, not dictated by the spec or the task brief — pinned
    /// by `BackendPublicationContractTests.test_coalescedSelectionDrag_publishesExactlyOneSnapshotAtTheEnd`):
    /// gates `setSelection`'s publication. While `true`, `setSelection` still updates
    /// `canonicalSelectionStorage` but defers the publish (see `pendingCoalescedSelectionPublish`
    /// below); flipping this back to `false` publishes exactly ONE settled snapshot, reflecting the
    /// LAST selection set during the suppressed run. This is the only lever this stage-1 backend
    /// exposes for a coalesced multi-sample drag — no begin/end-drag method exists on
    /// `RichTextInputBackend` yet; Task 26 is expected to wire a real canvas gesture through this
    /// flag, mirroring the legacy canvas's own `coalescingSelectionNotifications` (which Task 26 turned
    /// into a forwarder onto THIS flag and TASK 43 deleted outright). Default `false`,
    /// so every pre-existing call site (which never touches this) is byte-identical.
    ///
    /// FIX ROUND 2 (review Major A): this flag also gates Task 26's OWN delegate-bracket emitters
    /// (`notifyingSelectionChange(_:)`, "SUPPRESSED while coalescing" per the plan) — a second,
    /// independent consumer of the SAME flag. The doc comment on the protocol requirement
    /// (`RichTextInputBackend.swift`) is the normative statement of both halves; this file's own
    /// `setSelection`/didSet below implement only the publication half.
    /// FIX ROUND 1 (review Major 1): guarded on `isAttached`. `performDetachSteps()`
    /// (`+Attachment.swift`) now flips this flag off as part of teardown — D18 declares that
    /// teardown kills "the coalescing flag" — and it does so AFTER `isAttached` has already gone
    /// false (that assignment is step 1). Without this guard, a pending latch would flush a
    /// publish to a host that has just been declared closed to new operations, and would run
    /// `endTransaction()` in the middle of the nine detach steps. This is a normal teardown path,
    /// not a caller misuse, so it drops the latch silently rather than reporting a contract
    /// violation.
    ///
    /// FIX ROUND 1 (Minor 7): a content mutation interleaved into a suppressed run (`setSelection`
    /// while suppressed → `insertText` commits and publishes `.content`, overwriting
    /// `canonicalSelectionStorage` → flag cleared) yields one REDUNDANT `.selection` publish
    /// describing state the `.content` publish already carried — an extra `onSelectionChange` once
    /// Tasks 36a-39 make this flag live from a real gesture. Not reachable through any real gesture
    /// today (nothing routes `anchor`/`head` writes through `setSelection`, and no real drag can be
    /// mid-flight while a content edit lands); left as-is rather than restructuring the latch to
    /// detect it — Tasks 36a-39 are the owner of this once it becomes reachable.
    ///
    /// **TASK 35 CHECKED THIS AND IT STILL HOLDS, which is not what the sentence above predicted.**
    /// That parenthesis read "until Task 35" on both clauses, i.e. it expected this task to make the
    /// case reachable. It does not: Task 35 routes canvas `anchor`/`head` writes to the RAW
    /// `setCanonicalAnchor`/`setCanonicalHead` (which touch neither `setSelection` nor this latch —
    /// see their doc comment), precisely so the pre-seam sites do not start publishing all at once. So the
    /// owner is unchanged: Tasks 36a-39, when they convert those sites to `setSelection`.
    ///
    /// **TASK 36a CHECKED IT AGAIN AND IT STILL HOLDS, for the same reason one task later.** 36a's
    /// caret-outcome application also routes around `setSelection` (to the same raw pair), on a
    /// measurement recorded at `applyCaretOutcome` in `DocumentCanvasView+Editing.swift`. The owner
    /// moves to whichever commit first sends a converted site through `setSelection` — on current
    /// evidence Task 40b, not 36a-36c.
    var suppressesSelectionNotifications: Bool = false {
        didSet {
            guard oldValue != suppressesSelectionNotifications else { return }
            guard !suppressesSelectionNotifications, pendingCoalescedSelectionPublish else { return }
            guard isAttached else {
                pendingCoalescedSelectionPublish = false
                return
            }
            pendingCoalescedSelectionPublish = false
            // FIX ROUND 2 (review Major): routed through the `withTransaction(_:)` chokepoint
            // (`+Attachment.swift`) instead of manually bumping `activeTransactionDepth` and calling
            // `endTransaction()` separately — see that method's own doc comment for why the pair must
            // not be hand-paired at each call site.
            withTransaction {
                transactionPhase = .publishingState
                publishState(reason: .selection)
            }
        }
    }

    /// Set by `setSelection` when a publish was deferred because `suppressesSelectionNotifications`
    /// was `true` at the time; consumed (and cleared) by the `didSet` above once the flag clears.
    var pendingCoalescedSelectionPublish: Bool = false

    /// **THE floating-cursor flag — TASK 42 MERGED THE TWO STORES, so this is now the only one.**
    ///
    /// It is the SUPPRESSION flag: it gates the `selectedTextRange` SETTER below, which since TASK 33
    /// reads it and nothing else. `BackendSelectionContractTests
    /// .test_selectedTextRangeSetter_isIgnoredWhileFloatingCursorIsActive` pins the load-bearing fact
    /// that iOS pushes selection RANGES through that setter during the hold-spacebar gesture, and
    /// applying them would turn a cursor MOVE into a text SELECTION.
    ///
    /// It is ALSO the PRESENTATION flag, since Task 42: `DocumentCanvasView.floatingCursorActive` was a
    /// separate store until this task and is now a read-only projection of this one, so
    /// `updateCaretView()`'s dimmed landing caret and `floatingAutoScrollTick`'s guard read THIS value.
    /// **It IS a protocol member since Task 42** — `DocumentCanvasView.inputBackend` is typed
    /// `any RichTextInputBackend`, so a canvas projection can only reach a contract requirement (D33).
    ///
    /// **WRITERS — the list is the invariant, so keep it exact.** Added by TASK 22e ahead of the real
    /// gesture (mirroring how Task 22d added `suppressesSelectionNotifications` ahead of Task 26's drag
    /// wiring); TASK 33 made it the real gesture's flag and added the clears that keep it honest; TASK
    /// 42 added the canvas door and moved detach's reset:
    ///
    ///   * `beginFloatingCursor(at:)` sets it; `endFloatingCursor()` clears it (`+FloatingCursor.swift`).
    ///   * `setFloatingCursorActive(_:)` (`+FloatingCursor.swift`) — the TASK 42 door, and the one the
    ///     canvas's own bodies use: `legacyBeginFloatingCursor` (set), `legacyEndFloatingCursor` (clear)
    ///     and `cancelFloatingCursor()` (clear). Before Task 42 those three wrote a canvas store.
    ///   * `hostWillResignFirstResponder()` and `hostWillMove(toWindow:)` (`+Responder.swift`) and
    ///     `cancelActiveInteraction(reason:)` (`+Interaction.swift`) each clear it. These were Task
    ///     33's MIRROR clears, added because `cancelFloatingCursor()` then cleared the CANVAS's flag
    ///     only. **They are now redundant with that method's own clear and are KEPT anyway** — but
    ///     NOT all for the same reason, and the first version of this note said they were.
    ///
    ///     **TASK 42 FIX ROUND 1 (review Major 1), corrected PER PATH after being measured against the
    ///     bodies.** The retired sentence read: *"each is reached through an OPTIONAL `legacyCanvas?`,
    ///     so with no canvas attached the mirror is the only clear there is."* That is true for two of
    ///     the three and **impossible for the third**:
    ///
    ///     | member | how it reaches the canvas | is the mirror ever the only clear? |
    ///     | --- | --- | --- |
    ///     | `cancelActiveInteraction(reason:)` | `legacyCanvas?.cancelFloatingCursor()` | **yes** — optional; a canvas-less call still clears |
    ///     | `hostWillMove(toWindow:)` | `legacyCanvas?.legacyWillMove(toWindow:)` | **yes** — same shape |
    ///     | `hostWillResignFirstResponder()` | `guard isAttached, let host, let canvas = legacyCanvas else { return }` | **NO** — with no canvas it returns BEFORE the clear |
    ///
    ///     So for the resign path the kept-because reason is ONLY the second one: the invariant should
    ///     be a property of the MEMBER, not of what its forward happens to do. **That is correct
    ///     behaviour rather than a gap**, and the reason is its caller set: `hostWillResignFirstResponder()`
    ///     is reached from exactly one place in `Sources/`, `DocumentCanvasView.resignFirstResponder()`,
    ///     and `DocumentCanvasView` IS its own `LegacyRichTextInputHost` — so a call arriving with
    ///     `host`/`legacyCanvas` nil would have to come from a canvas that has already been
    ///     deallocated, which cannot dispatch it. The canvas-less configuration is unreachable on that
    ///     path, so there is nothing there to clear.
    ///
    ///     **A cancel path that leaves this flag set latches the setter guard `true` for the life of
    ///     the editor**, silently — which is why all three are kept even where redundant.
    ///
    ///     **WHAT PINS THEM (also Major 1): before this fix round, NOTHING DID.** The reviewer deleted
    ///     all three clears and the whole suite stayed green (`2303 UIKit / 5 skipped + 383 Core, exit
    ///     0`), because `cancelFloatingCursor()`'s own clear masks every one of them on the attached
    ///     path. Two mechanisms now cover them, and each says exactly what it proves:
    ///       - `FloatingCursorStateAuthorityTests.test_theMirrorClearsAreTheOnlyClearOnACanvaslessBackend`
    ///         drives `cancelActiveInteraction(reason:)` and `hostWillMove(toWindow: nil)` on an
    ///         attached backend whose `host` has been released — the one configuration where the mirror
    ///         is observable — and asserts the flag clears. It also asserts the resign path does NOT
    ///         clear there, which is the corrected fact above, pinned rather than merely written down.
    ///       - `InputBackendSourceBoundaryTests.test_theFloatingCursorMirrorClearsArePresent_R21` is a
    ///         source-level MUST-CONTAIN rule over all three bodies, because R17's `.statements` is a
    ///         rule about what a body MAY contain and can never catch a deletion. It is what covers the
    ///         resign clear, which no behavioural test in this tree can reach.
    ///   * `performDetachSteps()` (`+Attachment.swift`) clears it as hygiene, so a session left active
    ///     never survives detach/reattach. **TASK 42 MOVED that reset to AFTER step 2**, because with
    ///     one store an early reset makes `cancelFloatingCursor()`'s own `guard floatingCursorActive`
    ///     return before hiding the transient shadow caret — the hazard Task 32 wrote down and dated to
    ///     Task 42, pinned by `FloatingCursorStateAuthorityTests.test_detachHidesTheTransientCaret`.
    ///     That same reset is what covers the fourth cancel path (`legacyTearDownPresentation()`,
    ///     detach step 7), which no backend member intercepts.
    var floatingCursorActive: Bool = false

    /// TASK 42 — the last raw floating point, in canvas (content) coordinates. Moved from
    /// `DocumentCanvasView`; the canvas keeps a read-only projection. Written only by the canvas's own
    /// floating bodies, through `setFloatingCursorPoint(_:)`.
    var floatingCursorPoint: CGPoint = .zero

    /// TASK 42 — the per-tick auto-scroll step (points) while the floating caret is in a viewport edge
    /// band. Moved from `DocumentCanvasView`; the canvas keeps a read-only projection.
    ///
    /// **Its partner `floatingScrollLink` did NOT move** — a `CADisplayLink` retains its target and
    /// `willMove(toWindow:)` is its only teardown, so it stays canvas storage. The two are still
    /// written together, in `stopFloatingAutoScroll()` and `updateFloatingAutoScroll(viewportY:)`; see
    /// `setFloatingScrollVelocity(_:)`'s contract for why that placement is the whole answer to
    /// "no link ⇒ no velocity".
    var floatingScrollVelocity: CGFloat = 0

    // MARK: - Responder-transition capture (TASK 31, Family 8)
    //
    // ┌─ A GENERAL PHASE-4 FACT, NOT A TASK-31 ONE. Families 9-11 have candidates; this is the file
    // │  they must come to, because Swift extensions cannot declare stored properties. ────────────────
    // │
    // │  **Promoting a witness-local to backend state loses re-entrancy-safety BY CONSTRUCTION.** A
    // │  local on the witness's stack frame is private to that frame; a field on this class is shared
    // │  with every re-entrant frame. The field's validity window runs from the `hostWill…` WRITE to
    // │  the `hostDid…` READ, and **everything between them is a re-entry opportunity, not just the
    // │  callbacks a member happens to make**.
    // │
    // │  Task 31 FIX ROUND 1 (review Min-2) is the worked example, and the omission it corrects is the
    // │  instructive part: the original note enumerated only the two callbacks the backend itself
    // │  invokes (`backendDidBeginEditing()`, and `finalizeMarkedText()` inside
    // │  `legacyWillResignFirstResponder()`) and concluded "every read happens before the only callback
    // │  that can re-enter". **Two statements inside the window went unnamed** —
    // │  `super.become/resignFirstResponder()`, which runs arbitrary UIKit code and posts keyboard
    // │  notifications synchronously, and (on the become side) `canvas.legacyDidBecomeFirstResponder()`,
    // │  which precedes the read. Concretely: host code re-entering `becomeFirstResponder()` during
    // │  `super` would run a nested `hostWillBecomeFirstResponder()` that captures `true` — `super` has
    // │  already flipped `isFirstResponder` — clobbering the outer frame's `false`, so the outer frame
    // │  skips the transition and `onBecameFirstResponder` never fires. Pre-seam, the outer STACK LOCAL
    // │  survived that nesting and the callback fired.
    // │
    // │  No such re-entrant path exists in the tree today, so the conclusion ("no divergence") stands;
    // │  what did not stand was the argument, and an argument that is true only while nobody adds a
    // │  caller is the shape this project treats as a defect.
    // │
    // │  **The fix, for whoever needs it:** capture the field into a `let` at the TOP of the `hostDid…`
    // │  member, before any statement that can re-enter, and read the local thereafter. Deliberately
    // │  NOT applied in Task 31 — it is a behaviour-shape change with no observed failing case, inside
    // │  a zero-behaviour-change commit. Apply it the moment a member gains a second read, or a read
    // │  that follows a callback.
    // └───────────────────────────────────────────────────────────────────────────────────────────────
    //
    // **The brief asked for these two to be `private var`s inside `extension LegacyRichTextInputBackend`
    // in `+Responder.swift`. That does not compile** — Swift extensions cannot declare stored
    // properties — so they live here, exactly like `inputDelegate`/`tokenizerStorage` below and for the
    // identical reason. `private` is additionally wrong once they move here: Swift's `private` is
    // FILE-scoped, and both readers are in `+Responder.swift`, a different file. Plain `internal`,
    // like every other member of this class (see this section-block's own note at the top of the file).

    /// `becomeFirstResponder()`'s `wasFirstResponder` local, promoted to backend state.
    ///
    /// The pre-seam witness captured `isFirstResponder` BEFORE `super.becomeFirstResponder()` flipped
    /// it, and used it to gate the host callback so that a REPEAT become (already focused) fires
    /// nothing. `hostWillBecomeFirstResponder()` captures the same fact at the same instant;
    /// `hostDidBecomeFirstResponder()` reads it. Valid only between those two calls.
    ///
    /// Read through `host.hostInputView.isFirstResponder`, **not** `legacyCanvas.isFirstResponder` —
    /// see `hostWillBecomeFirstResponder()`'s own doc comment for why that distinction costs a
    /// permanent D24 exception.
    var wasFirstResponderAtWill: Bool = false

    /// The resign-side twin of `wasFirstResponderAtWill`, captured in `hostWillResignFirstResponder()`
    /// AFTER that hook's canvas work (the pre-seam body captured it in the same order) and read by
    /// `hostDidResignFirstResponder()`.
    var wasFirstResponderAtWillResign: Bool = false

    // MARK: - Layout-generation observation (TASK 32, Family 9)

    /// The `layoutGeneration` value the canvas last announced through `layoutDidChange(generation:)`.
    ///
    /// **The name overstates what this holds, and the gap is the point of this comment.** The canvas's
    /// `layoutGeneration` (`DocumentCanvasView.swift`) is advanced by TWO methods across **THIRTEEN**
    /// call sites, and exactly ONE of them notifies this member.
    ///
    ///   * `bumpDocumentRevision()` — 5 sites (every content mutation; see `documentRevision`'s own
    ///     doc comment, which enumerates them).
    ///   * `bumpLayoutGeneration()` — **8** sites, in eight distinct members:
    ///     `legacyViewportDidChange()`, `tableDidScroll(_:)` and `layoutContent()` on the canvas, plus
    ///     **all five** members of `TelegramAnnotationInputClient` (`addAnnotation`, `removeAnnotation`,
    ///     `addRenderingAttributes`, `removeRenderingAttributes`, `invalidateTemporaryAttributes`).
    ///
    /// Only `layoutContent()` notifies, so this field tracks *the generation as of the last LAYOUT
    /// PASS*, not the last generation. It lags after every viewport scroll, after every horizontal
    /// table scroll, after **every spell-annotation and rendering-attribute write**, and after every
    /// document mutation that does not also trigger a layout pass. **A reader who treats it as "the
    /// canvas's current generation" will be wrong, and nothing would tell them.**
    ///
    /// **FIX ROUND 1 (review Minor 1) — the counts above are MEASURED, and this comment is the third
    /// undercount of the same fact in a row.** It first shipped saying "THREE places", naming two
    /// `bumpLayoutGeneration()` callers; the coordinator's supplement (§9 axis 3) said the same, and
    /// Task 32's report agreed with it instead of re-measuring — the one place in that task where the
    /// "verify the supplement rather than trust it" discipline was not applied, next to three places
    /// where it was and caught real errors. The review corrected it to five and named two of the
    /// annotation client's members; the client has **five** such members, so five is short too. The
    /// numbers above come from `grep -rn "bumpLayoutGeneration()" Sources/` plus reading each enclosing
    /// declaration. **If you edit this paragraph, re-run that grep — do not adjust the number by
    /// reasoning about a diff.**
    ///
    /// That lag is not a bug today because **nothing reads this field** — the member that writes it is
    /// notification-only under zero behaviour change (the canvas already did all of its own layout by
    /// the time it announces). Wiring the other **twelve** advance sites to notify as well would be new
    /// behaviour in an extraction commit, so it is disclosed rather than added. Whoever gives this field
    /// its first READER owns the decision: either notify from every site and let the name become true,
    /// or rename it for what it actually is (`generationAtLastLayoutPass`).
    ///
    /// **FIX ROUND 2 — this sentence was the THIRD survivor of the old count, and it is the sharpest
    /// one: it sits in the SAME doc comment fix round 1 corrected, a few lines below the corrected
    /// paragraph.** It said "the other two bump sites". Found by the implementer's own cardinality
    /// sweep, not by the re-review — whose stated grep key for that finding was
    /// `three places|bump sites`, which this line matches, so its "returns exactly these two" was
    /// itself short by one. **Successive passes have each under-reported some copy of this fact,
    /// which is the argument for the box under `layoutDidChange(generation:)`
    /// (`+Interaction.swift`) rather than for another correction here: correcting a number and
    /// correcting every copy of it are different acts, and only the second one is durable.**
    ///
    /// **Deliberately NOT reset by `performDetachSteps()`**, unlike `floatingCursorActive` /
    /// `suppressesSelectionNotifications` / `tokenizerStorage`. Those resets each exist because
    /// something READS the field after a reattach and a stale value is a trap; this one has no reader
    /// at all, and adding a reset to a nine-step teardown whose ordering carries three separate
    /// adjudicated notes (`+Attachment.swift`) is a change with no protective effect. Add the reset in
    /// the same commit that adds the first reader.
    ///
    /// NOT a protocol member. `RichTextInputInteractionBackend` (Task 11) declares the five routed
    /// methods and no such property, and Task 32 adds none — the same call `floatingCursorActive` and
    /// `wasFirstResponderAtWill` above record: this is one conformer's private implementation of a
    /// contract, not part of the contract. (The task brief's Produces block listed it inside an
    /// `extension LegacyRichTextInputBackend` alongside the five methods, which cannot compile for a
    /// stored property, and described the whole block as "the contract members declared Task 11" — it
    /// was not declared there.)
    /// Plain `internal var`, like `floatingCursorActive` and `wasFirstResponderAtWill` above and for
    /// the same reason: `private(set)` is FILE-scoped in Swift, and the one writer
    /// (`layoutDidChange(generation:)`) lives in `+Interaction.swift`. A `private(set)` here would have
    /// forced a setter method whose only job is to defeat the access control, which is worse than the
    /// plain field it replaces.
    var lastObservedLayoutGeneration: UInt64 = 0

    // MARK: - Pending-routing stored witnesses
    //
    // `RichTextInputTextBackend`'s STORED-shape requirements. They conceptually belong to
    // the Phase-4 routing table (Selection & delegate — Task 26; the table itself is now the
    // historical ledger in `+Unwitnessed.swift`, Task 34), but Swift extensions cannot declare stored
    // properties, so they live here instead. They never recorded a stub call — a stored property has
    // nothing to record.
    //
    // TASK 29 narrowed this section: it held THREE stored witnesses (`inputDelegate`,
    // `markedTextStyle`, `tokenizerStorage`) and the Marked-text group is now empty — see
    // `markedTextStyle`'s own note below.
    //
    // `selectedTextRange` USED to live here too (plain stored, disconnected from
    // `canonicalSelectionStorage`) until TASK 22e gave it a real computed body — see the dedicated
    // section below, right after `setSelection`. It is no longer a "Selection & delegate — Task 26"
    // stub in the sense the table above once implied for THIS member's own get/set semantics
    // (endpoint identity, the unordered getter, floating-cursor suppression); Task 26's remaining job
    // is wiring the CANVAS's own `selectedTextRange` to forward here, plus the
    // `UITextInputDelegate` bracket around it.
    var inputDelegate: UITextInputDelegate?
    // `markedTextStyle` USED to be declared here as a plain stored property. TASK 29 ROUTED the canvas
    // witness onto this backend and DELETED the storage: the witness has always been `get { nil }
    // set { }` (we draw our own underline decoration), so forwarding onto a stored property would have
    // made the getter start answering whatever was last set. The real member is now `get { nil }
    // set { }` in `+MarkedText.swift`, and `markedTextStyle` is no longer a stored-shape requirement at
    // all — see `MarkedTextRouterTests.test_markedTextStyleGetterIsNilAndSetterIsANoOp`.
    /// Backing storage for the lazily-built `tokenizer` witness (`+TextReads.swift`, Task 24 — the
    /// `+PendingRouting.swift` citation that stood here was already stale when Task 34 renamed that
    /// file, and is repaired rather than merely renamed).
    var tokenizerStorage: UITextInputTokenizer?

    // MARK: - Six convenience accessors (read through `host`)

    var document: (any RichTextInputDocumentClient)? { host?.documentClient }
    var geometry: (any RichTextInputGeometryClient)? { host?.geometryClient }
    var annotation: (any RichTextInputAnnotationClient)? { host?.annotationClient }
    var presentation: (any RichTextInputPresentationClient)? { host?.presentationClient }
    var lifecycle: (any RichTextInputLifecycleClient)? { host?.lifecycleClient }
    var command: (any RichTextInputCommandClient)? { host?.commandClient }

    /// DEVIATION D24 — the single declared path from this backend to the `legacy…` canvas hooks
    /// that Phase 4 forwards to. There is no downcast anywhere: `host` is already typed as the
    /// refinement, because `attach(to:)` accepts only a `LegacyRichTextInputHost` (see
    /// `+Attachment.swift`).
    ///
    /// **This accessor may be used for two things and nothing else** (the rule is stated in full, with
    /// its history, on `LegacyRichTextInputHost` — keep the two copies in step):
    ///
    ///   (a) **invoking a narrowly named canvas hook.** The `legacy…` prefix is how a *renamed witness
    ///       body* earns that status; a canvas member that is already narrowly named needs no rename
    ///       and gets none (`commitMarkedText`, `dismissPrediction`, `finalizeMarkedText`). The prefix
    ///       is a provenance marker, not a magic string.
    ///   (b) **reading canvas-owned state that this backend will own after Phase 5**, where the read is
    ///       a plain property access with no branch and no side effect. The current ones, named so the
    ///       list is auditable: `markedRange`, `typingWritingDirection`. Adding another means adding
    ///       it to that list.
    ///
    /// **TASK 33 RETIRED ONE — the first entry ever to leave this list, which is what the list was
    /// always for.** `floatingCursorActive` was here because the `selectedTextRange` setter read the
    /// canvas's copy alongside this backend's; Task 33 made the backend the gesture's writer and
    /// collapsed that read, so the entry expired exactly as its own rationale said it would. **The
    /// ordinal is deliberately gone from the sentence above**: five successive tasks wrote "adding a
    /// sixth", and a count that has to be re-derived at every edit is the shape this file has paid for
    /// repeatedly. Count the list.
    ///
    /// **TASK 35 RETIRED `anchor` AND `head` — two at once, and by the list's own criterion rather
    /// than by a collapse of the read.** The criterion is "every entry is a store Phase 5 moves onto
    /// the backend; each read expires when its store does", and Task 35 IS that move: the canvas
    /// properties became forwarders over `canonicalSelectionStorage`, so the `selectedTextRange`
    /// getter's `legacyCanvas.anchor`/`.head` — the only two such reads in the tree — would have
    /// become a round trip back into this object. They read the store directly now. The list is down
    /// to two entries, both belonging to stores Task 41 (`markedRange`) and a later task
    /// (`typingWritingDirection`) still have to move; retired in the same commit in both copies, as
    /// Task 33's retirement established.
    ///
    /// TASK 30 added no new entry. Its `undoManager` member reads
    /// `RichTextInputCommandClient.undoManager` rather than `legacyCanvas?.effectiveUndoManager`,
    /// because the latter is NOT a store Phase 5 moves here (D14 keeps undo ownership on the canvas
    /// side permanently) and so would have been a never-expiring entry on a list of temporary ones.
    /// Its five new hooks are all clause (a): `legacyCopy`, `legacyCut`, `legacyPaste`, `legacySelect`,
    /// `legacySelectAll`. See `+Commands.swift`.
    ///
    /// What it still forbids: reaching through this accessor to WRITE canonical selection, marked state
    /// or the input delegate directly — after Phase 5 those have no writable canvas surface at all.
    /// TASK 29 AMENDMENT: this paragraph used to say "permitted ONLY to invoke a `legacy…`-prefixed
    /// hook", which four call sites already contradicted before Task 29 and which Task 29 broke twice
    /// more (a fifth read, plus the first unprefixed WRITES, both brief-mandated).
    ///
    /// Source-boundary rule R9 confines every mention of `legacyCanvas` to `S/InputBackend/Legacy*.swift`
    /// — note that R9 governs only WHERE the accessor may be named, never WHAT may be reached through
    /// it.
    ///
    /// **The two clauses above are STILL prose-enforced in general — measured at fix round 2, not
    /// assumed — but no longer everywhere, and the boundary is worth knowing rather than rounding off
    /// in either direction.** R17 (`InputBackendSourceBoundaryTests`) reaches a member only if
    /// `routedBackendMembers` NAMES it and that member's shape pins what it may reach: `.statements`'
    /// exact-text prefixes, `.canvasForward`'s required `legacyCanvas?.legacy` call, and (since Task
    /// 31's fix round 1) `.client`'s rule that the body must not name `legacyCanvas` at all. For those
    /// members both clauses are mechanically enforced — substituting a clause-(b) read into
    /// `hostWillBecomeFirstResponder()`, or into `undoManager`, reddens R17 (both measured). For every
    /// OTHER member, including this one and every member a future task adds without listing it, they
    /// are prose only: a new clause-(b) read added to `finalizeMarkedTextForDetach()` is GREEN, and
    /// so is an unprefixed, broad canvas call there (both measured, by applying the mutation rather
    /// than reasoning about it — which is the discipline this paragraph exists to hand forward).
    ///
    /// `internal`, not `private`, for the same file-scope reason as the stored state above: its
    /// readers are the eleven `LegacyRichTextInputBackend+*.swift` family files of Tasks 24-34.
    var legacyCanvas: DocumentCanvasView? { host?.legacyCanvas }

    init() {}

    // MARK: - Published state

    var state: RichTextInputStateSnapshot {
        RichTextInputStateSnapshot(
            documentRevision: documentRevision,
            selection: canonicalSelectionStorage,
            markedRange: markedRangeStorage,
            isComposing: isComposing)
    }

    // MARK: - Deviation D33 — seven stage-1 composite members
    //
    // Each is a two-line read or write over the storage declared above — real bodies, not
    // `+Unwitnessed.swift` stubs (Step 3 of the task brief).

    var canonicalSelection: RichTextCanonicalSelection { canonicalSelectionStorage }
    var canonicalSelectionAnchorOffset: Int { canonicalSelectionStorage.anchor.utf16Offset }
    var canonicalSelectionHeadOffset: Int { canonicalSelectionStorage.head.utf16Offset }

    /// The two RAW single-endpoint setters backing `DocumentCanvasView.anchor`/`.head` (Task 35)
    /// and, since TASK 36a, `DocumentCanvasView+Editing.swift`'s `applyCaretOutcome`. They are the
    /// transitional shape that keeps every pre-seam canvas write site behaving exactly as it did,
    /// and Task 40b deletes the canvas setters that reach them.
    ///
    /// **TASK 36a CORRECTION: "every deliberate selection write — including every site Tasks 36a-39
    /// convert — uses `setSelection(_:reason:)` instead" is FALSE for 36a-36c**, measured. The
    /// caret-outcome application uses this pair, because routing it through `setSelection` doubles
    /// the host selection report `editing`'s own tail already emits (measured). See
    /// `applyCaretOutcome`'s doc comment for the measurement, the control, and the deferral; it is
    /// the one normative record and is deliberately not restated here.
    ///
    /// **TASK 35 DIVERGED FROM ITS BRIEF HERE, and the divergence is the point of the member.** The
    /// brief's Step 3 (and the body these two carried from Task 20, when they had no callers at all)
    /// said each should "build the whole selection and route through the existing
    /// `setSelection(_:reason: .programmatic)`, so there is exactly one publication path". That is
    /// right for a deliberate write and wrong for a forwarder, for three measured reasons:
    ///
    ///   1. **It publishes a selection that never existed.** The canvas writes its endpoints ONE AT A
    ///      TIME — most sites are a literal `anchor = a; head = b` pair — so the first of
    ///      the two would publish `(a, OLD head)` through `presentationClient.apply` and
    ///      `lifecycleClient.backendDidPublishState`, and only the second would correct it.
    ///   2. **It defeats `setCaret(global:reportSelectionChange:)`.** That parameter exists so a tap
    ///      does not ask the host to scroll the caret into view; the lifecycle client turns a
    ///      `.selection` publish into `canvas.onSelectionChange?()`, so a publishing forwarder reports
    ///      twice per call whatever the caller asked for.
    ///   3. **It would move the whole phase's behavioural risk into its first commit.** Tasks 36a-39
    ///      exist to introduce publication one cluster at a time, each behind its own gate suites; a
    ///      publishing forwarder introduces it at every site at once, in the commit whose entire
    ///      job is to be invisible.
    ///
    /// So these write the store directly. They also carry NO `isAttached` guard and NO
    /// `editPolicy.isSelectable` gate, for the same transparency reason — a raw `anchor = …` had
    /// neither, and `setSelection`'s policy gate remains the ONE gate point for every deliberate
    /// write, which is exactly what it will be once Tasks 36a-40b are done and these two are gone.
    /// (`BackendEditPolicyTests`' header names these two as routing through that gate; it is
    /// corrected there, in the same commit.) Pinned by
    /// `SelectionAuthorityTests.test_aSingleEndpointWriteIsTransparentAndPublishesNothing`, which is red
    /// against the `setSelection`-routing shape.
    ///
    /// **THE MEASUREMENT, recorded once so a re-run does not read as drift.** Building the rejected
    /// shape and running the full `Scripts/iostest.sh` gives **exit 65, 18 red tests across 13 suites,
    /// 4 `Fatal error` traps** (`operation on a detached backend: setSelection(_:reason:)`, each one
    /// killing the xctest process). Task 35's report says 17/12 and the review says 18/13: the
    /// difference is entirely whether the pin named above — which is *supposed* to be red there — is
    /// counted. **18/13 including the pin; 17/12 of previously-passing tests.** Every failure is an
    /// extra publication, delegate bracket, or host report; none is a test merely encoding the old
    /// implementation.
    func setCanonicalAnchor(_ utf16Offset: Int) {
        canonicalSelectionStorage.anchor = .downstream(utf16Offset)
    }

    func setCanonicalHead(_ utf16Offset: Int) {
        canonicalSelectionStorage.head = .downstream(utf16Offset)
    }

    /// Clears the stored marked range. Still not reachable from anywhere real. TASK 29 CORRECTION:
    /// this used to say "Task 29 wires `+MarkedText`'s reset into this", and Task 29 did NOT — under
    /// the D35 ruling the marked-text witnesses became plain `legacyCanvas` forwards, so the canvas's
    /// composition reset writes `canvas.markedRange` and never reaches `markedRangeStorage` at all.
    /// **Task 41 owns the wiring**, and it is the same task that collapses the two stores (see
    /// `+MarkedText.swift`'s two-store section).
    ///
    /// FIX ROUND 1: this must publish. The spec's published snapshot is
    /// `(documentRevision, selection, markedRange, isComposing)`, and `backendDidPublishState` is
    /// "the only input-state publication into Telegram rendering and facade callbacks" — this
    /// mutates TWO of those four fields (`markedRange` and, via it, `isComposing`). A silent member
    /// here would be a real inconsistency, not a stylistic one — a caller outside a larger publish
    /// bracket would desynchronize the composing indicator/marked-text underline from the backend's
    /// true state until some unrelated operation happened to publish.
    ///
    /// **TASK 35 CORRECTION — this used to argue the point by SYMMETRY with `setCanonicalAnchor`/
    /// `setCanonicalHead` ("both route through `setSelection(_:reason:)`, which publishes
    /// unconditionally"), and that symmetry is gone.** Those two are now raw, non-publishing writes
    /// backing the canvas `anchor`/`head` forwarders (see their doc comment). The argument above
    /// stands on its own without them: this member is called deliberately, by a caller that means
    /// "the composition is over", whereas those two are a transitional bridge for canvas code that
    /// published nothing before the seam and must publish nothing after it. The whole-selection
    /// spelling `setSelection(_:reason:)` remains the publishing sibling to compare against.
    // MARK: - TASK 41 — composition state (the reads and the raw, non-publishing writes)

    /// The single stored marked range. See the protocol declaration for the contract.
    var markedRange: NSRange? { markedRangeStorage }

    /// ANDed with "a range exists", so the flag can never be observed stale — see
    /// `markedTextIsPredictionStorage`'s own note for the writer that makes that possible.
    var isComposingPrediction: Bool { markedRangeStorage != nil && markedTextIsPredictionStorage }

    var isComposing: Bool { markedRangeStorage != nil }

    var compositionSnapshot: RichTextCompositionSnapshot? { compositionSnapshotStorage }

    /// RAW and NON-PUBLISHING, per the protocol contract — the marked-text analogue of
    /// `setCanonicalAnchor`/`setCanonicalHead`. An empty range collapses to `nil`, which is
    /// `legacySetMarkedText`'s own convention (`isComposing` must never read `true` while composing
    /// nothing) and matches `.preserveIfRebasable`'s zero-length collapse.
    ///
    /// No `isAttached` guard and no contract violation: these are the transitional writes of canvas
    /// bodies that ran unguarded before the seam, and adding a guard here would make a detached
    /// canvas's composition reset REPORT where it used to be silent.
    func setCompositionMarkedRange(_ range: NSRange?, isPrediction: Bool) {
        if let range, range.length > 0 {
            markedRangeStorage = range
            markedTextIsPredictionStorage = isPrediction
        } else {
            markedRangeStorage = nil
            markedTextIsPredictionStorage = false
        }
    }

    /// RAW and NON-PUBLISHING, same contract as above.
    func setCompositionSnapshot(_ snapshot: RichTextCompositionSnapshot?) {
        compositionSnapshotStorage = snapshot
    }

    /// Every composition store, cleared together. The ONE place that knows the full inventory — the
    /// four call sites below (`clearCompositionState()`, `.discard`, `.commitBeforeChange`,
    /// `finalizeMarkedTextForDetach()`) each used to clear `markedRangeStorage` alone, which after
    /// Task 41 would leave a prediction flag and a whole-document undo snapshot behind.
    func clearCompositionStorage() {
        markedRangeStorage = nil
        markedTextIsPredictionStorage = false
        compositionSnapshotStorage = nil
    }

    func clearCompositionState() {
        guard isAttached else {
            RichTextInputContractViolation.report("operation on a detached backend: \(#function)")
            return
        }
        // TASK 26 — member-level reentrancy, the same shape as `setSelection` below: the storage
        // write happens, the bracket is skipped, the outer publish carries it. See that member's own
        // note for the full reasoning.
        //
        // TASK 41 widened this from `markedRangeStorage = nil` to the whole composition inventory.
        clearCompositionStorage()
        guard transactionPhase == .idle else { return }
        withTransaction {
            transactionPhase = .publishingState
            publishState(reason: .markedText)
        }
    }

    // MARK: - Whole-selection write (the spec's one spelling)

    func setSelection(_ selection: RichTextCanonicalSelection, reason: RichTextSelectionChangeReason) {
        guard isAttached else {
            RichTextInputContractViolation.report("operation on a detached backend: \(#function)")
            return
        }
        // TASK 22i ADDITION: the per-operation edit-policy gate — `isSelectable` blocks the write
        // entirely (storage untouched, no publish), read FRESH on every call, never cached at
        // attach (`BackendEditPolicyTests.test_notSelectable_rejectsSetSelection_andPublishesNothing`).
        // A silent drop, not a `RichTextInputContractViolation` — a restrictive policy is a normal
        // host state (a keyboard-driven selection landing while the host has disabled selection),
        // not caller misuse, mirroring the reasoning already documented for
        // `RichTextInputContractViolation.report`'s reserved use elsewhere in this file. Scope,
        // disclosed: this is the ONE gate point for whole-selection writes — `selectedTextRange`'s
        // setter and the floating-cursor path both route through this method, so gating here covers
        // them without a second check anywhere else. **TASK 35 CORRECTION: `setCanonicalAnchor`/
        // `setCanonicalHead` no longer do.** They became the raw storage writes backing the canvas
        // `anchor`/`head` forwarders, deliberately ungated — a pre-seam `anchor = …` consulted no
        // policy, and gating every pre-seam canvas write site in the commit whose job is to be invisible is
        // the behaviour change the forwarder strategy exists to avoid. Nothing is lost at the end
        // state: Tasks 36a-39 convert every one of those sites to `setSelection(_:reason:)`, i.e.
        // INTO this gate, and Task 40b deletes the ungated pair.
        // **TASK 36a CORRECTION — that sentence is not true of 36a-36c, and TASK 37 CORRECTION — it is
        // not true of 37 either. Both corrections are measured rather than a change of mind, and the
        // second is stated HERE because the first sat ten lines from a note Task 37 updated and was
        // read past anyway (Rule 15 fails at short range too).** 36a-36c funnel `+Editing.swift`'s 34
        // sites into ONE application point (`applyCaretOutcome`) which uses the RAW pair, because a
        // `setSelection` there doubles the host report `editing`'s tail already emits (measured
        // there, with a green control); Task 37 sent its own 31 to the same mechanism, for the two
        // further reasons in the fix-round note below. **So four of the six tasks named in that
        // sentence do NOT bring their sites into this gate**, and it should be read as naming Tasks 38
        // and 39 plus Task 40b — which is where every deferred site now arrives, the single funnel
        // line converted and the duplicate tail report removed together.
        //
        // **TASK 36c FIX ROUND 1 — the sentence that stood here, "Tasks 37-39 are unaffected by this
        // correction", was FALSE, and its falseness is measured.** Those three tasks were to convert
        // the remaining setter/Sources sites to a PUBLISHING `setSelection(_:reason:)` (the count is
        // the plan's Phase-5 preamble table, Rule 15), and **78 of them, 45 lines across 8 files, sit
        // INSIDE an `editing { }` body** — re-derived 2026-08-21 by brace-matching every `editing`
        // invocation and counting the raw writes within: `+ParagraphFormat` 18, `+UITextInput` 14,
        // `+Buttons` 10, `+Details` 8, `+Formula` 8, `+Tables` 8, `+Emoji` 6, `+QuoteCollapse` 6.
        // (`+UITextInput`'s 14 are Task 37's, and it converted them; the other 64 are Tasks 38/39's.)
        // A publishing write at any of them is the exact shape Task 36a built and measured at **10 red
        // across 7 suites plus 2 hard crashes**, and it reaches BOTH failure classes recorded at
        // `applyCaretOutcome`:
        //   * **class 1, the doubling** — `editing`'s tail already delivers the two host effects a
        //     `.selection` publish delivers, so each converted site adds a second
        //     `canvasSelectionChanged` INSIDE the delegate bracket. A body containing several writes
        //     (`+Formula` has four lines in one body, `+ParagraphFormat` three) publishes once PER
        //     WRITE, not once per transaction;
        //   * **class 2, the trapped runner** — `setSelection`'s `guard isAttached` fires
        //     `RichTextInputContractViolation.report` (`assertionFailure` in DEBUG), which kills the
        //     xctest process in the two `TelegramDocumentInputClientMutationTests` probes that
        //     `detach()` and then drive a mutation reaching `editing`. No characterization
        //     re-recording addresses a trapped process.
        // Three of the 78 are sharper still: `+Emoji:29,37` and `+Formula:42-48` are container-snaps
        // whose value is READ BACK two lines later inside the same body, so a publishing write there
        // is both doubled and load-bearing for the edit's own resolution.
        // **TASK 37 IS DONE AND CONVERTED NONE OF ITS 31 TO THIS METHOD** — and it found the census
        // above, sharp as it is, still too narrow twice over. **The hazard is not "inside
        // `editing { }`"; it is "any site whose publish would be a SECOND one".** Three of Task 37's
        // sites sit inside `notifyingSelectionChangeIgnoringCoalescing { }`, which the census does not
        // count because it is not `editing` — but that bracket opens no transaction and sets no
        // suppression flag, so both of this method's escapes fall through and class 1 lands verbatim.
        // A fourth, `legacyApplySelectedTextRange`, sits in NO bracket at all and is called BY this
        // file's own `selectedTextRange` setter, three statements above the `setSelection` that setter
        // already makes — so a conversion there doubles the CALLER's publish. Task 37's four measured
        // failures, the twelve sites that produced NO failure (Rule 24), and what that means for
        // Tasks 38/39 are recorded once, at `applyCaretOutcome`. Task 37's 31 went to the same raw,
        // non-publishing mechanism `+Editing.swift`'s 34 did: `return .caret(at:)` inside an
        // `editing { }`, `applyCaretOutcome(_:)` everywhere else.
        // **Tasks 38/39 must not read the 8-file census as a safe-list either** — every one of their
        // sites needs the same question asked of it: does a publish here land inside a bracket, or
        // beside one that already publishes?
        // **TASKS 38 AND 39 ARE DONE AND CONVERTED NONE OF THEIR 102 WARNINGS TO THIS METHOD EITHER.**
        // Task 38's 60 all became caret outcomes; Task 39 built the publishing shape for all 40 of its
        // own and measured **3 red across 3 suites**, every one of them attributable (by a second,
        // narrower construction) to the three canvas selection FUNNELS — the very sites its brief
        // called the exception where "publishing is the point". They are the worst case, not the
        // exception: a publish there defeats `setCaret(global:reportSelectionChange:)`, and the
        // coalesced path is not a refuge because a deferred publish still fires out of
        // `suppressesSelectionNotifications`' `didSet`. The numbers and the two other failures are at
        // `applyCaretOutcome`. **So NO task in 36a-39 sent a converted site through this method, and
        // the sentence above should now be read as naming Task 40b alone** — the commit that deletes
        // the raw pair, and which must bring an attachment story, a `reportSelectionChange` story and
        // the tail-report arithmetic with it.
        // `clearCompositionState()`/`setMarkedText`/`synchronizeAfterExternalChange` are NOT
        // gated by this task — the brief's six tests do not ask for it, and `synchronizeAfterExternalChange`
        // in particular is host-driven (reporting a change that already happened), not a user edit
        // attempt a policy would plausibly block.
        //
        // FIX ROUND 1 (task-22i-review.md Minor 3, recorded): this fails OPEN (`?? true` — a nil
        // `lifecycle` permits the write) while `canPerformCommand(_:sender:)`'s `.paste` gate
        // (`+Commands.swift` since Task 30; this citation read `+PendingRouting.swift` until Task 34
        // repaired it) fails CLOSED (`?? false` — a nil `lifecycle` denies). Each is the
        // BEHAVIOR-PRESERVING default relative to what it replaced, not an arbitrary inconsistency:
        // `setSelection` had NO policy concept before this task and unconditionally applied every
        // write, so `?? true` reproduces that when `lifecycle` is unexpectedly nil (which in practice
        // means `host` is nil despite `isAttached` — a state this class treats as impossible, not as
        // "policy forbids"); `canPerformCommand` had NO real answer before this task (`pendingRouting()`
        // returning `false` unconditionally), so `?? false` reproduces THAT prior default instead. The
        // two members simply had different starting defaults to preserve.
        guard lifecycle?.editPolicy.isSelectable ?? true else { return }
        canonicalSelectionStorage = selection
        // TASK 22d ADDITION: while a coalesced run is in progress (`suppressesSelectionNotifications`),
        // update storage but defer the publish to when the run ends (see the property's own doc
        // comment above) — a drag sample must not publish per-frame.
        guard !suppressesSelectionNotifications else {
            pendingCoalescedSelectionPublish = true
            return
        }
        // TASK 26 — MEMBER-LEVEL REENTRANCY (the carry-forward `endTransaction()`'s doc comment
        // (`+Attachment.swift`, Focal Point 1) named this task the owner of). A nested call — one made
        // from a client or facade callback that itself fired inside an in-flight transaction, the
        // realistic sites being `presentationClient.apply` and `lifecycleClient.backendDidPublishState`
        // — takes the reviewer's recommended shape: it performs its STORAGE WRITE (above) and SKIPS its
        // own bracket, letting the OUTER bracket's publish carry the resulting state. Deliberately NOT
        // a hard rejection: dropping the write would silently discard a legitimate adjustment a client
        // makes in response to a publish, and would contradict
        // `BackendReentrancyTests.test_nestedSetSelection_publishesTheFreshStateNotAStaleSnapshot`,
        // which pins that the nested value WINS. Deliberately silent (no
        // `RichTextInputContractViolation`): unlike a reentrant MUTATION (`prepareAndRun`'s guard,
        // `+Mutation.swift`, which has no "apply it later" semantics), a reentrant selection/marked
        // write has an obvious one — the outer publish, which has not been delivered yet, reports it.
        //
        // `transactionPhase != .idle` is exactly "some bracket this backend owns is open", because
        // `withTransaction(_:)` is the only thing that opens one.
        guard transactionPhase == .idle else { return }
        withTransaction {
            transactionPhase = .publishingState
            // Deliberately unconditional: an equal selection still publishes exactly once (matches
            // `test_setSelectionWithAnEqualSelectionPublishesOnce`) — this is a report of "selection
            // was set", not a change-detecting cache.
            publishState(reason: .selection)
        }
    }

    // MARK: - `selectedTextRange` (TASK 22e, ahead of Task 26's canvas wiring)
    //
    // `RichTextInputTextBackend`'s `selectedTextRange { get set }` requirement. This task gives it a
    // real body so `BackendSelectionContractTests` has something to pin: endpoint identity, the
    // UNORDERED getter, and floating-cursor suppression of the setter.
    //
    // FIX ROUND 1 (review Major 1): corrected — Task 26 does NOT add a `UITextInputDelegate` bracket
    // around this setter. Oracle row 21 (plan) and
    // `DelegateTraceCharacterizationTests.test_selectedTextRangeSetter_emitsNoDelegateNotifications`
    // (green today) both require this setter to stay delegate-SILENT — no `textWillChange`/
    // `selectionWillChange`/`selectionDidChange`/`textDidChange` call ever originates here. Task 26's
    // actual job (plan Step 4) is moving the CANVAS's own setter body in VERBATIM — the floating-cursor
    // early return, `imageObjectDeletePending` stash, `finalizeMarkedText()`, `clearStructuralSelections()`,
    // `dismissEditMenuForSelectionOrTextChange()`, the unordered read, `onSelectionChange?()` — none of
    // which is a delegate bracket. (Distinct from `setSelection`'s own SEPARATE
    // `notifyingSelectionChange(_:)` bracket, which lives at Task 26 too but gates a different call
    // path — the selection FUNNELS, rows 8-10 — not this setter.)
    //
    // FIX ROUND 1 (review Major 2): this body is DELIBERATELY PARTIAL, not the member's full get/set
    // semantics — it diverges from the canvas oracle (`DocumentCanvasView+UITextInput.swift`) on two
    // inputs, and neither divergence is pinned by a test:
    //   - a `nil` or non-`LegacyTextRange` `newValue` is DROPPED here (the write is ignored); the
    //     canvas COLLAPSES to offset 0 instead (`r?.from.offset ?? 0`).
    //   - offsets are written RAW/unclamped here; the canvas `clamp()`s both endpoints.
    // FIX ROUND 2 (review item 1): dropped the earlier "four canvas side-effect hooks above" count —
    // it undercounted (the list above enumerates five, and the real canvas body has seven counting
    // `setNeedsDisplay()`/`refreshSelectionUI()`) and, as guidance Task 26 reads, a number invites
    // "I did four, done" instead of checking against the real body. Task 26 carries the canvas body in
    // verbatim and must NOT treat this placeholder body as the already-correct core to preserve — the
    // canvas body's other side effects (the `imageObjectDeletePending` stash, `finalizeMarkedText()`,
    // `clearStructuralSelections()`, `dismissEditMenuForSelectionOrTextChange()`,
    // `setNeedsDisplay()`/`refreshSelectionUI()`, `onSelectionChange?()`), the nil-collapse and the
    // clamping are ALL still Task 26's to add, not already-delivered behavior.

    var selectedTextRange: UITextRange? {
        get {
            // UNORDERED by construction: `.start`/`.end` (`LegacyTextRange.from`/`.to`) report
            // anchor/head VERBATIM, never `min`/`max`. `RichTextCanonicalSelection.normalizedRange`'s
            // own doc comment: "the canvas hands UIKit an unordered range for a reversed drag and
            // that is load-bearing."
            //
            // TASK 35 — WHICH STORE THIS READS. `canonicalSelectionStorage`, unconditionally, and
            // there is no longer a second store it could read instead.
            //
            // Task 26 wrote the opposite here, correctly for its own tree: "Until Task 35 moves
            // `anchor`/`head` storage onto this backend, the CANVAS is the live selection authority
            // … reading the canonical store here would hand UIKit a stale caret after any of those
            // operations", and it read `legacyCanvas.anchor`/`.head` with the canonical store as a
            // fallback for the "no canvas" window. **This is the task that expires that**: those two
            // reads were the ONLY `legacyCanvas.anchor`/`.head` reads in the tree, and after the
            // canvas properties became forwarders they would have been a round trip
            // (backend → canvas forwarder → this backend's own stored property) on the hottest path
            // in the editor. The D24 clause-(b) exception list is down to `markedRange` and
            // `typingWritingDirection` accordingly — retired in both copies of the rule
            // (`LegacyRichTextInputHost.swift` and the `legacyCanvas` accessor above), in this commit.
            //
            // The "no canvas" fallback the guard existed for is gone with it: this backend's own
            // store is now the answer in every state, attached or not.
            return LegacyTextRange(LegacyTextPosition(canonicalSelectionStorage.anchor.utf16Offset),
                                     LegacyTextPosition(canonicalSelectionStorage.head.utf16Offset))
        }
        set {
            // The load-bearing floating-cursor invariant (see `floatingCursorActive`'s own doc
            // comment above): ignore a write while the floating-cursor gesture owns the caret. It sits
            // FIRST, exactly as it did in the canvas witness this body replaces, so none of the canvas
            // side effects below run for an ignored write either.
            //
            // FIX ROUND 1 (review Minor 7): this guard sits AHEAD of `setSelection`'s own `isAttached`
            // violation report, so a write reaching here while BOTH the flag is latched AND the
            // backend is detached is dropped silently rather than reported. Accepted as-is rather than
            // reordered.
            //
            // FIX ROUND 2 (review item 2): corrected reasoning — detach clears the flag and nothing
            // calls `begin` on a detached backend today; note `begin`/`end` carry no `isAttached`
            // guard, so the combination is reachable in principle — Task 33 should add it. **TASK 33
            // ADDED IT** (the silent form, on all three members — `+FloatingCursor.swift`).
            //
            // **TASK 33 COLLAPSED TASK 26'S DOUBLE READ, which was a bridge with an expiry date.**
            // Task 26 had to consult BOTH this flag and the canvas's, because the real hold-spacebar
            // gesture wrote only the canvas's; reading the backend's alone turned
            // `FloatingCursorTests.test_selectedTextRange_ignoredDuringFloatingCursor` RED, and that
            // measurement is why the `||` existed. The gesture now routes through
            // `beginFloatingCursor(at:)`/`endFloatingCursor()` (`+FloatingCursor.swift`), which write
            // THIS flag, so the canvas half of the read is gone — and with it the D24 clause-(b)
            // exception for `legacyCanvas?.floatingCursorActive`, which is retired from the list in
            // `LegacyRichTextInputHost.swift` and from its copy above.
            //
            // **What makes the collapse safe is NOT that the backend is now a writer — it is that the
            // backend's flag is cleared on every path that clears the canvas's.** `cancelFloatingCursor()`
            // clears only the canvas's, so without that mirror an interrupted gesture would latch this
            // guard `true` forever and drop every later selection write, silently. The four cancel
            // paths and who answers each are enumerated in `+FloatingCursor.swift`'s header;
            // `FloatingCursorRouterTests` pins the two live ones by asserting that a write AFTER an
            // interrupted gesture is honoured.
            guard !floatingCursorActive else { return }
            // TASK 26 — the canvas half, VERBATIM, through one D24 hook: the `imageObjectDeletePending`
            // stash, `finalizeMarkedText()`, `clearStructuralSelections()`,
            // `dismissEditMenuForSelectionOrTextChange()`, the unordered `from`/`to` read with the
            // `?? 0` nil-collapse and `clamp()` on BOTH endpoints, and `setNeedsDisplay()`. The hook's
            // own doc comment (`+UITextInput.swift`) records why its last two statements
            // (`refreshSelectionUI()`, `onSelectionChange?()`) are NOT in it: `setSelection`'s
            // publication below delivers exactly those two, in that order, through the presentation
            // and lifecycle clients. Emitting them in both places would double every selection report.
            let applied = legacyCanvas?.legacyApplySelectedTextRange(newValue)
            // With no attached canvas there is no `documentSize` to clamp against, so the raw
            // (nil-collapsed) offsets stand — the pre-Task-26 behavior of this member, minus its
            // outright DROP of a nil/non-`LegacyTextRange` write, which the canvas has always
            // collapsed to offset 0 instead. See the D27 divergence note in the task report.
            let raw = newValue as? LegacyTextRange
            let anchorOffset = applied?.anchor ?? (raw?.from.offset ?? 0)
            let headOffset = applied?.head ?? (raw?.to.offset ?? 0)
            // A `UITextRange`-shaped write reaching this witness is UIKit driving the selection
            // (keyboard cursor-drag / autocorrect) — there is no other origin. Routed through the
            // ONE whole-selection write, not a second, independently-implemented publish path.
            setSelection(RichTextCanonicalSelection(anchor: .downstream(anchorOffset),
                                                    head: .downstream(headOffset)),
                        reason: .keyboard)
        }
    }

    // MARK: - External synchronization

    func synchronizeAfterExternalChange(_ change: RichTextInputExternalChange) {
        guard isAttached else {
            RichTextInputContractViolation.report("operation on a detached backend: \(#function)")
            return
        }
        // TASK 22g — the spec's deferral rule: "No callback between preparation and commit may
        // publish an external document change. Such a request is deferred until the transaction
        // returns to `.idle`." Processing it inline here (while some OTHER operation's own
        // notify/commit/publish bracket is still open) would interleave a host-driven synchronization
        // into the middle of that in-flight transaction. Stash it instead; `endTransaction()` (the
        // exit path of EVERY mutating member, including this one) drains it once `transactionPhase`
        // genuinely returns to `.idle`. This is NOT a rejection — no contract violation is reported —
        // because a reentrant external change is an expected, ordinary occurrence (a remote update
        // landing while the user is mid-keystroke), not caller misuse.
        guard transactionPhase == .idle else {
            deferredExternalChange = change
            return
        }
        // FIX ROUND 1 — tightened to a true continuity check. The spec requires the backend to
        // "validate revision continuity", which is a property of the PAIR (oldRevision,
        // newRevision), not just the new endpoint: a plain `newRevision >= documentRevision` guard
        // prevents regression but not DISAGREEMENT — a change whose `oldRevision` describes a
        // stale baseline (e.g. the backend is at 5, the change claims oldRevision 3 → newRevision
        // 6) would pass a `>=` check even though its `changedRangeBefore`/`changedRangeAfter` were
        // computed against a baseline the backend never held — precisely the stale-diff race the
        // continuity check exists to catch. So BOTH must hold: `change.oldRevision` must equal
        // what this backend has actually adopted, AND `change.newRevision` must not regress it.
        guard change.oldRevision == documentRevision, change.newRevision >= documentRevision else {
            RichTextInputContractViolation.report(
                "synchronizeAfterExternalChange: revision continuity violated — change describes " +
                "oldRevision \(change.oldRevision) → newRevision \(change.newRevision), but this " +
                "backend has adopted \(documentRevision) — not adopted")
            return
        }
        // FIX ROUND 2 (review Major): routed through `withTransaction(_:)` (`+Attachment.swift`)
        // instead of a hand-paired `activeTransactionDepth += 1` / `endTransaction()` — see that
        // method's own doc comment for why the pair must not be hand-paired at each call site.
        withTransaction {
            transactionPhase = .publishingState
            // TASK 22f: reconcile any locally-tracked marked (composing) range against the three
            // `RichTextMarkedTextPolicy` branches BEFORE adopting `change.newRevision` AND BEFORE
            // adopting `change.selection` — so a `.preserveIfRebasable` rebase (below) reads
            // `change.oldRevision` and sees the STILL-STALE `canonicalSelectionStorage`, matching what
            // the marked range was actually expressed against, rather than values this call has already
            // moved past. (At this point `documentRevision == change.oldRevision` regardless, by the
            // guard just above, so this ordering has no observable effect on `.discard`/
            // `.commitBeforeChange` today — the helper never reads `documentRevision` or
            // `canonicalSelectionStorage` for those two branches. FIX ROUND 1 (review Major 3 / Focal
            // Point 2b): `BackendMarkedTextPolicyTests
            // .test_preserveIfRebasable_rebasesBeforeAdoptingRevisionAndSelection` pins BOTH halves of
            // this ordering via `FakeInputDocumentClient.onRebase`, a reentrant callout sampled from
            // INSIDE the rebase call — the report's original "no test would catch a re-reorder" claim
            // was an over-claim this hook refutes.)
            //
            // FIX ROUND 1 (review Major 3 / Minor 8): the EXTRACTION into
            // `reconcileMarkedTextForExternalChange` below is independently load-bearing, not merely a
            // readability choice — see that method's own doc comment.
            reconcileMarkedTextForExternalChange(change)
            // DEVIATION-adjacent: `.layoutOnly` means ONLY geometry changed (layout generation lives on
            // the geometry client, not here) — the document REVISION must not move, or a later real
            // content change could be mistaken for a no-op against a revision that silently advanced.
            if change.reason != .layoutOnly {
                documentRevision = change.newRevision
            }
            canonicalSelectionStorage = change.selection
            publishState(reason: .externalSynchronization)
        }
    }

    /// TASK 22f. The three `RichTextMarkedTextPolicy` branches of `synchronizeAfterExternalChange`.
    /// Deliberately does NOT route through `prepareAndRun`/`runMutation` (`+Mutation.swift`) for ANY
    /// branch — an external change is host-driven, not a keyboard mutation, and must stay silent on
    /// both the document client (`prepareMutation`/`commitPreparedMutation`) and
    /// `UITextInputDelegate`; routing through the mutation chokepoint here would fire both, turning a
    /// host-driven undo/redo/remote-update into a COUNTERFEIT keyboard mutation
    /// (`BackendMarkedTextPolicyTests.test_undoExternalChange_usesTheDeclaredPolicy_notACounterfeitKeyboardMutation`
    /// pins exactly this).
    ///
    /// FIX ROUND 1 (review Minor 8) — the EXTRACTION into this own method is load-bearing, not just a
    /// readability refactor: `.preserveIfRebasable`'s four failure paths below use a bare `return`.
    /// Were this switch ever inlined back into `synchronizeAfterExternalChange` itself, those
    /// `return`s would skip `publishState`/`endTransaction()` on the way out — wedging
    /// `transactionPhase` at `.publishingState` and stranding any latched detach. A future
    /// "simplify" pass must not re-inline this switch.
    ///
    /// `.discard` and `.commitBeforeChange` are OBSERVABLY IDENTICAL today (both simply clear
    /// `markedRangeStorage`, self-disclosed per the task brief's own vacuity-trap note, and CONFIRMED
    /// stronger on review: the two case BODIES are the same statement, so swapping them, or swapping
    /// the case labels, is a textual no-op — nothing anywhere in the package goes red on that swap).
    /// There is no separately-tracked provisional-vs-committed document delta at this stage-1 storage
    /// level. (TASK 29 CORRECTION: this used to say "see `setMarkedText(_:selectedRange:)`'s own doc
    /// comment below" — that member and its doc comment are no longer on this class. The storage-only
    /// body that made the claim true now lives on `ReferenceMutationBackend`, `T/Support/`, which is
    /// what this suite drives.)
    ///
    /// FIX ROUND 1 (review Major 2) — CORRECTED ORACLE, re-homed to TASK 41 by TASK 29's fix round 1:
    /// the real chokepoint
    /// `.commitBeforeChange` maps to is `legacyCanvas.finalizeMarkedText()`
    /// (`Canvas/DocumentCanvasView+MarkedText.swift:136-147`; plan `:7290,7359,7372`;
    /// live call site `RichTextEditorView.swift:440-441`) — **not** `commitMarkedText()` (an EARLIER,
    /// wrong recording this fix round corrects, here and in the test file). `finalizeMarkedText()` is
    /// TWO-HALVED, and both halves matter for TASK 41 (this said "Task 29" until Task 29's fix round 1
    /// re-homed the whole block; see the correction below the two bullets):
    ///   - a genuine COMPOSITION is COMMITTED (`commitMarkedText()`: one undo step from
    ///     `compositionUndoSnapshot`, no text mutation, no revision bump, no delegate notification);
    ///   - a system inline PREDICTION is DISMISSED, never committed (`dismissPrediction()`:
    ///     `applyReplaceOutcome(…, text: "")` removes the ghost, DOES bump the revision, fires
    ///     `textWillChange`/`textDidChange`, and registers NO undo — the ghost is keyboard-owned, not
    ///     user content). The canvas's own comment on this: "Committing a prediction here would desync
    ///     the keyboard's shadow document and duplicate the word on its accept-`replace`."
    /// **TASK 29 CORRECTION — the paragraph that followed named TASK 29 as the owner of this
    /// divergence, and Task 29 is not.** Under the D35 ruling Task 29 routed the marked-text witnesses
    /// as plain `legacyCanvas` forwards; this method still reconciles `markedRangeStorage`, which no
    /// routed member writes any more, so `.commitBeforeChange` and `.discard` are still the same
    /// statement and nothing here reaches `finalizeMarkedText()`. **TASK 41 owns it**, together with
    /// the two-store collapse that makes it reachable at all. Restated in that tense:
    ///
    /// **TASK 41 LOOKED, AND DECLINED — because there is no site to diverge AT.** This paragraph read
    /// "At TASK 41, `.commitBeforeChange` and `.discard` will diverge on (at least) three observables
    /// …: undo-stack depth; a document-revision bump specifically on PREDICTION dismissal (not on
    /// composition commit); and the `textWillChange`/`textDidChange` bracket `dismissPrediction()`
    /// fires". Task 41 measured that **`.commitBeforeChange` has ZERO production call sites** — all
    /// five `synchronizingExternalChange` sites declare `.discard` or `.preserveIfRebasable` — so
    /// building the divergence would have been building a second, differently-spelled `.discard` for
    /// nobody. The three observables above remain the correct oracle for whoever wires the first
    /// `.commitBeforeChange` site; they are pinned as a FACT rather than as a promise by
    /// `MarkedStateAuthorityTests.test_commitBeforeChangeHasNoProductionCallSite`, which fails the
    /// moment such a site appears and points its author back here. Concretely, `BackendMarkedTextPolicyTests
    /// .test_undoExternalChange_usesTheDeclaredPolicy_notACounterfeitKeyboardMutation`'s blanket "no
    /// delegate notifications" assertion holds ONLY for the composition-shaped input it exercises —
    /// **Task 41** needs a PREDICTION-shaped sibling asserting the delegate bracket DOES fire, not a
    /// relaxation of the composition test. See `BackendMarkedTextPolicyTests
    /// .test_predictionShapedSetMarkedText_isTreatedIdenticallyToACompositionAtThisStorageOnlyStage`
    /// (new this fix round) for the fixture this suite was missing entirely: every original test used
    /// a COMPOSITION-shaped `selectedRange` (location 1 or 2); none used the PREDICTION shape
    /// (`selectedRange == {0,0}` plus trailing ghost text) — precisely the input Task 18's
    /// ghost-prediction bug lived in.
    ///
    /// `.preserveIfRebasable` is the one policy that is genuinely different TODAY, in this stage-1
    /// backend, in the sense that it is the only branch with its own code path that touches the
    /// document client (`document.rebase(_:fromRevision:)`) and the only one that CAN keep the marked
    /// range rather than always dropping it.
    ///
    /// FIX ROUND 1 (review Major 4) — DISCLOSED: that "genuinely different" keep path is itself
    /// UNREACHABLE against the real `TelegramDocumentInputClient` by D32 construction, exactly the
    /// same shape `ensureCanonicalSelectionIsCurrent` discloses about itself
    /// (`+Mutation.swift:122-130`). The real client's `rebase` is `fromRevision == revision ? position
    /// : nil` (`Clients/TelegramDocumentInputClient.swift:67-69`); by the time
    /// `synchronizeAfterExternalChange` runs, the host has already applied the change, so
    /// `fromRevision (change.oldRevision) == revision` holds ONLY when the revision did not actually
    /// move — i.e. only for `.layoutOnly` (plan `:7292`).
    ///
    /// **TASK 41 CORRECTION — THE REST OF THIS PARAGRAPH WAS TRUE WHEN WRITTEN AND IS NOW FALSE, AND
    /// THE BODY 80 LINES BELOW IS WHAT MADE IT FALSE.** It read: "For every OTHER reason
    /// (`.formatting` included, despite the plan's stated rationale at `:7291` that 'the text length
    /// does not change, so a marked range survives' — that rationale is unachievable as written, since
    /// `.formatting` still bumps the revision), `rebase` returns `nil` for both endpoints and
    /// `.preserveIfRebasable` degrades to `.discard`. So in PRODUCTION, today, all three policies
    /// collapse to 'drop the composition' except when the reason is `.layoutOnly`."
    ///
    /// The fast path is no longer keyed on the revision at all: it is
    /// `if change.reason.preservesTextOffsets { return }`, and `.formatting` answers "offsets unmoved"
    /// alongside `.layoutOnly`. So the plan's `:7291` rationale is achievable after all — it just could
    /// not be achieved by a revision comparison, which is what "unachievable as written" was really
    /// about. For the six reasons that CAN move text, the sentence still holds verbatim: `rebase`
    /// returns `nil` for both endpoints and `.preserveIfRebasable` degrades to `.discard`.
    ///
    /// (Recorded rather than silently rewritten because this doc comment is the head of the very
    /// method whose body contradicted it, which is the failure mode this file's own history keeps
    /// paying for: a duplicated record is only durable if every task that touches either copy touches
    /// both.) The general D32 identity-or-nil truth already has a dedicated
    /// production-truth test at the real client
    /// (`TelegramDocumentInputClientMutationTests.test_rebase_isIdentityAtTheCurrentRevision_andNilForAStalePriorRevision`)
    /// covering the same claim this branch relies on, so this fix round does not duplicate it here;
    /// `test_preserveIfRebasable_keepsMarkedRange_whenRebaseSucceeds`'s "keep" path is reachable ONLY
    /// through the FAKE's `rebaseResultsQueue`, configured to return a non-identity result D32 says the
    /// real client never returns — worth flagging so a future reader does not mistake it for a
    /// production-reachable path. The `.formatting` mapping is flagged for Task 39/39b, which owns
    /// routing host-originated changes (including deciding what `.formatting` should actually do here).
    private func reconcileMarkedTextForExternalChange(_ change: RichTextInputExternalChange) {
        switch change.markedTextPolicy {
        case .discard:
            // The host already applied the change; drop the composition WITHOUT asking the document
            // client to change anything — the whole point of this policy is that there is nothing
            // left for the backend to do.
            //
            // TASK 41: widened to the whole composition inventory (see `clearCompositionStorage()`).
            // This branch now runs against a store that is genuinely non-nil, for the first time.
            clearCompositionStorage()
        case .commitBeforeChange:
            // See this method's own doc comment (Major 2 correction): bookkeeping-only, same
            // OBSERVABLE effect as `.discard` at this stage — the real divergence needs a
            // `finalizeMarkedText()` forward reached from HERE. TASK 29 CORRECTION: that used to say
            // "Task 29's", and Task 29's forward does not reach this method — it routed the witnesses
            // as plain `legacyCanvas` forwards, leaving this reconciliation on the parallel
            // `markedRangeStorage`. **Task 41 owns it.** TASK 41: it turns out there is nothing to
            // own — `.commitBeforeChange` has ZERO production call sites (all five
            // `synchronizingExternalChange` sites declare `.discard` or `.preserveIfRebasable`), so
            // the promised divergence has no site to occur at. Pinned by
            // `MarkedStateAuthorityTests.test_commitBeforeChangeHasNoProductionCallSite`, which is
            // where the next task to wire one will find the three observables it must diverge on.
            clearCompositionStorage()
        case .preserveIfRebasable:
            guard let range = markedRangeStorage else { return }
            guard let document = self.document else {
                clearCompositionStorage()
                return
            }
            // **TASK 41 REPLACED THIS FAST PATH'S KEY, AND BOTH THE OLD KEY AND THE OBVIOUS
            // ALTERNATIVE WERE BUILT AND MEASURED RATHER THAN REASONED ABOUT.**
            //
            // It read `guard document.revision != documentRevision else { return }` — the CLIENT's
            // live revision against THIS BACKEND'S CACHE. That key was correct only while the cache
            // tracked the client, and deviation D38 broke exactly that: `documentRevision` advances
            // only inside `synchronizeAfterExternalChange` and `prepareAndRun`, and no routed witness
            // reaches `prepareAndRun`, so ordinary typing moves the canvas's counter and leaves this
            // backend's at whatever the last external sync adopted. Until Task 41 the damage was
            // invisible because `markedRangeStorage` was uniformly nil and the `guard let range` above
            // returned first. This is the commit that makes it non-nil, and the failure it produces is
            // the one Task 39b's D38 note predicted verbatim: a width reflow during a composition
            // (rotation, keyboard-height change, composer resize mid-IME) skips the fast path, rebases
            // from a baseline the real client does not hold, gets `nil` from an identity-or-nil rebase,
            // and **silently degrades `.preserveIfRebasable` to `.discard`.** MEASURED at step 3 of
            // this task, before the fix: `MarkedStateAuthorityTests
            // .test_aWidthReflowDuringACompositionKeepsTheMarkedRange` red with
            // `("nil") is not equal to ("Optional({2, 2})")`, plus both `.formatting` siblings.
            //
            // **The fix D38's obligation literally asks for — pass the canvas's own counter as
            // `oldRevision` — was ALSO built, and it is worse.** All five production sites then report
            // `synchronizeAfterExternalChange: revision continuity violated — change describes
            // oldRevision 2 → newRevision 3, but this backend has adopted 0 — not adopted`, which is
            // an `assertionFailure` in DEBUG. It does not even repair this branch: the two `.formatting`
            // sites stayed red, because the rebase they reach still has no baseline the client holds.
            // That obligation's own precondition — "once the backend owns the mutation path, its
            // counter advances independently" — is NOT met by this task, which moves composition state
            // and does not touch the mutation path. It is re-homed to whichever stage-2 task routes
            // mutations through `prepareAndRun`; `oldRevision` keeps its D38 meaning for the continuity
            // guard, which is now its ONLY consumer that can change an outcome.
            //
            // What replaces it asks the question this branch actually has: **did anything move under
            // the marked range?** A marked range is a pair of offsets; it survives verbatim exactly
            // when the change moved no text. `preservesTextOffsets` (`RichTextInputTypes.swift`)
            // answers that from `change.reason`, exhaustively and with no `default`. Trusting the
            // reason is not a new liberty: `synchronizeAfterExternalChange` already skips adopting
            // `change.newRevision` on `case .layoutOnly` alone, on the same claim from the same
            // origination point — and unlike the two revision counters, the reason is never stale.
            //
            // `test_preserveIfRebasable_skipsRebase_whenTheRevisionHasNotMoved` (which drives
            // `.layoutOnly`) still pins `rebaseCallCount == 0` here, and
            // `MarkedStateAuthorityTests`' three preservation arms pin the production sites.
            //
            // **ONE DISCLOSED CONTRACT CHANGE, since the key changed AXIS and not just authority**
            // (TASK 41 FIX ROUND 1, review m5). The old guard was REVISION-scoped and reason-blind: it
            // kept the range for ANY reason whenever the revision had not moved. The new one is
            // REASON-scoped and revision-blind. The two differ on one input shape — a
            // `.preserveIfRebasable` change carrying a text-MOVING reason whose revision nevertheless
            // did not move — where the old key returned early and the new one makes two `rebase`
            // callouts. The OUTCOME is identical against the real `TelegramDocumentInputClient`
            // (equal revisions ⇒ identity rebase ⇒ the same range back), and no production site
            // produces that shape today, since the only reason that leaves the revision unmoved is
            // `.layoutOnly`, which the new key catches. It is stated anyway because it is a change in
            // what this branch ASKS, and a future document client whose `rebase` is not
            // identity-or-nil would answer differently; `BackendMarkedTextPolicyTests`' rebase-count
            // assertions are what stands between that and a silent behaviour change.
            if change.reason.preservesTextOffsets { return }   // nothing moved: keep the range as it stands
            // D32: `rebase(_:fromRevision:)` is identity-or-nil — a stale endpoint is rebased or
            // rejected, never remapped. A non-collapsed marked range needs its own rebase call per
            // endpoint (mirrors `ensureCanonicalSelectionIsCurrent`'s treatment of the canonical
            // selection's anchor/head, `+Mutation.swift`), short-circuiting on the FIRST failure —
            // D32's rule is AT MOST ONE rebase attempt per distinct offset, never a retry — so a
            // doomed range never spends a second rebase call.
            //
            // TASK 22g RESOLUTION (was FIX ROUND 1 (review Minor 5)'s open labelling note): judged and
            // KEPT AS `.publishingState`, not relabeled. `document.rebase` runs here under
            // `transactionPhase == .publishingState`, set by `synchronizeAfterExternalChange` at ITS
            // OWN entry — before this call, before the revision/selection adoption below it, and
            // before the eventual `publishState` call. That looks premature read as "we are
            // publishing", but it is the SAME convention every other single-bracket member already
            // uses: `setSelection` and `clearCompositionState` both set
            // `transactionPhase = .publishingState` immediately at entry too, despite each having its
            // own pre-publish work (storage writes) between that assignment and the member's actual
            // `publishState` call. (TASK 29 CORRECTION: this list named `setMarkedText` as a third such
            // member and said "these four". That member is no longer on this class — Task 29 routed it
            // and its storage body moved to `ReferenceMutationBackend`, where it still uses exactly
            // this convention, which is why the argument is unchanged and only the count is.)
            // None of these three members has a separate `RichTextInputTransactionPhase`
            // case for "single bracket in progress, not idle, no notify sub-phase" — only
            // `runMutation` (`+Mutation.swift`), which DOES have distinct notify/commit sub-phases,
            // needs (and has) `.notifyingWillChange`/`.mutatingDocument`/`.notifyingDidChange` as
            // intermediate labels. Adding a NEW phase case just for this one call site (e.g.
            // `.synchronizingExternalChange`) would single out `synchronizeAfterExternalChange` from
            // its three siblings for no functional reason: every reentrancy guard this task adds
            // (`prepareAndRun`'s phase check, `synchronizeAfterExternalChange`'s own deferral guard)
            // keys on `transactionPhase == .idle` / `!= .idle`, never on which NON-idle case it is, so
            // the specific label carries no gating behavior to get right or wrong.
            //
            // FIX ROUND 1 (review Focal Point 3) — the reviewer verified this by grep (every
            // `transactionPhase` READ in the package compares against `.idle`; no `switch`, no
            // `case .publishingState`, no test reading a non-idle value) and UPHELD the label. The one
            // thing genuinely missing was a PIN of 22f's own claim — "a reentrant `detach()` from
            // inside `rebase` still latches correctly" — which is now
            // `test_detachFromInsideAPreserveIfRebasableRebaseCallout_stillLatchesToTheBoundary`
            // (`BackendReentrancyTests.swift`), using `FakeInputDocumentClient.onRebase` (the
            // reentrant callout Task 22f added for exactly this kind of probe).
            //
            // One small, disclosed cost of keeping the label: `prepareAndRun`'s reentrancy-violation
            // message (`+Mutation.swift`) interpolates `\(transactionPhase)`, so a reentrant mutation
            // from inside THIS rebase callout reports "while transactionPhase is publishingState" — a
            // diagnostic that reads as if the backend were mid-publish, when it is really mid-external-
            // synchronization. `+Mutation.swift`'s message now adds one clarifying clause for this
            // case rather than gaining a new enum case just to make the diagnostic more specific.
            guard let rebasedStart = document.rebase(
                .downstream(range.location), fromRevision: change.oldRevision
            ) else {
                clearCompositionStorage()
                return
            }
            guard let rebasedEnd = document.rebase(
                .downstream(range.location + range.length), fromRevision: change.oldRevision
            ) else {
                clearCompositionStorage()
                return
            }
            let lo = min(rebasedStart.utf16Offset, rebasedEnd.utf16Offset)
            let hi = max(rebasedStart.utf16Offset, rebasedEnd.utf16Offset)
            // FIX ROUND 2 (review Minor 2) — collapse a zero-length result to `nil`, mirroring
            // `setMarkedText`'s own empty-collapses-to-nil convention (below): `isComposing` must never
            // read `true` while composing nothing. Production-unreachable today on its own (D32 makes
            // the KEEP path itself unreachable outside `.layoutOnly`, which now takes the fast path
            // above and never reaches this line at all) — but
            // `test_preserveIfRebasable_rebasesBeforeAdoptingRevisionAndSelection`'s `onRebase` probe
            // configures BOTH endpoints to rebase to the identical offset (0), producing exactly this
            // zero-length shape, which is why it needed catching rather than left as a latent
            // inconsistency the fixture happened not to previously observe.
            //
            // TASK 41: the KEEP path writes the RANGE only, deliberately — the prediction flag and the
            // composition-start snapshot travel WITH the composition being preserved and must not be
            // reset by a rebase. The collapse-to-nil path clears the whole inventory, because that is
            // the composition ending.
            if hi > lo {
                markedRangeStorage = NSRange(location: lo, length: hi - lo)
            } else {
                clearCompositionStorage()
            }
        }
    }

    // MARK: - Marked text — ROUTED BY TASK 29, in `LegacyRichTextInputBackend+MarkedText.swift`
    //
    // `markedTextRange` and `setMarkedText(_:selectedRange:)` used to live HERE, with storage-only
    // bodies over `markedRangeStorage` that Task 22f wrote ahead of schedule (so
    // `BackendMarkedTextPolicyTests` had something real to reconcile the three
    // `RichTextMarkedTextPolicy` branches against) under a 25-line header disclosing everything they
    // did NOT do. TASK 29 supplied the real forward those bodies were a placeholder for, so the header
    // and both bodies are gone from this file:
    //
    //   * the REAL members are now plain `legacyCanvas` forwards in `+MarkedText.swift`, alongside
    //     `markedTextStyle`, `unmarkText()` and the three composition-lifecycle entry points; and
    //   * the storage-only bodies moved VERBATIM to the test-only `ReferenceMutationBackend`
    //     (`T/Support/`), which `BackendMarkedTextPolicyTests` now runs against — the same re-homing
    //     Task 27b did for `insertText(_:)`'s transaction and Task 28 for `deleteBackward()`'s.
    //
    // `markedRangeStorage` (declared above) is therefore NO LONGER WRITTEN by any member of this
    // class's own marked-text surface. Its remaining writers are `runMutation` (`+Mutation.swift`),
    // `reconcileMarkedTextForExternalChange` (below), `clearCompositionState()` and
    // `finalizeMarkedTextForDetach()`; its only reader is `state`. The routed `markedTextRange` reads
    // the CANVAS's `markedRange` instead. That two-store split is a real, disclosed divergence Task 41
    // closes — `+MarkedText.swift`'s header states it in full, including why keeping a storage write
    // here as well would make it worse rather than better.

    // MARK: - Attach-time helpers (this task's own, not routed members; and not stubs — the
    // pending-routing machinery is GONE as of Task 34, and the file that held it is `+Unwitnessed.swift`)
    //
    // TASK 34 FIX ROUND 1 (review Minor 1): this MARK still read "`+PendingRouting` stubs" after the
    // rename sweep that repaired four other citations, and it CONTRADICTED that commit's own message
    // ("no doc comment names a file that does not exist"). **The sweep was keyed to the `.swift`
    // suffix and to doc-comment syntax; this is a MARK comment naming the file without its extension,
    // so neither key matched.** Rule 17 again, in a new variant: a sweep keyed to one comment syntax
    // will not see another, and a sweep keyed to a filename will not see the basename.

    /// Seeds `documentRevision` and the canonical selection from the host's document client. Called
    /// once, from `attach(to:)`, before `isAttached` flips true.
    func installInitialState(from host: any LegacyRichTextInputHost) throws {
        let client = host.documentClient
        documentRevision = client.revision
        let clamped = client.clamp(.downstream(0))
        canonicalSelectionStorage = .caret(at: clamped)
    }

    /// TASK 22f: `markedRangeStorage` now holds real (if storage-only, see `setMarkedText`'s own doc
    /// comment) composition state, so a composition left active at detach must not survive into a
    /// later `attach()` — mirrors how `performDetachSteps()` already resets
    /// `suppressesSelectionNotifications`/`floatingCursorActive`. Bookkeeping-only, same as
    /// `reconcileMarkedTextForExternalChange`'s `.discard`/`.commitBeforeChange` branches — and, per
    /// this method's own precedent before this task, deliberately does NOT report a contract
    /// violation, because teardown is not caller misuse. Called from `performDetachSteps()` (spec
    /// step 3, documented "commit or discard marked text" — `+Attachment.swift:84`).
    ///
    /// FIX ROUND 1 (review Minor 7) — the forward note here was only HALF recorded (undo registration
    /// only). Completing it: this unconditional discard is eventually replaced by
    /// `finalizeMarkedText()`'s semantics (see `reconcileMarkedTextForExternalChange`'s own doc
    /// comment, Major 2 correction) — a genuine composition is COMMITTED (one undo step), a genuine
    /// PREDICTION is DISMISSED (ghost removed, no undo). Idempotency, the no-violation choice, and
    /// no-survival-into-reattach (`test_markedTextIsNotMigratedAcrossDetachAndReattach`) all still hold
    /// regardless of which of those two is needed at any given detach.
    ///
    /// **TASK 29 CORRECTION — the note above used to name TASK 29 as the task that does it, and Task
    /// 29 deliberately did not.** Under the D35 ruling Task 29 routed the marked-text witnesses as plain
    /// `legacyCanvas` forwards, which leaves the real composition on `canvas.markedRange` and this
    /// discard operating on the now-parallel `markedRangeStorage`. Calling `legacyCanvas?.finalizeMarkedText()`
    /// from here would be a real BEHAVIOUR CHANGE at detach (a live prediction's ghost text would start
    /// being removed from the document during teardown) that no step of Task 29's brief asked for.
    /// **Task 41 owns it**, together with the two-store collapse that makes it coherent.
    func finalizeMarkedTextForDetach() {
        // TASK 41: widened to the whole composition inventory. A detach that left a
        // composition-start snapshot behind would hold the whole pre-composition document alive on a
        // backend the host has already let go of.
        clearCompositionStorage()
    }

    // MARK: - The one publication path (spec step 9)

    /// Assembles the snapshot, hands it to the presentation client, then to the lifecycle client —
    /// in that order. Call it exactly once per operation; `endTransaction()` follows it.
    ///
    /// The presentation snapshot's caret/selection-segment/interaction fields are placeholders
    /// (`nil` / `[]` / `.inactive`) because no geometry or interaction witness routes yet (Task 20's
    /// opening line: "No witnesses route yet") — Tasks 25/32-34 make them real. `isFirstResponder` is
    /// real today: `hostInputView` is a plain `UIView`/`UIResponder`, so reading it is an ordinary
    /// UIKit query, not a `legacyCanvas` escape-hatch use.
    ///
    /// FIX ROUND 1 (review Focal Point 1, consequence 3 — `endTransaction()`'s own doc comment,
    /// `+Attachment.swift`, names this as the residual gap its nesting-depth fix does NOT close): the
    /// LIFECYCLE client's delivered state is now read FRESH (`state`, not the `snapshot` captured
    /// above `presentationClient.apply(...)`) — so if that `apply` callout triggers a NESTED
    /// `setSelection`/`clearCompositionState`/`setMarkedText` (none of which is rejected; see
    /// `endTransaction()`'s note), the OUTER publish this method still delivers afterward carries the
    /// CURRENT truth rather than the state as it stood before the nested call ran. Pinned by
    /// `BackendReentrancyTests.test_nestedSetSelection_publishesTheFreshStateNotAStaleSnapshot`.
    /// Deliberately narrow: the PRESENTATION client's `apply(presentationSnapshot)` call above is
    /// UNCHANGED and still uses the captured `snapshot`.
    ///
    /// FIX ROUND 2 (review Minor) — CORRECTED WORDING: "nothing has run yet at that point" was
    /// inaccurate, not merely imprecise. Two callouts genuinely DO run between `let snapshot = state`
    /// and this `presentationClient.apply(presentationSnapshot)` call: `presentationClient.visibleBounds`
    /// (an arbitrary client getter, read while building `presentationSnapshot` above) and
    /// `host.hostInputView.isFirstResponder`. For the real client, `visibleBounds` is
    /// `canvas.viewportRect()` (`Clients/TelegramPresentationInputClient.swift` →
    /// `Canvas/DocumentCanvasView.swift`), which reads `superview`/`contentOffset`/`bounds` and
    /// mutates nothing; `isFirstResponder` is a plain UIKit query. Both are INERT for every client in
    /// this tree (a stored property on the fake; a pure geometry read on the real one) — so the
    /// CONCLUSION still holds (there is no staleness to fix on the presentation path, and widening
    /// this to re-read state a second time there would be a change with no observable case behind it)
    /// — but the reason is "inert in practice", not "nothing has run". This is a fix to the SHARED
    /// `publishState` helper, not a per-member reentrancy guard — it does not reject, defer, or skip
    /// any bracket, so it stays within the scope this task owns (nesting-awareness of the shared
    /// machinery) rather than the member-level rejection left to Task 26/29/41. See
    /// `endTransaction()`'s own doc comment (`+Attachment.swift`) for this fix's EXPIRY — which TASK 26
    /// RESOLVED IN THE NEGATIVE: its member-level reentrancy guard landed, and the freshening is
    /// KEPT, because the guard performs the nested storage write before skipping its bracket, so the
    /// re-read is still load-bearing. **The expiry is now owned by TASK 35**, and that note carries the
    /// empirical check, the two shapes that WOULD retire it (hard rejection, or defer-and-replay via the
    /// `deferredExternalChange` pattern), and the enumeration a future owner must do to choose between
    /// them. Until then this is a LIVE mitigation, not a settled contract.
    func publishState(reason: RichTextInputStateChangeReason) {
        guard let host else { return }
        let presentationClient = host.presentationClient
        let snapshot = state
        let presentationSnapshot = RichTextInputPresentationSnapshot(
            state: snapshot,
            caret: nil,
            visibleSelectionSegments: [],
            visibleBounds: presentationClient.visibleBounds,
            isFirstResponder: host.hostInputView.isFirstResponder,
            selectionDisplayVisible: false,
            interaction: .inactive)
        presentationClient.apply(presentationSnapshot)
        host.lifecycleClient.backendDidPublishState(state, reason: reason)
    }
}
#endif
