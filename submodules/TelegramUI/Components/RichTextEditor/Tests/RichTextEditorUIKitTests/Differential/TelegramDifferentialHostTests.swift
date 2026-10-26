#if canImport(UIKit)
import XCTest
import UIKit
import RichTextEditorDifferentialHarness
import RichTextEditorCore
@testable import RichTextEditorUIKit

/// Task 9b, Step 4 — **the Telegram-side host builds, and the facts Task 9c inherits are pinned
/// here rather than assumed there.**
///
/// The plan's Step 4 asks for one thing (the host builds, `input` is first responder, the window is
/// key). The rest of this suite exists because three measurements taken while writing the host
/// contradict what a reader would reasonably assume from the vendored original, and each one would
/// otherwise be discovered by Task 9c as a crash or — worse — as a silently wrong number:
///
///  1. **The `UITextInput` position axis is SPARSE.** A top-level paragraph boundary occupies two
///     position slots while the text projection emits one "\n".
///  2. **Four of the ten `UITextInputTraits` members do not exist on the editor**, and the six that
///     do have no-op setters.
///  3. **`textStylingAtPosition:inDirection:` does not exist on the editor either**, which removes
///     the vendored recorder's fallback for `typingInlineTraits` at a collapsed selection.
final class TelegramDifferentialHostTests: XCTestCase {

    override func setUp() {
        super.setUp()
        TelegramDifferentialInputFactory.install()
    }

    override func tearDown() {
        TelegramDifferentialInputFactory.uninstall()
        super.tearDown()
    }

    // MARK: - Step 4: the host builds

    func test_theTelegramHostBuilds_andItsInputCanBecomeFirstResponderInAKeyWindow() throws {
        let scenario = try DifferentialCorpus.firstScenario(inFile: "ime-ios26.5-v1")
        let host = try makeHost(.reference, scenario)

        XCTAssertEqual(host.kind, .reference)
        XCTAssertTrue(host.input is DocumentCanvasView,
                      "the Telegram host's UITextInput witness must be the editor's canvas")
        XCTAssertNotNil(host.input.superview,
                        "the input must be in the view hierarchy the host built")

        // The window is KEY and visible for every family except inline-formatting, which the
        // vendored original deliberately runs on a hidden window. Both halves are asserted, because
        // "the window is key" is only true for 54 of the 68 scenarios.
        XCTAssertTrue(host.window.isKeyWindow, "the host's window must be key for the IME family")
        XCTAssertFalse(host.window.isHidden)

        // The host does NOT make the input first responder, and that is faithful, not an omission:
        // `become-first-responder` is transaction kind 0 and the FIRST transaction of all 54
        // non-inline-formatting scenarios, so first-responder acquisition belongs to Task 9d's
        // driver. What Step 4 can assert here is that it succeeds when asked.
        XCTAssertFalse(host.input.isFirstResponder,
                       "the host must leave first-responder acquisition to the scenario's first transaction")
        XCTAssertTrue(host.input.becomeFirstResponder(), "the editor refused first responder in the host's window")
        XCTAssertTrue(host.input.isFirstResponder)
    }

    func test_theStockHostBuildsWithoutTheFactory_andCarriesItsRealTextStorage() throws {
        TelegramDifferentialInputFactory.uninstall()
        let scenario = try DifferentialCorpus.firstScenario(inFile: "ime-ios26.5-v1")
        let host = try makeHost(.stock, scenario)

        XCTAssertTrue(host.input is UITextView)
        XCTAssertTrue(host.observedTextStorage === (host.input as? UITextView)?.textStorage,
                      "the stock host must observe the real storage, exactly as the vendored original does")
        XCTAssertEqual(host.observedTextStorage.string, scenario.initialText)
        XCTAssertTrue(host.id_observedTextStorageIsAligned)
        XCTAssertNil(host.id_observedTextStorageMisalignmentReason)
    }

    /// A non-stock host with no factory registered must FAIL. If it quietly fell back to a stock
    /// input, the differential run would compare stock against stock, agree perfectly, and be
    /// meaningless — a green result that measured nothing.
    func test_aNonStockHostWithNoRegisteredFactoryFails() throws {
        TelegramDifferentialInputFactory.uninstall()
        let scenario = try DifferentialCorpus.firstScenario(inFile: "ime-ios26.5-v1")
        XCTAssertThrowsError(try IDTextInputTestHost(kind: .reference, scenario: scenario)) { raised in
            let error = raised as NSError
            XCTAssertEqual(error.domain, IDTextInputTestHostErrorDomain)
            XCTAssertTrue(error.localizedDescription.contains("No Telegram input factory is registered"),
                          "the failure must name the missing factory: \(error.localizedDescription)")
        }
    }

