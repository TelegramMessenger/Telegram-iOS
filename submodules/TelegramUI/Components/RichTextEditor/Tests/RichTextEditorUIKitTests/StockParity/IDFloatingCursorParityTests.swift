#if canImport(UIKit)
import UIKit
import XCTest
import RichTextEditorCore
import RichTextEditorDifferentialHarness
import RichTextEditorStockParitySupport
@testable import RichTextEditorUIKit

/// **RE-EXPRESSED from `/Users/isaac/Documents/InputDec/Tests/IDFloatingCursorParityTests.m`**
/// (846 lines, 12 tests — `wc -l`, `grep -c '^- (void)test'`). Task P1 could not reach it.
///
/// **This file is a RE-EXPRESSION, not a port, and the distinction is the whole reason this comment
/// is long.** Every one of upstream's 12 tests reaches the floating cursor through
/// `custom.id_richLayoutController` — an `IDRichTextLayoutController`, upstream PRODUCT source —
/// and compares it against stock's private `_internalTextLayoutController` via selectors like
/// `cursorPositionAtPoint:inContainer:`, `positionWithOffset:affinity:`,
/// `affinityForPosition:` and
/// `visualSelectionRangeForExtent:point:inContainer:affinity:`. Telegram's host has no
/// `IDRichTextLayoutController` and no `_internalTextLayoutController`: it routes the floating
/// cursor through `DocumentCanvasView+FloatingCursor.swift` into the input backend. So there is no
/// object on this side that upstream's assertions could be pointed at, and Global Constraint 12
/// forbids porting the one upstream uses.
///
/// What CAN be certified is the observable behaviour those assertions exist to protect, through the
/// three public `UITextInput` entry points the OS actually calls — `beginFloatingCursor(at:)`,
/// `updateFloatingCursor(at:)`, `endFloatingCursor()` — which all three arms implement. The claims
/// below are upstream's claims (where a drag lands, that a drag never mutates the document, that a
/// structural boundary is crossed the way stock crosses it) asserted through that surface.
///
/// **What is NOT covered, stated plainly rather than implied:** every affinity comparison
/// (`affinityForPosition:` at each stop), and all of upstream's container-local point arithmetic.
/// Derived with
/// `awk '/^- \(void\)test/{n=$0} /<selector>/{if(n!=l){print n; l=n}}' IDFloatingCursorParityTests.m`:
///
/// * `cursorPositionAtPoint:inContainer:` — **2** tests:
///   `testFloatingCursorControllerConsumesContainerLocalPointsWithoutViewConversion` (:512) and
///   `testFloatingCursorControllerLocalPointDoesNotSubtractHorizontalInsetOrigin` (:621).
/// * `affinityForPosition:` — **4** tests:
///   `testSelectionExtensionCapturedHorizontalPointsMatchPositionAffinityAndGeometry` (:202),
///   `testFloatingCursorStructuralBoundaryCapturedVerticalPointsMatchStock` (:306),
///   `testRichVisualSelectionNeutralCasesMatchStockWithoutMutatingDocument` (:412) and
///   `testFloatingCursorMixedBiDiVisualSelectionUsesPointDerivedExtentAndAnchor` (:686).
///
/// A first version of this comment called it "four upstream tests about that arithmetic
/// specifically" and then listed the affinity test among them. That was wrong in the grouping only
/// — all 12 are declared dropped either way, so nothing was ever over-claimed as covered — but the
/// label is now derived rather than remembered.
///
/// Probe points are derived per arm (P1 deviation 4): the arms' line boxes differ, so a
/// stock-derived y lands on a different line on the host and the failure would read as
/// "the floating cursor is broken" when the truth is "the line heights differ".
@available(iOS 17.0, *)
@MainActor
final class IDFloatingCursorParityTests: XCTestCase {

    private var violations = IDStockParity.ViolationLog()

    override func setUpWithError() throws {
        try super.setUpWithError()
        try XCTSkipUnless(IDTextEditorBackend.isSupported(),
                          "InputDec backend unsupported on this runtime")
        violations = IDStockParity.ViolationLog()
        IDStockParity.installContractReporter(violations, in: self)
    }

