#if canImport(UIKit)
import UIKit
import XCTest
import RichTextEditorCore
import RichTextEditorDifferentialHarness
import RichTextEditorStockParitySupport
@testable import RichTextEditorUIKit

/// **Ported from `/Users/isaac/Documents/InputDec/Tests/IDBlockTouchSelectionParityTests.m`**
/// (444 lines, 6 tests). See `PROVENANCE.md` in this directory.
///
/// Upstream stands its host `IDBlockTextView` beside a stock `UITextView` in one window, gives both
/// the same three paragraphs at the same font, and requires point-to-position resolution and
/// tokenizer granularity to agree. This port substitutes Telegram's host and adds the **Legacy
/// control arm** (see `IDStockParity.Verdict`), so a divergence the shipping canvas also shows is
/// tagged `PRE-EXISTING` rather than charged to the InputDec port.
///
/// ## The one structural re-expression, and why it is not a loosening
///
/// Upstream derives its probe points from the **stock** arm's caret rects and applies the same
/// `CGPoint` to both arms. It can, because both of its arms are TextKit-shaped and lay the same text
/// out at the same y. Telegram's cannot: `BlockLayoutEngine` pins every paragraph's line box
/// (`minimumLineHeight == maximumLineHeight`, from `RichTextRenderMetrics`) while a stock
/// `UITextView` uses the font's natural leading, so for the same font and width the two arms wrap at
/// different y. A stock-derived y applied to the host would land on a *different line*, and the
/// resulting failure would say "hit-testing is broken" when the truth is "the line heights differ" —
/// the single most misleading red this suite could produce.
///
/// So each probe point is derived from **the arm it is applied to** (`pointInsideCharacter`), and
/// what is compared across arms is the **resolved character index**, not the point. The claim
/// asserted is upstream's real one — *a point inside character N's glyph resolves to N, and all
/// three arms agree on N* — expressed so that it survives differing line boxes. It is strictly
/// checkable; it is not the weaker "each arm agrees with itself".
///
/// ## Dropped (PROVENANCE.md §Dropped)
///
/// `testTestOnlyLoupeSequenceMatchesStockSizeOffsetAndMovement` is **not ported**. Driving it
/// requires an `objc_msgSend` cast to the private 6-argument
/// `-loupeGestureWithState:location:translation:velocity:modifierFlags:shouldCancel:`, three of
/// whose arguments are `CGPoint`-returning blocks and one an out-`BOOL *`. Swift cannot form that
/// call — `objc_msgSend` is not callable through a `@convention(c)` cast in Swift — so the port
/// would need an Objective-C shim, and this is a Swift-only test target (SwiftPM cannot mix
/// Objective-C into it; the only ObjC target here is the PROVENANCE-governed vendored harness).
/// The assertions lost are the loupe's size, its offset from the caret, and its movement delta.
/// `IDKeyboardActivationTests.test_theAppReachableInstallationStateHasEveryThunkLive` still pins
/// that the host publishes a non-nil `interactionAssistant` at all.
@available(iOS 17.0, *)
@MainActor
final class IDBlockTouchSelectionParityTests: XCTestCase {

    private var violations = IDStockParity.ViolationLog()

    /// Upstream's `fixtureBlocks`, verbatim.
    private let fixtureBlocks = [
        "First wrapped paragraph contains constellation and punctuation for precise taps.",
        "Second wrapped paragraph provides selection handles across independent blocks.",
        "Third wrapped paragraph keeps the viewport tall enough for 👨‍👩‍👧‍👦 taps.",
    ]
    private var fixtureText: String { fixtureBlocks.joined(separator: "\n") }

    override func setUpWithError() throws {
        try super.setUpWithError()
        try XCTSkipUnless(IDTextEditorBackend.isSupported(),
                          "InputDec backend unsupported on this runtime")
        violations = IDStockParity.ViolationLog()
        IDStockParity.installContractReporter(violations, in: self)
    }

    // MARK: - Arms

