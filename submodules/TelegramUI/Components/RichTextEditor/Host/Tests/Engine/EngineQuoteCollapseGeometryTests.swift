import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// R7-collapse §4.1. The preview is capped at three LINE PITCHES, not three `font.lineHeight`s —
/// "how tall are N lines" is a pitch question (`BlockQuoteBox.lineHeight` carries the same note).
@available(iOS 18.4, *)
final class EngineQuoteCollapseGeometryTests: XCTestCase {
    private func para(_ id: String, _ text: String) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), runs: text.isEmpty ? [] : [TextRun(text: text)]))
    }
    private let font = UIFont.systemFont(ofSize: 15)
    private var attributes: [NSAttributedString.Key: Any] {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byTruncatingTail
        return [.font: font, .paragraphStyle: style]
    }
    private func attachment(_ children: [Block]) -> CollapsedQuoteTextAttachment {
        // The fixture builds the preview text the plain way on purpose: these cases are about the
        // BOX's arithmetic, and a mapper-built string would drag the whole editor in to ask a
        // question about widths and pitches. The formatted path is covered by
        // `EngineQuoteCollapseFidelityTests`, which drives the real bridge.
        let plain = children.map { block -> String in
            if case let .paragraph(paragraph) = block { return paragraph.text }
            return ""
        }.filter { !$0.isEmpty }.joined(separator: " ")
        return CollapsedQuoteTextAttachment(
            shape: QuoteShape(id: BlockID("q"), collapsed: true, foldedChildren: children),
            horizontalIndent: 0, leadingInset: 16, trailingInset: 22,
            previewText: NSAttributedString(string: plain, attributes: attributes),
            attributes: attributes)
    }

    /// The join rule moved to `EngineDocumentBridge.collapsedQuotePreviewText(for:)` when the preview
    /// became FORMATTED, so it is asserted there — `EngineQuoteCollapseFidelityTests`
    /// .test_blocksAreJoinedByExactlyOneSpace. The rule itself is unchanged: one space at the join.
    /// This case is retired rather than adapted; a copy here would pin the same rule twice against
    /// two different producers.

    func test_aShortQuotesPreviewIsOneLineTall() {
        let slot = attachment([para("a", "hi")]).slot(forLineWidth: 320)
        let pitch = RichTextRenderMetrics.linePitch(font, factor: 1.0)
        XCTAssertLessThan(slot.height, pitch * 2, "one line of text is not three lines tall")
        XCTAssertGreaterThan(slot.height, 0)
    }

    /// The cap is exactly `N × pitch`.
    ///
    /// This asserted `N × pitch + trailingHeightCorrection` when the rung shipped, which is the
    /// RENDERER's height convention and one pitch-minus-fontbox SHORT of what N lines of glyphs
    /// need — so the box could not hold its own third line and the label drew two. The expectation
    /// was wrong in the same way the code was, which is why it passed. See
    /// `test_theAtomsBoxCanHoldTheThreeLinesItDraws`, which asks the question this one cannot: it
    /// compares the box against the PINNED line box the real stylesheet produces, where this fixture
    /// builds a bare paragraph style.
    func test_aLongQuotesPreviewIsCappedAtThreeLines() {
        let long = String(repeating: "wordy ", count: 400)
        let slot = attachment([para("a", long)]).slot(forLineWidth: 320)
        let pitch = RichTextRenderMetrics.linePitch(font, factor: 1.0)
        XCTAssertEqual(slot.height, pitch * CGFloat(CollapsedQuoteGeometry.maxPreviewLines),
                       accuracy: 0.5)
    }

    /// The atom's box must be able to CONTAIN the three lines the preview draws.
    ///
    /// The cap was `3 × pitch + trailingHeightCorrection`, and that correction is NEGATIVE whenever
    /// the stylesheet's pinned line box is taller than the font's own box — at 15pt it is
    /// `ceil(14.28 + 3.62) − 19 = −1`. So the box came out 56pt where three pinned 19pt lines need
    /// 57, the label could fit only two, and it centred them: the device reported "two lines with
    /// larger vertical insets" (2026-09-15).
    ///
    /// The correction is the RENDERER's convention for how a block's height relates to the rhythm
    /// below it — a block of N lines measures `(N−1) × pitch + fontbox`. It says nothing about how
    /// much room N lines of glyphs need, which is what this box is for. An attachment atom
    /// contributes no trailing overhang to the rhythm anyway (`trailingLineBoxOverhangs` returns 0
    /// for one), so there is nothing here for the correction to be consistent with.
    ///
    /// Driven through the EDITOR rather than the local fixture: the fixture builds a bare paragraph
    /// style, and the number that matters here is the stylesheet's PINNED line box, which only the
    /// real bridge produces. The fixture's own precondition caught that.
    func test_theAtomsBoxCanHoldTheThreeLinesItDraws() {
        let long = String(repeating: "wordy ", count: 60)
        load([quote("q", [para("a", long)], collapsed: true)])
        defer { teardownWindow() }
        guard let attachment = editor.collapsedQuoteAttachment(atRoleAt: 0) else {
            return XCTFail("no attachment on the atom")
        }
        let pinned = (attachment.attributes[.paragraphStyle] as? NSParagraphStyle)?.minimumLineHeight ?? 0
        XCTAssertGreaterThan(pinned, 0, "precondition: the stylesheet pins the line box")
        XCTAssertGreaterThanOrEqual(
            attachment.slot(forLineWidth: 320).height,
            pinned * CGFloat(CollapsedQuoteGeometry.maxPreviewLines),
            "a box shorter than its own three lines drops one and centres the rest")
    }

    func test_theSlotSpansTheWholeLineSoTheBandDoesNotMoveWhenFolding() {
        XCTAssertEqual(attachment([para("a", "hi")]).slot(forLineWidth: 320).width, 320, accuracy: 0.01,
                       "the quote's own padding is applied INSIDE the host view, not by narrowing the atom")
    }

    func test_theMeasurementWidthIsNarrowedByThePaddingAndTheGlyphReserve() {
        let a = attachment([para("a", "hi")])
        XCTAssertEqual(a.textWidth(forLineWidth: 320),
                       320 - 16 - (22 + CollapsedQuoteGeometry.glyphSize + CollapsedQuoteGeometry.glyphGap),
                       accuracy: 0.01)
    }

    /// The document setter's differing-span diff compares rendered blocks with `isEqual`. A
    /// pointer-unequal atom reads as CHANGED on every set, which drags the caret's engine identity
    /// into the replaced span.
    func test_twoAtomsForTheSameFoldedQuoteAreEqual() {
        XCTAssertEqual(attachment([para("a", "hi")]), attachment([para("a", "hi")]))
    }

    func test_atomsForDifferentBodiesAreNotEqual() {
        XCTAssertNotEqual(attachment([para("a", "hi")]), attachment([para("a", "ho")]))
    }

    // MARK: - The band and the interior (R7-collapse §4.2)
    //
    // These arms were forced in by the compiler when `EngineBlockShape` gained its sixth case, so
    // they never had a natural red phase. Each was NEUTER-VERIFIED instead — the arm replaced by the
    // answer it displaced, the case confirmed red, the arm restored — which is the check this
    // package already applies to a rule it cannot watch fail (`EngineRoleNeighbourTests`).

    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!
    private func quote(_ id: String, _ children: [Block], collapsed: Bool = false) -> Block {
        .blockQuote(BlockQuote(id: BlockID(id), children: children, collapsed: collapsed))
    }
    private func load(_ blocks: [Block]) {
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window.addSubview(editor); window.makeKeyAndVisible()
        editor.document = Document(blocks: blocks)
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.setNeedsLayout(); editor.layoutIfNeeded()
    }
    private func teardownWindow() { window?.isHidden = true; window = nil; editor = nil }

    func test_aFoldedQuoteStillDrawsAQuoteBand() {
        load([quote("q", [para("a", "one")], collapsed: true)])
        defer { teardownWindow() }
        XCTAssertNotNil(editor.containerDecorationViews[BlockID("q")],
                        "the band comes from the LEAF path once the quote is no longer an ancestor")
    }

    func test_theBandSpansTheSameColumnFoldedAndOpen() {
        load([quote("q", [para("a", "one")])])
        let open = editor.containerDecorationViews[BlockID("q")]?.frame
        teardownWindow()
        load([quote("q", [para("a", "one")], collapsed: true)])
        let folded = editor.containerDecorationViews[BlockID("q")]?.frame
        defer { teardownWindow() }
        XCTAssertNotNil(open); XCTAssertNotNil(folded)
        XCTAssertEqual(open?.minX ?? -1, folded?.minX ?? -2, accuracy: 0.01)
        XCTAssertEqual(open?.width ?? -1, folded?.width ?? -2, accuracy: 0.01,
                       "folding changes the quote's HEIGHT and nothing about its column")
    }

    func test_aFoldedQuoteChargesItsOwnInteriorOnce() {
        load([quote("q", [para("a", "one")], collapsed: true)])
        defer { teardownWindow() }
        guard let band = editor.containerDecorationViews[BlockID("q")]?.frame else {
            return XCTFail("no band")
        }
        let atom = editor.engine.id_frameForBlock(at: 0)
        let interior = editor.bridge.styleSheet.quoteTopInset ?? 8.0
        XCTAssertEqual(atom.minY - band.minY, interior, accuracy: 0.6,
                       "the band grows into the quote's own top padding, exactly once")
    }

    // MARK: - The preview view (R7-collapse §4.3)

    func test_aFoldedQuoteGetsAPreviewViewOverItsAtom() {
        load([quote("q", [para("a", "one")], collapsed: true)])
        defer { teardownWindow() }
        guard let view = editor.collapsedQuoteViews[BlockID("q")] else {
            return XCTFail("no preview view")
        }
        XCTAssertEqual(view.frame, editor.engine.id_attachmentFrame(forCanonicalOffset: 0))
    }

    func test_thePreviewViewIsCulledWhenTheQuoteOpens() {
        load([quote("q", [para("a", "one")], collapsed: true)])
        defer { teardownWindow() }
        XCTAssertNotNil(editor.collapsedQuoteViews[BlockID("q")], "precondition: folded, so drawn")
        editor.toggleQuoteCollapsed(id: BlockID("q"))
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        XCTAssertNil(editor.collapsedQuoteViews[BlockID("q")])
    }

    /// §2.2: a pool that owns a view owns a field in the expectation, or the completeness check
    /// silently stops checking it.
    func test_aMissingPreviewViewIsReportedAsAShortfall() {
        load([quote("q", [para("a", "one")], collapsed: true)])
        defer { teardownWindow() }
        XCTAssertEqual(editor.derivedViewShortfall(), [], "precondition: complete after a layout")
        editor.collapsedQuoteViews.removeAll()
        XCTAssertTrue(editor.derivedViewShortfall().contains { $0.contains("collapsed quote") },
                      "got \(editor.derivedViewShortfall())")
    }

    /// THE device report: "the expand/collapse glyph is rendered at different positions."
    ///
    /// The two states draw different glyphs from different pools, and each used to spell the
    /// trailing-top corner against the rect it happened to hold — the open one against the BAND, the
    /// folded one against its preview view, which is the ATOM's frame, i.e. the band inset by the
    /// quote's interior padding. So the glyph dropped by exactly that padding on every fold.
    ///
    /// Compared in the ENGINE's coordinates, because that is the space the two views are hosted in
    /// and the only one in which "the same place" means anything: the folded glyph lives inside the
    /// preview view, whose own origin is the thing that differed.
    func test_theGlyphDoesNotMoveWhenTheQuoteIsToggled() {
        let body = String(repeating: "a quote long enough to be worth folding ", count: 4)
        load([quote("q", [para("a", body)])])
        guard let openGlyph = editor.quoteCollapseGlyphViews[BlockID("q")]?.frame else {
            teardownWindow(); return XCTFail("an open collapsible quote must show a collapse glyph")
        }
        // The two states' bands hug different things, and since 2026-09-16 that is worth one baseline
        // drop. OPEN, the band hugs the quote's 15pt child, which the lift raises onto V2's baseline
        // by its own drop (0.0996). FOLDED, it hugs an ATOM, whose line TextKit inflates to the
        // attachment — so the lift excludes it and it does not move. The glyph follows the band.
        //
        // Derived rather than a magic tolerance, and still two orders of magnitude tighter than the
        // defect this case exists for: the glyph used to drop by the quote's whole interior padding,
        // 8pt, which this would still catch.
        let bandDrop = editor.currentRoles.indices.map { editor.v2BaselineDrop(atRole: $0) }.max() ?? 0
        XCTAssertLessThan(bandDrop, 0.5, "a drop this large would mean the fixture is not 15pt text")
        teardownWindow()

        load([quote("q", [para("a", body)], collapsed: true)])
        defer { teardownWindow() }
        guard let preview = editor.collapsedQuoteViews[BlockID("q")] else {
            return XCTFail("no preview view")
        }
        let foldedGlyph = preview.convert(preview.glyphFrameForTesting, to: editor.engine)
        XCTAssertEqual(foldedGlyph.minX, openGlyph.minX, accuracy: 0.01,
                       "the glyph is in the band's trailing-top corner in BOTH states")
        XCTAssertEqual(foldedGlyph.minY, openGlyph.minY, accuracy: bandDrop + 0.01,
                       "it dropped by the quote's interior padding before this")
        XCTAssertEqual(foldedGlyph.size.width, openGlyph.size.width, accuracy: 0.01)
        XCTAssertEqual(foldedGlyph.size.height, openGlyph.size.height, accuracy: 0.01)
    }

    func test_tappingTheExpandGlyphOpensTheQuote() {
        load([quote("q", [para("a", "one")], collapsed: true)])
        defer { teardownWindow() }
        editor.collapsedQuoteViews[BlockID("q")]?.simulateGlyphTapForTesting()
        guard case let .blockQuote(read) = editor.document.blocks[0] else {
            return XCTFail("not a quote")
        }
        XCTAssertFalse(read.collapsed)
    }

    /// The preview is the ATOM's own string, never rebuilt beside it — that is what stops the
    /// measured height and the drawn text from disagreeing about what is on screen.
    func test_thePreviewViewDrawsTheAtomsOwnString() {
        load([quote("q", [para("a", "one"), para("b", "two")], collapsed: true)])
        defer { teardownWindow() }
        guard let attachment = editor.collapsedQuoteAttachment(atRoleAt: 0) else {
            return XCTFail("no attachment on the atom")
        }
        XCTAssertEqual(attachment.previewText.string, "one two")
    }

    // MARK: - The collapse glyph on an OPEN quote (R7-collapse §4.4)

    private func longBody() -> [Block] { [para("a", String(repeating: "wordy ", count: 60))] }

    func test_aShortQuoteShowsNoCollapseGlyph() {
        load([quote("q", [para("a", "one")])])
        defer { teardownWindow() }
        XCTAssertNil(editor.quoteCollapseGlyphViews[BlockID("q")],
                     "collapsing something no longer than its own preview is pure noise")
    }

    func test_aQuoteTallerThanItsPreviewShowsTheCollapseGlyph() {
        load([quote("q", longBody())])
        defer { teardownWindow() }
        XCTAssertNotNil(editor.quoteCollapseGlyphViews[BlockID("q")])
    }

    func test_theCollapseGlyphSitsInTheBandsTrailingTopCorner() {
        load([quote("q", longBody())])
        defer { teardownWindow() }
        guard let band = editor.containerDecorationViews[BlockID("q")]?.frame,
              let glyph = editor.quoteCollapseGlyphViews[BlockID("q")]?.frame else {
            return XCTFail("no band or glyph")
        }
        let side = CollapsedQuoteGeometry.glyphSize
        let inset = CollapsedQuoteGeometry.glyphCornerInset
        XCTAssertEqual(glyph, CGRect(x: band.maxX - inset - side, y: band.minY + inset,
                                     width: side, height: side))
    }

    /// The two glyphs never coexist: a folded quote's belongs to its preview view.
    func test_aFoldedQuoteShowsNoCollapseGlyph() {
        load([quote("q", longBody(), collapsed: true)])
        defer { teardownWindow() }
        XCTAssertNil(editor.quoteCollapseGlyphViews[BlockID("q")])
    }

    /// The cull is the reason this case exists. A folded quote still draws a BAND, so its id stays
    /// in the decoration pass's own `live` set — culling glyphs against that set would leave the
    /// collapse glyph on screen after the fold, floating over its own preview.
    func test_foldingATallQuoteRemovesItsCollapseGlyph() {
        load([quote("q", longBody())])
        defer { teardownWindow() }
        XCTAssertNotNil(editor.quoteCollapseGlyphViews[BlockID("q")], "precondition: tall, so shown")
        editor.toggleQuoteCollapsed(id: BlockID("q"))
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        XCTAssertNil(editor.quoteCollapseGlyphViews[BlockID("q")],
                     "the band survives the fold; the glyph must not")
    }

    /// The details chevron's recorded trap: measured against the INFLATED target, the refusal
    /// swallows taps on text beside the glyph. Measured against its own box, a touch in the slop
    /// both toggles and places a caret, which is the harmless direction.
    func test_theEngineRefusesCaretPlacementOnlyInsideTheGlyphsOwnBox() {
        load([quote("q", longBody())])
        defer { teardownWindow() }
        guard let glyph = editor.quoteCollapseGlyphViews[BlockID("q")]?.frame else {
            return XCTFail("no glyph")
        }
        XCTAssertFalse(editor.textInteractionMayBegin(at: CGPoint(x: glyph.midX, y: glyph.midY)))
        XCTAssertTrue(editor.textInteractionMayBegin(at: CGPoint(x: glyph.minX - 8, y: glyph.midY)),
                      "8pt outside the box is inside the 12pt slop and must still place a caret")
    }

    /// The band must sit the same distance below the block above it in BOTH states.
    ///
    /// A leaf container's interior has to be declared TWICE — once in `EngineBlockSpacing.layOut`,
    /// which reserves it in the LAYOUT, and once in `leafInteriorPadding`, which is the decoration
    /// pass's mirror of the same numbers. Declared only in the second, the band is drawn 8pt above
    /// the atom while the rhythm reserves nothing for it, so a folded quote sits 8pt closer to what
    /// precedes it than an open one and its background reads as a different shape. Reported from the
    /// device 2026-09-15 as "expanded and collapsed display the background differently; the text
    /// origin is correct" — which is exactly the signature, since the text is 8pt inside the band in
    /// both states.
    func test_theBandSitsTheSameDistanceBelowThePrecedingBlockInBothStates() {
        func gapAboveBand(collapsed: Bool) -> CGFloat {
            load([para("before", "before"), quote("q", [para("a", "one line")], collapsed: collapsed)])
            defer { teardownWindow() }
            guard let band = editor.containerDecorationViews[BlockID("q")]?.frame,
                  let above = editor.currentRoles.firstIndex(where: { $0.blockID == BlockID("before") })
            else {
                XCTFail("no band or preceding block"); return .nan
            }
            return band.minY - editor.engine.id_frameForBlock(at: UInt(above)).maxY
        }
        let open = gapAboveBand(collapsed: false)
        let folded = gapAboveBand(collapsed: true)
        XCTAssertEqual(folded, open, accuracy: 0.6,
                       "folding must not move the quote closer to the block above it")
    }

    func test_aGlyphThatOutlivesItsQuoteIsReportedAsAShortfall() {
        load([quote("q", longBody())])
        defer { teardownWindow() }
        XCTAssertEqual(editor.derivedViewShortfall(), [], "precondition: complete after a layout")
        editor.quoteCollapseGlyphViews[BlockID("ghost")] = InflatedTouchGlyphView()
        XCTAssertTrue(editor.derivedViewShortfall().contains { $0.contains("collapse glyph") },
                      "got \(editor.derivedViewShortfall())")
    }
}