    /// Upstream's fixture shape for this suite: 17pt, a wide-enough box that the sample text wraps
    /// once per paragraph.
    private func fixture(_ blocks: [String]) -> IDParityFixture {
        var fixture = IDParityFixture(blocks: blocks)
        fixture.fontSize = 17.0
        fixture.armSize = CGSize(width: 280, height: 250)
        return fixture
    }

    private func offset(_ input: UITextInput, _ position: UITextPosition?) -> String {
        guard let position else { return "(nil)" }
        return IDStockParity.characterIndex(input, position).map(String.init) ?? IDStockParity.decline("unmappable")
    }

    private func selectionOffset(_ input: UITextInput) -> String {
        offset(input, input.selectedTextRange?.start)
    }

    /// The caret rect of `index` on THIS arm, or nil. Every probe point below is built from one.
    private func caretRect(_ input: UITextInput, at index: Int) -> CGRect? {
        guard let position = IDStockParity.position(input, atCharacterIndex: index) else { return nil }
        let rect = input.caretRect(for: position)
        guard rect.midX.isFinite, rect.midY.isFinite else { return nil }
        return rect
    }


    /// True when the stock arm's reading shows it actually RESPONDED to the drag.
    ///
    /// MEASURED 2026-08-26: a stock `UITextView` in this process resolves EVERY programmatic
    /// `updateFloatingCursor(at:)` to the same offset — the document end — regardless of the point.
    /// It is not answering. Comparing against it would report `PRE-EXISTING` for every arm and bill
    /// a real InputDec regression to "the editor never matched stock here", which is false and is
    /// exactly the misattribution the Legacy control exists to prevent.
    ///
    /// So each drag test asserts the InputDec-vs-Legacy comparison FIRST and unconditionally, then
    /// declines the three-arm comparison with evidence. The decline is an `XCTSkip` — NOT CERTIFIED,
    /// never a pass — and it comes AFTER the control assertion, so a regression is still reported.
    private func stockDiscriminates(_ reading: String) -> Bool {
        // A DECLINED reading is not a discriminating one, and saying so here is load-bearing: the
        // parse below pulls integers out of the string, and a decline embedded mid-reading
        // ("…⟪DECLINED: no caret at 23⟫…") would feed it the numbers inside the reason text. The
        // skip/no-skip decision would then rest on garbage. `assertAgainstControl` above has already
        // failed on the decline by this point; this only stops it being compounded.
        if IDStockParity.isDeclined(reading) { return false }
        // A reading of the form "3→7 12→12" carries BOTH the destination asked for and the offset
        // resolved. Only the resolved half says whether the arm answered — a first draft parsed
        // every number in the string, saw the varying destinations, and concluded the oracle was
        // discriminating when every single resolved value was the document end.
        let values: [Int]
        if reading.contains("→") {
            values = reading.components(separatedBy: "→").dropFirst().compactMap { part in
                Int(part.prefix { $0.isNumber })
            }
        } else {
            values = reading.split(whereSeparator: { ",→ []=".contains($0) }).compactMap { Int($0) }
        }
        return Set(values).count > 1
    }

    private func assertNoKernelFailures(_ scenario: String, file: StaticString = #filePath,
                                        line: UInt = #line) {
        IDStockParity.assertNoKernelFailures(violations, scenario, file: file, line: line)
    }

    // MARK: - 1. Where a drag lands

