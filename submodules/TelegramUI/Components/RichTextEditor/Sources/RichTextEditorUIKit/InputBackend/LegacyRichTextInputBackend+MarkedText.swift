#if canImport(UIKit)
import UIKit

/// TASK 29 — Family 6 (marked text and prediction). Four witnesses — `markedTextRange`,
/// `markedTextStyle`, `setMarkedText(_:selectedRange:)`, `unmarkText()` — plus the three
/// composition-lifecycle entry points the canvas owns (`commitMarkedText()`, `dismissPrediction()`,
/// `finalizeMarkedText()`), which are NOT UIKit witnesses and therefore not on any protocol.
///
/// The two mutating witnesses are PLAIN D24 forwards, exactly the shape Task 27b gave `insertText(_:)`
/// and Task 28 gave `deleteBackward()` under the user's D35 ruling (Option A, 2026-08-19). The canvas
/// bodies bracket themselves — `legacySetMarkedText` emits a `notifyingContentChange` text bracket AND
/// a separate `notifyingSelectionChangeIgnoringCoalescing` selection bracket plus a
/// `notifyContentSizeChanged()`/`onSelectionChange?()` tail (six recorded events, pinned by exact
/// equality in `MarkedTextTraceCharacterizationTests.test_compositionBeginUpdateCommit_traceAndRevisions`),
/// while `legacyUnmarkText`/`commitMarkedText` emit *nothing at all* (pinned by the same test's
/// `XCTAssertEqual(recorder.kinds, [])`). So a bracket added here would DOUBLE the first and FABRICATE
/// the second — the asymmetry is why the forwards are bare.
///
/// **TWO of these members had real, storage-only bodies before this task, and this task REPLACES them.**
/// Task 22f gave `markedTextRange` and `setMarkedText(_:selectedRange:)` bodies over
/// `markedRangeStorage` ahead of schedule, so `BackendMarkedTextPolicyTests` had something real to
/// reconcile `synchronizeAfterExternalChange`'s three `RichTextMarkedTextPolicy` branches against.
/// Those bodies did not disappear: they moved to the TEST-ONLY reference conformer
/// `ReferenceMutationBackend` (`T/Support/`), and that suite now runs against it — the same re-homing
/// Task 27b did for `insertText(_:)`'s transaction. Nothing about the moved bodies changed; only their
/// home did.
///
/// # THE TWO-STORE DIVERGENCE THIS TASK CREATED — **CLOSED BY TASK 41**
///
/// Task 29 (this file) left two marked-range stores with no member writing both: `markedTextRange`
/// below read the CANVAS's `markedRange`, while `publishState` read `markedRangeStorage`. The
/// consequence it disclosed — "after a real composition commits, `markedTextRange` correctly reads
/// `nil` while `state.isComposing` can still read `true` (and vice versa)" — was never observable in
/// production, for the reason recorded here at the time: `prepareAndRun` has no production caller, and
/// `reconcileMarkedTextForExternalChange` only ever CLEARS or REBASES an already-non-nil store. So
/// `markedRangeStorage` was uniformly `nil` and `state.isComposing` uniformly `false`.
///
/// **TASK 41 collapsed the two into one.** `DocumentCanvasView.markedRange` is now a read-only
/// projection of `markedRangeStorage`, so this file's `markedTextRange` and `publishState` read the
/// same value by construction and cannot disagree. `markedTextRange` still spells its read as
/// `legacyCanvas?.markedRange` rather than reaching `markedRangeStorage` directly — see the next
/// section for why that clause-(b) read is legitimate — and it is now a read THROUGH the projection
/// back into this backend's own store, which is a hop, not a second authority.
///
/// **The thing Task 41 also had to close, and which this header did not predict**: making that store
/// non-nil for the first time activated `reconcileMarkedTextForExternalChange`'s three policy branches
/// against the REAL document client, and its `.preserveIfRebasable` fast path was keyed on a cache
/// deviation D38 had already made stale — so a width reflow during a composition dropped the
/// composition. Measured, then fixed at that method; `MarkedStateAuthorityTests` is the pin.
///
/// # Why the direct `legacyCanvas.markedRange` read is legitimate
///
/// **The argument is the RULE, not a precedent.** D24's prose was amended in Task 29's fix round 1 to
/// state the rule actually in force (see `LegacyRichTextInputHost.swift`, which carries it in full):
/// `legacyCanvas` may be used to (a) invoke a narrowly named canvas hook — the `legacy…` prefix being
/// how a *renamed witness body* earns that status, so an already-narrowly-named member such as
/// `commitMarkedText` needs no rename — and (b) **read canvas-owned state that this backend will own
/// after Phase 5, where the read is a plain property access with no branch and no side effect.**
/// `markedRange` is squarely (b), and it is the fifth such read, not the first: `anchor`/`head`
/// (Task 26), `typingWritingDirection` (Task 25) and `floatingCursorActive` (Task 26) were all already
/// in the tree, unobjected to. All five expire with the stores they read, at Tasks 33/35/41 — and
/// **`floatingCursorActive` has since done so, at Task 33**, the first of the five to go.
/// (The earlier version of this paragraph cited only Task 26's `selectedTextRange` and framed the read
/// as a tension with an absolute rule; the rule was never absolute in practice, and one precedent is a
/// weaker argument than the four that existed.)
///
/// **One way this member deliberately DIVERGES from the precedent it most resembles, disclosed because
/// the resemblance is close enough to mislead.** Task 26's `selectedTextRange` getter has a *storage
/// fallback* for the detached window — `guard let legacyCanvas else { return LegacyTextRange(from
/// canonicalSelectionStorage) }`. `markedTextRange` has none: it returns `nil`. That is the right
/// answer here and the difference is not an oversight. A `markedRangeStorage` fallback would be dead
/// code in stage-1 production (nothing reachable writes that store — see the two-store section below),
/// and worse, it would re-create shape (ii) that the coordinator's supplement §3 ruled dead and that
/// this task's own red-check RC7 measured red: a fallback that answers from `markedRangeStorage` is a
/// fallback that answers stale non-nil after every commit. `nil` — "not composing" — is both honest and
/// the pre-Task-22f stub's own answer.
@available(iOS 13.0, *)
extension LegacyRichTextInputBackend {

