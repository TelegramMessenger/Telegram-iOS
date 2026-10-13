#if canImport(UIKit)
import UIKit
import RichTextEditorCore

// MARK: - Position, range, and selection

@available(iOS 13.0, *)
enum RichTextInputAffinity: Int {
    case upstream
    case downstream
}

@available(iOS 13.0, *)
enum RichTextInputWritingDirection: Int {
    case leftToRight
    case rightToLeft
}

@available(iOS 13.0, *)
enum RichTextInputLayoutDirection: Int {
    case left
    case right
    case up
    case down
}

@available(iOS 13.0, *)
struct RichTextInputPosition: Equatable, Hashable {
    var utf16Offset: Int
    var affinity: RichTextInputAffinity

    /// Deviation D6: the legacy backend has no affinity model, so `.downstream` is the default and
    /// the only value it ever emits. The field is carried through the seam unchanged and no geometry
    /// consults it; making affinity MEAN something is a separate, behavior-changing project.
    init(utf16Offset: Int, affinity: RichTextInputAffinity = .downstream) {
        self.utf16Offset = utf16Offset
        self.affinity = affinity
    }

    static func downstream(_ utf16Offset: Int) -> RichTextInputPosition {
        RichTextInputPosition(utf16Offset: utf16Offset)
    }
}

@available(iOS 13.0, *)
struct RichTextCanonicalSelection: Equatable {
    var anchor: RichTextInputPosition
    var head: RichTextInputPosition

    init(anchor: RichTextInputPosition, head: RichTextInputPosition) {
        self.anchor = anchor; self.head = head
    }
    static func caret(at position: RichTextInputPosition) -> RichTextCanonicalSelection {
        RichTextCanonicalSelection(anchor: position, head: position)
    }
    /// Ordered range for range-shaped APIs. MUST NOT be used to reorder anchor/head — the canvas
    /// hands UIKit an unordered range for a reversed drag and that is load-bearing.
    var normalizedRange: NSRange {
        let lower = min(anchor.utf16Offset, head.utf16Offset)
        let upper = max(anchor.utf16Offset, head.utf16Offset)
        return NSRange(location: lower, length: upper - lower)
    }
    var isCollapsed: Bool { anchor.utf16Offset == head.utf16Offset }
    var isReversed: Bool { head.utf16Offset < anchor.utf16Offset }
}

// MARK: - Caret outcome (TASK 36a)

/// What a mutation primitive resolved the caret to.
///
/// `nil` means "the primitive made NO selection claim" — distinct from "it claims the current
/// selection" — which is why this is not simply an optional `RichTextCanonicalSelection`:
/// `DocumentCanvasView.editing(coalescing:_:)` must be able to tell "leave it alone"
/// from "set it to this". The two are observably different the moment the application path stops
/// being a raw store write, so the distinction is not merely stylistic: `.unchanged` skips the
/// application entirely, while `.caret(at: currentOffset)` runs it with a value that happens to
/// equal what is already there.
///
/// **Why a struct wrapping an Optional rather than the Optional itself.** The wrapper is what lets
/// a primitive's signature say `-> RichTextInputCaretOutcome` and read as an obligation. Tasks
/// 36b/36c convert `DocumentCanvasView+Editing.swift`'s end-of-primitive caret writes into `return`
/// statements of this type; an `Optional<RichTextCanonicalSelection>` return would spell the same
/// thing while inviting `?? current` at the call site, which is exactly the "claims the current
/// selection" collapse this type exists to keep separable.
///
/// **NOT ALL 34 OF THE FILE'S `anchor = …; head = …` LINES ARE CARET OUTCOMES — and the four that
/// are not look exactly like the ones that are.** (TASK 40a RESPELLED those four: they now read
/// `inputBackend.setCanonicalAnchor(r.location)` / `setCanonicalHead(r.location + r.length)`, which
/// is the identical non-publishing write, so grep for `setCanonicalAnchor` in `+Editing.swift` to
/// find them. Everything this paragraph says about them is unchanged.) 30 record where a primitive LEFT the caret and are
/// what 36b/36c convert. The other 4 (`legacyApplyMutation`'s `.insertText`, `.insertParagraphBreak`,
/// `.deleteBackward`, `.setMarkedText` cases) do the opposite: they **SEAT** the live selection as an
/// *input* to a witness invoked on the very next line, which reads it. `legacyApplyMutation` is a
/// DISPATCHER, not an `editing { }` body, so there is no "after `body()`" for a claim to be applied
/// at. Deferring those four to an outcome would run `legacyInsertText` / `legacyDeleteBackward` /
/// `legacySetMarkedText` against the PREVIOUS selection and land the text at the old caret; the
/// `.deleteBackward` case additionally re-reads `head` *after* its witness, to build `affected`.
/// **36b/36c must leave all four alone.** (Caught in Task 36a's review; the 30/4 arithmetic was
/// right and the semantic label on the 4 was not.)
///
/// **TASK 36b RESULT — the 30 are converted and the 4 are untouched, as written above.** What 36b
/// found that this note could not: the 30 sit in **26 primitives of two structurally different
/// kinds**, and only 11 of them are the "primitive returns, caller applies" shape the plan assumed.
/// The other 15 own their own `editing { }`, so they have no caller to return to and were converted
/// internally instead (`editing` + `return .caret(at:)`); they gained no new
/// signature, no wrapper and no deprecation. The distinction and its per-primitive tally are in
/// `DocumentCanvasView+Editing.swift` (`applyReplaceOutcome`'s own doc for the first kind,
/// `insertParagraphBreak` for the second).
@available(iOS 13.0, *)
struct RichTextInputCaretOutcome: Equatable {
    /// The claimed selection, or `nil` for "no claim". Deliberately `let`: an outcome is a value a
    /// primitive returns once, not a mutable accumulator.
    let selection: RichTextCanonicalSelection?