    /// Upstream's `testFloatingCursorFixtureGeometryMapsHorizontalAndVerticalPointsLikeStock`, at
    /// the public surface: begin the floating cursor at one caret, drag to a series of other
    /// carets' midpoints, and require the selection to land on those offsets — the same offsets on
    /// all three arms.
    ///
    /// Each destination is that ARM's own caret midpoint, so the claim survives differing line
    /// boxes; what is compared across arms is the resolved offset.
    func test_aFloatingCursorDragLandsOnTheOffsetItIsDraggedTo() throws {
        let scenario = "beginFloatingCursor at 3, drag through several carets, endFloatingCursor"
        let blocks = ["one two three four five", "six seven eight"]
        let arms = try IDStockParity.makeArms(fixture(blocks), in: self)
        let destinations = [0, 7, 12, (blocks[0] as NSString).length,
                            (blocks[0] as NSString).length + 5]

        let readings = arms.each { subject -> String in
            let input = subject.input
            _ = subject.responder.becomeFirstResponder()
            // The three floating-cursor methods are `@optional` on `UITextInput`. An arm that does
            // not implement them would make every drag below a silent no-op, and three silent
            // no-ops compare EQUAL and pass. Declining here routes that into the vacuity guard.
            guard input.beginFloatingCursor(at:) != nil, input.updateFloatingCursor(at:) != nil,
                  input.endFloatingCursor != nil else {
                return IDStockParity.decline("this arm does not implement the floating-cursor methods")
            }
            guard let origin = self.caretRect(input, at: 3) else { return IDStockParity.decline("no caret at 3") }
            input.beginFloatingCursor?(at: CGPoint(x: origin.midX, y: origin.midY))
            var landed: [String] = []
            for destination in destinations {
                guard let rect = self.caretRect(input, at: destination) else {
                    landed.append(IDStockParity.decline("no caret at \(destination)"))
                    continue
                }
                input.updateFloatingCursor?(at: CGPoint(x: rect.midX, y: rect.midY))
                landed.append("\(destination)→\(self.selectionOffset(input))")
            }
            input.endFloatingCursor?()
            landed.append("end→\(self.selectionOffset(input))")
            return landed.joined(separator: " ")
        }
        IDStockParity.assertAgainstControl("offset the drag resolves to", scenario: scenario,
                                           inputDec: readings.inputDec, legacy: readings.legacy,
                                           note: "each destination is that ARM's own caret midpoint")
        assertNoKernelFailures(scenario)
        try XCTSkipUnless(stockDiscriminates(readings.stock),
                          "[ORACLE UNAVAILABLE — NOT CERTIFIED] the stock UITextView resolved every "
                          + "drag point to the same offset (\(readings.stock)) — it does not respond "
                          + "to programmatic updateFloatingCursor in this process, so there is no "
                          + "oracle for WHERE a drag should land. The InputDec-vs-Legacy comparison "
                          + "above ran unconditionally and is the real signal here.")
        IDStockParity.assertArms("offset the drag resolves to", scenario: scenario, readings,
                                 note: "each destination is that ARM's own caret midpoint; the "
                                     + "resolved offset is what is compared")
    }

    // MARK: - 2. A drag never mutates the document

    /// Upstream: `testRichVisualSelectionNeutralCasesMatchStockWithoutMutatingDocument` — its
    /// `XCTAssertEqual(custom.id_document.documentRevision, revision)` after every probe.
    ///
    /// Re-expressed as the public observable: the document text is byte-identical before and after a
    /// full floating-cursor gesture, on every arm. A floating cursor is a SELECTION gesture; a
    /// backend that edited during one would corrupt the message being composed, and this is the
    /// cheapest possible guard against that.
    func test_aFloatingCursorGestureNeverMutatesTheDocument() throws {
        let scenario = "a full floating-cursor gesture must leave the text untouched"
        let blocks = ["one two three four five", "six seven eight"]
        let arms = try IDStockParity.makeArms(fixture(blocks), in: self)

        let readings = arms.each { subject -> String in
            let input = subject.input
            _ = subject.responder.becomeFirstResponder()
            // The three floating-cursor methods are `@optional` on `UITextInput`. An arm that does
            // not implement them would make every drag below a silent no-op, and three silent
            // no-ops compare EQUAL and pass. Declining here routes that into the vacuity guard.
            guard input.beginFloatingCursor(at:) != nil, input.updateFloatingCursor(at:) != nil,
                  input.endFloatingCursor != nil else {
                return IDStockParity.decline("this arm does not implement the floating-cursor methods")
            }
            let before = IDStockParity.plainText(input)
            guard let origin = self.caretRect(input, at: 2) else { return IDStockParity.decline("no caret at 2") }
            input.beginFloatingCursor?(at: CGPoint(x: origin.midX, y: origin.midY))
            for delta in [CGFloat(20), 60, -40, 0] {
                input.updateFloatingCursor?(at: CGPoint(x: origin.midX + delta, y: origin.midY))
            }
            input.endFloatingCursor?()
            let after = IDStockParity.plainText(input)
            return "unchanged=\(before == after) length=\((after as NSString).length)"
        }
        IDStockParity.assertArms("text is unchanged by the gesture", scenario: scenario, readings,
                                 note: "a floating cursor is a SELECTION gesture; an arm that "
                                     + "edited during one would corrupt the composed message")
        assertNoKernelFailures(scenario)
    }

    // MARK: - 3. Crossing a structural boundary

