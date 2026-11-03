#if canImport(UIKit)
import XCTest
import UIKit
import RichTextEditorDifferentialHarness
import RichTextEditorCore
@testable import RichTextEditorUIKit

/// Task 9c, Step 4 — **the Telegram-side state recorder, and the two rulings it has to satisfy.**
///
/// The plan asks for "a recorder test on a hand-built scenario, asserting the snapshot's shape and
/// that unsupported fields are absent rather than zero". That is the first section. The rest of the
/// suite exists because the recorder is where the sampling contract is fixed, and two of its
/// decisions are load-bearing for every number Task 9d will report:
///
///  1. **The axis is MAPPED, not excused.** `selection` is compared by all 68 scenarios and 58 of
///     them touch a paragraph boundary (measured), so a named expectation excusing the editor's
///     sparse position axis would hollow out the oracle. Every position is converted onto the stock
///     CHARACTER axis before it is reported, and the map is validated against stock ground truth.
///  2. **A declined field is DATA, not an omission.** `IDCompareTextInputSnapshotPair` treats two
///     `nil`s as equal, so a field absent from both snapshots reports agreement on something never
///     measured. The declined list is published so Task 9d can subtract it from `comparisonFields`,
///     and this suite pins that the published list is exactly what the recorder actually declines.
final class TelegramDifferentialRecorderTests: XCTestCase {

    override func setUp() {
        super.setUp()
        TelegramDifferentialInputFactory.install()
    }

    override func tearDown() {
        TelegramDifferentialInputFactory.uninstall()
        super.tearDown()
    }

    // MARK: - Step 4: the snapshot's shape

    /// Every field the corpus names is either SERVED or DECLINED, and the declined ones are
    /// **absent** — not zero, not an empty array. A defaulted field is a false comparison, which is
    /// worse than a missing one, and the vendored comparator cannot tell the two apart.
    func test_theSnapshotServesEveryComparisonFieldExceptTheDeclinedOnes_whichAreAbsent() throws {
        let declined = Set(IDTelegramDeclinedComparisonFields())
        for fileName in DifferentialCorpus.fileNames {
            let scenario = try DifferentialCorpus.firstScenario(inFile: fileName)
            let host = try makeHost(.reference, scenario)
            let recorder = IDTextInputStateRecorder(host: host)
            defer { recorder.detach() }
            let snapshot = recorder.capturePhase("baseline")

            XCTAssertEqual(snapshot.phase, "baseline")
            for field in scenario.comparisonFields {
                if declined.contains(field) {
                    XCTAssertNil(snapshot.state[field],
                                 "\(fileName): \(field) is declined and must be ABSENT, not defaulted "
                                 + "— two nils compare equal in the vendored runner")
                } else {
                    XCTAssertNotNil(snapshot.state[field],
                                    "\(fileName): \(field) is compared by this scenario and must be served")
                }
            }
        }
    }

    /// The stock arm serves the full set, including the two the Telegram arm declines. That is what
    /// makes an unfiltered `comparisonFields` fail LOUDLY (a value against a `nil`) rather than
    /// silently — and it is the ground truth that validates the decline as a property of the editor
    /// rather than of the recorder.
    func test_theStockSnapshotServesEveryFieldIncludingTheOnesTelegramDeclines() throws {
        TelegramDifferentialInputFactory.uninstall()
        let scenario = try DifferentialCorpus.firstScenario(inFile: "ime-ios26.5-v1")
        let host = try makeHost(.stock, scenario)
        let recorder = IDTextInputStateRecorder(host: host)
        defer { recorder.detach() }
        let snapshot = recorder.capturePhase("baseline")

        for field in scenario.comparisonFields {
            XCTAssertNotNil(snapshot.state[field], "stock must serve \(field)")
        }
        let declines = snapshot.state[IDTelegramSnapshotDeclinesKey] as? [String: String] ?? [:]
        XCTAssertTrue(declines.isEmpty, "a stock host declines nothing: \(declines)")
    }