    /// The primitive made no claim. Until Task 36c this was what **every** `editing(coalescing:_:)`
    /// call site passed — the deleted `Void` overload's body returned it unconditionally, which was the
    /// whole transparency argument for introducing the overload. Now it is what a body returns when it
    /// genuinely claims nothing: a formatting or attribute-only transaction, or one that still writes
    /// `anchor`/`head` itself (Tasks 38-39 own the ones that remain; Task 37 cleared its three files).
    /// See `DocumentCanvasView+Editing.swift`.
    static let unchanged = RichTextInputCaretOutcome(selection: nil)

    /// A collapsed caret at `utf16Offset`. **All 30 convertible sites become this** — the ones
    /// spelling `anchor = X; head = X` (or `head = anchor`), one of them `self.`-qualified.
    /// Classified mechanically over the base commit rather than eyeballed; the four excluded
    /// seat-before-dispatch writes are described in the type's own doc comment above. **Task 36b
    /// carried that out and the prediction held: 30 conversions, 30 `.caret(at:)`, zero `.range`.**
    static func caret(at utf16Offset: Int) -> RichTextInputCaretOutcome {
        RichTextInputCaretOutcome(selection: .caret(at: .downstream(utf16Offset)))
    }

    /// A directional range. Argument order is `(anchor, head)` and is NOT normalized — a reversed
    /// claim stays reversed, because `RichTextCanonicalSelection`'s own `normalizedRange` note says
    /// the unordered pair is load-bearing (the canvas hands UIKit an unordered range for a reversed
    /// drag).
    ///
    /// **TASK 37 GAVE IT ITS FIRST TWO PRODUCTION USERS; TASK 38 ADDED TWO MORE AND TASK 39 SEVEN, SO
    /// THERE ARE ELEVEN.** Task 39's are `setSelectionHead`, `setSelectionAnchor`, `setBlocks`'s
    /// per-endpoint clamp, `selectAcrossBlocks`, `selectAcrossLeafRegions` (`DocumentCanvasView.swift`),
    /// `applySelection` (`+SelectionActions.swift`) and `composerSelectedRange`'s setter
    /// (`+ComposerSelection.swift`) — every one of them a site whose raw pair wrote two DISTINCT
    /// endpoints, or preserved one while moving the other. **Task 39 also probed all seven for a pin
    /// and three had none** (the clamp, since fixed, and the two demo helpers); the per-site figures
    /// are at `applyCaretOutcome`. The list below keeps 37's and 38's.
    /// All four are genuine directional ranges rather than the invented caller the previous wording
    /// forbade. Task 37's: `legacyApplySelectedTextRange` (`+UITextInput.swift`) applies whatever range
    /// UIKit set, and `legacySetMarkedText` (`+MarkedText.swift`) places the selection WITHIN the marked
    /// text. Task 38's are the two fold toggles — `toggleDetailsExpanded` (`+Details.swift`) and
    /// `toggleCollapsed` (`+QuoteCollapse.swift`) — whose caret-outside-the-box arm PRESERVES the
    /// pre-fold selection, which need not be collapsed. None may be normalized — the canvas hands UIKit
    /// an unordered range for a reversed drag and that is load-bearing (see
    /// `RichTextCanonicalSelection.normalizedRange`), which is exactly why this case does not sort its
    /// arguments.
    ///
    /// **AND SINCE THIS IS THE DOC SOMEONE READS WHILE CHOOSING BETWEEN `.caret` AND `.range`, THE
    /// WARNING BELONGS HERE: CHOOSING WRONG IS INVISIBLE TO THE SUITE.** Task 38 built
    /// `return .caret(at: remap(beforeHead))` in BOTH fold toggles and ran the full
    /// `Scripts/iostest.sh`: 2630 passed, 0 failures, byte-identical to the control, and both of that
    /// task's own named gates passed it too. The two spellings differ in exactly one state — a
    /// non-collapsed selection lying outside the folded box — and nothing in the tree constructs it.
    /// So a `.range` site that gets spelled `.caret` degrades a user's selection silently and ships
    /// green. **Reach for `.range` whenever the arm you are converting PRESERVES a selection rather
    /// than parking a caret, and do not let a passing suite talk you out of it.** The measurement's
    /// numbers live at the `+Details.swift` arm; this is a pointer, and the other two axes the suite
    /// is blind to are enumerated in the plan (Task 39, "the blind axes").
    ///
    /// **It had none until then, and the history is worth keeping.** An earlier version of this
    /// comment named `legacyApplyMutation`'s four seat-before-dispatch lines (spelled
    /// `anchor = r.location; head = r.location + r.length` until Task 40a respelled them onto
    /// `inputBackend.setCanonicalAnchor`/`setCanonicalHead`) as its first users. They are not outcomes at all (see the type's doc comment): they are
    /// seat-before-dispatch writes, and converting them would be a live bug. **All 30 sites 36b/36c
    /// converted leave a COLLAPSED caret**, so nothing in that arc produced a range; Task 37 was the
    /// first task whose population included a site that was not a caret, and Task 38 the second. The case also still serves
    /// its original purpose — a primitive that PRESERVES a selection, the shape `performEditing`'s
    /// undo-caret branch already distinguishes ("a selection-preserving edit leaves a range
    /// post-body"), can say so without reaching for the memberwise init.
    static func range(_ anchor: Int, _ head: Int) -> RichTextInputCaretOutcome {
        RichTextInputCaretOutcome(selection: RichTextCanonicalSelection(
            anchor: .downstream(anchor), head: .downstream(head)))
    }
}

