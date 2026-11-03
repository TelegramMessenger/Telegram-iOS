#if canImport(UIKit)
import XCTest
import RichTextEditorCore
@testable import RichTextEditorUIKit

final class PullQuoteBoxTests: XCTestCase {
    func test_currentBlock_preservesRichRuns_stripsItalic() {
        let mapper = AttributedStringMapper()
        var bold = CharacterAttributes(); bold.bold = true
        let pq = PullQuote(id: BlockID("pq"), runs: [TextRun(text: "a", attributes: bold), TextRun(text: "b")])
        let box = PullQuoteBox(pullQuote: pq, mapper: mapper, width: 300)
        guard case .pullQuote(let out) = box.currentBlock() else { return XCTFail() }
        XCTAssertEqual(out.text, "ab")
        XCTAssertTrue(out.runs.contains { $0.attributes.bold })     // bold preserved
        XCTAssertFalse(out.runs.contains { $0.attributes.italic })  // forced italic not stored
    }
    func test_nodeSize_isContentPlusTwo() {
        let box = PullQuoteBox(pullQuote: PullQuote(id: BlockID("x"), runs: [TextRun(text: "abcd")]),
                               mapper: AttributedStringMapper(), width: 300)
        // length 4 + authorLength 0 (default-empty author) + 6 = 10 (was `length + 2` before the author region).
        XCTAssertEqual(box.nodeSize, 10)
    }
    func test_pullQuote_emptyHeight_matchesSingleLineTextHeight() {
        let mapper = AttributedStringMapper()
        let empty = PullQuoteBox(pullQuote: PullQuote(id: BlockID("e"), runs: []),
                                 mapper: mapper, pullQuoteStyle: .default, width: 300)
        let oneLine = PullQuoteBox(pullQuote: PullQuote(id: BlockID("t"), runs: [TextRun(text: "Hi")]),
                                   mapper: mapper, pullQuoteStyle: .default, width: 300)
        // An empty pull quote's TEXT must be exactly as tall as a one-line one's — the empty-line fallback must
        // apply the same lineHeightMultiple TextKit applies to a laid-out line. Compare `quoteOnlyHeight` (the
        // text portion alone), NOT `.height`: `empty` has no body text so its author region is hidden (this
        // task), while `oneLine`'s body ("Hi") shows its (empty-author) region — the two boxes now legitimately
        // differ in overall `.height`, but their pull-TEXT heights must still agree.
        XCTAssertEqual(empty.quoteOnlyHeight, oneLine.quoteOnlyHeight, accuracy: 0.5)
    }
    func test_canvasBuildsPullQuoteBox() {
        let canvas = DocumentCanvasView()
        canvas.setBlocks([.pullQuote(PullQuote(id: BlockID("pq"), runs: [TextRun(text: "hi")]))], width: 320)
        XCTAssertTrue(canvas.boxes.contains { $0 is PullQuoteBox })
    }

    func test_emptyPullQuote_showsPlaceholderAndHugsIt() {
        let box = PullQuoteBox(pullQuote: PullQuote(id: BlockID("pq"), runs: []),
                               mapper: AttributedStringMapper(), pullQuoteStyle: .default, width: 320)
        box.placeholders = .default    // pullQuote == "Type a quote here"
        XCTAssertEqual(box.placeholderText, "Type a quote here")
        XCTAssertGreaterThan(box.contentWidth, 0)      // empty pill hugs the placeholder, not zero width
    }

    func test_nonEmptyPullQuote_hasNoPlaceholder() {
        let box = PullQuoteBox(pullQuote: PullQuote(id: BlockID("pq"), runs: [TextRun(text: "hi")]),
                               mapper: AttributedStringMapper(), pullQuoteStyle: .default, width: 320)
        box.placeholders = .default
        XCTAssertNil(box.placeholderText)
    }

    func test_pullQuote_emptyPlaceholderStringSuppresses() {
        let box = PullQuoteBox(pullQuote: PullQuote(id: BlockID("pq"), runs: []),
                               mapper: AttributedStringMapper(), pullQuoteStyle: .default, width: 320)
        box.placeholders = RichTextEditorPlaceholders(body: "", listEnd: "", listOutdent: "", pullQuote: "")
        XCTAssertNil(box.placeholderText)
        XCTAssertEqual(box.contentWidth, 0)
    }