    // MARK: - `markedTextRange`

    /// Was `DocumentCanvasView.markedTextRange`; the `(from, to)` → `LegacyTextRange` projection is
    /// VERBATIM, only its home changed. It REPLACES the Task-22f body that read `markedRangeStorage`
    /// (see the header's two-store section for why that shape is dead, and `ReferenceMutationBackend`
    /// for where it went).
    ///
    /// **The four-axis divergence audit, per axis.**
    /// 1. *Clamp vs reject* — N/A. The witness clamped nothing and rejected nothing; it projects a
    ///    stored pair of offsets. `LegacyTextPosition` performs no bounds work either.
    /// 2. *nil / wrong-type input* — no input. **The DETACHED path is a real axis-2 divergence, and it
    ///    is the same one every other routed member carries**: with no `legacyCanvas` this answers
    ///    `nil`, where the pre-seam witness kept projecting live canvas state through the five windows
    ///    `+TextReads.swift`'s Task-24 fix note enumerates. `nil` is also the honest answer here — "not
    ///    composing" — and it is what the pre-Task-22f `+Unwitnessed.swift` stub returned. No
    ///    `RichTextInputContractViolation` is reported: UIKit polls `markedTextRange` on the keyboard's
    ///    per-keystroke evaluation path, so this follows `text(in:)`'s precedent rather than
    ///    `beginningOfDocument`'s.
    /// 3. *Which store is read* — the CANVAS's `markedRange`, NOT `markedRangeStorage`. This is the
    ///    axis the header's two-store section is about; read it before changing this line.
    /// 4. *Which object owns a consulted flag* — none. `markedTextIsPrediction` (the canvas's) is NOT
    ///    consulted: the witness never distinguished a prediction from a composition, and neither does
    ///    this. `MarkedTextTraceCharacterizationTests.test_predictionVsComposition_isDistinguishedBySelectedRange`
    ///    pins that distinction where it actually lives, inside the moved body.
    var markedTextRange: UITextRange? {
        guard let m = legacyCanvas?.markedRange else { return nil }
        return LegacyTextRange(LegacyTextPosition(m.from), LegacyTextPosition(m.to))
    }

    // MARK: - `markedTextStyle`

