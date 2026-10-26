#if canImport(UIKit)
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit

/// The surface the full-page article editor (`RichTextAttachmentScreen`) calls and the chat composer
/// does not.
///
/// Three kinds of member live here, and which kind each one is matters more than the code:
///
/// 1. **Answered for real** — `currentState()`, and the caret move. `currentState()` in particular
///    CANNOT trap: the toolbar reads it on every change, so a trap there would take the screen down
///    before a user could touch anything, which tells you nothing about the engine.
/// 2. **Stored for a later rung** — the three host callbacks for formulas and buttons. They accept
///    something and hold it; nothing asks them for it yet. Same contract as `+DeferredConfiguration`.
/// 3. **Trapped, naming the rung** — everything the engine genuinely cannot do. Under this
///    opt-in Debug Setting a user who taps "Table" crashes with `R7-tables` in the message. That is
///    the intended behaviour (`+Unsupported.swift` has the full argument): a silent no-op leaves the
///    audience thinking the editor is broken in some unnameable way.
@available(iOS 18.4, *)
extension RichTextEngineEditorView {

    // MARK: 1 — answered for real

    /// Built from what the engine actually knows. Every field is either a genuine read or a constant
    /// that is TRUE OF ENGINE DOCUMENTS — not a placeholder:
    ///
    /// - the table trio and `selectionIsTextOnly` are REAL READS (R7-tables rung A). They were
    ///   constants, justified by "the bridge TRAPS on `Block.table`" — which stopped being true at
    ///   R7-nesting, turning four honest answers into four wrong ones with nothing in the type system
    ///   to say so. A constant justified by a trap outlives the trap: when a rung discharges one,
    ///   every constant that cited it is now a defect.
    /// - `canUndo`/`canRedo` are REAL READS (R10-undo). They were constants, justified by
    ///   "`undo()`/`redo()` trap below" — the same shape as the table trio above, and it expired the
    ///   same way: the pair GATES the two buttons, so the moment the verbs work, two constants that
    ///   were an accurate report of a missing capability become the thing hiding a present one.
    public func currentState() -> RichTextEditorView.EditorState {
        let traits = currentInlineTraits()
        let selection = engineSelectedRange
        let role = roleAtCaret()
        let table = tableAtCaret()
        return RichTextEditorView.EditorState(
            bold: traits.bold == .on,
            italic: traits.italic == .on,
            underline: traits.underline == .on,
            strikethrough: traits.strikethrough == .on,
            code: isInlineCodeActive(),
            spoiler: isSpoilerActive(),
            paragraphStyle: currentParagraphStyle(),
            isCodeBlock: role.map { if case .code = $0.shape { return true } else { return false } } ?? false,
            isPullQuote: role.map { if case .pullQuote = $0.shape { return true } else { return false } } ?? false,
            listMarker: listMarkerAtCaret(),
            link: currentLink(),
            hasSelection: selection.length > 0,
            isInTable: table != nil,
            isTableCompact: table?.shape.compact ?? false,
            isTableBordered: table?.shape.bordered ?? true,
            selectionIsTextOnly: selectionIsTextOnly(),
            canUndo: engineUndoManager.canUndo,
            canRedo: engineUndoManager.canRedo,
            // QUOTES, not containers: `containerDepth` counts either kind, so it reported 1 for a
            // caret inside a top-level details enclosed by no quote at all.
            blockQuoteDepth: role?.enclosingQuoteCount ?? 0)
    }

    /// Non-empty, no endpoint in a table cell, and no atom touched.
    ///
    /// Legacy's rule (`DocumentCanvasView+State.swift`) is "either endpoint inside a table, or the
    /// selection overlaps a media or table box". Extended here to the atoms legacy predates: a button
    /// row is text-free in exactly the way a media block is, and `atomUnitIndex(forRoleAt:) == index`
    /// is the module's existing test for "this role IS a text-free atom", answering for both.
    ///
    /// A standalone formula is NOT an atom for this purpose — it is a paragraph holding one
    /// attachment character, formatting applies to it, and legacy treats it as text.
    private func selectionIsTextOnly() -> Bool {
        let selection = engineSelectedRange
        guard selection.length > 0 else { return false }
        for index in touchedBlockIndices(for: selection) {
            if currentRoles[index].owningTable != nil { return false }
            if atomUnitIndex(forRoleAt: index) == index { return false }
        }
        return true
    }

