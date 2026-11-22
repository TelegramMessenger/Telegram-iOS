#if canImport(UIKit)
import UIKit
import XCTest
import RichTextEditorCore
import RichTextEditorDifferentialHarness
import RichTextEditorStockParitySupport
@testable import RichTextEditorUIKit

/// **Ported from `/Users/isaac/Documents/InputDec/Tests/IDBlockSpellingIntegrationTests.m`**
/// (541 lines, 12 tests). See `PROVENANCE.md`. **One test is ported**; the other eleven are dropped
/// and each reason is recorded there and summarised below.
///
/// ## Why this one test is the point of the whole task
///
/// The user's fifth and still-open defect is *"corrected words are not underlined"*. Task G1/G2
/// ranked three suspects for it but could not measure any of them (read-only audits). Upstream's
/// `testMisspellingUsesNativeTemporaryPixelsAndCorrectionDropsBelowHalf` is the **only** end-to-end
/// assertion in the entire upstream corpus that would catch it: it types a misspelled word, waits
/// for red pixels to actually appear under it, and requires correcting the word to drop them.
///
/// It also pins the *mechanism*, which is the part that keeps being lost: the underline must come
/// from **temporary rendering attributes** and must NOT be in the canonical storage. Upstream
/// asserts exactly that (`XCTAssertNil(canonical[NSUnderlineStyleAttributeName])`) and this port
/// keeps it. A host that "fixed" the symptom by writing `.underline` into the document model would
/// pass a pixel test and fail this one — and would corrupt every message the user then sent.
///
/// ## Three arms, and what a zero means
///
/// Stock `UITextView` is the oracle. **If the oracle shows no red pixels, this test fails on the
/// oracle**, not silently: a test host where UIKit itself will not render a misspelling underline
/// cannot certify anybody, and three arms all reading zero would compare EQUAL and report a
/// meaningless pass. That guard is asserted first, before any comparison.
///
/// ## The eleven dropped tests, in one sentence
///
/// Ten of them assert directly on `IDRichTextAnnotationStore`, `IDCanonicalTextStorageAdapter`,
/// `IDBlockDocument` or `IDPrivateUIKit+RichTextLayout` — upstream **product source**, which Global
/// Constraint 12 forbids porting — and the eleventh
/// (`testTemporaryPrivateWrappersPreserveExactKeyValueRangeAndRejectWrongCanvasABI`) tests
/// upstream's own private-API wrapper functions, which do not exist on this side. PROVENANCE.md
/// lists them individually.
@available(iOS 17.0, *)
@MainActor
final class IDBlockSpellingIntegrationParityTests: XCTestCase {

    private var violations = IDStockParity.ViolationLog()

    /// Upstream's fixture word and its correction.
    private let misspelled = "mispelled"
    private let corrected = "misspelled"

    override func setUpWithError() throws {
        try super.setUpWithError()
        try XCTSkipUnless(IDTextEditorBackend.isSupported(),
                          "InputDec backend unsupported on this runtime")
        violations = IDStockParity.ViolationLog()
        IDStockParity.installContractReporter(violations, in: self)
    }

    // MARK: - Pixel instrumentation (upstream's `redMarkerPixelsForCanonicalRange:` / `IDRenderView`)

    /// One render of `view`, reduced to the two counts every assertion here needs.
    ///
    /// `red` is what the misspelling marker paints; `ink` is every pixel that is not the white
    /// background. **`ink` exists to tell a real zero from a blank render.** The first draft of this
    /// file used `drawHierarchy(in:afterScreenUpdates: true)` and got zero red pixels for a KNOWN
    /// red underline applied through public `NSAttributedString` attributes — because
    /// `drawHierarchy` renders nothing for a view whose window is not actually on screen, which is
    /// every window in an xctest process. Without an `ink` count that reads as "no marker" instead
    /// of "no image", and the whole file would have reported an environment limitation that was
    /// really its own bug. `layer.render(in:)` does not have that dependency.
    private struct PixelCounts { var red = 0; var ink = 0 }

    private func pixels(in view: UIView, band: CGRect) -> PixelCounts {
        let bounds = view.bounds
        guard bounds.width > 1, bounds.height > 1 else { return PixelCounts() }
        let roi = band.intersection(bounds)
        guard !roi.isNull, roi.width >= 1, roi.height >= 1 else { return PixelCounts() }

        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        let image = renderer.image { context in
            view.layer.render(in: context.cgContext)
        }
        guard let cgImage = image.cgImage else { return PixelCounts() }

        let width = cgImage.width, height = cgImage.height
        var raw = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(data: &raw, width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return PixelCounts() }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // The bitmap is in pixels; the band is in points.
        let scale = CGFloat(width) / bounds.width
        let x0 = max(0, Int(roi.minX * scale)), x1 = min(width, Int(roi.maxX * scale))
        let y0 = max(0, Int(roi.minY * scale)), y1 = min(height, Int(roi.maxY * scale))
        var counts = PixelCounts()
        for y in y0..<max(y0, y1) {
            for x in x0..<max(x0, x1) {
                let i = (y * width + x) * 4
                let r = Int(raw[i]), g = Int(raw[i + 1]), b = Int(raw[i + 2]), a = Int(raw[i + 3])
                if a > 8 && !(r > 240 && g > 240 && b > 240) { counts.ink += 1 }
                // Loose on hue, deliberately: the exact system misspelling red moves across OS
                // versions and appearance modes, and every assertion here is about the count
                // CHANGING, never about a specific colour.
                if r > 96 && r - g > 48 && r - b > 48 { counts.red += 1 }
            }
        }
        return counts
    }