    /// Was `DocumentCanvasView.markedTextStyle` — `get { nil } set { }`, VERBATIM. We draw our own
    /// underline decoration (`drawMarkedTextUnderline`), so there is no system styling to vend and
    /// nothing to remember when UIKit sets one.
    ///
    /// **This REPLACES a plain stored property** (`var markedTextStyle: [NSAttributedString.Key: Any]?`
    /// on `LegacyRichTextInputBackend` itself), and the replacement is load-bearing rather than
    /// tidying: routing the witness onto storage would be a BEHAVIOUR CHANGE — after
    /// `canvas.markedTextStyle = x` the getter would answer `x` where it has always answered `nil`.
    /// `MarkedTextRouterTests.test_markedTextStyleGetterIsNilAndSetterIsANoOp` is the guard.
    ///
    /// The four axes are all degenerate here and that is worth saying rather than omitting: nothing is
    /// clamped or rejected (axis 1); a `nil` or arbitrary dictionary is discarded identically, and the
    /// DETACHED path does not diverge at all — this member never reads `legacyCanvas`, so attached and
    /// detached answers are the same `nil` (axis 2); no store is read (axis 3); no flag is consulted
    /// (axis 4). It is the one member of this family with no divergence to disclose.
    var markedTextStyle: [NSAttributedString.Key: Any]? {
        get { nil }
        set { }
    }

    // MARK: - `setMarkedText(_:selectedRange:)`

    /// Was `DocumentCanvasView.setMarkedText(_:selectedRange:)`, now `legacySetMarkedText(_:selectedRange:)`.
    /// Forwarded **BARE** — no `notifyingContentChange`, no `notifyingSelectionChangeIgnoringCoalescing`,
    /// no `publishState`, no transaction and therefore no `endTransaction()`. The hook brackets itself,
    /// TWICE and asymmetrically (see the header). It also REPLACES the Task-22f storage-only body, which
    /// DID open a transaction and publish with reason `.markedText`; that body — including its
    /// `guard transactionPhase == .idle` member-level reentrancy guard, which the Task-26 note asked
    /// this task to carry forward — moved intact to `ReferenceMutationBackend`.
    ///
    /// **The four-axis divergence audit, per axis.**
    /// 1. *Clamp vs reject* — the moved body clamps (`clampGlobal`) when placing the selection inside
    ///    the composition and rejects nothing; that is unchanged, because it moved with the body. The
    ///    REPLACED storage-only body did neither, which is one of the several ways it was not the real
    ///    forward. `selectedRange` is passed through RAW — unordered, unclamped, marked-text-relative —
    ///    exactly as the pre-seam witness received it.
    /// 2. *nil / wrong-type input* — `markedText` is `String?` and a `nil` is NOT dropped here: it is
    ///    forwarded, and the moved body collapses it to `""` (`markedText ?? ""`), which is the
    ///    composition-CANCEL path. Dropping a nil at this member would silently strand a composition,
    ///    so the nil travels. **The DETACHED path is a real axis-2 divergence**, the same one
    ///    `insertText(_:)`/`deleteBackward()` carry: a composition update arriving while `legacyCanvas`
    ///    is nil is now DROPPED. Accepted rather than repaired (the alternative is a canvas-side
    ///    fallback, i.e. a second copy of the body). **No `RichTextInputContractViolation` is reported**
    ///    — this is the OS's IME entry point with no in-tree programmatic caller at all (measured
    ///    below), so it meets the Phase-4 preamble's "report only where a PROGRAMMATIC caller could
    ///    reach the member" clause the way `insertText`/`deleteBackward` did not, AND it matches their
    ///    precedent. Both tests agree, so there is nothing to trade off.
    ///    `BackendAttachmentTests.test_setMarkedTextOnADetachedBackend_isDroppedSilently_ratherThanReported`
    ///    pins it. Note this is ALSO a change from the body that used to sit here, which DID report
    ///    `"operation on a detached backend: setMarkedText(_:selectedRange:)"`; that report moved to
    ///    `ReferenceMutationBackend` with the transaction it guarded.
    /// 3. *Which store is read* — none here. The moved body reads the LIVE canvas `markedRange` and
    ///    `selFrom`/`selTo`, exactly as before. The REPLACED body derived its base offset from
    ///    `canonicalSelectionStorage`, which lagged the canvas until Task 35 (D35 finding 1) — one
    ///    more reason a plain forward was the right shape. That reason has EXPIRED (Task 35 collapsed
    ///    the two selection stores; see that property's declaration); the shape stands on axis 4 below,
    ///    which has not, because the two MARKED-text stores are still separate until Task 41.
    /// 4. *Which object owns a consulted flag* — every flag the moved body branches on is the CANVAS's:
    ///    `markedRange` (the "is a run already open" test that picks `lo`/`hi`), `markedTextIsPrediction`
    ///    (written from `selectedRange`'s `{0,0}` shape), `compositionUndoSnapshot`/
    ///    `compositionAnchorHead`. The backend's parallel `markedRangeStorage` is NOT consulted, and a
    ///    backend-side re-implementation that consulted it would take the wrong branch on the first
    ///    keystroke of every run.
    ///
    /// **The Task-22f "must look at BOTH channels" note, resolved.** That body's doc comment warned
    /// Task 29 that the real canvas fires TWO separate hook channels on every call —
    /// `notifyContentSizeChanged()` AND `onSelectionChange?()` — and that a single
    /// `.markedText`-reasoned `publishState` does not cover them. Under Option A the resolution is that
    /// this member publishes NOTHING: the canvas body fires both channels itself, as it always did, and
    /// they reach the presentation/lifecycle clients through the canvas's own hooks rather than through
    /// a backend publish. Adding a publish here would be a THIRD emission on top of those two.
    ///
    /// **Who now reaches the canvas body through this member**, so the drop above is not read as
    /// hypothetical. Measured, not assumed — `grep -rn "setMarkedText" Sources/` outside `InputBackend/`
    /// and outside `+MarkedText.swift` itself, comments excluded, is exactly ONE line:
    /// `legacyApplyMutation`'s `.setMarkedText` case, which Task 29 repointed at the LEGACY body and so
    /// does NOT come through here. There is no public-facade forwarder (unlike `insertText(_:)` and
    /// `deleteBackward()`), so UIKit is the only caller of this member in the tree.
    func setMarkedText(_ text: String?, selectedRange: NSRange) {
        legacyCanvas?.legacySetMarkedText(text, selectedRange: selectedRange)
    }

