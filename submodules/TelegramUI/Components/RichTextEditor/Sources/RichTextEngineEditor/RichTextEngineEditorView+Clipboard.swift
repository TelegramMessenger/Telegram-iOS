#if canImport(UIKit)
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit

/// **Copy and paste carry a `Document`, not a string.**
///
/// The engine writes exactly one representation — `public.utf8-plain-text` — so every block
/// structure is ABSENT from a copy rather than degraded. Measured before this existed: a document of
/// `paragraph / table / paragraph` copied as `"before\n\n\n\n\nafter"`, the five newlines being the
/// table's four empty cells. Reported as "tables are not preserved when copying/pasting"; it was
/// every structure, not only tables.
///
/// The legacy editor has carried the answer since Phase 5d and it is deliberately reused whole:
/// `RichTextEditorClipboard.pasteboardItem(for:)` writes the private fragment UTI (a JSON
/// `Document`, lossless within the app), `public.rtf` (cross-app) and plain text. Reusing it is what
/// makes a fragment copied in one editor paste into the other — the format has one definition, and
/// that file's own comment says the two callers must not drift.
///
/// **What makes this small is the global position axis** (`+GlobalPositions.swift`): copy is
/// `selectedGlobalRange()` + `Document.extractFragment`, paste is `Document.replacingRange`. Those
/// are the same two functions the AI-compose flow uses, so there is no clipboard-specific range
/// logic here at all — and no second definition of what "the selected sub-document" means.
/// **What a paste reads, whether it came from the clipboard or from a drop.**
///
/// Every paste handler below used to read `UIPasteboard.general` itself, so a DROP could only have
/// reused them by writing the dropped content to the user's clipboard first — which a drop must never
/// do. The handlers now read a source, and the two producers are the general pasteboard (`paste:`)
/// and a drop session's loaded items (`+DragAndDrop.swift`).
///
/// The pasteboard's CONTENTS are read lazily, only by the handler that needs them: the `has…` flags
/// are type tests, which raise no paste prompt, and a paste that the partial-table refusal consumes
/// never reads the clipboard at all — the same reads, in the same order, as before this existed.
internal struct EnginePasteSource {
    /// The editor's own lossless representation is present (`RichTextEditorClipboard.fragmentUTI`).
    let hasFragment: Bool
    /// A plain-text representation is present.
    let hasString: Bool
    /// An RTF / RTFD representation is present — which is what keeps markdown-on-paste off it
    /// (legacy's order: RTF is the richer reading of the same text).
    let hasRichText: Bool
    let fragmentData: () -> Data?
    let string: () -> String?
    /// The editor's own exact one-line text of what was copied (`RichTextEditorClipboard.oneLineFieldTextUTI`),
    /// or nil.
    var oneLineFieldText: () -> String? = { nil }
    /// The editor's own copy as the text its range covered (`RichTextEditorClipboard.coveredTextFragmentUTI`,
    /// encoded), or nil — what a runs-only destination pastes.
    var coveredTextFragmentData: () -> Data? = { nil }

    /// Whether any text representation at all is present — what the partial-table refusal and the
    /// cross-block delete ask.
    var hasText: Bool { hasString || hasRichText || hasFragment }

    /// The general pasteboard, read on demand.
    static var generalPasteboard: EnginePasteSource {
        let pasteboard = UIPasteboard.general
        return EnginePasteSource(
            hasFragment: pasteboard.contains(pasteboardTypes: [RichTextEditorClipboard.fragmentUTI]),
            hasString: pasteboard.hasStrings,
            hasRichText: pasteboard.contains(pasteboardTypes: ["public.rtf", "com.apple.flat-rtfd"]),
            fragmentData: { UIPasteboard.general.data(forPasteboardType: RichTextEditorClipboard.fragmentUTI) },
            string: { UIPasteboard.general.string.map(EnginePasteSource.normalisingLineEndings) },
            oneLineFieldText: {
                UIPasteboard.general.data(forPasteboardType: RichTextEditorClipboard.oneLineFieldTextUTI)
                    .flatMap { String(data: $0, encoding: .utf8) }
            },
            coveredTextFragmentData: {
                UIPasteboard.general.data(forPasteboardType: RichTextEditorClipboard.coveredTextFragmentUTI)
            })
    }

    /// Content already in hand — a drop's loaded items, or a test's.
    static func loaded(fragmentData: Data?, string: String?, hasRichText: Bool = false,
                       oneLineFieldText: String? = nil, coveredTextFragmentData: Data? = nil) -> EnginePasteSource {
        let normalised = string.map(EnginePasteSource.normalisingLineEndings)
        return EnginePasteSource(hasFragment: fragmentData != nil,
                                 hasString: string != nil,
                                 hasRichText: hasRichText,
                                 fragmentData: { fragmentData },
                                 string: { normalised },
                                 oneLineFieldText: { oneLineFieldText },
                                 coveredTextFragmentData: { coveredTextFragmentData })
    }

