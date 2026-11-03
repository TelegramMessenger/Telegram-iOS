#if canImport(UIKit)
import UIKit
import RichTextInputDecHost
import RichTextInputDecUpstream

/// Inline formatting (R3). The engine owns a native trait model
/// (`IDInlineTextTraits` / `IDInlineTextTraitState`, `include/IDInlineTextFormatting.h`) — Telegram's
/// job here is to name the traits and forward, never to reimplement toggling or state tracking of
/// its own. `currentInlineTraits()` in particular must read back `stateForInlineTextTrait:` and
/// report exactly that: the engine's own answer, not a re-derivation from attributed-string
/// attributes or from `Document`.
///
/// The engine's own state is TRI-state (`off`/`on`/`mixed` — a selection can genuinely span both
/// bold and non-bold text). `InlineTraitState` below mirrors those three cases and no more. Do NOT
/// collapse this to `Bool` here: Telegram's public `EditorState.bold` is a `Bool` and will have to
/// collapse the `mixed` case somewhere, but that collapse is Task 9's decision to make deliberately
/// at the public boundary — not something to bake in three layers down where it becomes silent and
/// untestable in isolation. Whoever implements `currentState()` at that boundary owns choosing (and
/// testing) what `mixed` maps to.
public enum InlineTraitState: Equatable {
    case off
    case on
    case mixed
}

private extension IDInlineTextTraitState {
    /// Mirrors the engine's own three cases verbatim — must not invent a fourth. A case the switch
    /// does not know about is a genuine invariant violation (the engine's enum grew a value this
    /// mirror has not been updated for), not a plausible-default situation to paper over.
    var asInlineTraitState: InlineTraitState {
        switch self {
        case .off: return .off
        case .on: return .on
        case .mixed: return .mixed
        @unknown default:
            preconditionFailure("IDInlineTextTraitState gained a case InlineTraitState does not mirror.")
        }
    }
}

/// The four inline traits a toolbar shows, answered together. They are read together and cached
/// together because the probe that computes them across a structural selection is one pass over the
/// selected cells, not four.
@available(iOS 18.4, *)
internal struct InlineTraitQuartet {
    internal let bold: InlineTraitState
    internal let italic: InlineTraitState
    internal let underline: InlineTraitState
    internal let strikethrough: InlineTraitState
}

@available(iOS 18.4, *)
extension RichTextEngineEditorView {
    /// `deliveringChangeNotification` wraps — never replaces — the forward: the engine performs the
    /// toggle exactly as it would unwrapped, and the wrapper only delivers, from THIS stack, the
    /// `onChange` the engine's change funnel already marked as owed. Without it the notification
    /// would either fire from inside `-[IDCanonicalTextStorageAdapter processEditing]` (running the
    /// consumer's layout pass inside the text storage's own edit processing) or arrive a runloop
    /// turn late. See `RichTextEngineEditorView.isChangeNotificationPending`.
    public func toggleBold() {
        if applyTraitAcrossStructuralSelection(.bold) { return }
        deliveringChangeNotification { recordingInlineFormatStep { toggleInlineTraitKeepingAtomsDerived(.bold) } }
    }

    public func toggleItalic() {
        if applyTraitAcrossStructuralSelection(.italic) { return }
        deliveringChangeNotification { recordingInlineFormatStep { toggleInlineTraitKeepingAtomsDerived(.italic) } }
    }

    public func toggleUnderline() {
        if applyTraitAcrossStructuralSelection(.underline) { return }
        deliveringChangeNotification { recordingInlineFormatStep { toggleInlineTraitKeepingAtomsDerived(.underline) } }
    }

    public func toggleStrikethrough() {
        if applyTraitAcrossStructuralSelection(.strikethrough) { return }
        deliveringChangeNotification { recordingInlineFormatStep { toggleInlineTraitKeepingAtomsDerived(.strikethrough) } }
    }