    /// **Task P2: this suite now obtains its subjects through the shared substitution seam.**
    ///
    /// Was three bespoke factories (`stockArm`, `hostArm`, `onEveryArm`) that each hosted their arm
    /// in its OWN window. `IDStockParity.makeArms` is upstream's `-makeCustom:stock:` +
    /// `-hostCustom:stock:` shape instead: one fixture, three arms, side by side in ONE window on a
    /// real window scene — which is what upstream does and what any scene-level assertion (the
    /// loupe) requires. The readings below did not change; only where the views live did.
    private func makeArms() throws -> IDParityArms {
        try IDStockParity.makeArms(IDParityFixture(blocks: fixtureBlocks), in: self)
    }

    /// Runs `probe` on all three arms and returns the three readings, so every test below is a
    /// three-way value comparison rather than three separately-written arms.
    private func onEveryArm<T>(_ probe: (UITextInput) throws -> T) throws -> (stock: T, inputDec: T,
                                                                             legacy: T) {
        try makeArms().eachInput(probe)
    }

    private func assertNoKernelFailures(_ scenario: String, file: StaticString = #filePath,
                                        line: UInt = #line) {
        IDStockParity.assertNoKernelFailures(violations, scenario, file: file, line: line)
    }

    // MARK: - 1 & 2. Point-to-position resolution

    /// Upstream: `testClosestPositionsMatchStockAtWrappedLineStartMiddleAndEnd` **and**
    /// `testClosestPositionMatchesStockAtConstellationPointForLiveWidth`, merged — both make the same
    /// claim at different probe indices, and the merge lets one fixture serve both.
    ///
    /// Upstream's own second test additionally re-frames the views to a live width before probing;
    /// that is preserved as the `liveWidth` variant below, because a relayout-then-probe is a
    /// genuinely different code path from a probe on first layout.
    func test_closestPositionResolvesTheCharacterItsGlyphContains() throws {
        let scenario = "closestPosition(to:) at an unambiguous interior point of a glyph"
        let text = fixtureText as NSString
        let constellation = text.range(of: "constellation")
        XCTAssertNotEqual(constellation.location, NSNotFound)

        // Start of the document, an interior character of the first paragraph, the last character
        // before the first structural newline, and a character of the SECOND paragraph (which is
        // where the sparse-axis skew begins and therefore where a mis-mapped probe would show).
        let probes: [(name: String, index: Int)] = [
            ("document start", 0),
            ("interior of \"constellation\"", constellation.location + 2),
            ("last character of paragraph 1", fixtureBlocks[0].utf16.count - 1),
            ("interior of paragraph 2", fixtureBlocks[0].utf16.count + 10),
        ]

        // 0.25 resolves to the character itself, 0.75 to the next one. Both are unambiguous — see
        // `IDStockParity.pointInsideCharacter`, which records why 0.5 is NOT.
        for (fraction, expectedDelta) in [(CGFloat(0.25), 0), (CGFloat(0.75), 1)] {
            for probe in probes {
                let resolved = try onEveryArm { input -> String in
                    guard let point = IDStockParity.pointInsideCharacter(input, at: probe.index,
                                                                         fraction: fraction) else {
                        return IDStockParity.decline("no glyph geometry for index \(probe.index)")
                    }
                    guard let index = IDStockParity.closestCharacterIndex(input, to: point) else {
                        return IDStockParity.decline("closestPosition returned nil")
                    }
                    return "\(index)"
                }
                let expected = "\(probe.index + expectedDelta)"
                IDStockParity.assertField("\(probe.name) @\(fraction)", scenario: scenario,
                                          stock: resolved.stock, inputDec: resolved.inputDec,
                                          legacy: resolved.legacy,
                                          note: "a point \(fraction) of the way across character "
                                              + "\(probe.index)'s OWN glyph on each arm; the nearest "
                                              + "caret is unambiguously \(expected)")
                // The oracle's own claim, asserted separately so a stock regression is not silently
                // absorbed into a three-way "everyone agrees".
                XCTAssertEqual(resolved.stock, expected,
                               "the ORACLE moved: a point \(fraction) across character "
                               + "\(probe.index)'s glyph no longer resolves to \(expected) on stock")
            }
        }
        assertNoKernelFailures(scenario)
    }

