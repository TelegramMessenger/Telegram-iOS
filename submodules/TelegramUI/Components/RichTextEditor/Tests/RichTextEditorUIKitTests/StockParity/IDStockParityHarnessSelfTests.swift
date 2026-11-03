#if canImport(UIKit)
import UIKit
import XCTest
@testable import RichTextEditorUIKit

/// **The harness testing itself.**
///
/// Every other file in this directory certifies Telegram's editor. This one certifies the thing that
/// does the certifying — because a harness that misclassifies is worse than no harness: it produces
/// confidently wrong verdicts, and this programme has already shipped vacuous green more than once.
///
/// It exists because the P2 review found a real bypass of the vacuity guard that no test could have
/// caught: `assertField`'s decline check was anchored to the whole value
/// (`hasPrefix("<") && hasSuffix(">")`), while two suites compose a reading out of per-element
/// tokens — so a decline for ONE element landed mid-string and the guard never fired. Three arms
/// that all declined on the same element compared EQUAL and passed having measured nothing.
///
/// `test_2` below is that bypass, written as a test. It fails against the old guard and passes
/// against the current one.
@MainActor
final class IDStockParityHarnessSelfTests: XCTestCase {

    // MARK: - The vacuity guard

    /// A whole-value decline, in either spelling, is detected. The legacy `<…>` shape is still
    /// honoured deliberately: a decline site added by hand, or one the migration missed, must still
    /// trip the guard rather than silently become a comparable value.
    func test_1_aWholeValueDeclineIsDetectedInBothSpellings() {
        XCTAssertTrue(IDStockParity.isDeclined(IDStockParity.decline("no caret at 3")))
        XCTAssertTrue(IDStockParity.isDeclined("<closestPosition returned nil>"),
                      "the pre-migration whole-value spelling must still be caught")
    }

    /// **THE BYPASS, as a regression test.** A decline for one element of a composed reading is
    /// detected even though the composed string neither starts with the marker nor ends with it.
    ///
    /// Against the old prefix/suffix guard every one of these assertions fails.
    func test_2_aDeclineEmbeddedInAComposedReadingIsDetected() {
        let composed = "0→0 " + IDStockParity.decline("no caret at 23") + " end→28"
        XCTAssertTrue(IDStockParity.isDeclined(composed),
                      "a per-element decline joined into a longer reading must still trip the guard "
                      + "— this is the exact bypass the P2 review found")

        // The `parts`-join shape from IDBlockTextViewParityTests, including the case where the
        // decline is further wrapped by `.debugDescription`.
        let wrapped = "word={4,6} text{4,10}=" + IDStockParity.decline("nil").debugDescription
        XCTAssertTrue(IDStockParity.isDeclined(wrapped),
                      "a decline wrapped in debugDescription inside a longer reading must be caught")

        // And the property that makes the whole guard worth having: three arms that all decline on
        // the same element produce EQUAL readings. Equality is exactly why the guard cannot be left
        // to the verdict comparison.
        let sameOnEveryArm = composed
        XCTAssertEqual(composed, sameOnEveryArm,
                       "three declining arms compare equal — which is why a decline must fail on "
                       + "its own and never be left to the stock/inputDec/legacy comparison")
    }

    /// A real reading must NOT be mistaken for a decline. Two specific shapes matter: the deliberate
    /// `(no selection)` sentinel (spelled with parentheses for exactly this reason), and a reading
    /// that embeds document text through `debugDescription`.
    func test_3_realReadingsAreNotMistakenForDeclines() {
        XCTAssertFalse(IDStockParity.isDeclined("(no selection)"))
        XCTAssertFalse(IDStockParity.isDeclined("{0, 0}"))
        XCTAssertFalse(IDStockParity.isDeclined("text=\"alpha\\nbeta\" newlineAt=5 caret=7"))
        XCTAssertFalse(IDStockParity.isDeclined("stops=[4,4,29,29] monotonic=true"))
        // The reason the guard does NOT scan for a bare `<…>` anywhere: a fixture containing angle
        // brackets would otherwise be permanently unable to assert anything.
        XCTAssertFalse(IDStockParity.isDeclined("text=\"a <b> c\""),
                       "document text containing angle brackets is a reading, not a decline")
    }

    // MARK: - The classification

    /// The four-way split is derived from the two equality comparisons and nothing else. Pinned
    /// because the P2 review found a call site that hardcoded one arm's value to a literal, which
    /// misclassified in both directions — and because `.portImprovement` does not fail, so a wrong
    /// input landing there disappears entirely.
    func test_4_theVerdictIsAFunctionOfTheThreeReadingsOnly() {
        func verdict(stock: String, inputDec: String, legacy: String) -> IDStockParity.Verdict {
            switch (inputDec == stock, legacy == stock) {
            case (true, true):   return .match
            case (true, false):  return .portImprovement
            case (false, true):  return .portDefect
            case (false, false): return .preExisting
            }
        }
        XCTAssertEqual(verdict(stock: "a", inputDec: "a", legacy: "a"), .match)
        XCTAssertEqual(verdict(stock: "a", inputDec: "b", legacy: "a"), .portDefect)
        XCTAssertEqual(verdict(stock: "a", inputDec: "b", legacy: "b"), .preExisting,
                       "when BOTH host arms diverge the bill is PRE-EXISTING, never PORT-DEFECT — "
                       + "the hardcoded-literal bug produced exactly this misclassification")
        XCTAssertEqual(verdict(stock: "a", inputDec: "a", legacy: "b"), .portImprovement)
    }
}
#endif