    /// The role the caret sits in, or nil when the selection resolves to no single block.
    private func roleAtCaret() -> EngineBlockRole? {
        let touched = touchedBlockIndices(for: engineSelectedRange)
        guard let index = touched.first, index < currentRoles.count else { return nil }
        return currentRoles[index]
    }

    private func listMarkerAtCaret() -> ListMarker? {
        roleAtCaret()?.shape.paragraph?.list?.marker
    }

    /// Whether a table's horizontal scroll is IN FLIGHT — being dragged, or coasting from a drag.
    ///
    /// For a host that nests this editor inside something with a drag of its own. Telegram's
    /// attachment sheet dismisses on a downward pan, its recogniser recognises SIMULTANEOUSLY with
    /// every other pan, and it decides by walking up to the nearest vertical scroll view — so a
    /// finger put down to CATCH a coasting table started the sheet's dismiss instead (K3,
    /// 2026-09-11). A table's run is not in the touch's responder chain at all and cannot defend
    /// itself; the host declines its own gesture on the editor's behalf while this is true.
    public var hasTableScrollInFlight: Bool { engine.id_hasPlacedRunInFlight }

    public func moveCaretToDocumentEnd() {
        engine.selectedTextRange = engine.textRange(from: engine.endOfDocument,
                                                    to: engine.endOfDocument)
    }

    // MARK: 2 — stored for a later rung

    // CONSUMED BY: R9-formulas — DONE. A tap on a formula's transparent target hands the host the
    // latex and replaces the run on completion (`+Formulas.swift`).
    public var onEditFormulaRequested: ((String, @escaping (String) -> Void) -> Void)? {
        get { deferredConfiguration.onEditFormulaRequested }
        set { deferredConfiguration.onEditFormulaRequested = newValue }
    }

    // CONSUMED BY: R9-buttons — DONE. Both pill kinds route here; `isBlockPill` says which.
    public var onEditButtonRequested: ((ButtonRef, Bool, @escaping (ButtonRef?) -> Void) -> Void)? {
        get { deferredConfiguration.onEditButtonRequested }
        set { deferredConfiguration.onEditButtonRequested = newValue }
    }

    // CONSUMED BY: R9-buttons — DONE.
    public var onRequestButtonRowMenu: ((ButtonRowMenuRequest) -> Void)? {
        get { deferredConfiguration.onRequestButtonRowMenu }
        set {
            deferredConfiguration.onRequestButtonRowMenu = newValue
            // The control is not only DRAWN, it is RESERVED: a row showing one packs its pills into
            // 34pt less width. So a change here re-renders every live row's atom, or the rows that
            // already exist keep the previous reserve and their pills are the wrong width.
            guard bridge.showsButtonRowMenuAffordance != (newValue != nil) else { return }
            bridge.showsButtonRowMenuAffordance = (newValue != nil)
            rerenderButtonRowAtoms()
        }
    }

    // CONSUMED BY: R7 — the pill's hug, corner-mark inset, fill and radius come from here, the
    // horizontal padding measures the text inside it (through the bridge), and the top/bottom insets
    // are reserved around the block by `EngineBlockSpacing`.
    public var pullQuoteStyle: PullQuoteStyle {
        get { deferredConfiguration.pullQuoteStyle }
        set {
            guard deferredConfiguration.pullQuoteStyle != newValue else { return }
            deferredConfiguration.pullQuoteStyle = newValue
            applyPullQuoteStyle(newValue)
        }
    }

    // MARK: 3 — answered for real, and once was not
    //
    // Everything below TRAPPED under a rung name when this file was written. Nothing here does now,
    // which is why kind 3 in the header above is no longer a description of this section — kept as
    // a section because each member below carries the argument for why its trap could go, and those
    // arguments are what a reader of the next rung needs.

