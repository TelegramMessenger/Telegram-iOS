#if canImport(UIKit)
import UIKit

/// TASK 31 — Family 8 (responder lifecycle, edit policy, traits notification). TWELVE backend members,
/// reached two different ways. SIX canvas WITNESSES land on TEN of them: `canBecomeFirstResponder`,
/// the NEW `canResignFirstResponder` override, `becomeFirstResponder()` (three members: will / did /
/// did-fail), `resignFirstResponder()` (three more), `willMove(toWindow:)`, and `isEditable` -> the
/// D3-renamed `isEditableForWritingTools`. The remaining TWO are notifications the canvas raises from
/// its own `didSet`s rather than witnesses: `editPolicyDidChange()` (wired since Task 20) and
/// `textInputTraitsDidChange()` (wired by this task).
///
/// # Six canvas hooks, not three — and the count is the finding
///
/// The task brief's Produces block named THREE `legacy…` hooks. **The real number is six**, and the
/// three extra ones are not decoration; each exists because a segment boundary in the pre-seam body is
/// a place where behaviour is observable.
///
///   1. `legacyDidBecomeFirstResponder()` — caret/handles/writing-directions.
///   2. `legacyMarkDidJustBecomeFirstResponder()` — the transition-only flag write.
///   3. `legacyFinishBecomingFirstResponder()` — native-checking install + preheat + `lastCheckedCaret`.
///   4. `legacyWillResignFirstResponder()` — finalize marked text, break undo coalescing, cancel the
///      floating cursor.
///   5. `legacyDidResignFirstResponder()` — hide caret/handles, clear the focusing-tap flag.
///   6. `legacyWillMove(toWindow:)` — the `newWindow == nil` display-link teardown.
///
/// **(2) and (3) exist because the brief's decomposition would have shipped two behaviour changes.**
/// The brief described `legacyDidBecomeFirstResponder()` as "the post-become body minus the transition
/// test", carrying `didJustBecomeFirstResponder = true` among other things, and called
/// unconditionally before the transition gate. Measured against the real body, that is wrong twice:
///
///   * **`didJustBecomeFirstResponder = true` IS the transition test**, not something beside it. It sat
///     inside `if became && !wasFirstResponder`, on the same line as `onBecameFirstResponder?()`.
///     Setting it unconditionally would set it on a REPEAT become — and repeat becomes are a live
///     production path, not a hypothetical one: the chat composer focuses the editor on touch-DOWN
///     (`ChatTextInputPanelNode`'s `TouchDownGestureRecognizer` -> `ensureFocusedOnTap()` ->
///     `RichTextEditorChatInputNode.makeInputFirstResponder()` -> `RichTextEditorView.becomeFirstResponder()`
///     -> `DocumentCanvasView.becomeFirstResponder()`), and none of those four hops tests
///     `isFirstResponder` first. The panel's touch-down handler even branches on
///     `isInputFirstResponder == true` and calls `ensureFocusedOnTap()` anyway, merely deferred by
///     0.05s. `DocumentCanvasView+Interaction.swift`'s own `ensureFirstResponder()` DOES guard, which
///     is what makes this easy to miss: the guarded path is the one inside the package.
///     `performSingleTap` then computes `wasFirstResponder = wasFirstResponderAtEntry && !justFocused`,
///     so a wrongly-`true` flag classifies every tap in a focused composer as FOCUSING and **the edit
///     menu stops toggling**. The suite had three assertions on that flag — first-become, post-resign
///     and windowless-failure — and none for a repeat become;
///     `ResponderRouterTests.test_aRepeatBecomeFirstResponderDoesNotSetTheFocusingTapFlag` is the one
///     that was missing.
///   * **The native-checking install must stay AFTER the host callback.** In the real body
///     `installNativeCheckingIfNeeded(); nativeChecker?.preheat(); lastCheckedCaret = head` runs after
///     — since TASK 34 the first of those three is `inputBackend.installCheckingIfNeeded()` (D37), which
///     changes who owns the call but not where it sits in the order this paragraph is about —
///     `onBecameFirstResponder?()`. Folding it into the same hook as the caret work moves it ahead.
///     `onBecameFirstResponder` reaches the composer through
///     `TelegramLifecycleInputClient.backendDidBeginEditing()` on a path the composer drives on every
///     touch-down, so "the host callback cannot observe the install" is not a claim available cheaply.
///     Preserved rather than argued away, and pinned by
///     `…test_becomeFirstResponder_runsTheNativeCheckingInstallAfterTheHostCallback`.
///
/// **The resign side is ASYMMETRIC, and the brief is right about it** — worth stating, because the
/// asymmetry is exactly what makes the become side's extra hook necessary rather than fussy. There,
/// `didJustBecomeFirstResponder = false` is its OWN un-gated `if resigned` line; only
/// `onResignedFirstResponder?()` is transition-gated. So one post-hook plus a gated
/// `backendDidEndEditing()` is faithful, and no third hook is needed.
///
/// **(6) is simply a hook the Produces block did not list at all.** `willMove(toWindow:)` keeps `super`
/// on the canvas and moves its `newWindow == nil` body, exactly like the other two witnesses.
///
/// # `isFirstResponder` is read through the HOST, not through `legacyCanvas`
///
/// `wasFirstResponderAtWill` could have been captured as `legacyCanvas?.isFirstResponder` — a plain,
/// branchless property read, i.e. D24 clause (b) on its face. **It is not**, for the reason Task 30
/// declined `legacyCanvas?.effectiveUndoManager`: the clause-(b) exception list
/// (`LegacyRichTextInputHost.swift`) has ONE criterion — every entry is a store Phase 5 moves onto the
/// backend — and `isFirstResponder` is `UIResponder`'s own state, which will never be the backend's in
/// stage 1 or stage 2. A permanent entry on a list of temporary ones is how a documented exception
/// becomes a precedent.
///
/// **FIX ROUND 2 — this sentence used to end "…and that list is prose-enforced: nothing mechanical
/// would have caught it." That was MEASURABLY FALSE, and it was false the moment it shipped rather
/// than having gone stale: the pin that falsifies it landed in the SAME commit.** R17 lists
/// `hostWillBecomeFirstResponder()` as
/// `.statements(allowed: ["wasFirstResponderAtWill = host.hostInputView.isFirstResponder"])`, an
/// exact-text pin, so substituting `legacyCanvas?.isFirstResponder` reddens the source-boundary suite.
/// Re-measured at fix round 2 by applying exactly that substitution: **RED**. Two review passes read
/// the sentence and did not test it, which is the argument for testing an enforcement claim instead of
/// reading it.
///
/// **What IS still prose-only, stated narrowly because the narrowness is the point:** the D24 exception
/// LIST itself. R17 reaches a member only if `routedBackendMembers` names it AND that member's shape
/// pins what it may reach — `.statements`' exact-text prefixes, `.canvasForward`'s `legacyCanvas?.legacy`
/// requirement, `.client`'s no-canvas rule. Measured at fix round 2 on a member R17 does not list
/// (`finalizeMarkedTextForDetach()`): a new clause-(b) read added there is **GREEN**, and so is an
/// unprefixed clause-(a) violation. So adding an entry to that list is still an unenforced act; adding
/// one *by editing one of the pinned members* is not.
///
/// `host.hostInputView.isFirstResponder` is the blessed spelling already used by `publishState`
/// (`LegacyRichTextInputBackend.swift`), whose own comment records why it is an ordinary UIKit query
/// rather than an escape-hatch use. **TASK 31 ADDS NO NEW CLAUSE-(b) EXCEPTION.** (TASK 33 later
/// REMOVED one — `floatingCursorActive` — the first entry ever to expire; `LegacyRichTextInputHost.swift`
/// records it, and the ordinal is gone from every copy of the rule as a result.)
///
/// # A FIFTH divergence axis, beyond the standard four: a stack local became shared state
///
/// The four-axis audit is written per member below. This family raises a fifth axis the standard four
/// do not name, and it is worth stating once here because it is a property of the DECOMPOSITION rather
/// than of any single member: `wasFirstResponder` used to be a **stack local**, and
/// `wasFirstResponderAtWill`/`wasFirstResponderAtWillResign` are **shared mutable backend state**. A
/// local is re-entrancy-proof by construction; a shared field is not.
///
/// **The window is the whole span from the `hostWill…` write to the `hostDid…` read, NOT just the
/// callbacks this backend makes.** FIX ROUND 1 (review Min-2) corrects the first version of this
/// paragraph, which enumerated only the latter and is a good illustration of why that is not enough.
/// Inside the window:
///
///   * **`super.become/resignFirstResponder()`** — the widest opportunity by far, and the one the
///     original note omitted. It runs arbitrary UIKit code and brings up or dismisses the keyboard,
///     posting its notifications synchronously.
///   * **`canvas.legacyDidBecomeFirstResponder()`** — on the become side, this also precedes the read.
///   * `backendDidBeginEditing()` -> `canvas.onBecameFirstResponder?()`, host code that may call
///     `becomeFirstResponder()` again; and `finalizeMarkedText()` inside
///     `legacyWillResignFirstResponder()`, which mutates the document and can reach host `onChange`.
///
/// **The concrete failure, so this is a named risk rather than a caveat:** host code re-entering
/// `becomeFirstResponder()` during `super` runs a nested `hostWillBecomeFirstResponder()` that captures
/// `true` — `super` has already flipped `isFirstResponder` — clobbering the outer frame's `false`. The
/// outer frame then skips the transition and `onBecameFirstResponder` never fires. Pre-seam, the outer
/// **stack local** survived that nesting and the callback fired.
///
/// **No divergence observed today, and the claim is scoped to what was actually checked rather than
/// asserted over the whole app.** Inside this package, every re-entrant call site is
/// `+Interaction.swift`'s `ensureFirstResponder()`, which is guarded by `if !isFirstResponder`; the two
/// unguarded in-package calls (`selectAcrossBlocks`/`selectAcrossLeafRegions`) are demo helpers that
/// run from neither the window nor a host callback. Outside it, the host callback this member fires
/// lands on `RichTextEditorChatInputNode`'s `chatInputTextNodeDidBeginEditing()` forward, and **the
/// panel's own reaction to that was not traced to a fixed point** — so "no re-entrant path" is a
/// statement about the paths that were read, not a proof. That is precisely the "true when written"
/// shape this header's axis-4 note warns about, which is why the fix below is written down as a
/// standing instruction rather than a hypothetical.
///
/// **What would break it, and the fix:** moving either read to AFTER a re-entrant statement, or adding
/// a second read. Whoever does either must first capture the field into a `let` at the TOP of the
/// `hostDid…` member and read the local thereafter. Not applied here: it is a behaviour-shape change
/// with no observed failing case, inside a zero-behaviour-change commit. The general form of this rule
/// — it applies to ANY witness-local promoted to backend state, and Families 9-11 have candidates —
/// is recorded at the fields themselves in `LegacyRichTextInputBackend.swift`, which is where a future
/// family task must go to declare one.
///
/// # The three Bool getters answer `true`, with no `isAttached` guard
///
/// `canBecomeFirstResponder`, `canResignFirstResponder` and `isEditableForWritingTools` were
/// `pendingRouting(); return false` stubs. Today's WITNESS values are all `true`: the canvas's
/// `canBecomeFirstResponder` override was a literal `true`, there was no `canResignFirstResponder`
/// override at all (so `UIResponder`'s documented `true` applied), and `isEditable` was a literal
/// `true`. So the routed bodies answer `true` — **and they deliberately have no
/// `guard isAttached else { return }` prelude**, because for a `Bool` getter that idiom silently means
/// `return false`, and a `canBecomeFirstResponder` that answers `false` during teardown is a canvas
/// that cannot take focus, with no test to see it. There is no fallback branch to get wrong: the value
/// is `true` attached or detached, which is what the pre-seam witnesses answered in both states.
///
/// # Detached guards are SILENT, superseding a written instruction
///
/// The handoff's next-action block and the Task-29 ledger both say `editPolicyDidChange()` and
/// `textInputTraitsDidChange()` "are programmatically reachable, so they take the *reporting* guard."
/// **That instruction is superseded, by the coordinator who wrote it**, and it is recorded here rather
/// than silently ignored because the wrong version is written in three places:
///
///   1. The convention this codebase actually records is behaviour preservation relative to the
///      REPLACED body (`+Unwitnessed.swift`, `insertDictationResult`'s note). The members that
///      report — `insertText`, `deleteBackward`, `setSelection`, `clearCompositionState`,
///      `setMarkedText`, `synchronizeAfterExternalChange` — are the content/selection MUTATING ones.
///      Both of these are notifications replacing a silent no-op with no detached guard at all.
///   2. `editPolicyDidChange()` already ships the silent guard, and its silence is an adjudicated
///      review outcome (task-22i Minor 3) cross-referenced from a second file.
///   3. Reporting is not free: `RichTextInputContractViolation.report` calls `assertionFailure` in
///      DEBUG when no reporter is installed, so adding a report on a path that is silent today
///      converts a benign detached call into a debug crash — a behaviour change, in a phase whose
///      premise is zero behaviour change.
///
/// Cost if this ruling is wrong: a host bug that calls either member while detached goes unreported in
/// stage 1. Task 41 or stage 2 can add reporting deliberately.
///
/// **One disclosure rather than a fix.** The `guard isAttached` on `hostWillResignFirstResponder()`
/// makes previously-UNCONDITIONAL canvas work (`finalizeMarkedText`, `breakUndoCoalescing`,
/// `cancelFloatingCursor`) conditional. Unreachable today, for ONE reason and one only — stated as one
/// rather than dressed up as two: `inputBackend.detach()` has exactly one caller, `DocumentCanvasView`'s
/// `deinit` (D18), so a canvas that is alive enough to receive `resignFirstResponder()` always has an
/// attached backend. If a future task ever detaches a live canvas (stage 2's
/// `RichTextInputCanvasFactory` is the plausible place), this guard silently drops a composition
/// commit and leaks a floating-cursor display link.
@available(iOS 13.0, *)
extension LegacyRichTextInputBackend {

