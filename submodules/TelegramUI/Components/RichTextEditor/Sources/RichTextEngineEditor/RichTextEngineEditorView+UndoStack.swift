#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// **The editor's own undo stack — snapshots of the document, not UIKit's text operations.**
///
/// See the RichTextEditor `CLAUDE.md`, "The editor owns its undo stack".
///
/// UIKit decides undo granularity from WHICH ENTRY POINT delivered the text: a hardware key press
/// arrives as `insertText:` and is registered as operation type 2, which coalesces, while the
/// keyboard's correction path arrives as `replaceRange:withText:` and is type 3, which calls
/// `stopCoalescing` and never folds. Measured, typing `"hello world"` one character at a time is ONE
/// undo step through the first and ELEVEN through the second. That is what reached the user as "⌘Z
/// acts like it should, the undo button erases char by char" — the two verbs were always the same
/// stack and the same method; the keyboards were different.
///
/// It is also the wrong model for this editor. UIKit's operations are text ranges in one storage;
/// this document is blocks, with a role per engine block and a selection on a third axis. That
/// mismatch is why every structural command has had to CLEAR the history
/// (`recordUndoStepForStructuralChange`) — UIKit's ranges describe text that no longer exists.
///
/// So the stack here holds `EngineUndoSnapshot`, and one undo restores a whole editor state.
/// The editor's undo manager. One addition to `UndoManager`: a step a composition is HOLDING back
/// (`pendingCompositionUndoStep`, registered only when the composition ends with a change) counts as
/// undoable and is registered the moment an undo asks for it — so ⌘Z or the toolbar's Undo during an
/// open composition still reverts it (`EngineUndoRedoHostTests.test_aMultiStepCompositionIsStillOneStep`),
/// while a composition that is cancelled leaves nothing behind (composer harness p21). For REDO the held
/// step counts as registered: opening it empties the redo stack (`clearRedoStack`, p22).
final class EngineUndoManager: UndoManager {
    /// Whether a held step exists, and the registration of it. Set by the editor.
    var hasHeldStep: () -> Bool = { false }
    var registerHeldStep: () -> Void = {}

    override var canUndo: Bool {
        super.canUndo || hasHeldStep()
    }

    override func undo() {
        registerHeldStep()
        super.undo()
    }

    /// Empties the REDO stack and nothing else — what registering a step does to it. A held step is
    /// not registered yet, but for redo it must behave as if it were: a stock `UITextView`'s first
    /// marked edit registers, which clears redo, so redo is unavailable during the composition and
    /// stays gone after a cancel (composer harness p22, `HarnessRedoDuringCompositionTests`). Left live,
    /// a redo mid-composition replayed a snapshot over the marked text and the pre-composition
    /// document became unreachable.
    ///
    /// `UndoManager` has no public "clear redo", so this registers a throwaway action in a group of
    /// its own and removes it. Measured (Foundation, 2026-10-01): the removal drops a TOP-LEVEL group
    /// it empties, but an EMPTY group nested in another stays and is an undo that does nothing — so at
    /// grouping level 0 event grouping is suspended (otherwise `beginUndoGrouping` opens the event's
    /// group first and ours nests in it); at level 1 the event's group already holds a real step, which
    /// the empty nested group rides along with harmlessly.
    final func clearRedoStack() {
        guard super.canRedo, !isUndoing, !isRedoing, isUndoRegistrationEnabled, groupingLevel <= 1 else { return }
        let token = NSObject()
        let byEvent = groupsByEvent
        if groupingLevel == 0 { groupsByEvent = false }
        beginUndoGrouping()
        registerUndo(withTarget: token) { _ in }
        endUndoGrouping()
        groupsByEvent = byEvent
        removeAllActions(withTarget: token)
    }
}

@available(iOS 18.4, *)
extension RichTextEngineEditorView {

