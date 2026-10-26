#if canImport(UIKit)
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
import RichTextInputDecHost

/// The pasteboard the table commands write to — a one-method seam so a test can assert what was
/// written without touching the device pasteboard, which is why `DocumentCanvasView` has one too.
///
/// NOT `TextPasteboard`: that protocol is internal and lives under `Canvas/`, which this branch does
/// not edit. R7-paste should widen THIS one rather than reach in there.
internal protocol EnginePasteboard: AnyObject {
    func setItems(_ items: [[String: Any]], options: [UIPasteboard.OptionsKey: Any])
}

extension UIPasteboard: EnginePasteboard {}

/// A Telegram rich-text editor whose text behaviour IS the InputDec engine's.
///
/// It owns no text layout, no caret geometry, no selection model and no input handling. It maps
/// Telegram's `Document` onto the engine's `attributedBlocks` and forwards everything else.
/// Members that have not reached their rung TRAP rather than answering (Global Constraint 6).
@available(iOS 18.4, *)
public final class RichTextEngineEditorView: UIView {
    internal let engine: TGIDObservingBlockTextView
    /// `var`, not `let`: a theme change rebuilds the mapper (the theme IS a mapper input — it
    /// supplies `primaryText`, so it decides the colour the engine renders text in), and the bridge
    /// owns the mapper. See `theme` in `+ComposerHost.swift`.
    internal var bridge: EngineDocumentBridge {
        didSet { lineAttributesByShape.removeAll() }
    }
    /// The providers' answers, memoised by what makes two empty lines render alike (the role, the
    /// block's kind and the paragraph fields the stylesheet reads) — a probe render each otherwise.
    internal var lineAttributesByShape: [String: [NSAttributedString.Key: Any]] = [:]
    /// Kept so `renderMetrics` can rebuild the bridge around a re-metricked copy.
    private var mapper: AttributedStringMapper
    private var observer: EngineObserver!

    /// The current paragraph structure. This is CACHED state, refreshed only from the engine's own
    /// change funnel (`engineDidChangeDocument`, R1) — the `document` getter never calls the bridge
    /// itself. INTERNAL, not private: a later task adds an extension to this type in a different
    /// file, and Swift `private` does not reach across files.
    ///
    /// This indirection is load-bearing, not a style choice. `EngineDocumentBridge.document(
    /// fromAttributedBlocks:engineIdentifiers:reusingStructureOf:)` mints a FRESH `BlockID` for any
    /// engine block whose `NSUUID` the identity table has never seen. If the getter instead called
    /// the bridge fresh on every read against a table that is only refreshed on edits, nothing would
    /// be wrong — but the recompute would run on every property read, and any window in which the
    /// table is stale (the engine having minted an identifier we have not recorded yet) would mint a
    /// NEW `BlockID` on every single call. Two back-to-back `editor.document` reads for the very same
    /// on-screen paragraph would then disagree, which no test asserting only block *counts* would
    /// ever catch. See `EngineEditorDocumentTests.test_twoConsecutiveDocumentReadsAreIdentical`,
    /// which pins this by reading `editor.document` twice with no engine mutation in between.
    /// One role per ENGINE block — the source of truth. A block quote is 1-to-N with engine blocks,
    /// so the model `Document` is DERIVED from this by grouping rather than stored.
    internal var currentRoles: [EngineBlockRole] = []
    /// Pooled by the LINE's id, which is unique per container and kind.
    internal var secondaryPlaceholderLabels: [BlockID: SecondaryPlaceholderLabel] = [:]

    /// The same array as model blocks, still one entry per ENGINE block: a quote's child appears as
    /// the child itself. Consumers that index the cache by engine block index — the flat-offset
    /// mapping, the paragraph commands — read this and are unaffected by grouping.
    internal var currentBlocks: [Block] { bridge.blocks(for: currentRoles, from: engine.attributedBlocks) }

    /// The `NSUUID` -> `ParagraphBlock` table spec §5.3 mandates: "Block identity bridges `BlockID`
    /// <-> `NSUUID` in a table the host layer owns, so neither model learns the other's identifier
    /// type." The engine names its blocks with `NSUUID`s and answers which of them survived an edit
    /// (`TGIDObservingBlockTextView.tgid_blockIdentifiers`, reading `IDBlockDocument.blocks`); this
    /// table is the only place that answer is joined to Telegram's `BlockID` and paragraph structure.
    ///
    /// Refreshed in lockstep with `currentBlocks`, from the SAME `tgid_blockIdentifiers` read
    /// that produced them (`recordBlockIdentities(_:)`), so the two can never describe different
    /// moments. Entries for identifiers the engine no longer reports are dropped rather than kept:
    /// an `NSUUID` is never reused by the engine, so a retained entry could only ever be dead weight.
    private var structureByEngineIdentity: [UUID: EngineBlockRole] = [:]

    /// Host configuration for capabilities this rung does not have yet. See
    /// `RichTextEngineEditorView+DeferredConfiguration.swift` for the rule that governs what may
    /// live here and why storing it is not the "plausible default" the trap discipline bans.
    /// Injectable pasteboard (defaults to the system one; tests inject a fake). See
    /// `copyCurrentTable` in `+TableCommands.swift`.
    internal var pasteboard: EnginePasteboard = UIPasteboard.general

    /// The table structural selection — a second axis alongside the text selection. See
    /// `+TableSelection.swift`.
    ///
    /// The READ is authoritative: a selection naming a table the roles no longer hold reads as nil,
    /// so it cannot outlive its table however the table went away. That is deliberately not a clear
    /// at each removing site — `deleteTable` edits flat and never touches the document setter, so a
    /// setter-side clear missed it entirely, and the next removal route would miss it again. One
    /// guarded READ has no site to forget, which is the same argument as the single guarded clear in
    /// the selection funnel.
    internal var tableStructuralSelection: (table: BlockID, kind: EngineTableStructuralSelection)? {
        get {
            guard let stored = storedTableStructuralSelection,
                  roleRun(ofTableWithID: stored.table) != nil else { return nil }
            return stored
        }
        set {
            storedTableStructuralSelection = newValue
            // The trait states are ACROSS this selection, so they mean nothing once it moves.
            cachedStructuralTraits = nil
        }
    }

    private var storedTableStructuralSelection: (table: BlockID, kind: EngineTableStructuralSelection)?

    /// Set for the duration of a structural selector's own caret park, so the selection funnel does
    /// not clear the selection that selector is in the middle of making.
    internal var isParkingCaretForStructuralSelection = false

    /// Pooled custom-emoji views, keyed by `EmojiRef.instanceID`. See `+CustomEmoji.swift`.
    internal var customEmojiViews: [String: UIView & RichTextEmojiView] = [:]

    /// Pooled spoiler dust, keyed by the run's canonical range. See `+SpoilerDust.swift`.
    /// Coalescing flag for the selection-driven `onChange`, mirroring the legacy facade.
    ///
    /// A command that follows a selection change in the SAME turn owns the selection's
    /// notification too: `flushPendingChangeNotification()` clears this flag itself when it
    /// delivers synchronously, so the coalesced fallback below — which may already be queued from
    /// that earlier selection change — finds it false when its turn comes and stands down, rather
    /// than firing a second time for a change its own delivery already reported.
    private var isSelectionOnChangeScheduled = false

    internal var spoilerDustViews: [NSRange: SpoilerDustView] = [:]

    /// Container decoration views, pooled by the HOST's block identity rather than by engine
    /// `NSUUID`: a container survives an edit as the same `BlockID` (that is what the structure table
    /// guarantees), so keying here on the same thing keeps a band from being torn down and rebuilt
    /// every keystroke.
    internal var containerDecorationViews: [BlockID: ContainerDecorationView] = [:]

    /// List markers, pooled by the LIST ITEM's block id — the bullet/ordinal label view, or the
    /// host's checkbox for a checklist. See `+ListMarkers.swift`.
    internal var listMarkerViews: [BlockID: UIView] = [:]
    /// Fold chevrons, keyed by the DETAILS' id (not its title line's — separate pool identities).
    internal var detailsChevronViews: [BlockID: DetailsChevronView] = [:]

    /// Hosted media views, pooled by the media block's id. See `+MediaHosting.swift`.
    internal var mediaAtomViews: [BlockID: MediaAtomHostView] = [:]

    /// Hosted button-row views, keyed by the row's `BlockID`. ENGINE-OWNED — unlike a media host
    /// view, nothing external supplies one — which is why `EngineDerivedViewExpectation` can check
    /// this pool and deliberately cannot check that one.
    internal var buttonRowViews: [BlockID: RichTextButtonRowView] = [:]
    /// One preview view per FOLDED quote, keyed by the quote's own id. ENGINE-owned — no host
    /// provider can decline it — so it is checkable in the forward direction, unlike a media atom.
    internal var collapsedQuoteViews: [BlockID: CollapsedQuotePreviewView] = [:]
    /// One collapse glyph per OPEN quote that is taller than its own preview, keyed by the quote's
    /// id. A folded quote's glyph belongs to its preview view instead, so the two never coexist.
    internal var quoteCollapseGlyphViews: [BlockID: InflatedTouchGlyphView] = [:]

    /// Hosted INLINE button pills, keyed by CANONICAL OFFSET. An inline `ButtonRef` is a pure value
    /// with no identity of its own — unlike an `EmojiRef`, which has an `instanceID` — so position
    /// is the only stable key available.
    internal var inlineButtonPillViews: [Int: RichTextButtonPillView] = [:]

    /// Transparent tap targets over rendered formulas, keyed by CANONICAL OFFSET — a formula run is
    /// a pure value with no identity of its own, so position is the only stable key.
    internal var formulaTapTargets: [Int: EngineFormulaTapTarget] = [:]

    /// Refuses a touch that lands on host chrome inside a placed run while that run is MOVING, so a
    /// tap which catches a scrolling or bouncing table presses nothing under the finger. One object
    /// for every such recogniser — see `+RunTouchGate.swift`.
    internal lazy var runTouchGate = EngineRunTouchGate(editor: self)

