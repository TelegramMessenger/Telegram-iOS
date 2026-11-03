#if canImport(UIKit)
import UIKit
import XCTest
import RichTextEditorCore
import RichTextEditorDifferentialHarness
@testable import RichTextEditorUIKit

/// **Ported from `/Users/isaac/Documents/InputDec/Tests/IDInlineFormattingStockOracleTests.m`**
/// (279 lines, 6 tests). See `PROVENANCE.md` in this directory for the full deviation record.
///
/// ## What upstream's file is, and why the port has three arms where upstream has one
///
/// Upstream's suite drives a **stock `UITextView` only**. It is the *oracle definition*: it records
/// what UIKit itself does with inline formatting at a caret, across a selection replacement, across
/// a newline, and through undo/redo, so upstream's own host can later be held to it. Ported
/// verbatim it would run entirely on `UITextView`, pass 6/6, and touch this port not at all —
/// precisely the vacuous green this programme has produced before.
///
/// So each test runs the same scenario three ways and compares the three readings:
///
/// | arm | what it is | what a divergence means |
/// | --- | --- | --- |
/// | **stock** | `UITextView`, upstream's own assertions preserved verbatim | UIKit moved; every claim below is unanchored |
/// | **inputDec** | `RichTextEditorView(inputBackend: .inputDecIfSupported)` | the thing under certification |
/// | **legacy** | `RichTextEditorView(inputBackend: .legacy)` — **the control** | the editor never matched stock here |
///
/// The Legacy control is not decoration. The earlier differential corpus recorded 514 differences,
/// **194 of which were shared with Legacy** — pre-existing canvas behaviour with nothing to do with
/// the InputDec port. Without the control those would all be charged to the port, overstating its
/// cost by ~38%. `IDStockParity.assertField` therefore tags every divergence `PORT-DEFECT` (Legacy
/// matches stock, InputDec does not) or `PRE-EXISTING` (neither does). Both still FAIL — the tag
/// says who to bill, not whether it counts.
///
/// ## The comparison surface, and the scope rule it obeys
///
/// Text, character-axis selection, and the four inline traits `IDNormalizedInlineTraitNames`
/// defines. All four traits are things a stock `UITextView` supports, per the task's rule: *use no
/// Telegram-specific feature that is not available in stock `UITextView`*. Only the *spelling*
/// differs — stock says `typingAttributes = boldAttributes`, the editor says `toggleBold()` — and
/// substituting the host is the whole point of the port.
///
/// ## Upstream assertions this port DROPS (PROVENANCE.md §Dropped records each with its reason)
///
/// * Every `snapshot:`-dictionary `@"typing"` read. `typingAttributes` is a `UITextView` member with
///   no `UITextInput` counterpart, and `-textStylingAtPosition:inDirection:` is `@optional` and
///   unimplemented on `DocumentCanvasView`. Where upstream's claim was *observable through typed
///   characters* it is re-expressed that way; where it was only readable as a dictionary it is gone.
/// * `canUndo` / `canRedo` snapshot fields. The host's undo manager is injected
///   (`undoManagerOverride`) and its grouping is the test's, not the view's, so comparing the two
///   managers' flags would compare the harness to itself.
/// * `IDNormalizedInlineRuns(...)` **run-array** equality between snapshots — kept verbatim on the
///   stock arm, re-expressed on the host arms as per-character trait names, because the host has no
///   single `NSTextStorage` spanning the document.
@available(iOS 17.0, *)
@MainActor
final class IDInlineFormattingStockOracleParityTests: XCTestCase {

    private var violations = IDStockParity.ViolationLog()

    override func setUpWithError() throws {
        try super.setUpWithError()
        try XCTSkipUnless(IDTextEditorBackend.isSupported(),
                          "InputDec backend unsupported on this runtime")
        violations = IDStockParity.ViolationLog()
        IDStockParity.installContractReporter(violations, in: self)
    }

    // MARK: - Arms

    /// **Task P2: both arms now come from the shared substitution seam** (`IDStockParity.makeSubject`),
    /// which is upstream's `-makeCustom:stock:` for a single arm.
    ///
    /// `makeSubject` and NOT `makeArms` here, deliberately. This suite MUTATES, so each scenario
    /// needs a fresh arm — the calibration below builds two same-backend editors on purpose so the
    /// second is not looking at the first's mutation, and a shared three-arm fixture would silently
    /// gut it. Building all three when a scenario needs one would also attach an unused InputDec
    /// kernel whose violations would land in this test's shared log.
    ///
    /// Each subject is hosted in its own window and made first responder, exactly as before, so the
    /// readings this suite reports are unchanged by the re-pointing.
    private func stockArm(_ text: String) throws -> UITextView {
        try XCTUnwrap(IDStockParity.makeSubject(.stock, IDParityFixture(blocks: [text]), in: self).stock)
    }