    // MARK: - The three Bool getters

    /// Was `DocumentCanvasView.canBecomeFirstResponder`, whose whole body was the literal `true`.
    ///
    /// **The four-axis divergence audit, per axis.**
    /// 1. *Clamp vs reject* — N/A. No arguments, no bounds.
    /// 2. *nil / wrong-type input* — no input. **NO detached divergence**, deliberately: see the header
    ///    note on why these three have no `isAttached` prelude. The answer is `true` in every state,
    ///    which is what the witness answered in every state.
    /// 3. *Which store is read* — none. It reads no canvas state today and must not start: there is no
    ///    edit-policy gate here (`ResponderLifecycleCharacterizationTests
    ///    .test_canBecomeFirstResponder_isUnconditionallyTrue` pins that), and adding one would be a new
    ///    behaviour rather than a routed one.
    /// 4. *Which object owns the consulted flag* — nothing is consulted.
    var canBecomeFirstResponder: Bool { true }

    /// A **NEW** override on the canvas side: `DocumentCanvasView` declared no
    /// `canResignFirstResponder`, so `UIResponder`'s own implementation applied, and its documented
    /// default is `true`. Answering `true` here therefore preserves behaviour exactly — that is the
    /// whole reason the brief could add a witness where none existed. Restated rather than left to be
    /// re-derived: if this ever answers `false`, `super.resignFirstResponder()` starts refusing and the
    /// editor cannot give up focus.
    ///
    /// The audit is `canBecomeFirstResponder`'s, verbatim, on all four axes.
    var canResignFirstResponder: Bool { true }