    /// The published declined list is not a hand-maintained constant that can drift: it must equal
    /// what a Telegram host's recorder actually refuses to sample, and it must be empty for stock.
    /// Each entry must also carry a stated reason — gate item 12's requirement, sourced here rather
    /// than re-derived in Task 9d.
    func test_thePublishedDeclinedListIsExactlyWhatTheRecorderDeclines_andEachCarriesAReason() throws {
        let published = IDTelegramDeclinedComparisonFields()
        let reasons = IDTelegramDeclinedComparisonFieldReasons()
        XCTAssertEqual(Set(published), Set(reasons.keys),
                       "every declined field must carry a stated reason")
        for (field, reason) in reasons {
            XCTAssertFalse(reason.isEmpty, "\(field)'s reason is empty")
        }

        let scenario = try DifferentialCorpus.firstScenario(inFile: "ime-ios26.5-v1")
        let telegram = try makeHost(.reference, scenario)
        let telegramRecorder = IDTextInputStateRecorder(host: telegram)
        defer { telegramRecorder.detach() }
        let telegramDeclines = telegramRecorder.capturePhase("baseline")
            .state[IDTelegramSnapshotDeclinesKey] as? [String: String] ?? [:]
        XCTAssertEqual(Set(telegramDeclines.keys), Set(published),
                       "the recorder's measured declines and the published list disagree")
    }

    /// Task 9d's Step 2b, made executable: the filter REMOVES the declined fields from the list the
    /// runner is given, preserving order, so a declined field is *visibly not compared* rather than
    /// invisibly equal.
    func test_theComparableFieldFilterRemovesExactlyTheDeclinedFields_preservingOrder() throws {
        for scenario in try DifferentialCorpus.allScenarios() {
            let filtered = IDTelegramComparableFields(scenario.comparisonFields)
            let declined = Set(IDTelegramDeclinedComparisonFields())
            XCTAssertEqual(filtered, scenario.comparisonFields.filter { !declined.contains($0) },
                           "\(scenario.identifier): the filter must subtract exactly the declined fields, in order")
            for field in filtered {
                XCTAssertFalse(declined.contains(field))
            }
        }

        // The inline-formatting family loses NOTHING: neither declined field appears in its
        // contract. That is the measurement that says how much the two declines actually cost.
        for scenario in try DifferentialCorpus.scenarios(inFile: "inline-formatting-ios26.5-v1") {
            XCTAssertEqual(IDTelegramComparableFields(scenario.comparisonFields), scenario.comparisonFields)
        }
        // The other three lose exactly two of fourteen.
        for fileName in ["ime-ios26.5-v1", "autocorrection-ios26.5-v1", "inline-prediction-ios26.5-v1"] {
            for scenario in try DifferentialCorpus.scenarios(inFile: fileName) {
                XCTAssertEqual(scenario.comparisonFields.count, 14)
                XCTAssertEqual(IDTelegramComparableFields(scenario.comparisonFields).count, 12)
            }
        }
    }

    // MARK: - The axis map (Task 9d Step 3a, revised ruling)

    /// **The map, against stock ground truth.** For a `UITextView` the character index of a position
    /// IS `offsetFromPosition:`, so running the recorder's map on the stock arm must reproduce that
    /// number for every position in the document. If it does not, the map is wrong and every
    /// Telegram number it produces is untrustworthy.
    func test_theMapReproducesOffsetFromPositionOnStock_atEveryPosition() throws {
        TelegramDifferentialInputFactory.uninstall()
        let scenario = try DifferentialCorpus.firstScenario(inFile: "ime-ios26.5-v1")
        let host = try makeHost(.stock, scenario)
        let input = host.input

        let length = (scenario.initialText as NSString).length
        for offset in 0...length {
            let position = try XCTUnwrap(input.position(from: input.beginningOfDocument, offset: offset))
            let range = try XCTUnwrap(input.textRange(from: input.beginningOfDocument, to: position))
            let mapped = (input.text(in: range) ?? "" as String)
            XCTAssertEqual((mapped as NSString).length, offset,
                           "stock: the prefix-length map must equal offsetFromPosition at \(offset)")
            XCTAssertEqual(input.offset(from: input.beginningOfDocument, to: position), offset)
        }
    }

