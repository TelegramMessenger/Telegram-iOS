#if canImport(UIKit)
import RichTextInputDecObjC
import UIKit
import XCTest
@testable import RichTextEditorUIKit

/// Task F4 — the flag had NO autocorrect and NO spelling underlines. Four independent, silently
/// inert sites caused it; this suite pins all four, each against a value CAPTURED before any
/// assertion reads it, and each written to fail on the pre-fix tree (the report records the
/// measured red output).
///
/// The suite is deliberately DIFFERENTIAL wherever a Legacy answer exists: the Legacy backend is
/// the reference implementation, it is what production ships, and "the two arms agree" is a far
/// stronger claim than any absolute value this package could assert on its own.
@available(iOS 17.0, *)
@MainActor
final class IDBackendCheckingAndTraitsTests: XCTestCase {
    private var harness: RichTextInputBackendHarness?

    override func tearDown() {
        harness?.tearDown()
        harness = nil
        super.tearDown()
    }

    private func focusedHarness(_ kind: RichTextInputBackendKind) -> RichTextInputBackendHarness {
        let h = makeBackendHarness(backend: kind, paragraphs: ["Alpha wrold", "Beta"])
        harness = h
        h.hostInWindow()
        _ = h.makeFirstResponder()
        return h
    }

    // MARK: - Defect 1: the native checking driver was never installed

    /// RED before the fix: `nativeChecker` was nil under `.inputDec` and non-nil under `.legacy`,
    /// because `IDTextEditorBackend.installCheckingIfNeeded()` was an empty body. Without the
    /// driver there is no source of `.spelling`/`.grammar`/`.correction` flags at all, so no
    /// underline can ever be drawn.
    func test_becomingFirstResponderInstallsTheNativeCheckerUnderBothBackends() throws {
        try XCTSkipUnless(IDTextEditorBackend.isSupported())
        try XCTSkipUnless(NativeTextChecker.nativeCheckingControllerClassIsAvailable,
                          "no private checking controller on this runtime — the comparison would be vacuous")

        let legacyInstalled = focusedHarness(.legacy).canvas.nativeChecker != nil
        harness?.tearDown(); harness = nil
        let inputDecInstalled = focusedHarness(.inputDec).canvas.nativeChecker != nil

        XCTAssertTrue(legacyInstalled, "precondition: the reference arm installs a checker")
        XCTAssertTrue(inputDecInstalled,
                      "the InputDec arm never constructed a NativeTextChecker, so nothing can " +
                      "ever flag a misspelling")
    }

    /// The toggle path, which is the OTHER install site (`isSpellCheckingEnabled`'s `didSet`).
    func test_reEnablingSpellCheckingReinstallsTheCheckerUnderInputDec() throws {
        try XCTSkipUnless(IDTextEditorBackend.isSupported())
        try XCTSkipUnless(NativeTextChecker.nativeCheckingControllerClassIsAvailable)
        let canvas = focusedHarness(.inputDec).canvas
        canvas.isSpellCheckingEnabled = false
        let afterDisable = canvas.nativeChecker != nil
        canvas.isSpellCheckingEnabled = true
        let afterEnable = canvas.nativeChecker != nil
        XCTAssertFalse(afterDisable)
        XCTAssertTrue(afterEnable)
    }

    // MARK: - Defect 2: the checking controller's own range converter was unreadable

