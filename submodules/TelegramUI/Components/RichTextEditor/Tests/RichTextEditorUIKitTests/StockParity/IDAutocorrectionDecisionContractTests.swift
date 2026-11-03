#if canImport(UIKit)
import UIKit
import XCTest
import RichTextEditorCore
import RichTextEditorDifferentialHarness
import RichTextEditorStockParitySupport
@testable import RichTextEditorUIKit

/// **Ported from `/Users/isaac/Documents/InputDec/Tests/IDAutocorrectionDecisionContractTests.m`**
/// (`grep -c '^- (void)test'` = **17** tests, not the 13 recorded in Task P1's `PROVENANCE.md` —
/// corrected here after re-deriving it from upstream rather than carrying the number forward).
/// **3 of 17 ported. Task P1 ported none.**
///
/// ## Why only three, and why three at all
///
/// P1 declined the whole file, and its reasoning survives for 14 of the 17. Re-derived from
/// upstream, the 17 split:
///
/// | group | count | ported? |
/// | --- | --- | --- |
/// | host behaviour (`testAutocorrectionReplacementKeepsActiveSemanticTraits`) | 1 | **no** — already covered by `IDInlineFormattingStockOracleParityTests` test 3 |
/// | upstream's own test scaffolding: the 21-row decision matrix, the `IDParseAutocorrectionStatus` JSON schema and its rejection cases, the candidate-absence error policy | 11 | **no** — they certify upstream's harness, not this port. Porting them would add eleven guaranteed-green tests that assert nothing about Telegram, and this programme has enough manufactured green. |
/// | correction ATOMICITY around a structural boundary | 5 | **3 ported here**, 2 dropped |
///
/// The atomicity group is the one worth having, and P1 under-weighted it. Its claim — *a correction
/// replaces EXACTLY the token it targets, leaves the block structure intact, and rebases a caret
/// that sits after it by exactly the length delta* — is precisely the family where the InputDec
/// backend has already been caught failing three separate ways (insert lands twice, backspace
/// deletes two, marked text commits twice). A correction landing next to a structural newline is
/// where that failure would do the most damage to a real message.
///
/// The two dropped from that group
/// (`testDelimiterCommitThenImmediateDeletesStayOrderedAcrossBlockBoundaries`,
/// `testCandidateCommitThenOrdinaryDeletesRemainControllerIndependent`) drive upstream's
/// `IDAutocorrectionDecisionTestSupport` candidate machinery, which does not exist on this side.
///
/// ## Dropped assertions inside the three that ARE ported
///
/// Upstream asserts `document.documentRevision == 1` and exactly one
/// `NSTextStorageDidProcessEditingNotification` — the literal "in ONE transaction" half. Both read
/// `IDCanonicalTextStorageAdapter` / `IDBlockDocument`, upstream product source, and neither has any
/// `UITextInput` observable. They are DROPPED and recorded, not silently re-expressed: what is kept
/// is the observable consequence (exact text, intact structure, correctly rebased caret), which is
/// what a user would notice, and not the transaction count, which is what a profiler would.
@available(iOS 17.0, *)
@MainActor
final class IDAutocorrectionDecisionContractTests: XCTestCase {

    private var violations = IDStockParity.ViolationLog()

    override func setUpWithError() throws {
        try super.setUpWithError()
        try XCTSkipUnless(IDTextEditorBackend.isSupported(),
                          "InputDec backend unsupported on this runtime")
        violations = IDStockParity.ViolationLog()
        IDStockParity.installContractReporter(violations, in: self)
    }

    private func fixture(_ blocks: [String]) -> IDParityFixture {
        var fixture = IDParityFixture(blocks: blocks)
        fixture.fontSize = 17.0
        fixture.armSize = CGSize(width: 280, height: 250)
        return fixture
    }