    /// Drags a table's resize KNOB. Lives on the editor rather than on the knob's own view so the
    /// knob's 44pt box claims a drag WITHOUT claiming the tap under it — see
    /// `TableStructuralChromeView.point(inside:)` for the 77%-of-a-cell measurement that forced this.
    internal lazy var tableKnobPan: UIPanGestureRecognizer = {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleTableKnobPan(_:)))
        pan.delegate = tableKnobPanGate
        return pan
    }()

    /// Decides whether `tableKnobPan` begins, and remembers WHICH knob for the gesture's duration.
    internal lazy var tableKnobPanGate = EngineTableKnobPanGate(editor: self)

    /// The text drag and the drop target, which the engine does not provide (`+DragAndDrop.swift`).
    internal lazy var textDragAndDrop = EngineTextDragAndDrop(editor: self)

    /// The grid each table was last solved on, keyed by the table's id. Written by
    /// `syncTableFrames()`; read by the cell insets and the chrome.
    internal var tableGrids: [BlockID: EngineTableGrid] = [:]

    /// The roles an undo or redo replay is restoring, installed by the snapshot handler the
    /// resolver registers in the keystroke's undo group (`registerReplayRoleSnapshot`). A replay
    /// re-inserts blocks under NEW engine identities, so the identity table cannot know them;
    /// the snapshot is adopted positionally once the replayed document has its block count.
    /// The gate is deciding a keystroke (surface-gate spec §3.1): its own edits report back through
    /// `engineDidFinishEdit`, which must not settle in the middle of them.
    internal var isDecidingAtGate = false
    /// Settle is running: its own edits report back too.
    internal var isSettling = false
    /// A host COMMAND is issuing its own structural edits (`performHostStructuralEdit`): the gate
    /// decides keystrokes, and a command has already decided — it carries its plan.
    internal var isIssuingHostEdit = false
    /// Engine identities first seen since the last settle — the blocks the edit minted, for settle
    /// to declare (surface-gate spec §3.2.1).
    internal var freshSinceSettle: Set<UUID> = []
    /// The roles before the keystroke's first change, for the replay snapshot.
    internal var rolesBeforeEdit: [EngineBlockRole]?
    /// Whether the gate or settle changed structure this keystroke (then a snapshot is registered).
    internal var structureTouchedThisEdit = false
    /// The roles a structural edit produces, adopted by position in that edit's own change
    /// notification (`replaceFlat(_:with:adopting:)`, structure-only roles design §3).
    internal var pendingRolePlan: [EngineBlockRole]?
    /// Engine identities whose text an edit touched or whose role changed since the last settle:
    /// settle re-derives their presentation from their roles (`normalisePresentation`).
    internal var touchedSinceSettle: Set<UUID> = []
    private var undoManagerObservers: [NSObjectProtocol] = []
    /// How many times `verifyDerivedViewsAreComplete` has run. A test seam: it pins that the check is
    /// CALLED, not merely that it is correct.
    internal var derivedViewVerificationCount = 0
    /// The placement check's own test seam, for the same reason the one above has one: a check that
    /// nothing invokes is the defect these instruments exist to catch.
    internal var derivedViewPlacementVerificationCount = 0

    /// Where each table's grid sits in its engine run — the single value that places both a table's
    /// cells and its chrome. Written by `syncTableFrames()`, read by `syncTableChrome()`, which used
    /// to derive its own: that was the same number until adjacent tables gained a run offset, and
    /// then the cells moved and the grid did not, which is a table drawn on top of the block above it
    /// (K3, 2026-09-08).
    internal var tablePlacements: [BlockID: TablePlacement] = [:]
    /// Where each table's run is scrolled, as the HOST believes it — mirrored from the engine on
    /// every settled pass, and pushed back on the first pass after the table's cells were rebuilt.
    ///
    /// This replaced a "park the offset at the edit, put it back later" scheme that produced three
    /// separate defects: the value had to be recorded before the change notification (the article
    /// host lays out synchronously from it), it was applied on an event that a pass could fail to
    /// deliver, and a measurement probe could spend it against a width nobody had committed to.
    /// Nothing is parked here, so none of those has anywhere to happen: the offset the host wants is
    /// always known, and every pass either learns it or re-asserts it.
    internal var runScrollOffsets: [BlockID: CGFloat] = [:]
    /// The cell identities each mirrored offset was taken against. A splice keeps the FIRST cell and
    /// mints the rest, so a change here is how the host knows the engine clamped its offset while the
    /// run was one cell wide rather than the user having scrolled to the start.
    internal var runScrollIdentities: [BlockID: [UUID]] = [:]
    /// Set while `height(forWidth:)` probes. The probe lays the engine out at a width the caller has
    /// not committed to, and `engineDidLayout` is post-layout WORK — it puts parked scroll offsets
    /// back and re-places the structural chrome. Run from a probe, that work reads a geometry that
    /// is about to be thrown away: a parked offset would be spent, clamped against the probed width,
    /// on a layout no one ever sees. A query must leave no state behind, the frame included.
    internal var isMeasuringHeight = false
    /// Set while the host's own `layoutSubviews` is placing derived views. The engine lays out in the
    /// middle of that pass — `syncTableFrames` pushes frames and the engine reconciles synchronously
    /// — and the views placed AFTER that point are legitimately stale at that moment, so the check
    /// belongs at the end of the pass and not in the middle of it.
    internal var isPlacingDerivedViews = false
    /// Set while `currentInlineTraits()` parks the selection in each cell of a structural selection
    /// to read its traits. The funnel treats a selection change under this flag as not having
    /// happened — it is restored before the call returns, and reporting it scheduled a host update
    /// that asked for the traits again, which asked for them again.
    internal var isProbingInlineTraits = false
    /// The four trait states across the structural selection, until the document or that selection
    /// changes. Nothing else can change the answer, and the probe that computes it is expensive
    /// enough that the toolbar must not pay for it on every host update.
    internal var cachedStructuralTraits: InlineTraitQuartet?

    internal var tableChromeViews: [BlockID: TableChromeView] = [:]

    /// Pooled structural chrome — the selection outline, grips and knobs. One per table, and only for
    /// the table the caret (or the committed selection) is in. See `+TableStructuralChrome.swift`.
    internal var tableStructuralChromeViews: [BlockID: TableStructuralChromeView] = [:]

    internal var deferredConfiguration = DeferredConfiguration()

    /// Composer-host state with no engine equivalent — but every field is READ on this rung, so
    /// unlike `deferredConfiguration` none of it is inert. See `+ComposerHost.swift`.
    internal var composerHostState = ComposerHostState()



    /// The body placeholder, drawn by us because THE ENGINE HAS NO PLACEHOLDER CONCEPT — grep
    /// `Sources/RichTextInputDecUpstream/` and the only hits are an unrelated UIKit insertion-rect
    /// parameter. Legacy renders its equivalent inside the frozen `Canvas/` directory
    /// (`BlockBox.swift:257`), which this path cannot reuse.
    ///
    /// This is deliberately NOT in the deferred-configuration register: that register requires every
    /// entry to name the rung that will consume it, `placeholders` can name none, and a composer
    /// whose placeholder never appears is visibly broken rather than merely incomplete. Only
    /// `placeholders.body` is honoured here; the block-specific entries (pull quote, code block,
    /// details title) have no blocks to attach to until R7.
    internal lazy var bodyPlaceholderLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 1
        label.isUserInteractionEnabled = false
        label.textColor = .placeholderText
        label.isHidden = true
        return label
    }()

    /// True while a host-driven `document` set is in flight. Gates BOTH halves of
    /// `engineDidChangeDocument` — the cache recompute and the `onChange` notification — with the
    /// same single guard, not just the notification. A host-driven set already knows its own
    /// resulting structure (it just handed `newValue` to the setter); letting the synchronous
    /// engine callback that `tgid_setAttributedBlocks` triggers overwrite the cache with the
    /// bridge's round-tripped runs would be observable even here — `AttributedStringMapper` pins
    /// every run's `fontSize` to its rendered point size on read-back (see `EngineDocumentBridge`'s
    /// doc comment), so a run set with `fontSize == nil` would come back non-nil on the very next
    /// read, and `test_settingTheDocumentIsReadableBack` would fail for a reason that has nothing to
    /// do with user editing. A host-driven set is not a user edit, and must leave no trace of one.
    private var isApplyingHostDocument = false

    /// A host `document` set has changed the text and has not been DRAWN yet.
    ///
    /// It is closed by the layout pass that draws it, which is also the pass that has to draw the
    /// caret — see `tgid_flushSelectionDisplayUpdate` for why the engine's own flush cannot: the set
    /// moves the caret twice (its own clamp, then the command's placement) and spends the flush on
    /// the first. Kept as a flag rather than asked of the engine because only the host knows that
    /// the second move is part of the same change and not a bare selection move.
    private var hostChangeAwaitingCaretDraw = false

    // MARK: - The editor's own undo stack (`+UndoStack.swift`)

    /// The ONE undo stack this editor has. `TGIDObservingBlockTextView.tgid_undoManagerOverride` is
    /// pointed at it, so ⌘Z, shake, the edit menu's Undo and the host's toolbar button are the same
    /// stack by construction rather than by two code paths agreeing.
    internal let engineUndoManager = EngineUndoManager()

    /// The editor as it stood after the last settled edit — the state an undo of the CURRENT edit
    /// must return to. Updated at the end of settle, and captured by value when a step is
    /// registered, so it is free to move on afterwards.
    internal var lastSettledUndoSnapshot: EngineUndoSnapshot? {
        didSet { undoStepRegisteredAgainstBaseline = false }
    }

    /// Whether an edit has already registered a step restoring `lastSettledUndoSnapshot`. A second
    /// registration against the same baseline can only restore what the first already does.
    internal var undoStepRegisteredAgainstBaseline = false

    /// Counts every undo step this editor registers (`registerUndoStep`). Compared across a keystroke
    /// the gate decided, it tells whether that keystroke left a step for a composition to join.
    internal var undoStepRegistrationCount = 0

    /// `undoStepRegistrationCount` when the gate last began deciding a keystroke.
    internal var undoStepRegistrationCountAtGateEntry = 0

    /// The flat offset a typing run currently ends at, or nil when no run is open. The whole of the
    /// coalescing policy — see `+UndoStack.swift`.
    internal var openTypingRunEnd: Int? {
        didSet { if openTypingRunEnd == nil { openRunEndsInComposition = false } }
    }

    /// Whether the edit that last moved `openTypingRunEnd` was a composition's — the one case where
    /// a REPLACEMENT continues the run (a candidate replacing the marked text that ends it).
    internal var openRunEndsInComposition = false

    /// The step a composition OPENED (its first candidate, contiguous with no run), held back until
    /// the composition ends: registered then if the document changed, dropped if it did not — a
    /// cancelled composition records nothing, as a stock text view's does (composer harness p21,
    /// `HarnessCancelledCompositionUndoTests`). See `resolvePendingCompositionUndoStep()`.
    internal var pendingCompositionUndoStep: EngineUndoSnapshot?

    /// The body line minted for a composition that started at an atom's stop, and the undo
    /// baseline from before it (`resolveAtomStopBeforeComposition`), until the composition ends.
    internal var compositionMintedLine: (identifier: UUID, baseline: EngineUndoSnapshot)?

    /// Set while a snapshot is being restored, so the restore is not recorded as a fresh edit.
    internal var isApplyingUndoSnapshot = false

    /// R6/Task 8 fix round 1 — state for the DEFERRED list-continuation reconciliation
    /// (`+Paragraph.swift`). `engineDidChangeDocument()`'s original synchronous reconciliation
    /// re-entered `tgid_setAttributedBlocks` from INSIDE `-processEditing`/`documentChangeHandler`
    /// (`IDCanonicalTextStorageAdapter.m:158-162` invokes the handler synchronously right after
    /// `[super processEditing]`, itself called from the ORIGINAL edit's own `endEditing`) — real
    /// `NSTextStorage` mutation during its own edit-processing notification, which is exactly the
    /// hazard the IME/marked-text and inline-prediction paths this design protects cannot risk. The
    /// reconciliation is now deferred to the next main-runloop turn instead. INTERNAL, not private:
    /// `+Paragraph.swift` reads/writes both (a stored property cannot be added from an extension in
    /// another file — or any extension at all — so both live here on the primary declaration).
    internal var pendingListContinuationBlockIDs: Set<BlockID> = []
    internal var isListContinuationReconciliationScheduled = false

    /// An `onChange` the consumer is owed for an engine-observed edit, not yet delivered.
    ///
    /// `onChange` is CONSUMER code — the real one (`RichTextEditorChatInputNode.swift:259-269`) runs
    /// a full layout pass from it — and `engineDidChangeDocument()` is called from inside
    /// `-[IDCanonicalTextStorageAdapter processEditing]` (`IDCanonicalTextStorageAdapter.m:156-166`
    /// invokes `documentChangeHandler` there, synchronously, from the original edit's own
    /// `endEditing`). Running TextKit layout inside the text storage's own edit processing is the
    /// same hazard Task 8 already deferred its own mutation off; this is the consumer half of it.
    ///
    /// So the notification is never fired from that callback. It is marked pending and delivered
    /// from a stack that is provably not `-processEditing`, by whichever of these gets there first:
    ///
    ///  * `deliveringChangeNotification { … }` — wraps every engine mutation this class initiates
    ///    itself (`insertText`, `deleteBackward`, `pasteFromPasteboard`, the four inline toggles).
    ///    The engine call has fully returned by then, so the flush is synchronous for the CALLER
    ///    while being off the engine's edit-processing stack. This is what keeps a host-driven
    ///    mutation's notification observable in the same turn, which the composer stand-in and the
    ///    list-continuation deferral control both depend on.
    ///  * the coalesced `DispatchQueue.main.async` flush scheduled alongside the flag — the only
    ///    path for an edit UIKit drove straight into the engine (real keyboard typing, autocorrect,
    ///    dictation, marked text), where this class has no call of its own to flush after.
    ///  * `deliverChangeNotificationNow()` — a mutation that produces no engine change funnel call
    ///    of its own to piggy-back on, because its `document =` set is `isApplyingHostDocument`-
    ///    gated: the five structural mutators (`+Paragraph.swift`'s `mutateTouchedParagraphs`) and
    ///    the deferred list-continuation reconciliation's trailing release.
    ///
    /// A caller that already changed the selection just BEFORE invoking a command (a drag-select
    /// immediately followed by a Format-menu tap, in the same run-loop turn —
    /// `RichTextAttachmentScreen.focusEditorAtDocumentEndIfNeeded` then the Quote action is a real
    /// production instance) has ALREADY scheduled the coalesced selection-driven fallback for that
    /// selection change before any of the bullets above run. That is a THIRD, independent path to a
    /// double delivery, and none of the three bullets close it on their own — the fix lives on the
    /// selection side instead: see `isSelectionOnChangeScheduled`'s doc comment.
    ///
    /// **Exactly once, because `flushPendingChangeNotification()` is the ONLY place `onChange?()` is
    /// ever called, and it clears the flag before calling.** That is the whole invariant, and it is
    /// the one this class got wrong once already: the structural mutators used to call `onChange?()`
    /// directly, without touching the flag. A keyboard-direct edit would mark the flag and enqueue
    /// the coalesced flush; a structural mutator running before that turn would deliver (its own
    /// `document =` set being gated, the flag survived); and the stale flush would then deliver a
    /// SECOND time for state already reported. Routing every delivery through the one function is
    /// what makes the claim above true rather than merely intended — see
    /// `EngineEditorDocumentTests.test_aStructuralMutatorDuringAPendingCoalescedFlushFiresOnChangeExactlyOnce`.
    /// Any new delivery site must go through it too.
    private var isChangeNotificationPending = false
    private var isChangeNotificationFlushScheduled = false
    /// How many `deliveringOneChangeNotificationAcrossSteps` bodies are running. While it is above
    /// zero a flush keeps the notification owed instead of delivering it, so a verb made of several
    /// steps that each deliver on their own is still reported ONCE, at its end.
    private var changeNotificationBatchDepth = 0

    public var onChange: (() -> Void)?
    /// See `RichTextEditor.onCaretRevealNeeded`: the synchronous report that a reveal is owed,
    /// deliberately not folded into `onChange`, which is coalesced.
    public var onCaretRevealNeeded: (() -> Void)?

    /// Set between an engine document change and the `textInputDidChange:` that ends it, so a
    /// selection change arriving in the middle of a keystroke is not reported as a caret move of its
    /// own. Measured: one `insertText` reaches the engine's caret path three times — the
    /// document-change reconcile, UIKit's selection settle, then `textInputDidChange:` — and only the
    /// last has settled geometry, so a host told at the first two would lay out against states it
    /// should not act on.
    internal private(set) var isEngineEditInFlight = false
    public var onSelectionChange: (() -> Void)?

    public init(frame: CGRect, mapper: AttributedStringMapper = AttributedStringMapper()) {
        // The quote's trailing inset is resolved HERE and not only in its setter: a host that never
        // assigns a `quoteStyle` still gets `QuoteStyle.default`'s 22, which is what the legacy
        // canvas does (`DocumentCanvasView` pushes its own default into the sheet). A knob whose
        // default never reaches the sheet is the deferred-configuration trap this module keeps
        // hitting — the value would have applied in the article editor, which assigns one, and
        // nowhere else.
        let mapper = Self.resolvingQuoteStyle(QuoteStyle.default, into: mapper)
        bridge = EngineDocumentBridge(mapper: mapper,
                                     pullQuoteStyle: deferredConfiguration.pullQuoteStyle,
                                     mediaBlockStyle: deferredConfiguration.mediaBlockStyle)
        self.mapper = mapper
        composerHostState.theme = mapper.theme
        engine = TGIDObservingBlockTextView(frame: CGRect(origin: .zero, size: frame.size),
                                           attributedBlocks: [NSAttributedString(string: "")])
        super.init(frame: frame)
        engine.isEditable = true
        engine.isSelectable = true
        engine.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(engine)
        observer = EngineObserver(owner: self)
        engine.observationSink = observer
        // The table's resize knobs drag from HERE, not from their own views — a 44pt knob box is the
        // right drag target and the wrong tap target, and a view that owns the touch takes the tap
        // with it. See `TableStructuralChromeView.point(inside:)`.
        addGestureRecognizer(tableKnobPan)
        // The composer owns its horizontal padding: the panel insets the field and the host passes
        // what remains as content margins. The text container's own 5pt default would land on top of
        // that, so the text read as inset 5pt more than asked on BOTH sides — which is exactly how it
        // was reported. The legacy input has no such padding either, so this is also parity.
        engine.lineFragmentPadding = 0.0
        // The HOST owns the insets exactly, through `update(size:insets:)`, and nothing may be added
        // to what it passes. Legacy pins the same value for the same reason: "the editor frame can
        // reach into the bottom safe area, so the default `.automatic` adjustment would ADD the
        // home-indicator inset on top of the parent's `contentInset.bottom` (double-counting it at
        // rest)". It also makes `adjustedContentInset == contentInset`, which is what lets the
        // content-height floor in `TGIDObservingBlockTextView` read the adjusted value without
        // feeding back through `.scrollableAxes`.
        engine.contentInsetAdjustmentBehavior = .never
        installEditMenuProvider()
        installTypedTextPolicy()
        installSpoilerDecorator()
        installEmptyLineProviders()
        installUndoStack()
        installTextInputGate()
        installAccessibilityReading()
        // The ORDER lives in `backspaceJoinRules`, which the GATE's door walks too. It used to be a
        // second hand-written list here, and the two drifted three times — see that array's doc
        // comment for what each drift cost.
        engine.tgid_compositionDidCommitHandler = { [weak self] in
            self?.removeEmptyCompositionMintedLine()
            self?.resolvePendingCompositionUndoStep()
            self?.settleAfterCompositionCommit()
        }
        engine.tgid_compositionDidEmptyHandler = { [weak self] in
            self?.removeEmptyCompositionMintedLine()
            self?.resolvePendingCompositionUndoStep()
        }
        engine.tgid_compositionCaretResolver = { [weak self] caret in
            self?.resolveAtomStopBeforeComposition(at: Int(caret))
        }
        engine.tgid_deleteBackwardHandler = { [weak self] in
            guard let self, self.consumeBackspaceAtACollapsedCaret() else { return false }
            // The keystroke was the host's: UIKit's own deletion never runs, so no
            // `textInputDidChange:` will end the edit.
            self.endHostDecidedKeystroke()
            return true
        }
        engine.tgid_shouldBeginTextInteractionHandler = { [weak self] point, isTap in
            self?.textInteractionMayBegin(at: point, isTap: isTap) ?? true
        }
        // The document's scroll declines a touch on a table's resize knob, or a vertical knob drag
        // is the scroll's and the knob's own pan is cancelled under it (K3, 2026-09-10). Knobs only:
        // `tableStructuralKnobContains` says why not the grips.
        engine.tgid_shouldBeginScrollPanHandler = { [weak self] point in
            !(self?.tableStructuralKnobContains(pointInEngine: point) ?? false)
        }
        // Read LAZILY: the composer installs its hooks after constructing the editor.
        engine.tgid_canPasteMediaHandler = { [weak self] in self?.deferredConfiguration.canPasteMedia?() ?? false }
        engine.tgid_pasteMediaHandler = { [weak self] in self?.deferredConfiguration.onPasteMedia?() ?? false }
        // The clipboard carries a `Document`, not a string (`+Clipboard.swift`). Both decline by
        // answering false, which leaves plain-text, RTF and media pasteboards to the engine exactly
        // as before.
        engine.tgid_copyHandler = { [weak self] in self?.writeSelectionToPasteboard() ?? false }
        engine.tgid_cutRangeHandler = { [weak self] selection in self?.cutDeletionRange(for: selection) ?? selection }
        // Markdown-on-paste sits behind the fragment and ahead of the engine's plain insert: it only
        // claims a pasteboard with a string, so the media hook between them in `paste:` never sees it.
        engine.tgid_richPasteHandler = { [weak self] in
            self?.handlePasteFromGeneralPasteboard() ?? false
        }
        engine.tgid_pasteWillLandHandler = { [weak self] in
            self?.enginePasteWillLand()
        }
        // A one-line field holds no line break, and that includes a composition's marked text: a candidate
        // holding "\n" split the field before settle's repair could see it (composer harness p24,
        // `HarnessCompositionNewlineInOneLineFieldTests`). The candidate is flattened as typing flattens it.
        engine.tgid_markedTextFilter = { [weak self] text in
            guard let self, self.selectionIsInOneLineField() else { return nil }
            return EngineDocumentBridge.oneLineText(text)
        }
        // Drag and drop (`+DragAndDrop.swift`): the engine installs neither interaction itself.
        installDragAndDrop()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not supported") }

    deinit {
        for observer in undoManagerObservers { NotificationCenter.default.removeObserver(observer) }
    }

    /// The document an undo or redo step restores: the model. A code block's language must come back with
    /// the whitespace its line holds — a snapshot one character short replayed the restored caret into the
    /// code BODY (composer harness p13, fuzz seed 43, `HarnessCodeLanguageRedoTests`) — and since p24 the
    /// model itself keeps it (`EngineBlockRole.merging`), so the snapshot no longer needs a read-back of its
    /// own.
    internal var replayDocument: Document { document }

    public var document: Document {
        get { bridge.document(for: currentRoles, from: engine.attributedBlocks) }
        set {
            // The bridge runs FIRST, before any state is touched. `attributedBlocks(for:)` TRAPS on a
            // non-`.paragraph` block (Global Constraint 6, R7); filling `currentBlocks` first —
            // via a `compactMap` that DROPS exactly the cases the bridge is about to trap on — meant
            // the view had already committed to a silently-truncated document by the time the trap
            // fired. Ordering it this way keeps the trap the first observable consequence.
            // The engine always holds one block, so an EMPTY document is one empty paragraph. Left as
            // zero roles, the engine's block had no role: every command looked for the block at the
            // caret and found none, so the expanded editor's "+" menu could not make a code block in a
            // fresh document until an edit had rebuilt the roles (measured on device, 2026-09-04).
            // A document set cannot go through the funnel above — `isApplyingHostDocument` makes it
            // return early — and the selection names a table that may not survive the set.
            tableStructuralSelection = nil
            let newValue = newValue.blocks.isEmpty
                ? Document(blocks: [.paragraph(ParagraphBlock(id: BlockID(UUID().uuidString)))]) : newValue
            let (attributedBlocks, roles) = bridge.engineRepresentation(for: newValue)
            let engineBlocks = engine.attributedBlocks
            let previousRoles = currentRoles
            // The differing span, by model identity and rendered text (spec §4). Everything outside
            // it stays: its engine identities, layout, run scroll views, adopted typing attributes.
            // Wholesale when the roles do not describe the engine — the first set, when the engine
            // holds its one initial empty block and the view no roles.
            var first = 0
            var newLast = roles.count - 1
            var oldLast = engineBlocks.count - 1
            if previousRoles.count == engineBlocks.count {
                while first < roles.count, first < previousRoles.count,
                      roles[first].blockID == previousRoles[first].blockID,
                      Self.renderedBlocksAgree(attributedBlocks[first], engineBlocks[first]) { first += 1 }
                while newLast >= first, oldLast >= first,
                      roles[newLast].blockID == previousRoles[oldLast].blockID,
                      Self.renderedBlocksAgree(attributedBlocks[newLast], engineBlocks[oldLast]) { newLast -= 1; oldLast -= 1 }
            }
            let unchanged = previousRoles.count == engineBlocks.count && first == roles.count && first == previousRoles.count
            // BEFORE the engine is touched: the empty-line providers answer positionally from these
            // while the replacement lands (`installEmptyLineProviders()`).
            currentRoles = roles
            isApplyingHostDocument = true
            // The TEXT is about to move, so the cursor has to be drawn with it — by the pass below,
            // not by UIKit's timer a run-loop iteration later. Never cleared here: a second set
            // before the first has been drawn is still a change awaiting one.
            if !unchanged { hostChangeAwaitingCaretDraw = true }
            if !unchanged {
                let selection = engineSelectedRange
                let oldLength = engineBlocks.reduce(0) { $0 + $1.length } + max(0, engineBlocks.count - 1)
                var spanStart = 0
                for index in 0..<min(first, engineBlocks.count) { spanStart += engineBlocks[index].length + 1 }
                spanStart = min(spanStart, oldLength)   // appending: the span starts at the document's end
                var spanEnd = spanStart
                if oldLast >= first {
                    for index in first...oldLast { spanEnd += engineBlocks[index].length + (index < oldLast ? 1 : 0) }
                }
                engine.tgid_replaceBlocks(in: NSRange(location: first, length: max(0, oldLast - first + 1)),
                                          withAttributedBlocks: newLast >= first ? Array(attributedBlocks[first...newLast]) : [])
                // The engine keeps the identities outside the span and the first one inside it;
                // every LATER refresh reads identity from the engine.
                recordBlockIdentitiesAfterReplacingSpan(first: first, newLast: newLast, rendered: attributedBlocks)
                // BEFORE anything measures. The rhythm is a function of the ROLES, not of whether a
                // layout has run; reserving it from `layoutSubviews` meant the host's first measure
                // omitted it and the field visibly grew on the next pass.
                syncTableFrames()
                syncContainerBlockInsets()
                // The selection survives a set outside the span; inside it, it clamps to the span's
                // new end (for a wholesale load: the end of the document, where typing continues).
                var newSpanEnd = spanStart
                if newLast >= first { newSpanEnd = flatOffset(ofRoleAt: newLast) + flatLength(ofRoleAt: newLast) }
                if selection.location >= spanStart && selection.location <= spanEnd {
                    reseatSelectionAfterHostSet(NSRange(location: newSpanEnd, length: 0))
                } else if selection.location > spanEnd {
                    reseatSelectionAfterHostSet(NSRange(location: selection.location + (newSpanEnd - spanEnd), length: 0))
                }
            } else {
                recordBlockIdentities(engine.tgid_blockIdentifiers)
                syncTableFrames()
                syncContainerBlockInsets()
            }
            // The caret may not have moved, but what its block IS may have (a container command on an
            // empty paragraph changes the role and not a character): the typing attributes an empty
            // block adopted for its previous role would otherwise survive the set. Measured on device:
            // a pull quote made where a code block had been typed in Menlo, left-aligned.
            engine.tgid_readoptEmptyBlockTypingAttributes()
            isApplyingHostDocument = false
            refreshBodyPlaceholder()
            // A set can put the caret in code, or make its block code, without a selection change.
            refreshCodeInputTraits()
            // Even when the text did not change: a set can change what a role DRAWS (a table's
            // borders, a quote's style) without changing a character, and the decorations and
            // chrome are placed from the roles in `layoutSubviews`.
            setNeedsLayout()
            // A host set is a new BASELINE, not an undoable step of its own — the command that
            // drove it registers the step, with the before-state it captured. Without this the
            // baseline stayed at whatever the editor held when it was constructed (an empty
            // document), so the first keystroke after a host set registered "restore empty" and one
            // undo wiped the document.
            if !isApplyingUndoSnapshot {
                endTypingRun()
                lastSettledUndoSnapshot = currentUndoSnapshot()
            }
        }
    }

    /// Whether a fresh rendering of a block draws what the engine block already holds — the document
    /// setter's test for "outside the differing span".
    ///
    /// `NSAttributedString` equality, except that an INLINE ATOM's attachment (custom emoji, formula,
    /// inline button) is compared by what it draws (`drawsTheSameAs`), not by object identity: every
    /// render mints new attachment objects, so a block holding one never equalled a fresh render of
    /// itself, and each undo / redo / host set replaced every block from the edit up to the last such
    /// paragraph — 61 of 62 blocks for a one-character undo at the top of a long document, and up to
    /// 0.8 s beside a 200-emoji paragraph (composer harness p15,
    /// `HarnessAtomParagraphReplayIdentityTests`). The attachment classes keep identity `isEqual`:
    /// equal adjacent attachments would coalesce into one attribute run.
    internal static func renderedBlocksAgree(_ fresh: NSAttributedString, _ held: NSAttributedString) -> Bool {
        if fresh.isEqual(to: held) { return true }
        guard fresh.length == held.length, fresh.string == held.string else { return false }
        var index = 0
        while index < fresh.length {
            var freshRun = NSRange(location: 0, length: 0)
            var heldRun = NSRange(location: 0, length: 0)
            let a = fresh.attributes(at: index, effectiveRange: &freshRun)
            let b = held.attributes(at: index, effectiveRange: &heldRun)
            guard a.count == b.count else { return false }
            for (key, value) in a {
                guard let other = b[key] else { return false }
                if let attachment = value as? NSTextAttachment, let heldAttachment = other as? NSTextAttachment {
                    let same: Bool
                    if let emoji = attachment as? EmojiTextAttachment {
                        same = emoji.drawsTheSameAs(heldAttachment)
                    } else if let formula = attachment as? FormulaTextAttachment {
                        same = formula.drawsTheSameAs(heldAttachment)
                    } else if let button = attachment as? ButtonTextAttachment {
                        same = button.drawsTheSameAs(heldAttachment)
                    } else {
                        same = attachment.isEqual(heldAttachment)
                    }
                    if !same { return false }
                } else if !(value as AnyObject).isEqual(other) {
                    return false
                }
            }
            index = min(NSMaxRange(freshRun), NSMaxRange(heldRun))
        }
        return true
    }

    /// Puts the caret at `range` after a host document set, making UIKit's input controller hold a
    /// range FOR THIS DOCUMENT even when the caret reads as already there.
    ///
    /// The controller keeps the range UIKit last gave it, and the ranges UIKit builds are SNAPSHOTS
    /// (anchors that do not track edits, whose offset is clamped to the document on every read). So
    /// after a paste left a range at 6, a content set to "abc" left that range in place reading 3 —
    /// and assigning 3 changed nothing, because the controller ignores a selection equal to the one it
    /// reads. The next paste measures its result FROM that range and resolved the stale 6 in the
    /// grown document: the caret landed where the previous paste had ended, mid-word (composer
    /// harness, 2026-09-23, `HarnessPasteCaretTests`). Stepping through a different position first
    /// makes the controller take a fresh range; the selection funnel ignores both moves while a host
    /// set is landing (`isApplyingHostDocument`).
    private func reseatSelectionAfterHostSet(_ range: NSRange) {
        let length = engine.attributedBlocks.reduce(0) { $0 + $1.length } + max(0, engine.attributedBlocks.count - 1)
        if length > 0, engineSelectedRange == range {
            engineSelectedRange = NSRange(location: range.location > 0 ? 0 : 1, length: 0)
        }
        engineSelectedRange = range
    }

    public func height(forWidth width: CGFloat) -> CGFloat {
        // A pure, side-effect-free measurement: probe at height 0 so the ported engine's own
        // `layoutSubviews` — which floors `contentSize.height` at the height of the VISIBLE area,
        // i.e. `MAX(bounds.height − contentInset.top − .bottom, documentContentSize.height + insets)`
        // (`TGIDObservingBlockTextView`'s `-setContentSize:`, over `IDBlockTextView.m`'s own
        // `MAX(bounds.height, …)`) — reports the document's real content height rather than clamping
        // it at whatever height the engine last had. At height 0 the visible term is 0 whatever the
        // content insets are, so the probe is exact for both hosts.
        // Without the probe, two `height(forWidth:)` calls at the SAME live frame height (as any
        // caller measuring before applying a new size does) can both clamp to that same height
        // regardless of how much content differs, which is indistinguishable from "content did not
        // grow".
        //
        // The engine's frame is captured HERE, before it is touched, and restored to that EXACT
        // captured value — not rebuilt from the `width` parameter. A caller may probe a width it
        // has not committed to (the composer-host protocol's whole point: ask "how tall at W"
        // before choosing W), so baking the queried `width` into the restored frame would leave
        // `engine.frame.width` at the last-probed value forever — an observable side effect on a
        // query that promises to have none. See
        // `EngineEditorDocumentTests.test_heightForWidthDoesNotDisturbTheEngineFrame`.
        let priorFrame = engine.frame
        isMeasuringHeight = true
        defer { isMeasuringHeight = false }
        engine.frame = CGRect(x: 0, y: 0, width: width, height: 0)
        engine.setNeedsLayout()
        engine.layoutIfNeeded()
        let measuredHeight = engine.contentSize.height
        engine.frame = priorFrame
        // Restoring the frame is NOT enough to undo the probe: it does not re-run the block layout,
        // so the document stayed laid out at the probed width and the text wrapped early on screen
        // until something else happened to trigger a pass. A query must leave no geometry behind.
        engine.setNeedsLayout()
        engine.layoutIfNeeded()
        // The probe's own side effect, undone. Laying the engine out at a width the caller has not
        // committed to re-ranges every table's run — probed WIDER than a table, the run has no
        // scrolling left and the engine clamps its offset to zero, which restoring the frame does
        // not undo. The host knows where each run belongs, so it says so again.
        pushRunScrollOffsets()
        // **A whole number of points, always.** Callers stack what they are given against a running
        // origin — the composer sizes its field from this, the article editor its scroll content —
        // so one fractional answer puts everything downstream on a fractional origin. The legacy
        // path states the same rule at `layoutTextItem` ("the `ceil` is load-bearing") and reaches
        // it by ceiling every BLOCK; the engine reaches it here instead, because since the baseline
        // lift its block canvases are deliberately fractional and must stay that way.
        //
        // `IDBlockTextView` already ceils its own `contentSize`, so this is a no-op today and was
        // measured to be one over paragraphs, every heading level, a quote, a code block, a details,
        // a table, a table in a quote and two aspect-ratio images. It is applied anyway because that
        // is VENDORED upstream code: a public contract of this package must not rest on an
        // incidental detail of a file we re-port. `EngineParagraphRhythmTests
        // .test_everyHeightThisViewHandsOutIsIntegral` pins both halves.
        return ceil(measuredHeight)
    }

    /// The BOX each block occupies — the frame of the thing the reader sees it as — accumulated
    /// during the layout pass by whichever sync owns it and pushed to the engine at the end of it.
    /// It decides both where that block's wash reaches across AND which part of the block's reserved
    /// space is the block's own padding rather than rhythm between blocks. A block that is absent
    /// has no box of its own: its column is the text column and all its reserved space is rhythm,
    /// which is the right answer for a plain paragraph.
    internal var pendingSelectionBoxes: [BlockID: CGRect] = [:]

    /// Hands the pass's columns to the engine, keyed by the engine's own block identity — like
    /// `blockInsets`, so an edit that moves a block takes its column with it.
    private func pushSelectionBoxes() {
        let identifiers = engine.tgid_blockIdentifiers
        var columns: [UUID: NSValue] = [:]
        for (index, role) in currentRoles.enumerated() where index < identifiers.count {
            guard let box = pendingSelectionBoxes[role.blockID] else { continue }
            columns[identifiers[index]] = NSValue(cgRect: box)
        }
        engine.selectionBoxes = columns
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        isPlacingDerivedViews = true
        defer { isPlacingDerivedViews = false }
        // Plain `bounds` is correct again: the host's content margins live in the engine's own
        // `textContainerInset`, which this assignment cannot disturb. While they lived in the FRAME,
        // this line silently threw them away on every UIKit-scheduled layout pass.
        engine.frame = bounds
        // Before anything reads an indent: the levels that indent follow the text column's width.
        syncIndentedQuoteLevelLimit()
        // Tables: the engine has laid each cell out at its column width; read the used heights,
        // solve the rows, and push final frames — which re-runs the engine pass in place before
        // the decorations below read it. Converges: an unchanged push is a no-op.
        syncTableFrames()
        syncContainerBlockInsets()
        // After the engine has laid out, so the geometry both are placed from is current.
        // Decoration FIRST: it sits behind the text, and sizing it before the overlays keeps the
        // whole placement pass reading in back-to-front order.
        // Rebuilt from scratch each pass: a stale entry would pin a wash to a band that has moved.
        pendingSelectionBoxes = [:]
        syncContainerDecorations()
        syncTableChrome()
        syncSecondaryPlaceholders()
        syncListMarkers()
        syncDetailsChrome()
        syncCustomEmojiViews()
        syncInlineButtonPills()
        syncFormulaTapTargets()
        syncMediaViews()
        syncButtonRowViews()
        syncCollapsedQuoteViews()
        // After every contributor above and before anything can ask for a selection rect.
        pushSelectionBoxes()
        syncSpoilerDust()
        // Here as well as in `engineDidLayout`, and for the opposite reason: that one catches the
        // engine's OWN passes (a run's scroll dirties nothing else), this one catches the pass that
        // places the cells after a table edit. Waiting for the engine to dirty itself again left a
        // parked offset standing until something unrelated happened to lay the engine out — and
        // `syncTableFrames` above has just given the run its real width, so this is the first moment
        // the offset can be clamped against the right maximum. Before the chrome, which reads it.
        syncRunScrollOffsets()
        // After the run offsets are reconciled and before the chrome reads them: a table's run
        // scrolls to the caret here, against the table widths this pass has just placed. See
        // `revealSelectionEndInPlacedRun`.
        if placedRunCaretRevealOwed {
            placedRunCaretRevealOwed = false
            if engine.isFirstResponder {
                revealSelectionEndInPlacedRun()
            }
        }
        // After the cells' own chrome and the overlays: the outline draws OVER the text.
        syncTableStructuralChrome()
        drawTheCaretWithAHostChange()
        // LAST: every sync above has run and the frame is complete. Per-layout rather than
        // per-settle — see its doc comment for why that is the whole point.
        verifyDerivedViewsAreComplete()
    }

    /// **The hint (and label) belong to the TEXT AREA, not to this container.** The element VoiceOver
    /// focuses — the one the AX runtime exposes as a text area — is the engine view inside, not this
    /// wrapper, so a hint stored here was never spoken: K1's AX tree read `Group … help "Message"` over
    /// `TextArea … help None`. The legacy composer puts the chat's "Message" placeholder on its
    /// `UITextView`, which is the text area; this is the same placement. Forwarded rather than copied,
    /// so there is one value and a host reading it back sees what the text area carries
    /// (`HarnessAccessibilityTests.testTheEngineTextAreaCarriesTheMessageHint`).
    public override var accessibilityHint: String? {
        get { engine.accessibilityHint }
        set { engine.accessibilityHint = newValue }
    }

    public override var accessibilityLabel: String? {
        get { engine.accessibilityLabel }
        set { engine.accessibilityLabel = newValue }
    }

    /// The host's localized name for a medium of each kind, which is what VoiceOver reads for a
    /// media atom (`RichTextEngineEditorView+Accessibility.swift`). nil — the package has no strings —
    /// reads a medium as nothing rather than as an attachment character.
    public var accessibilityMediaName: ((MediaKind) -> String?)?

    /// A host pass asked for the caret to be revealed inside a table's run; spent by the next
    /// `layoutSubviews`, after the tables are placed (`revealSelectionEndInPlacedRun`).
    internal var placedRunCaretRevealOwed = false

    /// The caret a host command places belongs to the change this pass is drawing, so it is drawn
    /// in this pass.
    ///
    /// The engine flushes its own selection display for an edit IT drove, once per document change,
    /// and a host `document` set spends that flush on its own bookkeeping: the setter clamps the
    /// caret to the replaced span's end and measures — which lays the engine out — before the
    /// command that called it puts the caret where it belongs. What the command wanted is then
    /// drawn by UIKit's zero-delay timer, a run-loop iteration later, which is a painted frame with
    /// the cursor in the wrong block (K3, 2026-09-15: a fresh detail block blinked its caret in the
    /// body before jumping into the title — the clamp's landing, then the command's).
    ///
    /// **Only for a pass that draws a document change.** `-layoutManagedSubviews` is the resetting
    /// entry and must not run on a pass a bare selection move triggered — `tgid_flushSelectionDisplayUpdate`
    /// and its upstream twin carry the Shift+Right trace that rule came from.
    /// The engine's text geometry as the host last applied it — the two things a host assignment can
    /// change that re-lay the text out, and so move the caret.
    internal struct EngineTextGeometry: Equatable {
        let frame: CGRect
        let inset: UIEdgeInsets
    }

    /// **A host layout pass that moves the TEXT moves the caret, and owes it a draw.**
    ///
    /// The sibling of the document-change case below, with a different trigger and the same
    /// consequence. `update(size:insets:contentMargins:scrollIndicatorInsets:)` assigns the engine's
    /// frame and `textContainerInset`; either re-lays the text out at a new origin. No document
    /// changed, so the engine has no flush pending of its own, and the cursor keeps whatever
    /// position the last flush gave it until UIKit's zero-delay timer fires an iteration later.
    /// Both hosts run that pass on every `onChange` — which is every keystroke — so the shape a user
    /// sees is "typing does not move the caret" over a model that is perfectly correct.
    ///
    /// **Only when the geometry actually MOVED.** A host re-running `update` with the same numbers
    /// changes nothing and must not flush: `-layoutManagedSubviews` is the resetting entry, and the
    /// Shift+Right trace in `tgid_flushSelectionDisplayUpdate` is what happens when it runs on a
    /// pass that had no business drawing.
    ///
    /// Reported as a regression from the typing-coalescing fix, and it half was: the per-keystroke
    /// presentation restyle that fix removed left the engine's flush flag armed, so the host's next
    /// pass happened to spend it. That was an accident of a restyle nobody wanted — the FIRST
    /// keystroke was stale before that fix too, measured — so this states the rule rather than
    /// restoring the accident.
    internal func markCaretForRedrawIfHostGeometryMoved(from previous: EngineTextGeometry) {
        let now = EngineTextGeometry(frame: engine.frame, inset: engine.textContainerInset)
        guard now != previous else { return }
        hostChangeAwaitingCaretDraw = true
    }

    /// Test seam: how many times this pass has actually flushed. The guard above is the half that
    /// cannot be observed from the outside — a flush that should NOT have happened leaves the caret
    /// in the right place anyway, and only shows up later as the Shift+Right anchor defect. Counting
    /// is what lets a test assert the negative (`EngineCaretFollowsTypingTests`).
    internal private(set) var caretRedrawCount = 0

    private func drawTheCaretWithAHostChange() {
        guard hostChangeAwaitingCaretDraw else { return }
        hostChangeAwaitingCaretDraw = false
        caretRedrawCount += 1
        // The syncs above lay the engine out by reading its frames, but none of that is a promise:
        // a document whose set changed no geometry can reach here with the engine still dirty, and
        // flushing against stale geometry would draw the caret in the place this exists to avoid.
        // A no-op when the engine is clean.
        engine.layoutIfNeeded()
        engine.tgid_flushSelectionDisplayUpdate()
    }

    /// R1's own funnel: fired for every engine mutation, host-driven sets included (Task 1's
    /// `EngineObservationCompletenessTests.test_hostContentReplacementIsObserved` pins that
    /// `tgid_setAttributedBlocks` reaches this synchronously). The single guard below is what tells
    /// a real user edit apart from the echo of a host-driven `document` set.
    ///
    /// R6/Task 8 fix round 1: when this edit created a block that needs list-continuation
    /// reconciliation (`+Paragraph.swift`'s `blockIDsNeedingListContinuation(from:in:)`), the
    /// correction is SCHEDULED rather than applied here — applying it here would re-enter
    /// `tgid_setAttributedBlocks` from inside the engine's own `processEditing`, which is the
    /// re-entrancy hazard `pendingListContinuationBlockIDs`'s doc comment describes. `onChange` is
    /// suppressed for this edit in that case (and for any edit while a reconciliation is still
    /// pending — e.g. typing into the just-split block before the deferred turn lands), so no
    /// consumer ever observes the intermediate, list-less document; the deferred reconciliation
    /// fires exactly one `onChange` once it has applied (or found nothing left to apply).
    /// Fires `onChange` for a SELECTION-only change, coalesced to one trailing call.
    ///
    /// THE LEGACY BACKEND DOES THIS, and the whole composer is written against it: its facade turns a
    /// canvas selection change into `onChange` (`scheduleSelectionDrivenOnChange`), which is why
    /// `RichTextEditorChatInputNode.onChange` documents itself as also firing "on a caret/selection
    /// move". This editor split the two — content to `onChange`, selection to `onSelectionChange` —
    /// and nothing wired the second, so the panel never learned the caret had moved.
    ///
    /// The consequence was data loss, not cosmetics: select all, apply a spoiler, insert a custom
    /// emoji, and it REPLACED THE WHOLE TEXT, because the panel still held the select-all range and
    /// inserted over it. Moving the caret did not help — the selection only looked gone.
    ///
    /// Coalesced for the reason the legacy one is: a gesture drag reports many transient ranges, and a
    /// host reading `hasSelection` on each would flicker a selection-gated toolbar.
    private func scheduleSelectionDrivenOnChange() {
        // SELECTION-ONLY. An edit moves the caret too, and its own notification is already owed — firing
        // here as well would deliver `onChange` twice for one edit, which
        // `EngineEditorDocumentTests.test_aStructuralMutatorDuringAPendingCoalescedFlushFiresOnChangeExactlyOnce`
        // pins against. Checked again at fire time, because an edit can begin between the two.
        //
        // A pending list-continuation reconciliation counts as an owed notification too, and that is
        // NOT covered by `isChangeNotificationPending`: while one is in flight the funnel suppresses
        // each edit's notification by returning BEFORE it marks the flag (`engineDidChangeDocument`),
        // so an edit that moves the caret — which every edit does — leaves this guard reading `false`
        // and schedules a delivery of its own. The reconciliation's release then fires, and this one
        // fires a turn behind it, for the same edit. That release owns the consumer's next
        // `onChange` (`+Paragraph.swift`'s list-continuation section), so this defers to it.
        //
        // Measured (2026-09-04): a multi-line insert or paste into a list item delivered `onChange`
        // twice. It crashed `EngineListContinuationTests`' two multi-block cases on a repeat
        // `XCTestExpectation.fulfill` — both were skipped from every run rather than read — and
        // failed `ComposerStandInReconciliationCoincidenceTests
        // .test_aStructuralMutationDuringAPendingReconciliationFiresOnChangeExactlyOnce` with 2
        // against 1. The composer runs a full layout pass from `onChange`.
        if isChangeNotificationPending || isSelectionOnChangeScheduled
            || isListContinuationReconciliationScheduled { return }
        isSelectionOnChangeScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // Already reported: a command that ran later in this same turn delivered
            // synchronously and, in doing so, absorbed this selection change as part of its own
            // notification (`flushPendingChangeNotification` clears this flag on every delivery).
            // Standing down here — rather than unconditionally proceeding — is what stops a
            // selection change immediately followed by a command in the same run-loop turn (a
            // drag-select then a Format-menu tap; `RichTextAttachmentScreen`'s
            // `focusEditorAtDocumentEndIfNeeded` then a Quote action) from delivering `onChange`
            // twice for the one edit.
            guard self.isSelectionOnChangeScheduled else { return }
            self.isSelectionOnChangeScheduled = false
            guard !self.isChangeNotificationPending, !self.isListContinuationReconciliationScheduled else { return }
            self.onChange?()
        }
    }

    /// A container whose text the user has just deleted becomes a plain paragraph again.
    ///
    /// Without this a container is UNDELETABLE, which is what device testing found. The engine keeps a
    /// block's identity when its text is emptied — that is the whole point of the identity table — so
    /// an emptied code block is faithfully rebuilt as `.code` with no runs: an empty band that
    /// Backspace cannot remove, because there is no text left to delete and the engine reports no
    /// further change. Select-All + Backspace hit the same wall.
    ///
    /// Note it only bit a container with nothing before it. With a preceding paragraph the engine
    /// MERGES the emptied block away and the problem never appears — which is why this needs the
    /// lone-container case tested explicitly, and why it survived the earlier round of tests.
    ///
    /// **Reached only for engine-driven edits**, because `engineDidChangeDocument` returns early
    /// while `isApplyingHostDocument` is set. That is what lets `makeCodeBlock` still create an EMPTY
    /// code block to type into: the command sets `document` itself, so this never sees it. Only a
    /// user's own delete dissolves a container.
    ///
    /// The `BlockID` is deliberately carried over rather than freshly minted — the block is the same

    /// Applies an ENGINE-PARALLEL array of blocks, preserving each position's quote membership.
    ///
    /// Mutators work on `currentBlocks`, which is one entry per engine block, so writing
    /// `Document(blocks:)` straight back would dissolve every quote into loose paragraphs. Mapping
    /// through the roles keeps membership attached to the position it belongs to.
    internal func applyEngineParallelBlocks(_ blocks: [Block]) {
        guard blocks.count == currentRoles.count else {
            // A different length means the caller changed the block COUNT, which cannot be mapped
            // onto existing roles positionally. Those callers (the container commands) build their
            // own roles instead.
            document = Document(blocks: blocks)
            return
        }
        let roles = zip(currentRoles, blocks).map { role, block in
            EngineBlockShape(of: block).map { role.replacingShape($0) } ?? role
        }
        document = EngineBlockRole.document(roles: roles, blocks: blocks)
    }

    /// Rebuilds the render pipeline around new metrics and re-renders the document.
    ///
    /// `renderMetrics` was stored and never read, so the composer's `edgeSpacingReduction` — 6pt at
    /// each sequence edge, which the input panel already provides — never reached the layout and
    /// reappeared as 12pt of height nothing accounted for. The metrics feed BOTH the text (through
    /// the mapper's stylesheet) and the block rhythm (through `EngineBlockSpacing`), so both are
    /// rebuilt from the same value.
    internal func applyRenderMetrics(_ metrics: RichTextRenderMetrics) {
        // Re-resolve the code geometry against the NEW metrics: `CodeStyle`'s fields are optional and
        // fall back to `metrics.code`, so a host that sets `codeStyle` before `renderMetrics` would
        // otherwise keep the geometry of the metrics it no longer uses. The legacy canvas carries the
        // same requirement for the same reason.
        // Read BEFORE the bridge is swapped: the document is materialised from the engine through
        // the bridge that rendered it, and the new one would read the old rendering's colours and
        // sizes as explicit overrides (a theme push re-rendered black text black).
        let restored = document
        // The quote style is re-resolved alongside the code style for the same reason: a metrics
        // rebuild returns a sheet built from the metrics, which carries neither.
        // …and the width-derived quote level limit, which a metrics rebuild's fresh sheet drops too.
        let quoteLevelLimit = mapper.styleSheet.indentedQuoteLevelLimit
        mapper = resolvingCodeStyle(deferredConfiguration.codeStyle,
                                    into: Self.resolvingQuoteStyle(deferredConfiguration.quoteStyle,
                                                                   into: mapper.withRenderMetrics(metrics)))
        var sheet = mapper.styleSheet
        sheet.indentedQuoteLevelLimit = quoteLevelLimit
        mapper = mapper.withStyleSheet(sheet)
        remakeBridge()
        rerenderPresentation(of: restored)
    }

    /// Re-renders `restored` — the document read through the bridge that rendered it — through the
    /// CURRENT bridge, after an applier above swapped it.
    ///
    /// **In place when only presentation changed.** A theme, Text Size or geometry change re-renders
    /// every block, so the `document` setter found every block different and replaced the whole text:
    /// the caret went to the end of the document, a selection was dropped, and an open IME composition
    /// ended, its next candidate landing at the end (composer harness, 2026-09-24,
    /// `HarnessThemeChangeSelectionTests` — auto-night turning on mid-sentence was enough). A stock
    /// text view re-colours in place. So when the new rendering has the same blocks with the same
    /// characters, only the attributes are rewritten, through the adapter: no character changes, no
    /// input-delegate bracket, the selection and the marked range stay where they are. The typing
    /// attributes (and an open composition's) follow the text's old → new values, or the next typed
    /// character would carry the old palette — which the read-back takes for an explicit colour.
    ///
    /// Anything else — a formula renderer turning LaTeX into one attachment character, a changed
    /// block structure — falls back to the document set, which is the only thing that can express it.
    internal func rerenderPresentation(of restored: Document) {
        if !rerenderPresentationInPlace(restored) {
            document = restored
        }
    }

    private func rerenderPresentationInPlace(_ restored: Document) -> Bool {
        guard !restored.blocks.isEmpty else { return false }
        let (attributedBlocks, roles) = bridge.engineRepresentation(for: restored)
        let engineBlocks = engine.attributedBlocks
        guard roles.count == engineBlocks.count, currentRoles.count == engineBlocks.count,
              attributedBlocks.count == engineBlocks.count else { return false }
        for index in 0..<roles.count {
            guard roles[index].blockID == currentRoles[index].blockID,
                  attributedBlocks[index].string == engineBlocks[index].string else { return false }
        }
        var edits: [PresentationEdit] = []
        // Old value → new value per key, as the text itself moved, for the typing attributes.
        var translations: [(key: NSAttributedString.Key, old: AnyObject, new: AnyObject)] = []
        func diff(wanted: [NSAttributedString.Key: Any], existing: [NSAttributedString.Key: Any], at range: NSRange) {
            var apply: [NSAttributedString.Key: Any] = [:]
            var remove: [NSAttributedString.Key] = []
            for (key, value) in wanted {
                let want = value as AnyObject
                let have = existing[key] as AnyObject?
                guard have == nil || !want.isEqual(have) else { continue }
                apply[key] = value
                if let have, !translations.contains(where: { $0.key == key && $0.old.isEqual(have) }) {
                    translations.append((key, have, want))
                }
            }
            for key in Self.presentationKeys where wanted[key] == nil && existing[key] != nil {
                remove.append(key)
            }
            if !apply.isEmpty || !remove.isEmpty { edits.append((range, apply, remove)) }
        }
        var offset = 0
        for index in 0..<engineBlocks.count {
            let rendered = attributedBlocks[index]
            let current = engineBlocks[index]
            rendered.enumerateAttributes(in: NSRange(location: 0, length: rendered.length)) { wanted, run, _ in
                current.enumerateAttributes(in: run) { existing, sub, _ in
                    diff(wanted: wanted, existing: existing,
                         at: NSRange(location: offset + sub.location, length: sub.length))
                }
            }
            offset += current.length
            // The separator carries the attributes of the block it ends, as a set joins them.
            if index + 1 < engineBlocks.count, rendered.length > 0, current.length > 0 {
                diff(wanted: rendered.attributes(at: rendered.length - 1, effectiveRange: nil),
                     existing: current.attributes(at: current.length - 1, effectiveRange: nil),
                     at: NSRange(location: offset, length: 1))
            }
            offset += 1
        }
        currentRoles = roles
        isApplyingHostDocument = true
        // ONE attribute edit for every run of every block: one merge per run made a theme change over
        // 240 paragraphs cost 8.4 s (`HarnessPresentationPassScalingTests`).
        applyPresentationEdits(edits)
        if !translations.isEmpty {
            engine.tgid_translateTypingAttributes { key, value in
                let value = value as AnyObject
                return translations.first(where: { $0.key == key && $0.old.isEqual(value) })?.new
            }
        }
        // Geometry can change with the presentation (Text Size), so the caret is drawn with it.
        if !edits.isEmpty { hostChangeAwaitingCaretDraw = true }
        recordBlockIdentities(engine.tgid_blockIdentifiers)
        syncTableFrames()
        syncContainerBlockInsets()
        engine.tgid_readoptEmptyBlockTypingAttributes()
        isApplyingHostDocument = false
        refreshBodyPlaceholder()
        refreshCodeInputTraits()
        setNeedsLayout()
        return true
    }

    /// Applies the host's pull-quote geometry. The pill's numbers are not in the stylesheet — that
    /// carries only `.pullQuote`'s italic + centred TEXT attributes — so they travel with the bridge
    /// (which measures the text inside the horizontal padding) and are read directly by the decoration
    /// and spacing passes.
    internal func applyPullQuoteStyle(_ style: PullQuoteStyle) {
        let restored = document
        remakeBridge(pullQuoteStyle: style)
        rerenderPresentation(of: restored)
    }

    /// Applies the host's code-block geometry, resolving its optional fields against the shared
    /// render metrics exactly as `DocumentCanvasView.applyCodeStyle` does.
    internal func applyCodeStyle(_ style: CodeStyle) {
        let restored = document
        mapper = resolvingCodeStyle(style, into: mapper)
        remakeBridge()
        rerenderPresentation(of: restored)
    }

    /// Applies the host's quote geometry that the STYLE SHEET owns — today its trailing inset, the
    /// one quote measurement the engine takes from the host rather than from its own default.
    ///
    /// Legacy narrows a quote's content by `QuoteStyle.trailingInset` and leaves the fill full width
    /// (`BlockQuoteBox`: `inner = width - leadingInset - trailingInset`, and the underlay is drawn
    /// over the whole frame). The engine drew its quoted text out to the column edge, because
    /// `StyleSheet.quoteTrailingInset` existed, was assigned by the legacy canvas alone, and was read
    /// by nothing at all.
    ///
    /// The LEADING inset is deliberately not synced here: the engine indents by the style sheet's own
    /// `quoteIndent` (16) where the article host asks legacy for 9, and changing that is a visible
    /// move nobody asked for. Recorded rather than quietly fixed.
    internal static func resolvingQuoteStyle(_ style: QuoteStyle,
                                             into mapper: AttributedStringMapper) -> AttributedStringMapper {
        var sheet = mapper.styleSheet
        sheet.quoteTrailingInset = style.trailingInset
        return mapper.withStyleSheet(sheet)
    }

    /// Sets how many quote levels indent (`StyleSheet.indentedQuoteLevelLimit`) from the engine's
    /// current text column, and re-renders when that changes. The levels past it add no indent, so a
    /// deep quote's column stays at least `EngineAncestor.minimumQuotedColumnWidth` wide and never widens
    /// with depth (composer harness p21, `HarnessDeepQuoteNarrowColumnTests`). A width-dependent number,
    /// so a width change can re-render — but only when it moves a whole level, and the re-render is an
    /// attribute pass over the blocks whose indent changed (`rerenderPresentation`).
    internal func syncIndentedQuoteLevelLimit() {
        let inset = engine.textContainerInset
        let column = engine.bounds.width - inset.left - inset.right - 2.0 * engine.lineFragmentPadding
        guard column > 0.0, engine.markedTextRange == nil, !isApplyingHostDocument, !isSettling,
              !isDecidingAtGate, !isIssuingHostEdit, !isApplyingUndoSnapshot else { return }
        let sheet = mapper.styleSheet
        let limit = EngineAncestor.indentedQuoteLevelLimit(column: column,
                                                           perLevel: sheet.quoteIndent + sheet.quoteTrailingInset)
        guard limit != sheet.indentedQuoteLevelLimit else { return }
        let effectiveBefore = min(EngineAncestor.maxIndentedQuoteLevels, sheet.indentedQuoteLevelLimit)
        // Read BEFORE the bridge is swapped, as every rebuild does.
        let restored = currentRoles.isEmpty ? nil : document
        var updated = sheet
        updated.indentedQuoteLevelLimit = limit
        mapper = mapper.withStyleSheet(updated)
        remakeBridge()
        // Only a quote nested deeper than the smaller of the two limits draws differently.
        let deepest = currentRoles.reduce(0) { max($0, $1.enclosingQuoteCount) }
        if let restored, deepest > min(limit, effectiveBefore) {
            rerenderPresentation(of: restored)
        }
    }

    internal func applyQuoteStyle(_ style: QuoteStyle) {
        let restored = document
        mapper = Self.resolvingQuoteStyle(style, into: mapper)
        remakeBridge()
        rerenderPresentation(of: restored)
    }

    /// Applies the host's media geometry — the bleed the atom's height is computed at. The bridge
    /// carries it, so the bridge is rebuilt; `document` is read BEFORE the swap, as every rebuild does.
    internal func applyMediaBlockStyle(_ style: MediaBlockStyle) {
        let restored = document
        remakeBridge(mediaBlockStyle: style)
        rerenderPresentation(of: restored)
    }

    /// Installs the host's formula renderer and RE-DERIVES the document.
    ///
    /// The rebuild is required, not defensive. Registration changes a formula run from N characters
    /// of LaTeX to ONE attachment character — a text LENGTH change, which no attribute merge can
    /// express — and `RichTextAttachmentScreen` always sets its document BEFORE registering. Legacy
    /// answers this the same way, reloading its canvas from `currentBlocks()`.
    ///
    /// `document` is read BEFORE the swap, as every rebuild here does.
    internal func applyFormulaRenderer(
        _ provider: @escaping (RichTextFormulaRenderContext) -> RichTextFormulaRenderResult?
    ) {
        let restored = document
        mapper.formulaRenderer = provider
        remakeBridge()
        rerenderPresentation(of: restored)
    }

    /// Rebuilds the bridge around the CURRENT mapper and configuration, carrying over the state the
    /// bridge itself owns rather than takes from either.
    ///
    /// Every applier above swaps the bridge to change one thing, and each one used to construct it
    /// inline — so each also silently reset `showsButtonRowMenuAffordance`, which is not derived
    /// from the mapper or the deferred configuration: it is stamped from whether the host is
    /// listening (`onRequestButtonRowMenu`), and it is part of the MEASUREMENT, so losing it
    /// re-packs every row in the document to a width the sent message will not have. Both hosts
    /// happen to register that hook LAST today, which is the only reason this never showed; a
    /// seventh rebuild (the quote style's) is what made the ordering luck worth removing.
    private func remakeBridge(pullQuoteStyle: PullQuoteStyle? = nil,
                              mediaBlockStyle: MediaBlockStyle? = nil) {
        let showsMenuAffordance = bridge.showsButtonRowMenuAffordance
        bridge = EngineDocumentBridge(mapper: mapper,
                                      pullQuoteStyle: pullQuoteStyle ?? deferredConfiguration.pullQuoteStyle,
                                      mediaBlockStyle: mediaBlockStyle ?? deferredConfiguration.mediaBlockStyle)
        bridge.showsButtonRowMenuAffordance = showsMenuAffordance
    }

    private func resolvingCodeStyle(_ style: CodeStyle,
                                    into mapper: AttributedStringMapper) -> AttributedStringMapper {
        var sheet = mapper.styleSheet
        sheet.codeVerticalInset = style.verticalInset ?? sheet.metrics.code.verticalInset
        sheet.codeLanguageSpacing = style.languageSpacing ?? sheet.metrics.code.languageSpacing
        sheet.codeHorizontalInset = style.horizontalInset
        sheet.codeCornerRadius = style.cornerRadius
        return mapper.withStyleSheet(sheet)
    }

    fileprivate func engineDidChangeDocument(replacedRange: NSRange, replacementLength: Int,
                                             charactersChanged: Bool) {
        // Hosted views — custom emoji, spoiler dust — are reconciled in `layoutSubviews`, and a
        // content change does not otherwise mark this view dirty. Without this an emoji outlives the
        // text it belonged to, and dust lingers over deleted runs.
        setNeedsLayout()
        // The other half of what a structural selection's trait states depend on.
        cachedStructuralTraits = nil
        guard !isApplyingHostDocument else { return }
        // An edit is in flight until `textInputDidChange:` ends it, and a selection change arriving
        // in between belongs to the keystroke rather than being a caret move of its own — see
        // `reportCaretRevealIfOwed`. Marked AFTER the host-document guard: a `document` set gets no
        // `textInputDidChange:`, so marking it there would leave the flag stuck and suppress every
        // later caret move. Measured as exactly that: a caret move after a document set reported
        // nothing.
        //
        // A RE-ATTRIBUTION arriving with no edit in flight belongs to the edit that just finished:
        // the typed-text policy (`+TypedText.swift`) re-attributes the typed run AFTER the
        // controller's `insertText:` has returned through `textInputDidChange:`, so after settle has
        // committed the undo baseline. It gets no `textInputDidChange:` of its own, so it must not
        // leave the flag set (every later caret move read as mid-edit), and the baseline must take
        // it in. Measured (composer harness, 2026-09-23): "Z" typed inside a spoiler was committed
        // plain, the spoiler landed a moment later, and undoing a LATER edit restored "Z" plain —
        // splitting the spoiler and revealing the character.
        let isTrailingReattribution = !charactersChanged && !isEngineEditInFlight && !isSettling
            && !isDecidingAtGate && !isIssuingHostEdit && !isApplyingUndoSnapshot
        defer {
            if isTrailingReattribution {
                isEngineEditInFlight = false
                commitUndoSnapshotAfterSettle()
            }
        }
        isEngineEditInFlight = true
        // BEFORE any structure is rebuilt: the decision needs the edit's shape, and
        // `lastSettledUndoSnapshot` is still the pre-edit state at this point.
        recordUndoForEngineEdit(replacedRange: replacedRange, replacementLength: replacementLength,
                                charactersChanged: charactersChanged)
        let blockIDsBeforeThisEdit = Set(currentRoles.map(\.blockID))
        let rolesBeforeThisEdit = currentRoles
        // ONE read of the engine's identifiers, used both to resolve structure and to refresh the
        // table, so the two can never describe different moments of the same edit.
        let identifiers = engine.tgid_blockIdentifiers
        let priorIdentifiers = Set(structureByEngineIdentity.keys)
        let rebuilt = bridge.roles(for: identifiers, reusingStructureOf: structureByEngineIdentity)
        // A block the engine minted inside this edit has no table entry, so it arrives standalone.
        // Between two children of one quote that would split the quote in three; adopting it is the
        // same host policy as list continuation.
        let freshIndices = Set(identifiers.indices.filter { !priorIdentifiers.contains(identifiers[$0]) })
        if rolesBeforeEdit == nil { rolesBeforeEdit = rolesBeforeThisEdit }
        for index in freshIndices { freshSinceSettle.insert(identifiers[index]) }
        // The blocks the edit's span lies in, after the edit: their presentation is re-derived at
        // settle, since text that arrived from another block carries that block's face.
        let editedSpan = NSRange(location: replacedRange.location, length: replacementLength)
        var offset = 0
        for (index, block) in engine.attributedBlocks.enumerated() where index < identifiers.count {
            let end = offset + block.length
            if NSMaxRange(editedSpan) >= offset && editedSpan.location <= end { touchedSinceSettle.insert(identifiers[index]) }
            offset = end + 1
        }
        // A container is NOT reverted when it runs out of text.
        //
        // It used to be, on the reasoning that a quote outliving its own text was undeletable. It is
        // not: backspace in an empty container un-quotes or un-codes it (see
        // `backspaceJoinRules`' dissolve rule), which is the legacy editor's rule too. Reverting on
        // emptiness instead meant one backspace too many silently changed what you were editing —
        // deleting a quote's last character deleted the quote — with no way to get it back but to
        // make it again.
        //
        // No structural decision is made here (surface-gate spec §3.3): the gate decided before the
        // edit and settle follows it. This funnel adopts the plan a structural edit carries, else
        // the roles by identity. No text is read: a role is structure only, and the engine holds
        // the text.
        //
        // There was a third arm — a REPLAY snapshot, for an undo that put UIKit's characters back
        // and left the roles to be reinstated positionally around them. The editor's own stack
        // restores a `Document` and the setter derives the roles from it, so no such window exists
        // and the arm is gone rather than left unreachable (`+UndoStack.swift`).
        if let plan = pendingRolePlan {
            pendingRolePlan = nil
            if plan.count == identifiers.count {
                currentRoles = plan
            } else {
                // A programming error in a rule, never data: the plan describes a block count the
                // edit did not produce.
                assertionFailure("RichTextEngineEditor: role plan expected \(plan.count) blocks, the edit produced \(identifiers.count)")
                NSLog("RichTextEngineEditor: role plan expected %ld blocks, the edit produced %ld — rebuilt by identity", plan.count, identifiers.count)
                currentRoles = rebuilt
            }
            // The plan declared every block the edit minted.
            for identifier in identifiers { freshSinceSettle.remove(identifier) }
            structureTouchedThisEdit = true
        } else {
            currentRoles = rebuilt
        }
        markRoleChanges(identifiers)
        recordBlockIdentities(identifiers)
        syncTableFrames()
        syncContainerBlockInsets()
        // Here rather than beside `onChange?()`: that delivery is deliberately suppressed while a
        // list-continuation reconciliation is pending, and a placeholder that lingered over typed
        // text for a runloop turn would be a visible artefact of a notification-policy decision.
        refreshBodyPlaceholder()
        let idsNeedingListContinuation = blockIDsNeedingListContinuation(previousIDs: blockIDsBeforeThisEdit,
                                                                         in: currentRoles)
        if !idsNeedingListContinuation.isEmpty {
            scheduleListContinuationReconciliation(for: idsNeedingListContinuation)
        }
        guard !isListContinuationReconciliationScheduled else {
            // A correction is in flight (from this edit, or one still pending from an earlier
            // edit) — suppress this edit's own notification too, so a consumer can never read
            // `document` via `onChange` and see the intermediate, list-less structure.
            return
        }
        scheduleChangeNotification()
    }

    /// Joins the engine's block identifiers to the paragraphs they just resolved to. Both arrays
    /// come from the same refresh, in the same order; `zip` drops any tail a length mismatch would
    /// leave, which is the conservative direction (an unrecorded identifier reads as "new" next
    /// time, which mints a fresh `BlockID` rather than reusing an unrelated paragraph's structure).
    /// A block whose role differs from the one recorded for its identity is presented as its old
    /// role until settle re-derives it.
    private func markRoleChanges(_ identifiers: [UUID]) {
        for (index, identifier) in identifiers.enumerated() where index < currentRoles.count {
            if let before = structureByEngineIdentity[identifier], before != currentRoles[index] {
                touchedSinceSettle.insert(identifier)
            }
        }
    }

    private func recordBlockIdentities(_ identifiers: [UUID]) {
        structureByEngineIdentity = Dictionary(zip(identifiers, currentRoles),
                                               uniquingKeysWith: { _, latest in latest })
    }

    /// `recordBlockIdentities` after a set replaced the roles `first...newLast` with `rendered`, when the engine
    /// may hold MORE blocks than there are roles: a rendered block holding `U+000A` — the engine's block
    /// separator, which the bridge's contract keeps out (`withoutBlockSeparators`) — is split by the engine into
    /// one block per line. Zipped positionally, every role after the split went to the wrong engine block, so the
    /// layout's recovery "by identity" (`recoverRolesFromEngineIdentities`) rebuilt from roles already shifted: a
    /// split language took the code BODY's role (`[code lang="x" "y"] [p "body"]`), cells moved one place, an
    /// authored quote's last child became its author (composer harness p23 audit). Here each rendered block's
    /// role goes to the FIRST engine block of its lines; the lines after it are left unknown — the recovery
    /// makes each a body paragraph where it stands — and the blocks after the span are matched from the END,
    /// so no role is ever given to a block it did not render (p24 fix wave, `HarnessRoleRecoveryByIdentityTests`).
    private func recordBlockIdentitiesAfterReplacingSpan(first: Int, newLast: Int, rendered: [NSAttributedString]) {
        let identifiers = engine.tgid_blockIdentifiers
        guard identifiers.count != currentRoles.count else {
            recordBlockIdentities(identifiers)
            return
        }
        var pairs: [(UUID, EngineBlockRole)] = []
        for index in 0..<min(first, identifiers.count, currentRoles.count) {
            pairs.append((identifiers[index], currentRoles[index]))
        }
        var engineIndex = first
        if newLast >= first {
            for index in first...newLast where index < rendered.count && index < currentRoles.count {
                guard engineIndex < identifiers.count else { break }
                pairs.append((identifiers[engineIndex], currentRoles[index]))
                let lines = (rendered[index].string as NSString).components(separatedBy: "\n").count
                engineIndex += lines
            }
        }
        let tail = currentRoles.count - (newLast + 1)
        if tail > 0, identifiers.count - tail >= engineIndex {
            for offset in 0..<tail {
                pairs.append((identifiers[identifiers.count - tail + offset], currentRoles[newLast + 1 + offset]))
            }
        }
        structureByEngineIdentity = Dictionary(pairs, uniquingKeysWith: { _, latest in latest })
    }

    /// The engine asks, by identity, what an EMPTY block should be measured, typed into and placed
    /// with — and the answer is the bridge's own rendering of THAT block's current role. No map to
    /// build at set time, nothing keyed by identities a set could re-mint, nothing that can lag a
    /// selection change.
    internal func installEmptyLineProviders() {
        engine.id_emptyLineAttributesProvider = { [weak self] identifier in
            guard let self, let role = self.role(forEngineIdentity: identifier) else { return nil }
            let attributes = self.cachedLineAttributes(for: role)
            return attributes.isEmpty ? nil : attributes
        }
        engine.id_emptyLineCaretOffsetProvider = { [weak self] identifier in
            guard let self, let role = self.role(forEngineIdentity: identifier) else { return nil }
            let offset = self.bridge.emptyLineCaretOffset(for: role)
            return offset == 0 ? nil : NSNumber(value: Double(offset))
        }
    }

    /// `bridge.lineAttributes(for:)` through `lineAttributesByShape` (cleared whenever the bridge is
    /// replaced). The probe renders a one-block document wrapped in the role's WHOLE ancestry, so it
    /// costs O(depth); every empty line of one shape answers the same, so it is asked once per shape.
    /// The spacing walk asks it for every empty block several times per layout — every nested quote's
    /// author line is one — and uncached that was most of what made a keystroke grow with quote
    /// depth (`HarnessNestedQuoteKeystrokeScalingTests`).
    internal func cachedLineAttributes(for role: EngineBlockRole) -> [NSAttributedString.Key: Any] {
        let key = EngineDocumentBridge.probeShapeKey(for: role)
        if let known = lineAttributesByShape[key] { return known }
        let attributes = bridge.lineAttributes(for: role)
        lineAttributesByShape[key] = attributes
        return attributes
    }

    /// The role behind an engine identity: from the identity table, or — while a host set is
    /// landing and the table still describes the previous document — positionally, from the roles
    /// the setter installed before the engine minted the new identities. The engine adopts an empty
    /// block's typing attributes on the selection move INSIDE that set, before the setter can
    /// record anything; answering positionally there is what lets a paragraph after a table take
    /// its own face rather than the last cell's (measured on device under the pushed maps).
    private func role(forEngineIdentity identifier: UUID) -> EngineBlockRole? {
        if let role = structureByEngineIdentity[identifier] { return role }
        // `tgid_index(ofBlockIdentifier:)`, not `tgid_blockIdentifiers.firstIndex(of:)`: the canvas asks
        // this once per block during a set, and rebuilding + bridging the identifier array per call
        // made a long rich paste O(n²) (1000 lines froze for 149 s; `HarnessLargeRichPasteScalingTests`).
        guard isApplyingHostDocument else { return nil }
        let index = engine.tgid_index(ofBlockIdentifier: identifier)
        guard index != NSNotFound, currentRoles.indices.contains(index) else { return nil }
        return currentRoles[index]
    }

    /// The resolver lives in another file; Swift `private` does not reach it.
    internal var structureByEngineIdentityForResolver: [UUID: EngineBlockRole] { structureByEngineIdentity }
    internal func recordBlockIdentitiesForResolver(_ identifiers: [UUID]) {
        markRoleChanges(identifiers)
        recordBlockIdentities(identifiers)
    }

    /// The recovery for roles that do not count the engine's blocks (`syncTableFramesOnce`): the roles
    /// by the engine's own identities, a block the table has never seen as a fresh body paragraph — so
    /// every block the engine holds is read into the model and nothing it holds is dropped from what is
    /// sent (composer harness p23). Its presentation is re-derived at the next settle.
    ///
    /// BY IDENTITY, both halves (p24 fix wave, `HarnessRoleRecoveryByIdentityTests`): the table it reads is
    /// recorded split-aware by the setter (`recordBlockIdentitiesAfterReplacingSpan`), so a known identity gets
    /// the role of the block it rendered, never its neighbour's; an unknown one is a body paragraph WHERE IT
    /// STANDS — at its predecessor's depth, as settle declares a fresh block (out of a block quote after its
    /// author line, the author being the quote's last line). It used to be provisionally top level, which
    /// split the quote around a block found inside it.
    internal func recoverRolesFromEngineIdentities(_ identifiers: [UUID]) {
        var recovered: [EngineBlockRole] = []
        recovered.reserveCapacity(identifiers.count)
        for identifier in identifiers {
            if let known = structureByEngineIdentity[identifier] {
                recovered.append(known)
                continue
            }
            var ancestry: [EngineAncestor] = []
            if let previous = recovered.last {
                ancestry = previous.secondaryKind == .blockQuoteAuthor ? Array(previous.ancestry.dropLast()) : previous.ancestry
            }
            recovered.append(freshBodyRole(within: ancestry))
        }
        currentRoles = recovered
        for identifier in identifiers { touchedSinceSettle.insert(identifier) }
        recordBlockIdentities(identifiers)
        structureTouchedThisEdit = true
        setNeedsLayout()
    }
    internal func registerUndoManagerObserver(_ observer: NSObjectProtocol) { undoManagerObservers.append(observer) }

    /// Marks the consumer's `onChange` owed and schedules the coalesced fallback delivery — see
    /// `isChangeNotificationPending`'s doc comment for why it is never fired from here directly.
    private func scheduleChangeNotification() {
        isChangeNotificationPending = true
        guard !isChangeNotificationFlushScheduled else { return }
        isChangeNotificationFlushScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isChangeNotificationFlushScheduled = false
            self.flushPendingChangeNotification()
        }
    }

    /// Delivers an owed `onChange` from THIS stack. Safe to call from anywhere that is not the
    /// engine's `-processEditing`; a no-op when nothing is owed.
    private func flushPendingChangeNotification() {
        guard isChangeNotificationPending else { return }
        // Inside a multi-step verb the notification stays owed; the verb's own end delivers it.
        guard changeNotificationBatchDepth == 0 else { return }
        isChangeNotificationPending = false
        // A selection change earlier in THIS run-loop turn may still have the coalesced fallback
        // queued (`scheduleSelectionDrivenOnChange`) — a drag-select immediately followed by a
        // command, in the same turn. This delivery reports the document as it stands NOW, wherever
        // the selection ended up, so that fallback's job is already done: clearing the flag here is
        // what lets it discover that when its turn comes and stand down, instead of firing again
        // for a change this delivery already covers.
        isSelectionOnChangeScheduled = false
        // A list-continuation reconciliation scheduled since this notification was marked takes
        // ownership of the consumer's next `onChange` (`+Paragraph.swift`'s list-continuation
        // section): firing here would expose the not-yet-reconciled intermediate document, and that
        // reconciliation's own trailing, unconditional call covers this edit too. Same suppression
        // `engineDidChangeDocument()` applies when the two coincide within one edit — stated once
        // more here because the async path can put a reconciliation between the mark and the flush.
        guard !isListContinuationReconciliationScheduled else { return }
        onChange?()
    }

    /// Delivers `onChange` NOW, from this stack, for a mutation that produced no engine change
    /// funnel call of its own to piggy-back on — its `document =` set having been swallowed by the
    /// `isApplyingHostDocument` guard. Marking the flag before flushing is what makes this
    /// **consume** any coalesced delivery still owed rather than sit beside it: one settled
    /// document, one notification, and the stale scheduled flush finds nothing left to fire.
    ///
    /// Suppression against a pending list-continuation reconciliation is NOT re-implemented here —
    /// it lives in `flushPendingChangeNotification()`, which this goes through, so a caller cannot
    /// get it subtly different. INTERNAL, and no longer a single caller: every host command and
    /// every first-refusal DOOR that must tell the consumer now flushes through here — a rule shared
    /// by two doors must NOT, or its delivery lands beside the door's and the same keystroke notifies
    /// twice (measured on the boundary rule, 2026-09-08).
    internal func deliverChangeNotificationNow() {
        isChangeNotificationPending = true
        flushPendingChangeNotification()
    }

    /// **The one place `onCaretRevealNeeded` is ever called**, and the reason there is only one.
    ///
    /// The engine marks `tgid_caretRevealPending` from its own caret path, which upstream reaches
    /// three times per keystroke; this reports at the END of the edit instead, where the geometry is
    /// settled, and immediately for a caret move with no edit in flight — the arrow-key case, which
    /// must settle before the next key event rather than a run-loop turn later.
    ///
    /// The flag is NOT cleared here. It is the host's pass that clears it, by performing the reveal;
    /// leaving it set means a host that ignores the report keeps being owed one, which is what the
    /// DEBUG audit later in this plan notices.
    internal func reportCaretRevealIfOwed() {
        guard engine.tgid_caretRevealPending, !isEngineEditInFlight else { return }
        onCaretRevealNeeded?()
        auditPendingCaretReveal()
    }

    /// How many times a reveal was reported to a host that then never asked about it. Zero in both
    /// shipping hosts; a test can read it, which is what makes the audit below more than a log
    /// nobody sees.
    internal private(set) var caretRevealsNeverAskedAbout = 0

    /// **Caret-follow now depends on a host pass arriving.** Before this design the editor followed
    /// the caret whatever the host did; now a host that stops calling `update(…caretReveal:)`
    /// silently stops following it, and the symptom is "typing feels broken" rather than a missing
    /// call. This notices, a run-loop turn later, that the reveal it reported is still owed.
    ///
    /// Deliberately a COUNT and a log rather than an assertion. The check is necessarily deferred,
    /// and an assertion firing a turn later lands inside whatever test happens to be running by then
    /// — a failure attributed to innocent code, which is worse than the defect it reports. Gated on a
    /// host having installed the callback at all: with nobody listening there is no promise to break,
    /// which is the case in every unit test that drives the engine directly.
    private func auditPendingCaretReveal() {
        #if DEBUG
        guard onCaretRevealNeeded != nil else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.engine.tgid_caretRevealPending else { return }
            self.caretRevealsNeverAskedAbout += 1
            print("RichTextEngineEditorView: a caret reveal was reported and never asked about. The "
                  + "host must answer onCaretRevealNeeded with update(…, caretReveal: .ifNeeded(…)), "
                  + "or the caret stops being followed.")
        }
        #endif
    }

    /// A mutator's own document set, the caret restore that follows it, and the ONE notification
    /// they owe between them.
    ///
    /// The notification is marked owed BEFORE `body` runs, and that ordering is the whole point. A
    /// mutator ends by putting the caret back where it was, which reaches `engineDidChangeSelection`
    /// like any other selection change — and `scheduleSelectionDrivenOnChange` declines to schedule
    /// only when a notification is already owed. Marking it at the END (`deliverChangeNotificationNow`)
    /// leaves that guard reading `false` for the duration of the mutation, so the restore schedules
    /// a SECOND delivery a run-loop turn later, after the mutator's own has already fired.
    ///
    /// Measured (2026-09-04) by counting deliveries over a run-loop window: EVERY paragraph mutator
    /// delivered `onChange` twice — `setParagraphStyle`, `setList`, `setAlignment`, `indent`,
    /// `outdent`, and the list-continuation reconciliation — the second landing a turn behind the
    /// first, from the caret restore each of them ends with.
    ///
    /// This is a SECOND, independent path to a double delivery, alongside the one
    /// `scheduleSelectionDrivenOnChange`'s reconciliation guard closes; neither subsumes the other.
    /// That guard cannot cover this one, because a mutator's restore runs when no reconciliation is
    /// pending at all (a toolbar tap), and because the reconciliation clears its own flag before it
    /// mutates. Reverting either fix alone brings its own double delivery back — measured both ways.
    ///
    /// It was invisible to the tests that pin the contract: they wait for the FIRST `onChange` and
    /// return, so the second arrives after the test has already finished. Counting over a window is
    /// what shows it — see `EngineChangeNotificationCountTests`. A caret restore is part of the
    /// mutation, not a user caret move.
    internal func deliveringOneChangeNotification(_ body: () -> Void) {
        isChangeNotificationPending = true
        body()
        flushPendingChangeNotification()
    }

    /// `deliveringOneChangeNotification` for a verb composed of steps that each deliver on their own
    /// (`insertText`, `insertEmoji`, `setLink`): every flush inside `body` keeps the notification
    /// owed, and ONE delivery follows `body`. Without it a host insert of a mention — typed text,
    /// then a link over it, then a space — told the consumer three times, twice about a document
    /// that was not finished (`insertInlineRunsOnUsersBehalf`).
    internal func deliveringOneChangeNotificationAcrossSteps(_ body: () -> Void) {
        isChangeNotificationPending = true
        changeNotificationBatchDepth += 1
        body()
        changeNotificationBatchDepth -= 1
        flushPendingChangeNotification()
    }

    /// Runs `body` — an engine call this class initiates — and then delivers whatever change
    /// notification it produced, from this stack rather than the engine's `-processEditing`.
    /// INTERNAL: `+Responder.swift` and `+Formatting.swift` wrap their forwards in it.
    internal func deliveringChangeNotification(_ body: () -> Void) {
        body()
        flushPendingChangeNotification()
        // A host-driven mutation produces an engine document change but no `textInputDidChange:`, so
        // without this the edit would never be declared finished and every later caret move would be
        // suppressed as "mid-edit".
        isEngineEditInFlight = false
        reportCaretRevealIfOwed()
    }

    /// Gated the same way as `engineDidChangeDocument`: the setter's own end-of-document caret
    /// move (`document`'s setter, above) reaches this callback SYNCHRONOUSLY too — Task 1's
    /// `EngineObservationCompletenessTests.test_programmaticSelectionChangeIsObserved` exists
    /// precisely to establish that a programmatic `selectedTextRange` write is observed. Left
    /// unguarded, every host-driven `document` set would fire `onSelectionChange` indistinguishably
    /// from a real user caret move — the same masquerading the `onChange` guard prevents, on the
    /// sibling callback. See `EngineEditorDocumentTests.test_settingTheDocumentDoesNotFireOnSelectionChange`.
    /// Rebuilds the document bridge around a mapper carrying `theme`, then re-applies the current
    /// document so already-rendered text picks up the new colours.
    ///
    /// The theme is a MAPPER input, not a view decoration: `AttributedStringMapper.init` takes it
    /// (`:54`) and `characterAttributes(from:)` reads `theme.primaryText` as the foreground. Storing
    /// it without rebuilding would leave the engine rendering the default palette whatever the app's
    /// appearance — white-on-white in dark mode.
    ///
    /// **Only the theme changes.** This built a mapper from the theme ALONE, which silently reset
    /// everything else the mapper carries — the render metrics, the code geometry, the quote
    /// geometry — back to their defaults. The composer pushes a theme on every presentation update,
    /// long after it configures the editor, so a host's configuration survived only until the first
    /// appearance change: the code block's horizontal inset disappeared and the block rhythm reverted
    /// to unreduced edge spacing. It also left `self.mapper` untouched, so the view and its bridge
    /// then disagreed about the palette they were rendering with.
    internal func rebuildMapper(withTheme theme: RichTextEditorTheme) {
        // Read through the bridge that rendered it — see `applyRenderMetrics`.
        let current = document
        var updated = mapper
        updated.theme = theme
        mapper = updated
        remakeBridge()
        rerenderPresentation(of: current)
    }

    /// The controller finished an edit: settle (surface-gate spec §3.2). Not while the gate is
    /// issuing its own edits for this keystroke, and not re-entrantly for settle's own.
    fileprivate func engineDidFinishEdit() {
        // Not while the gate, settle or a host command is issuing its own edits (they report here
        // too — a command settles once, at its end), and never during an undo or redo replay
        // (resolver spec §7).
        guard !isDecidingAtGate, !isSettling, !isIssuingHostEdit,
              !(engine.undoManager.map { $0.isUndoing || $0.isRedoing } ?? false) else {
            isEngineEditInFlight = false
            return
        }
        settleAfterEdit()
        // Settle can change what the caret's block IS (a code body's language line appears, a
        // container unwraps) without moving the caret.
        refreshCodeInputTraits()
        // AFTER the settle: it re-derives presentation and can move the caret, so the geometry the
        // host is about to be asked about is the settled one, not the one mid-edit.
        isEngineEditInFlight = false
        reportCaretRevealIfOwed()
    }

    /// The engine finished a layout pass of its own. The one host view placed from geometry INSIDE a
    /// placed run and hosted in the ENGINE's space is the table's structural chrome — anchored there
    /// so its row grip does not ride the run's scroll — and a scroll tick lays out the engine and
    /// nothing else, so this is where the chrome follows the cells. Every other overlay inside a run
    /// (grid chrome, custom emoji, dust, pills, formula targets) lives in the run's content view and
    /// rides the scroll on its own; the rest of the placement pass stays in `layoutSubviews`. Skipped
    /// while a document set is landing: the roles are mid-rebuild and the pass runs anyway once the
    /// set marks the editor for layout.
    fileprivate func engineDidLayout() {
        guard !isApplyingHostDocument, !isMeasuringHeight, !isPlacingDerivedViews else { return }
        // Before the chrome: a restored offset scrolls the run, and the chrome follows that scroll
        // from the pass it triggers.
        syncRunScrollOffsets()
        syncTableStructuralChrome()
        // The engine's own pass is the one nothing else checks: a run's scroll dirties the engine
        // and nothing marks the host for layout, so without this the check would never see a
        // scrolled table at all — which is the exact pass the chrome used to sit out.
        verifyDerivedViewPlacement()
    }

    /// A keystroke (or host command) the HOST decided — a Backspace rule at the caret door, a veto
    /// at the gate, a structural command — has fully landed and no `textInputDidChange:` will
    /// follow it, so the edit it marked in flight is over and the undo run it may have opened is
    /// closed: a structural step never has typing fold into it, and a caret move after it is a caret
    /// move of its own again (`refreshUndoBaselineSelection` bails while an edit is in flight, so a
    /// flag left stuck kept every later move from ending the run — composer harness, 2026-09-24,
    /// `HarnessCompositionUndoStepTests`).
    ///
    /// The one exception is the selection a COMPOSITION starts over: that deletion and the
    /// composition are one step, as a stock text view's composition over a selection is, so the run
    /// is re-opened at the caret the deletion left for the first candidate to continue.
    /// Settles what waited for a composition to commit (an empty quote's author line). The commit is
    /// part of the composition's edit, so the run it continues stays open for typing after it.
    internal func settleAfterCompositionCommit() {
        guard !isDecidingAtGate, !isSettling, !isIssuingHostEdit, !isApplyingUndoSnapshot else { return }
        deliveringChangeNotification {
            if rolesBeforeEdit == nil { rolesBeforeEdit = currentRoles }
            settleAfterEdit()
        }
    }

    internal func endHostDecidedKeystroke() {
        isEngineEditInFlight = false
        // Only when the deletion REGISTERED a step. The gate can resolve a selection to nothing — a
        // range from the end of a code body into its quote's empty author line collapses the caret
        // and changes no character — and a run re-opened there has no step behind it: the
        // composition continued it, registered none of its own, and one undo popped the step BEFORE
        // the composition (composer harness fuzz seeds 63 and 86, 2026-09-24,
        // `HarnessCompositionUndoResidualTests`). With nothing to join, the composition opens its own.
        if engine.tgid_isResolvingCompositionSelection,
           undoStepRegistrationCount != undoStepRegistrationCountAtGateEntry {
            openTypingRunEnd = engineSelectedRange.location
            openRunEndsInComposition = false
        } else {
            endTypingRun()
        }
    }

    fileprivate func engineDidChangeSelection() {
        // Whatever moved the selection, whether a drag could lift it now (`+DragAndDrop.swift`).
        textDragAndDrop.refreshDragAvailability()
        // A trait probe's parked selection is not a selection change: it is restored before the call
        // that made it returns, and every consequence below — clearing the structural selection,
        // relaying out, and above all SCHEDULING a host update — is wrong for it. The update is what
        // asks for the traits, so reporting the probe's own moves looped.
        guard !isApplyingHostDocument, !isProbingInlineTraits else { return }
        // Mid-keystroke the keyboard is not reloaded; `engineDidFinishEdit` re-derives once settled.
        // Likewise the undo baseline: only a caret move of its own moves the caret an undo restores.
        if !isEngineEditInFlight {
            refreshCodeInputTraits()
            refreshUndoBaselineSelection()
        }
        // A caret that moved with no edit around it owes a reveal NOW: this is the arrow-key case,
        // and it has to settle before the next key event rather than a run-loop turn later. Inside a
        // keystroke the report waits for the edit to finish (`reportCaretRevealIfOwed` declines while
        // one is in flight), so a keystroke still produces exactly one.
        reportCaretRevealIfOwed()
        cachedStructuralTraits = nil
        // ONE guarded site, not a `clearTableStructuralSelection()` at each known route. A route
        // nobody thought of — a hardware arrow, a tap, the loupe, a host command — clears it too.
        // Spelled per-site, the next route added silently keeps a stale selection alive, which is the
        // shape of defect this branch has hit repeatedly: a rule written for the doors that existed.
        if !isParkingCaretForStructuralSelection { clearTableStructuralSelection() }
        // A spoiler reveals and re-hides as the selection moves, which is not a document change, so
        // the rendered text would otherwise never be recomputed.
        engine.setNeedsDisplayDecorationUpdate()
        setNeedsLayout()
        onSelectionChange?()
        scheduleSelectionDrivenOnChange()
    }
}

