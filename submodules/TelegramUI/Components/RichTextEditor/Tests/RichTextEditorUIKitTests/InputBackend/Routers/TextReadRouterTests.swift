#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// TASK 24 — Family 1 (document reads and position/range conversion), the FIRST family task and the
/// one that sets the pattern the other ten copy. Every test below uses `XCTAssertRoutesOnly`
/// (`T/Support/RouterAssertions.swift`) for its assertion pair — never the separate `before`/
/// `XCTAssertSingleBackendCall`/`XCTAssertRouterDidNoWork` triple — so exit criterion 3's four clauses
/// ("one backend call", "exact arguments", "exact return propagation", "and nothing else" on both the
/// backend log and the canvas state) are structurally impossible to under-deliver in any one test here.
///
/// `test_beginningOfDocument_returnsTheBackendsExactObject` reads through `canvas.beginningOfDocument`
/// (a real canvas property), never `canvas.inputBackend.beginningOfDocument` — the latter would prove
/// only that the spy itself works, not that the canvas routes to it, and was deliberately kept out of
/// this file (Task 23's settled obligation #1). R14
/// (`Tests/RichTextEditorCoreTests/SourceBoundary/InputBackendSourceBoundaryTests.swift`,
/// `test_noInputBackendDotMentionInRouterTests_R14`) is the mechanical guard against reintroducing that
/// vacuity trap into this directory.
@MainActor
@available(iOS 16.0, *)
final class TextReadRouterTests: XCTestCase {
    private func spyCanvas() -> (DocumentCanvasView, SpyRichTextInputBackend) {
        let spy = SpyRichTextInputBackend()
        let v = DocumentCanvasView(inputBackend: spy)
        v.setParagraphs([ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "Alpha")])], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 300); v.layoutIfNeeded()
        spy.reset()
        return (v, spy)
    }

    func test_textInRange_callsTheBackendOnceAndReturnsItsExactString() {
        let (v, spy) = spyCanvas()
        let result = XCTAssertRoutesOnly(v, spy, member: "text(in:)",
                                         arguments: [ObjectIdentifier(spy.sentinelRange).debugDescription]) {
            v.text(in: spy.sentinelRange)
        }
        XCTAssertEqual(result, spy.stubbedText)
    }

    func test_beginningOfDocument_returnsTheBackendsExactObject() {
        let (v, spy) = spyCanvas()
        let result = XCTAssertRoutesOnly(v, spy, member: "beginningOfDocument", arguments: []) {
            v.beginningOfDocument
        }
        XCTAssertTrue(result === spy.sentinelPosition,
                      "the router must forward the object, not rebuild it")
    }

    func test_endOfDocument_returnsTheBackendsExactObject() {
        let (v, spy) = spyCanvas()
        let result = XCTAssertRoutesOnly(v, spy, member: "endOfDocument", arguments: []) {
            v.endOfDocument
        }
        XCTAssertTrue(result === spy.sentinelPosition,
                      "the router must forward the object, not rebuild it")
    }

    func test_textRangeFromTo_forwardsBothArgumentsInOrder() {
        let (v, spy) = spyCanvas()
        let from = DocumentTextPosition(11)
        let to = DocumentTextPosition(22)
        let result = XCTAssertRoutesOnly(v, spy, member: "textRange(from:to:)",
                                         arguments: [ObjectIdentifier(from).debugDescription,
                                                     ObjectIdentifier(to).debugDescription]) {
            v.textRange(from: from, to: to)
        }
        XCTAssertTrue(result === spy.sentinelRange,
                      "the router must forward the object, not rebuild it")
    }

    func test_positionFromOffset_forwardsTheSignedOffset() {
        let (v, spy) = spyCanvas()
        let result = XCTAssertRoutesOnly(v, spy, member: "position(from:offset:)",
                                         arguments: [ObjectIdentifier(spy.sentinelPosition).debugDescription, "-3"]) {
            v.position(from: spy.sentinelPosition, offset: -3)
        }
        XCTAssertTrue(result === spy.sentinelPosition,
                      "the router must forward the object, not rebuild it")
    }

    func test_compare_returnsTheBackendsComparisonResult() {
        let (v, spy) = spyCanvas()
        let a = DocumentTextPosition(5)
        let b = DocumentTextPosition(9)
        let result = XCTAssertRoutesOnly(v, spy, member: "compare(_:to:)",
                                         arguments: [ObjectIdentifier(a).debugDescription,
                                                     ObjectIdentifier(b).debugDescription]) {
            v.compare(a, to: b)
        }
        XCTAssertEqual(result, spy.stubbedComparison)
    }

    func test_offsetFromTo_returnsTheBackendsSignedOffset() {
        let (v, spy) = spyCanvas()
        let a = DocumentTextPosition(5)
        let b = DocumentTextPosition(9)
        let result = XCTAssertRoutesOnly(v, spy, member: "offset(from:to:)",
                                         arguments: [ObjectIdentifier(a).debugDescription,
                                                     ObjectIdentifier(b).debugDescription]) {
            v.offset(from: a, to: b)
        }
        XCTAssertEqual(result, spy.stubbedOffset)
    }

    func test_positionWithinFarthestIn_forwardsRangeAndDirection() {
        let (v, spy) = spyCanvas()
        // `String(describing:)` over `UITextLayoutDirection` does NOT render a case name on this SDK
        // (it renders `UITextLayoutDirection(rawValue: 3)`) — computed here, not hardcoded, so the
        // assertion still discriminates a WRONG direction being forwarded without depending on a
        // string shape this test does not control.
        let result = XCTAssertRoutesOnly(v, spy, member: "position(within:farthestIn:)",
                                         arguments: [ObjectIdentifier(spy.sentinelRange).debugDescription,
                                                     String(describing: UITextLayoutDirection.left)]) {
            v.position(within: spy.sentinelRange, farthestIn: .left)
        }
        XCTAssertTrue(result === spy.sentinelPosition,
                      "the router must forward the object, not rebuild it")
    }

    func test_characterRangeByExtending_forwardsPositionAndDirection() {
        let (v, spy) = spyCanvas()
        let result = XCTAssertRoutesOnly(v, spy, member: "characterRange(byExtending:in:)",
                                         arguments: [ObjectIdentifier(spy.sentinelPosition).debugDescription,
                                                     String(describing: UITextLayoutDirection.right)]) {
            v.characterRange(byExtending: spy.sentinelPosition, in: .right)
        }
        XCTAssertTrue(result === spy.sentinelRange,
                      "the router must forward the object, not rebuild it")
    }

    // The two that are NOT "the same shape" — written out because copying the first test's OPERATION
    // CLOSURE (not its assertion shape, which is uniform via `XCTAssertRoutesOnly` above) would produce
    // a passing-but-wrong assertion in both cases.

    /// The witness for this one lives in a DIFFERENT file (`+Navigation.swift`, not `+UITextInput.swift`),
    /// and it is the only read member carrying a `UITextLayoutDirection`. A router that dropped the
    /// direction would still return the sentinel and still record one call, so the direction must be
    /// asserted explicitly.
    func test_positionFromInDirectionOffset_forwardsTheDirection() {
        let (v, spy) = spyCanvas()
        let result = XCTAssertRoutesOnly(v, spy, member: "position(from:in:offset:)",
                                         arguments: [ObjectIdentifier(spy.sentinelPosition).debugDescription,
                                                     String(describing: UITextLayoutDirection.up), "3"]) {
            v.position(from: spy.sentinelPosition, in: .up, offset: 3)
        }
        XCTAssertTrue(result === spy.sentinelPosition)
    }

    /// `tokenizer` returns a `UITextInputTokenizer`, not a sentinel position — so identity is asserted
    /// against the spy's own stub, and the assertion that matters is that the canvas no longer builds
    /// its own `DocumentTokenizer` — TASK 43 deleted both the canvas's dead `inputTokenizer` storage
    /// and its `legacyMakeTokenizer()` construction hook, and
    /// `InputBackendSourceBoundaryTests.test_theTokenizerHasExactlyOneConstructionSite` is what pins
    /// that at the source level (two assertions since its own fix round — a construction scan and a
    /// mention allowance; the first version was evadable by `DocumentTokenizer.init(canvas:)`).
    ///
    /// TASK 24 FIX ROUND 1 (reviewer Minor 4, correcting an overstated claim) — the second read below
    /// proves only that the CANVAS routes twice (two spy calls, no local canvas work either time); it
    /// CANNOT prove the backend's own cache is a cache, since `SpyRichTextInputBackend.tokenizer`
    /// returns `stubbedTokenizer` unconditionally regardless of whether a real backend would have
    /// cached or rebuilt. That property — "reading it twice must not mint a second one" — is pinned
    /// against the REAL `LegacyRichTextInputBackend` instead, in
    /// `BackendAttachmentTests.test_tokenizerIsCachedAcrossReads` /
    /// `…test_tokenizerIsRebuiltAfterDetachAndReattachToADifferentCanvas`.
    func test_tokenizer_returnsTheBackendsExactTokenizer() {
        let (v, spy) = spyCanvas()
        let result = XCTAssertRoutesOnly(v, spy, member: "tokenizer", arguments: []) { v.tokenizer }
        XCTAssertTrue(result === spy.stubbedTokenizer,
                      "the router must vend the backend's tokenizer, not the canvas's own")
        // A second read must ALSO route through the canvas (not fall back to some canvas-local cache
        // reintroduced by mistake) — still exactly one call, still no other work.
        let second = XCTAssertRoutesOnly(v, spy, member: "tokenizer", arguments: []) { v.tokenizer }
        XCTAssertTrue(second === spy.stubbedTokenizer)
    }
}
#endif