    /// DEVIATION D3 — was `DocumentCanvasView.isEditable`
    /// (`+UITextInput.swift`, `@available(iOS 18.0, *)`), whose whole body was the literal `true`. It
    /// tells the system the view supports editing so Writing Tools can apply results in place.
    ///
    /// Renamed and UN-GATED on purpose. The witness keeps UIKit's own iOS-18 availability; this member
    /// carries none above the package's iOS 13 floor (hard invariant 12), so the responder contract is
    /// one existential surface rather than one whose shape depends on the deployment target. The name
    /// changes because `isEditable` already means something far broader on the contract side
    /// (`RichTextInputEditPolicy.isEditable`, the whole-editor gate), and a witness-named member would
    /// read as that.
    ///
    /// **It is NOT gated on `RichTextInputEditPolicy.allowsWritingTools`, and that is deliberate.** The
    /// policy field exists and would be the obvious consultation, but the pre-seam witness consulted
    /// nothing; wiring it here would be a new behaviour in a zero-behaviour-change phase. Whoever makes
    /// the policy live owns connecting the two.
    ///
    /// The audit is `canBecomeFirstResponder`'s on all four axes.
    var isEditableForWritingTools: Bool { true }

    // MARK: - Becoming first responder

    /// Captures the fact the pre-seam body captured in its `wasFirstResponder` local, at the same
    /// instant: BEFORE `super.becomeFirstResponder()` flips it. `hostDidBecomeFirstResponder()` reads
    /// it to decide whether this is a genuine not-focused -> focused transition.
    ///
    /// Read through `host.hostInputView`, never `legacyCanvas` — the header states why at length; the
    /// short version is that `isFirstResponder` is not a store Phase 5 moves onto the backend, so a
    /// clause-(b) read of it would be a never-expiring entry on a list of temporary ones.
    ///
    /// **When detached this returns without capturing, leaving a stale value — and that is not
    /// observable**, because `hostDidBecomeFirstResponder()` carries the identical guard and returns
    /// before it could read one. Stated so a future reader does not "fix" it into a write that would
    /// then be the only thing distinguishing the two paths.
    ///
    /// **The four-axis divergence audit, per axis.**
    /// 1. *Clamp vs reject* — N/A.
    /// 2. *nil / wrong-type input* — no input. Detached: silent, per the header's ruling.
    /// 3. *Which store is read* — `host.hostInputView.isFirstResponder`, which for the real host IS the
    ///    canvas (`DocumentCanvasView.hostInputView { self }`) — the same object the pre-seam local
    ///    read, one hop apart, and the same object `FakeInputHost` vends.
    /// 4. *Which object owns the consulted flag* — the flag MOVED: `wasFirstResponder` was a local on
    ///    the canvas's stack, `wasFirstResponderAtWill` is backend state
    ///    (`LegacyRichTextInputBackend.swift`). Its validity window is exactly this call to the
    ///    matching did/did-fail call, which is the same window the local had.
    func hostWillBecomeFirstResponder() {
        guard isAttached, let host else { return }
        wasFirstResponderAtWill = host.hostInputView.isFirstResponder
    }

