#if canImport(UIKit)
import UIKit

/// TASK 33 — Family 10 (floating cursor and autoscroll). THREE routed backend members, each a plain
/// forward onto a renamed canvas witness body:
///
///   1. `beginFloatingCursor(at:)` -> `legacyCanvas?.legacyBeginFloatingCursor(at:)`, then sets the flag
///   2. `updateFloatingCursor(at:)` -> `legacyCanvas?.legacyUpdateFloatingCursor(at:)` (**deviation D2 —
///      no `animated:`; UIKit's real requirement has none**)
///   3. `endFloatingCursor()` -> `legacyCanvas?.legacyEndFloatingCursor()`, then clears the flag
///
/// **STATE MOVED AT TASK 42 — this paragraph used to say it did not.** Task 33 moved only WHO WRITES the
/// suppression flag; Task 42 moved the STATE. `floatingCursorActive`, `floatingCursorPoint` and
/// `floatingScrollVelocity` are backend storage (`LegacyRichTextInputBackend.swift`) and the canvas keeps
/// read-only projections. What still does NOT move: the two `CADisplayLink`s (a display link retains its
/// target, and `DocumentCanvasView.willMove(toWindow:)` is the only teardown for them — Task 6's retain
/// cycle), `TransientCaretView`, and the alpha-0.4 landing caret. Those are presentation.
///
/// **The three forwards are BARE — no bracket, no publication — and that is measured, not assumed.**
/// `legacyBeginFloatingCursor` already calls `notifyingSelectionChangeIgnoringCoalescing` (for the
/// collapse-to-head, and only when `anchor != head`), and `legacyEndFloatingCursor` already calls
/// `onSelectionChange?()`. Adding either here would double it.
///
/// # ONE store called `floatingCursorActive` — TASK 42 COLLAPSED THE TWO
///
/// Until Task 42 there were two: `DocumentCanvasView.floatingCursorActive` (the PRESENTATION flag — the
/// dimmed landing caret in `updateCaretView()`, `floatingAutoScrollTick`'s guard) and this backend's (the
/// SUPPRESSION flag the `selectedTextRange` setter consults, made the real gesture's flag by Task 33).
/// **They are now one**, on the backend, and the canvas's is a get-only projection. Every sentence below
/// that used to have to say WHICH flag now means the only one there is.
///
/// Before Task 33 the real hold-spacebar gesture wrote only the CANVAS's, and the setter's guard read
/// `backendFlag || canvasFlag` as a deliberate bridge (Task 26's own note at the setter recorded that
/// reading only the backend's flag turned `FloatingCursorTests.test_selectedTextRange_ignoredDuringFloatingCursor`
/// RED, and instructed Task 33 to collapse it once the backend became the writer). **That collapse is
/// done**, and the D24 clause-(b) exception for `legacyCanvas?.floatingCursorActive` is RETIRED rather than
/// merely unused — the read is gone, so the entry is gone from `LegacyRichTextInputHost.swift`'s list and
/// from its copy in `LegacyRichTextInputBackend.swift`.
///
/// # THE INTERRUPTION LATCH — the defect Task 33 created and answered, and what Task 42 changed about it
///
/// This is the load-bearing section of the file, because the failure mode is silent and permanent.
///
/// `DocumentCanvasView.cancelFloatingCursor()` tears a gesture down when the OS will not deliver
/// `endFloatingCursor`. Once this backend writes the flag on `begin`, an interrupted gesture that failed to
/// clear it would leave `true` forever; with the setter's guard on that one flag,
/// `guard !floatingCursorActive else { return }` would be true for the rest of the editor's life and
/// **every subsequent `selectedTextRange` write would be silently dropped.** No crash, no log, no build
/// error — the editor would simply stop accepting OS selection changes.
///
/// **TASK 42 CLOSED THE HOLE AT ITS SOURCE:** `cancelFloatingCursor()` now clears THE flag (through
/// `setFloatingCursorActive(false)`, a contract door), because there is only one. The four production paths
/// are therefore all covered by that method itself:
///
/// | Path | Reaches cancel via | Also clears here |
/// |---|---|---|
/// | resign first responder | `hostWillResignFirstResponder()` -> `legacyWillResignFirstResponder()` | that member, `+Responder.swift` |
/// | removal from window | `hostWillMove(toWindow:)` -> `legacyWillMove(toWindow:)` | that member, `+Responder.swift` (mirroring its `nil` branch) |
/// | detach step 2 | `cancelActiveInteraction(reason:)` -> `legacyCanvas?.cancelFloatingCursor()` | that member, `+Interaction.swift` |
/// | detach step 7 | presentation client -> `legacyTearDownPresentation()` | `performDetachSteps()`'s hygiene reset, **moved by Task 42 to after step 2** |
///
/// **The three Task-33 mirror clears in column 3 are now REDUNDANT with the cancel's own, and they are
/// KEPT.** Two reasons, both load-bearing rather than sentimental: each is reached through an OPTIONAL
/// `legacyCanvas?`, so with no canvas attached the mirror is the only clear there is; and each member's own
/// doc comment argues that the invariant should be a property of the member, not of its caller's ordering
/// — the shape this file's re-entrancy note calls a defect. Their tests
/// (`FloatingCursorRouterTests`' three `…ClearsTheBackendsFlag` cases, two of which continue past the flag
/// to assert that a `selectedTextRange` write AFTER an interruption is honoured) stay exactly as they were.
///
/// **THE GAP TASK 33 RECORDED IS CLOSED.** That entry read: `TelegramPresentationInputClientTests
/// .test_tearDownPresentationCancelsAnActiveFloatingCursor` calls `tearDownPresentation()` directly and
/// ends with the two stores disagreeing — canvas `false`, backend `true`. With one store they cannot
/// disagree; that test now asserts the only flag there is.
///
/// **The detach ordering it depended on INVERTED, and that is Task 42's one behaviour change.** Task 33's
/// version of the fourth row said the path was covered "because step 1's hygiene block already cleared this
/// flag before step 7 runs". With one store that early clear is exactly the bug: it makes
/// `cancelFloatingCursor()`'s own `guard floatingCursorActive` return before
/// `transientCaretView.hide(animated: false)`, leaving a stuck BRIGHT caret on a detached canvas. Task 32
/// predicted this in writing and dated it to Task 42; it was MEASURED (red) before the reset was moved. The
/// full account is at the moved line in `+Attachment.swift`, pinned by
/// `FloatingCursorStateAuthorityTests.test_detachHidesTheTransientCaret`.
///
/// **Why `cancelFloatingCursor()` may write backend state at all, when Task 33 argued it must not.** That
/// argument was "a canvas body reaching this backend's store inverts the ownership direction the seam is
/// establishing, and could not be spelled through the contract anyway (`DocumentCanvasView.inputBackend` is
/// typed `any RichTextInputBackend`)". The second half is what changed: Task 42 puts
/// `setFloatingCursorActive(_:)` ON the contract, so the write is a contract call like every other canvas
/// door call (`setCanonicalAnchor`, `setCompositionMarkedRange`), not a reach into a concrete class. The
/// ownership direction is intact — the backend owns the store and vends the door.
///
/// **MEASURED, not argued — each mirror clear was deleted in turn and the suite re-run** (this file's
/// standard: an enforcement claim is a testable claim). These were run at TASK 33, against the two-store
/// tree; they are recorded as history, not re-run at Task 42, where the cancel's own clear would mask them:
///
///   * drop `hostWillResignFirstResponder()`'s clear -> **RED**, and it fails on the SELECTION-WRITE
///     assertion, not merely the flag: the post-resign write is dropped and `selFrom` stays where the
///     gesture left the caret. That is the production bug, reproduced. R17 stays **GREEN** — `.statements`
///     constrains what a body MAY contain, never what it must, which is the boundary this file's R17
///     entries record.
///   * make `hostWillMove(toWindow:)`'s clear unconditional -> **RED** on
///     `test_enteringAWindowMidGestureDoesNotClearTheBackendsFlag`, and **RED** on R17 too (the exact-text
///     statement pin carries the branch).
///   * drop `cancelActiveInteraction(reason:)`'s clear -> **RED** on its own test, which calls the member
///     directly rather than through detach, so detach's hygiene reset cannot mask it.
///
/// # `hostWillMove(toWindow:)` mirrors a BRANCH, and the branch is load-bearing
///
/// The canvas hook cancels only when `newWindow == nil`. An unconditional mirror clear would drop the
/// suppression during a live gesture whenever UIKit announced ANY window change — the exact invariant
/// this family exists for, lost in the opposite direction. So the backend member carries
/// `if window == nil`, which duplicates a decision Task 31 deliberately left on the canvas; the
/// duplication is disclosed at that member and pinned by
/// `FloatingCursorRouterTests.test_enteringAWindowMidGestureDoesNotClearTheBackendsFlag`.
///
/// **The non-nil case a test can actually drive is ENTERING a window, not re-parenting inside one** —
/// UIKit does not call `willMove(toWindow:)` at all when the view's window is unchanged, which made the
/// first version of that test vacuous (it passed under the mutation). The test's own doc comment carries
/// the measurement.
///
/// # The `isAttached` guard (Task 26 deferred it here BY NAME), and how it interacts with the latch
///
/// Task 26's fix-round-2 note at the `selectedTextRange` setter says `begin`/`end` "carry no `isAttached`
/// guard, so the combination is reachable in principle — Task 33 should add it". All three members now
/// carry the **silent** form, which is Task 31 §6's settled class for this shape: these are OS-driven
/// gesture entry points, not content/selection-mutating members, and `RichTextInputContractViolation.report`
/// calls `assertionFailure` in DEBUG when no reporter is installed, so a report on a path that is silent
/// today would convert a benign detached call into a debug crash.
///
/// **The guard wraps BOTH the forward and the flag write, and that is what keeps a detached backend out
/// of the latch rather than into it.** The obvious worry — "a flag cleared behind an `isAttached` guard
/// leaves a detached backend latched" — does not arise, because the guard is symmetric: a detached
/// `begin` sets nothing, so there is nothing for a detached `end` to fail to clear, and `detach()` itself
/// clears the flag on the way out. The two stores stay in lockstep while detached by both being untouched.
///
/// # Statement ORDER: forward FIRST, then write the flag — **and as of TASK 42 tests DO protect it**
///
/// Task 22e's Major 3b/3c notes made this a hard requirement in both directions
/// (`legacyBeginFloatingCursor` before `floatingCursorActive = true`, `legacyEndFloatingCursor` before
/// `= false`). The reason was entirely forward-looking: **from Task 42 the canvas's property is a
/// projection of THIS store**, at which point the canvas bodies' own guards (`guard !floatingCursorActive`
/// at begin, `guard floatingCursorActive` at end) read this flag. Write first and both bodies return
/// immediately — a permanent no-op.
///
/// **Task 33's version of this section ended "no test in this tree can catch it being reversed". That
/// sentence expired with this task, and the replacement is a measurement rather than a prediction.** With
/// both writes moved above their forwards, `FloatingCursorTests` goes **RED with 3 failures**:
/// `test_begin_collapsesRangedSelection` (`("2") is not equal to ("5")` — begin never ran, so the ranged
/// selection was never collapsed), `test_perUpdate_doesNotFireOnSelectionChange_endFiresOnce`
/// (`("0") is not equal to ("1")` — end never published) and
/// `test_steadyCaret_isDimmedLandingDuringGesture` (`0.4` vs `1.0` — the landing caret never un-dimmed).
/// So the constraint is now behaviourally pinned in both directions, by tests that predate it and were
/// never written for it. R17 still pins only the SET of statements in these bodies, never their order —
/// that half is unchanged, and it is why the behavioural pin matters.
///
/// # Re-entrancy (Task 22e's Major 3c) — DISCHARGED, and by construction rather than by luck
///
/// That note asked Task 33 to add a re-entrancy guard "rather than rely on this placeholder being
/// idempotent by accident". The renamed canvas bodies bring the real guards with them, and because the
/// forward runs BEFORE the flag write, a re-entrant `begin` reaches
/// `legacyBeginFloatingCursor`'s `guard !floatingCursorActive` while the canvas's flag is still `true` —
/// so the collapse, the edit-menu dismissal and the transient-caret show do not run twice, exactly as
/// before the seam. The backend's own write is idempotent (`= true` over `true`).
///
/// **No SECOND guard is added on this side, deliberately**, and the reason is a divergence rather than a
/// preference: a `guard !floatingCursorActive` here would consult the BACKEND's store, so if the two ever
/// disagreed it would skip a legitimate `begin` that the pre-seam witness would have run. The canvas's
/// guard is the one the witness had; it still runs; that is the behaviour-preserving answer.
///
/// # The four-axis divergence audit for the family, plus the fifth
///
/// 1. *Clamp vs reject* — no clamping surface anywhere in this family. `point` is forwarded verbatim;
///    the snapping to a grapheme boundary happens two levels down, inside `resolveFloatingCaret()`.
/// 2. *nil / wrong-type input* — no member takes an optional. Detached: silent, per the ruling above.
/// 3. *Which store is read* — the whole task; see the two-store section. The members WRITE the backend's
///    and reach the canvas's only through the forward.
/// 4. *Which object owns the consulted flag* — it MOVED, in the sense that matters: the flag the
///    `selectedTextRange` setter consults is now this backend's, where before Task 33 the live gesture
///    could only ever have satisfied that guard through the canvas's.
/// 5. *Does this family promote a witness-local to backend state?* (Task 31's standing fifth axis) — **no.**
///    `floatingCursorActive` was never a local; it was a canvas FIELD, and the backend's copy has existed
///    since Task 22e. The risk that applied instead was its inverse — two stores for one fact — which is
///    what the latch section is about and what **Task 42 removed**, along with the canvas's stores for
///    `floatingCursorPoint` and `floatingScrollVelocity`.
@available(iOS 13.0, *)
extension LegacyRichTextInputBackend {

