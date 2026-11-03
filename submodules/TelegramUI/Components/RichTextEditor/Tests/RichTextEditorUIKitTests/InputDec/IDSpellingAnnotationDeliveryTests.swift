#if canImport(UIKit)
import UIKit
import XCTest
import RichTextEditorCore
import RichTextInputDecObjC
@testable import RichTextEditorUIKit

/// **Task H2 — the user's open defect, expressed as an assertion.**
///
/// With the InputDec backend selected, autocorrect works but a misspelled word is never underlined.
/// Task P2 localised it by measurement to DELIVERY rather than driving: the private checking
/// controller asks the InputDec host about the word exactly as often as it asks the Legacy host
/// (`IDBlockSpellingIntegrationParityTests
/// .test_whichStepOfTheCheckingPipelineTheHostArmsReach`), yet only Legacy ends up with a flag.
///
/// This suite pins the seam that swallowed it, at two granularities:
///
/// 1. `test_theCheckingClientResolvesABackendMintedRange…` — the SHARP one. The canvas's
///    checking-client surface (`annotatedSubstringForRange:`,
///    `replaceRange:withAnnotatedString:relativeReplacementRange:`, `removeAnnotation:forRange:`)
///    resolved its incoming `UITextRange` through `LegacyTextIdentity` unconditionally. Under
///    `.inputDec` the controller hands back a KERNEL-minted `TGRichTextInputDecRange`, so that
///    downcast always failed and every delivery was dropped silently. Measured directly before the
///    fix (a swizzle over the three selectors, `.inputDec` vs `.legacy`, typing `"mispelled "`):
///
///    ```
///    INPUTDEC  annotatedSubstring range<TGRichTextInputDecRange/TGRichTextInputDecPosition>
///                                 legacy=nil kernel(1,11,rev 3) -> nil        FLAGGED=false
///    LEGACY    annotatedSubstring range<LegacyTextRange/LegacyTextPosition>
///                                 legacy(1,11)                -> "mispelled " FLAGGED=true
///    LEGACY    replaceRange       legacy(1,10) attrs=[{0,9} NSTextAlternativesDisplayStyle=2]
///    ```
///
///    i.e. the controller never even reached the delivery call on the InputDec arm, because the
///    read it makes first came back nil.
///
/// 2. `test_aMisspelledWordIsFlagged…` — the end-to-end oracle, run on BOTH backends. The Legacy
///    arm is the calibration: if IT does not flag, the environment (no en-US checker, cold
///    checker) is at fault and the InputDec reading certifies nothing, so the test says so rather
///    than reporting a false green.
@available(iOS 17.0, *)
@MainActor
final class IDSpellingAnnotationDeliveryTests: XCTestCase {

    private let misspelled = "mispelled"

    override func setUpWithError() throws {
        try super.setUpWithError()
        try XCTSkipUnless(IDTextEditorBackend.isSupported(),
                          "InputDec backend unsupported on this runtime")
    }

