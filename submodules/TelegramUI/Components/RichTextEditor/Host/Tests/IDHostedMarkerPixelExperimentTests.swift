import UIKit
import XCTest

/// **TASK PH4, STEP 1 — THE EXPERIMENT THAT DECIDES WHETHER A RENDERING TEST TIER CAN EXIST HERE.**
///
/// Task P1 measured, and task P2 confirmed by decomposition, that a stock `UITextView` paints
/// **zero** misspelling-marker pixels in a SwiftPM xctest process — while the *temporary
/// annotation* the marker is made of lands normally. `IDBlockSpellingIntegrationParityTests`
/// therefore declines (`XCTSkipUnless`) rather than passing, and the user's open
/// "corrected words are not underlined" defect has had **no automated oracle at all**.
///
/// `task-PORT-PLAN.md` §7.5 names the one thing that could change that answer: a **hosted** test —
/// a test bundle injected into a real, launched, foreground application, rather than the bare
/// `xctest` runner a SwiftPM package produces. That is the only environmental variable left, and
/// this file is the whole experiment.
///
/// ## What is reused, and why that matters more than it looks
///
/// Nothing here re-implements the counter. `IDRenderView` + `IDCountRedPixels`
/// (`Tests/StockParitySupport/IDStockParityPixels.m`, ported verbatim from upstream's
/// `IDTextCanvasTestSupport.m`) are compiled into this bundle **by reference** — same file, same
/// bytes, same red predicate. The Swift `PixelCounts` counter below is copied verbatim from
/// `Tests/RichTextEditorUIKitTests/StockParity/IDBlockSpellingIntegrationParityTests.swift`,
/// including its two hard-won corrections:
///
///   * `layer.render(in:)` and **not** `drawHierarchy(in:afterScreenUpdates:)` — the latter renders
///     nothing for a window that is not on a real screen, and produced a zero for a KNOWN red
///     underline once already;
///   * a marker band of `firstRect(for:).insetBy(dx: 0, dy: -6)` — a band tight to the baseline
///     misses a marker drawn below the reported rect.
///
/// And `test_0_calibration…` runs first: **a zero is only worth reporting once the instrument has
/// been shown to see a known red underline in THIS process.**
///
/// ## THE ANSWER, measured 2026-08-27 on iPhone 17 Pro K1 (iOS 26.5), first run
///
/// **Hosting is the missing ingredient. A hosted stock `UITextView` DOES paint the marker.**
///
/// | reading | SwiftPM xctest process | this hosted process |
/// | --- | --- | --- |
/// | Swift red-pixel counter under "mispelled" | **0** | **1427** |
/// | upstream `IDCountRedPixels` over the same band | **0** | **182** |
/// | `IDObserveStockSpellingReadiness().markerPixelCount` | **0** | **79** |
/// | that probe's `status` | `inputModeMismatch` | **`ready`** |
/// | first-responder `UITextView.textInputMode?.primaryLanguage` | **nil** | **"en-US"** |
///
/// The last row is the mechanism. The classifier's FIRST gate is that the controller mode and the
/// *per-view* input mode both read `en-US`; a bare `xctest` process has no per-view input mode at
/// all, so upstream's probe short-circuited at `inputModeMismatch` and never reached the pixel
/// question. Under a real launched app there is a keyboard scene, the view gets a real input mode,
/// the checker's marker is painted, and the probe reaches `ready` — **which is the value upstream's
/// own `testStockTextViewSpellingEnvironmentIsReady` asserts.** This process is, for the first time
/// in this programme, the environment upstream's corpus was written against.
///
/// Consequence: **tier T3 exists in this repo.** The user's open "corrected words are not
/// underlined" defect is certifiable here, and `IDBlockSpellingIntegrationParityTests`'
/// `[ORACLE UNAVAILABLE — NOT CERTIFIED]` skip is an artefact of the SwiftPM host, not of the OS.
///
/// The three tests below are therefore written as **standing assertions, not as a probe**: if a
/// future OS build, simulator or project change takes marker rendering away again, this suite goes
/// red and says so, rather than quietly reverting the programme to having no rendering oracle.
@available(iOS 17.0, *)
@MainActor
final class IDHostedMarkerPixelExperimentTests: XCTestCase {

