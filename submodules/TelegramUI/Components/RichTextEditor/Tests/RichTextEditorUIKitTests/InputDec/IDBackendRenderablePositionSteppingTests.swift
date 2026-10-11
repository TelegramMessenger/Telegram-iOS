#if canImport(UIKit)
import RichTextInputDecObjC
import UIKit
import XCTest
@testable import RichTextEditorUIKit

/// Task D4f — **`position(from:offset:)` must land on a RENDERABLE position, exactly as the legacy
/// backend's own member does.**
///
/// `LegacyRichTextInputBackend.position(from:offset:)`
/// (`LegacyRichTextInputBackend+TextReads.swift`) is one line of body:
///
///     LegacyTextPosition(legacyCanvas.legacySnapToRenderable(n, forward: offset >= 0))
///
/// The ID backend's counterpart (`TGRichTextInputDecLayoutController
/// .id_positionFromPosition:offset:affinity:`) clamped through the document client and stopped
/// there. Both walk the same STRUCTURAL axis, on which a top-level paragraph boundary occupies TWO
/// non-renderable token slots while the plain-text projection emits ONE `"\n"` — so a single
/// unsnapped `+1` step parks the caret on a slot no caret can occupy, and every consumer that
/// counts steps disagrees with legacy by one from that boundary onward.
///
/// **Why this is the last member of the plain-vs-structural cluster and not a fresh bug.** The
/// differential corpus aims every `set-selection`/`replace-range` transaction with
/// `IDTelegramPositionForCharacterIndex` (`Tests/DifferentialSupport/IDTelegramCharacterAxis.m`),
/// which walks `positionFromPosition:offset:1` and takes the FIRST position whose character index
/// equals the target — its own doc comment asserting that stepping "skips the non-renderable slots
/// exactly as the editor does" and that the map is "monotone and injective over these positions".
/// On legacy both hold. On the ID backend the walk visited the gap slot too, so the map stopped
/// being injective and the corpus's aim at the FIRST CHARACTER OF A SECOND PARAGRAPH resolved one
/// slot early — onto the boundary gap.
///
/// From there the damage is `DocumentCanvasView.legacySetMarkedText`'s (`+MarkedText.swift`), not
/// this file's: a caret in the gap fails `isBodyParagraphPosition(lo)`, so composition degrades to
/// `commitMarkedText()` + a plain `insertText(_:)` — the provisional character is committed as
/// ordinary text, no canvas-side `markedRange` is ever established, and the NEXT composition update
/// inserts beside it instead of replacing it. That is the corpus's "doubled character". The nested
/// `insertText` also drives a SECOND `replaceCharactersInRange:withString:` through the façade
/// inside the first, so the mirror takes the same insert twice — the corpus's `canonical`
/// divergence, on top of the `blocks` one.
///
/// Every test here pins a CAPTURED value (measured on K1 / iOS 26.5 / 23F73) alongside the
/// invariant, never a re-derived one.
@available(iOS 17.0, *)
@MainActor
final class IDBackendRenderablePositionSteppingTests: XCTestCase {
    override func setUpWithError() throws {
        try XCTSkipUnless(IDTextEditorBackend.isSupported())
    }

    // The corpus's own `ime-ios26.5-v1` fixture text, split the way its `initial.text` splits.
    private static let corpusParagraphs = ["Alpha middle omega", "Second block remains unchanged."]

    /// The structural offset a `UITextPosition` names. Only the ID backend's positions carry one;
    /// legacy's are a different opaque type, which is why the cross-backend assertions below compare
    /// CHARACTER indices instead.
    private func structuralOffset(_ p: UITextPosition?) -> Int? {
        (p as? TGRichTextInputDecPosition)?.utf16Offset
    }

    /// `characterIndex(p) = |text(in: beginningOfDocument … p)|` — the one line of public
    /// `UITextInput` the differential recorder's whole axis is built on
    /// (`IDTelegramCharacterAxis.m`), reproduced here so a test failure speaks the corpus's units.
    private func characterIndex(_ canvas: DocumentCanvasView, _ p: UITextPosition) -> Int {
        guard let r = canvas.textRange(from: canvas.beginningOfDocument, to: p) else { return -1 }
        return ((canvas.text(in: r) ?? "") as NSString).length
    }