// MARK: - Published state

@available(iOS 13.0, *)
struct RichTextInputStateSnapshot: Equatable {
    let documentRevision: UInt64
    let selection: RichTextCanonicalSelection
    let markedRange: NSRange?
    let isComposing: Bool
}

// MARK: - Composition snapshot

/// TASK 41 — the document + selection snapshot captured at composition START, registered as ONE undo
/// step at commit (so an undo removes the whole composed word, not each keystroke).
///
/// **ONE member, not two, deliberately.** It replaces the canvas's `compositionUndoSnapshot: [Block]?`
/// and `compositionAnchorHead: (Int, Int)?`, which were written together at every one of their four
/// write sites and read together at their one read site. This package has paid twice for the opposite
/// arrangement (`ChatHistoryListViewBackend`'s `enableUnreadAlignment` and `settledContentOffsets()`):
/// *a pair of raw members is a pair a backend can half-implement*. One value cannot be half-set.
///
/// It lives HERE rather than on `RichTextInputBackend.swift` because it names a `Block`, and that file
/// deliberately imports only UIKit — the shared contract stays free of the Core document model, and a
/// conformer sees one opaque snapshot type instead.
@available(iOS 13.0, *)
struct RichTextCompositionSnapshot {
    /// The whole document as it stood before the first provisional character landed.
    let blocks: [Block]
    /// The selection endpoints as they stood at that same moment, on the canvas's global axis.
    let anchor: Int
    let head: Int