    /// **The whole point of the ruling.** The editor's raw `offsetFromPosition:` for the second
    /// paragraph's first character is 20 (measured by Task 9b); stock's is 19. The recorder must
    /// report **19** — the same number as stock — for the same caret.
    func test_selectionIsReportedOnTheStockCharacterAxis_pastAParagraphBoundary() throws {
        let scenario = try DifferentialCorpus.firstScenario(inFile: "ime-ios26.5-v1")
        XCTAssertEqual(scenario.initialText, "Alpha middle omega\nSecond block remains unchanged.")

        let telegram = try makeHost(.reference, scenario)
        let input = telegram.input
        // The caret immediately before "Second": character index 19, raw slot 21.
        let caret = try XCTUnwrap(IDTelegramPositionForCharacterIndex(input, 19))
        XCTAssertEqual(input.offset(from: input.beginningOfDocument, to: caret), 20,
                       "the raw axis is still sparse — the map is what fixes the report, not the editor")
        input.selectedTextRange = input.textRange(from: caret, to: caret)

        let recorder = IDTextInputStateRecorder(host: telegram)
        defer { recorder.detach() }
        let selection = try XCTUnwrap(recorder.capturePhase("p").state["selection"] as? [String: Int])
        XCTAssertEqual(selection["location"], 19, "the recorder must report the STOCK character index")
        XCTAssertEqual(selection["length"], 0)

        // And the same caret on stock reports the same pair — which is the comparison Task 9d runs.
        TelegramDifferentialInputFactory.uninstall()
        let stock = try makeHost(.stock, scenario)
        let stockCaret = try XCTUnwrap(IDTelegramPositionForCharacterIndex(stock.input, 19))
        stock.input.selectedTextRange = stock.input.textRange(from: stockCaret, to: stockCaret)
        let stockRecorder = IDTextInputStateRecorder(host: stock)
        defer { stockRecorder.detach() }
        XCTAssertEqual(stockRecorder.capturePhase("p").state["selection"] as? [String: Int],
                       selection, "mapped Telegram selection must equal stock's, exactly")
    }

    /// A RANGED selection spanning the boundary: length must be the character count, not the slot
    /// count. Without the map the editor would report one more than stock for every crossed boundary.
    func test_aSelectionSpanningTheBoundaryReportsCharacterLength_notSlotLength() throws {
        let scenario = try DifferentialCorpus.firstScenario(inFile: "ime-ios26.5-v1")
        let telegram = try makeHost(.reference, scenario)
        let input = telegram.input
        let range = try XCTUnwrap(IDTelegramTextRangeForCharacterRange(input, NSRange(location: 12, length: 13)))
        input.selectedTextRange = range

        let recorder = IDTextInputStateRecorder(host: telegram)
        defer { recorder.detach() }
        let selection = try XCTUnwrap(recorder.capturePhase("p").state["selection"] as? [String: Int])
        let rawSpan = input.offset(from: range.start, to: range.end)

        XCTAssertEqual(selection["location"], 12)
        XCTAssertEqual(selection["length"], 13, "characters 12..<25, which span the boundary")
        XCTAssertEqual(rawSpan, 14, "the raw span charges the boundary a slot the text does not have")
    }