    private func redPixels(in view: UIView, band: CGRect) -> Int { pixels(in: view, band: band).red }

    /// The band a misspelling marker is drawn in: the bottom of the word's first rect, extended a
    /// few points down, since the underline sits below the baseline and may overhang the line box.
    private func markerBand(_ input: UITextInput, characterRange: NSRange) -> CGRect? {
        guard let range = IDStockParity.textRange(input, forCharacterRange: characterRange) else {
            return nil
        }
        let rect = input.firstRect(for: range)
        guard rect.width.isFinite, rect.height.isFinite, rect.width > 0 else { return nil }
        // The whole line box plus 6pt below it. A tight band under the baseline was the second
        // instrument bug: a misspelling marker can be drawn below the rect `firstRect(for:)`
        // reports, and on the host arms the pinned line box makes that overhang larger.
        return rect.insetBy(dx: 0, dy: -6.0)
    }

    private func spin(_ seconds: TimeInterval) {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02))
        }
    }

    /// Upstream's `IDWaitForCondition`: poll for up to `seconds`, spinning the main run loop.
    @discardableResult
    private func wait(upTo seconds: TimeInterval, for condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }
        return condition()
    }

    // MARK: - Calibration — is the instrument or the environment at fault?

    /// **This test decides how to read the one below it.** The ported test reports that stock
    /// `UITextView` paints ZERO red pixels under a misspelled word in this xctest process. That has
    /// two possible causes and they call for opposite responses:
    ///
    /// * the **instrument** is broken (`drawHierarchy` misses the marker, or the red predicate is
    ///   wrong) — then the port's own readings are worthless too and this file must be fixed;
    /// * the **environment** cannot run the system text checker — then the instrument is fine, no
    ///   automated test in this process can see a spelling marker, and that is itself the reason the
    ///   user has been the only oracle for the "corrected words are not underlined" defect.
    ///
    /// So this draws a **known** red underline through public `NSAttributedString` attributes — no
    /// spell checker involved — and requires the counter to find it. If this passes and the ported
    /// test still reads zero, the cause is unambiguously the environment.
    func test_0_calibrationTheRedPixelCounterSeesAKnownRedUnderline() {
        let view = IDStockParity.makeStock(frame: CGRect(x: 0, y: 0, width: 340, height: 200))
        view.attributedText = NSAttributedString(string: "mispelled word", attributes: [
            .font: IDStockParity.font,
            .foregroundColor: UIColor.black,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .underlineColor: UIColor.red,
        ])
        IDStockParity.host([view], in: self)
        view.layoutIfNeeded()

        let band = markerBand(view, characterRange: NSRange(location: 0, length: 9))
        let counts = band.map { pixels(in: view, band: $0) } ?? PixelCounts()

        XCTAssertNotNil(band, "the instrument could not even locate the word's rect — "
                        + "firstRect(for:) or the character-axis map is broken, not the environment")
        XCTAssertGreaterThan(counts.ink, 3,
                             "[INSTRUMENT BROKEN — BLANK RENDER] the render produced no non-white "
                             + "pixels at all under a word that is definitely drawn. The renderer, "
                             + "not the red predicate, is at fault; every pixel reading in this file "
                             + "is meaningless until it is fixed.")
        XCTAssertGreaterThan(counts.red, 3,
                             "[INSTRUMENT BROKEN — RED PREDICATE] the render has ink "
                             + "(\(counts.ink) px) but no red (\(counts.red) px), under a red "
                             + "underline applied through public NSAttributedString attributes. The "
                             + "band or the colour threshold is wrong.")
    }

    // MARK: - The ported test

    /// Upstream: `testMisspellingUsesNativeTemporaryPixelsAndCorrectionDropsBelowHalf`.
    ///
    /// Upstream's four claims, all kept:
    /// 1. typing a misspelled word eventually paints red pixels under it (`> 3`);
    /// 2. the canonical storage carries **no** `NSUnderlineStyle` / `NSUnderlineColor` at that index
    ///    — the marker is a temporary rendering attribute, not model state;
    /// 3. replacing the word with its correct spelling drops the red pixel count to **less than
    ///    half**;
    /// 4. (implicit in upstream's `installedViewWithBlocks:` + `becomeFirstResponder`) the whole
    ///    thing runs on a hosted, focused, spell-checking-enabled editor.
    ///
    /// Upstream's `IDAttachSpellingObservation` XCTAttachment diagnostics are dropped — they are
    /// observability, not assertions — but every number they carried is in the failure messages.
    func test_aMisspellingIsMarkedByTemporaryPixelsAndCorrectingItRemovesThem() throws {
        let scenario = "type \"\(misspelled) \", then replace it with \"\(corrected)\""
        let wordRange = NSRange(location: 0, length: (misspelled as NSString).length)

        struct SpellingReading {
            var misspelledPixels = 0
            var correctedPixels = 0
            var canonicalUnderlineAtIndex1 = "unknown"
            var textAfterCorrection = ""
        }

        // --- stock arm ---
        let stock = IDStockParity.makeStock(frame: CGRect(x: 0, y: 0, width: 340, height: 200))
        stock.spellCheckingType = .yes
        stock.autocorrectionType = .no          // corrections would rewrite the fixture out from under us
        IDStockParity.host([stock], in: self)
        XCTAssertTrue(stock.becomeFirstResponder())
        stock.insertText("\(misspelled) ")
        var stockReading = SpellingReading()
        _ = wait(upTo: 4.0) {
            guard let band = self.markerBand(stock, characterRange: wordRange) else { return false }
            stockReading.misspelledPixels = self.redPixels(in: stock, band: band)
            return stockReading.misspelledPixels > 3
        }
        stockReading.canonicalUnderlineAtIndex1 =
            String(describing: stock.textStorage.attribute(.underlineStyle, at: 1,
                                                           effectiveRange: nil) as Any)
        if let start = stock.position(from: stock.beginningOfDocument, offset: 0),
           let end = stock.position(from: stock.beginningOfDocument, offset: wordRange.length),
           let range = stock.textRange(from: start, to: end) {
            stock.replace(range, withText: corrected)
        }
        let stockCorrectedRange = NSRange(location: 0, length: (corrected as NSString).length)
        _ = wait(upTo: 4.0) {
            guard let band = self.markerBand(stock, characterRange: stockCorrectedRange) else { return false }
            stockReading.correctedPixels = self.redPixels(in: stock, band: band)
            return stockReading.correctedPixels * 2 < stockReading.misspelledPixels
        }
        stockReading.textAfterCorrection = stock.text ?? ""

        // --- THE ORACLE GUARD. Evaluated before any comparison. ---
        //
        // A `XCTSkip`, not an `XCTFail`, and the distinction is deliberate. A skip is not a pass —
        // it records "this claim is NOT CERTIFIED", which is the truthful state when the oracle
        // itself is silent. Failing instead would put a permanent, non-actionable red in the suite
        // that readers learn to ignore, which is how a real failure gets missed later. The
        // calibration test above proves the instrument works, so this branch means the environment
        // and nothing else.
        //
        // MEASURED 2026-08-26 on iPhone 17 Pro K1: this branch is TAKEN — stock UITextView paints
        // no misspelling marker in a SwiftPM xctest process. Which means the user's open
        // "corrected words are not underlined" defect CANNOT be certified by any test in this
        // process, and that is the single most important thing this file has to say.
        try XCTSkipUnless(
            stockReading.misspelledPixels > 3,
            "[ORACLE UNAVAILABLE — NOT CERTIFIED] stock UITextView painted no misspelling marker in "
            + "this test host (\(stockReading.misspelledPixels) red px under \"\(misspelled)\"), so "
            + "there is no oracle to certify either Telegram backend against. Three arms all "
            + "reading zero would compare EQUAL and report a meaningless pass, which is why this "
            + "declines to run rather than passing. The instrument is NOT the cause: "
            + "test_0_calibration… proves the pixel counter sees a known red underline. This is an "
            + "environment limit — a headless xctest process does not run the system text checker — "
            + "and it is why the underline defect has had no automated oracle.")

        // --- host arms ---
        func run(_ backend: RichTextEditorInputBackendPreference) throws -> SpellingReading {
            let editor = try IDStockParity.makeHost(paragraphs: [""], backend: backend,
                                                    frame: CGRect(x: 0, y: 0, width: 340, height: 200))
            editor.isSpellCheckingEnabled = true
            IDStockParity.host([editor], in: self)
            XCTAssertTrue(editor.becomeFirstResponder())
            let canvas = IDStockParity.input(of: editor)
            canvas.insertText("\(self.misspelled) ")
            // The editor's checker is selection-driven (see `NativeTextCheckingLiveTests`): a word is
            // checked when the caret LEAVES it. Typing the trailing space already moves past it; the
            // spin gives the async checker time to load and answer.
            self.spin(0.5)

            var reading = SpellingReading()
            _ = self.wait(upTo: 4.0) {
                guard let band = self.markerBand(canvas, characterRange: wordRange) else { return false }
                reading.misspelledPixels = self.redPixels(in: editor, band: band)
                return reading.misspelledPixels > 3
            }
            // Upstream's claim 2, in this host's terms: the marker must not have been written into
            // the document model. A backend that "fixed" underlining by setting `.underline` would
            // pass the pixel half of this test and corrupt every message the user sent.
            let modelUnderlines = editor.document.blocks.compactMap { block -> Bool? in
                guard case let .paragraph(paragraph) = block else { return nil }
                return paragraph.runs.contains { $0.attributes.underline }
            }
            reading.canonicalUnderlineAtIndex1 = modelUnderlines.contains(true) ? "IN MODEL" : "nil"

            if let range = IDStockParity.textRange(canvas, forCharacterRange: wordRange) {
                canvas.replace(range, withText: self.corrected)
            }
            self.spin(0.5)
            let correctedRange = NSRange(location: 0, length: (self.corrected as NSString).length)
            _ = self.wait(upTo: 4.0) {
                guard let band = self.markerBand(canvas, characterRange: correctedRange) else { return false }
                reading.correctedPixels = self.redPixels(in: editor, band: band)
                return reading.correctedPixels * 2 < reading.misspelledPixels
            }
            reading.textAfterCorrection = IDStockParity.plainText(canvas)
            return reading
        }
        let idReading = try run(.inputDecIfSupported)
        let capturedViolations = violations.messages
        let legacyReading = try run(.legacy)

        // 1. A misspelling is marked at all.
        IDStockParity.assertField("misspelling is marked", scenario: scenario,
                                  stock: "\(stockReading.misspelledPixels > 3)",
                                  inputDec: "\(idReading.misspelledPixels > 3)",
                                  legacy: "\(legacyReading.misspelledPixels > 3)",
                                  note: "red px under \"\(misspelled)\": "
                                      + "stock=\(stockReading.misspelledPixels) "
                                      + "inputDec=\(idReading.misspelledPixels) "
                                      + "legacy=\(legacyReading.misspelledPixels)")

        // 2. The marker is NOT canonical storage.
        IDStockParity.assertField("marker is not in the model", scenario: scenario,
                                  stock: stockReading.canonicalUnderlineAtIndex1 == "nil" ? "nil" : "IN MODEL",
                                  inputDec: idReading.canonicalUnderlineAtIndex1,
                                  legacy: legacyReading.canonicalUnderlineAtIndex1,
                                  note: "a marker written into the document model would travel into "
                                      + "the sent message")

        // 3. Correcting the word removes the marker.
        IDStockParity.assertField("correction drops the marker below half", scenario: scenario,
                                  stock: "\(stockReading.correctedPixels * 2 < stockReading.misspelledPixels)",
                                  inputDec: "\(idReading.correctedPixels * 2 < idReading.misspelledPixels)",
                                  legacy: "\(legacyReading.correctedPixels * 2 < legacyReading.misspelledPixels)",
                                  note: "red px after correction: "
                                      + "stock=\(stockReading.correctedPixels) "
                                      + "inputDec=\(idReading.correctedPixels) "
                                      + "legacy=\(legacyReading.correctedPixels)")

        // 4. The correction actually landed — without this, claim 3 passes trivially on any arm
        //    whose `replace` did nothing, which is precisely the failure mode suite 1 found.
        IDStockParity.assertField("text after correction", scenario: scenario,
                                  stock: stockReading.textAfterCorrection.debugDescription,
                                  inputDec: idReading.textAfterCorrection.debugDescription,
                                  legacy: legacyReading.textAfterCorrection.debugDescription)

        XCTAssertEqual(capturedViolations, [],
                       "[PORT-DEFECT] \(scenario) · the InputDec kernel reported contract violations")
    }

    // MARK: - THE ANNOTATION ORACLE (Task P2 — new; the pixel test above cannot reach this)

    /// **This is the test the user's open "corrected words are not underlined" defect needs, and
    /// until Task P2 nothing in this process could express it.**
    ///
    /// Task P1 concluded the defect "has no automated oracle in this test process and cannot
    /// acquire one here". That was right about PIXELS and wrong to stop there.
    /// `IDSpellingReadinessProbe`, ported in Task P2, carries a second, non-pixel signal:
    /// `IDRenderingAttributesDifferFromPersistentAttributes` walks a stock `UITextView`'s TextKit 2
    /// **rendering** attributes and reports the ranges whose attributes differ from the persistent
    /// ones — "the system applied a temporary annotation here", which is what a misspelling marker
    /// IS. `IDSpellingOracleFeasibilityTests` measures that this signal is present AND
    /// discriminating in this process, and that the private checking pipeline reaches upstream's
    /// terminal `firstMissingTransition == "complete"`.
    ///
    /// The host arms cannot be read the same way — a `DocumentCanvasView` has no
    /// `NSTextLayoutManager` spanning the document. Their equivalent state is
    /// `DocumentCanvasView.spellResults`, the BlockID-keyed side table
    /// `TelegramAnnotationInputClient.addAnnotation` writes into. Both arms answer the same
    /// PREDICATE — *is this word flagged as a transient annotation?* — through the mechanism each
    /// one has, which is what the pixel test above was doing when a pixel was available.
    ///
    /// ## The stimulus, and why the host arms need a caret move
    ///
    /// Both editors' checkers are **selection-driven**: a word is checked when the caret LEAVES it.
    /// On stock, typing the trailing space is enough — UIKit's own controller sees the selection
    /// change. On the host arms a programmatic `insertText` through this harness does NOT reach
    /// `nativeCheckOnSelectionChange`; measured 2026-08-26, BOTH host arms flag nothing after typing
    /// alone, and Legacy flags `{0, 9}` as soon as the caret is moved explicitly past the word. So
    /// the host arms are driven the way the in-tree `NativeTextCheckingLiveTests` drives them, and
    /// the way a user's finger does: type, then move the caret past the word. Recorded in
    /// `PROVENANCE.md` as a deviation — a stimulus that is only correct for one arm is how a suite
    /// ends up certifying the harness instead of the host.
    ///
    /// ## Claims
    ///
    /// 1. A misspelled word is flagged.
    /// 2. **A correctly-spelled word is NOT flagged.** Without this, a backend that flags
    ///    everything — or a probe reporting a constant true — passes claim 1 and certifies nothing.
    /// 3. Correcting the word clears the flag: the user's actual defect. **Declined per arm when
    ///    claim 1 did not fire on that arm**, because "the flag is gone" is vacuously true where no
    ///    flag ever existed, and three vacuous trues compare equal and pass.
    /// 4. The flag never enters the document model. A backend that "fixed" underlining by writing
    ///    `.underline` into the document would satisfy 1–3 and corrupt every message sent.
    func test_theAnnotationOracleFlagsAMisspellingAndClearsItOnCorrection() throws {
        let scenario = "annotation oracle: \"\(misspelled) \" flagged, corrected, cleared"
        let wordRange = NSRange(location: 0, length: (misspelled as NSString).length)

        struct AnnotationReading {
            var misspelledFlagged = "unknown"
            var correctSpellingFlagged = "unknown"
            var flaggedAfterCorrection = "unknown"
            var inModel = "unknown"
            var textAfterCorrection = ""
        }

        // --- stock arm, driven through the PORTED sampler ---
        //
        // Not hand-rolled. A hand-rolled drive that omitted `ensureLayoutForBounds` before sampling
        // read an empty set and made this whole test decline with "no oracle" for an INSTRUMENT
        // reason — the same class of mistake as P1's `drawHierarchy` bug. It was caught only because
        // `IDSpellingOracleFeasibilityTests` independently proves the signal fires.
        // INSTRUMENT WARM-UP, and it is load-bearing. MEASURED 2026-08-26: the FIRST text view
        // driven in a fresh test process receives NO annotation at all — the system text checker
        // loads asynchronously and the first word is typed before it is ready — while the second and
        // every later view are annotated normally. Upstream encodes the same fact rather than
        // fixing it: `IDObserveStockSpellingReadiness` types a WARM-UP word ("mispelled ") and
        // measures a SECOND one ("wrng"). Without this line the oracle guard below fires on a cold
        // process and the test declines having certified nothing — an instrument artefact
        // indistinguishable, from the outside, from "the environment cannot do this".
        let warmUpView = try XCTUnwrap(
            IDStockParity.makeSubject(.stock, IDParityFixture(blocks: [""]), in: self).stock)
        _ = IDObserveStockAnnotationRangesForText(warmUpView, "\(misspelled) ", 2.0)

        var stockReading = AnnotationReading()
        let stockMisspelledView = try XCTUnwrap(
            IDStockParity.makeSubject(.stock, IDParityFixture(blocks: [""]), in: self).stock)
        let stockMisspelledRanges =
            IDObserveStockAnnotationRangesForText(stockMisspelledView, "\(misspelled) ", 2.0)
        stockReading.misspelledFlagged = "\(!stockMisspelledRanges.isEmpty)"
        stockReading.inModel = stockMisspelledView.textStorage
            .attribute(.underlineStyle, at: 1, effectiveRange: nil) == nil ? "nil" : "IN MODEL"

        // --- THE ORACLE GUARD, same discipline as the pixel test: a silent oracle declines. ---
        try XCTSkipUnless(
            stockReading.misspelledFlagged == "true",
            "[ORACLE UNAVAILABLE — NOT CERTIFIED] the stock temporary-annotation signal did not "
            + "fire for \"\(misspelled)\", so there is nothing to certify either Telegram backend "
            + "against. IDSpellingOracleFeasibilityTests measures this signal directly; if this "
            + "skip fires, read that suite's failures first — it names the pipeline step that "
            + "stopped.")

        // CORRECT THE WORD AND RE-SAMPLE **BEFORE** ANY OTHER SUBJECT IS BUILT.
        //
        // Ordering, not style. `IDStockParityRuntime.h` states the invariant this depends on: the
        // sampler deliberately does NOT resign first responder, "so a caller can drive a further
        // edit (a correction) and sample again — the checker does not run for a view that has
        // resigned". `makeSubject(focused: true)` asserts `becomeFirstResponder()` returns true,
        // which necessarily resigns whoever held it. So building the correctly-spelled subject
        // between the correction and its sample — which this test did until the P2 review caught it
        // — takes claim 3's stock reading in exactly the state the header says invalidates it, and
        // the `[PRE-EXISTING]` billing that rests on it could not be trusted.
        //
        // The correctly-spelled calibration subject is therefore built AFTER this block, and the
        // guard below asserts the invariant instead of assuming it.
        if let start = stockMisspelledView.position(from: stockMisspelledView.beginningOfDocument,
                                                    offset: 0),
           let end = stockMisspelledView.position(from: stockMisspelledView.beginningOfDocument,
                                                  offset: wordRange.length),
           let range = stockMisspelledView.textRange(from: start, to: end) {
            stockMisspelledView.replace(range, withText: corrected)
        }
        let stockLength = (stockMisspelledView.text ?? "").utf16.count
        stockMisspelledView.selectedRange = NSRange(location: 0, length: 0)
        stockMisspelledView.selectedRange = NSRange(location: stockLength, length: 0)
        // The guard claim 1 has and claim 3 did not. A sample taken from a resigned view reads
        // "not flagged" for an instrument reason, which is indistinguishable from the real finding.
        XCTAssertTrue(stockMisspelledView.isFirstResponder,
                      "[ORACLE INVALID] the stock arm lost first responder before claim 3's sample, "
                      + "so 'the marker went away' would be an instrument artefact. Something built "
                      + "another focused subject between the correction and this sample.")
        let stockAfterCorrection = IDStockPumpAndSampleAnnotationRanges(stockMisspelledView, 2.0)
        stockReading.flaggedAfterCorrection = "\(!stockAfterCorrection.isEmpty)"
        stockReading.textAfterCorrection = stockMisspelledView.text ?? ""
        XCTAssertEqual(stockReading.textAfterCorrection, "\(corrected) ",
                       "[ORACLE INVALID] the stock arm's correction did not land, so claim 3 would "
                       + "be measuring an uncorrected document")

        // Claim 2's calibration, built LAST for the reason above.
        let stockCorrectView = try XCTUnwrap(
            IDStockParity.makeSubject(.stock, IDParityFixture(blocks: [""]), in: self).stock)
        let stockCorrectRanges =
            IDObserveStockAnnotationRangesForText(stockCorrectView, "\(corrected) ", 2.0)
        stockReading.correctSpellingFlagged = "\(!stockCorrectRanges.isEmpty)"
        XCTAssertEqual(stockReading.correctSpellingFlagged, "false",
                       "[ORACLE NOT DISCRIMINATING] the stock signal ALSO fired for the correctly "
                       + "spelled \"\(corrected)\" — every claim below would be vacuous.")

        // --- host arms ---
        func hostFlagged(_ canvas: DocumentCanvasView) -> Bool {
            canvas.spellResults.values.contains { !$0.ranges.isEmpty }
        }
        func drive(_ editor: RichTextEditorView, typing text: String) -> DocumentCanvasView {
            let canvas = editor.canvasForTesting
            editor.isSpellCheckingEnabled = true
            self.spin(2.5)          // the checker loads asynchronously (NativeTextCheckingLiveTests)
            canvas.insertText(text)
            self.spin(0.5)
            canvas.setCaret(global: 1)
            canvas.setCaret(global: 1 + (text as NSString).length)
            return canvas
        }
        func runHost(_ arm: IDParityArm) throws -> AnnotationReading {
            var reading = AnnotationReading()

            let misspelledEditor = try XCTUnwrap(
                IDStockParity.makeSubject(arm, IDParityFixture(blocks: [""]), in: self).editor)
            let canvas = drive(misspelledEditor, typing: "\(self.misspelled) ")
            let flagged = self.wait(upTo: 4.0) { hostFlagged(canvas) }
            reading.misspelledFlagged = "\(flagged)"

            // Claim 4, read before the correction so a later mutation cannot mask it.
            let underlinedInModel = misspelledEditor.document.blocks.contains { block -> Bool in
                guard case let .paragraph(paragraph) = block else { return false }
                return paragraph.runs.contains { $0.attributes.underline }
            }
            reading.inModel = underlinedInModel ? "IN MODEL" : "nil"

            // Claim 3: correct the word in place and require the flag to go away.
            if let range = IDStockParity.textRange(canvas, forCharacterRange: wordRange) {
                canvas.replace(range, withText: self.corrected)
            }
            self.spin(0.5)
            let length = (IDStockParity.plainText(canvas) as NSString).length
            canvas.setCaret(global: 1)
            canvas.setCaret(global: 1 + length)
            let cleared = self.wait(upTo: 4.0) { !hostFlagged(canvas) }
            // THE VACUITY GUARD, per arm. "The flag is gone" is trivially true on an arm that never
            // set one, and three trivial trues compare EQUAL and pass having certified nothing.
            reading.flaggedAfterCorrection =
                flagged ? "\(!cleared)" : IDStockParity.decline("never flagged, so nothing to clear")
            reading.textAfterCorrection = IDStockParity.plainText(canvas)

            // Claim 2's per-arm calibration: a separate editor, correctly spelled from the start.
            let correctEditor = try XCTUnwrap(
                IDStockParity.makeSubject(arm, IDParityFixture(blocks: [""]), in: self).editor)
            let correctCanvas = drive(correctEditor, typing: "\(self.corrected) ")
            self.spin(1.0)
            reading.correctSpellingFlagged = "\(hostFlagged(correctCanvas))"
            return reading
        }
        let idReading = try runHost(.inputDec)
        let capturedViolations = violations.messages
        let legacyReading = try runHost(.legacy)

        IDStockParity.assertField("misspelling is flagged", scenario: scenario,
                                  stock: stockReading.misspelledFlagged,
                                  inputDec: idReading.misspelledFlagged,
                                  legacy: legacyReading.misspelledFlagged,
                                  note: "claim 1 — the transient annotation exists at all")
        IDStockParity.assertField("correct spelling is NOT flagged", scenario: scenario,
                                  stock: stockReading.correctSpellingFlagged,
                                  inputDec: idReading.correctSpellingFlagged,
                                  legacy: legacyReading.correctSpellingFlagged,
                                  note: "claim 2 — the calibration; if this reads true anywhere, "
                                      + "that arm's claim 1 measured nothing")
        IDStockParity.assertField("still flagged after correction", scenario: scenario,
                                  stock: stockReading.flaggedAfterCorrection,
                                  inputDec: idReading.flaggedAfterCorrection,
                                  legacy: legacyReading.flaggedAfterCorrection,
                                  note: "claim 3 — THE USER'S OPEN DEFECT: correcting a word must "
                                      + "clear its marker")
        IDStockParity.assertField("text after correction", scenario: scenario,
                                  stock: stockReading.textAfterCorrection.debugDescription,
                                  inputDec: idReading.textAfterCorrection.debugDescription,
                                  legacy: legacyReading.textAfterCorrection.debugDescription,
                                  note: "without this, claim 3 passes trivially on an arm whose "
                                      + "`replace` did nothing — the exact failure mode the "
                                      + "inline-formatting suite found")
        IDStockParity.assertField("marker is not in the model", scenario: scenario,
                                  stock: stockReading.inModel, inputDec: idReading.inModel,
                                  legacy: legacyReading.inModel,
                                  note: "claim 4 — a marker written into the document model would "
                                      + "travel into the message the user sends")
        XCTAssertEqual(capturedViolations, [],
                       "[PORT-DEFECT] \(scenario) · the InputDec kernel reported contract violations")
    }

    // MARK: - WHERE the InputDec spelling path stops

    /// The test above establishes THAT the InputDec backend flags nothing. This one localises it,
    /// using the ported lifecycle trace.
    ///
    /// `IDObserveSpellingLifecycleWithStimulus` installs upstream's own swizzles on the private
    /// `UITextInputController` / `UITextCheckingController` and records which steps fire. Those
    /// hooks are installed on the CLASS, not on a view, so they observe the checking pipeline
    /// whatever drives it — which is what makes them usable against a host that is not a
    /// `UITextView`. Upstream's terminal vocabulary is reused unchanged: `hooksUnavailable` →
    /// `selectionDepartureUnavailable` → `selectionCheckUnavailable` → `wordCheckUnavailable` →
    /// `checkerUnavailable` → `keyboardLanguagesUnavailable` → `annotationUnavailable` →
    /// `complete`.
    ///
    /// The distinction it draws is the actionable one, and no other test in this directory can draw
    /// it: `wordCheckUnavailable` would mean the controller never asks the host about the word (a
    /// DRIVING defect — the host is not reporting the selection change), while `annotationUnavailable`
    /// would mean it asks, gets an answer, and the annotation never lands (a DELIVERY defect —
    /// `addAnnotation` refusing what the controller sends, which is G1/G2's ranked suspect 1).
    ///
    /// Asserted per arm rather than three-way: `firstMissingTransition` is a property of the
    /// pipeline, and a stock `UITextView` and a `DocumentCanvasView` do not have the same
    /// annotation-sampling surface (deviation P2-3), so an equality comparison across them would be
    /// comparing two different instruments. The arms are still compared — on the ONE step whose
    /// meaning is identical everywhere, `checking.checkWord`.
    ///
    /// ## What it measured, 2026-08-26
    ///
    /// | arm | `firstMissingTransition` | `checking.checkWord` | `checking.textChecker` |
    /// | --- | --- | --- | --- |
    /// | stock | `checkerUnavailable` | 1 | 1 |
    /// | inputDec | `selectionDepartureUnavailable` | **1** | 1 |
    /// | legacy | `selectionDepartureUnavailable` | **1** | 1 |
    ///
    /// **`checkSpellingForWordInRange:` fires once on EVERY arm, InputDec included.** So the
    /// controller does ask the InputDec host about the word, and the two host arms are
    /// indistinguishable at every step this trace can see — yet only Legacy ends up with a flag in
    /// `spellResults`. That places the InputDec spelling defect **downstream of the controller's
    /// request: in DELIVERY, not in driving.** It is the `addAnnotation` side, which is exactly
    /// G1/G2's ranked suspect 1 (`addAnnotation` refusing every value the controller sends), and it
    /// narrows the search from "spelling is broken" to one method.
    ///
    /// The `selectionDepartureUnavailable` terminal on the host arms is NOT the finding and must not
    /// be read as one: `IDFirstMissingSpellingLifecycleTransition` walks its steps in a fixed order
    /// and stops at the first missing one, and `didChangeSelectionFromRange:` is checked before the
    /// word check. The host drives the checker through its own selection path rather than that
    /// private callback, so the step is absent on both host arms equally. The `checkWord` count is
    /// the sharper signal, which is why that is what the cross-arm assertion uses.
    func test_whichStepOfTheCheckingPipelineTheHostArmsReach() throws {
        var traces: [IDParityArm: [String: Any]] = [:]

        // Stock first: it is the calibration. If the hooks do not fire for a plain UITextView the
        // instrument is broken and neither host reading means anything.
        let stock = try XCTUnwrap(
            IDStockParity.makeSubject(.stock, IDParityFixture(blocks: [""]), in: self).stock)
        stock.spellCheckingType = .yes
        stock.autocorrectionType = .no
        IDSetContinuousSpellCheckingEnabled(stock, true)
        // MEASURED: `-isContinuousSpellCheckingEnabled` reads back FALSE here even immediately after
        // setting it, on a view that is first responder and does go on to be spell-checked. So it is
        // NOT a usable precondition — it is carried into the diagnostic note below instead, and the
        // real calibration is `checking.checkWord` firing on the stock arm, which is asserted.
        // Asserting the readback would have failed the test for a reason unrelated to the pipeline.
        let stockContinuousReadback = IDIsContinuousSpellCheckingEnabled(stock)
        traces[.stock] = IDObserveSpellingLifecycleWithStimulus("stock", 2.5, {
            stock.insertText("\(self.misspelled) ")
            stock.selectedRange = NSRange(location: 0, length: 0)
            stock.selectedRange = NSRange(location: (stock.text ?? "").utf16.count, length: 0)
        }, {
            IDStockTemporaryRenderingRanges(stock)
        }).dictionaryRepresentation

        for arm in [IDParityArm.inputDec, .legacy] {
            let editor = try XCTUnwrap(
                IDStockParity.makeSubject(arm, IDParityFixture(blocks: [""]), in: self).editor)
            let canvas = editor.canvasForTesting
            editor.isSpellCheckingEnabled = true
            spin(2.5)                       // the checker loads asynchronously
            traces[arm] = IDObserveSpellingLifecycleWithStimulus(arm.rawValue, 2.5, {
                canvas.insertText("\(self.misspelled) ")
                canvas.setCaret(global: 1)
                canvas.setCaret(global: 1 + (self.misspelled as NSString).length + 1)
            }, {
                canvas.spellResults.values.flatMap(\.ranges).map {
                    ["location": NSNumber(value: $0.range.location),
                     "length": NSNumber(value: $0.range.length)]
                }
            }).dictionaryRepresentation
        }

        func transition(_ arm: IDParityArm) -> String {
            (traces[arm]?["firstMissingTransition"] as? String) ?? "<no trace>"
        }
        func events(_ arm: IDParityArm) -> [[String: Any]] {
            (traces[arm]?["events"] as? [[String: Any]]) ?? []
        }
        func count(_ arm: IDParityArm, _ name: String) -> Int {
            events(arm).filter { ($0["name"] as? String) == name }.count
        }

        // The instrument calibration. Without it a host arm reading `hooksUnavailable` would be
        // indistinguishable from "this build cannot see the private classes at all".
        XCTAssertEqual(traces[.stock]?["hooksInstalled"] as? Bool, true,
                       "the lifecycle swizzles did not install — every reading here is moot")
        XCTAssertEqual(traces[.stock]?["hooksRestored"] as? Bool, true,
                       "the swizzles were NOT restored; every later test in this process is running "
                       + "against patched UIKit classes")
        XCTAssertGreaterThan(count(.stock, "checking.checkWord"), 0,
                             "stock did not reach checkSpellingForWordInRange under this stimulus, "
                             + "so the host readings below cannot be interpreted. stock trace: "
                             + "\(transition(.stock)) "
                             + "isContinuousSpellCheckingEnabled=\(stockContinuousReadback)")

        // THE COMPARISON. `checking.checkWord` firing means the controller asked SOME host about a
        // word; it is the one step whose meaning does not depend on which arm is driving.
        IDStockParity.assertField("controller asked the host to check a word", scenario:
                                  "lifecycle trace of typing \"\(misspelled) \" and leaving the word",
                                  stock: "\(count(.stock, "checking.checkWord") > 0)",
                                  inputDec: "\(count(.inputDec, "checking.checkWord") > 0)",
                                  legacy: "\(count(.legacy, "checking.checkWord") > 0)",
                                  note: "firstMissingTransition — stock=\(transition(.stock)) "
                                      + "inputDec=\(transition(.inputDec)) "
                                      + "legacy=\(transition(.legacy)). `wordCheckUnavailable` on an "
                                      + "arm means the controller never asked it (a DRIVING defect); "
                                      + "`annotationUnavailable` means it asked and the answer never "
                                      + "landed (a DELIVERY defect).")

        // The two HOST arms share one annotation surface (`spellResults`), so their
        // `firstMissingTransition` values ARE comparable with each other — unlike stock's, which is
        // sampled from TextKit 2 rendering attributes (deviation P2-3). Compared against the Legacy
        // control only, and labelled as the weaker claim it is.
        IDStockParity.assertAgainstControl("first missing checking transition", scenario:
                                           "lifecycle trace, host arms only (one shared surface)",
                                           inputDec: transition(.inputDec),
                                           legacy: transition(.legacy),
                                           note: "checkWord counts — stock=\(count(.stock, "checking.checkWord")) "
                                               + "inputDec=\(count(.inputDec, "checking.checkWord")) "
                                               + "legacy=\(count(.legacy, "checking.checkWord")); "
                                               + "textChecker returns — inputDec="
                                               + "\(count(.inputDec, "checking.textChecker")) legacy="
                                               + "\(count(.legacy, "checking.textChecker"))")
    }
}
#endif