    /// CR LF, a lone CR, `U+2029` and NEL as the one paragraph break the model has, `"\n"` — Core
    /// `normalisedLineBreaks`, the ONE normaliser every door uses (the set's render too). A `U+000D` kept in
    /// the text reached the model and was sent (composer harness p20, `HarnessPastedCarriageReturnTests`); a
    /// `U+2029` broke the tokenizer (p24, `HarnessSetCarriageReturnTests`). The engine's OWN paste is
    /// normalised in the host view (`textPasteConfigurationSupporting:combineItemAttributedStrings:`).
    static func normalisingLineEndings(_ text: String) -> String {
        normalisedLineBreaks(text)
    }

    /// A fragment in hand, with the plain text a one-line field takes from it.
    static func fragment(_ document: Document, oneLineFieldText: String? = nil,
                         coveredText: Document? = nil) -> EnginePasteSource {
        let data = try? DocumentCodec.encode(document)
        return .loaded(fragmentData: data, string: externalChecklistPlainText(document.blocks),
                       oneLineFieldText: oneLineFieldText,
                       coveredTextFragmentData: coveredText.flatMap { try? DocumentCodec.encode($0) })
    }
}

@available(iOS 18.4, *)
extension RichTextEngineEditorView {

    /// What the clipboard verbs take a non-empty selection to hold: the fragment Copy writes (and a
    /// drag lifts), and the flat range Cut deletes (and a move takes away).
    ///
    /// **The two are decided together, so they cannot disagree** (composer harness p19). Copy used to
    /// widen the range over any medium or table it touched while Cut's deletion went through the gate
    /// over the range as selected, which keeps a partly covered medium's atom: a Cut entering a caption
    /// from above put the whole photo on the clipboard AND left it in the composer, so the next Paste
    /// showed two (`HarnessCutIntoCaptionMediaDuplicationTests`). Now:
    ///
    /// - a range inside ONE caption or ONE table cell is that text region's: its covered text is the
    ///   fragment and the selection is the deletion (`captionTextFragment`, `tableCellFragment`);
    /// - any other range widens over every unit it enters in part — a medium with its caption, a
    ///   table, a button row, a folded quote (`flatRangeExpandedOverUnits`) — and that ONE widened range
    ///   is both what is extracted and what is deleted. An endpoint on a unit's edge is on that edge,
    ///   not across the unit (`unitAwareGlobalPosition`).
    ///
    /// When nothing extracts (a one-line field), the fragment is empty and the deletion is the
    /// selection: the engine's plain copy takes over. A selection covering a table only in part keeps
    /// the selection as its deletion too, so the gate's refusal still applies to it.
    internal func clipboardSelection() -> (fragment: Document, deletion: NSRange)? {
        return clipboardSelectionWithCoveredText().map { ($0.fragment, $0.deletion) }
    }

    /// `clipboardSelection()` with the same range's covered TEXT (`Document.extractFragmentAsCoveredText`):
    /// what a runs-only destination pastes from this copy (`RichTextEditorClipboard.coveredTextFragmentUTI`).
    internal func clipboardSelectionWithCoveredText() -> (fragment: Document, coveredText: Document, deletion: NSRange)? {
        let selection = engineSelectedRange
        guard selection.length > 0, let range = selectedGlobalRange() else { return nil }
        let document = self.document
        let lo = Swift.min(range.from, range.to), hi = Swift.max(range.from, range.to)
        if let region = document.captionTextFragment(globalFrom: lo, globalTo: hi)
            ?? document.tableCellFragment(globalFrom: lo, globalTo: hi) {
            return (region, region, selection)
        }
        let widened = flatRangeExpandedOverUnits(selection)
        guard let from = unitAwareGlobalPosition(atFlatOffset: widened.location, preferring: .start),
              let to = unitAwareGlobalPosition(atFlatOffset: NSMaxRange(widened), preferring: .end),
              from < to else { return (Document(blocks: []), Document(blocks: []), selection) }
        let fragment = document.extractFragment(globalFrom: from, globalTo: to, carryingNonTextBlocks: true)
        let coveredText = document.extractFragmentAsCoveredText(globalFrom: from, globalTo: to, carryingNonTextBlocks: true)
        // A selection covering a table only in part is one typing REFUSES, and so do Cut (the gate
        // refuses its deletion: Cut is a Copy there) and a move of it (`dropIsAcceptable`). Widened, the
        // refusal would no longer see the table in part, so the deletion stays the selection.
        if fragment.blocks.isEmpty || rangeCoversATableOnlyInPart(selection) {
            return (fragment, coveredText, selection)
        }
        return (fragment, coveredText, widened)
    }

