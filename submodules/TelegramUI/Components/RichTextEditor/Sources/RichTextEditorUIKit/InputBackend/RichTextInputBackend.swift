#if canImport(UIKit)
import UIKit

// MARK: - `UITextInput` routing

/// The shared Swift contract contains public UIKit operations only. Every member here is a `UITextInput`
/// witness the canvas will forward to a one-line router.
@MainActor
@available(iOS 13.0, *)
protocol RichTextInputTextBackend: AnyObject {
    /// Routed from `DocumentCanvasView.inputDelegate` (S/Canvas/DocumentCanvasView+UITextInput.swift:164).
    var inputDelegate: UITextInputDelegate? { get set }

    /// Routed from `DocumentCanvasView.tokenizer` (`S/Canvas/DocumentCanvasView+UITextInput.swift`),
    /// which is a one-line router with no body of its own. **TASK 43: the conformer both CONSTRUCTS and
    /// OWNS its tokenizer** — the canvas's `legacyMakeTokenizer()` D24 hook is deleted, and
    /// `InputBackendSourceBoundaryTests.test_theTokenizerHasExactlyOneConstructionSite` caps the
    /// package at one construction site — via TWO assertions, because one regex cannot be a complete
    /// net over the five spellings Swift accepts (see that test). Stability is per ATTACHMENT, not per backend lifetime: the
    /// legacy conformer builds it eagerly in `attach(to:)` and clears it on detach, so a read taken
    /// while detached is a contract violation with a no-op fallback, and a re-attach to a different
    /// host vends a fresh instance (`BackendAttachmentTests`' three tokenizer tests).
    var tokenizer: UITextInputTokenizer { get }

    /// Routed from `DocumentCanvasView.selectedTextRange`
    /// (S/Canvas/DocumentCanvasView+UITextInput.swift:142).
    var selectedTextRange: UITextRange? { get set }

    /// Routed from `DocumentCanvasView.markedTextRange` (S/Canvas/DocumentCanvasView+MarkedText.swift:23).
    var markedTextRange: UITextRange? { get }

    /// Routed from `DocumentCanvasView.markedTextStyle` (S/Canvas/DocumentCanvasView+MarkedText.swift:28).
    var markedTextStyle: [NSAttributedString.Key: Any]? { get set }

    /// Routed from `DocumentCanvasView.beginningOfDocument`
    /// (S/Canvas/DocumentCanvasView+UITextInput.swift:178).
    var beginningOfDocument: UITextPosition { get }

    /// Routed from `DocumentCanvasView.endOfDocument` (S/Canvas/DocumentCanvasView+UITextInput.swift:179).
    var endOfDocument: UITextPosition { get }

    func text(in range: UITextRange) -> String?
    func replace(_ range: UITextRange, withText text: String)

    /// TASK 22f FIX ROUND 2 (review Major A) — a doc comment this member lacked entirely, against the
    /// precedent Task 22d set for `suppressesSelectionNotifications` (`:258-286` below): a conformer
    /// MUST publish (`backendDidPublishState`) exactly once, with reason `.markedText`, for the state
    /// this call mutates — the composing/marked range and, via it, `isComposing` (two of the four
    /// `RichTextInputStateSnapshot` fields). Silence here is the shape of the Task 20
    /// `clearCompositionState()` defect: a caller that composes text and never sees a publication has
    /// a presentation snapshot that has gone stale relative to the model. `LegacyRichTextInputBackend`
    /// mirrors `clearCompositionState()`'s own established reason choice
    /// (`BackendMarkedTextPolicyTests.test_setMarkedText_publishesWithMarkedTextReason`); this is
    /// deliberately narrower than the real canvas's own two-hook shape (`notifyContentSizeChanged()` +
    /// `onSelectionChange?()`) because THIS member, by this protocol's own contract, does not move the
    /// caret into the composition the way the canvas's richer implementation does — `.markedText`
    /// alone is the exactly-right signal for the state a conformer is required to mutate here, not a
    /// deliberately-incomplete half of some richer shape.
    func setMarkedText(_ text: String?, selectedRange: NSRange)
    func unmarkText()

    func textRange(
        from: UITextPosition,
        to: UITextPosition
    ) -> UITextRange?

    func position(
        from: UITextPosition,
        offset: Int
    ) -> UITextPosition?

    func position(
        from: UITextPosition,
        in direction: UITextLayoutDirection,
        offset: Int
    ) -> UITextPosition?

    func compare(
        _ position: UITextPosition,
        to other: UITextPosition
    ) -> ComparisonResult

    func offset(
        from: UITextPosition,
        to other: UITextPosition
    ) -> Int

    func position(
        within range: UITextRange,
        farthestIn direction: UITextLayoutDirection
    ) -> UITextPosition?

    func characterRange(
        byExtending position: UITextPosition,
        in direction: UITextLayoutDirection
    ) -> UITextRange?

    func baseWritingDirection(
        for position: UITextPosition,
        in direction: UITextStorageDirection
    ) -> NSWritingDirection

    func setBaseWritingDirection(
        _ direction: NSWritingDirection,
        for range: UITextRange
    )