    /// Reached from `DocumentCanvasView.beginFloatingCursor(at:)`, the UIKit witness, which is now a
    /// one-line router.
    ///
    /// The forward runs first and the flag write second. **Since TASK 42 that is pinned
    /// BEHAVIOURALLY** — the canvas body's own `guard !floatingCursorActive` reads this store now, so
    /// writing first makes `legacyBeginFloatingCursor` a no-op. Reversing the two writes here and in
    /// `endFloatingCursor()` reddens three `FloatingCursorTests` cases (`Executed 17 tests, with 3
    /// failures`); the header's ORDER section carries the measurement.
    ///
    /// **THIS SENTENCE USED TO READ "…including why no test can currently catch that being reversed",
    /// which Task 42 falsified.** It was the third of three copies of that claim; the other two (the
    /// file header and `+Unwitnessed.swift`) were corrected in the Task-42 commit and this one, the
    /// copy sitting directly above the code it describes, was missed. Recorded rather than silently
    /// swapped, because the lesson is the general one: **a corrected claim needs a grep for every
    /// instance of the old sentence, not just the instance that prompted the correction.**
    func beginFloatingCursor(at point: CGPoint) {
        guard isAttached else { return }
        legacyCanvas?.legacyBeginFloatingCursor(at: point)
        floatingCursorActive = true
    }