    func test_theInlineFormattingFamilyRunsOnAHiddenWindow() throws {
        let scenario = try DifferentialCorpus.firstScenario(inFile: "inline-formatting-ios26.5-v1")
        let host = try makeHost(.reference, scenario)
        XCTAssertEqual(scenario.family, .inlineFormatting)
        XCTAssertTrue(host.window.isHidden,
                      "the vendored original hides the window for this family; the arms must match")
        XCTAssertFalse(host.window.isKeyWindow)
    }

    // MARK: - Step 2: `observedTextStorage`

    /// The decision recorded for Task 9c: `observedTextStorage` IS populated for a Telegram host —
    /// option (a) — but as a **validated pull projection**, not a mirror. Every refresh compares the
    /// projected string against the host's own canonical text and declines on disagreement.
    func test_theProjectedStorageReproducesTheEditorsCanonicalTextForEveryCorpusScenarioShape() throws {
        for fileName in DifferentialCorpus.fileNames {
            for scenario in try DifferentialCorpus.scenarios(inFile: fileName) {
                let host = try makeHost(.reference, scenario)
                let input = host.input
                let range = try XCTUnwrap(input.textRange(from: input.beginningOfDocument,
                                                          to: input.endOfDocument))
                let canonical = input.text(in: range) ?? ""
                XCTAssertTrue(host.id_observedTextStorageIsAligned,
                              "\(scenario.identifier): \(host.id_observedTextStorageMisalignmentReason ?? "aligned")")
                XCTAssertEqual(host.observedTextStorage.string, canonical,
                               "\(scenario.identifier): the projection must equal the canonical text")
                XCTAssertEqual(host.observedTextStorage.string, scenario.initialText,
                               "\(scenario.identifier): and the canonical text must be what the scenario seeded")
            }
        }
    }

    /// **The payoff of populating the storage at all.** Option (b) — an empty storage plus a skip
    /// list — would have cost the inline-formatting family both of its formatting comparison fields
    /// (`typingInlineTraits`, `inlineRuns`), which is 14 of the 68 scenarios reduced to five fields.
    /// This asserts the projection actually carries the editor's inline traits, so that decision
    /// buys something rather than merely looking better.
    func test_theProjectionCarriesTheEditorsInlineTraits() throws {
        let scenario = try DifferentialCorpus.synthesise(
            identifier: "inline-trait-probe", family: "inline-formatting",
            initialText: "ABCD", selection: NSRange(location: 0, length: 0),
            comparisonFields: ["canonical", "inlineRuns"],
            transactions: [DifferentialCorpus.checkpoint("baseline")])
        let host = try makeHost(.reference, scenario)
        let input = host.input
        let canvas = try XCTUnwrap(input as? DocumentCanvasView)

        let start = try XCTUnwrap(input.position(from: input.beginningOfDocument, offset: 0))
        let middle = try XCTUnwrap(input.position(from: input.beginningOfDocument, offset: 2))
        input.selectedTextRange = input.textRange(from: start, to: middle)
        canvas.toggleBold()
        host.id_refreshObservedTextStorage()

        XCTAssertTrue(host.id_observedTextStorageIsAligned,
                      host.id_observedTextStorageMisalignmentReason ?? "aligned")
        XCTAssertEqual(host.observedTextStorage.string, "ABCD")

        func isBold(_ index: Int) -> Bool {
            let font = host.observedTextStorage.attributes(at: index, effectiveRange: nil)[.font] as? UIFont
            return font?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? false
        }
        XCTAssertTrue(isBold(0), "the projection must carry the bold run the editor applied")
        XCTAssertTrue(isBold(1))
        XCTAssertFalse(isBold(2), "and must not spread it past the selection")
        XCTAssertFalse(isBold(3))
    }

    /// The projection is a PULL, and it must stay one. If it ever became a live mirror wired through
    /// `NSTextStorage` mutation, the recorder's storage observer would start firing on our own
    /// refresh calls and `storageMutationTrace` would fill up with entries describing when the
    /// recorder sampled — then get compared against stock's genuine edit trace as though the two
    /// meant the same thing. This test is the tripwire for that.
    func test_refreshingTheProjectionPostsNoTextStorageNotification() throws {
        let scenario = try DifferentialCorpus.firstScenario(inFile: "ime-ios26.5-v1")
        let host = try makeHost(.reference, scenario)

        var posted = 0
        let observer = NotificationCenter.default.addObserver(
            forName: NSTextStorage.didProcessEditingNotification,
            object: host.observedTextStorage, queue: nil) { _ in posted += 1 }
        defer { NotificationCenter.default.removeObserver(observer) }

        host.input.becomeFirstResponder()
        host.input.insertText("Z")
        host.id_refreshObservedTextStorage()
        host.id_refreshObservedTextStorage()

        XCTAssertEqual(posted, 0,
                       "the projection must never post NSTextStorageDidProcessEditingNotification")
        XCTAssertTrue(host.id_observedTextStorageIsAligned)
        XCTAssertTrue(host.observedTextStorage.string.contains("Z"),
                      "the refresh must nonetheless pick up the edit")
    }