    /// The chat's ⇧⌘N: the selection loses every inline mark a toggle sets, as ONE step, and no
    /// block changes. Built from the same primitives the toggles use — there is no "set" for the
    /// engine's traits, but a toggle takes `mixed` to `on` (measured, see below), so at most two
    /// toggles reach `off`; inline code and spoiler are SETs already. Across a table's structural
    /// selection each covered cell is cleared in turn, under one step. A collapsed caret changes
    /// nothing, as the legacy composer's shortcut does not.
    public func clearInlineFormatting() {
        let structuralRanges = inlineFormatTargetRanges()
        let restore = engineSelectedRange
        let ranges = structuralRanges ?? (restore.length > 0 ? [restore] : [])
        guard !ranges.isEmpty else { return }
        let selection = tableStructuralSelection
        if structuralRanges != nil { isParkingCaretForStructuralSelection = true }
        defer {
            if structuralRanges != nil {
                engineSelectedRange = restore
                isParkingCaretForStructuralSelection = false
                tableStructuralSelection = selection
                setNeedsLayout()
            }
        }
        deliveringOneChangeNotification {
            recordingInlineFormatStep(selection: restore) {
                for range in ranges {
                    if structuralRanges != nil { engineSelectedRange = range }
                    for trait in [IDInlineTextTraits.bold, .italic, .underline, .strikethrough] {
                        var toggles = 0
                        while engine.state(forInlineTextTrait: trait) != .off, toggles < 2 {
                            toggleInlineTraitKeepingAtomsDerived(trait)
                            toggles += 1
                        }
                    }
                    applyInlineCode(enabling: false)
                    applySpoiler(enabling: false)
                }
            }
        }
    }

    /// The engine's toggle, followed by the re-derivation of every ATTACHMENT ATOM it touched.
    ///
    /// **A face or decoration toggle is skipped over an atom.** The engine's toggle writes the
    /// face (and the base-font key) and the decoration over the whole selection, atoms included —
    /// but an inline formula, an inline button, a custom emoji, a media atom and a button row carry
    /// no bold / italic / underline / strikethrough in the model (the read-back of an attachment
    /// character keeps only what the atom itself is, `AttributedStringMapper.characterAttributes`),
    /// so what the toggle drew there was presentation the role's derivation never gives: the
    /// verifier's drift, a DEBUG trap reachable by Select All ▸ Bold over an edited message with a
    /// photo, and a face the next IME commit inherited (composer harness p13,
    /// `HarnessAtomInlineFormatDriftTests`). Text around the atoms keeps the toggle.
    internal func toggleInlineTraitKeepingAtomsDerived(_ trait: IDInlineTextTraits) {
        engine.toggleInlineTextTrait(trait)
        rederiveAtomPresentation(touching: engineSelectedRange)
    }

    /// Brings every cell of a table's structural selection to ONE value of `trait`, built from the
    /// only two primitives the engine offers.
    ///
    /// There is no SET: `IDBlockTextView` exposes `toggleInlineTextTrait:` and
    /// `stateForInlineTextTrait:` and nothing else, and `RichTextInputDecUpstream/` is read-only. So
    /// the target is decided first — `.off` only when EVERY cell reports `.on`, legacy's rule — and
    /// each differing cell is toggled ONCE.
    ///
    /// **MEASURED 2026-09-10: a toggle takes a `mixed` selection to `.on`.** That is what makes one
    /// toggle always enough. For target `.on` a differing cell is `.off` or `.mixed`, and both reach
    /// `.on` in one. For target `.off` every cell was `.on` by the target rule's own definition, so a
    /// mixed cell cannot occur there at all — the two-toggle case is unreachable BY CONSTRUCTION, not
    /// by luck, which is why this is not a toggle-until-it-matches loop against an opaque engine.
    ///
    /// Returns false having done nothing when `inlineFormatTargetRanges()` answers nil: no structural
    /// selection, and no code-block language line in the selection.
    private func applyTraitAcrossStructuralSelection(_ trait: IDInlineTextTraits) -> Bool {
        // The cells of a structural selection, or the selection with any code-block language line
        // taken out (`inlineFormatTargetRanges`); nil is the ordinary path.
        guard let ranges = inlineFormatTargetRanges(excludingPullQuoteBodies: trait == .italic) else { return false }
        guard !ranges.isEmpty else { return true }
        let restore = engineSelectedRange
        let selection = tableStructuralSelection
        isParkingCaretForStructuralSelection = true
        defer {
            engineSelectedRange = restore
            isParkingCaretForStructuralSelection = false
            tableStructuralSelection = selection
            setNeedsLayout()
        }
        let states = ranges.map { range -> InlineTraitState in
            engineSelectedRange = range
            return engine.state(forInlineTextTrait: trait).asInlineTraitState
        }
        let target: InlineTraitState = states.allSatisfy { $0 == .on } ? .off : .on
        deliveringOneChangeNotification {
            recordingInlineFormatStep(selection: restore) {
                for (range, state) in zip(ranges, states) where state != target {
                    engineSelectedRange = range
                    toggleInlineTraitKeepingAtomsDerived(trait)
                }
            }
        }
        return true
    }