    func test_pullQuoteStyle_customInsets_propagateToBox() {
        var style = PullQuoteStyle.default; style.topInset = 30; style.bottomInset = 10
        let box = PullQuoteBox(pullQuote: PullQuote(id: BlockID("pq"), runs: [TextRun(text: "hi")]),
                               mapper: AttributedStringMapper(), pullQuoteStyle: style, width: 320)
        XCTAssertEqual(box.topInset, 30, accuracy: 0.001)
        XCTAssertEqual(box.bottomInset, 10, accuracy: 0.001)
    }

    func test_emptyPullQuote_caretIndent_atPlaceholderStart() {
        let box = PullQuoteBox(pullQuote: PullQuote(id: BlockID("pq"), runs: []),
                               mapper: AttributedStringMapper(), pullQuoteStyle: .default, width: 320)
        box.placeholders = .default   // pullQuote == "Type a quote here"
        box.frame = CGRect(x: 0, y: 0, width: 320, height: box.height)
        let containerWidth = box.frame.width - box.leftInset - box.rightInset
        let indent = box.leafRegions().first!.emptyLineLeadingIndent
        XCTAssertEqual(indent, (containerWidth - box.contentWidth) / 2, accuracy: 0.5)  // placeholder leading edge
        XCTAssertGreaterThan(indent, 0)                        // not the strip's left edge (the bug)
        XCTAssertLessThan(indent, containerWidth / 2)          // left of center (the placeholder has width)
    }

    func test_emptyPullQuote_noPlaceholder_caretIndent_atCenter() {
        let box = PullQuoteBox(pullQuote: PullQuote(id: BlockID("pq"), runs: []),
                               mapper: AttributedStringMapper(), pullQuoteStyle: .default, width: 320)
        box.placeholders = RichTextEditorPlaceholders(body: "", listEnd: "", listOutdent: "", pullQuote: "")
        box.frame = CGRect(x: 0, y: 0, width: 320, height: box.height)
        let containerWidth = box.frame.width - box.leftInset - box.rightInset
        XCTAssertEqual(box.leafRegions().first!.emptyLineLeadingIndent, containerWidth / 2, accuracy: 0.5)
    }

    func test_nonEmptyPullQuote_caretIndent_isZero() {
        let box = PullQuoteBox(pullQuote: PullQuote(id: BlockID("pq"), runs: [TextRun(text: "hi")]),
                               mapper: AttributedStringMapper(), pullQuoteStyle: .default, width: 320)
        box.frame = CGRect(x: 0, y: 0, width: 320, height: box.height)
        XCTAssertEqual(box.leafRegions().first!.emptyLineLeadingIndent, 0, accuracy: 0.001)
    }

    // MARK: - Task 3: author region

    func test_pullQuote_nodeSize_includesAuthorRegion() {
        let box = PullQuoteBox(pullQuote: PullQuote(id: BlockID("pq"), runs: [TextRun(text: "abcd")], author: [TextRun(text: "AB")]),
                               mapper: AttributedStringMapper(), pullQuoteStyle: .default, width: 320)
        XCTAssertEqual(box.nodeSize, 12)  // 4 + 2 (author) + 6
    }

    func test_pullQuote_leafRegions_pullThenAuthor() {
        let box = PullQuoteBox(pullQuote: PullQuote(id: BlockID("pq"), runs: [TextRun(text: "abcd")], author: [TextRun(text: "AB")]),
                               mapper: AttributedStringMapper(), pullQuoteStyle: .default, width: 320)
        box.nodeStart = 10
        box.frame = CGRect(x: 0, y: 0, width: 320, height: box.height)
        let regions = box.leafRegions()
        XCTAssertEqual(regions.count, 2)
        XCTAssertEqual(regions[0].ref, .pullQuote(BlockID("pq")))
        XCTAssertEqual(regions[0].globalStart, 11)        // nodeStart + 1
        XCTAssertEqual(regions[0].length, 4)
        XCTAssertEqual(regions[1].ref, .quoteAuthor(BlockID("pq")))
        XCTAssertEqual(regions[1].globalStart, 10 + 4 + 3) // nodeStart + length + 3 = 17
        XCTAssertEqual(regions[1].length, 2)
    }

