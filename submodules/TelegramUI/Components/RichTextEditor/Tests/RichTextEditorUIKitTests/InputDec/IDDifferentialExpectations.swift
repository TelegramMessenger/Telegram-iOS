#if canImport(UIKit)
import Foundation
import UIKit
import RichTextEditorDifferentialHarness
import RichTextEditorUIKit

/// Task D4b — the ID-backend twin of `TelegramDifferentialExpectations` (stage 1, Task 9d).
///
/// Reuses `ObservedDifference` and `TelegramDifferentialExpectation` verbatim (both are declared
/// `internal` in `Differential/TelegramDifferentialExpectations.swift` and are backend-agnostic —
/// neither type names a backend). **This is a SEPARATE table, not an extension of the legacy one**,
/// on purpose: `ObservedDifference.leftHostKind`/`rightHostKind` are `IDTextInputHostKind` values
/// (`.stock`/`.reference`/`.minimal`) — the SAME three cases legacy's differences are reported
/// against — so nothing about a raw `ObservedDifference` says which BACKEND produced it. Sharing one
/// table would risk a legacy-shaped predicate silently swallowing a genuinely new ID-backend defect
/// that happens to land on the same field with a coincidentally similar shape. Keeping the two
/// tables apart, each consulted only by its own suite, is what keeps that impossible by construction.
///
/// Every entry here is either:
///   (a) a KNOWN-UNREACHABLE kernel limit, already characterized with captured evidence in
///       `Sources/RichTextInputDecObjC/../InputDec/DIVERGENCES.md` (reactive-validation storm,
///       directional-stepping overshoot) — attributed, not re-investigated. **TASK F1: this
///       category is currently EMPTY. Its only two members were the geometry pair, and F1 rerouted
///       Family 2 off the kernel onto the host geometry client, which moved both into the
///       shared-with-legacy class below — see `DIVERGENCES.md` entry 19 for what the
///       "unreachable" label cost (a crash on first tap that nobody predicted, because the label
///       stopped anyone looking).**;
///   (b) a NEW instance of the axis-conversion class DIVERGENCES.md already names (a plain-text-axis
///       range handed to a bridge that assumed structural) — the shape is precedented even when the
///       specific site is new;
///   (c) an unimplemented witness (an empty-stub kernel entry point) — the corpus produces no effect
///       at all where stock produces one;
///   (d) genuinely new and uncategorised — NOT added here. A category-(d) difference is the point of
///       this task and is left red, recorded in the task report and the baseline doc instead.
/// Each entry's doc comment below states which of (a)/(b)/(c) it is and cites its evidence.
enum IDDifferentialExpectations {