    /// Upstream: `testFloatingCursorStructuralBoundaryStopsMatchStockOffsetAffinityOrderAndGeometry`
    /// and `…CapturedVerticalPointsMatchStock`, at the public surface: drag DOWNWARD across the
    /// paragraph boundary in even steps and compare the ORDERED SEQUENCE of offsets the drag stops
    /// at.
    ///
    /// The sequence, not just the endpoint: upstream's point is that the stops are the same stops in
    /// the same order, which is what makes a drag feel like stock rather than merely ending in the
    /// right place. Upstream's affinity half is NOT covered — `affinityForPosition:` has no public
    /// counterpart (see the file comment).
    func test_draggingDownAcrossAParagraphBoundaryStopsWhereStockStops() throws {
        let scenario = "drag the floating cursor down across the paragraph boundary"
        let blocks = ["one two three four five", "six seven eight"]
        let arms = try IDStockParity.makeArms(fixture(blocks), in: self)

        let readings = arms.each { subject -> String in
            let input = subject.input
            _ = subject.responder.becomeFirstResponder()
            // The three floating-cursor methods are `@optional` on `UITextInput`. An arm that does
            // not implement them would make every drag below a silent no-op, and three silent
            // no-ops compare EQUAL and pass. Declining here routes that into the vacuity guard.
            guard input.beginFloatingCursor(at:) != nil, input.updateFloatingCursor(at:) != nil,
                  input.endFloatingCursor != nil else {
                return IDStockParity.decline("this arm does not implement the floating-cursor methods")
            }
            guard let start = self.caretRect(input, at: 4),
                  let end = self.caretRect(input, at: (blocks[0] as NSString).length + 6)
            else { return IDStockParity.decline("no caret geometry for the drag") }
            input.beginFloatingCursor?(at: CGPoint(x: start.midX, y: start.midY))
            var stops: [String] = []
            let steps = 6
            for step in 1...steps {
                let t = CGFloat(step) / CGFloat(steps)
                let point = CGPoint(x: start.midX + (end.midX - start.midX) * t,
                                    y: start.midY + (end.midY - start.midY) * t)
                input.updateFloatingCursor?(at: point)
                stops.append(self.selectionOffset(input))
            }
            input.endFloatingCursor?()
            // Upstream's claim is about the ORDER, so a monotonicity read travels with the stops.
            let numeric = stops.compactMap(Int.init)
            let monotonic = numeric.count == stops.count
                && zip(numeric, numeric.dropFirst()).allSatisfy { $0 <= $1 }
            return "stops=[\(stops.joined(separator: ","))] monotonic=\(monotonic)"
        }
        IDStockParity.assertAgainstControl("ordered stops through the boundary", scenario: scenario,
                                           inputDec: readings.inputDec, legacy: readings.legacy,
                                           note: "upstream compares the stop SEQUENCE, not just "
                                               + "where the drag ends")
        assertNoKernelFailures(scenario)
        try XCTSkipUnless(stockDiscriminates(readings.stock),
                          "[ORACLE UNAVAILABLE — NOT CERTIFIED] stock reported the same offset at "
                          + "every stop (\(readings.stock)).")
        IDStockParity.assertArms("ordered stops through the boundary", scenario: scenario, readings,
                                 note: "upstream compares the stop SEQUENCE, not just where the "
                                     + "drag ends; affinity at each stop has no public counterpart "
                                     + "and is not covered here")
    }

    // MARK: - 4. Mixed bidi