    init(blocks: [Block], anchor: Int, head: Int) {
        self.blocks = blocks
        self.anchor = anchor
        self.head = head
    }
}

// MARK: - Mutation origin

@available(iOS 13.0, *)
enum RichTextInputMutationOrigin: Equatable {
    case softwareKeyboard
    case hardwareKeyboard
    case autocorrection
    case inlinePrediction
    case markedText
    case dictation
    case paste
    case programmatic
}

// MARK: - Semantic mutation intents

@available(iOS 13.0, *)
enum RichTextInputMutation {
    case insertText(
        text: NSAttributedString,
        replacing: RichTextCanonicalSelection,
        origin: RichTextInputMutationOrigin
    )

    case insertParagraphBreak(
        replacing: RichTextCanonicalSelection,
        origin: RichTextInputMutationOrigin
    )

    case replaceText(
        range: NSRange,
        text: NSAttributedString,
        origin: RichTextInputMutationOrigin
    )

    case deleteBackward(
        selection: RichTextCanonicalSelection,
        proposedRange: NSRange?
    )

    case deleteForward(
        selection: RichTextCanonicalSelection,
        proposedRange: NSRange?
    )

    case setBaseWritingDirection(
        direction: RichTextInputWritingDirection,
        range: NSRange,
        origin: RichTextInputMutationOrigin
    )

    case setMarkedText(
        text: NSAttributedString,
        replacing: NSRange,
        selectedRangeInMarkedText: NSRange
    )

    case unmarkText
}

// MARK: - Mutation result

@available(iOS 13.0, *)
struct RichTextInputPreparedMutation: Equatable {
    /// Opaque outside the document client that created it.
    let token: UUID
    let expectedRevision: UInt64
    let contentWillChange: Bool
    let selectionWillChange: Bool
}

@available(iOS 13.0, *)
enum RichTextInputMutationPreparation {
    case ready(RichTextInputPreparedMutation)
    case terminal(RichTextInputMutationResult)
}

@available(iOS 13.0, *)
struct RichTextInputMutationResult {
    enum Disposition: Equatable {
        case applied
        case rejected(RichTextInputMutationRejection)
        case noChange
    }

    let disposition: Disposition
    let revision: UInt64
    let selection: RichTextCanonicalSelection
    let markedRange: NSRange?
    let affectedRange: NSRange?
    let contentChanged: Bool
    let selectionChanged: Bool
    /// Deviation D10: `LegacyRichTextInputBackend`'s preparation is deliberately conservative —
    /// `contentWillChange`/`selectionWillChange` are `true` for every mutation that reaches
    /// `editing { }`, because `editing(coalescing:_:)` fires both will-notifications unconditionally
    /// before the body runs. This flag records that the preparation for this result was conservative
    /// rather than a true preflight, so a later reader does not mistake it for a bug.
    let legacyConservativePreparation: Bool
}

@available(iOS 13.0, *)
enum RichTextInputMutationRejection: Equatable {
    case revisionMismatch
    case invalidRange
    case notEditable
    case prohibitedStructuralEdit
    case unsupportedOperation
}

// MARK: - Geometry client result types

@available(iOS 13.0, *)
struct RichTextInputCaretGeometry {
    let position: RichTextInputPosition
    let rect: CGRect
    let writingDirection: RichTextInputWritingDirection
    let lineID: RichTextInputLineID
    let documentRevision: UInt64
    let layoutGeneration: UInt64
}

@available(iOS 13.0, *)
struct RichTextInputSelectionSegment {
    let range: NSRange
    let rect: CGRect
    let containsStart: Bool
    let containsEnd: Bool
    let writingDirection: RichTextInputWritingDirection
    let isVertical: Bool
    let documentRevision: UInt64
    let layoutGeneration: UInt64
}

@available(iOS 13.0, *)
struct RichTextInputNavigationResult {
    let position: RichTextInputPosition
    let anchorPositionOffset: CGFloat?
    let documentRevision: UInt64
    let layoutGeneration: UInt64
}