    /// The success path. Runs the two unconditional segments of the pre-seam post-`super` body around
    /// the transition-gated one, in the original order:
    /// caret/handles -> (flag, host callback) -> native-checking install.
    ///
    /// `host.lifecycleClient.backendDidBeginEditing()` is what reaches `canvas.onBecameFirstResponder?()`
    /// (`TelegramLifecycleInputClient`) — the same callback, through the seam's declared channel.
    ///
    /// **The four-axis divergence audit, per axis.**
    /// 1. *Clamp vs reject* — N/A.
    /// 2. *nil / wrong-type input* — no input. **Detached is a real axis-2 divergence**: a successful
    ///    become with no host would run none of the three segments, where the pre-seam body ran all of
    ///    them from canvas state alone. Unreachable today (detach happens only at `deinit`), silent for
    ///    the same reason `deleteBackward()`'s is — a `UIResponder` entry point that DEBUG-asserted on a
    ///    documented teardown window would be a trap.
    /// 3. *Which store is read* — `wasFirstResponderAtWill`, captured moments earlier from the canvas;
    ///    the three canvas hooks read the live canvas exactly as before.
    /// 4. *Which object owns the consulted flag* — the gate moved from a stack local to backend state;
    ///    the DECISION it drives is unchanged, and `didJustBecomeFirstResponder` stays canvas-owned and
    ///    written only inside the gate.
    func hostDidBecomeFirstResponder() {
        guard isAttached, let host, let canvas = legacyCanvas else { return }
        canvas.legacyDidBecomeFirstResponder()
        if !wasFirstResponderAtWill {
            canvas.legacyMarkDidJustBecomeFirstResponder()
            host.lifecycleClient.backendDidBeginEditing()
        }
        canvas.legacyFinishBecomingFirstResponder()
    }