    /// `IDTelegramPositionForCharacterIndex` (`IDTelegramCharacterAxis.m`) verbatim in Swift — the
    /// corpus driver's aim. Reproduced rather than called so this suite needs no ObjC test bridge;
    /// the walk, the termination rule and the "first match wins" rule are identical.
    private func positionForCharacterIndex(_ canvas: DocumentCanvasView, _ index: Int) -> UITextPosition? {
        var current: UITextPosition? = canvas.beginningOfDocument
        var steps = 0
        while let c = current, steps < 1_000 {
            steps += 1
            let at = characterIndex(canvas, c)
            if at == index { return c }
            if at > index { return nil }
            guard let next = canvas.position(from: c, offset: 1),
                  canvas.compare(next, to: c) != .orderedSame else { return nil }
            current = next
        }
        return nil
    }

    private func canonical(_ canvas: DocumentCanvasView) -> String {
        guard let r = canvas.textRange(from: canvas.beginningOfDocument, to: canvas.endOfDocument)
        else { return "<no range>" }
        return canvas.text(in: r) ?? "<nil>"
    }

    private func documentProjection(_ canvas: DocumentCanvasView) -> String {
        (canvas.differentialTopLevelBlockTexts() ?? []).joined(separator: "\n")
    }

    // MARK: - The stepping primitive itself

    /// One `+1` step off the END of the first paragraph. Structurally the next TWO slots belong to
    /// the boundary (paragraph one closes, paragraph two opens); only the far side is renderable.
    /// Measured on `["Alpha", "Beta"]`: the first paragraph's text ends at structural 6, the gap is
    /// 7, and "Beta" starts at 8 — so a correct step answers 8 and a raw one answers 7.
    func test_steppingForwardOffTheEndOfAParagraph_skipsTheBoundaryGap() {
        let h = makeBackendHarness(backend: .inputDec, paragraphs: ["Alpha", "Beta"], width: 300)
        defer { h.tearDown() }
        let canvas = h.canvas

        let endOfAlpha = canvas.position(from: canvas.beginningOfDocument, offset: 5)!
        XCTAssertEqual(structuralOffset(endOfAlpha), 6, "fixture check: the end of \"Alpha\"")

        let next = canvas.position(from: endOfAlpha, offset: 1)
        XCTAssertEqual(structuralOffset(next), 8,
                       "a forward step must clear the whole two-slot boundary gap, landing on the "
                       + "start of \"Beta\" — 7 is the gap itself")
        XCTAssertTrue(canvas.isRenderablePosition(structuralOffset(next) ?? -1),
                      "the invariant: a position this witness hands back must be one a caret can occupy")
    }

    /// The mirror image. A `-1` step off the START of the second paragraph must land on the END of
    /// the first (structural 6), not in the gap (7).
    func test_steppingBackwardOffTheStartOfAParagraph_skipsTheBoundaryGap() {
        let h = makeBackendHarness(backend: .inputDec, paragraphs: ["Alpha", "Beta"], width: 300)
        defer { h.tearDown() }
        let canvas = h.canvas

        let startOfBeta = canvas.position(from: canvas.beginningOfDocument, offset: 7)!
        XCTAssertEqual(structuralOffset(startOfBeta), 8, "fixture check: the start of \"Beta\"")

        let previous = canvas.position(from: startOfBeta, offset: -1)
        XCTAssertEqual(structuralOffset(previous), 6,
                       "a backward step must clear the gap in the direction it is travelling")
        XCTAssertTrue(canvas.isRenderablePosition(structuralOffset(previous) ?? -1))
    }

