#if canImport(UIKit)
import Foundation
import RichTextEditorDifferentialHarness

/// Task 9d — **the named-and-reasoned divergence table.**
///
/// Phase-6 gate item 12: *"every difference the run does not fail on is accounted for by a named
/// entry with a stated reason"*. A bare tolerance count is not acceptable, and neither is widening
/// an entry until a run goes green. The rules this table is written under:
///
/// * **An entry is for a difference that has been EXPLAINED**, not for one that is inconvenient. If
///   a run reports something no entry covers, the suite fails and the difference is a finding.
/// * **An entry must be NARROW.** Task 9d's Step 3a is the precedent: `selection` diverges past
///   every paragraph boundary for a structural reason, and 58 of the 68 scenarios touch a boundary
///   — so an entry excusing it would have excused ~85% of the corpus on a field every scenario
///   compares. That divergence was MAPPED instead (`IDTelegramCharacterAxis`), and no entry for it
///   exists here. A systematic offset is a map; only the residue is an expectation.
/// * **A DECLINED field is not an entry.** A field a Telegram host cannot sample is removed from
///   the comparison list by `IDTelegramComparableFields()` and carries its reason in
///   `IDTelegramDeclinedComparisonFieldReasons()`. Declines and divergences are different facts and
///   the file that records one must not be able to hide the other.
struct TelegramDifferentialExpectation {
    /// A stable identifier, used in the failure report and in the baseline document.
    let name: String
    /// Why this difference is expected. Written for someone who has never read this branch.
    let reason: String
    /// Whether this entry accounts for one observed difference. Deliberately a predicate over the
    /// FULL observation (scenario, family, field, arms, values) rather than a field name: an entry
    /// that matched on `fieldPath` alone would excuse the field everywhere it ever appears.
    let matches: (ObservedDifference) -> Bool
}

/// One difference the run reported, flattened for reporting and matching.
struct ObservedDifference {
    let scenarioIdentifier: String
    let family: IDTextInputScenarioFamily
    let fieldPath: String
    let transactionIndex: Int
    let phase: String
    let leftHostKind: IDTextInputHostKind
    let rightHostKind: IDTextInputHostKind
    let leftValue: Any?
    let rightValue: Any?

    /// True when this is the stock-vs-Telegram comparison (either non-stock arm). The
    /// reference-vs-minimal pair is a different question entirely — see `caveats`.
    var isAgainstStock: Bool { leftHostKind == .stock || rightHostKind == .stock }

    /// The stock arm's value, and the Telegram arm's. `nil` when this is the reference-vs-minimal
    /// pair, which has no stock side at all — every entry below requires `isAgainstStock`, so the
    /// force of this is that a determinism difference can never be matched by naming a value.
    var stockValue: Any? { leftHostKind == .stock ? leftValue : (rightHostKind == .stock ? rightValue : nil) }
    var telegramValue: Any? { leftHostKind == .stock ? rightValue : (rightHostKind == .stock ? leftValue : nil) }

    var description: String {
        "\(scenarioIdentifier) [\(TelegramDifferentialExpectations.name(of: leftHostKind))"
        + " vs \(TelegramDifferentialExpectations.name(of: rightHostKind))]"
        + " field=\(fieldPath) transaction=\(transactionIndex) phase=\(phase)\n"
        + "        left  = \(TelegramDifferentialExpectations.render(leftValue))\n"
        + "        right = \(TelegramDifferentialExpectations.render(rightValue))"
    }
}

enum TelegramDifferentialExpectations {

    // MARK: - The table