    /// The failure path. The spec is explicit: "Failed responder transitions emit no did-begin/did-end
    /// callback", and the pre-seam body agreed — every one of its three post-`super` lines was gated on
    /// `became`. So this emits nothing and touches no canvas hook.
    ///
    /// It clears the capture so the flag never outlives its window. **Disclosed rather than dressed up:
    /// this write is not observable today** — `hostWillBecomeFirstResponder()` overwrites the flag at
    /// the start of every subsequent become, and `hostDidBecomeFirstResponder()` is the only reader. It
    /// is kept because it makes the flag's contract ("valid only between will and did") true by
    /// construction rather than by an argument about call order, which is the kind of argument that
    /// stops holding when someone adds a caller.
    func hostDidFailToBecomeFirstResponder() {
        wasFirstResponderAtWill = false
    }

    // MARK: - Resigning first responder

    /// Runs the pre-seam body's pre-`super` segment and THEN captures the transition fact, in that
    /// order — the original captured `wasFirstResponder` after `finalizeMarkedText()`,
    /// `breakUndoCoalescing()` and `cancelFloatingCursor()`, not before.
    ///
    /// **TASK 33 ADDED THE `floatingCursorActive = false` MIRROR, and it is not hygiene — without it
    /// this member latches the editor's selection handling.** The canvas hook's third statement is
    /// `cancelFloatingCursor()`, which clears the CANVAS's flag only; since Task 33 the backend's own
    /// flag is what the `selectedTextRange` setter consults, so a gesture interrupted by a resign
    /// would leave that guard `true` forever and silently drop every later selection write. Behaviour
    /// PRESERVING, not new: pre-seam there was one flag and this path cleared it. The full four-path
    /// account is in `+FloatingCursor.swift`'s header;
    /// `FloatingCursorRouterTests.test_resignFirstResponderClearsTheBackendsFlag_soLaterSelectionWritesAreHonoured`
    /// is the pin, and it asserts the honoured write rather than only the flag.
    ///
    /// **TASK 42 FIX ROUND 1 (review Major 1) — THAT PIN SENTENCE IS NO LONGER TRUE OF THIS LINE, and
    /// this member is the one of the three mirrors that is special.** Since the store collapse,
    /// `cancelFloatingCursor()` (reached through `legacyWillResignFirstResponder()` on the line above)
    /// clears the same flag, so the named test passes with or without the clear below — measured: the
    /// reviewer deleted all three mirror clears and the entire suite stayed green. And unlike its two
    /// siblings, this member canNOT be the only clear on a canvas-less path: its `guard` binds
    /// `let canvas = legacyCanvas` and RETURNS before reaching the clear. So the "optional forward"
    /// justification recorded elsewhere in the Task-42 commit does not apply here at all.
    ///
    /// **It is kept for the remaining reason, and that reason is enough**: the invariant should be a
    /// property of this member rather than of what its forward happens to do. The canvas-less case is
    /// unreachable here by construction — the only `Sources/` caller is
    /// `DocumentCanvasView.resignFirstResponder()`, and `DocumentCanvasView` IS its own host, so a
    /// call with `host`/`legacyCanvas` nil would have to be dispatched by a deallocated canvas.
    /// **Pinned by `InputBackendSourceBoundaryTests.test_theFloatingCursorMirrorClearsArePresent_R21`**,
    /// a source-level MUST-CONTAIN rule — R17's `.statements` entry for this member lists the same
    /// text but is a MAY-contain rule and cannot catch a deletion. The full per-path table is at the
    /// flag's declaration (`LegacyRichTextInputBackend.swift`).
    ///
    /// **The four-axis divergence audit, per axis.**
    /// 1. *Clamp vs reject* — N/A.
    /// 2. *nil / wrong-type input* — no input. Detached: the previously-unconditional teardown becomes
    ///    conditional, which is the one disclosure the header states in full (one reason, not two:
    ///    `detach()` runs only at `deinit`).
    /// 3. *Which store is read* — `host.hostInputView.isFirstResponder`, same as the become side.
    /// 4. *Which object owns the consulted flag* — `wasFirstResponderAtWillResign` replaces a stack
    ///    local, with the same validity window.
    func hostWillResignFirstResponder() {
        guard isAttached, let host, let canvas = legacyCanvas else { return }
        canvas.legacyWillResignFirstResponder()
        floatingCursorActive = false
        wasFirstResponderAtWillResign = host.hostInputView.isFirstResponder
    }