    /// **The corpus driver's own documented invariant** (`IDTelegramCharacterAxis.m`: "the map is
    /// monotone and injective over these positions (measured)"). Injective means every `+1` step
    /// advances the character index by exactly one; a step onto a non-renderable slot advances it by
    /// zero and breaks the assumption every aimed transaction rests on.
    func test_theCharacterIndexOfEveryWalkedPositionIncreasesByExactlyOne() {
        let h = makeBackendHarness(backend: .inputDec,
                                   paragraphs: Self.corpusParagraphs, width: 400)
        defer { h.tearDown() }
        let canvas = h.canvas

        var indices: [Int] = []
        var current: UITextPosition? = canvas.beginningOfDocument
        var steps = 0
        while let c = current, steps < 200 {
            steps += 1
            indices.append(characterIndex(canvas, c))
            guard let next = canvas.position(from: c, offset: 1),
                  canvas.compare(next, to: c) != .orderedSame else { break }
            current = next
        }

        XCTAssertEqual(indices, Array(0...50),
                       "the walk must visit every character index exactly once and stop at the "
                       + "document's own length (50 characters over two paragraphs)")
    }

    // MARK: - The corpus's aim

    /// The `after-boundary` scenarios place the caret at character index 19 — the FIRST CHARACTER of
    /// the second paragraph. Structurally that is 21 (paragraph two's text start); 20 is the gap
    /// slot, which shares character index 19 with it because the projection's `"\n"` is emitted the
    /// moment the range reaches into the second block at all.
    func test_aimingAtTheFirstCharacterOfTheSecondParagraph_landsOnItsTextStart() {
        let h = makeBackendHarness(backend: .inputDec,
                                   paragraphs: Self.corpusParagraphs, width: 400)
        defer { h.tearDown() }
        let canvas = h.canvas

        let aimed = positionForCharacterIndex(canvas, 19)
        XCTAssertEqual(structuralOffset(aimed), 21,
                       "the corpus's `after-boundary` caret — 20 is the inter-paragraph gap")
        XCTAssertTrue(canvas.isRenderablePosition(structuralOffset(aimed) ?? -1),
                      "a caret the corpus aims must be one the editor can actually draw")
    }

    /// CONTROL, and the reason the failures above are about the BOUNDARY rather than about aiming in
    /// general: character index 6 sits inside the first paragraph, crosses nothing, and resolves to
    /// structural 7 both before and after this task's change.
    func test_aimingInsideAParagraph_isUnaffected() {
        let h = makeBackendHarness(backend: .inputDec,
                                   paragraphs: Self.corpusParagraphs, width: 400)
        defer { h.tearDown() }
        let canvas = h.canvas

        let aimed = positionForCharacterIndex(canvas, 6)
        XCTAssertEqual(structuralOffset(aimed), 7)
        XCTAssertTrue(canvas.isRenderablePosition(7))
    }

    // MARK: - What the mis-aim did downstream

    /// The corpus's `*-after-boundary-*` composition, reduced to its first two transactions. Before
    /// this task the second `setMarkedText` did not replace the first — the document read
    /// `"kかSecond …"` where stock UIKit reads `"かSecond …"` — because the degraded first
    /// composition never established a canvas-side `markedRange` to replace.
    func test_composingAtTheStartOfTheSecondParagraph_replacesTheProvisionalText() {
        let h = makeBackendHarness(backend: .inputDec,
                                   paragraphs: Self.corpusParagraphs, width: 400)
        defer { h.tearDown() }
        let canvas = h.canvas

        let aimed = positionForCharacterIndex(canvas, 19)!
        canvas.selectedTextRange = canvas.textRange(from: aimed, to: aimed)
        canvas.setMarkedText("k", selectedRange: NSRange(location: 1, length: 0))
        canvas.setMarkedText("か", selectedRange: NSRange(location: 1, length: 0))

        XCTAssertEqual(canvas.differentialTopLevelBlockTexts(),
                       ["Alpha middle omega", "かSecond block remains unchanged."],
                       "the composition update must REPLACE the provisional \"k\", not sit beside it")
    }