/// A separate object so the view is not itself an ObjC-visible sink — the protocol conformance
/// stays an implementation detail and cannot be reached from outside the module.
@available(iOS 18.4, *)
private final class EngineObserver: NSObject, TGIDEngineObservationSink {
    private weak var owner: RichTextEngineEditorView?
    init(owner: RichTextEngineEditorView) { self.owner = owner }

    func engineDidChangeDocument(withReplacedRange replacedRange: NSRange,
                                replacementLength: UInt,
                                charactersChanged: Bool) {
        owner?.engineDidChangeDocument(replacedRange: replacedRange,
                                       replacementLength: Int(replacementLength),
                                       charactersChanged: charactersChanged)
    }

    func engineDidFinishEdit() {
        owner?.engineDidFinishEdit()
    }
    func engineDidChangeSelection() {
        owner?.engineDidChangeSelection()
    }
    func engineDidLayout() {
        owner?.engineDidLayout()
    }
    func engineDidBecomeFirstResponder() {
        owner?.textDragAndDrop.refreshDragAvailability()
        owner?.composerHostState.onBecameFirstResponder?()
    }
    func engineDidResignFirstResponder() {
        owner?.textDragAndDrop.refreshDragAvailability()
        owner?.composerHostState.onResignedFirstResponder?()
    }
}
#endif