    /// The success path, and the shape is NOT the mirror of `hostDidBecomeFirstResponder()`. In the
    /// pre-seam body the caret/handle hide and `didJustBecomeFirstResponder = false` were each their own
    /// UN-gated `if resigned` line; only `onResignedFirstResponder?()` was transition-gated. So both
    /// statements live in one hook and the gate wraps only the callback — a second `legacyMark…`-style
    /// hook here would be inventing a distinction the original body does not make.
    ///
    /// **The four-axis divergence audit, per axis.** Identical to `hostDidBecomeFirstResponder()`'s on
    /// axes 1, 2 and 3. On axis 4 it differs in exactly the way described above: the gate covers strictly
    /// less here than it does on the become side.
    func hostDidResignFirstResponder() {
        guard isAttached, let host, let canvas = legacyCanvas else { return }
        canvas.legacyDidResignFirstResponder()
        guard wasFirstResponderAtWillResign else { return }
        host.lifecycleClient.backendDidEndEditing()
    }

    /// The failure path — same contract, and same non-observable clearing write, as
    /// `hostDidFailToBecomeFirstResponder()`. Note that "failure" here is routine, not exceptional:
    /// `UIResponder.resignFirstResponder()` answers `false` whenever the receiver was not the first
    /// responder to begin with, which `ResponderLifecycleCharacterizationTests` records as observed
    /// behaviour that corrected the original brief.
    func hostDidFailToResignFirstResponder() {
        wasFirstResponderAtWillResign = false
    }

    // MARK: - Window movement

    /// Was the `newWindow == nil` half of `DocumentCanvasView.willMove(toWindow:)` —
    /// `stopDragAutoScroll()` + `cancelFloatingCursor()`, which `WindowDetachCharacterizationTests`
    /// calls "the ONLY teardown for the two CADisplayLinks". `super.willMove(toWindow:)` stays on the
    /// canvas; the branch stays inside the moved body, so this member forwards the window argument
    /// unconditionally rather than re-deciding anything.
    ///
    /// A `legacyCanvas` forward with NO `isAttached` prelude — the family-standard shape of
    /// `insertText(_:)`/`deleteBackward()`/`unmarkText()`, and unlike the responder trio above, which
    /// bind `host` because they need the lifecycle client and the first-responder read.
    ///
    /// **TASK 33 ADDED A SECOND STATEMENT, and it carries a BRANCH this member deliberately did not
    /// have.** The canvas hook cancels the floating cursor only when `newWindow == nil`, and since Task
    /// 33 the backend's `floatingCursorActive` is the flag the `selectedTextRange` setter consults, so
    /// the mirror clear has to fire on exactly the same condition:
    ///
    ///   * clear it unconditionally and ANY announced window change drops the suppression mid-gesture —
    ///     the very invariant this family exists for, lost in the opposite direction (pinned by
    ///     `FloatingCursorRouterTests.test_enteringAWindowMidGestureDoesNotClearTheBackendsFlag`, which
    ///     drives the one non-nil case UIKit actually announces: a canvas ENTERING a window. A re-parent
    ///     *within* one announces nothing, so it cannot drive this member at all);
    ///   * omit it and an interrupted gesture latches the guard `true` for the life of the editor,
    ///     silently dropping every later selection write (pinned by
    ///     `…test_windowRemovalClearsTheBackendsFlag_soLaterSelectionWritesAreHonoured`).
    ///
    /// So axis 4 below no longer reads "nothing moved": the `newWindow == nil` DECISION is now
    /// duplicated, on the canvas (where it gates the teardown) and here (where it gates the mirror).
    /// That duplication is a cost, disclosed rather than hidden — the alternative was a canvas body
    /// writing backend state, which inverts the seam's ownership.
    ///
    /// **TASK 42 PREDICTION, CORRECTED: this note said "Task 42 deletes the second store and with it
    /// this branch". Half of that came true.** The second store IS gone — `cancelFloatingCursor()`
    /// clears the one flag through a contract door — but the branch and its clear STAY, and the reason
    /// is the `?` in the line above them: `legacyCanvas?.legacyWillMove(toWindow:)` reaches no canvas
    /// body at all when none is attached, so this clear is the only one on that path. Keeping it also
    /// keeps the invariant a property of THIS member rather than of what its forward happens to do,
    /// which is the same reasoning `cancelActiveInteraction(reason:)` carries. It is redundant on the
    /// attached path and that redundancy is deliberate.
    ///
    /// **FIX ROUND 1 (review Major 1) — the pin sentence that stood here was FALSE and is replaced.**
    /// It claimed `test_windowRemovalClearsTheBackendsFlag_…` and
    /// `test_enteringAWindowMidGestureDoesNotClearTheBackendsFlag` "both still pin it". Neither does:
    /// the first passes on the canvas's own clear if this one is deleted, and the second pins the
    /// BRANCH (that a non-nil window clears nothing), which a deletion satisfies trivially. Measured —
    /// the reviewer deleted all three mirror clears and the whole suite stayed green. The real pins,
    /// added in this fix round, are
    /// `FloatingCursorStateAuthorityTests.test_theMirrorClearsAreTheOnlyClearOnACanvaslessBackend`
    /// (which drives THIS member on a released-host backend, the one configuration where its clear is
    /// observable) and the source-level
    /// `InputBackendSourceBoundaryTests.test_theFloatingCursorMirrorClearsArePresent_R21`.
    ///
    /// **The four-axis divergence audit, per axis.**
    /// 1. *Clamp vs reject* — N/A.
    /// 2. *nil / wrong-type input* — `window` is `UIWindow?` and nil is the ACTIVE case (the teardown
    ///    branch), not the degenerate one; it is forwarded verbatim. **Detached is a real axis-2
    ///    divergence and it is the sharpest one in this family**: dropping this call leaks two
    ///    `CADisplayLink`s that retain the canvas. Unreachable today for the same single reason as
    ///    above, and `WindowDetachCharacterizationTests.test_canvasIsDeallocatedAfterWindowRemoval`
    ///    is the test that would catch a regression on the attached path. Silent, on the same
    ///    precedent: this is a `UIView` lifecycle callback UIKit invokes at arbitrary times.
    /// 3. *Which store is read* — none here; the moved body reads the live canvas.
    /// 4. *Which object owns the consulted flag* — see the Task-33 note above: the `newWindow == nil`
    ///    decision is now made in BOTH places, because the backend must mirror the canvas's cancel onto
    ///    its own flag and must do so on the same condition.
    func hostWillMove(toWindow window: UIWindow?) {
        legacyCanvas?.legacyWillMove(toWindow: window)
        if window == nil { floatingCursorActive = false }
    }