    /// **The trap the inverse map exists for, pinned with the numbers that expose it.**
    /// `-positionFromPosition:offset:` does RAW-offset arithmetic and then snaps, so aiming at a
    /// character index with it lands one character early past every structural boundary. A driver
    /// built on it would apply every post-boundary edit to the wrong character, the recorder would
    /// faithfully report the resulting text, and the difference would be blamed on the editor's
    /// EDITING rather than on the harness's aim. (Found by this suite: two of its tests were written
    /// that way and failed against a correct recorder.)
    func test_positionFromBeginningAimsOneCharacterEarlyPastABoundary_whichIsWhyTheInverseMapExists() throws {
        let scenario = try DifferentialCorpus.firstScenario(inFile: "ime-ios26.5-v1")
        let telegram = try makeHost(.reference, scenario)
        let input = telegram.input

        func characterIndex(_ position: UITextPosition?) -> Int? {
            IDTelegramCharacterIndexForPosition(input, position)?.intValue
        }
        // Before the boundary the two spellings agree...
        XCTAssertEqual(characterIndex(input.position(from: input.beginningOfDocument, offset: 12)), 12)
        // ...and after it they do not.
        XCTAssertEqual(characterIndex(input.position(from: input.beginningOfDocument, offset: 25)), 24,
                       "raw-offset arithmetic lands on raw 26, which is character 24")
        XCTAssertEqual(characterIndex(IDTelegramPositionForCharacterIndex(input, 25)), 25,
                       "the inverse map steps the input's own positions and lands on character 25")

        // Stock has no such gap, which is exactly why an improvised driver would look correct there.
        TelegramDifferentialInputFactory.uninstall()
        let stock = try makeHost(.stock, scenario)
        XCTAssertEqual(IDTelegramCharacterIndexForPosition(
            stock.input, stock.input.position(from: stock.input.beginningOfDocument, offset: 25))?.intValue, 25)
    }

    /// The inverse round-trips every character index on both arms — the property Task 9d's driver
    /// depends on when it realises a scenario's character-coordinate range.
    func test_theInverseMapRoundTripsEveryCharacterIndexOnBothArms() throws {
        let scenario = try DifferentialCorpus.firstScenario(inFile: "ime-ios26.5-v1")
        let length = (scenario.initialText as NSString).length

        func check(_ host: IDTextInputTestHost, _ label: String) throws {
            for index in 0...length {
                let position = try XCTUnwrap(IDTelegramPositionForCharacterIndex(host.input, UInt(index)),
                                             "\(label): character \(index) is unreachable")
                XCTAssertEqual(IDTelegramCharacterIndexForPosition(host.input, position)?.intValue, index,
                               "\(label): round-trip failed at \(index)")
            }
            XCTAssertNil(IDTelegramPositionForCharacterIndex(host.input, UInt(length + 1)),
                         "\(label): an index past the end must be nil, not clamped")
        }

        try check(try makeHost(.reference, scenario), "telegram")
        TelegramDifferentialInputFactory.uninstall()
        try check(try makeHost(.stock, scenario), "stock")
    }

    /// `markedRange` lives on the same axis and gets the same treatment. Marked text is set past the
    /// boundary so the mapping is actually exercised.
    func test_markedRangeIsReportedOnTheStockCharacterAxisToo() throws {
        let scenario = try DifferentialCorpus.firstScenario(inFile: "ime-ios26.5-v1")

        func markedRange(_ host: IDTextInputTestHost) throws -> [String: Int] {
            let input = host.input
            XCTAssertTrue(input.becomeFirstResponder())
            let caret = try XCTUnwrap(IDTelegramPositionForCharacterIndex(input, 25))
            input.selectedTextRange = input.textRange(from: caret, to: caret)
            input.setMarkedText("ka", selectedRange: NSRange(location: 2, length: 0))
            let recorder = IDTextInputStateRecorder(host: host)
            defer { recorder.detach() }
            let snapshot = recorder.capturePhase("marked")
            XCTAssertEqual(snapshot.state["markedText"] as? String, "ka")
            return try XCTUnwrap(snapshot.state["markedRange"] as? [String: Int])
        }

        let telegram = try makeHost(.reference, scenario)
        let telegramMarked = try markedRange(telegram)
        TelegramDifferentialInputFactory.uninstall()
        let stock = try makeHost(.stock, scenario)
        let stockMarked = try markedRange(stock)

        XCTAssertEqual(telegramMarked, stockMarked,
                       "the mapped marked range must land on the same character indices as stock's")
        XCTAssertEqual(telegramMarked["location"], 25)
        XCTAssertEqual(telegramMarked["length"], 2)
    }