    private func spin(_ seconds: TimeInterval) {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02))
        }
    }

    @discardableResult
    private func wait(upTo seconds: TimeInterval, for condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }
        return condition()
    }

    private func makeEditor(_ backend: RichTextEditorInputBackendPreference) throws -> RichTextEditorView {
        let frame = CGRect(x: 0, y: 0, width: 240, height: 420)
        let editor = try IDStockParity.makeHost(paragraphs: [""], backend: backend, frame: frame)
        IDStockParity.host([editor], in: self, size: frame.size)
        XCTAssertTrue(editor.becomeFirstResponder(), "the \(backend) arm could not become first responder")
        return editor
    }

    // MARK: - 1. the seam

    /// The canvas's checking-client surface must resolve a range minted by the ACTIVE backend.
    ///
    /// This is a pure identity test — no checker, no timing, no async. It builds the range through
    /// the canvas's own `UITextInput` witnesses (which is exactly how the private controller builds
    /// the ranges it hands back) and asks the client surface to read it back.
    func test_theCheckingClientResolvesABackendMintedRange_onBothBackends() throws {
        for backend in [RichTextEditorInputBackendPreference.inputDecIfSupported, .legacy] {
            let editor = try makeEditor(backend)
            let canvas = editor.canvasForTesting
            canvas.insertText("hello world")
            let whole = try XCTUnwrap(canvas.textRange(from: canvas.beginningOfDocument,
                                                       to: canvas.endOfDocument),
                                      "\(backend): the backend vended no document range")
            let read = canvas.annotatedSubstring(for: whole)
            XCTAssertEqual(read?.string, "hello world",
                           "\(backend): the checking client could not read back a range the SAME "
                           + "canvas minted — every annotation the controller delivers through this "
                           + "surface is dropped. Range class: \(type(of: whole))")
        }
    }

    /// The delivery half of the same seam: an annotated-string delivery over a backend-minted range
    /// must land in `spellResults`, the store the underline overlay actually draws from.
    func test_anAnnotatedStringDeliveryOverABackendMintedRangeLands_onBothBackends() throws {
        for backend in [RichTextEditorInputBackendPreference.inputDecIfSupported, .legacy] {
            let editor = try makeEditor(backend)
            let canvas = editor.canvasForTesting
            canvas.isSpellCheckingEnabled = true
            canvas.insertText("hello world")
            // Park the caret away from the word being flagged: `isExcludedSpellRange` refuses to
            // flag the word under a collapsed caret (the in-progress word).
            canvas.setCaret(global: 1)
            // Build the range the way the private controller does — through the canvas's own
            // `UITextInput` witnesses, so it carries the ACTIVE backend's identity. Using
            // `nativeTextRange(forGlobalLocation:length:)` here would be vacuous: that helper mints
            // the canvas's legacy identity under EVERY backend, so the test would pass on both arms
            // while the real delivery path stayed broken (it did, in this test's first draft).
            let wordStart = try XCTUnwrap(canvas.position(from: canvas.beginningOfDocument, offset: 6))
            let wordEnd = try XCTUnwrap(canvas.position(from: wordStart, offset: 5))
            let wordRange = try XCTUnwrap(canvas.textRange(from: wordStart, to: wordEnd),
                                          "\(backend): the backend vended no range for the word")
            if backend != .legacy {
                XCTAssertFalse(wordRange is LegacyTextRange,
                               "the InputDec arm minted the LEGACY identity — this test would then "
                               + "be certifying the wrong backend's seam")
            }
            XCTAssertEqual(canvas.text(in: wordRange), "world",
                           "\(backend): the range does not cover the intended word")
            let delivered = NSMutableAttributedString(string: "world")
            delivered.addAttribute(DocumentCanvasView.displayStyleKey, value: NSNumber(value: 2),
                                   range: NSRange(location: 0, length: 5))
            canvas.nativeReplace(wordRange, withAnnotatedString: delivered,
                                 relativeReplacementRange: NSRange(location: NSNotFound, length: 0))
            let flagged = canvas.spellResults.values.contains { entry in
                entry.ranges.contains { $0.style == .spelling }
            }
            XCTAssertTrue(flagged,
                          "\(backend): a delivered spelling annotation did not reach `spellResults` "
                          + "— \(canvas.spellResults)")
        }
    }

    // MARK: - 2. the oracle

    /// End to end, through the real private checking controller: typing a misspelled word and then
    /// leaving it must flag it.
    ///
    /// The Legacy arm is the calibration and is asserted FIRST — a run in which Legacy does not
    /// flag proves only that this process has no working checker, and the InputDec reading would
    /// then certify nothing.
    func test_aMisspelledWordIsFlagged_onBothBackends() throws {
        func run(_ backend: RichTextEditorInputBackendPreference) throws -> Bool {
            let editor = try makeEditor(backend)
            let canvas = editor.canvasForTesting
            editor.isSpellCheckingEnabled = true
            spin(2.5)                              // the checker loads asynchronously
            canvas.insertText("\(misspelled) ")
            spin(0.5)
            canvas.setCaret(global: 1)             // leave the word — the checker is caret-driven
            canvas.setCaret(global: 1 + ("\(misspelled) " as NSString).length)
            return wait(upTo: 4.0) {
                canvas.spellResults.values.contains { !$0.ranges.isEmpty }
            }
        }
        let legacyFlagged = try run(.legacy)
        try XCTSkipUnless(legacyFlagged,
                          "[ORACLE UNAVAILABLE] the shipping Legacy backend did not flag "
                          + "\"\(misspelled)\" in this process, so the InputDec reading below "
                          + "would certify nothing")
        let inputDecFlagged = try run(.inputDecIfSupported)
        XCTAssertTrue(inputDecFlagged,
                      "THE USER'S DEFECT: with the InputDec backend selected, \"\(misspelled)\" is "
                      + "never flagged, while the Legacy backend in the same process flags it.")
    }

    /// The second half of the user's complaint, and the row the certification harness bills against
    /// LEGACY: correcting a flagged word must clear its flag.
    ///
    /// **Why it is measured PER ARM, IN ISOLATION, and why that matters.** Task P2 measured the
    /// harness's three-arm version of this claim as `[PRE-EXISTING] stock=false legacy=TRUE` — i.e.
    /// the SHIPPING backend never clears. After Task H2's delivery fix the harness's row passes on
    /// all three arms, and Task H2 changed nothing in Legacy's behaviour (its
    /// `globalRange(ofCheckingRange:)` is the identical expression the canvas used to spell inline).
    /// A verdict that moves without a cause is a verdict to distrust, so this test asks each arm the
    /// question alone, with no sibling arm having run first — which is the one variable the
    /// three-arm version cannot hold still.
    func test_correctingAFlaggedWordClearsIt_onBothBackends() throws {
        func run(_ backend: RichTextEditorInputBackendPreference) throws -> (flagged: Bool, cleared: Bool, text: String) {
            let editor = try makeEditor(backend)
            let canvas = editor.canvasForTesting
            editor.isSpellCheckingEnabled = true
            spin(2.5)
            canvas.insertText("\(misspelled) ")
            spin(0.5)
            canvas.setCaret(global: 1)
            canvas.setCaret(global: 1 + ("\(misspelled) " as NSString).length)
            let flagged = wait(upTo: 4.0) {
                canvas.spellResults.values.contains { !$0.ranges.isEmpty }
            }
            guard flagged else { return (false, false, IDStockParity.plainText(canvas)) }

            // Correct the word in place, then leave it again.
            let start = try XCTUnwrap(canvas.position(from: canvas.beginningOfDocument, offset: 0))
            let end = try XCTUnwrap(canvas.position(from: start,
                                                    offset: (misspelled as NSString).length))
            let wordRange = try XCTUnwrap(canvas.textRange(from: start, to: end))
            XCTAssertEqual(canvas.text(in: wordRange), misspelled,
                           "\(backend): the range does not cover the flagged word")
            canvas.replace(wordRange, withText: "misspelled")
            spin(0.5)
            canvas.setCaret(global: 1)
            canvas.setCaret(global: 1 + (IDStockParity.plainText(canvas) as NSString).length)
            let cleared = wait(upTo: 4.0) {
                !canvas.spellResults.values.contains { !$0.ranges.isEmpty }
            }
            return (flagged, cleared, IDStockParity.plainText(canvas))
        }
        let legacy = try run(.legacy)
        let inputDec = try run(.inputDecIfSupported)
        // THE VACUITY GUARD. "the flag did not clear" is not a finding on an arm whose correction
        // never landed — the word would still be misspelled and the flag would be correct.
        XCTAssertEqual(legacy.text, "misspelled ", "the legacy arm's correction did not land")
        XCTAssertEqual(inputDec.text, "misspelled ", "the inputDec arm's correction did not land")
        XCTAssertTrue(legacy.flagged && inputDec.flagged,
                      "both arms must flag first, or the clear assertions below are vacuous "
                      + "(legacy=\(legacy.flagged) inputDec=\(inputDec.flagged))")
        // The InputDec arm — the claim in scope — must clear, as stock does.
        XCTAssertTrue(inputDec.cleared,
                      "the InputDec backend did not clear the flag after a correction")

        // The Legacy arm does NOT, and this is the finding, not an omission. Task P2 measured it
        // (`[PRE-EXISTING] still flagged after correction  stock=false  legacy=TRUE`) and this
        // test re-confirms it in ISOLATION, with the corrections asserted to have landed. It
        // matters because the three-arm harness's row for the same claim now PASSES on all three
        // arms — which, given that Task H2 changed nothing in Legacy, means that row's verdict is
        // order- or timing-dependent inside the harness and must not be read as "Legacy was fixed".
        //
        // `XCTExpectFailure` and not a comment, deliberately: it is strict, so the day Legacy does
        // start clearing this suite goes RED and whoever fixed it is told to come and update the
        // record — which a comment could never do.
        XCTExpectFailure("PRE-EXISTING: the shipping Legacy backend never clears a spelling flag "
                         + "after a correction, where stock does. Not introduced by Task H2 and "
                         + "not in its scope. If this stops failing, remove the expectation.") {
            XCTAssertTrue(legacy.cleared,
                          "the SHIPPING Legacy backend did not clear the flag after a correction")
        }
    }
}
#endif