    /// The flat span of the UNIT the role at `index` belongs to — a medium with its caption, a table's
    /// cells, a button row, a folded quote — and the unit's block id; nil for a role in no unit.
    private func unitFlatSpan(ofRoleAt index: Int) -> (span: NSRange, id: BlockID)? {
        guard index >= 0, index < currentRoles.count else { return nil }
        let role = currentRoles[index]
        switch role.container {
        case .table:
            break
        case let .block(shape):
            switch shape {
            case .media, .buttonRow, .collapsedQuote: break
            case .paragraph, .code, .pullQuote: return nil
            }
        case .blockQuote, .details:
            return nil
        }
        let id = role.containerID
        var first = index, last = index
        while first > 0, currentRoles[first - 1].containerID == id { first -= 1 }
        while last + 1 < currentRoles.count, currentRoles[last + 1].containerID == id { last += 1 }
        let start = flatOffset(ofRoleAt: first)
        let end = flatOffset(ofRoleAt: last) + flatLength(ofRoleAt: last)
        return (NSRange(location: start, length: end - start), id)
    }

    /// `range` with each endpoint that lies strictly INSIDE a unit moved to that unit's edge — the
    /// engine-axis form of `Document.expandingRangeOverNonTextBlocks`, for the range Cut deletes — and
    /// then widened over every container the gate would drop WHOLE (`widenedOverDroppedContainers`).
    internal func flatRangeExpandedOverUnits(_ range: NSRange) -> NSRange {
        return widenedOverDroppedContainers(flatRangeSnappedToUnits(range))
    }

    /// The gate drops a container whose primary blocks the range covers wholly — code, pull quote,
    /// block quote, details — "second lines included": its author or language line goes too, even
    /// where the range stops short of it (`replaceAcrossBlocks`, `containerIsCovered`). A copy that
    /// stopped where the range does carried an EMPTY author, so Cut + Paste of a quote's body lost the
    /// author and a move lost it for good (composer harness p19 fix wave, fuzz seed 27,
    /// `HarnessQuoteAuthorCutMoveTests`). So the range takes those lines too, and the copy carries
    /// them. Only a range across blocks: inside one block the gate drops nothing.
    private func widenedOverDroppedContainers(_ range: NSRange) -> NSRange {
        guard range.length > 0, let first = roleIndex(atFlatOffset: range.location),
              let last = roleIndex(atFlatOffset: NSMaxRange(range)), first != last else { return range }
        let headKept = range.location - flatOffset(ofRoleAt: first)
        let tailKept = flatOffset(ofRoleAt: last) + flatLength(ofRoleAt: last) - NSMaxRange(range)
        var lo = range.location, hi = NSMaxRange(range)
        var seen: Set<BlockID> = []
        func consider(_ span: ClosedRange<Int>) {
            guard containerIsCovered(span, first: first, last: last, headKept: headKept, tailKept: tailKept) else { return }
            lo = Swift.min(lo, flatOffset(ofRoleAt: span.lowerBound))
            hi = Swift.max(hi, flatOffset(ofRoleAt: span.upperBound) + flatLength(ofRoleAt: span.upperBound))
        }
        for index in first ... last {
            let role = currentRoles[index]
            switch role.container {
            case .block(.code), .block(.pullQuote), .blockQuote:
                if seen.insert(role.containerID).inserted { consider(containerSpan(containing: index)) }
            case .block, .details, .table:
                break
            }
            for ancestor in role.ancestry where seen.insert(ancestor.id).inserted {
                consider(span(of: ancestor.id, around: index))
            }
        }
        return NSRange(location: lo, length: hi - lo)
    }

    private func flatRangeSnappedToUnits(_ range: NSRange) -> NSRange {
        var lo = range.location, hi = NSMaxRange(range)
        if let index = roleIndex(atFlatOffset: lo), let unit = unitFlatSpan(ofRoleAt: index),
           lo > unit.span.location, lo < NSMaxRange(unit.span) {
            lo = unit.span.location
        }
        if let index = roleIndex(atFlatOffset: hi), let unit = unitFlatSpan(ofRoleAt: index),
           hi > unit.span.location, hi < NSMaxRange(unit.span) {
            hi = NSMaxRange(unit.span)
        }
        return NSRange(location: lo, length: hi - lo)
    }

