import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// R7-details §5: a details draws no band — one hairline at the bottom of its span in BOTH states —
/// a gutter chevron, and a title whose glyphs alone clear that chevron.
@available(iOS 18.4, *)
final class EngineDetailsGeometryTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!
    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window.addSubview(editor); window.makeKeyAndVisible()
    }
    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }

    private func para(_ id: String, _ text: String) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), runs: text.isEmpty ? [] : [TextRun(text: text)]))
    }
    private func details(_ id: String, title: String, _ children: [Block], expanded: Bool = true) -> Block {
        .details(DetailsBlock(id: BlockID(id), title: title.isEmpty ? [] : [TextRun(text: title)],
                              children: children, expanded: expanded))
    }
    private func table(_ id: String) -> Block {
        .table(TableBlock(id: BlockID(id), columns: [ColumnSpec(width: 100), ColumnSpec(width: 100)],
                          rows: [Row(id: BlockID("\(id)r"),
                                     cells: [Cell(id: BlockID("\(id)c0"), blocks: [para("\(id)p0", "")]),
                                             Cell(id: BlockID("\(id)c1"), blocks: [para("\(id)p1", "")])])]))
    }
    private func load(_ blocks: [Block]) {
        editor.document = Document(blocks: blocks)
        editor.setNeedsLayout(); editor.layoutIfNeeded()
    }
    private func separator(_ id: String) -> CGRect? { editor.containerDecorationViews[BlockID(id)]?.frame }
    private func headIndent(_ index: Int) -> CGFloat {
        (editor.engine.attributedBlocks[index].attribute(.paragraphStyle, at: 0, effectiveRange: nil)
            as? NSParagraphStyle)?.headIndent ?? -1
    }

    // MARK: §5.1 the separator

    func test_aDetailsDrawsAHairlineAtTheBottomOfItsSpanInBothStates() {
        load([details("d", title: "T", [para("a", "one")])])
        guard let expanded = separator("d") else { return XCTFail("no separator when expanded") }
        XCTAssertEqual(expanded.height, 0.5, accuracy: 0.01, "a hairline, not a band")
        let lastBlock = editor.engine.id_frameForBlock(at: 1)
        XCTAssertGreaterThanOrEqual(expanded.minY, lastBlock.maxY, "at the BOTTOM of the span")

        load([details("d", title: "T", [para("a", "one")], expanded: false)])
        guard let folded = separator("d") else { return XCTFail("no separator when folded") }
        XCTAssertEqual(folded.height, 0.5, accuracy: 0.01, "collapsed, the hairline is the whole ornament")
    }

    /// P2 answered "the union gives the column only BY ACCIDENT" — every ordinary child returns a
    /// full-width text frame, so unioning them happens to produce the column. A table's cells are
    /// PLACED, and a details holding only a table would get a hairline hugging the grid. The width is
    /// pinned to the column at the details' own level instead.
    func test_theSeparatorSpansTheColumnEvenWhenTheOnlyChildIsATable() {
        load([details("d", title: "T", [table("t")])])
        guard let hairline = separator("d") else { return XCTFail("no separator") }
        XCTAssertEqual(hairline.minX, editor.engine.textContainerInset.left, accuracy: 0.5)
        XCTAssertEqual(hairline.width, editor.availableTableWidth, accuracy: 0.5)
    }

    func test_aQuotedDetailsSeparatorTakesTheColumnAtItsOwnLevel() {
        load([.blockQuote(BlockQuote(id: BlockID("q"),
                                     children: [details("d", title: "T", [para("a", "one")])]))])
        guard let hairline = separator("d") else { return XCTFail("no separator") }
        let indent = editor.bridge.styleSheet.quoteIndent
        XCTAssertEqual(hairline.minX, editor.engine.textContainerInset.left + indent, accuracy: 0.5)
        XCTAssertEqual(hairline.width, editor.availableTableWidth - indent, accuracy: 0.5)
    }

    // MARK: §5.2 the insets

    /// The top inset is the SAME in both states, deliberately, so the title and chevron do not move
    /// when folding.
    func test_theTitleDoesNotMoveWhenFolding() {
        load([details("d", title: "T", [para("a", "one")])])
        let expanded = editor.engine.id_frameForBlock(at: 0)
        load([details("d", title: "T", [para("a", "one")], expanded: false)])
        let folded = editor.engine.id_frameForBlock(at: 0)
        XCTAssertEqual(expanded.minY, folded.minY, accuracy: 0.5)
    }

    // MARK: §5.3 the chevron

    func test_theChevronSitsInTheGutterAndRotatesWithState() {
        load([details("d", title: "T", [para("a", "one")])])
        guard let chevron = editor.detailsChevronViews[BlockID("d")] else { return XCTFail("no chevron") }
        XCTAssertEqual(chevron.frame.size, CGSize(width: 18.0, height: 18.0))
        XCTAssertEqual(chevron.frame.minX, editor.engine.textContainerInset.left + 3.0, accuracy: 0.5)
        let title = editor.engine.id_frameForBlock(at: 0)
        XCTAssertEqual(chevron.frame.midY, title.midY, accuracy: 2.0, "centred on the title row")
        let expandedTransform = chevron.transform

        load([details("d", title: "T", [para("a", "one")], expanded: false)])
        guard let folded = editor.detailsChevronViews[BlockID("d")] else { return XCTFail("no chevron when folded") }
        XCTAssertNotEqual(folded.transform, expandedTransform, "…and rotates between the two states")
    }

    /// A nested details' chevron steps in with its content.
    func test_aQuotedDetailsChevronStepsInByTheQuotesIndent() {
        load([.blockQuote(BlockQuote(id: BlockID("q"),
                                     children: [details("d", title: "T", [para("a", "one")])]))])
        guard let chevron = editor.detailsChevronViews[BlockID("d")] else { return XCTFail("no chevron") }
        XCTAssertEqual(chevron.frame.minX,
                       editor.engine.textContainerInset.left + editor.bridge.styleSheet.quoteIndent + 3.0,
                       accuracy: 0.5)
    }

    /// Deepest match wins, so a nested details' chevron is reachable — legacy's rule.
    func test_theDeepestChevronWinsAHitTest() {
        load([details("outer", title: "O", [details("inner", title: "I", [para("a", "one")])])])
        guard let inner = editor.detailsChevronViews[BlockID("inner")] else { return XCTFail("no inner chevron") }
        XCTAssertEqual(editor.detailsChevron(at: CGPoint(x: inner.frame.midX, y: inner.frame.midY)),
                       BlockID("inner"))
    }

    // MARK: §4.2 / P1 — only the title's glyphs clear the chevron

    /// P1 answered COMPOSES: a quoted title indents by the quote's 16 PLUS its own 26, and its body
    /// by the quote's 16 alone.
    func test_onlyTheTitleIsIndentedPastTheChevron() {
        load([details("d", title: "T", [para("a", "one")])])
        // The LITERAL, not `DetailsShape.titleGlyphIndent` — asserting against the constant makes the
        // expectation move with the code and the test cannot fail. (Caught by neutering it: zeroing the
        // constant left this green.)
        XCTAssertEqual(headIndent(0), 26.0, accuracy: 0.5, "the title clears the chevron")
        XCTAssertEqual(headIndent(1), 0.0, accuracy: 0.5, "the body sits flush, NOT aligned with the title")
    }

    func test_aQuotedTitleComposesBothIndents() {
        load([.blockQuote(BlockQuote(id: BlockID("q"),
                                     children: [details("d", title: "T", [para("a", "one")])]))])
        let quote = editor.bridge.styleSheet.quoteIndent
        XCTAssertEqual(headIndent(0), quote + 26.0, accuracy: 0.5, "the quote's indent PLUS the title's own")
        XCTAssertEqual(headIndent(1), quote, accuracy: 0.5, "the body takes the quote's indent only")
    }

    // MARK: the review wave

    /// §8.2 says the chevron IS the interaction, and nothing invoked it: the view was built
    /// `isUserInteractionEnabled = false` with a comment claiming a canvas gesture consulted
    /// `detailsChevron(at:)`, and no such gesture existed. `toggleDetailsExpanded` had no caller
    /// outside XCTest either, so the rung's headline capability was unreachable in the app.
    func test_theChevronIsTappableAndTogglesTheFold() {
        load([details("d", title: "T", [para("a", "one")])])
        guard let chevron = editor.detailsChevronViews[BlockID("d")] else { return XCTFail("no chevron") }
        XCTAssertTrue(chevron.isUserInteractionEnabled, "a chevron that swallows no touch can never be tapped")
        XCTAssertEqual(chevron.gestureRecognizers?.count, 1, "…and it carries its own tap")
        XCTAssertTrue(editor.toggleDetails(atChevronPoint: CGPoint(x: chevron.frame.midX, y: chevron.frame.midY)))
        guard case let .details(read) = editor.document.blocks[0] else { return XCTFail("not a details") }
        XCTAssertFalse(read.expanded, "the tap folded it")
    }

    /// The arbitration stays `detailsChevron(at:)`'s, not the view hierarchy's: overlapping touch
    /// targets are resolved deepest-first however UIKit orders the pool's subviews.
    ///
    /// The frames are moved ON TOP OF EACH OTHER on purpose. Laid out naturally, two nested chevrons
    /// sit ~42pt apart while each target reaches 21pt, so nothing overlaps, `hits` holds one entry,
    /// and the test passes even if the rule returns `hits.keys.first` — which is what the first
    /// version of this case did.
    func test_aTapInOverlappingChevronsTogglesTheDeepestOne() {
        load([details("outer", title: "O", [details("inner", title: "I", [para("a", "one")])])])
        guard let outer = editor.detailsChevronViews[BlockID("outer")],
              let inner = editor.detailsChevronViews[BlockID("inner")] else { return XCTFail("no chevrons") }
        inner.frame = outer.frame
        let point = CGPoint(x: outer.frame.midX, y: outer.frame.midY)
        XCTAssertEqual(editor.detailsChevron(at: point), BlockID("inner"), "both are hit; the deeper wins")
        XCTAssertTrue(editor.toggleDetails(atChevronPoint: point))
        guard case let .details(outerBlock) = editor.document.blocks[0],
              case let .details(innerBlock) = outerBlock.children[0] else { return XCTFail("shape lost") }
        XCTAssertFalse(innerBlock.expanded)
        XCTAssertTrue(outerBlock.expanded, "the outer one is untouched")
    }

    // MARK: §5.2 — the insets are RESERVED, not merely declared

    /// `layOut`'s container branch was gated on `unit.quote`, which is nil for a details, so a
    /// details fell through to a `default: break`: none of its interior reached `blockInsets` and —
    /// worse — `layOut` never recursed into its children at all. The hairline was then drawn 16pt
    /// below the last body block, in space nothing had reserved, overlapping the block after it.
    func test_aDetailsReservesItsOwnInterior() {
        load([details("d", title: "T", [para("a", "one")])])
        let insets = EngineBlockSpacing.blockLayout(for: editor.currentRoles,
                                                    styleSheet: editor.bridge.styleSheet,
                                                    quoteStyle: editor.deferredConfiguration.quoteStyle,
                                                    pullQuoteStyle: editor.deferredConfiguration.pullQuoteStyle,
                                                    grids: [:],
                                                    lineAttributes: editor.spacingLineAttributes()).insets
        // Literals, not `DetailsShape.topInset` — an assertion against the constant the code reads
        // moves with it and cannot fail.
        XCTAssertGreaterThanOrEqual(insets[0].top, 6.0, "the title carries the details' top inset")
        XCTAssertGreaterThanOrEqual(insets[1].bottom, 16.0, "the last body block carries the expanded bottom")
        // The gap a body block hangs below the title, less the TITLE's own trailing line-box
        // overhang: the title's box runs one empty band past its glyphs, and the gap gives it back
        // so the body sits `titleBodyGap` below the TEXT (2026-09-15).
        // Less the BODY's own baseline drop as well: the lift takes that out of its top inset and
        // gives it back below, so the body's canvas top IS V2's item top and the inset reads
        // `titleBodyGap - drop`. The gap to the TEXT is unchanged, which is the invariant (2026-09-16).
        XCTAssertGreaterThanOrEqual(insets[1].top,
                                    14.0 - editor.trailingLineBoxOverhang(atRole: 0)
                                        - editor.v2BaselineDrop(atRole: 1),
                                    "and the body hangs titleBodyGap below the title")
    }

    /// The recursion, which the same gate skipped: a quote INSIDE a details got no interior of its
    /// own, and neither did anything inside that quote.
    func test_aQuoteInsideADetailsStillGetsItsOwnInterior() {
        load([.details(DetailsBlock(id: BlockID("d"), title: [TextRun(text: "T")],
                                    children: [.blockQuote(BlockQuote(id: BlockID("q"),
                                                                      children: [para("a", "one")]))],
                                    expanded: true))])
        let insets = EngineBlockSpacing.blockLayout(for: editor.currentRoles,
                                                    styleSheet: editor.bridge.styleSheet,
                                                    quoteStyle: editor.deferredConfiguration.quoteStyle,
                                                    pullQuoteStyle: editor.deferredConfiguration.pullQuoteStyle,
                                                    grids: [:],
                                                    lineAttributes: editor.spacingLineAttributes()).insets
        XCTAssertGreaterThan(insets[1].top, 14.0, "the quote's own top interior, on top of the title gap")
        // The quote carries an author line, so both the quote's and the details' bottoms land on
        // THAT — the span's last role — not on the paragraph.
        XCTAssertGreaterThan(insets[insets.count - 1].bottom, 16.0, "and its bottom, under the details' own")
    }

    /// §4.2 through the EMPTY-line path: `probeBlock` had no `.detailsTitle` arm, so the probe was
    /// built as a plain paragraph, `lineAttributes` found no role with a matching `secondaryKind`
    /// and returned nothing. A freshly inserted details' empty title got no font and no paragraph
    /// style, so its caret sat under the chevron while the placeholder drew 26pt in.
    func test_anEmptyTitleGetsItsOwnLineAttributes() {
        load([details("d", title: "", [para("a", "one")])])
        let title = editor.currentRoles[0]
        let attributes = editor.bridge.lineAttributes(for: title)
        XCTAssertNotNil(attributes[.font], "an empty title must be measured as a title")
        let style = attributes[.paragraphStyle] as? NSParagraphStyle
        XCTAssertEqual(style?.headIndent ?? -1, 26.0, accuracy: 0.5, "…clearing the chevron, like a filled one")
    }

    /// `bottom` on a PLACED role extends the whole run, so it has to reach every cell of the last
    /// row. A details ending in a table is the one shape that carries the document's trailing gap
    /// through a placed role — deposited on the span's `upperBound` alone it landed on the final cell
    /// while the rest of its row got none, which is the ragged-run shape this file already measured
    /// once as a 24pt cell drift.
    func test_aTrailingDetailsEndingInATableSpreadsItsBottomOverTheLastRow() {
        load([para("p", "hi"), details("d", title: "T", [table("t")])])
        XCTAssertEqual(editor.currentRoles.count, 4, "paragraph, title, two cells")
        let insets = EngineBlockSpacing.blockLayout(for: editor.currentRoles,
                                                    styleSheet: editor.bridge.styleSheet,
                                                    quoteStyle: editor.deferredConfiguration.quoteStyle,
                                                    pullQuoteStyle: editor.deferredConfiguration.pullQuoteStyle,
                                                    grids: [:],
                                                    lineAttributes: editor.spacingLineAttributes()).insets
        XCTAssertGreaterThan(insets[2].bottom, 0.0, "the first cell of the last row carries it")
        XCTAssertEqual(insets[2].bottom, insets[3].bottom, accuracy: 0.01, "and so does every other")
    }
}
