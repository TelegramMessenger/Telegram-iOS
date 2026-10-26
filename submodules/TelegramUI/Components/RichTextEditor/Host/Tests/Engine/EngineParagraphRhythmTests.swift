import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// The engine stacks paragraphs on the RENDERER's rhythm, not on its own line boxes.
///
/// Measured from the screen — the caret's own top, which is the line box the reader sees — against
/// V2's arithmetic for the same document, because the two disagreed for months without anyone
/// noticing: V2's item reserves only the DESCENDER below a paragraph's last line, while the engine
/// pins every line box to the full pitch, so each block stood `pitch - ceil(ascender + |descender|)`
/// too tall and every block below it was pushed down by that much.
///
/// It stayed invisible because at the old body factor (0.9) the pitch was 22 and V2's item-plus-gap
/// was 22 as well — the error and the rhythm happened to be equal. Raising body line spacing a point
/// (0.9 → 0.95) split them and the drift showed up on K3 as "the spacing between body paragraphs is
/// 1pt larger than it should be" (2026-09-15). It was 2: one from the change, one that had always
/// been there.
///
/// The numbers are not written here as constants. Every expectation is V2's own formula over the
/// same metrics, so a future metrics change moves the test and the editor together — which is the
/// whole point of `RichTextRenderMetrics` being one definition.
@available(iOS 18.4, *)
final class EngineParagraphRhythmTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!

    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window.addSubview(editor)
        window.makeKeyAndVisible()
    }

    override func tearDown() {
        window.isHidden = true
        window = nil
        editor = nil
        super.tearDown()
    }

    /// A custom emoji at a paragraph's END must not make the BLOCK taller.
    ///
    /// Reported from a device as "inserting a custom emoji makes that line taller". The LINE is not
    /// — it is pinned, and stays 23 at body and 30 at H1 either way — but the BLOCK was, because
    /// `trailingLineBoxOverhang` refused to give back a line box's empty band whenever the last line
    /// carried ANY attachment. That rule is right for a media atom or a button row, whose line
    /// TextKit inflates to the attachment; an emoji reserves exactly the font's own box and inflates
    /// nothing, so the band is still there and still has to come out of the rhythm.
    ///
    /// Measured through `height(forWidth:)` — the COMPOSER's own question — and not through the
    /// block frame, because the block frame is the half that never moved: asserting on it alone is
    /// what let this sit unnoticed. Both are asserted here so the pair states the whole invariant.
    ///
    /// H1 is included deliberately: its boost is ZERO, so it pins the defect as the overhang rule
    /// rather than anything about how large an emoji is drawn.
    func test_aTrailingCustomEmojiDoesNotGrowTheBlock() {
        var attributes = CharacterAttributes()
        attributes.emoji = EmojiRef(id: "e1", instanceID: "i1")
        for style in [ParagraphStyleName.body, .heading1] {
            editor.document = Document(blocks: [.paragraph(ParagraphBlock(
                id: BlockID("p"), style: style, runs: [TextRun(text: "Hi")]))])
            editor.setNeedsLayout(); editor.layoutIfNeeded()
            let plainHeight = editor.height(forWidth: 320)
            let plainLine = editor.engine.id_frameForBlock(at: 0).height

            editor.document = Document(blocks: [.paragraph(ParagraphBlock(
                id: BlockID("p"), style: style,
                runs: [TextRun(text: "Hi"),
                       TextRun(text: "\u{FFFC}", attributes: attributes)]))])
            editor.setNeedsLayout(); editor.layoutIfNeeded()
            let emojiHeight = editor.height(forWidth: 320)
            let emojiLine = editor.engine.id_frameForBlock(at: 0).height

            XCTAssertEqual(emojiLine, plainLine, accuracy: 0.01,
                           "\(style): the LINE BOX is pinned and never moved")
            XCTAssertEqual(emojiHeight, plainHeight, accuracy: 0.01,
                           "\(style): the BLOCK must not grow either — the emoji reserves the "
                           + "font's own box, so the line's empty band is still there to give back")
        }
    }

    /// The same rule for an inline FORMULA and an inline BUTTON: give the line box's empty band back
    /// whenever the attachment fits the pinned line, and only then.
    ///
    /// Fit is per-SIDE, which is the whole reason this is measured rather than assumed. The pin
    /// bottom-aligns the line, so an attachment SHORTER than the box still inflates it by overhanging
    /// the baseline: at body a 22pt formula grows the line 0.2994 and a 19.9pt pill grows it 0.5176,
    /// both against a 23pt box. So "sufficiently small" is not a height comparison, and a height
    /// comparison would hand back a band that is no longer there.
    private func rhythmProbe(_ runs: [TextRun], formulaHeight: CGFloat) -> (line: CGFloat, block: CGFloat) {
        editor.registerFormulaRenderer { _ in
            let size = CGSize(width: 20, height: formulaHeight)
            return RichTextFormulaRenderResult(
                image: UIGraphicsImageRenderer(size: size).image { _ in },
                size: size, ascent: formulaHeight * 0.8, descent: formulaHeight * 0.2)
        }
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p"), runs: runs))])
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        return (editor.engine.id_frameForBlock(at: 0).height, editor.height(forWidth: 320))
    }

    func test_aTrailingInlineFormulaThatFitsTheLineDoesNotGrowTheBlock() {
        var formula = CharacterAttributes(); formula.formula = "x"
        let plain = rhythmProbe([TextRun(text: "Hi")], formulaHeight: 14)
        let small = rhythmProbe([TextRun(text: "Hi"), TextRun(text: "\u{FFFC}", attributes: formula)],
                                formulaHeight: 14)
        XCTAssertEqual(small.line, plain.line, accuracy: 0.01,
                       "a 14pt formula fits the 23pt box on both sides — the line is untouched")
        XCTAssertEqual(small.block, plain.block, accuracy: 0.01,
                       "so the band below it is still there and must come out of the rhythm")
    }

    /// The other side of the rule, and the reason it is not simply "always give it back": a formula
    /// that really does inflate the line has no band left to hand over.
    func test_aTrailingInlineFormulaThatInflatesTheLineKeepsItsBand() {
        var formula = CharacterAttributes(); formula.formula = "x"
        let plain = rhythmProbe([TextRun(text: "Hi")], formulaHeight: 40)
        let tall = rhythmProbe([TextRun(text: "Hi"), TextRun(text: "\u{FFFC}", attributes: formula)],
                               formulaHeight: 40)
        XCTAssertGreaterThan(tall.line, plain.line + 1,
                             "a 40pt formula genuinely inflates the line box")
        XCTAssertGreaterThan(tall.block, plain.block,
                             "and the block grows with it — there is no empty band to reclaim")
    }

    /// An inline BUTTON pill takes the same rule and, at today's pill metrics, does not qualify: it
    /// is SHORTER than the line box (19.9 against 23) and still overhangs the baseline by ~0.52, so
    /// the line really is taller and the bubble's own pill does the same thing. Pinned so that a
    /// future pill that does fit picks the band up automatically, and so that "the button case is a
    /// no-op" is a recorded measurement rather than an oversight.
    func test_aTrailingInlineButtonInflatesTheLineSoItKeepsItsBand() {
        var button = CharacterAttributes()
        button.button = ButtonRef(label: [TextRun(text: "Go")], action: .url("https://t.me"))
        let plain = rhythmProbe([TextRun(text: "Hi")], formulaHeight: 14)
        let pill = rhythmProbe([TextRun(text: "Hi"), TextRun(text: "\u{FFFC}", attributes: button)],
                               formulaHeight: 14)
        XCTAssertGreaterThan(pill.line, plain.line,
                             "the pill overhangs the baseline, so the line is not pinned any more")
        // The block grows by MORE than the line did (measured 3.0 against 0.52), and that is right
        // rather than the defect this rung fixed: the pill's ink reaches the line's bottom edge, so
        // the empty band is genuinely gone and there is nothing left to hand back. The emoji case is
        // the contrast — there the line does not move at all and the band is untouched.
        XCTAssertGreaterThan(pill.block, plain.block,
                             "with no empty band left, the block grows with its line")
    }

    private func para(_ id: String, _ text: String) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), runs: [TextRun(text: text)]))
    }

    /// The top of the line box holding the character at `offset` on the engine's canonical axis.
    private func lineTop(at offset: Int, file: StaticString = #filePath, line: UInt = #line) -> CGFloat {
        guard let position = editor.engine.position(from: editor.engine.beginningOfDocument, offset: offset) else {
            XCTFail("offset \(offset) is not a position in this document", file: file, line: line)
            return .nan
        }
        return editor.engine.caretRect(for: position).minY
    }

    private var bodyFont: UIFont { editor.bridge.styleSheet.font(for: .body, attributes: .plain) }
    private var bodyFactor: CGFloat { editor.bridge.styleSheet.metrics.spec(for: .body).lineSpacingFactor }

    /// V2's advance from one single-line paragraph's top to the next one's: the item it lays out,
    /// plus the flat 1pt the renderer puts between two paragraphs ("two paragraphs are already held
    /// apart by their own line boxes" — `richTextSpacingBetweenBlocks`).
    private var expectedParagraphAdvance: CGFloat {
        RichTextRenderMetrics.textHeight(bodyFont, factor: bodyFactor, lineCount: 1)
            + richTextSpacingBetweenBlocks(upper: .paragraph, lower: .paragraph,
                                           kind: .topLevel, metrics: editor.bridge.styleSheet.metrics)
    }

    func test_twoBodyParagraphsAdvanceByTheRenderersRhythm() {
        editor.document = Document(blocks: [para("p0", "one"), para("p1", "two"), para("p2", "three")])
        editor.layoutIfNeeded()

        // "one\ntwo\nthree" — the canonical axis counts the separators.
        XCTAssertEqual(lineTop(at: 4) - lineTop(at: 0), expectedParagraphAdvance, accuracy: 0.01)
        XCTAssertEqual(lineTop(at: 8) - lineTop(at: 4), expectedParagraphAdvance, accuracy: 0.01)
    }

    /// The counterpart, and the reason the rhythm is not simply "one pitch": WITHIN a paragraph the
    /// lines do advance by the full pitch, which is what the line-spacing setting moves. A fix that
    /// tightened both would have taken the requested point back out again.
    func test_linesWithinAParagraphStillAdvanceByTheFullPitch() {
        let wrapping = String(repeating: "wrap ", count: 40)
        editor.document = Document(blocks: [para("p0", wrapping)])
        editor.layoutIfNeeded()

        let firstLine = lineTop(at: 0)
        var secondLine = firstLine
        var offset = 1
        while offset < wrapping.utf16.count, secondLine <= firstLine + 0.5 {
            secondLine = lineTop(at: offset)
            offset += 1
        }
        XCTAssertGreaterThan(secondLine, firstLine, "the text did not wrap; the probe measured nothing")
        XCTAssertEqual(secondLine - firstLine,
                       RichTextRenderMetrics.linePitch(bodyFont, factor: bodyFactor), accuracy: 0.01)
    }

    /// The overhang is charged ONCE per boundary. A quote's last child has its container's bottom
    /// interior below it AND the rhythm gap to whatever follows the quote; taking the overhang out
    /// of both would pull the next block into the quote's text.
    ///
    /// **Driven under `.off`, because that is the arm the overhang mechanism belongs to** — see the
    /// case below for why `.safe` leaves it nothing to do. Pinning the double charge still matters:
    /// `.off` is the supported rollback, and this is the rule that would be wrong under it.
    func test_theOverhangIsTakenOutOnceAtAContainerBoundary() {
        let original = EngineDocumentBridge.v2BaselinePlacement
        let originalShift = EngineBlockSpacing.v2BaselineShiftEnabled
        defer {
            EngineDocumentBridge.v2BaselinePlacement = original
            EngineBlockSpacing.v2BaselineShiftEnabled = originalShift
        }
        EngineDocumentBridge.v2BaselinePlacement = .off
        // The lift writes the SAME insets, so leaving it on would mean this case could no longer
        // tell a double-charged overhang from a lifted block. One mechanism per case.
        EngineBlockSpacing.v2BaselineShiftEnabled = false

        let quote = Block.blockQuote(BlockQuote(id: BlockID("q"), children: [para("c0", "inside")], author: []))
        editor.document = Document(blocks: [para("p0", "above"), quote, para("p1", "below")])
        editor.layoutIfNeeded()

        let insets = EngineBlockSpacing.blockLayout(for: editor.currentRoles,
                                                    styleSheet: editor.bridge.styleSheet,
                                                    quoteStyle: editor.deferredConfiguration.quoteStyle,
                                                    pullQuoteStyle: editor.deferredConfiguration.pullQuoteStyle,
                                                    lineAttributes: editor.spacingLineAttributes()).insets
        let overhang = EngineBlockSpacing.trailingLineBoxOverhang(
            of: editor.spacingLineAttributes()(editor.currentRoles.count - 1))
        XCTAssertGreaterThan(overhang, 0, "a body line's box must exceed the renderer's item for this to mean anything")

        // Every inset is finite and no single boundary went more than one overhang negative — the
        // shape a double charge takes.
        for (index, inset) in insets.enumerated() {
            XCTAssertGreaterThanOrEqual(inset.top, -overhang, "role \(index) top")
            XCTAssertGreaterThanOrEqual(inset.bottom, -overhang, "role \(index) bottom")
        }
    }

    // MARK: - What the public measurement hands out

    /// **Every size this view hands an outside consumer is a whole number of points.**
    ///
    /// Callers stack what they are given against a running origin — the composer sizes its field
    /// from it, the article editor its scroll content — so one fractional answer puts everything
    /// downstream on a fractional origin. That is the same rule the legacy path states at
    /// `layoutTextItem` ("the `ceil` is load-bearing") and reaches by ceiling every block; the engine
    /// reaches it at the boundary instead, because its block canvases are DELIBERATELY fractional
    /// since the baseline lift.
    ///
    /// Two halves, and only the second was ever broken:
    ///
    /// - The MEASURED height is integral because `IDBlockTextView` ceils its own `contentSize`
    ///   (`ceil(MAX(bounds, documentContentSize + insets))`, two sites). Measured over paragraphs,
    ///   every heading level, a quote, a code block, a details, a table, a table in a quote, and two
    ///   aspect-ratio images: all whole. The explicit `ceil` is still ours to apply — that one is
    ///   VENDORED upstream code, and a public contract of this package should not rest on an
    ///   incidental detail of it.
    /// - The FLOOR is a host value returned verbatim, so a fractional `minimumContentHeight` reached
    ///   the host unchanged. That is the half this case was written against and watched fail.
    func test_everyHeightThisViewHandsOutIsIntegral() {
        func cell(_ id: String, _ text: String) -> Cell {
            Cell(id: BlockID(id), blocks: [para(id + "b", text)])
        }
        let grid = TableBlock(id: BlockID("t"),
                              columns: [ColumnSpec(width: 100), ColumnSpec(width: 100)],
                              rows: [Row(id: BlockID("r0"), cells: [cell("c0", "a"), cell("c1", "b")]),
                                     Row(id: BlockID("r1"), cells: [cell("c2", "c"), cell("c3", "d")])])
        let fixtures: [(String, [Block])] = [
            ("three body paragraphs", [para("p0", "a"), para("p1", "b"), para("p2", "c")]),
            // Mixed first/last styles: the lift's per-role drops differ at the two document edges
            // (0.9062 against 0.7129), so this is the shape that would leak if they did not cancel.
            ("heading5 then body", [
                .paragraph(ParagraphBlock(id: BlockID("h"), style: .heading5, runs: [TextRun(text: "H")])),
                para("p1", "b")]),
            ("every style", ParagraphStyleName.allCases.enumerated().map { index, style in
                .paragraph(ParagraphBlock(id: BlockID("s\(index)"), style: style, runs: [TextRun(text: "S")]))
            }),
            ("a quote", [.blockQuote(BlockQuote(id: BlockID("q"), children: [para("c", "in")], author: []))]),
            ("a code block", [.code(CodeBlock(id: BlockID("k"), language: "swift", runs: [TextRun(text: "x")]))]),
            ("a details", [.details(DetailsBlock(id: BlockID("d"), title: [TextRun(text: "T")],
                                                 children: [para("db", "body")], expanded: true))]),
            ("a table", [para("p0", "above"), .table(grid), para("p1", "below")]),
            ("a table in a quote", [.blockQuote(BlockQuote(id: BlockID("q"), children: [.table(grid)], author: []))]),
            // Aspect-ratio derived, the likeliest fractional source: 1000x543 on this column is not a
            // whole number of points however the slot is solved.
            ("an image", [para("p0", "above"),
                          .media(MediaBlock(id: BlockID("m"), mediaID: "x", kind: .image,
                                            naturalSize: Size2D(width: 1000, height: 543))),
                          para("p1", "below")]),
            ("an odd image in a quote", [.blockQuote(BlockQuote(id: BlockID("q"), children: [
                .media(MediaBlock(id: BlockID("m"), mediaID: "y", kind: .image,
                                  naturalSize: Size2D(width: 997, height: 331)))], author: []))]),
        ]
        for (name, blocks) in fixtures {
            editor.document = Document(blocks: blocks)
            editor.setNeedsLayout(); editor.layoutIfNeeded()
            let measured = editor.height(forWidth: 320)
            XCTAssertGreaterThan(measured, 0, "\(name): the probe measured nothing")
            XCTAssertEqual(measured, ceil(measured), accuracy: 0.0001, "\(name): height(forWidth:)")
        }

        // The floor WINS here — a short document under a tall, fractional minimum — which is the only
        // arrangement in which it reaches the caller at all. With the floor below the content the max
        // picks the measured height and this would pass whatever `update` did with it.
        editor.document = Document(blocks: [para("p0", "short")])
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        editor.minimumContentHeight = 200.5
        let updated = editor.update(size: CGSize(width: 320, height: 400), insets: .zero,
                                    contentMargins: .zero, scrollIndicatorInsets: nil)
        XCTAssertGreaterThanOrEqual(updated, 200.5, "the floor must still be respected")
        XCTAssertEqual(updated, ceil(updated), accuracy: 0.0001,
                       "a fractional floor must not reach the host verbatim")
    }

    // MARK: - Lifting the text onto V2's baseline

    private func mixedStyleDocument() -> Document {
        Document(blocks: [
            para("p0", "above"),
            .paragraph(ParagraphBlock(id: BlockID("h"), style: .heading5, runs: [TextRun(text: "Head")])),
            para("p1", "below"),
        ])
    }

    private func currentInsets() -> [UIEdgeInsets] {
        EngineBlockSpacing.blockLayout(for: editor.currentRoles,
                                       styleSheet: editor.bridge.styleSheet,
                                       quoteStyle: editor.deferredConfiguration.quoteStyle,
                                       pullQuoteStyle: editor.deferredConfiguration.pullQuoteStyle,
                                       lineAttributes: editor.spacingLineAttributes()).insets
    }

    /// **Each block's text is lifted onto V2's baseline by taking its own drop out of its top inset
    /// and putting the same amount back below it.**
    ///
    /// `.safe` leaves the baseline `pinnedLineHeight - fontBox` low — 0.7129 at 17pt body — because
    /// the box is rounded UP and TextKit bottom-aligns inside it. That is a whole-block offset, so it
    /// comes back as a net-zero inset pair rather than by making the box fractional: block heights
    /// stay integral, every later origin stays where it was, and only the glyphs inside each box move.
    ///
    /// **A/B against the shift's own control**, so nothing here re-derives the number it is checking.
    /// A no-op implementation fails this by construction: `shifted == unshifted` while every `drop`
    /// is positive.
    ///
    /// The fixture MIXES styles deliberately — body 17pt drops 0.7129 and heading5 16pt drops 0.9062 —
    /// and the last assertion refuses a fixture that does not, because a single-style document cannot
    /// tell a per-role correction from a constant one. That is the whole question this answers.
    func test_eachBlocksTextIsLiftedOntoV2sBaselineByItsOwnDrop() {
        editor.document = mixedStyleDocument()
        editor.setNeedsLayout(); editor.layoutIfNeeded()

        let shifted = currentInsets()
        let original = EngineBlockSpacing.v2BaselineShiftEnabled
        defer { EngineBlockSpacing.v2BaselineShiftEnabled = original }
        EngineBlockSpacing.v2BaselineShiftEnabled = false
        let unshifted = currentInsets()

        let attributes = editor.spacingLineAttributes()
        var distinctExactDrops: Set<Int> = []
        var appliedAny = false
        for index in editor.currentRoles.indices {
            let drop = EngineBlockSpacing.v2BaselineDrop(of: attributes(index))
            if drop > 0 { appliedAny = true }
            // **The per-role question is now asked of the EXACT drop, not the applied one.** Since
            // the applied drop is snapped to a whole point (see `snappedToWholePoints`), the styles
            // in this fixture mostly land on the same 1.0 — body's exact 0.7129 and heading5's
            // 0.9062 both do — so counting APPLIED values can no longer tell a per-role correction
            // from a constant. What still can: the exact residuals differ per role, and each applied
            // value is the snap of its OWN residual rather than of some shared one.
            let font = EngineBlockSpacing.pinnedBoxFont(of: attributes(index))
            let paragraph = attributes(index)[.paragraphStyle] as? NSParagraphStyle
            let exact = max(0, (paragraph?.maximumLineHeight ?? 0) - ((font?.ascender ?? 0) - (font?.descender ?? 0)))
            distinctExactDrops.insert(Int((exact * 10_000).rounded()))
            XCTAssertEqual(drop, EngineBlockSpacing.snappedToWholePoints(exact), accuracy: 0.0001,
                           "role \(index): the applied drop must be the snap of this role's OWN residual")

            XCTAssertEqual(shifted[index].top, unshifted[index].top - drop, accuracy: 0.0001,
                           "role \(index): the text must come UP by its own drop")
            XCTAssertEqual(shifted[index].bottom, unshifted[index].bottom + drop, accuracy: 0.0001,
                           "role \(index): and the same amount must go back below it")
            XCTAssertEqual(shifted[index].top + shifted[index].bottom,
                           unshifted[index].top + unshifted[index].bottom, accuracy: 0.0001,
                           "role \(index): the transform must be NET ZERO or the rhythm moves")
        }
        XCTAssertTrue(appliedAny, "the fixture must exercise the shift at all")
        XCTAssertGreaterThan(distinctExactDrops.count, 1,
                             "the fixture must mix styles, or this cannot tell a per-role "
                             + "correction from a constant one")
    }

    /// **The rhythm is what must not move**, and the document's own height is the reading that says
    /// so — the same question the composer asks through `height(forWidth:)`, and the one that caught
    /// the 2pt block drift in the first place. Net zero per block means this is identical either way.
    func test_theBaselineShiftDoesNotChangeTheDocumentsHeight() {
        editor.document = mixedStyleDocument()
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        let shiftedHeight = editor.height(forWidth: 320)

        let original = EngineBlockSpacing.v2BaselineShiftEnabled
        defer { EngineBlockSpacing.v2BaselineShiftEnabled = original }
        EngineBlockSpacing.v2BaselineShiftEnabled = false
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        let unshiftedHeight = editor.height(forWidth: 320)

        XCTAssertGreaterThan(shiftedHeight, 0, "the probe measured nothing")
        XCTAssertEqual(shiftedHeight, unshiftedHeight, accuracy: 0.01,
                       "the shift must be invisible to the document's height")
    }

    /// **`.safe` SUBSUMES the overhang, and this pins that rather than leaving it an accident.**
    ///
    /// The two are the same correction applied in different places. The overhang is
    /// `pitch - ceil(ascender + |descender|)` — one band of empty space below a block, given back out
    /// of the rhythm beneath it. `v2BaselinePlacedStyle` re-pins the box to `ceil(ascender +
    /// |descender|)` and puts exactly that band into `lineSpacing` instead, so a block of `n` lines
    /// loses the band `n` times and gains it `n - 1` times: net one band, the same one, taken where
    /// it belongs — BETWEEN the lines rather than below the last of them, and so never above the
    /// first, which is the defect the placement exists for.
    ///
    /// Consequence: `trailingLineBoxOverhang` answers 0 for every stacked role the bridge renders,
    /// and the correction it used to make is now made by the paragraph style. The rhythm is
    /// unchanged — the case above and the block-frame cases either side of it are what say so.
    func test_theSafePlacementLeavesNoTrailingOverhangToGiveBack() {
        XCTAssertEqual(EngineDocumentBridge.v2BaselinePlacement, .safe, "this pins the shipping arm")

        let quote = Block.blockQuote(BlockQuote(id: BlockID("q"), children: [para("c0", "inside")],
                                                author: [TextRun(text: "who")]))
        editor.document = Document(blocks: [
            para("p0", "above"),
            quote,
            .code(CodeBlock(id: BlockID("k"), language: "swift", runs: [TextRun(text: "let x = 1")])),
            para("p1", "below"),
        ])
        editor.layoutIfNeeded()

        // Every pinned role, whatever pitch it carries — body, a 15pt quote child, its author line,
        // a code line and its language line are five different boxes and five different fonts.
        let attributes = editor.spacingLineAttributes()
        for index in editor.currentRoles.indices where editor.currentRoles[index].owningTable == nil {
            XCTAssertEqual(EngineBlockSpacing.trailingLineBoxOverhang(of: attributes(index)), 0,
                           accuracy: 0.001, "role \(index) still has a band to give back")
        }
    }

    /// A media atom is one attachment character whose line TextKit inflates to the attachment, so it
    /// has no pinned-box overhang to give back. Reading the rendered attributes is what makes that
    /// fall out rather than needing a rule per shape.
    func test_anAttachmentLineOffersNoOverhang() {
        XCTAssertEqual(EngineBlockSpacing.trailingLineBoxOverhang(of: [:]), 0)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.maximumLineHeight = 40
        XCTAssertEqual(EngineBlockSpacing.trailingLineBoxOverhang(of: [
            .font: UIFont.systemFont(ofSize: 17),
            .paragraphStyle: paragraphStyle,
            .attachment: NSTextAttachment(),
        ]), 0)
    }
}