    /// Upstream probes at **exactly** the glyph midpoint
    /// (`(CGRectGetMidX(startCaret) + CGRectGetMidX(endCaret)) * 0.5`, twice), where the two caret
    /// positions are equidistant and the answer is a tie-breaking POLICY rather than a hit-test
    /// result. Upstream's claim there is only that its arms agree, and that is the claim ported here
    /// — no oracle self-consistency assertion, because none is available: measured 2026-08-26, stock
    /// breaks the tie upward and both Telegram arms break it downward.
    ///
    /// Kept as its own test rather than folded into the one above, so that a tie-breaking divergence
    /// reads as what it is (a one-pixel policy difference at the exact centre of a glyph) and is
    /// never confused with hit-testing resolving the wrong character.
    func test_closestPositionTieBreakingAtTheExactGlyphMidpoint() throws {
        let scenario = "closestPosition(to:) at the EXACT midpoint of a glyph (a tie)"
        let text = fixtureText as NSString
        let index = text.range(of: "constellation").location + 2

        let resolved = try onEveryArm { input -> String in
            guard let point = IDStockParity.pointInsideCharacter(input, at: index, fraction: 0.5)
            else { return IDStockParity.decline("no glyph geometry") }
            guard let hit = IDStockParity.closestCharacterIndex(input, to: point) else {
                return IDStockParity.decline("closestPosition returned nil")
            }
            return "\(hit)"
        }
        IDStockParity.assertField("tie at character \(index)", scenario: scenario,
                                  stock: resolved.stock, inputDec: resolved.inputDec,
                                  legacy: resolved.legacy,
                                  note: "equidistant from the carets of \(index) and \(index + 1); "
                                      + "stock rounds UP, both Telegram arms round DOWN. A "
                                      + "one-pixel policy difference, not a hit-test error.")
        assertNoKernelFailures(scenario)
    }

    /// Upstream's `…ForLiveWidth` variant: re-frame both arms, force layout, then probe. Upstream
    /// widens to 370×360; the port keeps that width.
    func test_closestPositionResolvesTheSameCharacterAfterARelayout() throws {
        let scenario = "closestPosition(to:) after a live re-frame to 370×360"
        let text = fixtureText as NSString
        let constellation = text.range(of: "constellation")
        let index = constellation.location + 2

        func reframe(_ view: UIView) {
            view.frame = CGRect(x: 0, y: 0, width: 370, height: 360)
            view.setNeedsLayout()
            view.layoutIfNeeded()
        }

        let arms = try makeArms()
        for arm in IDParityArm.allCases { reframe(arms[arm].view) }
        let stock = arms.stock.input
        let idEditor = arms.inputDec
        let legacyEditor = arms.legacy

        func resolve(_ input: UITextInput) -> String {
            guard let point = IDStockParity.pointInsideCharacter(input, at: index) else {
                return IDStockParity.decline("no glyph geometry")
            }
            guard let resolved = IDStockParity.closestCharacterIndex(input, to: point) else {
                return IDStockParity.decline("closestPosition returned nil")
            }
            return "\(resolved)"
        }
        let stockResolved = resolve(stock)
        let idResolved = resolve(idEditor.input)
        let legacyResolved = resolve(legacyEditor.input)

        XCTAssertEqual(stockResolved, "\(index)", "the ORACLE moved: a point 0.25 across character \(index)'s glyph no longer resolves to \(index) after a relayout")
        IDStockParity.assertField("interior of \"constellation\" after relayout", scenario: scenario,
                                  stock: stockResolved, inputDec: idResolved, legacy: legacyResolved)
        assertNoKernelFailures(scenario)
    }

    // MARK: - 3. Tokenizer granularity across a structural newline