    /// Undo and redo for the article editor's toolbar pair, and for nothing else: the composer has
    /// no such control, and the SYSTEM affordances (⌘Z, shake, the edit menu's Undo) never come
    /// through here — they go straight to the engine's own responder, which already handles them.
    ///
    /// **The stack is the ENGINE's, not one of ours.** `engine.undoManager` is the private text-input
    /// controller's manager, i.e. the one UIKit itself records the typing into, and every command in
    /// this module already registers its inverse there (`restyleFlat`, `registerReplayRoleSnapshot`,
    /// `recordUndoStepForStructuralChange`, the list, table, media and button-row commands). So the
    /// verbs are a forward, and the whole of R10-undo was deciding that they could be.
    ///
    /// That is the opposite of legacy's answer, deliberately. `DocumentCanvasView` keeps a PRIVATE
    /// per-canvas manager precisely so that UIKit's own registrations cannot surface in `canUndo` —
    /// it had shipped the device-observed "undo is active on the first tap, before anything was
    /// typed", which was a SELECTION change recorded by the shared manager. The engine is not
    /// exposed to that: its manager belongs to the text-input controller for this view alone, and it
    /// records no caret move — asserted, not assumed, by
    /// `EngineUndoRedoHostTests.test_nothingIsUndoableBeforeAnEdit`, which is the negative control
    /// for this whole decision. Were it ever to go red, the answer is a manager of our own, and the
    /// cost is that every `registerUndo` in the module has to move onto it at the same instant.
    ///
    /// The two lines each do two things, in this order:
    ///
    /// 1. **Replay.** The engine's own change funnel and `engineDidFinishEdit` both stand down while
    ///    `isUndoing`/`isRedoing` — the replay adopts the role snapshot instead of settling — so
    ///    this is not an edit issued by a host command and must NOT be wrapped in one
    ///    (`performHostStructuralEdit` would settle on top of the replay it is restoring).
    /// 2. **Tell the host, from THIS stack, once the manager has settled.** The replay's own
    ///    notification is scheduled from inside `UndoManager.undo()`, where the group has not
    ///    finished popping — a host that re-reads `canUndo` from it sees the stack one step stale,
    ///    which for the LAST undo leaves the button enabled with nothing behind it. Legacy carries
    ///    the identical trailing refresh and the identical comment. `deliverChangeNotificationNow`
    ///    CONSUMES the scheduled delivery rather than landing beside it, so the host is still told
    ///    exactly once.
    ///
    /// **There is deliberately NO `unmarkText()` first, and legacy has one.** `canvas.finalizeMarkedText()`
    /// opens legacy's pair because a composition is not committed text and replaying around one
    /// would strand it — a real hazard, and one the engine closes itself: measured on a live
    /// composition over an earlier edit, the end state is IDENTICAL with the call and without it
    /// (`"alphaXか"` → `"alphaX"`, no marked range left either way), because the engine finalizes as
    /// part of the replay. Writing the call anyway costs nothing at runtime and costs a reader the
    /// belief that this verb is what closes the composition, so it is not written. The property a
    /// user depends on — undo never leaves you mid-composition — is pinned as a CHARACTERIZATION in
    /// `EngineUndoRedoHostTests`, which says in as many words that the engine supplies it: if that
    /// goes red the call comes back here.
    ///
    /// Unguarded on `canUndo`, like legacy: the buttons are gated on the pair above, so an empty
    /// stack is unreachable from the UI, and the no-op notification a stray call produces is
    /// harmless.
    public func undo() {
        endTypingRun()
        engineUndoManager.undo()
    }

    public func redo() {
        endTypingRun()
        engineUndoManager.redo()
    }