    /// **DEVIATION D2** — no `animated:` parameter; UIKit's real `UITextInput` requirement has none, and
    /// the plan's `(at:animated:)` spelling is the deviation, not this.
    ///
    /// The only member of the three that writes no flag: the gesture is already live by the time UIKit
    /// samples it, and the pre-seam body's own `guard floatingCursorActive` (now
    /// `legacyUpdateFloatingCursor`'s) still decides whether a sample does anything.
    func updateFloatingCursor(at point: CGPoint) {
        guard isAttached else { return }
        legacyCanvas?.legacyUpdateFloatingCursor(at: point)
    }

    /// Reached from `DocumentCanvasView.endFloatingCursor()`. The canvas body publishes
    /// `onSelectionChange?()` itself, so this member adds nothing.
    ///
    /// Same order requirement as `beginFloatingCursor(at:)`, in the other direction: clearing the flag
    /// before the forward would, from Task 42 on, make `legacyEndFloatingCursor`'s
    /// `guard floatingCursorActive` skip hiding the transient shadow caret.
    func endFloatingCursor() {
        guard isAttached else { return }
        legacyCanvas?.legacyEndFloatingCursor()
        floatingCursorActive = false
    }

    // MARK: - TASK 42 — the three raw state doors
    //
    // The canvas's own floating bodies used to write three canvas fields; those fields are now
    // read-only projections and these three doors are the writes. **Raw and NON-PUBLISHING**, exactly
    // like the D33 selection pair and Task 41's composition pair, and for the same reason: the canvas
    // bodies that call them already emit their own delegate brackets and host hooks, so a publishing
    // door would add a host report at sites that reported nothing before the seam.
    //
    // **No `isAttached` guard on any of the three, deliberately.** They are not entry points — every
    // caller is a canvas body that is itself already downstream of an `isAttached`-guarded backend
    // member, or is `cancelFloatingCursor()`, which detach step 2 calls *while tearing down* (so a
    // guard would make it a no-op at the one moment it must run). The D33 pair carries no guard either,
    // on the same reasoning, and `RichTextInputContractViolation.report` is an `assertionFailure` in
    // DEBUG — a report here would convert a benign teardown call into a debug crash.
    //
    // Enumerated, per file, by `InputBackendSourceBoundaryTests
    // .test_theWriteDoorsIntoBackendOwnedInputStateAreEnumerated`: the R7 write scan cannot see a
    // `.`-qualified call, so an exact call-site allowance is the only mechanism there is.

    func setFloatingCursorActive(_ active: Bool) {
        floatingCursorActive = active
    }

    func setFloatingCursorPoint(_ point: CGPoint) {
        floatingCursorPoint = point
    }

    func setFloatingScrollVelocity(_ velocity: CGFloat) {
        floatingScrollVelocity = velocity
    }
}
#endif