    /// Everything an undo has to put back. **Roles are NOT stored**: the `document` setter derives
    /// them through the bridge, so they are a function of the document and a second copy could only
    /// go stale — the same reasoning that keeps text out of a role.
    internal struct EngineUndoSnapshot {
        let document: Document
        let selection: NSRange
        /// The selection the change that produced `document` LEFT — which a caret move afterwards
        /// does not change (`refreshUndoBaselineSelection` moves only `selection`). It is what a REDO
        /// of that change restores: a stock `UITextView` redoes an insertion with the caret after the
        /// redone text, wherever the caret was when undo was pressed. Measured (composer harness,
        /// 2026-09-23, `HarnessRedoCaretTests`): type at 44, move to 4, undo, redo gave 4, not 45,
        /// because the redo step was registered with the live selection of the undo moment.
        let editSelection: NSRange
        /// The engine's format-command typing state (`tgid_formatCommandSelection`, composer harness p22):
        /// which selection a format command last set the typing attributes for. Typing state, and an undo
        /// puts it back as a stock text view's undo puts back the attributes its newline was given — the
        /// fuzz's chat-insert oracle (default seed 40, edited seed 4) typed plain after undoing an insert
        /// that had itself been formatted.
        let formatCommandSelection: NSRange?

        init(document: Document, selection: NSRange, editSelection: NSRange? = nil,
             formatCommandSelection: NSRange? = nil) {
            self.document = document
            self.selection = selection
            self.editSelection = editSelection ?? selection
            self.formatCommandSelection = formatCommandSelection
        }
    }

    internal func currentUndoSnapshot() -> EngineUndoSnapshot {
        EngineUndoSnapshot(document: replayDocument, selection: engineSelectedRange,
                           formatCommandSelection: engine.tgid_formatCommandSelection?.rangeValue)
    }

    internal func installUndoStack() {
        // `groupsByEvent` STAYS ON, and that is not laziness. Pointing the engine's `undoManager`
        // at this stack means the engine's own upstream code registers into it too —
        // `IDInlineTextFormattingController` registers a formatting snapshot through
        // `host.undoManager` — and with event grouping off those registrations arrive outside any
        // group and `NSUndoManager` rejects them ("must begin a group before registering undo",
        // measured across 100 tests). Event grouping also costs nothing here: a run registers
        // exactly once at its start and nothing afterwards, so one iteration is one step anyway.
        engineUndoManager.groupsByEvent = true
        engineUndoManager.hasHeldStep = { [weak self] in self?.pendingCompositionUndoStep != nil }
        engineUndoManager.registerHeldStep = { [weak self] in self?.registerPendingCompositionUndoStepNow() }
        engineUndoManager.levelsOfUndo = Self.undoDepth
        // The routing that makes ⌘Z and the toolbar button the same thing. See the header.
        engine.tgid_undoManagerOverride = engineUndoManager
        lastSettledUndoSnapshot = currentUndoSnapshot()
        // **The host is told from the MANAGER, not from the verbs.** ⌘Z, shake and the edit menu
        // reach `engineUndoManager.undo()` through `UIResponder` without passing through this
        // class at all, so a delivery written into `undo()`/`redo()` would leave the host unaware
        // of every system undo. These notifications are posted once the manager has finished, which
        // is also what makes the availability the host reads from them the SETTLED one — the defect
        // legacy documents at its own pair and closes with a trailing refresh.
        for name in [Notification.Name.NSUndoManagerDidUndoChange, .NSUndoManagerDidRedoChange] {
            let observer = NotificationCenter.default.addObserver(forName: name, object: engineUndoManager,
                                                                  queue: nil) { [weak self] _ in
                self?.deliverChangeNotificationNow()
            }
            registerUndoManagerObserver(observer)
        }
    }

    /// A cap rather than an assumption. A snapshot holds a whole `Document`, but blocks are values
    /// sharing storage, so the real cost is proportional to what CHANGED — still, an editor open for
    /// an hour should not grow without bound.
    internal static var undoDepth: Int { 200 }

    // MARK: - Registering

    /// One undo step, restoring `snapshot`, with its own mirror registered on the way back so redo
    /// falls out of the same code.
    internal func registerUndoStep(restoring snapshot: EngineUndoSnapshot) {
        // A step a composition opened is OLDER than this one: it goes on the stack first.
        registerPendingCompositionUndoStepNow()
        undoStepRegistrationCount += 1
        engineUndoManager.registerUndo(withTarget: self) { editor in
            let inverse = editor.currentRedoSnapshot()
            editor.applyUndoSnapshot(snapshot)
            editor.registerUndoStep(restoring: inverse)
        }
    }