    /// **The residue, measured rather than asserted away.** Stepping the editor's own positions one
    /// at a time and mapping each: the sequence must be non-decreasing and must cover EVERY
    /// character index, so no caret the editor can reach is unrepresentable on the stock axis. The
    /// collisions (two positions, one index) are counted and pinned — they are the residue the
    /// ruling asks about.
    func test_theMapIsMonotoneAndSurjectiveOverEveryPositionTheEditorCanReach() throws {
        let scenario = try DifferentialCorpus.firstScenario(inFile: "ime-ios26.5-v1")
        let host = try makeHost(.reference, scenario)
        let input = host.input
        let canonicalLength = (scenario.initialText as NSString).length

        var indices: [Int] = []
        var position: UITextPosition? = input.beginningOfDocument
        var guardCounter = 0
        while let current = position, guardCounter < 4096 {
            guardCounter += 1
            let range = try XCTUnwrap(input.textRange(from: input.beginningOfDocument, to: current))
            indices.append(((input.text(in: range) ?? "") as NSString).length)
            guard let next = input.position(from: current, offset: 1),
                  input.compare(next, to: current) != .orderedSame else { break }
            position = next
        }

        XCTAssertEqual(indices, indices.sorted(), "the map must be monotone over the editor's own positions")
        XCTAssertEqual(Set(indices), Set(0...canonicalLength),
                       "every character index must be reachable: missing \(Set(0...canonicalLength).subtracting(indices).sorted())")
        let collisions = indices.count - Set(indices).count
        XCTAssertEqual(collisions, 0,
                       "residue: \(collisions) position(s) share a character index — steps \(indices)")
    }

    // MARK: - Storage-derived fields

    /// `inlineRuns` are indexed on the canonical axis because the projection is, and the projection
    /// is validated equal to the canonical text on every refresh. A bold run applied in the SECOND
    /// paragraph is the case that would be off by one under the raw axis.
    func test_inlineRunsAreIndexedOnTheCanonicalAxis_pastTheBoundary() throws {
        let scenario = try DifferentialCorpus.synthesise(
            identifier: "runs-past-boundary", family: "inline-formatting",
            initialText: "AB\nCDEF", selection: NSRange(location: 0, length: 0),
            comparisonFields: ["canonical", "inlineRuns"],
            transactions: [DifferentialCorpus.checkpoint("baseline")])
        let host = try makeHost(.reference, scenario)
        let input = host.input
        let canvas = try XCTUnwrap(input as? DocumentCanvasView)

        // "CD" — character indices 3..<5, i.e. past the paragraph boundary.
        input.selectedTextRange = IDTelegramTextRangeForCharacterRange(input, NSRange(location: 3, length: 2))
        canvas.toggleBold()

        let recorder = IDTextInputStateRecorder(host: host)
        defer { recorder.detach() }
        let state = recorder.capturePhase("bolded").state
        XCTAssertEqual(state["canonical"] as? String, "AB\nCDEF")
        let runs = try XCTUnwrap(state["inlineRuns"] as? [[String: Any]])
        let bold = runs.filter { ($0["traits"] as? [String])?.contains("bold") == true }
        XCTAssertEqual(bold.count, 1, "expected one bold run, got \(runs)")
        XCTAssertEqual(bold.first?["range"] as? [String: Int], ["location": 3, "length": 2],
                       "the run must be indexed on the canonical axis, not the sparse one")

        let covered = runs.reduce(0) { $0 + (($1["range"] as? [String: Int])?["length"] ?? 0) }
        XCTAssertEqual(covered, 7, "the runs must tile the canonical string exactly")
    }