    /// Every entry is a difference this branch MEASURED (2026-08-24, iOS 26.5 / 23F73, K1) and then
    /// located in source. None is a tolerance: each carries a predicate narrow enough that a
    /// DIFFERENT difference in the same field still fails the run. Where a narrowing was available
    /// it was taken — `caretRect` matches only when the caret's SIZE agrees and only its origin
    /// moves; `inputDelegateTrace` matches only when stock's trace is a SUBSEQUENCE of the editor's,
    /// so a MISSING notification is still a failure. The counts in
    /// `docs/input-backend-differential-baseline.md` are the measured population of each.
    ///
    /// **"Explained" does not mean "benign".** Several of these are candidate defects; the baseline
    /// document says which, and says so in the same words the report to the user used. What an entry
    /// asserts is that the difference is understood and attributable, not that it is desirable.
    static let all: [TelegramDifferentialExpectation] = [

        // ------------------------------------------------------------------ geometry

        TelegramDifferentialExpectation(
            name: "caret-origin-differs-because-the-arms-use-different-text-metrics",
            reason: """
            The stock arm is a `UITextView` with 17pt system text; the editor lays text out on the \
            InstantPage-V2 CHAT MESSAGE metrics (serif family, pinned line pitch) — a deliberate, \
            project-level contract, not a setting this harness may change: the editor renders what \
            the sent message will look like. Two arms with different fonts cannot produce the same \
            caret ORIGIN, and the corpus's `geometryTolerance` of 1.0 was calibrated for two arms \
            that shared stock's font. Measured deltas on this corpus: dx = 12.0pt at every column \
            (the text origin) plus the per-column advance difference, dy = 7.0pt on line 1 and \
            8.67pt on line 2 (the line pitch). \
            THE COST, STATED PLAINLY: with this entry, `caretRect` certifies nothing about position \
            for this arm pair. What it still certifies is the caret's SHAPE — the predicate matches \
            only when width and height are EQUAL, so a caret that changed size, or vanished, still \
            fails the run. Restoring a positional comparison needs a stock arm configured with the \
            editor's metrics, which would no longer be the arm the corpus was captured against.
            """,
            matches: { difference in
                guard difference.isAgainstStock, difference.fieldPath == "caretRect",
                      let stock = difference.stockValue as? [String: Any],
                      let telegram = difference.telegramValue as? [String: Any] else { return false }
                func number(_ value: Any?) -> Double? { (value as? NSNumber)?.doubleValue }
                guard let sw = number(stock["width"]), let tw = number(telegram["width"]),
                      let sh = number(stock["height"]), let th = number(telegram["height"]) else { return false }
                return sw == tw && sh == th
            }),

        TelegramDifferentialExpectation(
            name: "editor-returns-no-selection-rects-for-a-collapsed-range",
            reason: """
            `UITextView` answers `selectionRects(for:)` on a COLLAPSED range with one zero-width \
            rect carrying `containsStart`/`containsEnd`; the editor answers with an EMPTY array. \
            Located: `LegacyRichTextInputBackend+Geometry.swift:163-174` maps the geometry client's \
            SEGMENTS to `LegacySelectionRect`s, and an empty range produces no segments. Every \
            checkpoint in this corpus that compares geometry sits at a collapsed caret, so this \
            accounts for the whole population. \
            NOT BLESSED — this is a real `UITextInput` conformance difference and a candidate defect \
            (UIKit callers that ask for the rects of a collapsed range get nothing to draw); it is \
            recorded here because it is understood and attributable, not because it is desirable. \
            The predicate requires the EDITOR's side to be empty, so a non-empty disagreement about \
            selection geometry — the case this field exists to catch — still fails the run.
            """,
            matches: { difference in
                guard difference.isAgainstStock, difference.fieldPath == "selectionRects",
                      let telegram = difference.telegramValue as? [Any], telegram.isEmpty,
                      let stock = difference.stockValue as? [Any], !stock.isEmpty else { return false }
                return true
            }),

        // ------------------------------------------------------------------ input-delegate traffic

        TelegramDifferentialExpectation(
            name: "editor-notifies-the-input-delegate-where-stock-stays-silent",
            reason: """
            Three shapes were measured, and in ALL of them the editor's trace CONTAINS stock's in \
            order: (a) `setMarkedText` — stock `[textWillChange, textDidChange]`, editor the same \
            plus `selectionWillChange`/`selectionDidChange`; (b) a programmatic `replace(_:withText:)` \
            or `insertText(_:)` — stock emits NOTHING at all, the editor emits a full \
            text+selection bracket per mutation. Stock's silence in (b) is UIKit not telling the \
            input system about a change the input system's own protocol method just made; the editor \
            brackets every mutation through `notifyingContentAndSelectionChange` regardless of who \
            asked. \
            NOT BLESSED — extra `selectionDidChange` traffic during a live composition is exactly \
            the kind of thing that perturbs autocorrection and inline prediction, and it deserves a \
            keyboard-level look. It is named here because the mechanism is understood, and the \
            predicate is a SUBSEQUENCE test: a notification the editor FAILS to send (stock's trace \
            not embeddable in the editor's) is not matched and still fails the run.
            """,
            matches: { difference in
                guard difference.isAgainstStock, difference.fieldPath == "inputDelegateTrace",
                      let stock = difference.stockValue as? [String],
                      let telegram = difference.telegramValue as? [String] else { return false }
                var index = telegram.startIndex
                for event in stock {
                    guard let found = telegram[index...].firstIndex(of: event) else { return false }
                    index = telegram.index(after: found)
                }
                return true
            }),

        // ------------------------------------------------------------------ composition

        TelegramDifferentialExpectation(
            name: "editor-registers-no-undo-step-for-an-uncommitted-composition",
            reason: """
            Stock reports `canUndo == true` as soon as `setMarkedText` puts a composition on screen; \
            the editor reports `false` until the composition COMMITS. Verified rather than assumed: \
            at the terminal checkpoint of the same scenarios — after `unmarkText` — both arms report \
            `canUndo == true`, so the editor does register a step, just later. Consequence: a user \
            who hits undo mid-composition gets the pre-composition document on stock and the \
            pre-EDIT document on the editor. \
            The predicate is directional (stock true, editor false): the reverse — the editor \
            claiming an undo step stock does not have — is not matched and still fails.
            """,
            matches: { difference in
                guard difference.isAgainstStock, difference.fieldPath == "canUndo",
                      let stock = difference.stockValue as? NSNumber,
                      let telegram = difference.telegramValue as? NSNumber else { return false }
                return stock.boolValue && !telegram.boolValue
            }),

        TelegramDifferentialExpectation(
            name: "editor-does-not-model-selection-affinity",
            reason: """
            `selectionAffinity` is `@optional` on `UITextInput` and both arms answer it, but the \
            editor's answer is a constant: across all 68 scenarios and every checkpoint it reports \
            `forward` and never `backward`. There is no affinity in the editor's model — \
            `RichTextInputAffinity` exists on the geometry client and its only producer returns \
            `.downstream` unconditionally (`TelegramGeometryInputClient.swift:99`). Stock reports \
            `backward` while a composition caret sits at the END of the marked text, which is why \
            the IME family diverges here (its compositions place the caret at the end) and the \
            inline-prediction family does not (its compositions place it at offset 0). \
            The predicate is directional: stock `backward` against editor `forward`. Any other \
            affinity disagreement still fails.
            """,
            matches: { difference in
                guard difference.isAgainstStock, difference.fieldPath == "affinity" else { return false }
                return (difference.stockValue as? String) == "backward"
                    && (difference.telegramValue as? String) == "forward"
            }),

        TelegramDifferentialExpectation(
            name: "editor-finalizes-a-live-composition-when-it-resigns-first-responder",
            reason: """
            After `resignFirstResponder` with a composition live, stock KEEPS the marked text and \
            its range; the editor has none — it commits the composition on detach \
            (`finalizeMarkedTextForDetach()`). Two IME scenarios exercise it \
            (`*-responder-loss`), on both `markedRange` and `markedText`. \
            The predicate requires the EDITOR to be the side with no marked text: a disagreement \
            about WHERE the composition is, or an editor that kept one stock dropped, still fails.
            """,
            matches: { difference in
                guard difference.isAgainstStock else { return false }
                if difference.fieldPath == "markedText" {
                    return (difference.telegramValue as? String)?.isEmpty == true
                        && (difference.stockValue as? String)?.isEmpty == false
                }
                guard difference.fieldPath == "markedRange",
                      let telegram = difference.telegramValue as? [String: Any],
                      let stock = difference.stockValue as? [String: Any],
                      let telegramLocation = telegram["location"] as? NSNumber,
                      let stockLocation = stock["location"] as? NSNumber else { return false }
                return telegramLocation.intValue == NSNotFound && stockLocation.intValue != NSNotFound
            }),

        // ------------------------------------------------------------------ undo

        TelegramDifferentialExpectation(
            name: "undo-restores-the-pre-edit-caret-where-stock-re-selects-the-restored-range",
            reason: """
            After undoing a word replacement, stock leaves the RESTORED RANGE selected \
            (`{8, 6}` — the word it put back); the editor leaves a COLLAPSED caret at the position \
            the selection had before the edit run began (`{14, 0}`). Both arms restore identical \
            text — `canonical` and `blocks` agree at that checkpoint — so this is purely the \
            selection-restoration policy: the editor's undo is a whole-document `[Block]` snapshot \
            that carries the selection it captured when the run opened. \
            The predicate checks the two are RELATED, not merely different: the editor's caret must \
            be collapsed AND sit exactly at the end of the range stock re-selected. An undo that \
            landed the caret anywhere else still fails.
            """,
            matches: { difference in
                guard difference.isAgainstStock, difference.fieldPath == "selection",
                      let stock = difference.stockValue as? [String: Any],
                      let telegram = difference.telegramValue as? [String: Any],
                      let stockLocation = (stock["location"] as? NSNumber)?.intValue,
                      let stockLength = (stock["length"] as? NSNumber)?.intValue,
                      let telegramLocation = (telegram["location"] as? NSNumber)?.intValue,
                      let telegramLength = (telegram["length"] as? NSNumber)?.intValue else { return false }
                return stockLength > 0 && telegramLength == 0
                    && telegramLocation == stockLocation + stockLength
            }),

        // ------------------------------------------------------------------ pending caret format

        TelegramDifferentialExpectation(
            name: "editor-has-no-pending-caret-format",
            reason: """
            THE DIFFERENCE THE INLINE-FORMATTING FAMILY EXISTS TO FIND, and Task 9c predicted it \
            from production source before any driver existed. `DocumentCanvasView.characterFormat\
            Targets()` opens with `guard selFrom < selTo else { return [] }` \
            (`DocumentCanvasView+CharacterFormat.swift:24`), so `toggleBold()` at a COLLAPSED caret \
            applies to nothing and the next typed character is not bold; a `UITextView` carries the \
            toggle in `typingAttributes` and types bold. The editor's own README lists pending caret \
            formatting as DEFERRED, so this is a known gap the oracle can now MEASURE rather than a \
            new discovery. It shows up twice, as one cause: `typingInlineTraits` at the toggle \
            checkpoint (the caret carries nothing), and `inlineRuns` at the next checkpoint (the \
            character typed after it carries nothing). \
            Both predicates require the EDITOR to be the side with NO traits — the editor applying a \
            format stock does not, or the two disagreeing about a RANGE format, still fails. Note \
            that `single-range-add-remove`, `cross-block-bold` and the other RANGE-selection \
            scenarios of this family pass outright: the editor's range formatting agrees with stock.
            """,
            matches: { difference in
                guard difference.isAgainstStock else { return false }
                if difference.fieldPath == "typingInlineTraits" {
                    guard let stock = difference.stockValue as? [String],
                          let telegram = difference.telegramValue as? [String] else { return false }
                    return telegram.isEmpty && !stock.isEmpty
                }
                guard difference.fieldPath == "inlineRuns",
                      let stock = difference.stockValue as? [[String: Any]],
                      let telegram = difference.telegramValue as? [[String: Any]] else { return false }
                func traits(_ runs: [[String: Any]]) -> [[String]] { runs.map { ($0["traits"] as? [String]) ?? [] } }
                return traits(telegram).allSatisfy(\.isEmpty) && traits(stock).contains { !$0.isEmpty }
            }),
    ]