    /// The state an undo (or redo) step's mirror restores: the live document, with the selection the
    /// change that produced it left rather than wherever the caret was moved since. Mid-edit there is
    /// no settled change to speak for the document, so the live selection is the only answer.
    private func currentRedoSnapshot() -> EngineUndoSnapshot {
        guard !isEngineEditInFlight, let baseline = lastSettledUndoSnapshot else {
            return currentUndoSnapshot()
        }
        return EngineUndoSnapshot(document: replayDocument, selection: baseline.editSelection,
                                  formatCommandSelection: engine.tgid_formatCommandSelection?.rangeValue)
    }

    /// Restores a snapshot without recording it as a new edit.
    internal func applyUndoSnapshot(_ snapshot: EngineUndoSnapshot) {
        isApplyingUndoSnapshot = true
        // The restore replaces whatever a composition had marked; the step it held back describes a
        // document that is gone.
        pendingCompositionUndoStep = nil
        document = snapshot.document
        let length = joinedEngineLength()
        let clamped = NSRange(location: min(snapshot.selection.location, length),
                              length: min(snapshot.selection.length,
                                          max(0, length - min(snapshot.selection.location, length))))
        engineSelectedRange = clamped
        // The typing state the snapshot was taken with, after the selection (whose change clears it).
        engine.tgid_formatCommandSelection = snapshot.formatCommandSelection.map { NSValue(range: $0) }
        engine.tgid_readoptEmptyBlockTypingAttributes()
        isApplyingUndoSnapshot = false
        endTypingRun()
        lastSettledUndoSnapshot = currentUndoSnapshot()
        // NO delivery here. It belongs to the manager's own did-undo notification (see
        // `installUndoStack`), which fires once the stack has settled and covers ⌘Z too; delivering
        // here as well would notify twice for one verb.
    }

    private func joinedEngineLength() -> Int {
        let blocks = engine.attributedBlocks
        return blocks.reduce(0) { $0 + $1.length } + max(0, blocks.count - 1)
    }

    /// Ends the open typing run, so the next edit starts a step of its own.
    internal func endTypingRun() { openTypingRunEnd = nil }

    /// An EXTERNAL content set happened (the host replaced the document from outside): the steps on
    /// the stack describe a document the user no longer has, so both stacks are emptied and the live
    /// state becomes the baseline — a stock `UITextView`'s rule on a `text` set. See the protocol.
    public func discardUndoHistory() {
        pendingCompositionUndoStep = nil
        engineUndoManager.removeAllActions()
        endTypingRun()
        lastSettledUndoSnapshot = currentUndoSnapshot()
    }

    /// A host's set on the USER's behalf, as ONE step on top of the stack (see the protocol). The set's
    /// own engine edits register nothing (`isApplyingHostDocument` keeps the funnel out, and
    /// registration is off around `body` as for an inline format step); the step restores the
    /// document and selection from before `body`, and the setter's baseline becomes its after-state.
    public func performAsOneUndoStep(_ body: () -> Void) {
        performAsOneUndoStep(registeringWhenUnchanged: { false }, body)
    }

    /// `performAsOneUndoStep(_:)`, except that `registeringWhenUnchanged` — asked after `body` —
    /// can make the step register although the document came out as it was. A local MOVE is an
    /// edit the user made whatever its result: a stock text view registers it, and a body paragraph
    /// did here too (its moved text came back under fresh block ids), but a move inside a pull quote
    /// that put identical text back compared equal and registered nothing, so the next ⌘Z took back
    /// the edit BEFORE the move (composer harness p20, `HarnessPullQuoteNoOpMoveUndoTests`).
    internal func performAsOneUndoStep(registeringWhenUnchanged: () -> Bool, _ body: () -> Void) {
        let before = currentUndoSnapshot()
        engineUndoManager.disableUndoRegistration()
        body()
        engineUndoManager.enableUndoRegistration()
        guard replayDocument != before.document || registeringWhenUnchanged() else { return }
        recordUndoStepForCommand(restoring: before)
    }