    func test_pullQuote_currentBlock_roundTripsAuthor_withBoldStripped() {
        // Author typed with bold would come back bold from the layout; the box strips it (bold is ambient).
        let box = PullQuoteBox(pullQuote: PullQuote(id: BlockID("pq"), runs: [TextRun(text: "q")], author: [TextRun(text: "Jobs")]),
                               mapper: AttributedStringMapper(), pullQuoteStyle: .default, width: 320)
        guard case let .pullQuote(pq) = box.currentBlock() else { return XCTFail("expected pullQuote") }
        XCTAssertEqual(pq.author.map(\.text).joined(), "Jobs")
        XCTAssertTrue(pq.author.allSatisfy { $0.attributes.bold == false }) // ambient bold not stored
    }

    func test_pullQuote_emptyAuthor_hasPlaceholderRegion() {
        let box = PullQuoteBox(pullQuote: PullQuote(id: BlockID("pq"), runs: [TextRun(text: "q")]),
                               mapper: AttributedStringMapper(), pullQuoteStyle: .default, width: 320)
        box.frame = CGRect(x: 0, y: 0, width: 320, height: box.height)
        XCTAssertEqual(box.leafRegions().count, 2)                 // author region present even when empty
        XCTAssertEqual(box.leafRegions()[1].length, 0)
        XCTAssertGreaterThan(box.leafRegions()[1].emptyLineHeight, 0)
    }

    func test_emptyPullQuote_caretIndent_isFrameIndependent() {
        let box = PullQuoteBox(pullQuote: PullQuote(id: BlockID("pq"), runs: []),
                               mapper: AttributedStringMapper(), pullQuoteStyle: .default, width: 320)
        box.placeholders = .default
        // Deliberately do NOT set box.frame (it stays .zero). The empty-caret indent must still
        // reflect the construction-time configured width, not the not-yet-assigned frame.
        let containerWidth = box.layoutWidth - box.leftInset - box.rightInset
        let indent = box.leafRegions().first!.emptyLineLeadingIndent
        XCTAssertEqual(indent, (containerWidth - box.contentWidth) / 2, accuracy: 0.5)  // placeholder start
        XCTAssertGreaterThan(indent, 0)   // NOT the left-edge fallback, despite frame == .zero
    }

    // MARK: - pillContentWidth (author widens the content-hugging pill)

    func test_pillContentWidth_longAuthor_widensPill() {
        let box = PullQuoteBox(pullQuote: PullQuote(id: BlockID("pq"), runs: [TextRun(text: "Hi")],
                                                    author: [TextRun(text: "A rather long attribution line")]),
                               mapper: AttributedStringMapper(), pullQuoteStyle: .default, width: 320)
        box.frame = CGRect(x: 0, y: 0, width: 320, height: box.height)
        let pullW = box.layout.selectionRects(start: 0, end: box.length).map(\.width).max() ?? 0
        let authorW = box.authorLayout.selectionRects(start: 0, end: box.authorLength).map(\.width).max() ?? 0
        XCTAssertGreaterThan(authorW, pullW)                            // sanity: author really is wider
        XCTAssertEqual(box.contentWidth, pullW, accuracy: 0.5)          // contentWidth unchanged (pull text only)
        XCTAssertEqual(box.pillContentWidth, authorW, accuracy: 0.5)    // pill now hugs the author
    }

    func test_pillContentWidth_narrowAuthor_doesNotShrinkPill() {
        let box = PullQuoteBox(pullQuote: PullQuote(id: BlockID("pq"), runs: [TextRun(text: "A rather long pull quote line here")],
                                                    author: [TextRun(text: "x")]),
                               mapper: AttributedStringMapper(), pullQuoteStyle: .default, width: 320)
        box.frame = CGRect(x: 0, y: 0, width: 320, height: box.height)
        XCTAssertEqual(box.pillContentWidth, box.contentWidth, accuracy: 0.5)
        let pullW = box.layout.selectionRects(start: 0, end: box.length).map(\.width).max() ?? 0
        XCTAssertEqual(box.pillContentWidth, pullW, accuracy: 0.5)
    }

    func test_pillContentWidth_emptyAuthorPlaceholder_participates() {
        let box = PullQuoteBox(pullQuote: PullQuote(id: BlockID("pq"), runs: [TextRun(text: "Hi")], author: []),
                               mapper: AttributedStringMapper(), pullQuoteStyle: .default, width: 320)
        box.frame = CGRect(x: 0, y: 0, width: 320, height: box.height)
        let font = AttributedStringMapper().styleSheet.font(for: .caption, attributes: CharacterAttributes(bold: true))
        let placeholderWidth = (box.placeholders.quoteAuthor as NSString).size(withAttributes: [.font: font]).width
        XCTAssertGreaterThanOrEqual(box.pillContentWidth, placeholderWidth - 0.5)
    }