    // MARK: - Caveats — statements about what an AGREEMENT means

    /// Not tolerances. These are the places where a green result means less than it looks like it
    /// means, recorded here because a divergence table that only lists differences lets a false
    /// agreement pass unremarked — and a false agreement is the failure mode this phase exists to
    /// prevent (`IDCompareTextInputSnapshotPair` treats `nil == nil` as equality).
    static let caveats: [(name: String, reason: String)] = [
        (name: "minimal-is-not-a-second-backend",
         reason: """
         `IDTextInputHostKind` is vendored and has exactly three cases, and the vendored runner \
         executes all three for every scenario. InputDec had two of its own implementations for the \
         two non-stock slots; Telegram has ONE. The factory therefore builds a fresh, independently \
         constructed editor for BOTH non-stock kinds, so the reference-vs-minimal pair is a \
         DETERMINISM / EXECUTION-ORDER check — the two run at different points of the runner's order, \
         so a difference between them means state leaked across instances or the result depended on \
         when it ran. Reading a reference-vs-minimal AGREEMENT as "two backends agree" would be \
         exactly the false comfort this phase exists to prevent. No entry in `all` may match a \
         reference-vs-minimal difference: such a difference is always a finding. When a second \
         Telegram input backend exists it takes the `Minimal` slot and the check becomes a real one.
         """),
        (name: "declined-fields-are-not-compared",
         reason: """
         `storageMutationTrace` and `traits` are removed from every comparison by \
         `IDTelegramComparableFields()`. They are NOT reported as agreeing — they are visibly not \
         compared, which is the point: the vendored comparator's `leftValue == rightValue` makes two \
         absent fields equal, so leaving them in the list would have certified something nobody \
         measured. `storageMutationTrace` is in 3 of the 4 families' contracts and `traits` in the \
         same 3, so this removes 2 of 14 comparison fields for 54 scenarios and 0 of 7 for the \
         14 inline-formatting ones. Each carries its reason in \
         `IDTelegramDeclinedComparisonFieldReasons()`.
         """),
        (name: "one-difference-per-field-per-pair",
         reason: """
         `IDCompareTextInputSnapshotPair` RETURNS ON THE FIRST INEQUALITY, scanning snapshot indices \
         outermost, so a single call reports at most one difference per host pair and everything \
         after it is masked. The family tests therefore call the vendored comparator ONCE PER FIELD \
         (a single-element `comparisonFields` list) so that one diverging field cannot hide the \
         others. Within a field, only the FIRST diverging checkpoint is reported — the counts below \
         are counts of (scenario, field, host-pair) triples, not of individual disagreeing values.
         """),
        (name: "annotations-are-never-requested",
         reason: """
         `comparesAnnotations` is computed from the scenario, and no scenario in this corpus names \
         `annotationRanges` (measured over all 68). The recorder's annotation path is therefore \
         written but unexercised — a capability claim, not a result.
         """),
    ]