    func test_theProjectedStorageRefusesToBeMutated() throws {
        let scenario = try DifferentialCorpus.firstScenario(inFile: "ime-ios26.5-v1")
        let host = try makeHost(.reference, scenario)
        let storage = try XCTUnwrap(host.observedTextStorage as? IDTelegramProjectedTextStorage)
        let raised = IDTelegramCatchException {
            storage.replaceCharacters(in: NSRange(location: 0, length: 0), with: "x")
        }
        XCTAssertNotNil(raised, "a projection has no upstream to write to; mutating it must raise")
        XCTAssertEqual(raised?.name, NSExceptionName.internalInconsistencyException)
    }

    // MARK: - The three measurements Task 9c inherits

    /// **The `UITextInput` position axis is SPARSE.** Pinned with the exact numbers, because a
    /// whole-document `NSTextStorage` mirror indexed by recorder-reported offsets would read the
    /// wrong character's attributes from the second paragraph onward and report it as agreement.
    /// This is why the projection takes a `UITextRange`.
    func test_thePositionAxisGainsOneSlotPerTopLevelParagraphBoundary() throws {
        let scenario = try DifferentialCorpus.synthesise(
            identifier: "axis-probe", family: "ime",
            initialText: "Alpha middle omega\nSecond block remains unchanged.",
            selection: NSRange(location: 0, length: 0),
            comparisonFields: ["canonical"],
            transactions: [DifferentialCorpus.checkpoint("baseline")])
        let host = try makeHost(.reference, scenario)
        let input = host.input

        let range = try XCTUnwrap(input.textRange(from: input.beginningOfDocument, to: input.endOfDocument))
        let canonical = try XCTUnwrap(input.text(in: range))
        let span = input.offset(from: input.beginningOfDocument, to: input.endOfDocument)

        XCTAssertEqual(canonical.utf16.count, 50)
        XCTAssertEqual(span, 51, "one boundary => the axis is one slot longer than the text")

        // The second paragraph's first character: index 19 in the text, offset 20 on the axis.
        let secondParagraphStart = try XCTUnwrap(input.position(from: input.beginningOfDocument, offset: 19))
        XCTAssertEqual(input.offset(from: input.beginningOfDocument, to: secondParagraphStart), 20)

        // The stock arm has no such gap — which is exactly why the two cannot share an index.
        TelegramDifferentialInputFactory.uninstall()
        let stock = try makeHost(.stock, scenario)
        XCTAssertEqual(stock.input.offset(from: stock.input.beginningOfDocument,
                                          to: stock.input.endOfDocument), 50)
    }

    /// The traits census. Both halves are asserted: stock takes all ten, so the read-back mechanism
    /// is validated against ground truth before its answer for Telegram is believed.
    func test_theTraitCensusIsEmptyForStock_andNamesBothWaysTelegramFailsToTakeATrait() throws {
        let scenario = try DifferentialCorpus.firstScenario(inFile: "autocorrection-ios26.5-v1")

        let telegram = try makeHost(.reference, scenario)
        TelegramDifferentialInputFactory.uninstall()
        let stock = try makeHost(.stock, scenario)

        XCTAssertTrue(stock.id_unappliedTraits.isEmpty,
                      "a UITextView takes every trait; if it does not, the read-back census is broken: "
                      + "\(stock.id_unappliedTraits)")

        // MEASURED 2026-08-24 against this scenario's traits. The census is scenario-dependent by
        // construction — a no-op setter only surfaces when the scenario asks for a value the
        // editor's fixed one does not already equal — so the assertion names a scenario, not a
        // universal set.
        //
        // THREE are absent outright: every `UITextInputTraits` member is `@optional`, `UIView`
        // implements none, and `DocumentCanvasView` implements seven of the ten. Sending them
        // unguarded — which is exactly what the vendored original does — would raise
        // `unrecognized selector`.
        //
        // TWO are no-op setters: this family asks for `inlinePredictionType: 1` (No) and the canvas
        // answers a fixed `2` (Yes), and it asks for an `autocapitalizationType` the canvas likewise
        // answers with its own fixed value. That is the second, quieter failure mode, and it is why
        // the census reads each trait BACK instead of trusting `-respondsToSelector:`.
        // `autocapitalizationType` became the SEVENTH implemented trait when the code-block language
        // line landed: a language name is an identifier, so the canvas answers `.none` while the
        // caret is in that region and `.sentences` — UIKit's own default for an unimplemented trait,
        // so nothing moved elsewhere — everywhere else.
        //
        // `spellCheckingType` is absent from the census — it sticks, because the factory routes it
        // through the editor's own `isSpellCheckingEnabled` knob before this generic pass runs. The
        // `UITextInputTraits` setter alone would not have.
        let absent = Set(["keyboardType", "returnKeyType", "secureTextEntry"])
        let noOpSetters = Set(["inlinePredictionType", "autocapitalizationType"])
        XCTAssertEqual(Set(telegram.id_unappliedTraits.keys), absent.union(noOpSetters),
                       "the unapplied-trait census changed: \(telegram.id_unappliedTraits)")
        for name in absent {
            XCTAssertTrue(telegram.id_unappliedTraits[name]?.contains("implements neither") == true,
                          "\(name) should be reported as absent, not as a no-op setter")
        }
        for name in noOpSetters {
            XCTAssertTrue(telegram.id_unappliedTraits[name]?.contains("did not take") == true,
                          "\(name) should be reported as a no-op setter, not as absent")
        }
        XCTAssertNil(telegram.id_unappliedTraits["spellCheckingType"],
                     "spellCheckingType is applied through the editor's own knob and must stick")
    }