    /// Deviation D9: the geometry *client* returns `nil` for missing geometry; this UIKit witness keeps
    /// UIKit's real non-optional `CGRect` signature. TASK 25 (correcting this comment, which pre-dated
    /// the family's real implementation): the `?? .zero` transformation lives in THIS backend's
    /// UIKit-facing member (`S/InputBackend/LegacyRichTextInputBackend+Geometry.swift`'s `firstRect(for:)`),
    /// not in the canvas router — the canvas witness (`S/Canvas/DocumentCanvasView+UITextInput.swift`)
    /// is a pure one-line `inputBackend.firstRect(for: range)` forward, per the family's own
    /// "one statement starting `inputBackend.`" shape gate. This is the one representation-difference
    /// translation a member may perform, wherever in the seam it lives.
    func firstRect(for range: UITextRange) -> CGRect

    /// Deviation D9, same rationale as `firstRect(for:)` — see that member's corrected comment above.
    /// (`S/InputBackend/LegacyRichTextInputBackend+Geometry.swift`'s `caretRect(for:)`;
    /// `S/Canvas/DocumentCanvasView+UITextInput.swift`'s witness is a pure one-line forward.)
    func caretRect(for position: UITextPosition) -> CGRect

    func selectionRects(for range: UITextRange) -> [UITextSelectionRect]

    func closestPosition(to point: CGPoint) -> UITextPosition?

    func closestPosition(
        to point: CGPoint,
        within range: UITextRange
    ) -> UITextPosition?

    func characterRange(at point: CGPoint) -> UITextRange?

    /// Deviation D15: declared per spec, but the canvas witnesses neither `textStyling(at:in:)` nor
    /// `insertDictationResult(_:)` today (grep: zero hits). `LegacyRichTextInputBackend` returns `nil` /
    /// no-ops; a source-boundary test asserts no canvas witness appears.
    func textStyling(
        at position: UITextPosition,
        in direction: UITextStorageDirection
    ) -> [NSAttributedString.Key: Any]?

    /// Deviation D15, same rationale as `textStyling(at:in:)`.
    func insertDictationResult(
        _ dictationResult: [UIDictationPhrase]
    )
}

// MARK: - `UIKeyInput` routing

@MainActor
@available(iOS 13.0, *)
protocol RichTextKeyInputBackend: AnyObject {
    /// Routed from `DocumentCanvasView.hasText` (S/Canvas/DocumentCanvasView+UITextInput.swift:299).
    var hasText: Bool { get }

    /// Routed from `DocumentCanvasView.insertText(_:)` (S/Canvas/DocumentCanvasView+UITextInput.swift:301).
    func insertText(_ text: String)

    /// Routed from `DocumentCanvasView.deleteBackward()` (S/Canvas/DocumentCanvasView+UITextInput.swift:503).
    func deleteBackward()
}

// MARK: - Responder lifecycle routing

@MainActor
@available(iOS 13.0, *)
protocol RichTextInputResponderBackend: AnyObject {
    /// Routed from `DocumentCanvasView.canBecomeFirstResponder` — TASK 31 made that witness a one-line
    /// router and the unconditional `true` lives here now. (The `S/Canvas/DocumentCanvasView.swift:665`
    /// citation this line carried was already stale when Task 31 measured it, and is dropped rather
    /// than repaired.)
    var canBecomeFirstResponder: Bool { get }

    /// Routed from `DocumentCanvasView.canResignFirstResponder`, a NEW override TASK 31 added: the
    /// canvas declared none, so `UIResponder`'s own documented `true` applied, and an override
    /// answering `true` reproduces it exactly.
    var canResignFirstResponder: Bool { get }

    func hostWillBecomeFirstResponder()
    func hostDidBecomeFirstResponder()
    func hostDidFailToBecomeFirstResponder()

    func hostWillResignFirstResponder()
    func hostDidResignFirstResponder()
    func hostDidFailToResignFirstResponder()

    func hostWillMove(toWindow window: UIWindow?)
    func editPolicyDidChange()
    func textInputTraitsDidChange()

    /// DEVIATION D3: added, un-gated (no `@available` above the iOS 13 floor — hard invariant 12). The
    /// canvas keeps its `@available(iOS 18.0, *) var isEditable: Bool`
    /// (`+UITextInput.swift`) as a one-line router to this, which TASK 31 made real. **Not gated on
    /// `RichTextInputEditPolicy.allowsWritingTools`**, deliberately: the pre-seam witness consulted
    /// nothing, so a conformer that gates this is changing behaviour, not routing it.
    var isEditableForWritingTools: Bool { get }

    /// DEVIATION D28: `canPerformAction(_:withSender:)` and the standard edit actions are `UIResponder`
    /// witnesses, not `UITextInput` witnesses, so they have no home in `RichTextInputTextBackend`; they
    /// still must reach the command client. Routed from
    /// `DocumentCanvasView.canPerformAction(_:withSender:)` (S/Canvas/DocumentCanvasView+EditMenu.swift:83).
    func canPerformCommand(_ command: RichTextInputCommand, sender: Any?) -> Bool

    /// DEVIATION D28, same rationale as `canPerformCommand(_:sender:)`.
    func performCommand(_ command: RichTextInputCommand, sender: Any?)