    /// `globalPosition(atFlatOffset:preferring:)`, except that an offset on a unit's EDGE is the unit
    /// block's edge on the global axis: a range starting right after an atom does not hold the atom,
    /// and one ending at a caption's end holds the whole medium. The plain mapping answers a text-less
    /// role's START for either of its offsets, so a selection beginning just after an audio atom
    /// copied the audio.
    private func unitAwareGlobalPosition(atFlatOffset offset: Int, preferring side: BlockSpanSide) -> Int? {
        if let index = roleIndex(atFlatOffset: offset), let unit = unitFlatSpan(ofRoleAt: index),
           offset == unit.span.location || offset == NSMaxRange(unit.span),
           let span = PositionResolver.blockSpan(ofBlockWithID: unit.id, in: DocumentTree.build(from: document)) {
            return offset == unit.span.location ? span.start : span.end
        }
        return globalPosition(atFlatOffset: offset, preferring: side)
    }

    /// Writes the selection as a `Document` fragment (`clipboardSelection()`). `false` — nothing
    /// selected, or nothing extractable — leaves the pasteboard untouched and lets the engine's plain
    /// copy proceed.
    internal func writeSelectionToPasteboard() -> Bool {
        guard let selection = clipboardSelectionWithCoveredText(), !selection.fragment.blocks.isEmpty else { return false }
        var item = RichTextEditorClipboard.pasteboardItem(for: selection.fragment)
        item[RichTextEditorClipboard.oneLineFieldTextUTI] = Data(oneLineFieldText(ofFlatRange: selection.deletion).utf8)
        if let covered = try? DocumentCodec.encode(selection.coveredText) {
            item[RichTextEditorClipboard.coveredTextFragmentUTI] = covered
        }
        UIPasteboard.general.items = [item]
        return true
    }

    /// The text a ONE-LINE field takes from what the clipboard verbs took over `range` — exactly the
    /// characters a Cut of it deletes (`clipboardSelection().deletion`), every line of the range on the
    /// engine's axis (a language, an author, a title, a caption, a cell included), lines joined by one
    /// space, an inline atom as its text (a custom emoji's alt text, a formula's LaTeX, a pill's label) and
    /// a unit's atom (a medium, a button row) as nothing. Copy == delete (p19) only holds if what a field
    /// pastes is what was deleted (composer harness p22, `HarnessFragmentIntoOneLineFieldTests`).
    internal func oneLineFieldText(ofFlatRange range: NSRange) -> String {
        var lines: [String] = []
        var offset = 0
        for block in engine.attributedBlocks {
            if offset > NSMaxRange(range) { break }
            let clip = NSIntersectionRange(range, NSRange(location: offset, length: block.length))
            if clip.length > 0 {
                let piece = block.attributedSubstring(from: NSRange(location: clip.location - offset, length: clip.length))
                lines.append(oneLineFieldReading(of: piece))
            }
            offset += block.length + 1
        }
        // A code body's or a pull quote's soft line break (`U+2028`) is a line break too: the gate's
        // one-line rule turns only "\n" into a space by itself, so it is applied here (seed 27's language
        // line received a raw U+2028, which the model reads back as "\n").
        return Self.oneLineFieldText(lines.filter { !$0.isEmpty }.joined(separator: " "))
    }

    private func oneLineFieldReading(of text: NSAttributedString) -> String {
        let string = text.string as NSString
        let result = NSMutableString()
        var cursor = 0
        text.enumerateAttribute(.attachment, in: NSRange(location: 0, length: text.length), options: []) { value, range, _ in
            guard let value else { return }
            for offset in range.location ..< NSMaxRange(range) where string.character(at: offset) == 0xFFFC {
                result.append(string.substring(with: NSRange(location: cursor, length: offset - cursor)))
                if value is EmojiTextAttachment || value is FormulaTextAttachment || value is ButtonTextAttachment {
                    result.append(accessibilityReading(of: value))
                }
                cursor = offset + 1
            }
        }
        result.append(string.substring(from: cursor))
        return (result as String).replacingOccurrences(of: "\u{FFFC}", with: "")
    }

    /// The flat range a Cut of `selection` deletes: exactly what its copy took
    /// (`clipboardSelection()`), which the host view then deletes through the surface gate.
    internal func cutDeletionRange(for selection: NSRange) -> NSRange {
        guard selection == engineSelectedRange, let clipboard = clipboardSelection() else { return selection }
        return clipboard.deletion
    }