    // MARK: - Dedicated author theme colors (quoteAuthorText / quoteAuthorPlaceholder)

    // Reconstructed via the SAME `UIColor(red:green:blue:alpha:)` initializer `RGBAColor.uiColor` uses, so the
    // render round-trip (TextRun.foreground → mapper → NSAttributedString → back) is bit-exact (mirrors the
    // `RGBAColor(red:1,green:0,blue:0)` precedent in MapperTests, rather than comparing against a named
    // system color that may live in a different color space).
    private static let distinctAuthorColor = UIColor(red: 1, green: 0, blue: 0, alpha: 1)
    private static let distinctPlaceholderColor = UIColor(red: 0, green: 0, blue: 1, alpha: 1)

    private func distinctAuthorTheme() -> RichTextEditorTheme {
        RichTextEditorTheme(
            primaryText: .black, secondaryText: .black, placeholder: .placeholderText,
            accent: .link, tableBorder: .gray, tableHeaderBackground: .gray, codeBackground: .gray,
            quoteAuthorText: Self.distinctAuthorColor, quoteAuthorPlaceholder: Self.distinctPlaceholderColor)
    }

    /// The author RENDER layout's foreground is the theme's dedicated `quoteAuthorText`, not `secondaryText`.
    func test_pullQuote_authorRenderForeground_usesQuoteAuthorTextTheme() {
        let mapper = AttributedStringMapper(theme: distinctAuthorTheme())
        let box = PullQuoteBox(pullQuote: PullQuote(id: BlockID("pq"), runs: [TextRun(text: "q")], author: [TextRun(text: "Ada")]),
                               mapper: mapper, pullQuoteStyle: .default, width: 320)
        let color = box.authorLayout.attributedString.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        XCTAssertEqual(color?.rgba, Self.distinctAuthorColor.rgba)
    }

    /// The color is render-only: `currentBlock()` read-back author runs carry NO foreground even under a
    /// theme with a distinct `quoteAuthorText` — proves no model pollution.
    func test_pullQuote_currentBlock_author_stripsForeground_evenWithDistinctTheme() {
        let mapper = AttributedStringMapper(theme: distinctAuthorTheme())
        let box = PullQuoteBox(pullQuote: PullQuote(id: BlockID("pq"), runs: [TextRun(text: "q")], author: [TextRun(text: "Ada")]),
                               mapper: mapper, pullQuoteStyle: .default, width: 320)
        guard case let .pullQuote(pq) = box.currentBlock() else { return XCTFail("expected pullQuote") }
        XCTAssertEqual(pq.author.map(\.text).joined(), "Ada")
        XCTAssertTrue(pq.author.allSatisfy { $0.attributes.foreground == nil }, "author color must not persist into the model")
        XCTAssertTrue(pq.author.allSatisfy { $0.attributes.bold == false }, "ambient bold still stripped")
    }

    /// Regression guard: the `.default` theme (no distinct author color set) still renders the author in
    /// `secondaryText` and still strips cleanly on read-back — unchanged from before this feature.
    func test_pullQuote_defaultTheme_authorForeground_matchesSecondaryText_andStripsClean() {
        let mapper = AttributedStringMapper()
        let box = PullQuoteBox(pullQuote: PullQuote(id: BlockID("pq"), runs: [TextRun(text: "q")], author: [TextRun(text: "Ada")]),
                               mapper: mapper, pullQuoteStyle: .default, width: 320)
        let color = box.authorLayout.attributedString.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        XCTAssertEqual(color?.rgba, RichTextEditorTheme.default.secondaryText.rgba)
        guard case let .pullQuote(pq) = box.currentBlock() else { return XCTFail("expected pullQuote") }
        XCTAssertTrue(pq.author.allSatisfy { $0.attributes.foreground == nil })
    }