    /// The private controller converts every range it checks through
    /// `nativeTextRange(forGlobalLocation:length:)` and reads it back through `text(in:)`.
    /// RED before the fix: `.inputDec` answered `nil` (and `annotatedSubstring` degraded to `""`),
    /// because the canvas mints a `LegacyTextRange` under every backend and the kernel casts every
    /// incoming range to its own type unchecked.
    func test_theCheckingControllersRangeConverterIsReadableUnderBothBackends() throws {
        try XCTSkipUnless(IDTextEditorBackend.isSupported())

        func readBack(_ kind: RichTextInputBackendKind) -> (text: String?, annotated: String?) {
            let canvas = focusedHarness(kind).canvas
            // Offsets are the canvas's 1-based GLOBAL axis, on which "wrold" occupies 7..<12
            // (`beginningOfDocument` sits at global 1 — see `nativeTextRange(forGlobalLocation:length:)`'s
            // own note on why the driver uses this converter rather than position arithmetic).
            guard let range = canvas.nativeTextRange(forGlobalLocation: 7, length: 5) else {
                return (nil, nil)
            }
            return (canvas.text(in: range), canvas.annotatedSubstring(for: range)?.string)
        }

        let legacy = readBack(.legacy)
        harness?.tearDown(); harness = nil
        let inputDec = readBack(.inputDec)

        XCTAssertEqual(legacy.text, "wrold", "precondition: the reference arm reads the word back")
        XCTAssertEqual(inputDec.text, legacy.text,
                       "the InputDec arm could not read a canvas-minted checking range")
        XCTAssertEqual(inputDec.annotated, legacy.annotated)
    }

    /// The witness must still degrade — never fabricate — for a genuinely foreign range.
    func test_textInAForeignRangeIsStillNil() throws {
        try XCTSkipUnless(IDTextEditorBackend.isSupported())
        let canvas = focusedHarness(.inputDec).canvas
        let foreign = ForeignTextRange()
        XCTAssertNil(canvas.text(in: foreign))
    }

    // MARK: - Defect 3: the word-boundary tokenizer cast

    /// RED before the fix: `spellCheckTargets` cast the tokenizer to the CONCRETE
    /// `DocumentTokenizer`, which `.inputDec`'s `IDDocumentTokenizer` is not, so every caret move
    /// produced `(nil, nil)` and no word was ever checked.
    func test_spellCheckTargetsResolveWordsUnderBothBackends() throws {
        try XCTSkipUnless(IDTextEditorBackend.isSupported())

        func targets(_ kind: RichTextInputBackendKind) -> (check: NSRange?, clear: NSRange?) {
            focusedHarness(kind).canvas.spellCheckTargets(fromCaret: 8, toCaret: 1)
        }

        let legacy = targets(.legacy)
        harness?.tearDown(); harness = nil
        let inputDec = targets(.inputDec)

        XCTAssertNotNil(legacy.check, "precondition: the reference arm resolves the word left behind")
        XCTAssertEqual(inputDec.check, legacy.check,
                       "the InputDec arm resolved no spell-check target, so nothing was ever checked")
        XCTAssertEqual(inputDec.clear, legacy.clear)
    }

    /// The same concrete cast disabled double-tap word select and triple-tap paragraph select.
    func test_theTokenizerAnswersStructuralBoundariesUnderInputDec() throws {
        try XCTSkipUnless(IDTextEditorBackend.isSupported())
        let canvas = focusedHarness(.inputDec).canvas
        let tokenizer = canvas.tokenizer as? DocumentBoundaryTokenizer
        let word = tokenizer?.wordRange(at: 8)
        let paragraph = tokenizer?.paragraphRange(at: 8)
        XCTAssertNotNil(tokenizer, "the ID tokenizer must expose the structural-boundary surface")
        XCTAssertEqual(word.map { NSRange(location: $0.from, length: $0.to - $0.from) },
                       NSRange(location: 7, length: 5))
        XCTAssertNotNil(paragraph)
    }

    // MARK: - Defect 4: the private input controller's traits were never synchronised