    /// Splices a `Document` fragment from the pasteboard over the selection (or at the caret).
    /// `false` when the pasteboard carries no fragment, which is every plain-text, RTF and media
    /// paste — those fall through to the engine untouched.
    internal func pasteFragment(from source: EnginePasteSource) -> Bool {
        guard source.hasFragment, let data = source.fragmentData(),
              let decoded = try? DocumentCodec.decode(data), !decoded.blocks.isEmpty else { return false }
        // A pasted button cannot carry an opaque action — a callback / web-app / payment binding
        // belongs to the message it arrived in and can never work anywhere else. Legacy's
        // `spliceFragmentInEditing` applies the identical downgrade; the EDIT round-trip is
        // unaffected, since that goes through the `document` setter rather than a fragment splice.
        var fragment = decoded.convertingUnsupportedButtonActions()
        guard let target = pasteTargetGlobalRange() else { return false }
        // A destination that holds only RUNS takes the TEXT the copy covered: a code block's language as a
        // line when the copy took its language line, nothing of it when the copy took a body slice (whose
        // fragment still carries the language as metadata). Degraded from the fragment, every code block
        // lost its language, so Cut + Paste of a code block into a cell, a caption or a pull quote's body
        // deleted it (composer harness p23, `HarnessCodeLanguageIntoRunsRegionTests`). A fragment from
        // elsewhere has no covered-text twin and holds every language as content (`withCodeLanguagesAsText`).
        if selectionIsInOneRunsOnlyRegion() {
            if let data = source.coveredTextFragmentData(), let covered = try? DocumentCodec.decode(data),
               !covered.blocks.isEmpty {
                fragment = covered.convertingUnsupportedButtonActions()
            } else {
                fragment = fragment.withCodeLanguagesAsText
            }
        }

        // Block ids are regenerated by `replacingRange`, which is what makes pasting the SAME
        // clipboard twice safe: an id keys the hosted-view pool, so two blocks sharing one would
        // share one hosted view.
        replaceRange(from: target.lo, to: target.hi, with: fragment)
        return true
    }

    /// Whether the selection lies wholly inside ONE region that holds only runs: a table cell, a media
    /// caption, a pull quote's body — the destinations Core degrades a fragment to inline runs for
    /// (`replacingRangeInsideOneContainer`).
    private func selectionIsInOneRunsOnlyRegion() -> Bool {
        let selection = engineSelectedRange
        guard let index = roleIndex(atFlatOffset: selection.location),
              roleIndex(atFlatOffset: NSMaxRange(selection)) == index, index < currentRoles.count else { return false }
        let role = currentRoles[index]
        if role.owningTable != nil || role.secondaryKind == .mediaCaption { return true }
        if case .standalone(.pullQuote) = role.position { return true }
        return false
    }

    /// The global range a paste replaces: the selection widened over any table or medium it
    /// touches, or the collapsed caret. nil when the caret has no global position.
    private func pasteTargetGlobalRange() -> (lo: Int, hi: Int)? {
        let selection = engineSelectedRange
        if selection.length > 0, let range = selectedGlobalRange() {
            // What a copy of this selection would take is what the paste replaces: a range inside one
            // caption or cell stays inside it (Core's region arms splice there), anything else is
            // widened over the units it enters (`clipboardSelection()`).
            let lo = Swift.min(range.from, range.to), hi = Swift.max(range.from, range.to)
            if document.captionTextFragment(globalFrom: lo, globalTo: hi) != nil
                || document.tableCellFragment(globalFrom: lo, globalTo: hi) != nil {
                return (lo, hi)
            }
            let widened = flatRangeExpandedOverUnits(selection)
            if let from = unitAwareGlobalPosition(atFlatOffset: widened.location, preferring: .start),
               let to = unitAwareGlobalPosition(atFlatOffset: NSMaxRange(widened), preferring: .end), from <= to {
                return (from, to)
            }
            return document.expandingRangeOverNonTextBlocks(globalFrom: range.from, globalTo: range.to)
        }
        // A collapsed caret is an empty range, which `replacingRange` splices at rather than
        // replaces — including mid-paragraph, where it folds an inline-mergeable first block
        // into the host paragraph instead of breaking it in two.
        guard let caret = globalPosition(atFlatOffset: selection.location, preferring: .start) else { return nil }
        return (caret, caret)
    }