    /// Upstream: `testFloatingCursorMixedBiDiGestureDeltaPointsMatchStockVisualRanges` and
    /// `…MixedBiDiStopsMatchStockOffsetAffinityOrderAndGeometry`, at the public surface: drag left
    /// to right across an embedded RTL run and compare the ordered stops.
    ///
    /// This is where a floating cursor is hardest and where a backend most plausibly diverges: the
    /// visual order and the logical order disagree inside the Hebrew run, so the stop sequence is
    /// NOT monotonic in offset and the arms must disagree with monotonicity in the same way.
    func test_draggingAcrossAnEmbeddedRTLRunVisitsTheSameStops() throws {
        let scenario = "drag the floating cursor across the RTL run of \"abc אבג def\""
        let arms = try IDStockParity.makeArms(fixture(["abc אבג def"]), in: self)

        let readings = arms.each { subject -> String in
            let input = subject.input
            _ = subject.responder.becomeFirstResponder()
            // The three floating-cursor methods are `@optional` on `UITextInput`. An arm that does
            // not implement them would make every drag below a silent no-op, and three silent
            // no-ops compare EQUAL and pass. Declining here routes that into the vacuity guard.
            guard input.beginFloatingCursor(at:) != nil, input.updateFloatingCursor(at:) != nil,
                  input.endFloatingCursor != nil else {
                return IDStockParity.decline("this arm does not implement the floating-cursor methods")
            }
            guard let start = self.caretRect(input, at: 0),
                  let end = self.caretRect(input, at: 11)
            else { return IDStockParity.decline("no caret geometry for the drag") }
            input.beginFloatingCursor?(at: CGPoint(x: start.midX, y: start.midY))
            var stops: [String] = []
            let steps = 10
            for step in 1...steps {
                let t = CGFloat(step) / CGFloat(steps)
                input.updateFloatingCursor?(at: CGPoint(x: start.midX + (end.midX - start.midX) * t,
                                                       y: start.midY))
                stops.append(self.selectionOffset(input))
            }
            input.endFloatingCursor?()
            return stops.joined(separator: ",")
        }
        IDStockParity.assertAgainstControl("ordered stops across the RTL run", scenario: scenario,
                                           inputDec: readings.inputDec, legacy: readings.legacy,
                                           note: "visual and logical order disagree inside the RTL "
                                               + "run")
        assertNoKernelFailures(scenario)
        try XCTSkipUnless(stockDiscriminates(readings.stock),
                          "[ORACLE UNAVAILABLE — NOT CERTIFIED] stock reported the same offset at "
                          + "every stop (\(readings.stock)).")
        IDStockParity.assertArms("ordered stops across the RTL run", scenario: scenario, readings,
                                 note: "visual and logical order disagree inside the RTL run, so "
                                     + "the arms must disagree with monotonicity in the SAME way")
    }

    // MARK: - 5. Lifecycle robustness

    /// **Not upstream.** Upstream never drives the three entry points out of order because its own
    /// controller owns the sequencing. Telegram's host does not: `DocumentCanvasView+FloatingCursor`
    /// routes each call one line into the backend, and the file's own header records that the OS
    /// does NOT always deliver `endFloatingCursor` (it names resigning first responder and removal
    /// from the window as two cases where it does not).
    ///
    /// So an unmatched `endFloatingCursor()`, and a second `beginFloatingCursor(at:)` without an
    /// intervening end, are states this host really reaches. This asserts only that they do not
    /// crash and do not mutate the document — the weakest useful claim, and stated as an addition
    /// rather than dressed up as upstream's.
    func test_unbalancedFloatingCursorCallsDoNotCrashOrMutate() throws {
        let scenario = "endFloatingCursor without begin, and begin twice"
        let arms = try IDStockParity.makeArms(fixture(["one two three"]), in: self)

        let readings = arms.each { subject -> String in
            let input = subject.input
            _ = subject.responder.becomeFirstResponder()
            // The three floating-cursor methods are `@optional` on `UITextInput`. An arm that does
            // not implement them would make every drag below a silent no-op, and three silent
            // no-ops compare EQUAL and pass. Declining here routes that into the vacuity guard.
            guard input.beginFloatingCursor(at:) != nil, input.updateFloatingCursor(at:) != nil,
                  input.endFloatingCursor != nil else {
                return IDStockParity.decline("this arm does not implement the floating-cursor methods")
            }
            let before = IDStockParity.plainText(input)
            input.endFloatingCursor?()
            guard let rect = self.caretRect(input, at: 2) else { return IDStockParity.decline("no caret at 2") }
            input.beginFloatingCursor?(at: CGPoint(x: rect.midX, y: rect.midY))
            input.beginFloatingCursor?(at: CGPoint(x: rect.midX + 30, y: rect.midY))
            input.endFloatingCursor?()
            input.endFloatingCursor?()
            return "unchanged=\(IDStockParity.plainText(input) == before)"
        }
        IDStockParity.assertArms("text unchanged through an unbalanced sequence",
                                 scenario: scenario, readings,
                                 note: "the host's own +FloatingCursor header records that the OS "
                                     + "does not always deliver endFloatingCursor")
        assertNoKernelFailures(scenario)
    }
}
#endif