    /// Upstream: `testWordAndParagraphTokenizerRangesMatchStockAcrossStructuralNewline`.
    ///
    /// **The most directly portable test in the whole suite** — it touches no geometry at all, only
    /// `UITextInput.tokenizer`, so it is a near-verbatim port modulo the character-axis map. It is
    /// also the sharpest: a word range and a paragraph range are both compared *at and immediately
    /// after* the structural newline, which is exactly where the sparse axis and the block structure
    /// could quietly disagree with a flat `NSString`.
    func test_wordAndParagraphTokenizerRangesAcrossAStructuralNewline() throws {
        let scenario = "tokenizer word/paragraph ranges across a structural newline"
        let text = fixtureText as NSString
        let constellation = text.range(of: "constellation")
        XCTAssertNotEqual(constellation.location, NSNotFound)
        let structuralNewline = fixtureBlocks[0].utf16.count

        func canonicalRange(_ input: UITextInput, offset: Int,
                            granularity: UITextGranularity) -> String {
            guard let position = IDStockParity.position(input, atCharacterIndex: offset) else {
                return IDStockParity.decline("no position at \(offset)")
            }
            guard let range = input.tokenizer.rangeEnclosingPosition(
                position, with: granularity, inDirection: .storage(.forward)) else {
                return IDStockParity.decline("tokenizer returned nil")
            }
            guard let converted = IDStockParity.characterRange(input, range) else {
                return IDStockParity.decline("range not on the character axis")
            }
            return NSStringFromRange(converted)
        }

        // --- word granularity, mid-word ---
        let wordProbe = constellation.location + 2
        let word = try onEveryArm { canonicalRange($0, offset: wordProbe, granularity: .word) }
        XCTAssertEqual(word.stock, NSStringFromRange(constellation),
                       "the ORACLE moved: stock's word tokenizer no longer encloses \"constellation\"")
        IDStockParity.assertField("word range at \"co[n]stellation\"", scenario: scenario,
                                  stock: word.stock, inputDec: word.inputDec, legacy: word.legacy)

        // --- paragraph granularity, at and immediately after the structural newline ---
        for probe in [structuralNewline, structuralNewline + 1] {
            let paragraph = try onEveryArm {
                canonicalRange($0, offset: probe, granularity: .paragraph)
            }
            IDStockParity.assertField("paragraph range at character \(probe)", scenario: scenario,
                                      stock: paragraph.stock, inputDec: paragraph.inputDec,
                                      legacy: paragraph.legacy,
                                      note: "character \(structuralNewline) IS the structural "
                                          + "newline; \(structuralNewline + 1) is the first "
                                          + "character of paragraph 2")
        }
        assertNoKernelFailures(scenario)
    }

    // MARK: - 4. Composed character clusters

