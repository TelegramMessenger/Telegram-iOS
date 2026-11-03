import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// Nesting design §5: bands nest with one quoteIndent per level and sit below their parent's band;
/// spacing stacks each level's interior; placed and hosted views follow the indent.
@available(iOS 18.4, *)
final class EngineNestedQuoteGeometryTests: XCTestCase {
    var window: UIWindow!
    var editor: RichTextEngineEditorView!
    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window.addSubview(editor); window.makeKeyAndVisible()
    }
    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }

    func para(_ id: String, _ text: String) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), runs: text.isEmpty ? [] : [TextRun(text: text)]))
    }
    func quote(_ id: String, _ children: [Block], author: String = "") -> Block {
        .blockQuote(BlockQuote(id: BlockID(id), children: children, author: author.isEmpty ? [] : [TextRun(text: author)]))
    }
    func load(_ blocks: [Block]) { editor.document = Document(blocks: blocks); editor.setNeedsLayout(); editor.layoutIfNeeded() }
    var bands: [ContainerDecorationView] { editor.engine.subviews.compactMap { $0 as? ContainerDecorationView } }
    /// The band whose frame contains the frame of the engine block at `index` and is the NARROWEST such.
    func innermostBand(over index: Int) -> ContainerDecorationView? {
        let frame = editor.engine.id_frameForBlock(at: UInt(index))
        return bands.filter { $0.frame.contains(CGPoint(x: frame.midX, y: frame.midY)) }.min { $0.frame.width < $1.frame.width }
    }
    var indent: CGFloat { editor.bridge.styleSheet.quoteIndent }
    /// How far short of the column a quote's content stops on the RIGHT — legacy's
    /// `BlockQuoteBox`'s `inner = width - leadingInset - trailingInset`, whose trailing half this
    /// editor did not apply until 2026-09-11.
    var trailing: CGFloat { editor.bridge.styleSheet.quoteTrailingInset }

    // MARK: §5.1 bands

    func test_anInnerQuoteBandSitsInsideTheOuterOneAndBelowItInZOrder() {
        load([quote("q", [para("a", "one"), quote("q2", [para("b", "two")])])])
        // Roles: a@1, b@2, q2#author@2, q#author@1 — two bands.
        XCTAssertEqual(bands.count, 2)
        guard let outer = innermostBand(over: 0), let inner = innermostBand(over: 1) else { return XCTFail("no bands") }
        XCTAssertNotEqual(outer, inner)
        XCTAssertEqual(inner.frame.minX - outer.frame.minX, indent, accuracy: 0.5, "one quoteIndent per level")
        XCTAssertEqual(inner.frame.maxX, outer.frame.maxX, accuracy: 0.5)
        XCTAssertTrue(outer.frame.contains(inner.frame), "the outer band covers the inner: \(outer.frame) vs \(inner.frame)")
        let subviews = editor.engine.subviews
        XCTAssertLessThan(subviews.firstIndex(of: outer)!, subviews.firstIndex(of: inner)!, "outer below inner")
        // The inner quote's author line is inside the inner band; the outer's only inside the outer.
        XCTAssertTrue(inner.frame.contains(editor.engine.id_frameForBlock(at: 2).insetBy(dx: indent * 2, dy: 0)))
        XCTAssertFalse(inner.frame.intersects(editor.engine.id_frameForBlock(at: 3)))
    }

    func test_theBandOrderIsRestoredIfAnotherViewIsInsertedBelow() {
        load([quote("q", [quote("q2", [para("b", "two")])])])
        guard let inner = innermostBand(over: 0) else { return XCTFail() }
        editor.engine.insertSubview(inner, at: 0)    // wrong order on purpose
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        let ordered = bands
        XCTAssertEqual(ordered.count, 2)
        XCTAssertGreaterThan(ordered[1].frame.minX, ordered[0].frame.minX, "the sync pass re-sorts: outer (wider, lefter) first")
        // P3: a second layout pass changes nothing and does not loop.
        let before = editor.engine.subviews.map { ObjectIdentifier($0) }
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        XCTAssertEqual(editor.engine.subviews.map { ObjectIdentifier($0) }, before)
    }

    func test_aCodeBandInsideAQuoteIsFlushWithTheQuotesInnerEdgeAndDoesNotBleed() {
        editor.codeStyle = CodeStyle(horizontalBleed: nil, horizontalInset: 8.0, cornerRadius: 4.0)   // the article host: a top-level band would be full width
        load([quote("q", [para("a", "one"), .code(CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "x")]))])])
        // Roles: a@1, language@1, code@1, author@1
        let codeBands = bands.filter { $0.backgroundColor != nil && $0.frame.contains(CGPoint(x: editor.engine.id_frameForBlock(at: 2).midX, y: editor.engine.id_frameForBlock(at: 2).midY)) }
        guard let quoteBand = codeBands.max(by: { $0.frame.width < $1.frame.width }),
              let codeBand = codeBands.min(by: { $0.frame.width < $1.frame.width }), quoteBand != codeBand else {
            return XCTFail("expected a quote band and a code band over the code: \(bands.map(\.frame))")
        }
        XCTAssertEqual(codeBand.frame.minX - quoteBand.frame.minX, indent, accuracy: 0.5, "flush with the quote's inner edge")
        XCTAssertLessThanOrEqual(codeBand.frame.maxX, quoteBand.frame.maxX + 0.5, "no bleed past the quote")
        XCTAssertTrue(codeBand.frame.contains(editor.engine.id_frameForBlock(at: 1).insetBy(dx: indent, dy: 0)), "the band covers the language line too")
    }

    // MARK: §5.2 spacing

    func test_eachLevelAddsItsOwnInteriorPaddingAboveTheFirstChild() {
        load([para("p0", "above"), quote("q", [quote("q2", [para("b", "deep")])])])
        let metrics = RichTextRenderMetrics.default
        let exterior = richTextSpacingBetweenBlocks(upper: .paragraph, lower: .blockQuote, kind: .topLevel, metrics: metrics)
        let above = editor.engine.id_frameForBlock(at: 0)
        let deep = editor.engine.id_frameForBlock(at: 1)
        // Less the paragraph's own trailing overhang: a frame's bottom is one empty line-box band
        // below its glyphs, and the rhythm gives that band back (2026-09-15).
        XCTAssertEqual(deep.minY - above.maxY,
                       exterior + 8.0 + 8.0 - editor.trailingLineBoxOverhang(atRole: 0),
                       accuracy: 1.0, "the shared gap plus two interiors")
        guard let outer = bands.max(by: { $0.frame.width < $1.frame.width }), let inner = bands.min(by: { $0.frame.width < $1.frame.width }) else { return XCTFail() }
        XCTAssertEqual(deep.minY - inner.frame.minY, 8.0, accuracy: 1.0, "the inner band grows into its own padding")
        XCTAssertEqual(deep.minY - outer.frame.minY, 16.0, accuracy: 1.0, "the outer band grows into both")
    }

    func test_siblingsInsideAQuoteKeepTheRhythmOfTheirOwnKinds() {
        load([quote("q", [para("a", "one"), .paragraph(ParagraphBlock(id: BlockID("h"), style: .heading2, runs: [TextRun(text: "Head")]))])])
        let metrics = RichTextRenderMetrics.default
        let expected = richTextSpacingBetweenBlocks(upper: .paragraph, lower: .heading, kind: .topLevel, metrics: metrics)
        let one = editor.engine.id_frameForBlock(at: 0), head = editor.engine.id_frameForBlock(at: 1)
        XCTAssertEqual(head.minY - one.maxY, expected, accuracy: 1.0, "a quoted heading gets the renderer's heading rhythm, not paragraph-to-paragraph")
    }

    // MARK: §5.3 tables inside a quote (probe P2)

    func table(_ id: String) -> Block {
        .table(TableBlock(id: BlockID(id), columns: [ColumnSpec(width: 100), ColumnSpec(width: 100)],
                          rows: [Row(id: BlockID("\(id)r"), cells: [Cell(id: BlockID("\(id)a"), blocks: [para("\(id)ap", "a")]),
                                                                   Cell(id: BlockID("\(id)b"), blocks: [para("\(id)bp", "b")])])]))
    }

    /// A nested table is FLUSH with its container's interior on BOTH sides: one quoteIndent in on
    /// the left and the quote's trailing inset short of the column on the right, so it is narrowed
    /// by their sum. It briefly reserved a grip's gutter on each side as well; that read as a table
    /// pushed in from everything around it (user report, 2026-09-11), and the room was already
    /// there — the grips hang into the quote's own indent, which is what `tableClipX` opens the
    /// chrome's window for.
    ///
    /// The right-hand half moved on 2026-09-11: it used to reach the column edge a TOP-LEVEL table
    /// reaches, which left a quoted grid running 22pt past where the quote's own paragraphs stop.
    func test_aTableInsideAQuoteIsFlushWithTheQuotesInteriorOnBothSides() {
        load([table("top"), quote("q", [table("t")])])
        // Roles: top a, top b, t a@1, t b@1, q author@1
        let topLeft = editor.engine.id_frameForBlock(at: 0)
        let nestedLeft = editor.engine.id_frameForBlock(at: 2)
        let topRight = editor.engine.id_frameForBlock(at: 1)
        let nestedRight = editor.engine.id_frameForBlock(at: 3)
        XCTAssertEqual(nestedLeft.minX - topLeft.minX, indent, accuracy: 0.5,
                       "one quoteIndent in, and nothing else")
        XCTAssertEqual(topRight.maxX - nestedRight.maxX, trailing, accuracy: 1.0,
                       "\u{2026}and stops the quote's trailing inset short of the column, like its text")
        XCTAssertEqual((nestedRight.maxX - nestedLeft.minX) - (topRight.maxX - topLeft.minX),
                       -(indent + trailing), accuracy: 1.0, "so the grid is narrower by both")
        guard let quoteBand = innermostBand(over: 4) else { return XCTFail("no quote band") }
        XCTAssertTrue(quoteBand.frame.contains(nestedLeft) && quoteBand.frame.contains(nestedRight), "the cells sit inside the quote's band")
    }

    func test_theChromeOfANestedTableFollowsItsCells() {
        load([quote("q", [table("t")])])
        guard let chrome = editor.tableChromeViews[BlockID("t")], let frame = editor.tableFrame(forTableAt: 0) else { return XCTFail("no chrome") }
        let inSuperview = chrome.superview?.convert(chrome.frame, to: editor.engine) ?? chrome.frame
        XCTAssertEqual(inSuperview.minX, frame.minX, accuracy: 1.0, "chrome and cells agree on the table's left edge")
        XCTAssertEqual(inSuperview.width, frame.width, accuracy: 1.0)
    }

    func test_aTableThatIsAQuotesFirstChildTakesNoRhythmGap() {
        load([para("p0", "above"), quote("q", [table("t")])])
        let above = editor.engine.id_frameForBlock(at: 0)
        guard let tableFrame = editor.tableFrame(forTableAt: 1) else { return XCTFail() }
        let metrics = RichTextRenderMetrics.default
        let exterior = richTextSpacingBetweenBlocks(upper: .paragraph, lower: .blockQuote, kind: .topLevel, metrics: metrics)
        XCTAssertEqual(tableFrame.minY - above.maxY,
                       exterior + 8.0 - editor.trailingLineBoxOverhang(atRole: 0),
                       accuracy: 1.5, "the shared gap above the quote plus its interior \u{2014} no table rhythm gap on top")
    }

    /// The gap a table OPENS a quote with, at the two shapes the case above does not reach: one per
    /// quote opened, and the leading rhythm when the quote opens the document.
    ///
    /// The document's first block is measured from the text container's own top inset, which is where
    /// the engine anchors the first run (verified against a real layout, not derived).
    func test_aTableOpeningQuotesTakesTheOutermostRhythmAndOneInteriorPerQuote() {
        let metrics = RichTextRenderMetrics.default
        // `nil` upper is the ONE place the spacing table tells `.table` and `.blockQuote` apart
        // (11 vs 4), so these two also pin that the opened unit is read as a quote, not as the table.
        let leading = richTextSpacingBetweenBlocks(upper: nil, lower: .blockQuote, kind: .topLevel, metrics: metrics)

        load([quote("a", [quote("b", [table("t")])])])
        guard let pair = editor.tableFrame(forTableAt: 0) else { return XCTFail("no nested pair") }
        XCTAssertEqual(pair.minY - editor.engine.textContainerInset.top, leading + 16.0, accuracy: 1.0,
                       "the outer quote's leading rhythm, then BOTH quotes' top interiors")
        XCTAssertEqual(pair.minX - editor.engine.textContainerInset.left,
                       indent * 2.0, accuracy: 0.5,
                       "\u{2026}two indents in, and nothing for the chrome: the grips hang into the "
                       + "innermost container's own indent rather than into room the table reserves")

        load([quote("q", [table("t")])])
        guard let single = editor.tableFrame(forTableAt: 0) else { return XCTFail("no quoted table") }
        XCTAssertEqual(single.minY - editor.engine.textContainerInset.top, leading + 8.0, accuracy: 1.0,
                       "one quote opened, so one interior")
    }

    /// A table that opens NO quote keeps its own rhythm against its sibling and takes no interior:
    /// the quote's padding was already reserved on the sibling above it.
    func test_aTableAfterASiblingInsideAQuoteTakesItsOwnRhythmAndNoInterior() {
        let metrics = RichTextRenderMetrics.default
        load([quote("q", [para("p", "x"), table("t")])])
        let sibling = editor.engine.id_frameForBlock(at: 0)
        guard let tableFrame = editor.tableFrame(forTableAt: 1) else { return XCTFail("no quoted table") }
        XCTAssertEqual(tableFrame.minY - sibling.maxY, richTextSpacingBetweenBlocks(upper: .paragraph, lower: .table, kind: .topLevel, metrics: metrics),
                       accuracy: 1.0, "paragraph-to-table rhythm, no quote interior on top of it")

        // The same arm at depth 0, where `lower` is visibly `.table`: a bare table opening the document.
        load([table("t")])
        guard let top = editor.tableFrame(forTableAt: 0) else { return XCTFail("no table") }
        XCTAssertEqual(top.minY - editor.engine.textContainerInset.top, richTextSpacingBetweenBlocks(upper: nil, lower: .table, kind: .topLevel, metrics: metrics),
                       accuracy: 1.0, "the leading rhythm of a TABLE, not of a quote")
    }

    // MARK: §5.4 media inside a quote (probe P1)

    final class StubMediaView: UIView, RichTextMediaItemView {
        func update(size: CGSize) {}
        var onControlTapped: ((RichTextMediaControlKind, Int?, UIView, CGRect) -> Void)?
    }
    func photo(_ id: String) -> Block {
        .media(MediaBlock(id: BlockID(id), items: [MediaItem(mediaID: "m-\(id)", kind: .image, naturalSize: Size2D(width: 1000, height: 500))]))
    }
    /// The atom's flat offset, read from the roles rather than counted by hand: the brief's worked
    /// numbering for the two-photo document was one out (an empty caption line contributes only its
    /// separator).
    func atomOffset(_ id: String) -> UInt {
        guard let index = editor.mediaAtomIndex(ofBlock: BlockID(id)) else { return UInt.max }
        return UInt(editor.flatOffset(ofRoleAt: index))
    }

    /// P1: whether TextKit 2 hands the attachment a fragment already narrowed by the container's
    /// indents.
    ///
    /// **Measured 2026-09-05, with `horizontalIndent` not yet subtracted anywhere: FULL FRAGMENT.**
    /// On a 310pt column with a 16pt indent the nested atom came back `(x 13, w 310)` against the
    /// top-level `(x 5, w 310)` — the same width, hanging 8pt past the column on the right and
    /// starting 8pt short of the indented edge on the left, the shape's centred alignment splitting
    /// the 16pt overflow. So `slot(forLineWidth:)` subtracts the indent; with it subtracted the same
    /// document measures `(x 21, w 294)`.
    ///
    /// **Re-measured 2026-09-11 for the TRAILING inset, and P1's answer holds there too:** with the
    /// leading half alone subtracted, the 294pt-wide atom was centred in the 272pt line its own
    /// paragraph now stops at and hung 11pt off each end. Subtracting both halves makes the slot the
    /// line exactly, which is what the three assertions below say.
    func test_anAtomInsideAQuoteIsAsWideAsTheIndentedLine() {
        editor.mediaBlockStyle = MediaBlockStyle(horizontalBleed: 0)
        load([photo("top"), quote("q", [photo("ph")])])
        let top = editor.engine.id_attachmentFrame(forCanonicalOffset: atomOffset("top"))
        let nested = editor.engine.id_attachmentFrame(forCanonicalOffset: atomOffset("ph"))
        XCTAssertEqual(nested.minX - top.minX, indent, accuracy: 1.0, "the atom sits at the quoted line's start")
        XCTAssertEqual(top.width - nested.width, indent + trailing, accuracy: 1.0,
                       "and is narrower by both insets: it cannot run past either edge of the quote's column")
        XCTAssertEqual(nested.maxX, top.maxX - trailing, accuracy: 1.0,
                       "stopping the trailing inset short of the column, like the quote's text")
    }

    func test_aNestedMediaViewDoesNotBleedAndSitsInsideTheBand() {
        editor.mediaBlockStyle = MediaBlockStyle(horizontalBleed: 16)
        editor.registerMediaViewProvider { _, _, _, existing in existing ?? StubMediaView() }
        load([photo("top"), quote("q", [photo("ph")])])
        let top = editor.engine.id_attachmentFrame(forCanonicalOffset: atomOffset("top"))
        let nested = editor.engine.id_attachmentFrame(forCanonicalOffset: atomOffset("ph"))
        XCTAssertEqual(editor.mediaAtomViews[BlockID("top")]?.frame, top.insetBy(dx: -16, dy: 0), "a top-level unit bleeds")
        XCTAssertEqual(editor.mediaAtomViews[BlockID("ph")]?.frame, nested, "a nested one is flush with the line")
        guard let band = innermostBand(over: 2), let host = editor.mediaAtomViews[BlockID("ph")] else { return XCTFail() }
        XCTAssertTrue(band.frame.insetBy(dx: -0.5, dy: -0.5).contains(host.frame), "inside the quote's band: \(band.frame) vs \(host.frame)")
    }

    func test_theTwoStepBackspaceOnANestedPhotoKeepsTheQuote() {
        load([quote("q", [para("a", "one"), photo("ph")])])
        // one 0..3 | ▣ 4 | cap 6 | q author 7
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engineSelectedRange = NSRange(location: 6, length: 0)
        editor.engine.deleteBackward()
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 4, length: 1), "first: the atom is selected")
        editor.engine.deleteBackward()
        XCTAssertEqual(editor.engine.attributedBlocks.map(\.string), ["one", "", ""], "second: atom and caption go, an empty child stays")
        XCTAssertEqual(editor.currentRoles.map(\.containerDepth), [1, 1, 1], "…inside the quote, whose author line stays too")
    }

    // MARK: §5.5 markers and placeholders

    func test_aListMarkerInsideAQuoteHangsOneIndentPerLevelFurtherIn() {
        let bullet = ListMembership(marker: .bullet, level: 0)
        load([.paragraph(ParagraphBlock(id: BlockID("top"), list: bullet, runs: [TextRun(text: "top")])),
              quote("q", [quote("q2", [.paragraph(ParagraphBlock(id: BlockID("deep"), list: bullet, runs: [TextRun(text: "deep")]))])])])
        guard let top = editor.listMarkerViews[BlockID("top")], let deep = editor.listMarkerViews[BlockID("deep")] else { return XCTFail("no markers") }
        let topBlock = editor.engine.id_frameForBlock(at: 0), deepBlock = editor.engine.id_frameForBlock(at: 1)
        XCTAssertEqual((deep.frame.minX - deepBlock.minX) - (top.frame.minX - topBlock.minX), indent * 2, accuracy: 0.5, "two levels, two indents")
    }

    func test_aNestedAuthorPlaceholderSitsAtTheLinesIndent() {
        load([quote("q", [quote("q2", [para("b", "two")])])])
        // Roles: b@2, q2 author@2 (empty: shows its prompt), q author@1 (empty: prompt)
        guard let inner = editor.secondaryPlaceholderLabels[BlockID("q2#author")],
              let outer = editor.secondaryPlaceholderLabels[BlockID("q#author")] else { return XCTFail("no placeholders") }
        let innerBlock = editor.engine.id_frameForBlock(at: 1), outerBlock = editor.engine.id_frameForBlock(at: 2)
        XCTAssertEqual(inner.frame.minX - innerBlock.minX, indent * 2, accuracy: 0.5)
        XCTAssertEqual(outer.frame.minX - outerBlock.minX, indent, accuracy: 0.5, "the top-level author line keeps today's one indent")
    }

    // MARK: a quote's band is its COLUMN, not the union of what it holds (device, K3 pass 2)

    func tbl(_ id: String, _ cols: Int = 2) -> Block {
        .table(TableBlock(id: BlockID(id), columns: (0..<cols).map { _ in ColumnSpec(width: 100) },
                          rows: [Row(id: BlockID("\(id)r"),
                                     cells: (0..<cols).map { i in Cell(id: BlockID("\(id)c\(i)"),
                                                                       blocks: [para("\(id)p\(i)", "")]) })]))
    }

    /// A quote whose ONLY child is a table. Every ordinary child returns a full-width line frame, so
    /// unioning the span gave the column by accident; a table returns PLACED cell rects, and the band
    /// came out hugging the grid — the quote's background visibly shrank to the table.
    func test_aQuoteHoldingOnlyATableStillSpansTheColumn() {
        load([quote("q", [tbl("t")])])
        guard let band = bands.first else { return XCTFail("no band") }
        let column = editor.engine.textContainerInset.left
        XCTAssertEqual(band.frame.minX, column, accuracy: 0.5, "the band starts at the column, not at the first cell")
        XCTAssertEqual(band.frame.width, editor.availableTableWidth, accuracy: 0.5, "and spans the whole column")
    }

    /// The same quote with a paragraph before the table: the band is unchanged, which is what says
    /// the column — not the paragraph that used to dominate the union — is what decides it.
    func test_aParagraphBesideTheTableDoesNotChangeTheBandsColumn() {
        load([quote("q", [tbl("t")])])
        guard let alone = bands.first?.frame else { return XCTFail("no band") }
        load([quote("q", [para("a", "one"), tbl("t")])])
        guard let beside = bands.first?.frame else { return XCTFail("no band") }
        XCTAssertEqual(alone.minX, beside.minX, accuracy: 0.5)
        XCTAssertEqual(alone.width, beside.width, accuracy: 0.5)
    }

    /// A nested quote's band still steps in one indent per level, so pinning the column did not flatten
    /// the levels.
    func test_aNestedQuotesBandStillStepsInOneIndent() {
        load([quote("q", [para("a", "one"), quote("q2", [tbl("t")])])])
        let sorted = bands.map(\.frame).sorted { $0.width > $1.width }
        guard sorted.count == 2 else { return XCTFail("expected two bands, got \(sorted.count)") }
        XCTAssertEqual(sorted[1].minX - sorted[0].minX, indent, accuracy: 0.5)
        XCTAssertEqual(sorted[1].maxX, sorted[0].maxX, accuracy: 0.5)
    }

    /// The band's VERTICAL extent comes from the union, and a placed cell contributes its TABLE frame
    /// rather than its text frame — so the band covers the grid's real top instead of starting
    /// `border + padding` inside it.
    /// A PLACED cell's own frame is its TEXT frame, which sits `border 1 + padding 14` inside the
    /// grid, so a band that unions cell frames starts BELOW the table it is supposed to contain.
    /// Measured with the fix removed: the band's top lands 7pt below the table's, which is the
    /// quoted table's top edge hanging out of its own quote.
    func test_theBandCoversAQuotedTablesRealTop() {
        load([quote("q", [tbl("t")])])
        guard let band = bands.first, let table = editor.tableFrame(forTableAt: 0) else { return XCTFail() }
        XCTAssertLessThanOrEqual(band.frame.minY, table.minY, "the band starts at or above the table's top")
        XCTAssertGreaterThanOrEqual(band.frame.maxY, table.maxY, "and ends at or below its bottom")
        // Not merely "covers": the band carries the quote's INTERIOR around the table, the same
        // padding it gives any other child. A band that merely grazed the table's edges would satisfy
        // the two assertions above while reading as a quote with no padding at all.
        let interior = editor.bridge.styleSheet.quoteTopInset ?? 8.0
        XCTAssertEqual(table.minY - band.frame.minY, interior, accuracy: 0.5,
                       "one quote interior above the table")
        // Measured below the AUTHOR LINE, not the table: since 2026-09-11 a quote holding a table
        // holds a child and so carries an author line, which is the last thing in its span. The
        // quantity under test is unchanged — one quote interior below whatever the quote ends with.
        guard let authorRole = editor.currentRoles.firstIndex(where: { $0.secondaryKind == .blockQuoteAuthor })
        else { return XCTFail("the quoted table gets the quote an author line") }
        let author = editor.engine.id_frameForBlock(at: UInt(authorRole))
        XCTAssertGreaterThanOrEqual(author.minY, table.maxY, "the author line sits below the table")
        XCTAssertEqual(band.frame.maxY - author.maxY,
                       (editor.bridge.styleSheet.quoteBottomInset ?? 8.0)
                           - editor.trailingLineBoxOverhang(atRole: authorRole),
                       accuracy: 0.5, "and one below")
    }
}