    /// DEVIATION D28 (TASK 30 — a THIRD member under the same deviation, added rather than assumed).
    /// `UIResponder.undoManager` is the responder-chain hook the SYSTEM undo affordances act through
    /// (hardware Cmd-Z / Cmd-Shift-Z, shake-to-undo, the Edit-menu Undo/Redo). It is a `UIResponder`
    /// witness, not a `UITextInput` one, so — exactly like `canPerformAction(_:withSender:)` and the
    /// standard edit actions above — it has no home in `RichTextInputTextBackend`, and
    /// `DocumentCanvasView.inputBackend` is typed `any RichTextInputBackend`, so the canvas's routed
    /// `override var undoManager` needs this to be a protocol requirement (the D33 reasoning).
    ///
    /// **This does NOT move undo OWNERSHIP** (deviation D14 keeps that with the document client and the
    /// canvas: `openUndoRun`, `undoRegistrationCount`, `undoManagerOverride`, `breakUndoCoalescing()`).
    /// It VENDS the manager to the responder chain, which is the same category as the command client's
    /// existing `canPerform(.undo)`/`performUndo()` — reading and invoking, never owning. A conformer
    /// answers with whatever manager its own edits register into; `nil` means "this responder has no
    /// undo manager", which is what a detached backend answers.
    var undoManager: UndoManager? { get }
}

// MARK: - Interaction routing

@MainActor
@available(iOS 13.0, *)
protocol RichTextInputInteractionBackend: AnyObject {
    func installInteractions()
    func removeInteractions()

    /// Routed from `DocumentCanvasView.viewportDidChange()`, whose body Task 32 moved to
    /// `legacyViewportDidChange()`. **The `DocumentCanvasView.swift:<line>` citation that used to sit
    /// here is DELETED, not repaired** (review Minor 4): it read `:1029` for a member that has been at
    /// three different line numbers across three documents, which is the tracked in-tree register item
    /// about line citations rotting silently. Cite by member name.
    func viewportDidChange()

    func layoutDidChange(generation: UInt64)

    /// Routed from `DocumentCanvasView.beginFloatingCursor(at:)`. **TASK 33 DELETED the
    /// `+FloatingCursor.swift:<line>` citations from these three doc comments rather than repairing
    /// them** — all three were already wrong, which is the same tracked register item (line citations
    /// rot silently) that `viewportDidChange()` above records. Cite by member name.
    func beginFloatingCursor(at point: CGPoint)

    /// Routed from `DocumentCanvasView.updateFloatingCursor(at:)`. Deviation D2: UIKit's real signature
    /// has no `animated:`, so the spec's `(at:animated:)` is not used — a router may only forward.
    func updateFloatingCursor(at point: CGPoint)

    /// Routed from `DocumentCanvasView.endFloatingCursor()`.
    func endFloatingCursor()

    func cancelActiveInteraction(
        reason: RichTextInteractionCancellationReason
    )
}

// MARK: - Text-checking routing

/// DEVIATION D37 (Task 34, Family 11) — the checking LIFECYCLE, and nothing else.
///
/// **Why this is a protocol requirement at all**, since the task brief said the opposite ("these are
/// not UIKit witnesses, so nothing is added to any protocol"): the members that call these live on the
/// CANVAS — the `isSpellCheckingEnabled` `didSet`, `legacyFinishBecomingFirstResponder()`,
/// `refreshSelectionUI()` and `endCoalescedSelectionDrag()` — and `DocumentCanvasView.inputBackend` is
/// typed `any RichTextInputBackend` (Task 20). **Anything canvas-side code reaches through it must be a
/// protocol requirement**; a member declared only on `LegacyRichTextInputBackend` is unreachable and
/// does not compile. That is D33's rationale verbatim, which added seven members for exactly this
/// reason, and D28's `undoManager` made eight — so this is the established pattern, not a new licence.
///
/// **D36 is the near neighbour a reader will reach for, and it does not transfer.** Task 32's four
/// interaction witnesses stayed off the contract because **Global Constraint 12** forbids an
/// `@available` gate above iOS 13 on a protocol requirement, and two of the four name
/// `UIEditMenuInteraction` (iOS 16+) / `UITextSelectionDisplayInteraction` (iOS 17+). Neither member
/// below takes a parameter at all, let alone a gated type. **"We did not add one there" is not a
/// precedent when the reason we did not was a prohibition that does not apply here.**
///
/// **Scope — the line is sharp and it is D11's.** The backend owns *when* checking is installed,
/// preheated and driven. It owns nothing else: the `NativeTextChecker` handle stays a canvas-owned
/// resource so `DocumentCanvasView.deinit` keeps invalidating it; annotation STORAGE stays on the
/// canvas behind `TelegramAnnotationInputClient` (Task 17), including D17's documented non-rebasing;
/// and the five `@objc` private-controller client selectors plus the obfuscated resolver strings stay
/// exactly where they are, because carving them into an Objective-C module is stage-2 work.
///
/// **A brief error worth carrying here, because it inverts the picture:** the five `@objc` selectors do
/// NOT "forward to `annotationClient`". They call canvas-internal translation
/// (`applyNativeAnnotations` / `clearNativeAnnotations` / `spellResults`), and it is
/// `TelegramAnnotationInputClient` that delegates INTO them ("Delegates verbatim to the existing
/// controller-facing callback" — its own doc comment). Pinned by
/// `CheckingRouterTests.test_theAnnotationClientForwardsToTheCanvasNotTheReverse`.
///
/// **`driveNativeCheck(style:_:)` is deliberately NOT here**, and the task brief listed it. It is a
/// bracket over canvas-owned state (`inFlightCheckStyle`, read synchronously by the `@objc`
/// `removeAnnotation:forRange:` during the closure), and all three of its call sites are inside canvas
/// bodies. Routing it would send a canvas-captured closure out to the backend and straight back with no
/// decision taken in between, and would put the canvas-nested `DocumentCanvasView.SpellStyle` on a
/// contract member's face. Driving is the backend's; the bracket around one driven call is the body's.
///
/// A conformer with no checking of its own implements both as no-ops — the operations are "if you have
/// a checker, install it" and "the selection moved, do whatever checking that implies", neither of which
/// encodes a legacy assumption.
@MainActor
@available(iOS 13.0, *)
protocol RichTextInputCheckingBackend: AnyObject {
    /// Routed from `DocumentCanvasView.legacyFinishBecomingFirstResponder()` and from the
    /// `isSpellCheckingEnabled` `didSet`'s enable branch. Must be IDEMPOTENT: the chat composer focuses
    /// the editor on every touch-down, so this runs on every `becomeFirstResponder()`, and a second
    /// install would drop a live controller and its warm checker on the floor.
    func installCheckingIfNeeded()