    // MARK: - Edit policy and traits notifications

    /// Wired to a real call site since Task 20: `DocumentCanvasView.editPolicy`'s `didSet` calls
    /// `inputBackend.editPolicyDidChange()`.
    ///
    /// **TASK 31 MOVED THIS MEMBER out of `+Unwitnessed.swift`. THE BODY IS BYTE-FOR-BYTE THE ONE
    /// TASK 22i WROTE; the doc comment moved with it, and the four adjudicated review findings it
    /// records are unchanged in substance.** Stated precisely rather than as a blanket "verbatim",
    /// because the comment IS edited in four places and a reader deserves the list: this paragraph is
    /// new; two `DocumentCanvasView.swift:<line>` citations are dropped rather than repaired (the
    /// register item that line citations here rot silently); the Major-1 grep count gains "three, as of
    /// Task 31"; and the Minor-2 and Minor-3 notes each gain a sentence saying what Task 31 decided
    /// about the follow-up they left open.
    ///
    /// It is not a stub and has not been one since Task 22i, which gave it this real body for
    /// `BackendEditPolicyTests
    /// .test_editPolicyDidChangeToNotEditable_dismissesTheEditMenu_andKeepsTheBackendAttached`. The only
    /// thing Task 31 DECIDED is the question `+Unwitnessed.swift` explicitly deferred to it — whether
    /// this member needed anything ELSE (e.g. interaction with `canBecomeFirstResponder` or responder
    /// resignation). **It does not**, so its `pendingRoutingInventory` entry is gone, together with the
    /// matching hardcoded exception in the Core suite's reconciliation rule. (That rule was R13; TASK 34
    /// DELETED it along with the inventory Set and the `pendingRouting(_:)` funnel it reconciled, so the
    /// pointer is restated rather than left chasing a symbol that no longer exists. What it conveyed:
    /// the entry and the exception had to move in the SAME commit, because the rule asserted both that
    /// the name was still a quoted entry AND that entries == call sites + exceptions.)
    ///
    /// TASK 22i ADDITION — a MINIMAL real body, ahead of Task 31's full responder-lifecycle wiring
    /// (mirrors how Task 22e gave `beginFloatingCursor(at:)`/`endFloatingCursor()` minimal real
    /// bodies ahead of Task 33): dismisses any open edit menu whenever this is called while the
    /// CURRENT policy is not editable — the one `RichTextInputEditMenuDismissReason` case
    /// (`.policyChanged`) this member exists to drive — without detaching or otherwise disturbing the
    /// backend (`BackendEditPolicyTests
    /// .test_editPolicyDidChangeToNotEditable_dismissesTheEditMenu_andKeepsTheBackendAttached`).
    ///
    /// FIX ROUND 1 (task-22i-review.md Major 4) — CORRECTED: this body does NOT observe a
    /// "transition". It compares nothing against a prior value; it dismisses on EVERY call made while
    /// `!isEditable` holds, including a second consecutive one. The transition property (only called
    /// when the policy actually changed) comes entirely from the ONE caller,
    /// `DocumentCanvasView.editPolicy`'s own `didSet` guard (`guard editPolicy != oldValue else {
    /// return }`) — a stage-2 backend inheriting
    /// `test_editPolicyDidChangeToNotEditable_dismissesTheEditMenu_andKeepsTheBackendAttached` may
    /// implement either the "dismiss on every not-editable call" shape here or a real transition
    /// check; the test cannot and does not distinguish them, since it only ever calls this method once
    /// per policy value.
    ///
    /// FIX ROUND 1 (task-22i-review.md Major 1) — THE REACHABILITY ARGUMENT: this IS new behavior on
    /// this call path, not a duplicate of an existing dismiss — the canvas's OWN `editPolicy` `didSet`
    /// contains exactly this one statement and nothing else;
    /// `dismissEditMenuForSelectionOrTextChange()` is reached only from the selection setters,
    /// `editing { }`, and `beginFloatingCursor`, never from a policy change, so there is no prior
    /// dismiss this would duplicate. It is nevertheless ZERO-BEHAVIOR-CHANGE in production TODAY, for
    /// two INDEPENDENT reasons, both required:
    /// 1. **Nothing production-side ever sets `canvas.editPolicy`.** A grep across `submodules/` and
    ///    `Telegram/` finds `editPolicy =` at exactly two sites, both tests
    ///    (`TelegramLifecycleInputClientTests.swift`, `TelegramDocumentInputClientMutationTests.swift`)
    ///    — three, as of Task 31, whose `ResponderRouterTests` adds one more, likewise a test.
    ///    So the `didSet`'s inequality guard never fires in production, and `editPolicyDidChange()` is
    ///    never called at all.
    /// 2. **Even if it were called, the guard below exits immediately** — production's policy is
    ///    `TelegramLifecycleInputClient.editPolicy` -> `canvas.editPolicy`, which defaults to
    ///    `.legacyUnrestricted` (`isEditable == true`), so `guard !editPolicy.isEditable else { return
    ///    }` returns before `dismissEditMenu` is ever reached.
    /// Either gate alone would already make this dormant; BOTH holding is what makes the phase's
    /// "zero behavior change" premise survive a genuinely NEW, real call path rather than a
    /// harmless-because-duplicate one. `RichTextInputEditMenuDismissReason.policyChanged`
    /// (`RichTextInputTypes.swift`) is a sanctioned Task-11 case with this as its only producer
    /// anywhere in the tree — the semantics are not invented, only the wiring is new.
    ///
    /// FIX ROUND 1 (task-22i-review.md Minor 2, recorded not fixed): this member does not call
    /// `pendingRouting()`, so an edit-policy change is not RECORDED anywhere in `pendingRoutingCalls`.
    /// **Task 31 closed the follow-up this note left open** — see the paragraph at the top.
    ///
    /// FIX ROUND 1 (task-22i-review.md Minor 3, recorded): this guard returns SILENTLY when detached —
    /// unlike `insertDictationResult(_:)`, which reports a `RichTextInputContractViolation` when
    /// detached. The asymmetry is deliberate, not an oversight: each choice is the BEHAVIOR-PRESERVING
    /// one relative to the code it replaced. This member's pre-22i body was already a silent
    /// `pendingRouting()` no-op with no detached guard at all, so staying silent when detached
    /// preserves that. Task 31 re-examined this against a written instruction to make it REPORT and
    /// upheld the silence — see this file's header for the three reasons and the supersession record.
    func editPolicyDidChange() {
        guard isAttached, let host else { return }
        guard !host.lifecycleClient.editPolicy.isEditable else { return }
        host.presentationClient.dismissEditMenu(reason: .policyChanged)
    }