    /// **Markdown on paste**: plain text the host's `plainTextFragmentTransformer` turns into a
    /// `Document` is pasted as that document. `false` — no transformer, a richer representation on
    /// the pasteboard, text the transformer declines (plain prose: the composer's parser answers nil),
    /// or a destination that is not prose — leaves the paste to the engine, which inserts it literally.
    ///
    /// Consulted AFTER the fragment check (the editor's own copy always carries plain text too, and
    /// the fragment is the faithful reading of it) and only when there is no RTF: that is legacy's
    /// order (`DocumentCanvasView.legacyPaste`), and an RTF pasteboard is the engine's.
    ///
    /// **Only a top-level body paragraph takes it.** A code block is not prose: markdown there is
    /// source, and legacy's second step flattens the parsed blocks INTO the code text
    /// (`insertingFragment`'s code arm joins each block's plain text), which silently deletes the
    /// `#`, `**` and `- ` the user pasted. The engine keeps them. Pull quotes, quotes, details and
    /// table cells fall through for the same reason in a weaker form: `replacingRange` splices
    /// structure there at a top-level boundary, so the paste would land outside the container the
    /// caret is in. A literal paste is the honest answer until that is designed.
    ///
    /// **Two undo steps, legacy's shape**: the first undo leaves the RAW text the user pasted, the
    /// second removes it. Both replacements are computed from the pre-paste document over the same
    /// range, so step 1 (`plain`) and step 2 (`rich`) are each exactly what a single paste of that
    /// content produces; the host is told once, after step 2. Legacy defers step 2 to the next
    /// run-loop pass to escape `groupsByEvent` coalescing; here the automatic group is closed
    /// between the two registrations instead, so there is no intermediate frame to suppress and no
    /// window in which a keystroke could land between the steps. If the manager is not sitting in
    /// exactly its automatic group (registration disabled, or a caller's own group open), the two
    /// registrations share a group and one undo restores the pre-paste document — the acceptable
    /// degradation, never a torn state.
    internal func pasteTransformedPlainText(from source: EnginePasteSource) -> Bool {
        guard let transformer = deferredConfiguration.plainTextFragmentTransformer else { return false }
        guard !source.hasFragment, !source.hasRichText, source.hasString,
              let text = source.string(), !text.isEmpty else { return false }
        guard selectionIsInTopLevelBodyText() else { return false }
        guard let parsed = transformer(text), !parsed.blocks.isEmpty else { return false }
        guard let target = pasteTargetGlobalRange() else { return false }
        let rich = parsed.convertingUnsupportedButtonActions()
        let plain = Self.plainTextFragment(text)

        let before = document
        let selection = engineSelectedRange
        // Step 1: the raw text, undoing to the pre-paste document.
        applyReplacingRange(in: before, from: target.lo, to: target.hi, with: plain)
        recordUndoStepForStructuralChange(restoring: before, selection: selection)
        let plainState = currentUndoSnapshot()
        if engineUndoManager.groupsByEvent, engineUndoManager.groupingLevel == 1 {
            // Close the event's group on step 1 and open the next by hand: the manager opens its
            // automatic group once per event, so a registration after a bare `end` is refused
            // ("must begin a group", measured). The end-of-event pass closes this one as it would
            // have closed the automatic one — it ends whatever sits at level 1.
            engineUndoManager.endUndoGrouping()
            engineUndoManager.beginUndoGrouping()
        }
        // Step 2: the parsed content over the same range, undoing to the raw text.
        applyReplacingRange(in: before, from: target.lo, to: target.hi, with: rich)
        recordUndoStepForCommand(restoring: plainState)
        deliverChangeNotificationNow()
        return true
    }

    /// **Paste obeys typing's refusal.** A selection covering a table only in part refuses typed
    /// text (the gate's rule, `rangeCoversATableOnlyInPart`), and a paste over it is refused the same
    /// way: consumed, nothing changes. Before this every paste route bypassed the rule — the engine's
    /// plain/RTF paste replaced the selection by its own storage edit after
    /// `deleteCrossBlockSelectionBeforeEnginePaste`'s gated delete had already been vetoed, emptying
    /// four cells on screen but not in the model and swallowing the paragraph after the table; and a
    /// fragment paste widened the range over the whole table (`expandingRangeOverNonTextBlocks`) and
    /// dropped it (composer harness, 2026-09-23, fuzz seeds 3, 17, 33, 53, 62,
    /// `HarnessPasteOverPartialTableSelectionTests`). Refusal rather than widening, because a paste IS
    /// a replacement of the selection and the selection is the one typing refuses; the two must not
    /// answer the same range differently. A media pasteboard is not refused: it goes to the send
    /// flow and edits nothing.
    ///
    /// Answers true — the paste is handled — when it refuses.
    internal func refusePasteOverPartlyCoveredTable(from source: EnginePasteSource) -> Bool {
        guard rangeCoversATableOnlyInPart(engineSelectedRange) else { return false }
        return source.hasText
    }