    // MARK: - Classification

    static func expectation(for difference: ObservedDifference) -> TelegramDifferentialExpectation? {
        all.first { $0.matches(difference) }
    }

    // MARK: - Rendering

    static func name(of kind: IDTextInputHostKind) -> String {
        switch kind {
        case .stock: return "stock"
        case .reference: return "reference"
        case .minimal: return "minimal"
        @unknown default: return "unknown"
        }
    }

    static func name(of family: IDTextInputScenarioFamily) -> String {
        switch family {
        case .IME: return "ime"
        case .autocorrection: return "autocorrection"
        case .inlinePrediction: return "inline-prediction"
        case .inlineFormatting: return "inline-formatting"
        @unknown default: return "unknown"
        }
    }

    /// One line, always — and **whitespace is escaped, never collapsed.**
    ///
    /// `String(describing:)` on an `NSDictionary`/`NSArray` is multi-line and indented, which turns
    /// a per-difference report into hundreds of unreadable lines. The obvious fix — collapsing runs
    /// of whitespace — is WRONG here and cost a debugging cycle: the inline-prediction family's
    /// `canonical` difference is *entirely* a lost `"\n"`, so a collapsed render printed the two
    /// arms' values IDENTICALLY next to a report saying they differed. Escape, do not collapse.
    static func render(_ value: Any?) -> String {
        guard let value else { return "<absent>" }
        var text = String(describing: value)
        // Escaping (not stripping) is what makes the result one line: after this every newline the
        // container description emitted for pretty-printing is a two-character `\n` and nothing is
        // lost. The residual indent spaces are left alone — removing them would need a rule that
        // cannot tell a container's indent from a string value's own leading spaces, and the
        // inline-prediction family's differences are literally about spaces.
        text = text.replacingOccurrences(of: "\n", with: "\\n")
        text = text.replacingOccurrences(of: "\t", with: "\\t")
        return text.count > 800 ? String(text.prefix(800)) + "\u{2026}" : text
    }
}
#endif