// MARK: - Geometry purpose and bounded selection requests

@available(iOS 13.0, *)
enum RichTextInputGeometryPurpose {
    case keyboard
    case caret
    case selectionEndpoint
    case selectionPresentation
    case loupe
    case floatingCursor
    case editMenu
    case accessibility
}

@available(iOS 13.0, *)
struct RichTextInputSelectionGeometryRequest {
    let range: NSRange
    let visibleRect: CGRect?
    let includeStartEndpoint: Bool
    let includeEndEndpoint: Bool
    let purpose: RichTextInputGeometryPurpose
}

/// Deviation D7: `.line` means "the whole enclosing leaf region" everywhere in this editor
/// (`S/Canvas/DocumentTokenizer.swift:33,73,165`) and `BlockLayoutEngine` exposes no line fragments, so
/// there is no true visual-line identity to hand out. `lineID` boxes `(BlockID, regionIndex)` — the
/// leaf-region identity — rather than the spec's opaque `AnyHashable`. It is comparable only within
/// the same layout generation, per the spec's own contract.
///
/// Consequence: this concrete type binds every future backend conforming to this contract to
/// expressing line identity as `(BlockID, regionIndex)` — exactly the coupling the spec's `AnyHashable`
/// was hedging against. A backend with a genuine visual-line concept (e.g. one line fragment per
/// wrapped row, not per leaf region) has no way to represent that distinction through this type without
/// either overloading `regionIndex` to mean something it doesn't say, or widening this struct later.
@available(iOS 13.0, *)
struct RichTextInputLineID: Hashable {
    let blockID: BlockID
    let regionIndex: Int
}

// MARK: - Presentation client types

@available(iOS 13.0, *)
enum RichTextSelectionEndpoint: Equatable {
    case anchor
    case head
}

@available(iOS 13.0, *)
enum RichTextInputInteractionState: Equatable {
    case inactive
    case caret
    case selecting(activeEndpoint: RichTextSelectionEndpoint?)
    case loupe
    case floatingCursor
}

@available(iOS 13.0, *)
struct RichTextInputPresentationSnapshot {
    let state: RichTextInputStateSnapshot
    let caret: RichTextInputCaretGeometry?
    let visibleSelectionSegments: [RichTextInputSelectionSegment]
    let visibleBounds: CGRect
    let isFirstResponder: Bool
    let selectionDisplayVisible: Bool
    let interaction: RichTextInputInteractionState
}

@available(iOS 13.0, *)
struct RichTextInputPresentationInvalidation: OptionSet {
    let rawValue: UInt

    static let caret = Self(rawValue: 1 << 0)
    static let selection = Self(rawValue: 1 << 1)
    static let handles = Self(rawValue: 1 << 2)
    static let markedText = Self(rawValue: 1 << 3)
    static let annotations = Self(rawValue: 1 << 4)
    static let spelling = Self(rawValue: 1 << 5)
    static let layout = Self(rawValue: 1 << 6)
    static let editMenu = Self(rawValue: 1 << 7)
    static let all: Self = [
        .caret, .selection, .handles, .markedText,
        .annotations, .spelling, .layout, .editMenu,
    ]
}

@available(iOS 13.0, *)
enum RichTextInputRevealTarget {
    case caret(RichTextInputPosition)
    case selectionEndpoint(RichTextSelectionEndpoint)
    case range(NSRange)
    case rect(CGRect)
}

@available(iOS 13.0, *)
enum RichTextInputEditMenuDismissReason {
    case selectionChanged
    case contentChanged
    case interactionBegan
    case responderTransition
    case policyChanged
}

// MARK: - Lifecycle client types

@available(iOS 13.0, *)
struct RichTextInputEditPolicy: Equatable {
    let isEditable: Bool
    let isSelectable: Bool
    let allowsRichText: Bool
    let allowsPaste: Bool
    let allowsDictation: Bool
    let allowsWritingTools: Bool

    static let legacyUnrestricted = RichTextInputEditPolicy(
        isEditable: true, isSelectable: true, allowsRichText: true,
        allowsPaste: true, allowsDictation: true, allowsWritingTools: true
    )
}

@available(iOS 13.0, *)
enum RichTextInputStateChangeReason {
    case selection
    case content
    case markedText
    case interaction
    case externalSynchronization
    case policy
}