    /// A change this editor made that is NOT a text edit — a command, a format toggle, a document
    /// set. Ends the run and records one step restoring `snapshot`.
    ///
    /// Takes the before-state explicitly because a command has usually already mutated by the time
    /// it can call this, and because several commands rebuild through the `document` setter, whose
    /// edit the funnel below never sees (`isApplyingHostDocument`).
    internal func recordUndoStepForCommand(restoring snapshot: EngineUndoSnapshot) {
        endTypingRun()
        registerUndoStep(restoring: snapshot)
        lastSettledUndoSnapshot = currentUndoSnapshot()
    }

    /// An INLINE format command — a trait toggle, a link, a spoiler, inline code — as ONE step that
    /// restores the text, its formatting AND the selection it was applied to.
    ///
    /// Measured (composer harness, 2026-09-22): a Bold toggle registered TWO entries in one group —
    /// the funnel's `recordUndoForEngineEdit`, restoring `lastSettledUndoSnapshot` (whose selection is
    /// the last settled EDIT's, not the live one), and `IDInlineTextFormattingController`'s own
    /// attribute snapshot through `host.undoManager`, which is this stack. Undo ran both, the funnel's
    /// last, so the selection landed on the stale caret; the controller's restore was itself an engine
    /// edit, so the funnel registered a THIRD entry during the undo, and redo replayed a plain
    /// document. Registration is off for the command, and the one step is registered here.
    ///
    /// `selection` is the selection to restore when the command parks the caret while it works (a
    /// table's structural selection); nil means the live selection. No step when nothing changed —
    /// a toggle on a collapsed caret only changes the typing attributes.
    internal func recordingInlineFormatStep(selection: NSRange? = nil, _ body: () -> Void) {
        let selection = selection ?? engineSelectedRange
        let blocksBefore = engine.attributedBlocks
        let before = EngineUndoSnapshot(document: replayDocument, selection: selection,
                                        formatCommandSelection: engine.tgid_formatCommandSelection?.rangeValue)
        engineUndoManager.disableUndoRegistration()
        body()
        engineUndoManager.enableUndoRegistration()
        // The command restyled the selected text under an unchanged selection, and UIKit derives the
        // typing attributes only on a selection CHANGE: without this a character typed over the
        // selection right after Bold took the unbolded attributes (`HarnessTypingOverFormattedSelectionTests`).
        engine.tgid_adoptTypingAttributesOfSelectedText()
        guard engine.attributedBlocks != blocksBefore else { return }
        endTypingRun()
        registerUndoStep(restoring: before)
        lastSettledUndoSnapshot = EngineUndoSnapshot(document: replayDocument, selection: selection,
                                                     formatCommandSelection: engine.tgid_formatCommandSelection?.rangeValue)
    }

    // MARK: - The coalescing policy