    private func hostArm(_ paragraphs: [String],
                         _ backend: RichTextEditorInputBackendPreference) throws -> RichTextEditorView {
        let arm: IDParityArm = (backend == .legacy) ? .legacy : .inputDec
        return try XCTUnwrap(IDStockParity.makeSubject(arm, IDParityFixture(blocks: paragraphs),
                                                       in: self).editor)
    }

    // MARK: - Readings (captured into values before anything is asserted)

    private func reading(of stock: UITextView) -> IDStockParity.Reading {
        var result = IDStockParity.Reading()
        result.text = stock.text ?? ""
        result.selection = NSStringFromRange(stock.selectedRange)
        let length = (result.text as NSString).length
        result.traits = (0..<length).map {
            IDNormalizedInlineTraitNames(stock.textStorage.attributes(at: $0, effectiveRange: nil))
        }
        return result
    }

    private func reading(of editor: RichTextEditorView) -> IDStockParity.Reading {
        let canvas = IDStockParity.input(of: editor)
        var result = IDStockParity.Reading()
        result.text = IDStockParity.plainText(canvas)
        result.selection = IDStockParity.characterRange(canvas, canvas.selectedTextRange)
            .map(NSStringFromRange) ?? "(no selection)"
        result.traits = hostTraitsPerCharacter(editor)
        return result
    }