@available(iOS 13.0, *)
enum RichTextInputLayoutRequestReason {
    case textMutation
    case selectionEndpoint
    case keyboardGeometry
    case interactionGeometry
    case annotation
    case viewport
}

// MARK: - Command client types

@available(iOS 13.0, *)
enum RichTextInputCommand: Equatable {
    case cut
    case copy
    case paste
    case selectWord
    case selectAll
    case delete
    case undo
    case redo
}

@available(iOS 13.0, *)
struct RichTextInputPreparedCommand: Equatable {
    let token: UUID
    let contentWillChange: Bool
    let selectionWillChange: Bool
}

@available(iOS 13.0, *)
struct RichTextInputCommandResult {
    let performed: Bool
    let revision: UInt64
    let selection: RichTextCanonicalSelection
    let contentChanged: Bool
    let selectionChanged: Bool
}

@available(iOS 13.0, *)
enum RichTextInputCommandPreparation {
    case ready(RichTextInputPreparedCommand)
    case terminal(RichTextInputCommandResult)
}

// MARK: - Attachment and teardown

@available(iOS 13.0, *)
enum RichTextInputBackendAttachmentError: Error {
    case alreadyAttached
    case incompatibleHost(String)
    case missingCapability(String)
    case invalidInitialState(String)
    case privateRuntimeFailure(String)
}

// MARK: - External changes and programmatic selection

@available(iOS 13.0, *)
enum RichTextInputExternalChangeReason {
    case initialDocument
    case documentReplacement
    case undo
    case redo
    case formatting
    case structuralCommand
    case remoteUpdate
    case layoutOnly
}