    // MARK: - `unmarkText()`

    /// Was `DocumentCanvasView.unmarkText()`, now `legacyUnmarkText()` — a one-line
    /// `commitMarkedText()` call. Forwarded **BARE**, and here that is sharper than for its siblings:
    /// `commitMarkedText()` emits NO delegate notification and NO canvas-hook event whatsoever, so a
    /// bracket at this member would not double an existing one, it would invent the only one — and
    /// `MarkedTextTraceCharacterizationTests.test_compositionBeginUpdateCommit_traceAndRevisions`
    /// asserts `recorder.kinds == []` across the whole commit.
    ///
    /// This member was a genuine `+Unwitnessed.swift` stub until now (unlike its three siblings),
    /// so routing it removed a real `pendingRouting()` call site and a real R13 inventory entry.
    ///
    /// **The four-axis divergence audit, per axis.**
    /// 1. *Clamp vs reject* — N/A, no input and no offsets.
    /// 2. *nil / wrong-type input* — no input. **The DETACHED path is the same axis-2 divergence**: a
    ///    commit arriving with no `legacyCanvas` is dropped, where the pre-seam witness committed from
    ///    live canvas state. Silent, for the same reason and by the same precedent as
    ///    `setMarkedText(_:selectedRange:)` above.
    /// 3. *Which store is read* — none here; `commitMarkedText()`'s own `guard markedRange != nil` reads
    ///    the CANVAS's store, unchanged. (TASK 41: that read is now a projection of
    ///    `markedRangeStorage`, so it reads THIS backend's store through the canvas — one value, not
    ///    two. The member is unchanged.)
    /// 4. *Which object owns a consulted flag* — the canvas's `markedRange` (the no-op guard) and
    ///    `markedTextIsPrediction` (cleared on commit). Note `unmarkText`/`commitMarkedText` COMMITS a
    ///    prediction rather than dismissing it — that asymmetry with `finalizeMarkedText()` below is
    ///    deliberate and load-bearing (a keyboard-driven accept must not desync the keyboard's shadow
    ///    document), and it moved with the bodies.
    func unmarkText() {
        legacyCanvas?.legacyUnmarkText()
    }

    // MARK: - Composition lifecycle (NOT UIKit witnesses — backend-internal, no protocol change)