    /// `textStylingAtPosition:inDirection:` is an `@optional` `UITextInput` member that
    /// `UITextView` implements and `DocumentCanvasView` does not. The vendored recorder falls back
    /// to it for `typingInlineTraits` at a COLLAPSED selection, so Task 9c cannot reuse that
    /// fallback and must decline the field (or source it from the editor) rather than send the
    /// message and crash.
    func test_theEditorDoesNotImplementTextStylingAtPosition_whichStockDoes() throws {
        let scenario = try DifferentialCorpus.firstScenario(inFile: "inline-formatting-ios26.5-v1")
        let telegram = try makeHost(.reference, scenario)
        TelegramDifferentialInputFactory.uninstall()
        let stock = try makeHost(.stock, scenario)

        let selector = NSSelectorFromString("textStylingAtPosition:inDirection:")
        XCTAssertFalse(telegram.input.responds(to: selector))
        XCTAssertTrue(stock.input.responds(to: selector))

        // `selectionAffinity`, by contrast, IS answered by both — the recorder reads it
        // unconditionally at every capture, so its absence would be a crash on every scenario.
        let affinity = NSSelectorFromString("selectionAffinity")
        XCTAssertTrue(telegram.input.responds(to: affinity))
        XCTAssertTrue(stock.input.responds(to: affinity))
    }

    // MARK: - Step 3: `comparesAnnotations`

    func test_comparesAnnotationsFollowsTheScenario_andNoCorpusScenarioAsksForIt() throws {
        for scenario in try DifferentialCorpus.allScenarios() {
            XCTAssertFalse(scenario.comparisonFields.contains("annotationRanges"),
                           "\(scenario.identifier) asks for annotationRanges; the 9b measurement no longer holds")
        }
        let corpusScenario = try DifferentialCorpus.firstScenario(inFile: "ime-ios26.5-v1")
        XCTAssertFalse(try makeHost(.reference, corpusScenario).comparesAnnotations)

        let asking = try DifferentialCorpus.synthesise(
            identifier: "annotations-requested", family: "ime",
            initialText: "AB", selection: NSRange(location: 0, length: 0),
            comparisonFields: ["canonical", "annotationRanges"],
            transactions: [DifferentialCorpus.checkpoint("baseline")])
        XCTAssertTrue(try makeHost(.reference, asking).comparesAnnotations,
                      "the flag must follow the scenario, not a hard-coded NO")
    }

    // MARK: - The two non-stock kinds

    /// `IDTextInputHostKind` is vendored and the runner executes all three kinds. Telegram has one
    /// input implementation, so `Minimal` is a SECOND, INDEPENDENT instance of the same editor and
    /// the reference-vs-minimal pair is a determinism / execution-order check. Asserting that the
    /// two are distinct objects is what stops that from silently degrading into comparing an object
    /// with itself, which would agree by construction.
    func test_referenceAndMinimalAreDistinctEditorInstances() throws {
        let scenario = try DifferentialCorpus.firstScenario(inFile: "ime-ios26.5-v1")
        let reference = try makeHost(.reference, scenario)
        let minimal = try makeHost(.minimal, scenario)
        XCTAssertEqual(minimal.kind, .minimal)
        XCTAssertFalse(reference.input === minimal.input)
        XCTAssertFalse(reference.window === minimal.window)
        XCTAssertEqual(reference.observedTextStorage.string, minimal.observedTextStorage.string)
    }

    // MARK: - Helpers

    /// Builds a host, failing the test with the host's own diagnostic rather than a bare `nil`.
    /// The returned host must be held by the caller: its `dealloc` resigns first responder, hides
    /// the window and restores the previous key window, which is the teardown the vendored original
    /// relies on.
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