    /// The empty-author FIRST-CHAR typing attributes also carry the dedicated author color.
    func test_pullQuote_authorTypingAttributes_useQuoteAuthorTextTheme() {
        let mapper = AttributedStringMapper(theme: distinctAuthorTheme())
        let box = PullQuoteBox(pullQuote: PullQuote(id: BlockID("pq"), runs: [TextRun(text: "q")]),
                               mapper: mapper, pullQuoteStyle: .default, width: 320)
        let color = box.authorTypingAttributes()[.foregroundColor] as? UIColor
        XCTAssertEqual(color?.rgba, Self.distinctAuthorColor.rgba)
    }

    // MARK: - Pull-quote author is ALWAYS italic in addition to always bold (block-quote author stays bold-only)

    /// The rendered author run's font carries BOTH `.traitBold` and `.traitItalic` — pull-quote authors are
    /// always bold+italic, unlike a block-quote author (bold-only, see `BlockQuoteBoxTests`).
    func test_pullQuote_authorRender_isBoldAndItalic() {
        let box = PullQuoteBox(pullQuote: PullQuote(id: BlockID("pq"), runs: [TextRun(text: "q")], author: [TextRun(text: "Ada")]),
                               mapper: AttributedStringMapper(), pullQuoteStyle: .default, width: 320)
        let font = box.authorLayout.attributedString.attribute(.font, at: 0, effectiveRange: nil) as! UIFont
        let traits = font.fontDescriptor.symbolicTraits
        XCTAssertTrue(traits.contains(.traitBold))
        XCTAssertTrue(traits.contains(.traitItalic))
    }

    /// The read-back `currentBlock().author` carries NEITHER bold NOR italic — both are render-only ambient
    /// styling, forced at render and stripped on read-back, so the model stays clean.
    func test_pullQuote_currentBlock_author_stripsBoldAndItalic() {
        let box = PullQuoteBox(pullQuote: PullQuote(id: BlockID("pq"), runs: [TextRun(text: "q")], author: [TextRun(text: "Ada")]),
                               mapper: AttributedStringMapper(), pullQuoteStyle: .default, width: 320)
        guard case let .pullQuote(pq) = box.currentBlock() else { return XCTFail("expected pullQuote") }
        XCTAssertEqual(pq.author.map(\.text).joined(), "Ada")
        XCTAssertTrue(pq.author.allSatisfy { $0.attributes.bold == false && $0.attributes.italic == false })
    }

    // MARK: - authorSpacing (adjustable text→author gap)

    /// `PullQuoteStyle.authorSpacing` controls the vertical gap between the pull text's last line and the
    /// author line. Non-default value → the author sits that many points below the text.
    func test_pullQuote_authorSpacing_adjustable() {
        var style = PullQuoteStyle.default
        style.authorSpacing = 10
        let box = PullQuoteBox(pullQuote: PullQuote(id: BlockID("pq"), runs: [TextRun(text: "Hi")], author: [TextRun(text: "Ada")]),
                               mapper: AttributedStringMapper(), pullQuoteStyle: style, width: 320)
        box.frame = CGRect(x: 0, y: 0, width: 320, height: box.height)
        let gap = box.authorOrigin.y - (box.textOrigin.y + box.layout.boundingHeight)
        XCTAssertEqual(gap, 10, accuracy: 0.5)
    }

    /// Default `PullQuoteStyle` (`authorSpacing == 1`) — a 1pt gap between the pull text's last line
    /// and the author line.
    func test_pullQuote_authorSpacing_defaultIsOne() {
        let box = PullQuoteBox(pullQuote: PullQuote(id: BlockID("pq"), runs: [TextRun(text: "Hi")], author: [TextRun(text: "Ada")]),
                               mapper: AttributedStringMapper(), pullQuoteStyle: .default, width: 320)
        box.frame = CGRect(x: 0, y: 0, width: 320, height: box.height)
        let gap = box.authorOrigin.y - (box.textOrigin.y + box.layout.boundingHeight)
        XCTAssertEqual(gap, 1, accuracy: 0.5)
    }

    // MARK: - Conditional author (hidden unless the quote has content)

    func test_pullQuote_author_hiddenWhenBothEmpty() {
        // Empty pull + empty author → author region ABSENT: 1 leaf region, nodeSize length+4.
        let empty = PullQuoteBox(pullQuote: PullQuote(id: BlockID("pq"), runs: [], author: []),
                                 mapper: AttributedStringMapper(), pullQuoteStyle: .default, width: 320)
        empty.frame = CGRect(x: 0, y: 0, width: 320, height: empty.height)
        XCTAssertFalse(empty.shouldShowAuthor)
        XCTAssertEqual(empty.leafRegions().count, 1)
        XCTAssertEqual(empty.nodeSize, empty.length + 4)
        XCTAssertEqual(empty.height, empty.quoteOnlyHeight, accuracy: 0.5)   // no author line reserved
    }