    /// `typingInlineTraits` over a RANGED selection reads the projection through the mapped range —
    /// the vendored recorder read it through the raw one, which is exactly the silent misindexing
    /// the projection was made range-taking to avoid.
    func test_typingInlineTraitsOverARangedSelectionReadsTheMappedRange() throws {
        let scenario = try DifferentialCorpus.synthesise(
            identifier: "typing-traits-ranged", family: "inline-formatting",
            initialText: "AB\nCDEF", selection: NSRange(location: 0, length: 0),
            comparisonFields: ["canonical", "typingInlineTraits"],
            transactions: [DifferentialCorpus.checkpoint("baseline")])
        let host = try makeHost(.reference, scenario)
        let input = host.input
        let canvas = try XCTUnwrap(input as? DocumentCanvasView)

        input.selectedTextRange = IDTelegramTextRangeForCharacterRange(input, NSRange(location: 3, length: 2))
        canvas.toggleBold()

        let recorder = IDTextInputStateRecorder(host: host)
        defer { recorder.detach() }
        XCTAssertEqual(recorder.capturePhase("p").state["typingInlineTraits"] as? [String], ["bold"])

        // Extend over "CDE": the third character is not bold, so the intersection empties.
        input.selectedTextRange = IDTelegramTextRangeForCharacterRange(input, NSRange(location: 3, length: 3))
        XCTAssertEqual(recorder.capturePhase("p").state["typingInlineTraits"] as? [String], [])
    }

    /// **A measured divergence, pinned here so Task 9d finds it named rather than as a surprise.**
    /// At a COLLAPSED caret the editor has no pending typing format at all: `characterFormatTargets()`
    /// is empty for a caret, so `toggleBold()` is inert and the next character is not bold. Stock
    /// carries the toggle in `typingAttributes`. The recorder reports what each arm actually thinks —
    /// declining here would have HIDDEN a real behavioural difference, which is the opposite of the
    /// job.
    func test_theEditorHasNoPendingTypingFormatAtACaret_andTheRecorderReportsThatHonestly() throws {
        let scenario = try DifferentialCorpus.synthesise(
            identifier: "typing-traits-caret", family: "inline-formatting",
            initialText: "AB", selection: NSRange(location: 2, length: 0),
            comparisonFields: ["canonical", "typingInlineTraits"],
            transactions: [DifferentialCorpus.checkpoint("baseline")])

        let telegram = try makeHost(.reference, scenario)
        let canvas = try XCTUnwrap(telegram.input as? DocumentCanvasView)
        let telegramRecorder = IDTextInputStateRecorder(host: telegram)
        defer { telegramRecorder.detach() }
        XCTAssertEqual(telegramRecorder.capturePhase("p").state["typingInlineTraits"] as? [String], [],
                       "the field must be SERVED at a caret, not declined")
        canvas.toggleBold()
        XCTAssertEqual(telegramRecorder.capturePhase("p").state["typingInlineTraits"] as? [String], [],
                       "the editor has no pending caret format — a real divergence, reported not hidden")

        TelegramDifferentialInputFactory.uninstall()
        let stock = try makeHost(.stock, scenario)
        let textView = try XCTUnwrap(stock.input as? UITextView)
        let stockRecorder = IDTextInputStateRecorder(host: stock)
        defer { stockRecorder.detach() }
        var attributes = textView.typingAttributes
        attributes[.font] = UIFont.boldSystemFont(ofSize: 17)
        textView.typingAttributes = attributes
        XCTAssertEqual(stockRecorder.capturePhase("p").state["typingInlineTraits"] as? [String], ["bold"],
                       "stock carries the pending format; the two arms genuinely differ here")
    }