    /// DEVIATION D4's other half. The six `UITextInputTraits` witnesses (`autocorrectionType`,
    /// `spellCheckingType`, `inlinePredictionType`, `smartDashesType`, `smartQuotesType`,
    /// `smartInsertDeleteType`) deliberately do NOT route — one of them, `spellCheckingType`, reads
    /// canvas state (`isSpellCheckingEnabled ? .yes : .no`), so a naive extraction would break the
    /// spellcheck toggle. The canvas's `isSpellCheckingEnabled` `didSet` calls this instead.
    ///
    /// **THE EMPTY BODY IS DELIBERATE AND IS THE WHOLE MEMBER TODAY.** The `didSet` already does every
    /// piece of the work: install + preheat, or invalidate + clear the results/alternatives/pending
    /// menu + `setNeedsSpellUnderlineDisplay()`, then `reloadInputViews()` so the keyboard re-reads the
    /// trait. Under this phase's zero-behaviour-change premise there is nothing left for the backend to
    /// do, so this is **a notification the backend does not yet act on** — the same footing as Task 32's
    /// `layoutDidChange(generation:)`, which the plan describes as "stores the generation and does
    /// nothing else … not a missing forward". Said explicitly because an empty function with no such
    /// note reads as an unfinished forward, and this project has twice paid for "reads-as-enforcement,
    /// enforces-nothing".
    ///
    /// The `guard` is likewise deliberate: it does nothing today (both branches return without effect)
    /// and is written to state the convention — silent, per this file's header ruling — and to be the
    /// place a real body goes when one is owed.
    ///
    /// Its cover is `ResponderRouterTests.test_traitsDidChangeFiresWhenSpellCheckingIsToggled`, which
    /// asserts the CANVAS calls it and is unaffected by the body being empty, plus
    /// `…test_traitsDidChangeDoesNotFireWhenSpellCheckingIsSetToItsCurrentValue`, which pins that the
    /// `didSet`'s own `guard oldValue != isSpellCheckingEnabled` still gates the notification.
    func textInputTraitsDidChange() {
        guard isAttached else { return }
    }
}
#endif