    func test_pullQuote_author_shownWhenBodyHasText() {
        let box = PullQuoteBox(pullQuote: PullQuote(id: BlockID("pq"), runs: [TextRun(text: "Hi")], author: []),
                               mapper: AttributedStringMapper(), pullQuoteStyle: .default, width: 320)
        box.frame = CGRect(x: 0, y: 0, width: 320, height: box.height)
        XCTAssertTrue(box.shouldShowAuthor)
        XCTAssertEqual(box.leafRegions().count, 2)
        XCTAssertEqual(box.leafRegions()[1].ref, .quoteAuthor(BlockID("pq")))
        XCTAssertEqual(box.nodeSize, box.length + box.authorLength + 6)
        XCTAssertGreaterThan(box.height, box.quoteOnlyHeight)   // author line reserved
    }

    /// A HIDDEN author (both body and author empty) must not inflate `pillContentWidth` to fit the invisible
    /// "Add author" placeholder. Uses a host placeholder shorter than "Add author" (empty) so `contentWidth`
    /// is provably 0 — before the `shouldShowAuthor` gate, `authorContentWidth` still returned the "Add
    /// author" placeholder's width even though the author region doesn't render.
    func test_pillContentWidth_hiddenAuthor_notInflatedByPlaceholder() {
        let box = PullQuoteBox(pullQuote: PullQuote(id: BlockID("pq"), runs: [], author: []),
                               mapper: AttributedStringMapper(), pullQuoteStyle: .default, width: 320)
        box.placeholders = RichTextEditorPlaceholders(body: "", listEnd: "", listOutdent: "", pullQuote: "")
        box.frame = CGRect(x: 0, y: 0, width: 320, height: box.height)
        XCTAssertFalse(box.shouldShowAuthor)
        XCTAssertEqual(box.contentWidth, 0)
        XCTAssertEqual(box.pillContentWidth, 0, "a hidden author must not widen the pill for its invisible placeholder")
    }

    func test_pullQuote_author_shownWhenAuthorHasText_bodyEmpty() {
        let box = PullQuoteBox(pullQuote: PullQuote(id: BlockID("pq"), runs: [], author: [TextRun(text: "Ada")]),
                               mapper: AttributedStringMapper(), pullQuoteStyle: .default, width: 320)
        box.frame = CGRect(x: 0, y: 0, width: 320, height: box.height)
        XCTAssertTrue(box.shouldShowAuthor)
        XCTAssertEqual(box.leafRegions().count, 2)
    }

    /// `toggleItalic()` over a selection entirely within a pull-quote's author region is a no-op — the
    /// author is always-italic (ambient), so toggling must not mutate its (rendered) attributes nor dirty
    /// the model. Mirrors `BlockQuoteEditTests.test_toggleBold_isNoOp_inAuthorRegion`.
    func test_toggleItalic_isNoOp_inPullQuoteAuthorRegion() {
        let canvas = DocumentCanvasView()
        canvas.frame = CGRect(x: 0, y: 0, width: 320, height: 400)
        canvas.setBlocks([.pullQuote(PullQuote(id: BlockID("pq"), runs: [TextRun(text: "q")], author: [TextRun(text: "Ada")]))], width: 320)
        canvas.simulateParentLayout()
        let box = canvas.boxes.first as! PullQuoteBox
        guard let authorRegion = box.leafRegions().first(where: { $0.ref == .quoteAuthor(BlockID("pq")) }) else {
            return XCTFail("no author region")
        }
        let before = authorRegion.layout.attributedString.copy() as! NSAttributedString
        canvas.setSelectionForTesting(anchor: authorRegion.globalStart, head: authorRegion.globalStart + authorRegion.length)
        canvas.toggleItalic()
        XCTAssertEqual(authorRegion.layout.attributedString, before,
                       "toggleItalic in the pull-quote author region must not mutate the author's attributes")
        guard case let .pullQuote(pq) = box.currentBlock() else { return XCTFail() }
        XCTAssertTrue(pq.author.allSatisfy { $0.attributes.italic == false })
    }
}
#endif