    /// The same run, read through the façade mirror instead of the document — the corpus's
    /// `canonical` field. The mis-aimed first composition drove a SECOND, nested
    /// `replaceCharactersInRange:withString:` (the `insertText` fallback inside
    /// `legacySetMarkedText`'s non-body-paragraph guard), and both frames applied the same
    /// `{19, 0} <- "k"` to the mirror: measured `"Alpha middle omega\nkkSecond block remains
    /// unchanged"` against a document that held exactly one `"k"`.
    func test_composingAtTheStartOfTheSecondParagraph_leavesTheMirrorMatchingTheDocument() {
        let h = makeBackendHarness(backend: .inputDec,
                                   paragraphs: Self.corpusParagraphs, width: 400)
        defer { h.tearDown() }
        let canvas = h.canvas

        let aimed = positionForCharacterIndex(canvas, 19)!
        canvas.selectedTextRange = canvas.textRange(from: aimed, to: aimed)
        canvas.setMarkedText("k", selectedRange: NSRange(location: 1, length: 0))

        XCTAssertEqual(canonical(canvas), documentProjection(canvas),
                       "the façade mirror must project the document exactly — one composed "
                       + "character, applied once")
        XCTAssertEqual(canonical(canvas), "Alpha middle omega\nkSecond block remains unchanged.",
                       "stock UIKit's own text at this checkpoint")
    }

    /// CONTROL for the pair above: the corpus's `interior-*` scenarios compose in the middle of the
    /// first paragraph and PASS both before and after. Keeping one here is what makes the two
    /// failures above attributable to the boundary rather than to marked text generally.
    func test_composingInsideAParagraph_replacesTheProvisionalText() {
        let h = makeBackendHarness(backend: .inputDec,
                                   paragraphs: Self.corpusParagraphs, width: 400)
        defer { h.tearDown() }
        let canvas = h.canvas

        let aimed = positionForCharacterIndex(canvas, 6)!
        canvas.selectedTextRange = canvas.textRange(from: aimed, to: aimed)
        canvas.setMarkedText("k", selectedRange: NSRange(location: 1, length: 0))
        canvas.setMarkedText("か", selectedRange: NSRange(location: 1, length: 0))

        XCTAssertEqual(canvas.differentialTopLevelBlockTexts(),
                       ["Alpha かmiddle omega", "Second block remains unchanged."])
        XCTAssertEqual(canonical(canvas), documentProjection(canvas))
    }

    // MARK: - Caret stepping (the second consumer of the same decision)

    /// `IDBackendDifferentialTraceTests`' `caret-across-paragraph-boundary`, reduced to its
    /// measurement: two hardware-arrow `.right` steps from the end of "Alpha". Legacy walks
    /// character indices 5 → 6 → 7. The ID backend walked 5 → 6 → 6, because its first step landed
    /// in the gap and its second only climbed out of it.
    func test_twoRightStepsFromTheEndOfAParagraph_advanceTwoCharacters() {
        let h = makeBackendHarness(backend: .inputDec, paragraphs: ["Alpha", "Beta"], width: 300)
        defer { h.tearDown() }
        let canvas = h.canvas

        var p = canvas.position(from: canvas.beginningOfDocument, offset: 5)!
        var walked: [Int] = [characterIndex(canvas, p)]
        for _ in 0..<2 {
            guard let next = canvas.position(from: p, in: .right, offset: 1) else { break }
            p = next
            walked.append(characterIndex(canvas, p))
        }

        XCTAssertEqual(walked, [5, 6, 7],
                       "two arrow presses must advance two characters, the same walk legacy makes")
        XCTAssertEqual(structuralOffset(p), 9, "one character into \"Beta\"")
    }

    /// The legacy arm of the assertion above, run here so the expected walk is MEASURED from the
    /// reference backend in the same process rather than asserted from memory.
    func test_theLegacyBackendWalksTheSameTwoCharacters() {
        let h = makeBackendHarness(backend: .legacy, paragraphs: ["Alpha", "Beta"], width: 300)
        defer { h.tearDown() }
        let canvas = h.canvas

        var p = canvas.position(from: canvas.beginningOfDocument, offset: 5)!
        var walked: [Int] = [characterIndex(canvas, p)]
        for _ in 0..<2 {
            guard let next = canvas.position(from: p, in: .right, offset: 1) else { break }
            p = next
            walked.append(characterIndex(canvas, p))
        }

        XCTAssertEqual(walked, [5, 6, 7])
    }
}
#endif