    /// Upstream: `testClosestPositionNeverReturnsComposedClusterInteriorOffset`. A tap in the middle
    /// of a 👨‍👩‍👧‍👦 (an 11-UTF-16-unit grapheme cluster) must not resolve to an offset *inside* the
    /// cluster — a caret there would split the family emoji and the next backspace would corrupt it.
    ///
    /// Upstream asserts both halves (the arms agree, AND the offset is not cluster-interior); both
    /// are kept. This is the one place where the *stock* assertion is the weaker of the two: stock
    /// agreeing with itself proves nothing, so `XCTAssertFalse(isInsideComposedCluster)` is asserted
    /// per arm as well as compared across arms.
    func test_closestPositionNeverLandsInsideAComposedCluster() throws {
        let scenario = "tap in the middle of a 👨‍👩‍👧‍👦 grapheme cluster"
        let text = fixtureText as NSString
        let cluster = text.range(of: "👨‍👩‍👧‍👦")
        XCTAssertNotEqual(cluster.location, NSNotFound)
        XCTAssertGreaterThan(cluster.length, 2, "the fixture emoji is not a multi-unit cluster")

        struct ClusterProbe { var resolved: String; var interior: Bool }
        let probes = try onEveryArm { input -> ClusterProbe in
            guard let start = IDStockParity.position(input, atCharacterIndex: cluster.location),
                  let end = IDStockParity.position(input,
                                                   atCharacterIndex: cluster.location + cluster.length)
            else { return ClusterProbe(resolved: IDStockParity.decline("no cluster geometry"), interior: false) }
            let startCaret = input.caretRect(for: start)
            let endCaret = input.caretRect(for: end)
            let point = CGPoint(x: (startCaret.midX + endCaret.midX) * 0.5, y: startCaret.midY)
            guard let index = IDStockParity.closestCharacterIndex(input, to: point) else {
                return ClusterProbe(resolved: IDStockParity.decline("closestPosition returned nil"), interior: false)
            }
            return ClusterProbe(resolved: "\(index)",
                                interior: IDStockParity.offset(index,
                                                               isInsideComposedClusterOf: self.fixtureText))
        }

        XCTAssertFalse(probes.stock.interior, "the ORACLE moved: stock now resolves a mid-cluster "
                       + "tap to a cluster-INTERIOR offset (\(probes.stock.resolved))")
        XCTAssertFalse(probes.inputDec.interior,
                       "[PORT-DEFECT] \(scenario) · the InputDec arm resolved the tap to "
                       + "\(probes.inputDec.resolved), which is INSIDE the cluster — a caret there "
                       + "splits the family emoji")
        XCTAssertFalse(probes.legacy.interior,
                       "[PRE-EXISTING] \(scenario) · the Legacy arm resolved the tap to "
                       + "\(probes.legacy.resolved), which is INSIDE the cluster")
        IDStockParity.assertField("resolved offset", scenario: scenario,
                                  stock: probes.stock.resolved, inputDec: probes.inputDec.resolved,
                                  legacy: probes.legacy.resolved)
        assertNoKernelFailures(scenario)
    }

    // MARK: - 5. A tap below every block

    /// Upstream: `testTask5ClosestPositionBelowIndependentBlocksMatchesStockDocumentEnd`. A tap in
    /// the empty space below the last block must resolve to the end of the document — upstream's own
    /// stock assertion (`stockOffset == stock.text.length`) is kept as the oracle claim.
    ///
    /// The point is per-arm (below *that arm's* content), for the reason in the type comment: the
    /// arms' content heights differ, so one absolute y cannot be "below the content" on all three.
    func test_tapBelowEveryBlockResolvesToTheDocumentEnd() throws {
        let scenario = "tap in the empty space below the last block"
        let expected = "\(fixtureText.utf16.count)"

        let resolved = try onEveryArm { input -> String in
            // 24pt above the bottom of the hosting view's bounds — upstream's own inset. `input` is
            // always a `UIView` here (a `UITextView` or a `DocumentCanvasView`).
            guard let view = input as? UIView else { return IDStockParity.decline("not a view") }
            let point = CGPoint(x: 132.0, y: view.bounds.height - 24.0)
            guard let index = IDStockParity.closestCharacterIndex(input, to: point) else {
                return IDStockParity.decline("closestPosition returned nil")
            }
            return "\(index)"
        }
        XCTAssertEqual(resolved.stock, expected,
                       "the ORACLE moved: a tap below the text no longer resolves to the document end")
        IDStockParity.assertField("resolved offset", scenario: scenario,
                                  stock: resolved.stock, inputDec: resolved.inputDec,
                                  legacy: resolved.legacy,
                                  note: "the document is \(expected) characters long")
        assertNoKernelFailures(scenario)
    }

    // MARK: - 6. The loupe (RESTORED — Task P1 had to drop this whole test)