    // MARK: - The instrument
    //
    // Lives in `HostedPixelInstrument` so every hosted suite reads the same predicate, render call
    // and band; its doc comment carries the two corrections that make a zero interpretable.

    private typealias PixelCounts = HostedPixelInstrument.PixelCounts

    private func pixels(in view: UIView, band: CGRect) -> PixelCounts {
        HostedPixelInstrument.pixels(in: view, band: band)
    }

    private func markerBand(_ input: UITextInput, characterRange: NSRange) -> CGRect? {
        guard let view = input as? UIView else { return nil }
        return HostedPixelInstrument.markerBand(input, characterRange: characterRange, in: view)
    }

    private func upstreamRedPixels(in view: UIView, band: CGRect) -> Int {
        HostedPixelInstrument.upstreamRedPixels(in: view, band: band)
    }

    // MARK: - Hosting, in the REAL application window

    /// The point of a hosted test: the view goes into the launched app's own key window, which is
    /// attached to a real (simulated) screen and belongs to a foreground-active scene. A detached
    /// `UIWindow` built inside the test — what the SwiftPM suite must do — is the control.
    private var appRootView: UIView {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
            ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        guard let window = scene?.windows.first(where: { $0.isKeyWindow }) ?? scene?.windows.first,
              let root = window.rootViewController?.view else {
            XCTFail("HOSTED TEST IS NOT HOSTED: no application window. TEST_HOST is not in effect "
                    + "and every reading below is about a bare xctest process, which is the thing "
                    + "this experiment exists to be different from.")
            return UIView()
        }
        return root
    }

    @discardableResult
    private func install(_ view: UIView, at origin: CGPoint) -> UIView {
        let root = appRootView
        view.frame = CGRect(origin: origin, size: view.bounds.size)
        root.addSubview(view)
        root.layoutIfNeeded()
        view.layoutIfNeeded()
        addTeardownBlock { MainActor.assumeIsolated { view.removeFromSuperview() } }
        return root
    }