    /// An empty grid where the caret is: an empty paragraph is replaced (as legacy does), anything
    /// else gets the table after it. Caret in the first cell; one undo step.
    ///
    /// Placed wherever the caret is, at any depth — a table asked for inside a quote becomes a CHILD
    /// of that quote. The anchor is the caret's LEAF container: a paragraph's own id, a code block's,
    /// a media unit's, the table's for a caret in a cell (so the new grid lands beside that table,
    /// never inside it), and the quote's own id for its author line.
    ///
    /// The anchor is resolved against the whole tree. Looked up in the TOP-LEVEL list, as it was, a
    /// caret inside a quote matched nothing, the lookup fell back to `blocks.count`, and the table
    /// was appended at the END of the document — the user saw it arrive beside the quote instead of
    /// in it (device, K3 2026-09-08).
    public func insertTable(rows: Int, cols: Int) {
        let before = document
        let selection = engineSelectedRange
        let table = TableBlock.empty(rows: max(rows, 1), columns: max(cols, 1))
        let anchor = roleIndex(atFlatOffset: selection.location).map { currentRoles[$0].containerID }
        if let anchor, before.blocksByID[anchor]?.asParagraph?.runs.isEmpty == true {
            document = before.replacingBlock(withID: anchor, with: .table(table))
        } else if let anchor {
            document = before.insertingBlock(.table(table), after: anchor)
        } else {
            var updated = before
            updated.blocks.append(.table(table))
            document = updated
        }
        if let first = currentRoles.firstIndex(where: { $0.containerID == table.id }) {
            engineSelectedRange = NSRange(location: flatOffset(ofRoleAt: first), length: 0)
        }
        recordUndoStepForStructuralChange(restoring: before, selection: selection)
        deliverChangeNotificationNow()
    }
    // `deleteTable()` is answered for real, in `+TableCommands.swift`.
    // `copyCurrentTable()` is answered for real, in `+TableCommands.swift`.
    // `convertCurrentTableToText()` is answered for real, in `+TableCommands.swift`.
    // `toggleTableBordered()` and `toggleTableCompact()` are answered for real, in
    // `+TableCommands.swift`, as a rewrite of the shape every cell role carries.

    // `insertMedia(mediaID:naturalSize:kind:caption:)` and `insertDocument(_:)` are answered for
    // real, in `+MediaCommands.swift`.

    // `insertFormula(latex:)` is answered for real, in `+Formulas.swift`.
    // `insertButtonRow()` is answered for real, in `+ButtonRows.swift`.
    // `makeSelectionInlineButton()` is answered for real, in `+InlineButtons.swift`.

    // `unwrapBlockQuoteLevel()` is answered for real, in `+Containers.swift`, and
    // `insertDetailsBlock()` in `+Details.swift`.

    // `insertEmoji(id:altText:)` is answered for real, in `+CustomEmoji.swift`, beside the hosting
    // pass it has to agree with.

    /// The selection as positions on Core's global axis, or `nil` when the selection is collapsed.
    ///
    /// Both of these used to TRAP at rung `R7-paste`, and the premise was wrong: the axis is not
    /// legacy's, it is `RichTextEditorCore`'s, and it is a pure function of a `Document` the engine
    /// owns. `+GlobalPositions.swift` carries the mapping and the reasoning; the crash the trap
    /// produced was tapping the AI button in the article editor.
    ///
    /// `nil` still means EXACTLY "nothing is selected" — the one answer the trap existed to avoid
    /// giving wrongly — so an endpoint that cannot be expressed is not quietly folded into it: a
    /// role holding no text answers its block's span instead, and only an offset past the document
    /// end has no answer, which is a collapsed selection's neighbour rather than a live one.
    public func selectedGlobalRange() -> (from: Int, to: Int)? {
        let selection = engineSelectedRange
        guard selection.length > 0 else { return nil }
        guard let from = globalPosition(atFlatOffset: selection.location, preferring: .start),
              let to = globalPosition(atFlatOffset: selection.location + selection.length, preferring: .end)
        else { return nil }
        return (Swift.min(from, to), Swift.max(from, to))
    }