    /// The tripwire for "declines, does not guess". A factory handing back a projection that does
    /// NOT reproduce the canonical text must cost the storage-derived fields their value — absent,
    /// with a reason — rather than yielding a plausible-looking run list over the wrong characters.
    func test_aMisalignedProjectionDeclinesTheStorageDerivedFieldsInsteadOfGuessing() throws {
        let scenario = try DifferentialCorpus.synthesise(
            identifier: "misaligned-projection", family: "inline-formatting",
            initialText: "AB\nCD", selection: NSRange(location: 0, length: 0),
            comparisonFields: ["canonical", "inlineRuns", "typingInlineTraits"],
            transactions: [DifferentialCorpus.checkpoint("baseline")])

        var editors: [RichTextEditorView] = []
        IDTextInputTestHost.id_setTelegramInputFactory { _, _, _ in
            let editor = RichTextEditorView(frame: TelegramDifferentialInputFactory.editorFrame)
            editor.document = Document(blocks: [
                .paragraph(ParagraphBlock(id: BlockID.generate(), runs: [TextRun(text: "AB")])),
                .paragraph(ParagraphBlock(id: BlockID.generate(), runs: [TextRun(text: "CD")])),
            ])
            editor.update(size: TelegramDifferentialInputFactory.editorFrame.size, insets: .zero,
                          contentMargins: TelegramDifferentialInputFactory.textInsets)
            editors.append(editor)
            // Deliberately wrong: one character short of the canonical text.
            return IDTelegramInputHandle(input: editor.canvas, ownerView: editor,
                                         attributedTextProjection: { _ in NSAttributedString(string: "AB\nC") },
                                         blockTexts: nil, typingAttributes: nil)
        }

        let host = try makeHost(.reference, scenario)
        XCTAssertFalse(host.id_observedTextStorageIsAligned)
        let recorder = IDTextInputStateRecorder(host: host)
        defer { recorder.detach() }
        let snapshot = recorder.capturePhase("baseline")

        XCTAssertEqual(snapshot.state["canonical"] as? String, "AB\nCD",
                       "canonical comes from the input itself and is unaffected")
        XCTAssertNil(snapshot.state["inlineRuns"], "a misaligned projection must not produce runs")
        XCTAssertNil(snapshot.state["typingInlineTraits"])
        let declines = try XCTUnwrap(snapshot.state[IDTelegramSnapshotDeclinesKey] as? [String: String])
        XCTAssertNotNil(declines["inlineRuns"])
        XCTAssertTrue(declines["inlineRuns"]?.contains("projection") == true, "\(declines)")
    }

    // MARK: - Traces and lifecycle

    /// The delegate trace records the editor's own `UITextInputDelegate` callbacks and forwards them
    /// on, and `resetTransactionTraces` clears the trace without disturbing the installed delegate.
    func test_theDelegateTraceRecordsTheEditorsCallbacks_andResetsWithoutDetaching() throws {
        let scenario = try DifferentialCorpus.firstScenario(inFile: "ime-ios26.5-v1")
        let host = try makeHost(.reference, scenario)
        let recorder = IDTextInputStateRecorder(host: host)
        defer { recorder.detach() }

        XCTAssertTrue(host.input.becomeFirstResponder())
        host.input.insertText("Z")
        let trace = try XCTUnwrap(recorder.capturePhase("typed").state["inputDelegateTrace"] as? [String])
        XCTAssertTrue(trace.contains("textWillChange") && trace.contains("textDidChange"),
                      "the editor's own delegate callbacks must be recorded: \(trace)")

        recorder.resetTransactionTraces()
        XCTAssertEqual(recorder.capturePhase("after-reset").state["inputDelegateTrace"] as? [String], [])
        host.input.insertText("Y")
        XCTAssertFalse((recorder.capturePhase("again").state["inputDelegateTrace"] as? [String] ?? []).isEmpty,
                       "reset must not detach the recorder")
    }

    func test_detachRestoresThePriorInputDelegate_andIsIdempotent() throws {
        let scenario = try DifferentialCorpus.firstScenario(inFile: "ime-ios26.5-v1")
        let host = try makeHost(.reference, scenario)
        let prior = host.input.inputDelegate
        let recorder = IDTextInputStateRecorder(host: host)
        XCTAssertFalse(host.input.inputDelegate === prior, "the recorder must install itself")
        recorder.detach()
        XCTAssertTrue(host.input.inputDelegate === prior, "detach must put the prior delegate back")
        recorder.detach()
    }