    /// The trait states ACROSS a structural selection: on when every cell is, off when none is, mixed
    /// otherwise, for all four traits at once. Nil when there is no structural selection.
    ///
    /// The engine answers a trait for its CURRENT selection and has no range-taking variant, so the
    /// only way to ask about a cell is to park the selection in it. That is a query with a very large
    /// side effect — `setSelectedTextRange:` runs UIKit's whole selection-change coordination — and it
    /// was costing this three ways until 2026-09-11, all of which this one function fixes:
    ///
    /// 1. Each parked range fired the selection funnel, which SCHEDULES a selection-driven `onChange`.
    ///    The article host answers that by re-running its component update, which asks for
    ///    `currentState()`, which lands back here: a self-sustaining loop at run-loop cadence for as
    ///    long as a structural selection existed. Scrolling a table then fought the loop for the main
    ///    thread and the run visibly dropped frames — the symptom as reported. `isProbingInlineTraits`
    ///    makes the probe invisible to the funnel, which is honest: the selection is restored before
    ///    anything can observe it.
    /// 2. It ran once PER TRAIT, so a four-trait toolbar query parked the selection 4×(cells+1) times.
    ///    One pass reads all four per cell.
    /// 3. It ran on every host update. The answer can only change when the document or the structural
    ///    selection changes, so it is cached against both.
    private func structuralTraitStates() -> InlineTraitQuartet? {
        if let cached = cachedStructuralTraits { return cached }
        let ranges = structuralSelectionCellRanges()
        guard !ranges.isEmpty else { return nil }
        let restore = engineSelectedRange
        isParkingCaretForStructuralSelection = true
        isProbingInlineTraits = true
        defer {
            engineSelectedRange = restore
            isProbingInlineTraits = false
            isParkingCaretForStructuralSelection = false
        }
        let traits: [IDInlineTextTraits] = [.bold, .italic, .underline, .strikethrough]
        var perTrait: [[InlineTraitState]] = Array(repeating: [], count: traits.count)
        for range in ranges {
            engineSelectedRange = range
            for (index, trait) in traits.enumerated() {
                perTrait[index].append(engine.state(forInlineTextTrait: trait).asInlineTraitState)
            }
        }
        func combined(_ states: [InlineTraitState]) -> InlineTraitState {
            if states.allSatisfy({ $0 == .on }) { return .on }
            if states.allSatisfy({ $0 == .off }) { return .off }
            return .mixed
        }
        let quartet = InlineTraitQuartet(bold: combined(perTrait[0]), italic: combined(perTrait[1]),
                                         underline: combined(perTrait[2]),
                                         strikethrough: combined(perTrait[3]))
        cachedStructuralTraits = quartet
        return quartet
    }

    /// R3 gate: agrees with the engine's own `stateForInlineTextTrait:` — including the `mixed`
    /// case a selection spanning both bold and non-bold text genuinely reports. See
    /// `InlineTraitState`'s doc comment for why this is not collapsed to `Bool` here.
    public func currentInlineTraits() -> (bold: InlineTraitState, italic: InlineTraitState,
                                          underline: InlineTraitState, strikethrough: InlineTraitState) {
        // With a table's structural selection live, the toolbar must describe the SELECTION and not
        // the single cell the caret is parked in.
        if let structural = structuralTraitStates() {
            return (structural.bold, structural.italic, structural.underline, structural.strikethrough)
        }
        return (
            bold: engine.state(forInlineTextTrait: .bold).asInlineTraitState,
            italic: engine.state(forInlineTextTrait: .italic).asInlineTraitState,
            underline: engine.state(forInlineTextTrait: .underline).asInlineTraitState,
            strikethrough: engine.state(forInlineTextTrait: .strikethrough).asInlineTraitState
        )
    }

    /// Whether `toggleItalic()` would reach any text: nil from `inlineFormatTargetRanges` is the
    /// ordinary path (it does), an empty array is a selection wholly inside pull-quote bodies or
    /// language lines, where italic is a no-op (`inlineFormatTargetRanges(excludingPullQuoteBodies:)`).
    public var italicReachesSelection: Bool {
        guard let ranges = inlineFormatTargetRanges(excludingPullQuoteBodies: true) else { return true }
        return !ranges.isEmpty
    }

    /// Whether Bold, Underline, Strikethrough, Monospace, Spoiler or a link would reach any text: false
    /// for a selection lying wholly in code — a code block's body or its language line — where every
    /// inline format is refused (`inlineFormatTargetRanges`, composer harness p20).
    public var inlineFormatsReachSelection: Bool {
        guard let ranges = inlineFormatTargetRanges() else { return true }
        return !ranges.isEmpty
    }

    // `toggleInlineCode()` CLIMBED at R9-inline — see `+InlineCode.swift`.

    // `toggleSpoiler()` CLIMBED at R9-inline — see `+Spoiler.swift`.
}
#endif