    /// Upstream's `attributesWithBold:italic:underline:strike:`, transliterated.
    private func attributes(bold: Bool, italic: Bool, underline: Bool,
                            strike: Bool) -> [NSAttributedString.Key: Any] {
        var traits: UIFontDescriptor.SymbolicTraits = []
        if bold { traits.insert(.traitBold) }
        if italic { traits.insert(.traitItalic) }
        let base = UIFont.systemFont(ofSize: 17.0).fontDescriptor
        var result: [NSAttributedString.Key: Any] = [:]
        if let descriptor = base.withSymbolicTraits(traits) {
            result[.font] = UIFont(descriptor: descriptor, size: 17.0)
        }
        if underline { result[.underlineStyle] = NSUnderlineStyle.single.rawValue }
        if strike { result[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
        return result
    }

    /// The host arm's per-character trait names, in the SAME vocabulary and order
    /// `IDNormalizedInlineTraitNames` uses, read off the document model. A structural paragraph
    /// boundary contributes one `"\n"` character carrying no traits, matching what the canonical
    /// text projection emits — so this array is index-aligned with `Reading.text`.
    private func hostTraitsPerCharacter(_ editor: RichTextEditorView) -> [[String]] {
        var result: [[String]] = []
        var first = true
        for block in editor.document.blocks {
            guard case let .paragraph(paragraph) = block else { continue }
            if !first { result.append([]) }          // the structural "\n"
            first = false
            for run in paragraph.runs {
                var names: [String] = []
                if run.attributes.bold { names.append("bold") }
                if run.attributes.italic { names.append("italic") }
                if run.attributes.underline { names.append("underline") }
                if run.attributes.strikethrough { names.append("strikethrough") }
                for _ in 0..<(run.text as NSString).length { result.append(names) }
            }
        }
        return result
    }

    /// Selects `range` on the host's character axis. Returns false when the axis map cannot realise
    /// it, so a test reports "the selection could not be made" rather than asserting against
    /// whatever selection happened to be there.
    @discardableResult
    private func selectHost(_ editor: RichTextEditorView, _ range: NSRange) -> Bool {
        let canvas = IDStockParity.input(of: editor)
        guard let textRange = IDStockParity.textRange(canvas, forCharacterRange: range) else { return false }
        canvas.selectedTextRange = textRange
        return true
    }

    /// Kernel-witness failures are an InputDec-only signal (Legacy has no kernel), so they are
    /// asserted on their own rather than folded into the three-arm comparison.
    private func assertNoKernelFailures(_ scenario: String, file: StaticString = #filePath,
                                        line: UInt = #line) {
        IDStockParity.assertNoKernelFailures(violations, scenario, file: file, line: line)
    }

    // MARK: - 0. Calibration — the character-axis map is not the cause

    /// **The objection this test exists to kill.** Tests 2–6 below report that the InputDec backend
    /// applies every caret mutation ONE CHARACTER TOO WIDE: `insertText` overwrites the character
    /// after the caret, `deleteBackward` removes two. The obvious counter-explanation is that the
    /// *harness* aimed one character off — every one of those tests positions its caret through
    /// `IDTelegramCharacterRangeForTextRange`'s inverse, and `IDTelegramCharacterAxis.h` itself warns
    /// at length that naive offset arithmetic on this axis is "wrong past a boundary, and wrong
    /// quietly".
    ///
    /// So this test reproduces both halves **without calling the map at all**. The caret is placed by
    /// `RichTextEditorView.moveCaretToDocumentEnd()` — production API, which resolves the end through
    /// the backend's own `endOfDocument` — and the document is a single paragraph with no structural
    /// boundary anywhere near the edit. If these fail, the off-by-one is in the backend; if they
    /// pass while 2–6 fail, the map is the suspect and every verdict below needs re-deriving.
    ///
    /// `XCTSkipUnless` is deliberately NOT used to soften this: the assertions run on both host arms.
    func test_0_calibrationCaretMutationsAtDocumentEndWithoutTheAxisMap() throws {
        let scenario = "map-free: caret at end of \"ab\", one backspace / one insert"

        // --- stock arm ---
        let stockDelete = IDStockParity.makeStock(text: "ab")
        let stockInsert = IDStockParity.makeStock(text: "ab")
        IDStockParity.host([stockDelete, stockInsert], in: self)
        stockDelete.selectedRange = NSRange(location: 2, length: 0)
        stockDelete.deleteBackward()
        stockInsert.selectedRange = NSRange(location: 2, length: 0)
        stockInsert.insertText("X")
        XCTAssertEqual(stockDelete.text, "a",
                       "the ORACLE moved: one backspace no longer removes one character")
        XCTAssertEqual(stockInsert.text, "abX", "the ORACLE moved")

        // --- host arms ---
        func run(_ backend: RichTextEditorInputBackendPreference) throws -> (String, String) {
            let deleteEditor = try hostArm(["ab"], backend)
            deleteEditor.moveCaretToDocumentEnd()
            IDStockParity.input(of: deleteEditor).deleteBackward()
            let insertEditor = try hostArm(["ab"], backend)
            insertEditor.moveCaretToDocumentEnd()
            IDStockParity.input(of: insertEditor).insertText("X")
            return (IDStockParity.plainText(IDStockParity.input(of: deleteEditor)),
                    IDStockParity.plainText(IDStockParity.input(of: insertEditor)))
        }
        let (idDeleted, idInserted) = try run(.inputDecIfSupported)
        let (legacyDeleted, legacyInserted) = try run(.legacy)

        // `UITextView.text` is `String!`; `.debugDescription` on it renders `Optional("a")`, which
        // would differ from the host arms' plain `"a"` for no reason and mis-tag the verdict. A first
        // run did exactly that and reported PRE-EXISTING where the truth is PORT-DEFECT.
        IDStockParity.assertField("text after one backspace", scenario: scenario,
                                  stock: (stockDelete.text ?? "").debugDescription,
                                  inputDec: idDeleted.debugDescription,
                                  legacy: legacyDeleted.debugDescription,
                                  note: "no call to the character-axis map was made in this test")
        IDStockParity.assertField("text after one insert", scenario: scenario,
                                  stock: (stockInsert.text ?? "").debugDescription,
                                  inputDec: idInserted.debugDescription,
                                  legacy: legacyInserted.debugDescription,
                                  note: "no call to the character-axis map was made in this test")
    }

    // MARK: - 1. Caret movement across a mixed run boundary

    /// Upstream: `testStockCaretTypingAttributesAtStartInteriorEndAndMixedBoundary`.
    ///
    /// Upstream's own assertions are only two — the four selections round-trip as
    /// `{0,0} {1,0} {2,0} {4,0}`, and the text is unchanged. (Its `typing` snapshots are logged,
    /// never asserted; nothing is dropped by not porting a log.) The claim is therefore
    /// **"setting a caret at each of four offsets, including across a formatting-run boundary, reads
    /// back exactly that caret and mutates nothing"**, which both host arms must satisfy too.
    func test_1_caretPlacementAtStartInteriorEndAndMixedRunBoundary() throws {
        let scenario = "caret placement at 0/1/2/4 across a bold|italic run boundary"

        // --- stock arm (upstream's assertions, verbatim) ---
        let stock = try stockArm("abcd")
        stock.textStorage.setAttributes(attributes(bold: true, italic: false, underline: false,
                                                   strike: false), range: NSRange(location: 0, length: 2))
        stock.textStorage.setAttributes(attributes(bold: false, italic: true, underline: false,
                                                   strike: false), range: NSRange(location: 2, length: 2))
        var stockSelections: [String] = []
        for offset in [0, 1, 2, 4] {
            stock.selectedRange = NSRange(location: offset, length: 0)
            stockSelections.append(NSStringFromRange(stock.selectedRange))
        }
        XCTAssertEqual(stockSelections, ["{0, 0}", "{1, 0}", "{2, 0}", "{4, 0}"],
                       "the ORACLE moved: UIKit no longer round-trips a caret set at these offsets")
        XCTAssertEqual(stock.text, "abcd")
        let stockReading = reading(of: stock)

        // --- host arms ---
        func hostSelections(_ backend: RichTextEditorInputBackendPreference)
            throws -> (IDStockParity.Reading, [String]) {
            let editor = try hostArm(["abcd"], backend)
            XCTAssertTrue(selectHost(editor, NSRange(location: 0, length: 2)))
            editor.toggleBold()
            XCTAssertTrue(selectHost(editor, NSRange(location: 2, length: 2)))
            editor.toggleItalic()
            var selections: [String] = []
            for offset in [0, 1, 2, 4] {
                XCTAssertTrue(selectHost(editor, NSRange(location: offset, length: 0)),
                              "the character axis could not realise a caret at \(offset) "
                              + "(backend \(backend))")
                let canvas = IDStockParity.input(of: editor)
                selections.append(IDStockParity.characterRange(canvas, canvas.selectedTextRange)
                    .map(NSStringFromRange) ?? "(no selection)")
            }
            return (reading(of: editor), selections)
        }
        let (idReading, idSelections) = try hostSelections(.inputDecIfSupported)
        let capturedViolations = violations.messages
        let (legacyReading, legacySelections) = try hostSelections(.legacy)

        IDStockParity.assertField("caret round-trip", scenario: scenario,
                                  stock: stockSelections.joined(separator: " "),
                                  inputDec: idSelections.joined(separator: " "),
                                  legacy: legacySelections.joined(separator: " "))
        IDStockParity.assertField("text", scenario: scenario,
                                  stock: stockReading.text.debugDescription,
                                  inputDec: idReading.text.debugDescription,
                                  legacy: legacyReading.text.debugDescription,
                                  note: "placing carets must mutate nothing")
        IDStockParity.assertField("traits", scenario: scenario,
                                  stock: stockReading.traitsDescription,
                                  inputDec: idReading.traitsDescription,
                                  legacy: legacyReading.traitsDescription,
                                  note: "the fixture's own bold|italic runs, before any caret moved")
        XCTAssertEqual(capturedViolations, [],
                       "[PORT-DEFECT] \(scenario) · the InputDec kernel reported contract violations")
    }

    // MARK: - 2. Explicit caret formatting, then insert, then Return

    /// Upstream: `testStockExplicitCaretToggleThenInsertAndReturn`.
    ///
    /// Upstream sets `typingAttributes` to bold at a collapsed caret, types `X`, `\n`, `Y`, and pins
    /// three claims: the resulting text; that `X` is bold; and that the character after the newline
    /// (`Y`) is **not** — UIKit drops the explicit typing override across a paragraph break. The host
    /// arms express "set the caret's formatting" as `toggleBold()` at a collapsed caret, the only
    /// spelling this editor has.
    func test_2_explicitCaretBoldThenInsertAndReturn() throws {
        let scenario = "toggle bold at caret 1 of \"ab\", then type X, Return, Y"

        // --- stock arm (upstream's assertions, verbatim) ---
        let stock = try stockArm("ab")
        stock.selectedRange = NSRange(location: 1, length: 0)
        stock.typingAttributes = attributes(bold: true, italic: false, underline: false, strike: false)
        stock.insertText("X")
        stock.insertText("\n")
        stock.insertText("Y")
        XCTAssertEqual(stock.text, "aX\nYb", "the ORACLE moved")
        let stockReading = reading(of: stock)
        XCTAssertEqual(stockReading.traits[1], ["bold"], "the ORACLE moved: X is no longer bold")
        XCTAssertEqual(stockReading.traits[3], [],
                       "the ORACLE moved: UIKit no longer drops the typing override across a Return")
        // Upstream's `IDNormalizedInlineRuns(self.view.textStorage)[2][@"traits"] == @[]`
        // (`IDInlineFormattingStockOracleTests.m:158-161`), PORTED — on the stock arm only, which is
        // where it is expressible: the run array is derived from a single `NSTextStorage` and the
        // host has none spanning the document. Task P1 dropped it without a record; the P1 review
        // caught that, and an undocumented divergence from upstream is the thing a later reader
        // mistakes for upstream's own claim. It adds little over the per-character read above — the
        // point is that it is now either ported or recorded, never silently absent.
        let stockRuns = IDNormalizedInlineRuns(stock.textStorage) as NSArray
        XCTAssertGreaterThan(stockRuns.count, 2,
                             "the ORACLE moved: \"aX\\nYb\" no longer has a third inline run")
        XCTAssertEqual((stockRuns[2] as? [String: Any])?["traits"] as? [String], [],
                       "the ORACLE moved: the third run of \"aX\\nYb\" is no longer trait-free")

        // --- host arms ---
        func run(_ backend: RichTextEditorInputBackendPreference) throws -> IDStockParity.Reading {
            let editor = try hostArm(["ab"], backend)
            XCTAssertTrue(selectHost(editor, NSRange(location: 1, length: 0)))
            editor.toggleBold()
            let canvas = IDStockParity.input(of: editor)
            canvas.insertText("X")
            canvas.insertText("\n")
            canvas.insertText("Y")
            return reading(of: editor)
        }
        let idReading = try run(.inputDecIfSupported)
        let capturedViolations = violations.messages
        let legacyReading = try run(.legacy)

        IDStockParity.assertReading(
            scenario: scenario, stock: stockReading, inputDec: idReading, legacy: legacyReading,
            note: "a character typed after toggling bold at a CARET must be bold, as stock's is. "
                + "`DocumentCanvasView+CharacterFormat.swift` documents a collapsed-caret toggle as "
                + "a no-op ('collapsed typing attributes are deferred'), which — if this reports "
                + "PRE-EXISTING — is the mechanism, and it predates the InputDec port.")
        XCTAssertEqual(capturedViolations, [],
                       "[PORT-DEFECT] \(scenario) · the InputDec kernel reported contract violations")
    }

    // MARK: - 3. Formatting a selection replacement

    /// Upstream: `testStockSelectionReplacementFormatting`. Selects `{1,2}` of `"abcd"`, sets the
    /// typing attributes to italic + underline, types `Z`, and requires the replacement character to
    /// carry BOTH and the caret to land at `{2,0}`.
    func test_3_selectionReplacementCarriesTheChosenFormatting() throws {
        let scenario = "italic+underline on \"bc\" of \"abcd\", then type Z over the selection"

        // --- stock arm (upstream's assertions, verbatim) ---
        let stock = try stockArm("abcd")
        stock.selectedRange = NSRange(location: 1, length: 2)
        stock.typingAttributes = attributes(bold: false, italic: true, underline: true, strike: false)
        stock.insertText("Z")
        XCTAssertEqual(stock.text, "aZd", "the ORACLE moved")
        let stockReading = reading(of: stock)
        XCTAssertEqual(stockReading.traits[1], ["italic", "underline"], "the ORACLE moved")
        XCTAssertEqual(stockReading.selection, "{2, 0}", "the ORACLE moved")

        // --- host arms ---
        func run(_ backend: RichTextEditorInputBackendPreference) throws -> IDStockParity.Reading {
            let editor = try hostArm(["abcd"], backend)
            XCTAssertTrue(selectHost(editor, NSRange(location: 1, length: 2)))
            editor.toggleItalic()
            editor.toggleUnderline()
            XCTAssertTrue(selectHost(editor, NSRange(location: 1, length: 2)),
                          "re-selecting after the toggles (backend \(backend))")
            IDStockParity.input(of: editor).insertText("Z")
            return reading(of: editor)
        }
        let idReading = try run(.inputDecIfSupported)
        let capturedViolations = violations.messages
        let legacyReading = try run(.legacy)

        IDStockParity.assertReading(
            scenario: scenario, stock: stockReading, inputDec: idReading, legacy: legacyReading,
            note: "typing over a formatted selection must replace EXACTLY that selection and the "
                + "replacement must inherit its formatting")
        XCTAssertEqual(capturedViolations, [],
                       "[PORT-DEFECT] \(scenario) · the InputDec kernel reported contract violations")
    }

    // MARK: - 4. Return at the end of the document

    /// Upstream: `testStockExplicitTypingOverrideMovementAndReturnAtEnd`.
    ///
    /// **Four of upstream's EIGHT assertions are dropped**, all four `typingAttributes` reads:
    /// `explicit[@"typing"] == [bold]`, `moved[@"typing"] == [italic]`,
    /// `returned[@"typing"] == [bold]`, `typed[@"typing"] == [bold]`
    /// (`IDInlineFormattingStockOracleTests.m:215-226`; counts derived by
    /// `sed -n '/testStockExplicitTypingOverrideMovementAndReturnAtEnd/,/^}/p' … | grep -c XCTAssert`
    /// = 8 and the same with `grep -c '@"typing"'` = 4). All four read `typingAttributes` directly
    /// and there is no `UITextInput` way to ask a host the same question.
    ///
    /// *(Task P1 recorded this as "two of five", both here and in `PROVENANCE.md`. Corrected in
    /// Task P2 after the P1 review re-derived it from upstream. The four surviving assertions are
    /// unchanged either way; only the count was wrong.)*
    ///
    /// Upstream's remaining, *observable* claims are kept and are the load-bearing ones — the text
    /// after Return-then-type, both caret positions, and that the character typed after a Return at
    /// the end of the document carries the re-applied bold.
    func test_4_returnAtEndOfDocumentKeepsTheReAppliedFormatting() throws {
        let scenario = "bold re-applied after a Return at the end of \"ab\", then type Y"

        // --- stock arm (upstream's assertions minus the four typingAttributes reads) ---
        let stock = try stockArm("ab")
        stock.textStorage.setAttributes(attributes(bold: false, italic: true, underline: false,
                                                   strike: false), range: NSRange(location: 1, length: 1))
        stock.selectedRange = NSRange(location: 0, length: 0)
        stock.typingAttributes = attributes(bold: true, italic: false, underline: false, strike: false)
        stock.selectedRange = NSRange(location: 2, length: 0)
        stock.typingAttributes = attributes(bold: true, italic: false, underline: false, strike: false)
        stock.insertText("\n")
        let stockAfterReturn = NSStringFromRange(stock.selectedRange)
        stock.insertText("Y")
        XCTAssertEqual(stock.text, "ab\nY", "the ORACLE moved")
        XCTAssertEqual(stockAfterReturn, "{3, 0}", "the ORACLE moved")
        let stockReading = reading(of: stock)
        XCTAssertEqual(stockReading.selection, "{4, 0}", "the ORACLE moved")
        XCTAssertEqual(stockReading.traits[3], ["bold"], "the ORACLE moved")

        // --- host arms ---
        func run(_ backend: RichTextEditorInputBackendPreference)
            throws -> (IDStockParity.Reading, String) {
            let editor = try hostArm(["ab"], backend)
            XCTAssertTrue(selectHost(editor, NSRange(location: 1, length: 1)))
            editor.toggleItalic()
            XCTAssertTrue(selectHost(editor, NSRange(location: 2, length: 0)))
            editor.toggleBold()
            let canvas = IDStockParity.input(of: editor)
            canvas.insertText("\n")
            let afterReturn = IDStockParity.characterRange(canvas, canvas.selectedTextRange)
                .map(NSStringFromRange) ?? "(no selection)"
            // Mirrors upstream's SECOND `typingAttributes =`: the override does not survive the
            // Return on stock either, so both arms re-apply it before typing.
            editor.toggleBold()
            canvas.insertText("Y")
            return (reading(of: editor), afterReturn)
        }
        let (idReading, idAfterReturn) = try run(.inputDecIfSupported)
        let capturedViolations = violations.messages
        let (legacyReading, legacyAfterReturn) = try run(.legacy)

        IDStockParity.assertField("selection after Return", scenario: scenario,
                                  stock: stockAfterReturn, inputDec: idAfterReturn,
                                  legacy: legacyAfterReturn)
        IDStockParity.assertReading(
            scenario: scenario, stock: stockReading, inputDec: idReading, legacy: legacyReading,
            note: "a character typed after re-applying bold following a Return must be bold")
        XCTAssertEqual(capturedViolations, [],
                       "[PORT-DEFECT] \(scenario) · the InputDec kernel reported contract violations")
    }

    // MARK: - 5. Delete across a run boundary

    /// Upstream: `testStockDeleteAcrossRunBoundaryReconcilesTypingAttributes`. `"ab"` with bold `a`
    /// and italic `b`, caret at 1, `deleteBackward` → `"b"`, caret `{0,0}`, and the run array
    /// changed.
    ///
    /// Upstream's third claim is `XCTAssertNotEqualObjects(before[runs], after[runs])`. The host arms
    /// re-express it as "the surviving character is still italic and carries nothing else" — a
    /// **stronger** statement, chosen because `!=` is trivially satisfiable and would be a weaker
    /// claim than upstream's on a host whose run array is derived differently. Recorded as a
    /// re-expression, not a loosening.
    func test_5_deleteBackwardAcrossARunBoundary() throws {
        let scenario = "deleteBackward at caret 1 of bold(a)+italic(b)"

        // --- stock arm (upstream's assertions, verbatim) ---
        let stock = try stockArm("ab")
        stock.textStorage.setAttributes(attributes(bold: true, italic: false, underline: false,
                                                   strike: false), range: NSRange(location: 0, length: 1))
        stock.textStorage.setAttributes(attributes(bold: false, italic: true, underline: false,
                                                   strike: false), range: NSRange(location: 1, length: 1))
        stock.selectedRange = NSRange(location: 1, length: 0)
        let stockRunsBefore = IDNormalizedInlineRuns(stock.textStorage) as NSArray
        stock.deleteBackward()
        let stockRunsAfter = IDNormalizedInlineRuns(stock.textStorage) as NSArray
        XCTAssertEqual(stock.text, "b", "the ORACLE moved")
        XCTAssertNotEqual(stockRunsBefore, stockRunsAfter, "the ORACLE moved")
        let stockReading = reading(of: stock)
        XCTAssertEqual(stockReading.selection, "{0, 0}", "the ORACLE moved")
        XCTAssertEqual(stockReading.traits, [["italic"]], "the ORACLE moved")

        // --- host arms ---
        func run(_ backend: RichTextEditorInputBackendPreference)
            throws -> (IDStockParity.Reading, [[String]]) {
            let editor = try hostArm(["ab"], backend)
            XCTAssertTrue(selectHost(editor, NSRange(location: 0, length: 1)))
            editor.toggleBold()
            XCTAssertTrue(selectHost(editor, NSRange(location: 1, length: 1)))
            editor.toggleItalic()
            XCTAssertTrue(selectHost(editor, NSRange(location: 1, length: 0)))
            let before = hostTraitsPerCharacter(editor)
            IDStockParity.input(of: editor).deleteBackward()
            return (reading(of: editor), before)
        }
        let (idReading, idBefore) = try run(.inputDecIfSupported)
        let capturedViolations = violations.messages
        let (legacyReading, legacyBefore) = try run(.legacy)

        // The fixture itself, checked on both host arms before the behaviour under test — a fixture
        // that silently failed to apply would make the comparison below meaningless.
        XCTAssertEqual(idBefore, [["bold"], ["italic"]],
                       "the InputDec fixture did not take: the bold|italic runs were never applied")
        XCTAssertEqual(legacyBefore, [["bold"], ["italic"]],
                       "the Legacy fixture did not take: the bold|italic runs were never applied")

        IDStockParity.assertReading(
            scenario: scenario, stock: stockReading, inputDec: idReading, legacy: legacyReading,
            note: "one backspace at a caret must delete exactly ONE character and leave the "
                + "surviving character's formatting alone")
        XCTAssertEqual(capturedViolations, [],
                       "[PORT-DEFECT] \(scenario) · the InputDec kernel reported contract violations")
    }

    // MARK: - 6. Undo / redo restores formatting

    /// Upstream: `testStockUndoRedoRestoresFormattingAndTypingState`. Upstream drives
    /// `view.undoManager` directly with explicit grouping; the host arms inject their own manager
    /// (`undoManagerOverride`), the established in-tree way to make the editor's undo deterministic
    /// (`EditorFormatFacadeTests.test_facade_undo_revertsFormatting`).
    ///
    /// The `canUndo`/`canRedo` **snapshot fields** are dropped (see the type comment). `canUndo` and
    /// `canRedo` are still asserted per arm as preconditions — an arm that recorded nothing undoable
    /// would otherwise "restore" trivially and read as agreement.
    func test_6_undoRedoRestoresFormattingAndText() throws {
        let scenario = "undo then redo of an insert at caret 1 of \"ab\""

        // --- stock arm (upstream's assertions, verbatim) ---
        let stock = try stockArm("ab")
        stock.selectedRange = NSRange(location: 1, length: 0)
        stock.typingAttributes = attributes(bold: true, italic: false, underline: false, strike: true)
        stock.undoManager?.beginUndoGrouping()
        stock.insertText("X")
        stock.undoManager?.endUndoGrouping()
        let stockInserted = reading(of: stock)
        XCTAssertTrue(stock.undoManager?.canUndo ?? false, "the ORACLE moved")
        stock.undoManager?.undo()
        let stockUndone = reading(of: stock)
        XCTAssertEqual(stockUndone.text, "ab", "the ORACLE moved")
        XCTAssertTrue(stock.undoManager?.canRedo ?? false, "the ORACLE moved")
        stock.undoManager?.redo()
        let stockRedone = reading(of: stock)
        XCTAssertEqual(stockRedone.text, "aXb", "the ORACLE moved")
        XCTAssertEqual(stockInserted.traits, stockRedone.traits, "the ORACLE moved")

        // --- host arms ---
        struct UndoTrace { var inserted: IDStockParity.Reading; var undone: IDStockParity.Reading
                           var redone: IDStockParity.Reading; var canUndo: Bool; var canRedo: Bool }
        func run(_ backend: RichTextEditorInputBackendPreference) throws -> UndoTrace {
            let editor = try hostArm(["ab"], backend)
            let manager = UndoManager()
            manager.groupsByEvent = false
            editor.canvasForTesting.undoManagerOverride = manager
            XCTAssertTrue(selectHost(editor, NSRange(location: 1, length: 0)))
            let canvas = IDStockParity.input(of: editor)
            manager.beginUndoGrouping()
            canvas.insertText("X")
            manager.endUndoGrouping()
            let inserted = reading(of: editor)
            let canUndo = manager.canUndo
            manager.undo()
            let undone = reading(of: editor)
            let canRedo = manager.canRedo
            manager.redo()
            return UndoTrace(inserted: inserted, undone: undone, redone: reading(of: editor),
                             canUndo: canUndo, canRedo: canRedo)
        }
        let id = try run(.inputDecIfSupported)
        let capturedViolations = violations.messages
        let legacy = try run(.legacy)

        XCTAssertTrue(id.canUndo, "the InputDec arm recorded no undoable insert — 'restore' below "
                                + "would be vacuous")
        XCTAssertTrue(legacy.canUndo, "the Legacy arm recorded no undoable insert")
        XCTAssertTrue(id.canRedo, "the InputDec arm recorded no redoable undo")
        XCTAssertTrue(legacy.canRedo, "the Legacy arm recorded no redoable undo")

        IDStockParity.assertField("text after insert", scenario: scenario,
                                  stock: stockInserted.text.debugDescription,
                                  inputDec: id.inserted.text.debugDescription,
                                  legacy: legacy.inserted.text.debugDescription)
        IDStockParity.assertField("text after undo", scenario: scenario,
                                  stock: stockUndone.text.debugDescription,
                                  inputDec: id.undone.text.debugDescription,
                                  legacy: legacy.undone.text.debugDescription)
        IDStockParity.assertField("text after redo", scenario: scenario,
                                  stock: stockRedone.text.debugDescription,
                                  inputDec: id.redone.text.debugDescription,
                                  legacy: legacy.redone.text.debugDescription)
        IDStockParity.assertField("traits after redo == traits after insert", scenario: scenario,
                                  stock: "\(stockInserted.traitsDescription == stockRedone.traitsDescription)",
                                  inputDec: "\(id.inserted.traitsDescription == id.redone.traitsDescription)",
                                  legacy: "\(legacy.inserted.traitsDescription == legacy.redone.traitsDescription)")
        XCTAssertEqual(capturedViolations, [],
                       "[PORT-DEFECT] \(scenario) · the InputDec kernel reported contract violations")
    }
}
#endif