    /// The three entry points below are the canvas's own composition lifecycle, surfaced on the backend
    /// so that the object that will OWN composition state after Task 41 already declares the operations
    /// it will have to perform. They keep their canvas names (there is no witness to collide with, so
    /// nothing needed renaming), and they are plain D24 forwards like everything else in this file.
    ///
    /// **ZERO CALLERS AND ZERO COVERAGE, stated as an obligation on Task 41 rather than a caveat about
    /// today.** Measured both halves: `grep -rn "commitMarkedText\|dismissPrediction\|finalizeMarkedText"
    /// Sources/` finds no call on a BACKEND (every hit is a `DocumentCanvasView` member or one of these
    /// three forwards), and the same grep over `Tests/` finds no drive point on a backend either — every
    /// hit drives a canvas. So all three, including `finalizeMarkedText()`'s `?? nil` double-optional
    /// flatten and its `@discardableResult`, are untested. They also sit outside every mechanical rule:
    /// not witnesses (so outside `RouterWitnessBodyTests`), and not listed in R17. **TASK 31 LANDED the
    /// `forwardTarget:` rule-mechanism change this sentence used to describe as deferred** — R17's
    /// per-member flag is now a six-case `ForwardShape` — and these three are still NOT listed, which is
    /// a decision of SCOPE rather than an omission: Task 31's mandate was the shapes its own twelve
    /// members and `performCommand`'s `switch` needed, not a coverage widening for members whose owner
    /// is Task 41.
    ///
    /// **FIX ROUND 1 (review Min-3) — the MECHANISM reason this paragraph also gave is deleted, because
    /// it was false.** It claimed listing these three "would need a SEVENTH case, since none of the six
    /// expresses `legacyCanvas?.<unprefixed>`". `.statements(allowed: ["legacyCanvas?.commitMarkedText()"])`
    /// expresses it exactly, and Task 31 used that spelling three times in the same commit. Whoever
    /// lists them needs no new case — only a decision that it is their job to. The false claim is
    /// recorded rather than silently removed, because it would have sent Task 41 building a case it
    /// does not need. **TASK 41 is the task that gives them callers, and it therefore owes them
    /// coverage** — a backend-driven sibling of
    /// `MarkedTextRouterTests.test_finalizeMarkedTextDismissesAPredictionButCommitsAComposition`, which
    /// today drives the CANVAS and so characterizes pre-existing behaviour rather than guarding these.
    /// Adding tests now would be testing dead code; deleting them would contradict the brief that
    /// mandates them.
    ///
    /// **They have no caller in `Sources/` today, and that is deliberate rather than an oversight.**
    /// Every production call site — `+UITextInput.swift`'s two `commitMarkedText()` calls, and the
    /// fourteen `finalizeMarkedText()` calls spread across the canvas, the clients and
    /// `RichTextEditorView` — is *canvas-internal or canvas-directed* and stays that way until Task 41
    /// moves the state; re-pointing them at the backend now would add a hop through `legacyCanvas` and
    /// straight back for no behavioural difference, on paths this task was not asked to touch. What
    /// this file buys instead is that a Task-41 reader finds the whole composition surface in one
    /// place, with the commit-vs-dismiss asymmetry stated where the state will live.

    /// Commits the active composition: registers ONE undo step from the composition-start snapshot and
    /// clears marked state, WITHOUT mutating text (the provisional characters stay committed). No-op
    /// when not composing. This is the KEYBOARD-DRIVEN accept path, which is why it commits a
    /// prediction rather than dismissing it.
    func commitMarkedText() {
        legacyCanvas?.commitMarkedText()
    }

    /// Removes an active PREDICTION's provisional ghost text. The ghost is keyboard-owned, never user
    /// content, so this registers NO undo (but it DOES bump the revision and fire a text-only delegate
    /// bracket, since it really does mutate the document). No-op unless a prediction is showing.
    func dismissPrediction() {
        legacyCanvas?.dismissPrediction()
    }

    /// The NON-keyboard-driven interruption path (gesture caret-move, focus loss, structural edit,
    /// undo/redo, full reload): a COMPOSITION is COMMITTED (kept, one undo step); a PREDICTION ghost is
    /// DISMISSED (removed, no undo). Committing a prediction here would desync the keyboard's shadow
    /// document and duplicate the word on its accept-`replace` — the on-device bug Task 18 fixed.
    /// Returns the dismissed prediction's range so a caller holding a pre-dismiss coordinate can adjust
    /// for the removed length; `nil` for a committed composition or no marked text.
    ///
    /// The `?? nil` flattens optional chaining's `((from: Int, to: Int)?)?`: "no canvas" and "nothing
    /// was dismissed" are the same answer to this member's caller, and R15 forbids the force-unwrap
    /// that would avoid the double optional.
    @discardableResult
    func finalizeMarkedText() -> (from: Int, to: Int)? {
        legacyCanvas?.finalizeMarkedText() ?? nil
    }
}
#endif