    /// A paste into a ONE-LINE field — a code block's language, a details title, a quote's author —
    /// is that field's text input, not a structural paste: the pasteboard's plain text replaces the
    /// selection through the surface gate, which keeps it one line (`oneLineFieldText`: a newline and
    /// the whitespace around it become one space, as a `UITextField` paste does). The engine's own
    /// paste split the field instead — two lines pasted over an author left an EMPTY author and two
    /// body paragraphs after the pull quote, and into a details title the second line became the
    /// body's first paragraph (composer harness, p12, `HarnessSingleLineFieldNewlineTests`). Asked
    /// before the fragment paste: a field can hold only text, whatever richer form the copy carried.
    ///
    /// Only for a selection lying wholly inside one such field; anything reaching out of it is a
    /// cross-block paste and keeps its own path.
    internal func pastePlainTextIntoOneLineField(from source: EnginePasteSource) -> Bool {
        let selection = engineSelectedRange
        guard let index = roleIndex(atFlatOffset: selection.location),
              roleIndex(atFlatOffset: NSMaxRange(selection)) == index,
              index < currentRoles.count else { return false }
        switch currentRoles[index].secondaryKind {
        case .codeLanguage, .detailsTitle, .pullQuoteAuthor, .blockQuoteAuthor:
            break
        default:
            return false
        }
        // The editor's OWN fragment is flattened from the fragment, every line of it — authors,
        // languages, titles — never from its plain string, which leaves those out: Cut + Paste (and a
        // move, which is Cut + Paste) of an authored quote or a code block with a language into this
        // field deleted the author / language and inserted nothing of it (composer harness p22,
        // `HarnessFragmentIntoOneLineFieldTests`). Copy == delete (p19) only holds if paste == copy.
        // The editor's own copy says exactly what it took; a fragment from elsewhere (a whole message
        // copied by the host) is flattened whole.
        let text: String
        if let exact = source.oneLineFieldText() {
            text = exact
        } else if source.hasFragment, let data = source.fragmentData(),
           let fragment = try? DocumentCodec.decode(data), !fragment.blocks.isEmpty {
            text = fragment.oneLineFieldText
        } else {
            guard source.hasString, let string = source.string() else { return false }
            text = string
        }
        // On one line whatever the source: the gate flattens a text with "\n" itself, but forwards a
        // `U+2028` (a code body's or pull quote's soft break) unread.
        let line = Self.oneLineFieldText(text)
        guard !line.isEmpty, let range = engine.selectedTextRange else { return false }
        engine.replace(range, withText: line)
        return true
    }

    /// Before the ENGINE's own paste (plain text or RTF): a selection spanning more than one block is
    /// deleted through the surface gate first, and the paste then lands at the collapsed caret.
    /// Always answers false, so the engine's paste proceeds.
    ///
    /// UIKit's paste replaces the selection through its input controller's own text-storage edit,
    /// which never reaches the gated `replaceRange:withText:`. Over a selection from a paragraph into
    /// a quote's pull quote that merged the pull quote's surviving text into the paragraph by
    /// identity: the pull quote's role was lost and the quote was left holding only its author line —
    /// a quote with no children in the model and an empty line on screen (composer harness,
    /// 2026-09-23, fuzz seeds 2 and 18, `HarnessPasteOverCrossBlockSelectionTests`). The gate's
    /// cross-block rule is the one that decides what survives such a range, as it does for a cut or
    /// a typed character. A paste at a collapsed caret is left to the engine, as before: a newline
    /// in it splits a block, which settle already declares.
    ///
    /// **The deletion and the paste are ONE undo step** (composer harness p20,
    /// `HarnessCrossBlockPasteUndoTests`). UIKit's paste lands 20-30 ms after `paste:`, in a later
    /// event, so a deletion registered here was a step of its own and the first ⌘Z left the selection
    /// deleted and the paste gone; a stock text view undoes the paste in one. So the deletion
    /// registers nothing and the undo baseline is put back to the state before it, and the paste's
    /// own step (`recordUndoForEngineEdit`) restores that — the pattern a composition at an atom's stop
    /// uses for the line it mints (`resolveAtomStopBeforeComposition`).
    internal func deleteCrossBlockSelectionBeforeEnginePaste(from source: EnginePasteSource) -> Bool {
        let selection = engineSelectedRange
        guard selection.length > 0,
              let first = roleIndex(atFlatOffset: selection.location),
              let last = roleIndex(atFlatOffset: NSMaxRange(selection)), first != last else { return false }
        guard source.hasString || source.hasRichText,
              let range = engine.selectedTextRange else { return false }
        let before = currentUndoSnapshot()
        engineUndoManager.disableUndoRegistration()
        engine.replace(range, withText: "")
        engineUndoManager.enableUndoRegistration()
        endTypingRun()
        lastSettledUndoSnapshot = before
        return false
    }