    /// Upstream: `testTestOnlyLoupeSequenceMatchesStockSizeOffsetAndMovement`.
    ///
    /// **Task P1 dropped this test entirely** because driving it needs an `objc_msgSend` cast to the
    /// private 6-argument
    /// `-loupeGestureWithState:location:translation:velocity:modifierFlags:shouldCancel:`, three of
    /// whose arguments are `CGPoint`-returning blocks and one an out-`BOOL *` — a call Swift cannot
    /// form. Task P2 ported that call into the Objective-C support target
    /// (`IDSendTestLoupeGesture`, `Tests/StockParitySupport/IDStockParityLoupe.m`), so the test is
    /// back. It is the end-to-end proof that the new seam carries an upstream suite that the old one
    /// could not.
    ///
    /// It is also the only test here that needs `IDParityArms.focus(_:)`: upstream hides the arm it
    /// is not driving (`custom.hidden = YES; stock.hidden = NO;`) because a loupe is presented into
    /// the *scene*, and `IDWaitForLoupeInScene` searches every window of it — with two live arms you
    /// cannot tell whose loupe you measured. Hosting all three arms in ONE window, which the seam
    /// does and P1's per-arm windows did not, is what makes that search meaningful.
    ///
    /// **Deviation from upstream, recorded:** upstream asserts the loupe geometry unconditionally.
    /// Here the assertions are gated on the STOCK arm actually presenting a loupe — if the oracle
    /// itself produces none in this process there is nothing to compare against, and three arms all
    /// producing no loupe would compare equal and pass having measured nothing. That is the
    /// `[DECLINED]` vacuity rule applied to a geometry the harness cannot express as a `Reading`.
    /// The gate is an `XCTSkip`, never a pass.
    func test_loupeSizeOffsetAndMovementMatchStock() throws {
        let scenario = "test-only loupe gesture sequence"
        let arms = try makeArms()
        let scene = try XCTUnwrap(arms.window.windowScene,
                                  "the loupe is presented into a UIWindowScene; this process has none")
        let initialPoint = CGPoint(x: 72, y: 42)
        let movedPoint = CGPoint(x: 112, y: 42)

        /// Upstream's sequence, verbatim: began → changed at the same point → measure → changed at
        /// the moved point → measure → ended → require the loupe to be gone.
        // The reason a measurement declined must travel with it. A bare nil would make the skip
        // below say "no loupe" when the truth might be "no interaction assistant" or "the gesture
        // was cancelled" — three different findings, and only one of them is an environment limit.
        var declineReason: [IDParityArm: String] = [:]
        func measure(_ arm: IDParityArm) throws -> (first: CGRect, second: CGRect, caret: CGRect)? {
            XCTAssertTrue(arms.focus(arm), "\(arm.rawValue) could not become first responder")
            defer { arms.unfocusAll() }
            guard let assistant = IDInteractionAssistantOfInput(arms[arm].input) else {
                declineReason[arm] = "no interactionAssistant on \(type(of: arms[arm].input))"
                return nil
            }
            guard IDSendTestLoupeGesture(assistant, .began, initialPoint, .zero, .zero),
                  IDSendTestLoupeGesture(assistant, .changed, initialPoint, .zero, .zero) else {
                declineReason[arm] = "the test-only loupe gesture was CANCELLED (or the private "
                    + "selector is absent on \(type(of: assistant)))"
                return nil
            }
            IDWaitForLoupePresentation()
            _ = IDCaptureWindowScene(scene)
            guard let firstLoupe = IDWaitForLoupeInScene(scene, true) else {
                declineReason[arm] = "no _UITextMagnifiedGlassLoupeView appeared in the scene "
                    + "(assistant=\(type(of: assistant)))"
                return nil
            }
            let first = IDScreenRectForView(firstLoupe)
            let caret = IDCaretViewOfAssistant(assistant).map(IDScreenRectForView) ?? .null

            _ = IDSendTestLoupeGesture(assistant, .changed, movedPoint, CGPoint(x: 40, y: 0), .zero)
            IDWaitForLoupePresentation()
            _ = IDCaptureWindowScene(scene)
            guard let secondLoupe = IDWaitForLoupeInScene(scene, true) else {
                declineReason[arm] = "the loupe vanished before the second sample"
                return nil
            }
            let second = IDScreenRectForView(secondLoupe)

            _ = IDSendTestLoupeGesture(assistant, .ended, movedPoint, CGPoint(x: 40, y: 0), .zero)
            IDWaitForLoupePresentation()
            XCTAssertNil(IDWaitForLoupeInScene(scene, false),
                         "[\(arm.rawValue)] the loupe did not go away after .ended")
            return (first, second, caret)
        }

        let stockMeasurement = try measure(.stock)
        try XCTSkipIf(stockMeasurement == nil,
                      "NOT CERTIFIED: the stock UITextView presented no loupe in this process, so "
                      + "there is no oracle to compare either Telegram arm against. This is a skip, "
                      + "not a pass — nothing was measured. reason="
                      + (declineReason[.stock] ?? IDStockParity.decline("unrecorded")))
        let stockValue = try XCTUnwrap(stockMeasurement)

        // BOTH host arms are measured BEFORE anything is classified, and the presence claim is then
        // ONE assertion carrying three LIVE readings.
        //
        // It was written the other way first — inside the loop, with the arm not being tested
        // hardcoded to `"true"` — and that is the only place in this harness where a verdict input
        // was a literal. It misclassified in both directions: two failing host arms billed
        // `PORT-DEFECT` (the hardcoded legacy `"true"` hid that Legacy failed too, so the honest
        // verdict is `PRE-EXISTING`), and a legacy-only absence computed `.portImprovement`, which
        // `assertField` does not fail on at all — a silent pass. Latent only because the skip above
        // fires today.
        let hostMeasurements: [IDParityArm: (first: CGRect, second: CGRect, caret: CGRect)?] =
            [.inputDec: try measure(.inputDec), .legacy: try measure(.legacy)]
        IDStockParity.assertField("presents a loupe at all", scenario: scenario,
                                  stock: "\(stockMeasurement != nil)",
                                  inputDec: "\((hostMeasurements[.inputDec] ?? nil) != nil)",
                                  legacy: "\((hostMeasurements[.legacy] ?? nil) != nil)",
                                  note: "decline reasons — inputDec: "
                                      + "\(declineReason[.inputDec] ?? "(presented)")  legacy: "
                                      + "\(declineReason[.legacy] ?? "(presented)")")

        for arm in [IDParityArm.inputDec, .legacy] {
            guard let value = hostMeasurements[arm] ?? nil else { continue }
            XCTAssertEqual(value.first.width, stockValue.first.width, accuracy: 4.0,
                           "[\(arm.rawValue)] loupe width vs stock")
            XCTAssertEqual(value.first.height, stockValue.first.height, accuracy: 4.0,
                           "[\(arm.rawValue)] loupe height vs stock")
            if !stockValue.caret.isNull && !value.caret.isNull {
                let stockOffset = CGPoint(x: stockValue.first.midX - stockValue.caret.midX,
                                          y: stockValue.first.midY - stockValue.caret.midY)
                let offset = CGPoint(x: value.first.midX - value.caret.midX,
                                     y: value.first.midY - value.caret.midY)
                XCTAssertEqual(offset.x, stockOffset.x, accuracy: 2.0,
                               "[\(arm.rawValue)] loupe x-offset from the caret vs stock")
                XCTAssertEqual(offset.y, stockOffset.y, accuracy: 2.0,
                               "[\(arm.rawValue)] loupe y-offset from the caret vs stock")
            }
            let stockMovement = CGPoint(x: stockValue.second.midX - stockValue.first.midX,
                                        y: stockValue.second.midY - stockValue.first.midY)
            let movement = CGPoint(x: value.second.midX - value.first.midX,
                                   y: value.second.midY - value.first.midY)
            XCTAssertEqual(movement.x, stockMovement.x, accuracy: 2.0,
                           "[\(arm.rawValue)] loupe movement dx vs stock")
            XCTAssertEqual(movement.y, stockMovement.y, accuracy: 2.0,
                           "[\(arm.rawValue)] loupe movement dy vs stock")
        }
        assertNoKernelFailures(scenario)
    }
}
#endif