    /// **The rule is CONTIGUITY, and it is measured rather than designed.** A stock `UITextView`
    /// driven through `insertText:` one character at a time (`EngineTypingUndoParityTests`) gives
    /// ONE undo step for a sentence with spaces, for a newline, for a long word, for a run followed
    /// by five backspaces, and for type-backspace-type. It gives TWO when the caret is moved between
    /// runs, and TWO for a selection replacement. So a run continues while each edit begins exactly
    /// where the previous one ended and replaces nothing, and ends otherwise.
    ///
    /// Two things that deliberately do NOT end a run, because iOS does not end one there:
    ///
    /// - a sentence boundary. `-[UITextInputController shouldStartNewUndoGroup:textGranularity:
    ///   operationType:]` would, but only when `[UIKeyboardImpl activeInstance]
    ///   nextInputWouldStartSentence` is true, which it is not in the host the oracle runs in. The
    ///   parity test measures the oracle in the same place, so the two cannot drift; a DEVICE with a
    ///   live keyboard may break there and we will not.
    /// - the typing↔deleting switch. The LEGACY canvas ends a run there (`editing(coalescing:)`);
    ///   iOS does not, and matching iOS was the instruction.
    ///
    /// **A composition continues the run it is contiguous with.** Its updates replace the marked
    /// text, which is a replacement and would otherwise end the run on every IME keystroke — the
    /// defect that had `かんじ` stepping back through `かん` and `か` — so a candidate replacing the
    /// marked text that ENDS the open run continues it. A composition started anywhere else opens
    /// a step of its own, like typing there would.
    ///
    /// **An attribute-only change inside an open run is part of it.** Typing the first character into
    /// an empty line — or deleting the last one — makes the controller re-attribute the separator
    /// after it in the same keystroke, and read by its range that is a replacement: it opened a
    /// SECOND step and moved the run's end one past the caret, so the next keystroke was not
    /// contiguous either. Measured on a code block's language line (composer harness, 2026-09-22):
    /// typing `swift` was two steps, `s` and `wift`. With no run open it is still recorded, so a
    /// re-attribution nothing else registers is not lost.
    internal func recordUndoForEngineEdit(replacedRange: NSRange, replacementLength: Int,
                                          charactersChanged: Bool) {
        guard !isApplyingUndoSnapshot else { return }
        if !charactersChanged, openTypingRunEnd != nil { return }
        // An edit SETTLE makes while a run is open belongs to the edit being settled (an author line
        // minted, a caption line repaired): it registers nothing and leaves the run open, only moved
        // with the text it covers. Registered as an edit of its own it would close the run, and the
        // next character typed into a fresh quote opened a second undo step.
        if isSettling, let runEnd = openTypingRunEnd {
            if replacedRange.location >= runEnd { return }
            if NSMaxRange(replacedRange) <= runEnd {
                openTypingRunEnd = runEnd + replacementLength - replacedRange.length
                return
            }
            endTypingRun()
            return
        }
        // An attribute-only change arriving after this edit already registered its step (settle
        // re-deriving the presentation of the blocks a structural Backspace touched) is part of
        // that step: registering again would restore the same baseline a second time — an undo that
        // changes nothing — and would OPEN a run nothing closes, which a later composition then
        // joined, so one undo reverted the composition AND the unquoting before it (composer
        // harness, 2026-09-24, `HarnessCompositionUndoStepTests`).
        if !charactersChanged, undoStepRegisteredAgainstBaseline { return }

        let isInsert = replacedRange.length == 0 && replacementLength > 0
        let isDelete = replacedRange.length > 0 && replacementLength == 0
        let composing = engine.markedTextRange != nil
        // Where the edit leaves the caret, for all three shapes at once: an insert ends past what it
        // put in, a delete at what it removed from, a replacement past its replacement.
        let newEnd = replacedRange.location + replacementLength

        if let runEnd = openTypingRunEnd {
            let contiguous = (isInsert && replacedRange.location == runEnd)
                          || (isDelete && NSMaxRange(replacedRange) == runEnd)
            // A composition continues the run only where it is CONTIGUOUS with it: its first
            // candidate inserted where the run ends, or a later candidate replacing the marked text
            // that ends it. "Any open run" let a composition typed elsewhere join a run a structural
            // command had left open.
            // The marked text is known to END the run only when the edit that last moved the run
            // was itself a composition's; a selection that merely ends where typing stopped is a
            // replacement like any other (fuzz seed 63, 2026-09-24).
            let continuesComposition = composing && openRunEndsInComposition
                && NSMaxRange(replacedRange) == runEnd
            if contiguous || continuesComposition {
                // The run's opening snapshot already describes where this returns to, so nothing is
                // registered — which is exactly what makes one undo revert the whole run.
                openTypingRunEnd = newEnd
                openRunEndsInComposition = composing
                return
            }
        }

        // A run ENDS here and another OPENS. The second half matters as much as the first: a
        // replacement is its own step, and the characters typed after it continue from it rather
        // than each becoming a step of their own — stock replaces a selection with `H` and then
        // coalesces the `I`, which is what this reproduces.
        // NOT `?? currentUndoSnapshot()`. This runs mid-edit, so the current state is the state
        // AFTER the edit — a fallback would register an undo that restores what is already there and
        // silently does nothing. `installUndoStack` seeds it and the `document` setter and settle
        // both keep it current, so nil is a programming error and says so.
        guard let before = lastSettledUndoSnapshot else {
            assertionFailure("RichTextEngineEditor: no settled snapshot to undo to — the baseline was "
                             + "never seeded, so this edit would register a no-op step.")
            openTypingRunEnd = newEnd
            return
        }
        if composing {
            // A composition that opens a step of its own HOLDS it until it ends: a cancel (every
            // candidate deleted, or the keyboard switched mid-word) leaves the document as it was, and
            // a stock text view records nothing for it — registered now, the step restored what was
            // already there and swallowed the user's next ⌘Z (composer harness p21,
            // `HarnessCancelledCompositionUndoTests`). `resolvePendingCompositionUndoStep()` decides
            // when the composition ends; any other registration before then flushes it first.
            registerPendingCompositionUndoStepNow()
            pendingCompositionUndoStep = before
            // For REDO the held step is already registered: the redo stack describes a future the
            // composition has just left (p22).
            engineUndoManager.clearRedoStack()
        } else {
            registerUndoStep(restoring: before)
        }
        undoStepRegisteredAgainstBaseline = true
        openTypingRunEnd = newEnd
        openRunEndsInComposition = composing
    }