    /// The paste handler the engine view asks on `paste:`: the host's own paste paths
    /// (`performHostPaste`), and — when they leave a text pasteboard to the ENGINE's paste — the
    /// preparation that paste needs, which the drop path (`insertPlainText`, through the gate) does not:
    ///
    /// - **At a unit's stop** (a medium's atom, a button row) the caret is resolved first as typing
    ///   would resolve it (`resolveAtomStopBeforeComposition`: a body line minted at a leading stop, the
    ///   caption's start at a captioned medium's trailing stop), unrecorded, so the paste lands in text.
    ///   The engine's paste inserts by a storage edit the gate never sees, and multi-line text at the
    ///   atom's line split the unit: the photo left the model and a bare `U+FFFC` was sent (composer
    ///   harness p20, `HarnessPasteAtMediaStopTests`).
    /// - The typing run is ended when the paste LANDS (`enginePasteWillLand`), not here.
    internal func handlePasteFromGeneralPasteboard() -> Bool {
        let source = EnginePasteSource.generalPasteboard
        if performHostPaste(from: source) { return true }
        guard source.hasString || source.hasRichText else { return false }
        if engineSelectedRange.length == 0 {
            resolveAtomStopBeforeComposition(at: engineSelectedRange.location)
            // The minted line is the paste's, not a composition's: a later cancelled composition
            // must not take it away.
            compositionMintedLine = nil
        }
        return false
    }

    /// The engine's own paste is about to land (`tgid_pasteWillLandHandler`): the next storage edit is
    /// the paste. A paste is never part of the typing before it — a stock text view undoes it alone —
    /// so the open run ends and the paste registers a step of its own; left open, a paste straight
    /// after typing was contiguous with the run and one ⌘Z took back both (composer harness p20,
    /// `HarnessPasteJoinsTypingUndoTests`).
    internal func enginePasteWillLand() {
        endTypingRun()
    }

    /// The host's half of a paste, in order: the partial-table refusal, a one-line field, the
    /// editor's own fragment, markdown, and the cross-block delete that precedes the engine's own
    /// plain/RTF insert. `true` — consumed; `false` — the engine's paste (or, for a drop, the gated
    /// plain insert in `insertPlainText(from:)`) proceeds.
    internal func performHostPaste(from source: EnginePasteSource) -> Bool {
        return refusePasteOverPartlyCoveredTable(from: source)
            || pastePlainTextIntoOneLineField(from: source)
            || pasteFragment(from: source) || pasteTransformedPlainText(from: source)
            || deleteCrossBlockSelectionBeforeEnginePaste(from: source)
    }

    /// The last step of a paste that does NOT come from the pasteboard — a drop. The engine's own
    /// `paste:` reads the general pasteboard, which a drop must neither read nor write, so the text
    /// goes in as a replacement of the (by now collapsed) selection instead: the gated surface every
    /// typed or replaced string takes (`tgid_textInputGate`), with the typing attributes of the
    /// caret, newlines decided by the gate as for any multi-line replacement. `false` — no text.
    internal func insertPlainText(from source: EnginePasteSource) -> Bool {
        guard source.hasString, let text = source.string(), !text.isEmpty,
              let range = engine.selectedTextRange else { return false }
        engine.replace(range, withText: text)
        return true
    }

    /// Whether every block the selection touches is a top-level, standalone body paragraph — the
    /// only destination markdown-on-paste structures (see `pasteTransformedPlainText(from:)`).
    private func selectionIsInTopLevelBodyText() -> Bool {
        let touched = touchedBlockIndices(for: engineSelectedRange)
        guard !touched.isEmpty else { return false }
        return touched.allSatisfy { index in
            guard index < currentRoles.count else { return false }
            let role = currentRoles[index]
            guard role.ancestry.isEmpty, case let .standalone(shape) = role.position,
                  let paragraph = shape.paragraph else { return false }
            switch paragraph.style {
            case .body, .heading1, .heading2, .heading3, .heading4, .heading5, .heading6:
                return true
            case .caption, .pullQuote:
                return false
            }
        }
    }

    /// The raw text as blocks: one body paragraph per line, CRLF normalised — what the first undo
    /// step shows. Legacy's `plainTextFragment` minus its checklist-emoji decoding, which is a
    /// reading of the text rather than the text.
    private static func plainTextFragment(_ text: String) -> Document {
        let lines = EnginePasteSource.normalisingLineEndings(text).components(separatedBy: "\n")
        return Document(blocks: lines.map { line in
            .paragraph(ParagraphBlock(id: .generate(), runs: line.isEmpty ? [] : [TextRun(text: line)]))
        })
    }
}
#endif