    private func makeStock(width: CGFloat = 340, height: CGFloat = 90) -> UITextView {
        let view = UITextView(frame: CGRect(x: 0, y: 0, width: width, height: height))
        view.font = UIFont.systemFont(ofSize: 20.0)
        view.textColor = .black
        view.backgroundColor = .white
        view.spellCheckingType = .yes
        view.autocorrectionType = .no
        return view
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

    // MARK: - Step 0. The instrument, calibrated in THIS process.

    /// A known red underline through **public** `NSAttributedString` attributes — no spell checker
    /// involved. If this fails, every other number in this file is meaningless and the cause is the
    /// instrument, not the environment.
    func test_0_calibrationTheRedPixelCounterSeesAKnownRedUnderline() {
        let view = makeStock()
        view.attributedText = NSAttributedString(string: "mispelled word", attributes: [
            .font: UIFont.systemFont(ofSize: 20.0),
            .foregroundColor: UIColor.black,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .underlineColor: UIColor.red,
        ])
        install(view, at: CGPoint(x: 10, y: 80))

        let band = markerBand(view, characterRange: NSRange(location: 0, length: 9))
        XCTAssertNotNil(band, "the instrument could not locate the word's rect")
        let counts = band.map { pixels(in: view, band: $0) } ?? PixelCounts()
        let upstream = band.map { upstreamRedPixels(in: view, band: $0) } ?? 0

        XCTAssertGreaterThan(counts.ink, 3,
                             "[INSTRUMENT BROKEN — BLANK RENDER] no non-white pixels under a word "
                             + "that is definitely drawn.")
        XCTAssertGreaterThan(counts.red, 3,
                             "[INSTRUMENT BROKEN — RED PREDICATE] ink=\(counts.ink) red=\(counts.red)")
        XCTAssertGreaterThan(upstream, 3,
                             "[UPSTREAM INSTRUMENT BROKEN] the ported IDCountRedPixels/IDRenderView "
                             + "pair read \(upstream) red px where the Swift counter read "
                             + "\(counts.red). The two disagree about a KNOWN underline.")
        print("PH4-EVIDENCE calibration: swiftRed=\(counts.red) ink=\(counts.ink) upstreamRed=\(upstream)")
    }

    // MARK: - Step 1. What the hosted process is, factually.

    /// The facts P2 recorded for the SwiftPM process, re-measured here. In that process
    /// `UITextInputMode.currentInputMode.primaryLanguage` was `"en-US"` but a first-responder
    /// `UITextView`'s own `textInputMode` was **nil** — which is the classifier's first gate, so
    /// upstream's probe returned `inputModeMismatch` and never evaluated the pixel question at all.
    ///
    /// Recorded, not asserted to a fixed value: this test's job is to say what changed.
    func test_1_recordTheHostedProcessInputModeFacts() {
        let view = makeStock()
        install(view, at: CGPoint(x: 10, y: 80))
        XCTAssertTrue(view.becomeFirstResponder(), "the stock editor could not become first responder")
        spin(0.5)

        let controllerMode = IDCurrentInputModePrimaryLanguage() ?? "<nil>"
        let perViewMode = view.textInputMode?.primaryLanguage ?? "<nil>"
        let hasMode = IDHasCurrentInputMode()
        let privateClasses = IDPrivateTextInputClassAvailability()
        let isKeyWindowOnScreen = view.window?.screen != nil
        print("PH4-EVIDENCE inputmode: controller=\(controllerMode) perView=\(perViewMode) "
              + "hasCurrentInputMode=\(hasMode) onScreen=\(isKeyWindowOnScreen) "
              + "privateClasses=\(privateClasses)")

        XCTAssertNotNil(view.window, "the editor is not in a window")
    }

    // MARK: - Step 2. THE EXPERIMENT.

    /// Type a misspelling into a stock `UITextView` living in the launched app's own window, wait,
    /// and count the red pixels under it.
    ///
    /// **A zero here fails the test.** It did not fail when the experiment was first run
    /// (swiftRed=1427, upstreamRed=182), so a zero from here on is a REGRESSION in the host, the
    /// project settings, or the OS build — not a standing environment limit. Every intermediate is
    /// still printed, so a failure names its own cause.
    func test_2_doesAStockUITextViewPaintMisspellingMarkerPixelsWhenHosted() throws {
        // WARM-UP. Measured in the SwiftPM process and equally true here: the FIRST text view driven
        // in a fresh process receives no annotation at all — the system checker loads
        // asynchronously. Upstream encodes the same fact rather than fixing it.
        let warmUp = makeStock()
        install(warmUp, at: CGPoint(x: 10, y: 300))
        XCTAssertTrue(warmUp.becomeFirstResponder())
        warmUp.insertText("mispelled ")
        spin(2.0)
        warmUp.resignFirstResponder()

        let misspelled = "mispelled"
        let wordRange = NSRange(location: 0, length: (misspelled as NSString).length)

        let editor = makeStock()
        install(editor, at: CGPoint(x: 10, y: 80))
        XCTAssertTrue(editor.becomeFirstResponder())
        editor.insertText("\(misspelled) ")

        var swiftRed = 0, ink = 0, upstreamRed = 0
        let sawMarker = wait(upTo: 8.0) {
            guard let band = self.markerBand(editor, characterRange: wordRange) else { return false }
            let counts = self.pixels(in: editor, band: band)
            swiftRed = counts.red
            ink = counts.ink
            upstreamRed = self.upstreamRedPixels(in: editor, band: band)
            return counts.red > 3 || upstreamRed > 3
        }

        // The annotation oracle, for contrast. In the SwiftPM process THIS fires while the pixels
        // do not — so if it fires here too and the pixels still do not, hosting changed nothing.
        let annotationRanges = IDStockPumpAndSampleAnnotationRanges(editor, 2.0)

        let band = markerBand(editor, characterRange: wordRange).map { "\($0)" } ?? "<none>"
        print("PH4-EVIDENCE ================= THE ANSWER =================")
        print("PH4-EVIDENCE hostedMarkerPixels: swiftRed=\(swiftRed) upstreamRed=\(upstreamRed) "
              + "ink=\(ink) sawMarker=\(sawMarker) band=\(band) "
              + "annotationRanges=\(annotationRanges) text=\"\(editor.text ?? "")\"")
        print("PH4-EVIDENCE ======================================================")

        XCTAssertGreaterThan(ink, 3,
                             "[INSTRUMENT] the render of the editor is blank, so the red count "
                             + "below is about nothing. This is an instrument failure, not a "
                             + "finding.")
        XCTAssertFalse(annotationRanges.isEmpty,
                       "the temporary-annotation oracle did not fire either — the system checker "
                       + "did not run at all in this process, so the pixel reading is not a "
                       + "statement about MARKER RENDERING. Fix this before reading the zero.")

        // THE ASSERTION THE WHOLE RENDERING TIER RESTS ON.
        XCTAssertGreaterThan(swiftRed, 3,
                             "[RENDERING TIER LOST] a hosted stock UITextView painted NO misspelling "
                             + "marker (\(swiftRed) red px, upstream counter \(upstreamRed), ink "
                             + "\(ink), annotation ranges \(annotationRanges)). This measured 1427 "
                             + "on 2026-08-27, so something regressed: check that TEST_HOST is still "
                             + "in effect (test_1 prints the per-view input mode — nil there means the "
                             + "bundle is running unhosted), then the OS build. Until this passes, "
                             + "tier T3 does not exist and the underline defect has no oracle.")
        XCTAssertGreaterThan(upstreamRed, 3,
                             "the Swift counter saw \(swiftRed) red px but upstream's stricter "
                             + "predicate saw \(upstreamRed). The two instruments disagree about the "
                             + "same band, which means one of them is wrong.")
    }

    // MARK: - Step 3. Upstream's own probe, unmodified, in this process.

    /// `IDObserveStockSpellingReadiness` is upstream's whole verdict: en-US on the controller AND
    /// the input, continuous checking on, an annotation observed, and a **non-zero marker pixel
    /// count**. Upstream asserts it reaches `ready`. The SwiftPM process reaches
    /// `inputModeMismatch` with `markerPixelCount == 0`.
    func test_3_upstreamsOwnReadinessProbeInThisProcess() {
        let warmUp = makeStock()
        install(warmUp, at: CGPoint(x: 10, y: 300))
        _ = IDObserveStockAnnotationRangesForText(warmUp, "mispelled ", 2.0)

        let editor = makeStock(width: 340, height: 120)
        install(editor, at: CGPoint(x: 10, y: 80))
        XCTAssertNotNil(editor.textLayoutManager, "the probe requires TextKit 2")
        let observation = IDObserveStockSpellingReadiness(editor, 6.0)
        let json = (try? JSONSerialization.data(withJSONObject: observation.dictionaryRepresentation,
                                                options: [.sortedKeys]))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "<unserialisable>"
        print("PH4-EVIDENCE upstreamProbe: status=\(IDSpellingReadinessStatusString(observation.status)) "
              + "markerPixelCount=\(observation.markerPixelCount) "
              + "annotation=\(observation.temporaryAnnotationObserved) evidence=\(json)")

        // Upstream's own assertion, reproduced. `IDSpellingReadinessProbeTests`'
        // `testStockTextViewSpellingEnvironmentIsReady` requires exactly this, and this repo has
        // never been able to satisfy it before.
        XCTAssertEqual(IDSpellingReadinessStatusString(observation.status), "ready",
                       "upstream's readiness probe no longer reaches `ready` in this host "
                       + "(\(IDSpellingReadinessStatusString(observation.status))). It reached "
                       + "`ready` on 2026-08-27. evidence=\(json)")
        XCTAssertGreaterThan(observation.markerPixelCount, 0,
                             "upstream's own marker pixel count went to zero. evidence=\(json)")
    }
}