@available(iOS 13.0, *)
extension RichTextInputExternalChangeReason {
    /// TASK 41 — **does a change of this reason leave the OFFSETS of existing characters where they
    /// were?** The one question `.preserveIfRebasable` actually needs answered: a marked range is a
    /// pair of offsets, so it survives verbatim exactly when nothing moved under it.
    ///
    /// **Why the REASON and not a revision comparison** — measured, not preferred.
    /// `reconcileMarkedTextForExternalChange`'s fast path used to ask `document.revision !=
    /// documentRevision`, i.e. the client's LIVE revision against the backend's CACHED one. Deviation
    /// D38 makes those two diverge after any typing (the cache only advances at external-sync time,
    /// and no routed witness reaches `prepareAndRun`), so with composition state finally live the
    /// guard stopped firing and a width reflow mid-composition dropped the composition — MEASURED at
    /// Task 41 step 3, `("nil") is not equal to ("Optional({2, 2})")`. Fixing the CALLER instead
    /// (passing the canvas's own counter as `oldRevision`, which is what D38's obligation literally
    /// asks for) was also built and measured, and is worse: all five production sites then raise
    /// `revision continuity violated … but this backend has adopted 0`, an `assertionFailure` in
    /// DEBUG. That obligation's precondition — "once the backend owns the mutation path, its counter
    /// advances independently" — is NOT met at Task 41; it belongs to whichever stage-2 task routes
    /// mutations through `prepareAndRun`. See the Task 41 report for both measurements.
    ///
    /// The reason is an authority this code ALREADY trusts for a structurally identical question:
    /// `synchronizeAfterExternalChange` skips adopting `change.newRevision` on `case .layoutOnly`
    /// alone, on the same "the document did not really move" claim from the same origination point.
    ///
    /// **Exhaustive on purpose — no `default`. A new reason must be classified here deliberately, and
    /// READ THE DIRECTION OFF THE CONSUMER, not off the name.** The one consumer is
    /// `reconcileMarkedTextForExternalChange`'s `.preserveIfRebasable` branch
    /// (`LegacyRichTextInputBackend.swift`), and its shape is
    /// `if change.reason.preservesTextOffsets { return }`:
    ///
    ///   * **`true` RETURNS EARLY and KEEPS the range verbatim** — no rebase, no validation, nothing
    ///     asked of the document client. It is a claim that the offsets are still correct.
    ///   * **`false` FALLS THROUGH to `document.rebase(_:fromRevision:)`**, which against the real
    ///     `TelegramDocumentInputClient` is identity-or-nil (D32) and therefore DISCARDS the
    ///     composition whenever the revision moved.
    ///
    /// So the two error directions are:
    ///   * **`true` in error ⇒ a marked range left pointing at text that MOVED.** Silent, and the
    ///     damage lands later: the next committing keystroke reaches `+UITextInput.swift`'s
    ///     marked-commit, which calls `applyReplaceOutcome(globalFrom: m.from, globalTo: m.to, …)`
    ///     with stale offsets. `clampGlobal` prevents a crash, so the symptom is the WRONG SPAN of
    ///     the new document being replaced, with nothing logged.
    ///   * **`false` in error ⇒ a dropped composition.** Visible immediately, recoverable by retyping,
    ///     and exactly what every reason did before this property existed.
    ///
    /// **WHEN IN DOUBT ANSWER `false`.** That is the conservative side: it attempts a rebase, and the
    /// real client answers identity-or-nil rather than remapping. `true` is a promise the code cannot
    /// check.
    ///
    /// (TASK 41 FIX ROUND 1, review M1 — this paragraph shipped with **both** direction words and the
    /// parenthetical inverted, recommending `true`. It was written against an earlier draft in which
    /// the returns had the opposite polarity; the polarity was corrected when the failing test caught
    /// it, and the prose was not re-read. Recorded rather than quietly repaired, because it is the
    /// sharpest available example of the hazard the paragraph is about: a guidance sentence and the
    /// code it guides can disagree with no token in common, and only the consumer settles it. Every
    /// case below now states its direction in words as well as returning a value, so a future reader
    /// comparing the two has a second source.)
    var preservesTextOffsets: Bool {
        switch self {
        case .layoutOnly:
            // KEEPS the range (no rebase). Geometry only, by definition — the same claim the
            // revision-adoption skip in `synchronizeAfterExternalChange` is keyed on.
            return true
        case .formatting:
            // KEEPS the range (no rebase). Attribute-only. Both production sites (`applyCharacterToggle`, `applyCharacterAttribute`
            // in `DocumentCanvasView+CharacterFormat.swift` / `+Links.swift`) mutate NSTextStorage
            // ATTRIBUTES inside `editing { }` and return `.unchanged`; no glyph is added or removed.
            // `applyCharacterToggle`'s own call-site comment has always said so ("the text length does
            // not change, so a marked range survives in principle") — this is where "in principle"
            // becomes the mechanism. A `.formatting` site that changed lengths would be misusing the
            // reason, and would drop compositions silently; say `.structuralCommand` instead.
            return true
        case .initialDocument, .documentReplacement, .undo, .redo, .structuralCommand, .remoteUpdate:
            // REBASES, and therefore discards against the real client. All of these can replace or
            // reflow text. The marked range must be rebased, and against
            // the real `TelegramDocumentInputClient` (whose `rebase` is identity-or-nil by D32) that
            // means `.preserveIfRebasable` legitimately degrades to `.discard` — which is correct:
            // the characters the composition was expressed over may no longer exist.
            return false
        }
    }
}

@available(iOS 13.0, *)
enum RichTextMarkedTextPolicy {
    case preserveIfRebasable
    case commitBeforeChange
    case discard
}

@available(iOS 13.0, *)
struct RichTextInputExternalChange {
    let oldRevision: UInt64
    let newRevision: UInt64
    let reason: RichTextInputExternalChangeReason
    let changedRangeBefore: NSRange?
    let changedRangeAfter: NSRange?
    let selection: RichTextCanonicalSelection
    let markedTextPolicy: RichTextMarkedTextPolicy
}

@available(iOS 13.0, *)
enum RichTextSelectionChangeReason {
    case keyboard
    case touch
    case floatingCursor
    case command
    case programmatic
    case externalSynchronization
}

// MARK: - Interaction routing

@available(iOS 13.0, *)
enum RichTextInteractionCancellationReason {
    case responderLoss
    case windowDetach
    case policyChange
    case documentReplacement
    case backendDetach
}

// MARK: - Transaction phase

@available(iOS 13.0, *)
enum RichTextInputTransactionPhase {
    case idle
    case notifyingWillChange
    case mutatingDocument
    case notifyingDidChange
    case publishingState
    case detaching
}
#endif