    /// Registers the step a composition is holding back (`pendingCompositionUndoStep`), as it was
    /// when the composition opened it. For a registration that must not leapfrog it.
    internal func registerPendingCompositionUndoStepNow() {
        guard let pending = pendingCompositionUndoStep else { return }
        pendingCompositionUndoStep = nil
        registerUndoStep(restoring: pending)
    }

    /// The composition holding a step back has ENDED (committed, emptied, or found unmarked at a
    /// settle): the step is registered when the document differs from the one it restores, and
    /// dropped when it does not — with the run it opened, so the next keystroke opens a step of its
    /// own rather than continuing a run nothing on the stack stands behind.
    internal func resolvePendingCompositionUndoStep() {
        guard let pending = pendingCompositionUndoStep, engine.markedTextRange == nil else { return }
        pendingCompositionUndoStep = nil
        if replayDocument != pending.document {
            registerUndoStep(restoring: pending)
            return
        }
        endTypingRun()
        if !isEngineEditInFlight, !isSettling {
            lastSettledUndoSnapshot = currentUndoSnapshot()
        }
    }

    /// A caret move with no edit around it: the baseline keeps its document and takes the live
    /// selection, so the next edit's step restores the caret to where THAT edit happened.
    ///
    /// Measured (composer harness, 2026-09-22): type at 44, move the caret to 4, type, undo — the
    /// step restored the baseline settle had left after the FIRST edit, caret 45, where a stock
    /// `UITextView` gives 4. Only the selection moves here: the document is the settled one by
    /// definition, and a selection change reported mid-edit (the caller's in-flight guard) or
    /// during a replay, the gate, settle or a host edit belongs to that edit, which re-seeds the
    /// baseline itself when it finishes.
    internal func refreshUndoBaselineSelection() {
        guard !isApplyingUndoSnapshot, !isDecidingAtGate, !isSettling, !isIssuingHostEdit,
              let baseline = lastSettledUndoSnapshot else { return }
        let selection = engineSelectedRange
        // A caret moved away from where the open run ends starts a new run, as a stock text view's
        // does: measured, moving the caret between two runs gives two undo steps. Without this a
        // caret moved away and BACK to the run's end continued the run, so deleting a word typed
        // before the move coalesced into the typing and one undo restored the state before either.
        if let runEnd = openTypingRunEnd, selection != NSRange(location: runEnd, length: 0) {
            endTypingRun()
        }
        guard baseline.selection != selection else { return }
        lastSettledUndoSnapshot = EngineUndoSnapshot(document: baseline.document, selection: selection,
                                                     editSelection: baseline.editSelection,
                                                     formatCommandSelection: engine.tgid_formatCommandSelection?.rangeValue)
    }

    /// Called at the end of settle: the edit has fully landed, so THIS is the state a later edit
    /// will want to return to.
    internal func commitUndoSnapshotAfterSettle() {
        guard !isApplyingUndoSnapshot else { return }
        // A composition that ended by a route with no handler of its own is resolved here.
        resolvePendingCompositionUndoStep()
        lastSettledUndoSnapshot = currentUndoSnapshot()
    }
}
#endif