    /// Routed from `DocumentCanvasView.refreshSelectionUI()` and `endCoalescedSelectionDrag()`. Called
    /// on every selection change; a conformer decides what (if anything) that implies.
    func checkOnSelectionChange()
}

// MARK: - Composite backend

/// One lifetime-fixed input authority. The backend retains the host weakly. `attach` is exactly once.
/// `detach` is idempotent and terminal. Operational use before attachment or after detachment is a
/// programmer contract violation (`RichTextInputContractViolation`).
@MainActor
@available(iOS 13.0, *)
protocol RichTextInputBackend:
    RichTextInputTextBackend,
    RichTextKeyInputBackend,
    RichTextInputResponderBackend,
    RichTextInputInteractionBackend,
    RichTextInputCheckingBackend
{
    var state: RichTextInputStateSnapshot { get }
    var isAttached: Bool { get }

    func attach(to host: any RichTextInputHost) throws
    func detach()

    func synchronizeAfterExternalChange(
        _ change: RichTextInputExternalChange
    )

    /// Whole-selection writes use this spec spelling exclusively. Do NOT add a second spelling such as
    /// `setCanonicalSelection` — one operation, one name.
    func setSelection(
        _ selection: RichTextCanonicalSelection,
        reason: RichTextSelectionChangeReason
    )

    // MARK: Deviation D33 — seven stage-1 members.
    //
    // `DocumentCanvasView.inputBackend` is typed `any RichTextInputBackend` (Task 20), so anything
    // canvas-side code reaches through it must be a protocol requirement; a member declared only on
    // `LegacyRichTextInputBackend` is unreachable and does not compile. Phase 5 turns `anchor`/`head`
    // (Task 35), `coalescingSelectionNotifications` (Task 26) and the marked-state reset (Task 41) into
    // canvas forwarders, and each needs exactly one of these.

    /// Read by Task 44's canvas surface.
    var canonicalSelection: RichTextCanonicalSelection { get }

    /// Read by Task 35's `anchor` forwarder.
    var canonicalSelectionAnchorOffset: Int { get }

    /// Read by Task 35's `head` forwarder.
    var canonicalSelectionHeadOffset: Int { get }

    /// Written by `DocumentCanvasView+Editing.swift`'s `applyCaretOutcome` (since TASK 36a) and, since
    /// TASK 40a, by four more named sites — the list below is exhaustive.
    ///
    /// **TASK 40a CORRECTION — "and by nothing else" is no longer true, and the `anchor` setter is no
    /// longer one of the writers.** Task 40a made that setter `@available(*, unavailable)` and Task
    /// 40b DELETED it, along with `head`'s; both properties are now get-only projections. The
    /// complete set of callers is:
    ///   1. `applyCaretOutcome` (`+Editing.swift`) — the caret-claim application point;
    ///   2. `legacyApplyMutation`'s four seat-before-dispatch sites (`+Editing.swift`), respelled by
    ///      Task 40a from `anchor = …; head = …`. They SEAT the selection as an input to a witness
    ///      read on the next line and must not become caret outcomes;
    ///   3. `registerUndo`'s restore pair (`+Editing.swift`), via `target.inputBackend.…`;
    ///   4. `DocumentCanvasView.setSelectionForTesting(anchor:head:)` — the test seam, whose body is
    ///      this pair. Task 40a measured the alternatives; the record is at that method;
    ///   5. `SelectionAuthorityTests`' two helpers, which is the suite that pins this contract.
    /// The forwarder setters that used to dominate this list are gone from `Sources/` entirely.
    ///
    /// **CONTRACT: a conformer must write ONLY the named endpoint and MUST NOT publish.** These two
    /// exist so every pre-seam canvas write site keeps behaving exactly as it did while Tasks 36a-40a
    /// convert them; a raw `anchor = …` consulted no policy and reported nothing, and the canvas
    /// writes its two endpoints one at a time, so a publishing implementation would announce a
    /// half-updated selection that never existed.
    ///
    /// **TASK 36a CORRECTION — this clause used to read "A DELIBERATE write, including every site
    /// those tasks convert, uses `setSelection(_:reason:)` above", and the FIRST of those tasks
    /// measured otherwise.** Applying a converted primitive's caret claim through `setSelection`
    /// turns a measured set of tests red, because `editing`'s own tail already delivers exactly the
    /// two host effects a `.selection` publish delivers, so a claim inside its bracket DOUBLES them.
    /// The claim is therefore applied through this pair. The normative record — the failing count,
    /// the suites, the control, and what the choice costs — is `applyCaretOutcome`'s doc comment in
    /// `DocumentCanvasView+Editing.swift`, and the numbers appear ONLY there.
    ///
    /// **Consequence for TASK 40b, which deletes the canvas setters:** they are no longer the only
    /// callers of this pair. 36b/36c remove 34 forwarder writes from `+Editing.swift` and add ONE
    /// call in `applyCaretOutcome`. **TASK 40a CORRECTION — "40b inherits a single site to convert"
    /// understates it**: Task 40a's Step-4 gate forced the remaining `Sources/` writes onto this pair
    /// too, so 40b inherits the SEVEN `Sources/` sites enumerated above (1-3), not one. All seven are
    /// already spelled as this pair, so 40b's work there is deletion of the setters, not conversion.
    ///
    /// **AND IF 40b REVISITS THE PUBLICATION DECISION, IT MUST GATE ON THE RIGHT SUITES.** Task 40a
    /// measured the publishing alternative and found it red — but the three CHARACTERIZATION suites
    /// its brief named were **green under the broken shape**, and not because the sample was small.
    /// `Tests/RichTextEditorUIKitTests/Characterization/` contains **zero** canvases built over an
    /// injected backend (no `DocumentCanvasView(inputBackend:)`, no double referenced anywhere in that
    /// directory); every backend-double file lives under `Tests/…/InputBackend/` or `Tests/…/Support/`.
    /// Those suites are therefore **categorically** blind to any behaviour that only differs on a
    /// double — adding more of them changes nothing. **Rule: a decision about what a canvas→backend
    /// seam DOES must be gated on suites that inject a backend double, or on the full suite.**
    /// (`LegacyRichTextInputBackend`'s implementation carries the full reasoning and Task 35's own
    /// measurement.)
    ///
    /// # TASK 40b — THE DECISION: THIS PAIR IS **KEPT**, AND IT IS NOT A TRANSITIONAL MEMBER
    ///
    /// Task 40b's brief required this to be decided rather than drifted into, because the contract
    /// above is stage-2 binding: every future backend inherits an obligation to provide an ungated,
    /// non-publishing raw endpoint write. Its "delete them" branch rested on the claim that the pair
    /// has **no callers** once the canvas setters go. That claim was true when it was written and is
    /// false now: `grep -rn "setCanonicalAnchor\|setCanonicalHead" Sources Tests` at this commit
    /// returns the SEVEN `Sources/` call LOCATIONS enumerated above plus the test-side users — each
    /// writes both endpoints, so it is fourteen CALLS, which is the unit
    /// `InputBackendSourceBoundaryTests.test_theWriteDoorsIntoBackendOwnedInputStateAreEnumerated` pins them
    /// in. **Deletion was not an available option, and the reason is not "stage 2 might want it."**
    ///
    /// Four of the seven are structural and cannot be re-expressed. `legacyApplyMutation`'s
    /// seat-before-dispatch lines SEAT the selection as an INPUT to a no-arg legacy witness read on
    /// the very next line; `RichTextInputCaretOutcome`'s own doc records that converting them into
    /// caret outcomes would be a live bug, because an outcome is applied AFTER the transaction and
    /// these must land before it. A publishing write is equally unavailable there: it would announce
    /// a selection that exists only as a dispatch argument. What those sites need is exactly what
    /// this pair is.
    ///
    /// So the transitional framing is retired: this is a **permanent primitive** of the contract, and
    /// the obligation a stage-2 backend inherits is a real one — "seat an endpoint without
    /// announcing it" is a thing an input backend must be able to do, not scaffolding left over from
    /// Phase 5. What a conformer owes is unchanged and is stated above: write ONLY the named
    /// endpoint, publish nothing, consult no policy gate. The two properties a reader might expect
    /// and will not find — an attachment guard and a policy gate — are absent deliberately;
    /// `applyCaretOutcome`'s doc records what happens when a guarded, publishing member is used at
    /// one of these sites instead (`setSelection`'s `guard isAttached` fires
    /// `RichTextInputContractViolation.report`, which is `assertionFailure` in DEBUG, and kills the
    /// test runner on the two detached-backend probes).
    ///
    /// **Adding an eighth caller is a decision, and it now COSTS like one.** The publishing door
    /// (`setSelection(_:reason:)`) is the default; this pair is for the case where a raw endpoint
    /// must be seated with no host-visible effect, and that case should stay rare enough to
    /// enumerate. `test_theWriteDoorsIntoBackendOwnedInputStateAreEnumerated` holds an exact per-file call
    /// count for exactly that reason — until Task 40b's fix round added it, this paragraph was
    /// advice with nothing behind it.
    func setCanonicalAnchor(_ utf16Offset: Int)

    /// The moving endpoint's raw seat. Same contract as `setCanonicalAnchor(_:)` above — endpoint
    /// only, no publication, no gate — and the same Task 40b decision applies: kept, permanent, seven
    /// callers. (This line used to read "Written by `DocumentCanvasView.head`'s legacy setter (Task
    /// 35)"; that setter no longer exists, deleted by Task 40b.)
    func setCanonicalHead(_ utf16Offset: Int)

    // MARK: TASK 41 — composition state
    //
    // The backend is the single writable COMPOSITION authority, the same rule that already holds for
    // the selection (`test_exactlyOneWritableSelectionAuthority` covers both under one name, because
    // it is one rule). `DocumentCanvasView.markedRange`/`.markedTextIsPrediction` are READ-ONLY
    // projections of the three members immediately below; `compositionUndoSnapshot` and
    // `compositionAnchorHead` have no canvas projection at all — they moved outright.
    //
    // `ghostStyledLayout` did NOT move and must never (D13): it holds a `BlockLayoutEngine`, and
    // passing one across this boundary is an explicit patch-rejection criterion. It stays canvas-side
    // presentation state, written by `refreshPredictionStyling()`.

    /// The marked (IME composing / inline-prediction) range, in the same coordinate space as
    /// `canonicalSelection`. `nil` = not composing.
    var markedRange: NSRange? { get }

    /// True when the active marked text is a system INLINE PREDICTION (ghost text: `setMarkedText`
    /// with the caret at the START, `sel == {0,0}`) rather than a CJK/IME composition. The two are
    /// resolved differently on interruption and the difference is load-bearing: a prediction must be
    /// DISMISSED, never committed, or the keyboard's shadow document desynchronizes and the word is
    /// duplicated on its accept-`replace`. `false` whenever `markedRange` is `nil`.
    var isComposingPrediction: Bool { get }

    /// `markedRange != nil`, named. The published snapshot's `isComposing` field must agree with this.
    var isComposing: Bool { get }

    /// The document + selection snapshot captured at composition START. `nil` = no composition open.
    var compositionSnapshot: RichTextCompositionSnapshot? { get }

    /// **RAW, NON-PUBLISHING composition writes — the marked-text analogue of the D33
    /// `setCanonicalAnchor`/`setCanonicalHead` pair, and chosen for exactly the same reason.**
    ///
    /// `DocumentCanvasView+MarkedText.swift`'s three composition-lifecycle bodies
    /// (`legacySetMarkedText`, `commitMarkedText`, `dismissPrediction`) emit their OWN delegate
    /// brackets and host hooks, in shapes pinned by exact equality
    /// (`MarkedTextTraceCharacterizationTests.test_compositionBeginUpdateCommit_traceAndRevisions`
    /// asserts six recorded events for one begin, and `recorder.kinds == []` across a whole commit).
    /// Routing their state writes through the PUBLISHING `clearCompositionState()` would add a
    /// `.markedText` publication — and therefore a `notifyContentSizeChanged()` — at sites that
    /// published nothing before the seam. These two members are the transitional shape that keeps
    /// every one of those sites byte-identical.
    ///
    /// `isPrediction` travels WITH the range rather than as its own setter, so the two can never
    /// disagree: a non-nil range with a stale prediction flag is the exact state that would send
    /// `finalizeMarkedText()` down the wrong half of its commit-vs-dismiss fork.
    func setCompositionMarkedRange(_ range: NSRange?, isPrediction: Bool)

    /// The other half of the raw pair: the composition-start snapshot. Same non-publishing contract.
    func setCompositionSnapshot(_ snapshot: RichTextCompositionSnapshot?)

    /// Called by Task 41's +MarkedText rewire — specifically by `registerUndo`'s restore closure
    /// (`DocumentCanvasView+Editing.swift`), which is where a system Cmd-Z that fires MID-COMPOSITION
    /// lands: the responder path reaches that closure without the facade's `finalizeMarkedText()` in
    /// front of it, so the composition must be dropped there or the restored snapshot is left with a
    /// marked range pointing into a document that no longer exists.
    ///
    /// **TASK 41 WIDENED WHAT IT CLEARS**: all of `markedRange`, `isComposingPrediction` and
    /// `compositionSnapshot`, not just the range. Before this task it cleared a store that was
    /// uniformly nil in production, so the widening has no observable effect on any pre-existing
    /// caller; it has one on the new caller, which is the point.
    ///
    /// TASK 22f FIX ROUND 2 (review Major A) — stating the obligation this member has always carried,
    /// but which previously lived ONLY as an inherited `BackendContractCases` test
    /// (`BackendAttachmentTests.test_clearCompositionStatePublishesExactlyOnceWithMarkedTextReason`)
    /// scoped to the LEGACY conformer specifically — stage 2 was never bound by it at the protocol
    /// level at all. A conformer MUST publish exactly once, with reason `.markedText`, for the two
    /// snapshot fields this call mutates (`markedRange` and, via it, `isComposing`) — the same
    /// obligation `setMarkedText(_:selectedRange:)` above now states explicitly.
    func clearCompositionState()

    // MARK: TASK 42 — floating-cursor state
    //
    // The backend is the single writable FLOATING-CURSOR authority, the third instance of the rule
    // that already holds for the selection (Task 40b) and the composition (Task 41).
    // `DocumentCanvasView.floatingCursorActive` / `.floatingCursorPoint` / `.floatingScrollVelocity`
    // are READ-ONLY projections of the three reads below, written only through the three doors below.
    //
    // **`floatingScrollLink` did NOT move and must never.** A `CADisplayLink` RETAINS ITS TARGET, and
    // `DocumentCanvasView.willMove(toWindow:)` is its only teardown (the Task-6 retain cycle
    // `WindowDetachCharacterizationTests` guards). The backend owns the STATE and asks nothing of the
    // link; the canvas owns the link and starts/stops it from the same two bodies that always did.
    //
    // **These are on the CONTRACT and not merely on `LegacyRichTextInputBackend` for D33's reason,
    // which is mechanical**: `DocumentCanvasView.inputBackend` is typed `any RichTextInputBackend`, so
    // a canvas projection or a canvas-body door call can only reach a protocol requirement.

    /// True while a floating-cursor (spacebar-trackpad) gesture owns the caret.
    ///
    /// **It is the SUPPRESSION flag AND the PRESENTATION flag — Task 42 merged the two stores that
    /// used to carry those two jobs.** It gates the `selectedTextRange` setter (iOS pushes selection
    /// RANGES through that setter during the gesture, and applying them turns a cursor MOVE into a
    /// text SELECTION), and it also drives `updateCaretView()`'s dimmed landing caret and
    /// `floatingAutoScrollTick`'s guard.
    var floatingCursorActive: Bool { get }

    /// The last raw floating point, in canvas (content) coordinates — an ABSOLUTE position that
    /// already tracks the cursor across the whole document, NOT a relative delta.
    var floatingCursorPoint: CGPoint { get }

    /// The per-tick vertical auto-scroll step (points) while the floating caret sits in a viewport
    /// edge band. Zero means "not auto-scrolling", and it must be zero whenever the canvas holds no
    /// display link — see `setFloatingScrollVelocity(_:)`.
    var floatingScrollVelocity: CGFloat { get }

    /// **RAW, NON-PUBLISHING floating-cursor writes — the third analogue of the D33
    /// `setCanonicalAnchor`/`setCanonicalHead` pair, and bounded on exactly the same terms.**
    ///
    /// The canvas's own floating-cursor bodies (`legacyBeginFloatingCursor`, `legacyEndFloatingCursor`,
    /// `cancelFloatingCursor`) emit their own delegate brackets and host hooks in shapes pinned by
    /// exact equality; routing their flag writes through anything that publishes would add a report at
    /// sites that published nothing before the seam. `InputBackendSourceBoundaryTests
    /// .test_theWriteDoorsIntoBackendOwnedInputStateAreEnumerated` holds an EXACT per-file call-site count for
    /// all three doors, because the R7 write scan cannot see them (they are `.`-qualified).
    ///
    /// **Order matters at both of this door's canvas call sites, and it is not a style preference.**
    /// `legacyBeginFloatingCursor` must set the flag BEFORE its `updateCaretView()`, or that call
    /// paints the steady caret instead of the dimmed landing caret; `legacyEndFloatingCursor` must
    /// clear it before its own `updateCaretView()`, for the mirror-image reason.
    func setFloatingCursorActive(_ active: Bool)

    /// The floating point's raw seat. Same non-publishing contract.
    func setFloatingCursorPoint(_ point: CGPoint)

    /// The auto-scroll velocity's raw seat. Same non-publishing contract.
    ///
    /// **The "no link ⇒ no velocity" invariant is the canvas's, and it stays in one body.**
    /// `DocumentCanvasView.stopFloatingAutoScroll()` invalidates the link and calls this with `0` in
    /// the same two lines it always did, so the pair never straddles the seam even though the two
    /// halves now live on different objects. Pinned by `FloatingCursorStateAuthorityTests
    /// .test_stoppingTheAutoScrollClearsTheLinkAndTheVelocityTogether`.
    func setFloatingScrollVelocity(_ velocity: CGFloat)

    /// Task 26's coalescing forwarder. Written by a future canvas gesture (a selection-handle /
    /// loupe drag) around a run of `setSelection(_:reason:)` samples.
    ///
    /// FIX ROUND 1 (review Major 3) — the obligation every conformer must implement, pinned by
    /// `BackendPublicationContractTests.test_coalescedSelectionDrag_publishesExactlyOneSnapshotAtTheEnd`
    /// (a `BackendContractCases` suite inherited by every conformer's stage-2 subclass, so this is
    /// not merely `LegacyRichTextInputBackend`'s own choice to document, even though it originated
    /// there):
    /// - While `true`, `setSelection(_:reason:)` still updates the canonical selection but MUST
    ///   defer its publish rather than calling it per sample.
    /// - Clearing it back to `false` MUST publish exactly once — the final, settled selection — IF
    ///   AND ONLY IF a selection delta went unpublished during the suppressed run (a plain stored
    ///   `Bool` with no such gating, e.g. the one this class had through Task 22c, satisfies the
    ///   `{ get set }` shape but fails the test: it publishes N times, once per sample, or zero
    ///   times if it never re-checks on clear).
    /// - FIX ROUND 3 (review item 3) — rewritten to remove two dangling references: an earlier
    ///   version of this bullet said "the PRECEDING bullet's 'gates publication'", but that phrase
    ///   was itself deleted by the very edit that added this bullet (fix round 2), leaving nothing
    ///   for "preceding" to point at; and it said "this file's didSet", but THIS file
    ///   (`RichTextInputBackend.swift`) is the protocol declaration — it has no `didSet` at all. The
    ///   `didSet` referred to is a CONFORMER's (`LegacyRichTextInputBackend`'s, concretely).
    ///
    ///   This flag has TWO independent consumers, and each conformer must implement BOTH: (1) the
    ///   publish-deferral in the preceding bullet (a conformer's `setSelection`, gating its OWN
    ///   publication — `LegacyRichTextInputBackend`'s `didSet` flushes it); and (2) Task 26's OWN
    ///   `UITextInputDelegate`-bracket emitters, which separately consult this SAME flag to SUPPRESS
    ///   their own per-sample `selectionWillChange`/`selectionDidChange` bracket while it is set
    ///   (`notifyingSelectionChange(_:)`, plan: "SUPPRESSED while coalescing"), firing exactly ONE
    ///   resync bracket at the end via `notifyCoalescedSelectionResync()`. A conformer's publish
    ///   FLUSH is publication-only — it must never itself emit a delegate notification — but the
    ///   FLAG it reads is shared with that second, independent consumer; do not read "publication
    ///   only" as scoping the flag itself, only the flush. This is precisely the two-writers-of-one-
    ///   flag risk Task 26 itself calls out as its own riskiest edge; a conformer that treats the
    ///   flag as its own private, publication-only state will silently break Task 26's
    ///   bracket-suppression the moment that half lands.
    var suppressesSelectionNotifications: Bool { get set }

    // MARK: Deviation D33 — Task 26's five `UITextInputDelegate` bracket members.
    //
    // Task 26 makes the backend the ONLY sender of `UITextInputDelegate` notifications in the package
    // (enforced by source-boundary rule R16, `InputBackendSourceBoundaryTests`). The 44 canvas-side
    // emission sites become calls to the brackets below, and `DocumentCanvasView.inputBackend` is typed
    // `any RichTextInputBackend`, so — by the same reasoning as the seven members above — each bracket
    // the canvas calls must be a protocol requirement. The four raw emitters
    // (`notifyTextWillChange`/`notifySelectionWillChange`/`notifySelectionDidChange`/`notifyTextDidChange`)
    // are deliberately NOT here: no canvas site calls one directly, so they stay a conformer's own
    // internal detail.
    //
    // The three deliberate asymmetries the legacy canvas has today are preserved as three DISTINCT
    // members rather than one parameterised bracket, so a conformer cannot silently collapse them:
    //   * `notifyingContentAndSelectionChange` fires all four UNCONDITIONALLY (deviation D10).
    //   * `notifyingSelectionChange` is SUPPRESSED while `suppressesSelectionNotifications` is set.
    //   * `notifyingSelectionChangeIgnoringCoalescing` is NOT suppressed by it.
    //
    // SELF-DISCLOSED ADDITION (Task 26, replacing one of the five brackets the task brief lists):
    // `notifyingSelectionChangeIgnoringCoalescing(_:)`. The brief named only `notifyingFloatingCaretMove`
    // as an unsuppressed selection bracket, but NINE canvas sites emit one today and only ONE of them is
    // `moveFloatingCaret` (the others: `beginFloatingCursor`'s collapse, `setMarkedText`'s selection
    // half, the three table structural selectors, `selectImage`, `applySelection`, and the composer's
    // `composerSelectedRange` setter). Routing those eight through the SUPPRESSED bracket would change
    // their behavior during a coalesced drag; routing them through a member named
    // `notifyingFloatingCaretMove` would be a lie. Pinned by
    // `DelegateEmissionTests.test_theUnsuppressedSelectionBracketIsNotSuppressedByCoalescing`.
    //
    // TASK 26 FIX ROUND 1 (review m2, coordinator ruling — a DELIBERATE DEVIATION from the brief, which
    // named `notifyingFloatingCaretMove` among its five): that member is GONE, from this contract and
    // from every conformer. It had been added alongside the one above and was a pure forwarder onto it —
    // verified byte-identical, `{ notifyingSelectionChangeIgnoringCoalescing(body) }`, zero distinct
    // behavior. Two protocol requirements with identical semantics is a shape stage 2 inherits forever
    // and can implement inconsistently, with only one test noticing. **The contract stage 2 inherits
    // carries BEHAVIOURS, not call-site intents.** `moveFloatingCaret`'s documented asymmetry is not
    // lost: its rationale now lives verbatim at the call site (`DocumentCanvasView+FloatingCursor.swift`),
    // which is where a call-site intent belongs, and the asymmetry itself stays pinned by
    // `DelegateEmissionTests.test_moveFloatingCaretIgnoresSuppression` and by the golden trace
    // `DelegateTraceCharacterizationTests.test_moveFloatingCaret_emitsABracketEvenWhileCoalescing`.

    /// textWill → selectionWill → `body` → selectionDid → textDid, UNCONDITIONALLY — the legacy
    /// `editing { }` bracket shape (deviation D10). Never gated on a preparation's flags, never on
    /// `suppressesSelectionNotifications`.
    func notifyingContentAndSelectionChange(_ body: () -> Void)

    /// selectionWill → `body` → selectionDid, SUPPRESSED (the notifications, not `body`) while
    /// `suppressesSelectionNotifications` is set. `body` ALWAYS runs.
    func notifyingSelectionChange(_ body: () -> Void)

    /// selectionWill → `body` → selectionDid, deliberately IGNORING
    /// `suppressesSelectionNotifications` — the shape every canvas selection site other than the three
    /// coalescing-aware funnels uses today, `moveFloatingCaret` included.
    func notifyingSelectionChangeIgnoringCoalescing(_ body: () -> Void)

    /// textWill → `body` → textDid only — the marked-commit / `setMarkedText` text-half /
    /// `dismissPrediction` shape, which moves the caret WITHOUT a selection bracket.
    func notifyingContentChange(_ body: () -> Void)

    /// One selectionWill/selectionDid bracket with NO state change between the two — the single
    /// resync `endCoalescedSelectionDrag` fires for the settled selection of a coalesced run.
    func notifyCoalescedSelectionResync()
}
#endif