    /// Upstream's shared body, at the public surface: park a caret at `caretBefore`, replace
    /// `range` with `"address"`, and read back the text, the newline position, and where the caret
    /// ended up.
    private func correct(_ blocks: [String], range: NSRange, caretBefore: Int,
                         scenario: String, expected: String, expectedCaretAfter: Int) throws {
        let arms = try IDStockParity.makeArms(fixture(blocks), in: self)

        let readings = arms.each { subject -> String in
            let input = subject.input
            _ = subject.responder.becomeFirstResponder()
            guard let caretPosition = IDStockParity.position(input, atCharacterIndex: caretBefore),
                  let caretRange = input.textRange(from: caretPosition, to: caretPosition) else {
                return IDStockParity.decline("no caret at \(caretBefore)")
            }
            input.selectedTextRange = caretRange
            guard let target = IDStockParity.textRange(input, forCharacterRange: range) else {
                return IDStockParity.decline("no range \(NSStringFromRange(range))")
            }
            input.replace(target, withText: "address")
            let text = IDStockParity.plainText(input)
            let newline = (text as NSString).range(of: "\n").location
            let caretAfter = input.selectedTextRange.flatMap {
                IDStockParity.characterIndex(input, $0.start)
            }
            // THREE FIELDS, not one composite string — deviation P2-5. They are joined by "|" only
            // so one `each` pass can carry them; they are split apart before any classification.
            // Written as a composite first, two commits after P2-5 was recorded, and the review
            // caught it: a caret-only divergence would otherwise bill the text and the block
            // structure too.
            return [
                "text=\(text.debugDescription)",
                "newlineAt=\(newline == NSNotFound ? "none" : String(newline))",
                "caret=\(caretAfter.map(String.init) ?? IDStockParity.decline("caret unmappable"))",
            ].joined(separator: "|")
        }

        // The oracle's own claims, kept verbatim from upstream and asserted on stock alone, so a
        // stock regression is never absorbed into a three-way "everyone agrees".
        let expectedNewline = (expected as NSString).range(of: "\n").location
        XCTAssertEqual(readings.stock,
                       ["text=\(expected.debugDescription)",
                        "newlineAt=\(expectedNewline == NSNotFound ? "none" : String(expectedNewline))",
                        "caret=\(expectedCaretAfter)"].joined(separator: "|"),
                       "the ORACLE moved: stock no longer produces upstream's expected result")

        // ONE assertField PER CLAIM (deviation P2-5). A declined arm's whole reading is handed to
        // every claim index, exactly as `IDBlockTextViewParityTests` does, so the vacuity guard
        // fires on all three rather than on whichever index happens to hold the sentinel.
        let claims = ["replaced text", "structural newline position", "rebased caret"]
        for (index, claim) in claims.enumerated() {
            func part(_ reading: String) -> String {
                if IDStockParity.isDeclined(reading) { return reading }
                let parts = reading.components(separatedBy: "|")
                return index < parts.count ? parts[index] : reading
            }
            IDStockParity.assertField(claim, scenario: scenario,
                                      stock: part(readings.stock),
                                      inputDec: part(readings.inputDec),
                                      legacy: part(readings.legacy),
                                      note: "a correction must replace EXACTLY its token, leave the "
                                          + "structural newline where it was, and shift a caret "
                                          + "sitting after it by the length delta")
        }
        IDStockParity.assertNoKernelFailures(violations, scenario)
    }

    /// Upstream: `testInteriorCorrectionReplacesExactCanonicalTokenInOneTransaction`. `"adress"` at
    /// {8, 6} of the FIRST of two blocks becomes `"address"`; the second block is untouched.
    func test_anInteriorCorrectionReplacesExactlyItsToken() throws {
        try correct(["A quiet adress lantern waits.", "Second block stays unchanged."],
                    range: NSRange(location: 8, length: 6),
                    caretBefore: 14,
                    scenario: "correct \"adress\"→\"address\" in the middle of the first block",
                    expected: "A quiet address lantern waits.\nSecond block stays unchanged.",
                    expectedCaretAfter: 15)
    }

    /// Upstream: `testCorrectionImmediatelyBeforeStructuralNewlineIsAtomic`. The corrected token
    /// ENDS at the block boundary — the character after it is the structural newline.
    func test_aCorrectionImmediatelyBeforeAStructuralNewlineIsAtomic() throws {
        try correct(["A quiet adress", "lantern waits."],
                    range: NSRange(location: 8, length: 6),
                    caretBefore: 14,
                    scenario: "correct a token that ends AT the block boundary",
                    expected: "A quiet address\nlantern waits.",
                    expectedCaretAfter: 15)
    }

    /// Upstream: `testCorrectionImmediatelyAfterStructuralNewlineIsAtomic`. The corrected token
    /// STARTS at the block boundary — it is the first word of the second block.
    func test_aCorrectionImmediatelyAfterAStructuralNewlineIsAtomic() throws {
        try correct(["A quiet scene.", "adress lantern waits."],
                    range: NSRange(location: 15, length: 6),
                    caretBefore: 21,
                    scenario: "correct a token that starts AT the block boundary",
                    expected: "A quiet scene.\naddress lantern waits.",
                    expectedCaretAfter: 22)
    }
}
#endif