    static let all: [TelegramDifferentialExpectation] = [

        // ------------------------------------------------------------------ shared-with-legacy: no pending caret format

        /// **Not category (a)/(b)/(c) — a FOURTH class this task's own report names explicitly: a
        /// divergence ALREADY characterized under the legacy backend (`TelegramDifferentialExpectations
        /// .all`'s own "editor-has-no-pending-caret-format", stage 1 Task 9d), reproduced here because
        /// it is BACKEND-AGNOSTIC canvas code, not because `.inputDec` introduces anything new.
        ///
        /// `DocumentCanvasView.characterFormatTargets()` (`+CharacterFormat.swift`) opens with `guard
        /// selFrom < selTo else { return [] }` — a COLLAPSED caret never carries a pending format, for
        /// EITHER backend, because `applyCharacterToggle`/`toggleBold()` etc. are pure canvas-level
        /// code that never reads `inputBackend` at all (confirmed directly, Task D4b: the toggle
        /// closure `TelegramInputDecDifferentialInputFactory` registers calls `canvas.toggleBold()`
        /// unconditionally, identically to the legacy factory's own closure). So a `UITextView`
        /// carries a caret-toggled format in `typingAttributes` and types bold; this editor does not,
        /// under EITHER backend. Measured here: `caret-bold-type`, `caret-bold-return-type`,
        /// `caret-combined-traits`, `caret-move-away`, `undo-formatted-typing` — the same five-scenario
        /// shape stage 1 named, now confirmed present under `.inputDec` too.
        TelegramDifferentialExpectation(
            name: "editor-has-no-pending-caret-format-inputdec",
            reason: """
            Reproduction, under `.inputDec`, of stage 1's "editor-has-no-pending-caret-format" \
            (`TelegramDifferentialExpectations.swift`) — same root cause (`characterFormatTargets()` \
            returns `[]` for a collapsed caret, canvas-level and backend-agnostic), so it is expected \
            to appear again here rather than being ID-specific. Named separately because this table is \
            deliberately not shared with legacy's (see this file's header) — NOT because the mechanism \
            differs. Both predicates require the TELEGRAM side to be the one with NO traits; a range- \
            selection format disagreement, or the editor applying a format stock does not, still fails.
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

        // ------------------------------------------------------------------ shared-with-legacy: caret + selection geometry
        //
        // TASK F1 RECLASSIFIED BOTH ENTRIES BELOW, and re-measured the predicates rather than
        // re-labelling them. They were category (a), "known-unreachable kernel geometry bypass": the
        // kernel laid caret and selection geometry out through its own synthetic, unstyled
        // `NSTextContainer` and never asked Telegram anything, so nothing about either field was
        // expected to agree. F1 rerouted all eight Family-2 witnesses onto the host geometry client
        // (`IDTextEditorBackend+Geometry.swift`) — the SAME client
        // `LegacyRichTextInputBackend+Geometry.swift` has always used — so both fields are now
        // produced by backend-agnostic canvas code and belong in the fourth, shared-with-legacy class
        // alongside `editor-has-no-pending-caret-format-inputdec` above.
        //
        // MEASURED, not asserted (K1, build 23F73, all four families in one invocation): the counts
        // are unchanged (108 `caretRect`, 108 `selectionRects`), but the caretRect predicate was
        // NARROWED from "any dict-vs-dict difference on this field" to legacy's own "the caret's SIZE
        // agrees and only its origin moves" — and it still matches 108/108 with 0 unexplained. Under
        // the kernel it could not have: the pre-F1 baseline recorded divergence in BOTH size and
        // origin, which is precisely why the old entry declined to narrow.

        /// **Shared-with-legacy** (post-F1). Byte-for-byte the same predicate as legacy's
        /// `caret-origin-differs-because-the-arms-use-different-text-metrics`, because it is now
        /// literally the same mechanism: the stock arm is a `UITextView` with 17pt system text and
        /// this editor lays text out on the InstantPage-V2 chat-message metrics, so two arms with
        /// different fonts cannot agree on a caret ORIGIN. What the predicate still certifies is the
        /// caret's SHAPE — width and height must be EQUAL — so a caret that changed size, or
        /// vanished, still fails the run. That certification is NEW here: it was unavailable while
        /// the kernel owned this field.
        TelegramDifferentialExpectation(
            name: "caret-origin-differs-because-the-arms-use-different-text-metrics-inputdec",
            reason: """
            Reproduction, under `.inputDec`, of stage 1's \
            "caret-origin-differs-because-the-arms-use-different-text-metrics" \
            (`TelegramDifferentialExpectations.swift`). Since Task F1 both backends answer \
            `caretRect(for:)` from the SAME host geometry client, so the only thing left between the \
            arms is the font: stock is 17pt system, the editor is on the InstantPage-V2 chat-message \
            metrics (a project-level contract — the editor renders what the sent message will look \
            like), and the corpus's 1.0pt geometryTolerance was calibrated for two arms sharing \
            stock's font. Named separately from legacy's entry because this table is deliberately not \
            shared (see this file's header), NOT because the mechanism differs. \
            SUPERSEDES `kernel-geometry-bypass-caretRect`, which claimed the kernel computed this \
            field against its own synthetic container and that therefore NEITHER dimension could be \
            expected to agree. That was true before F1 and is false now; the narrowed predicate below \
            is the measurement that proves it (108/108 still matched with size equality required). \
            The height is checked against the editor's OWN body line pitch since 2026-09-15 rather \
            than against stock's caret height — see `differentialBodyLinePitch`, and the legacy \
            twin, which was narrowed in the same way and for the same reason.
            """,
            matches: { difference in
                guard difference.isAgainstStock, difference.fieldPath == "caretRect",
                      let stock = difference.stockValue as? [String: Any],
                      let telegram = difference.telegramValue as? [String: Any] else { return false }
                func number(_ value: Any?) -> Double? { (value as? NSNumber)?.doubleValue }
                guard let sw = number(stock["width"]), let tw = number(telegram["width"]),
                      let th = number(telegram["height"]) else { return false }
                return sw == tw && th == differentialBodyLinePitch
            }),

        /// **Shared-with-legacy** (post-F1), the twin of legacy's
        /// `editor-returns-no-selection-rects-for-a-collapsed-range`. `UITextView` answers
        /// `selectionRects(for:)` on a COLLAPSED range with one zero-width rect carrying
        /// `containsStart`/`containsEnd`; this editor maps the geometry client's SEGMENTS, and an
        /// empty range produces no segments — under EITHER backend now, for the same reason and in
        /// the same line of code shape. Every checkpoint in this corpus that compares selection
        /// geometry sits at a collapsed caret, which is why this accounts for the whole population.
        ///
        /// NOT BLESSED, exactly as legacy's own entry says: a real `UITextInput` conformance
        /// difference and a candidate defect (a UIKit caller asking for a collapsed range's rects
        /// gets nothing to draw). The predicate requires the EDITOR's side to be empty, so a
        /// non-empty disagreement about selection geometry — the case this field exists to catch —
        /// still fails the run.
        TelegramDifferentialExpectation(
            name: "editor-returns-no-selection-rects-for-a-collapsed-range-inputdec",
            reason: """
            Reproduction, under `.inputDec`, of stage 1's \
            "editor-returns-no-selection-rects-for-a-collapsed-range". Since Task F1, \
            `IDTextEditorBackend+Geometry.swift`'s `selectionRects(for:)` maps the geometry client's \
            segments exactly as `LegacyRichTextInputBackend+Geometry.swift` does, and a collapsed \
            range produces no segments — so the empty array is now the SHARED canvas behaviour, not \
            a kernel choice. \
            SUPERSEDES `kernel-geometry-bypass-selectionRects-empty`, whose whole stated mechanism \
            ("the kernel's own geometry answer, never routed through Telegram's bridge") no longer \
            describes this code. The observable shape is unchanged, which is exactly why the old \
            entry kept passing and the mischaracterisation went unnoticed.
            """,
            matches: { difference in
                guard difference.isAgainstStock, difference.fieldPath == "selectionRects",
                      let telegram = difference.telegramValue as? [Any], telegram.isEmpty,
                      let stock = difference.stockValue as? [Any], !stock.isEmpty else { return false }
                return true
            }),

        // ------------------------------------------------------------------ shared-with-legacy: affinity + input-delegate trace

        /// Shared-with-legacy (see the header's "fourth class" note on the pending-caret-format
        /// entry above) — `RichTextInputAffinity`'s one producer
        /// (`TelegramGeometryInputClient.swift:99`) returns `.downstream` unconditionally, and that
        /// client is one of the SIX Telegram-side clients BOTH backends share
        /// (`RichTextInputHost.geometryClient`) — not legacy-specific code, so the same constant
        /// answer is expected under `.inputDec` too. Measured: same direction as legacy
        /// (stock `backward`, telegram `forward`), same trigger (a composition caret at the START of
        /// the marked text — every affected scenario here is `*-candidate-commit`/`*-ordinary-commit`/
        /// `*-cancel`/`*-responder-loss`/`*-return-commit-then-undo`, IME's own compositions).
        TelegramDifferentialExpectation(
            name: "editor-does-not-model-selection-affinity-inputdec",
            reason: """
            Reproduction, under `.inputDec`, of stage 1's "editor-does-not-model-selection-affinity" — \
            `TelegramGeometryInputClient` is shared, backend-agnostic code, so its constant `.downstream` \
            answer is expected here too. Directional predicate: stock `backward` vs telegram `forward`; \
            any other affinity disagreement still fails.
            """,
            matches: { difference in
                guard difference.isAgainstStock, difference.fieldPath == "affinity" else { return false }
                return (difference.stockValue as? String) == "backward"
                    && (difference.telegramValue as? String) == "forward"
            }),

        /// Shared-with-legacy. `notifyingContentAndSelectionChange` (the `editing{}`/composition
        /// bracket that produces this trace) is canvas-level, backend-agnostic code — the SAME
        /// mechanism legacy's "editor-notifies-the-input-delegate-where-stock-stays-silent" already
        /// names. Predicate identical to stage 1's: a SUBSEQUENCE test (telegram's trace must CONTAIN
        /// stock's, in order), so a notification the editor FAILS to send still fails the run.
        TelegramDifferentialExpectation(
            name: "editor-notifies-the-input-delegate-where-stock-stays-silent-inputdec",
            reason: """
            Reproduction, under `.inputDec`, of stage 1's "editor-notifies-the-input-delegate-where-\
            stock-stays-silent" — the bracket is canvas-level and backend-agnostic. Predicate is a \
            SUBSEQUENCE test: telegram's trace must contain stock's in order; a notification the \
            editor fails to send is not matched and still fails the run.
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

        // ------------------------------------------------------------------ shared-with-legacy: undo selection policy

        /// Shared-with-legacy. The editor's undo is a whole-document `[Block]` snapshot
        /// (`DocumentCanvasView+Editing.swift`'s `registerUndo`/`performEditing`) restoring a
        /// COLLAPSED caret at the end of the pre-edit span for a content edit, where stock re-selects
        /// the restored RANGE — canvas-level, backend-agnostic undo-registration code (confirmed:
        /// `registerUndo`'s caller, `performEditing`, never reads `inputBackend` to decide the
        /// restored selection shape). Measured here (autocorrection family, all 9 `*-undo-*`
        /// scenarios): stock `{location 8, length 6}` (or `{15, 6}` after-boundary) vs telegram
        /// `{location 14, length 0}` (or `{21, 0}`) — telegram's collapsed caret sits exactly at
        /// `stockLocation + stockLength` in every case, matching legacy's own measured example
        /// (`{8,6}` → `{14,0}`) exactly.
        TelegramDifferentialExpectation(
            name: "undo-restores-the-pre-edit-caret-where-stock-re-selects-the-restored-range-inputdec",
            reason: """
            Reproduction, under `.inputDec`, of stage 1's identically-named entry — the undo-selection \
            policy is canvas-level, backend-agnostic code. Predicate checks the two are RELATED, not \
            merely different: the editor's caret must be collapsed AND sit exactly at the end of the \
            range stock re-selected. An undo landing the caret anywhere else still fails.
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
    ]

    // MARK: - Classification

    static func expectation(for difference: ObservedDifference) -> TelegramDifferentialExpectation? {
        all.first { $0.matches(difference) }
    }
}
#endif