    /// The mechanism the port was missing outright (upstream `IDPrivateSynchronizeTextInputTraits`).
    ///
    /// RED before the fix: the controller's own traits answered `0`/`0`/`0` — byte-identical to
    /// `+[UITextInputTraits defaultTextInputTraits]` — while the canvas answered `.yes`/`.yes`.
    /// The keyboard configures autocorrection and spell checking from the CONTROLLER's traits when
    /// one is in play, which is why only this arm loses them.
    func test_attachSynchronizesTheHostTraitsOntoTheControllersOwnTraits() throws {
        try XCTSkipUnless(IDTextEditorBackend.isSupported())
        let h = focusedHarness(.inputDec)
        let backend = try XCTUnwrap(h.canvas.inputBackend as? IDTextEditorBackend)
        let traits = try XCTUnwrap(backend.kernelInput?.id_textInputTraits as? NSObject,
                                   "no controller traits object — the comparison would be vacuous")
        let autocorrection = traits.value(forKey: "autocorrectionType") as? Int
        let spellChecking = traits.value(forKey: "spellCheckingType") as? Int
        let canvasAutocorrection = h.canvas.autocorrectionType.rawValue
        let canvasSpellChecking = h.canvas.spellCheckingType.rawValue

        XCTAssertEqual(canvasAutocorrection, UITextAutocorrectionType.yes.rawValue,
                       "precondition: the canvas asks for autocorrection")
        XCTAssertEqual(autocorrection, canvasAutocorrection,
                       "the private input controller never learned the host wants autocorrection")
        XCTAssertEqual(spellChecking, canvasSpellChecking,
                       "the private input controller never learned the host wants spell checking")
    }

    /// The traits must also RE-synchronise when the host toggles one, which is the whole reason
    /// upstream calls the sync from every trait setter rather than only at construction.
    func test_togglingSpellCheckingResynchronizesTheControllersTraits() throws {
        try XCTSkipUnless(IDTextEditorBackend.isSupported())
        let h = focusedHarness(.inputDec)
        let backend = try XCTUnwrap(h.canvas.inputBackend as? IDTextEditorBackend)
        h.canvas.isSpellCheckingEnabled = false
        let traits = try XCTUnwrap(backend.kernelInput?.id_textInputTraits as? NSObject)
        let afterDisable = traits.value(forKey: "spellCheckingType") as? Int
        h.canvas.isSpellCheckingEnabled = true
        let afterEnable = traits.value(forKey: "spellCheckingType") as? Int

        XCTAssertEqual(afterDisable, UITextSpellCheckingType.no.rawValue)
        XCTAssertEqual(afterEnable, UITextSpellCheckingType.yes.rawValue)
    }
    // MARK: - Defect 5 (pre-existing, found by this task): a detached `tokenizer` read TRAPPED

    /// UIKit's own keyboard document-state snapshot
    /// (`-[TIDocumentState(UITextInputAdditions) initWithDocument:contextBoundary:]`) reads the
    /// canvas's `tokenizer` ASYNCHRONOUSLY, so it can land after the backend detached while the
    /// canvas is still alive. The fallback reported through
    /// `RichTextInputContractViolation.report`, whose no-reporter DEBUG branch is an
    /// `assertionFailure` — a hard trap in a debug build.
    ///
    /// Reproduced on the PRE-TASK tree with a `git stash` control run: `IDBackendFamily8Tests`
    /// printed `Executed 5 tests, 0 failures` and then killed the xctest process. The stack trace
    /// naming `TIDocumentState` is recorded in the task report.
    ///
    /// This test drives the read deterministically instead of waiting for UIKit's own timing, with
    /// NO reporter installed — the exact configuration that trapped.
    func test_readingTheTokenizerAfterDetachDoesNotTrap() throws {
        try XCTSkipUnless(IDTextEditorBackend.isSupported())
        let h = focusedHarness(.inputDec)
        h.canvas.inputBackend.detach()
        let previousReporter = RichTextInputContractViolation.reporter
        RichTextInputContractViolation.reporter = nil
        defer { RichTextInputContractViolation.reporter = previousReporter }

        let tokenizer = h.canvas.tokenizer   // trapped the process before the fix

        XCTAssertNotNil(tokenizer, "the detached fallback must still answer a tokenizer")
    }
}

/// A `UITextRange` minted by neither backend — the control that keeps the `text(in:)` normalisation
/// from turning "I do not recognise this" into a fabricated range over the document.
@available(iOS 17.0, *)
private final class ForeignTextRange: UITextRange {
    private let startPosition = UITextPosition()
    private let endPosition = UITextPosition()
    override var start: UITextPosition { startPosition }
    override var end: UITextPosition { endPosition }
    override var isEmpty: Bool { false }
}
#endif