    /// `storageMutationTrace` is declined structurally, not by convention: the projection cannot post
    /// `NSTextStorageDidProcessEditingNotification`, so a trace assembled for a Telegram host would
    /// describe when the RECORDER sampled rather than when the editor edited.
    func test_storageMutationTraceIsServedForStockAndDeclinedForTelegram() throws {
        let scenario = try DifferentialCorpus.firstScenario(inFile: "ime-ios26.5-v1")
        let telegram = try makeHost(.reference, scenario)
        let telegramRecorder = IDTextInputStateRecorder(host: telegram)
        defer { telegramRecorder.detach() }
        XCTAssertTrue(telegram.input.becomeFirstResponder())
        telegram.input.insertText("Z")
        XCTAssertNil(telegramRecorder.capturePhase("typed").state["storageMutationTrace"])

        TelegramDifferentialInputFactory.uninstall()
        let stock = try makeHost(.stock, scenario)
        let stockRecorder = IDTextInputStateRecorder(host: stock)
        defer { stockRecorder.detach() }
        XCTAssertTrue(stock.input.becomeFirstResponder())
        stock.input.insertText("Z")
        let trace = try XCTUnwrap(stockRecorder.capturePhase("typed").state["storageMutationTrace"] as? [[String: Any]])
        XCTAssertFalse(trace.isEmpty, "stock's storage does post edit notifications")
    }

    /// `traits` is declined because three of the ten `UITextInputTraits` members do not exist on the
    /// editor, so the ten-key census the contract compares cannot be formed at all. What CAN be read
    /// is published under a diagnostic name, so the decline costs no measurement.
    func test_traitsIsDeclinedForTelegramButTheReadableSubsetIsStillPublished() throws {
        let scenario = try DifferentialCorpus.firstScenario(inFile: "autocorrection-ios26.5-v1")
        let host = try makeHost(.reference, scenario)
        let recorder = IDTextInputStateRecorder(host: host)
        defer { recorder.detach() }
        let state = recorder.capturePhase("baseline").state

        XCTAssertNil(state["traits"])
        let readable = try XCTUnwrap(state["telegramReadableTraits"] as? [String: Int])
        XCTAssertEqual(Set(readable.keys), Set([
            "autocorrectionType", "spellCheckingType", "smartQuotesType",
            "smartDashesType", "smartInsertDeleteType", "inlinePredictionType",
            // The seventh, added with the code-block language line: the canvas answers `.none` there
            // (a language name is an identifier) and `.sentences` — UIKit's own unimplemented default
            // — everywhere else.
            "autocapitalizationType",
        ]), "the seven the canvas implements; the census changed: \(readable.keys.sorted())")
        let unapplied = try XCTUnwrap(state["telegramUnappliedTraits"] as? [String: String])
        XCTAssertFalse(unapplied.isEmpty, "the host's construction-time census must travel with the snapshot")
    }

    /// `blocks` is the editor's own top-level block list — the vendored recorder's semantic for a
    /// non-stock host, reached through a provider instead of a downcast. It must agree with the
    /// canonical text's "\n" split at construction for every scenario in the corpus; a later
    /// disagreement is a real finding about the editor, not about the recorder.
    func test_blocksAreTheEditorsOwnBlockList_andAgreeWithTheCanonicalSplitForEveryCorpusScenario() throws {
        for fileName in DifferentialCorpus.fileNames {
            for scenario in try DifferentialCorpus.scenarios(inFile: fileName) {
                let host = try makeHost(.reference, scenario)
                let recorder = IDTextInputStateRecorder(host: host)
                defer { recorder.detach() }
                let state = recorder.capturePhase("baseline").state
                let canonical = try XCTUnwrap(state["canonical"] as? String)
                XCTAssertEqual(state["blocks"] as? [String], canonical.components(separatedBy: "\n"),
                               "\(scenario.identifier): the editor's block list and its own text projection disagree")
            }
        }
    }

    // MARK: - Helpers

    private func makeHost(_ kind: IDTextInputHostKind,
                          _ scenario: IDTextInputScenario,
                          file: StaticString = #filePath, line: UInt = #line) throws -> IDTextInputTestHost {
        do {
            return try IDTextInputTestHost(kind: kind, scenario: scenario)
        } catch {
            XCTFail("host(kind: \(kind.rawValue)) failed: \((error as NSError).localizedDescription)",
                    file: file, line: line)
            throw error
        }
    }
}
#endif