    /// Replaces the global range `[from, to)` with `fragment`'s blocks, caret at the end of the
    /// inserted content. An empty `fragment` deletes the range.
    ///
    /// The whole edit is `Document.replacingRange`, which is the function that DEFINES this axis —
    /// so no boundary rule is re-derived here, and the caret it returns is on the same axis. Like
    /// `insertTable` this rebuilds through the document setter and therefore clears the undo
    /// history (`recordUndoStepForStructuralChange`): the setter's edit is swallowed by
    /// `isApplyingHostDocument`, so settle never runs and there is no replay snapshot to pop.
    public func replaceRange(from: Int, to: Int, with fragment: Document) {
        let before = document
        let selection = engineSelectedRange
        applyReplacingRange(in: before, from: from, to: to, with: fragment)
        recordUndoStepForStructuralChange(restoring: before, selection: selection)
        deliverChangeNotificationNow()
    }

    /// The body of `replaceRange`: `base` with `[from, to)` replaced by `fragment` becomes the live
    /// document, the caret placed by the rule below. Records NO undo step and tells the host
    /// NOTHING — the caller owns both. Split out for the markdown paste (`+Clipboard.swift`), which
    /// applies two replacements over the SAME pre-paste range as two undo steps and one delivery.
    internal func applyReplacingRange(in base: Document, from: Int, to: Int, with fragment: Document) {
        let (updated, caret) = Self.replacingRangePlacingCaret(in: base, from: from, to: to, with: fragment)
        document = updated
        if let flat = flatOffset(atGlobalPosition: caret) {
            engineSelectedRange = NSRange(location: flat, length: 0)
        }
    }

    /// The pure half of `applyReplacingRange`: the document and the global caret, with the caret rule
    /// below applied. A local drag-and-drop move composes two of these into one step
    /// (`+DragAndDrop.swift`).
    internal static func replacingRangePlacingCaret(in base: Document, from: Int, to: Int,
                                                    with fragment: Document) -> (document: Document, caret: Int) {
        var (updated, caret, lastInserted) =
            base.replacingRangeReportingInsertion(globalFrom: from, globalTo: to, with: fragment)

        // **The caret goes AFTER everything inserted, and if there is nowhere after it to stand the
        // document grows a line.**
        //
        // `replacingRange`'s own caret is `globalTextStart(ofBlockAt: last) + lastLen`, and `lastLen`
        // is 0 for every block with no trailing text — a table, a medium, a button row, a quote, a
        // details. That is a STRUCTURAL position INSIDE the block rather than after it, so the
        // nearest-text scan below resolved it BACKWARDS into the preceding paragraph: pasting a
        // fragment ending in a table left the caret at the end of the paragraph above it (measured).
        //
        // `lastInsertedBlockIndex` is nil when the fragment folded wholly into existing text, where
        // the caret is already mid-text and correct.
        if let last = lastInserted, last < updated.blocks.count,
           !Self.blockEndsInEditableTrailingText(updated.blocks[last]) {
            if last == updated.blocks.count - 1 {
                // Nothing follows it, so there is no caret position after it at all until one exists.
                updated.blocks.append(.paragraph(ParagraphBlock(id: .generate(), runs: [])))
                caret = updated.globalTextStart(ofBlockAt: updated.blocks.count - 1)
            } else {
                caret = updated.globalTextStart(ofBlockAt: last + 1)
            }
        }
        return (updated, caret)
    }

    /// Whether a caret can rest at the END of this block's own text — "body or header", the two
    /// kinds a user can simply carry on typing in.
    ///
    /// Exhaustive over `ParagraphStyleName` with no `default`, so a new style has to decide. Note
    /// there is no `.quote` case: a quote is a CONTAINER block, so it is already on the other side
    /// of this test along with every other non-paragraph kind. A LIST item is an ordinary body
    /// paragraph and stays on the typing side — pasting a list ends with the caret in its last item,
    /// where Return continues the list.
    private static func blockEndsInEditableTrailingText(_ block: Block) -> Bool {
        guard case let .paragraph(paragraph) = block else { return false }
        switch paragraph.style {
        case .body, .heading1, .heading2, .heading3, .heading4, .heading5, .heading6:
            return true
        case .caption, .pullQuote:
            // Render-only styles; neither is a place to carry on typing after.
            return false
        }
    }
}
#endif
