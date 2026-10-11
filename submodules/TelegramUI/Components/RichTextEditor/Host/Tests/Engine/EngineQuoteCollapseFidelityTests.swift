import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// R7-collapse-fidelity. The preview is laid out by the editor's OWN text layout, so what it draws
/// and where it sits are the same answers the expanded quote gives.
@available(iOS 18.4, *)
final class EngineQuoteCollapseFidelityTests: XCTestCase {

    // MARK: - Task 1: the seam is reachable from this module

    /// The layout seam has to cross a MODULE boundary: it lives in `RichTextEditorUIKit` under
    /// `Layout/`, and the preview lives here. Republished rather than copied — a second
    /// implementation of text layout is the one thing that must not exist.
    func test_theLayoutSeamIsReachableFromTheEngineEditor() {
        let text = NSAttributedString(string: "one two three",
                                      attributes: [.font: UIFont.systemFont(ofSize: 15)])
        let layout = richTextMakeBlockLayout(attributedString: text, width: 200)
        XCTAssertEqual(layout.length, text.length)
        XCTAssertGreaterThan(layout.boundingHeight, 0)
        XCTAssertNotNil(layout.firstLineBaselineFromTop,
                        "the baseline is the number this rung exists to share")
    }

    // MARK: - Task 2: the preview keeps its runs' formatting

    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!
    private func teardownWindow() { window?.isHidden = true; window = nil; editor = nil }

    private func run(_ text: String, bold: Bool = false, spoiler: Bool = false,
                     emoji: EmojiRef? = nil) -> TextRun {
        var attributes = CharacterAttributes()
        attributes.bold = bold
        attributes.spoiler = spoiler
        attributes.emoji = emoji
        return TextRun(text: emoji == nil ? text : "\u{FFFC}", attributes: attributes)
    }
    private func para(_ id: String, _ runs: [TextRun]) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), runs: runs))
    }
    private func loadFolded(_ children: [Block]) {
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window.addSubview(editor); window.makeKeyAndVisible()
        editor.document = Document(blocks: [.blockQuote(BlockQuote(
            id: BlockID("q"), children: children, collapsed: true))])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.setNeedsLayout(); editor.layoutIfNeeded()
    }
    private func previewText() -> NSAttributedString? {
        editor.collapsedQuoteAttachment(atRoleAt: 0)?.previewText
    }

    func test_aBoldRunStaysBoldInThePreview() {
        loadFolded([para("a", [run("plain "), run("loud", bold: true)])])
        defer { teardownWindow() }
        guard let text = previewText() else { return XCTFail("no preview text") }
        XCTAssertEqual(text.string, "plain loud")
        let boldRange = (text.string as NSString).range(of: "loud")
        guard let font = text.attribute(.font, at: boldRange.location, effectiveRange: nil) as? UIFont else {
            return XCTFail("no font on the bold run")
        }
        XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.traitBold),
                      "the preview is built through the mapper, so a run keeps its traits")
    }

    func test_blocksAreJoinedByExactlyOneSpace() {
        loadFolded([para("a", [run("first")]), para("b", [run("second")])])
        defer { teardownWindow() }
        XCTAssertEqual(previewText()?.string, "first second",
                       "legacy's newline-to-space rule, applied AT the join")
    }

    // MARK: - Task 3: a block with no text says it is there

    private func photo(_ id: String) -> Block {
        .media(MediaBlock(id: BlockID(id),
                          items: [MediaItem(mediaID: "m-\(id)", kind: .image,
                                            naturalSize: Size2D(width: 100, height: 100))]))
    }
    private func markerCount(in text: NSAttributedString) -> Int {
        var markers = 0
        text.enumerateAttribute(.attachment, in: NSRange(location: 0, length: text.length),
                                options: []) { value, _, _ in
            if value is CollapsedQuoteMarkerAttachment { markers += 1 }
        }
        return markers
    }

    func test_aMediaBlockContributesOneMarker() {
        loadFolded([para("a", [run("look")]), photo("m"), para("b", [run("here")])])
        defer { teardownWindow() }
        guard let text = previewText() else { return XCTFail("no preview text") }
        XCTAssertEqual(markerCount(in: text), 1, "one marker for the photo, and only for the photo")
        XCTAssertTrue(text.string.contains("look"))
        XCTAssertTrue(text.string.contains("here"))
    }

    func test_aTextOnlyQuoteHasNoMarkers() {
        loadFolded([para("a", [run("just words")])])
        defer { teardownWindow() }
        guard let text = previewText() else { return XCTFail("no preview text") }
        XCTAssertEqual(markerCount(in: text), 0)
    }

    func test_eachKindHasItsOwnSymbol() {
        XCTAssertEqual(CollapsedQuoteMarkers.symbolName(for: photo("m")), "photo")
        XCTAssertEqual(CollapsedQuoteMarkers.symbolName(for: .table(TableBlock.empty(rows: 1, columns: 1))),
                       "tablecells")
        XCTAssertEqual(CollapsedQuoteMarkers.symbolName(
            for: .buttonRow(ButtonRowBlock(id: BlockID("r"), buttons: []))),
                       "rectangle.and.hand.point.up.left")
        XCTAssertNil(CollapsedQuoteMarkers.symbolName(for: para("a", [run("text")])),
                     "a block that has text of its own is not marked — it is quoted")
    }

    /// A marker costs WIDTH, never a LINE. It is inline, so it cannot change the line count the
    /// three-line cap measures — which is what keeps `maxPreviewLines` meaning the same thing here,
    /// in the V2 renderer and in `InteractiveTextComponent`. Asserted because the spec claims it and
    /// nothing else would notice a marker that broke the line.
    func test_aMarkerDoesNotCostALine() {
        loadFolded([para("a", [run("one line of words")])])
        let withoutMarker = editor.engine.id_frameForBlock(at: 0).height
        teardownWindow()

        loadFolded([para("a", [run("one line of words")]), photo("m")])
        defer { teardownWindow() }
        let withMarker = editor.engine.id_frameForBlock(at: 0).height
        XCTAssertEqual(withMarker, withoutMarker, accuracy: 0.5,
                       "the marker joined the same line; it did not open a second one")
    }

    // MARK: - Task 4: the preview's baseline is the engine's

    private func inkTopBelowBand(collapsed: Bool) -> CGFloat? {
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window.addSubview(editor); window.makeKeyAndVisible()
        editor.document = Document(blocks: [.blockQuote(BlockQuote(
            id: BlockID("q"), children: [para("a", [run("Hxy quoted text")])], collapsed: collapsed))])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        guard let band = editor.containerDecorationViews[BlockID("q")]?.frame else { return nil }
        let image = EngineInk.render(editor)
        // Skip the leading inset so the accent BAR is not read as ink.
        let scan = CGRect(x: band.minX + 20, y: band.minY, width: band.width - 40, height: band.height)
        guard let row = EngineInk.firstInkRow(in: image, rect: scan) else { return nil }
        return row - band.minY
    }

    /// The defect this rung closes: measured at 0.33pt (one device pixel at 3×) before it, because
    /// the engine puts its first baseline at `firstBaselineFromTop` and a `UILabel` distributed the
    /// pinned box's slack by its own rule.
    func test_theFoldedTextSitsWhereTheExpandedTextSits() {
        let open = inkTopBelowBand(collapsed: false)
        teardownWindow()
        let folded = inkTopBelowBand(collapsed: true)
        defer { teardownWindow() }
        guard let open, let folded else { return XCTFail("no ink in one of the states") }
        // 0.4pt, and the tolerance is the INSTRUMENT's rather than a preference: a first-ink scan
        // resolves to one device pixel, which is 1/3 pt at 3×, so asserting equality any tighter
        // would be asserting below the noise floor. The defect this replaces was 0.33 — a whole
        // pixel — and would still fail here.
        XCTAssertEqual(folded, open, accuracy: 0.4,
                       "one layout, asked the same question, cannot give two answers")
    }

    // MARK: - Task 5: a custom emoji is a hosted view here too

    /// A stand-in for the host's emoji view. The real provider vends an animated sticker; what this
    /// rung pins is that a view is asked for and framed on the attachment's own box.
    ///
    /// `RichTextEmojiView`'s ONLY requirement is `dynamicColor` — the tint pushed for a template
    /// emoji. There is no `update(size:)`; the editor sizes a hosted emoji by its FRAME.
    private final class StubEmojiView: UIView, RichTextEmojiView {
        var dynamicColor: UIColor?
    }

    private func loadFoldedWithEmoji(_ children: [Block]) {
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window.addSubview(editor); window.makeKeyAndVisible()
        editor.registerEmojiViewProvider { _, _ in StubEmojiView() }
        editor.document = Document(blocks: [.blockQuote(BlockQuote(
            id: BlockID("q"), children: children, collapsed: true))])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.setNeedsLayout(); editor.layoutIfNeeded()
    }

    func test_anEmojiInAFoldedQuoteGetsAHostedViewOnItsBox() {
        loadFoldedWithEmoji([para("a", [run("hi "), run("", emoji: EmojiRef(id: "e1", instanceID: "i1"))])])
        defer { teardownWindow() }
        guard let preview = editor.collapsedQuoteViews[BlockID("q")] else {
            return XCTFail("no preview view")
        }
        XCTAssertEqual(preview.emojiViews.count, 1, "one view for one emoji, pooled by instanceID")
        guard let view = preview.emojiViews["i1"] else { return XCTFail("not pooled by instanceID") }
        XCTAssertGreaterThan(view.frame.width, 0, "framed on the attachment's own box")
        XCTAssertGreaterThan(view.frame.height, 0)
        XCTAssertTrue(view.isDescendant(of: preview))
    }

    // MARK: - The preview draws THREE lines, and the cap is the layout's

    /// The text area of the folded quote's preview, in the editor's own coordinates, with the
    /// trailing glyph column excluded so the expand chevron is never read as text ink.
    private func previewTextArea() -> CGRect? {
        guard let preview = editor.collapsedQuoteViews[BlockID("q")] else { return nil }
        let area = editor.convert(preview.bounds, from: preview)
        let glyphColumn = CollapsedQuoteGeometry.glyphSize + CollapsedQuoteGeometry.glyphGap + 8
        return CGRect(x: area.minX + 20, y: area.minY,
                      width: max(area.width - 20 - glyphColumn, 1), height: area.height)
    }

    /// THE device report: "the height of a collapsed quote is correct, but it only displays one
    /// line, ellipsized, instead of 3".
    ///
    /// Asserted on RENDERED INK, in thirds, because the two states this tells apart have the same
    /// box: a one-line preview and a three-line preview are both 57pt tall, so every geometry
    /// question about the atom — its slot, its frame, the band around it — answers identically in
    /// both. What differs is only what is drawn, which is what the user was looking at.
    ///
    /// The middle third is checked as well as the last. A preview that truncated to TWO lines would
    /// pass a bottom-third-only test if the tail of line two happened to descend into it, and two
    /// lines in a three-line box is a defect this rung has already shipped once (from the cap
    /// arithmetic, 2026-09-15).
    func test_aLongFoldedQuoteDrawsAllThreeOfItsLines() {
        loadFolded([para("a", [run(String(repeating: "wordy ", count: 60))])])
        defer { teardownWindow() }
        guard let area = previewTextArea() else { return XCTFail("no preview view") }
        let image = EngineInk.render(editor)
        let third = area.height / 3
        for (index, name) in [(0, "first"), (1, "second"), (2, "third")] {
            let band = CGRect(x: area.minX, y: area.minY + CGFloat(index) * third,
                              width: area.width, height: third)
            XCTAssertNotNil(EngineInk.firstInkRow(in: image, rect: band),
                            "no ink on the \(name) line: the preview is not filling its own box")
        }
    }

    /// The mechanism, stated where a reader will meet it. A truncating mode in the PARAGRAPH STYLE
    /// beats the container's cap and collapses the text to one line however long it is — measured
    /// 19.0pt against 57.0 — which is why `collapsedQuotePreviewAttributes` wraps and the truncation
    /// is `capLines`'.
    ///
    /// Without it the test above still fails, but it fails saying "no ink on the second line", which
    /// names the symptom. This names the cause, and it is the assertion that goes red if someone
    /// puts `.byTruncatingTail` back on the string.
    func test_aTruncatingParagraphStyleWouldCollapseThePreviewToOneLine() {
        loadFolded([para("a", [run(String(repeating: "wordy ", count: 60))])])
        defer { teardownWindow() }
        guard let attachment = editor.collapsedQuoteAttachment(atRoleAt: 0) else {
            return XCTFail("no attachment")
        }
        let width = attachment.textWidth(forLineWidth: 320)
        let asStored = richTextMakeBlockLayout(attributedString: attachment.previewText, width: width)
        asStored.capLines(CollapsedQuoteGeometry.maxPreviewLines, truncating: .byTruncatingTail)
        let capped = asStored.boundingHeight

        let truncated = NSMutableAttributedString(attributedString: attachment.previewText)
        let whole = NSRange(location: 0, length: truncated.length)
        truncated.enumerateAttribute(.paragraphStyle, in: whole, options: []) { value, range, _ in
            guard let base = value as? NSParagraphStyle,
                  let style = base.mutableCopy() as? NSMutableParagraphStyle else { return }
            style.lineBreakMode = .byTruncatingTail
            truncated.addAttribute(.paragraphStyle, value: style, range: range)
        }
        let onTheString = richTextMakeBlockLayout(attributedString: truncated, width: width)
        onTheString.capLines(CollapsedQuoteGeometry.maxPreviewLines, truncating: .byTruncatingTail)

        XCTAssertGreaterThan(capped, onTheString.boundingHeight * 2,
                             "truncation on the string beats the container and lays out one line")
        XCTAssertEqual(capped, attachment.slot(forLineWidth: 320).height, accuracy: 0.5,
                       "the drawn layout fills exactly the box the atom reserved")
    }

    // MARK: - A custom emoji is the same size folded and expanded

    /// THE other device report: "in collapsed quotes and in expanded quotes the custom emoji size
    /// differs". The engine answers with the layout's RESERVATION and the preview's layout answers
    /// with the VISIBLE box, which is the reservation grown by `renderBoost` — so the same emoji was
    /// 17.9pt expanded and 21.9pt folded.
    ///
    /// Both halves are asserted. Equality alone is satisfied by dropping the boost on BOTH sides,
    /// which would make the two states agree at a size neither the legacy canvas nor the V2 renderer
    /// draws; the second assertion pins which of the two answers was the correct one.
    func test_aCustomEmojiIsTheSameSizeFoldedAndExpanded() {
        let children: [Block] = [para("a", [run("hi "),
                                            run("", emoji: EmojiRef(id: "e1", instanceID: "i1"))])]
        loadFoldedWithEmoji(children)
        guard let folded = editor.collapsedQuoteViews[BlockID("q")]?.emojiViews["i1"]?.frame.size else {
            teardownWindow(); return XCTFail("no hosted emoji in the folded quote")
        }
        teardownWindow()

        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window.addSubview(editor); window.makeKeyAndVisible()
        editor.registerEmojiViewProvider { _, _ in StubEmojiView() }
        editor.document = Document(blocks: [.blockQuote(BlockQuote(
            id: BlockID("q"), children: children, collapsed: false))])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        defer { teardownWindow() }

        guard let occurrence = editor.emojiOccurrences().first,
              let expanded = editor.customEmojiViews["i1"]?.frame.size else {
            return XCTFail("no hosted emoji in the expanded quote")
        }
        XCTAssertEqual(folded.width, expanded.width, accuracy: 0.01)
        XCTAssertEqual(folded.height, expanded.height, accuracy: 0.01)

        let reserved = editor.engine.id_attachmentFrame(
            forCanonicalOffset: UInt(occurrence.range.location))
        // Read off the attachment the document actually carries, not re-derived from a mapper: the
        // boost is the attachment's own property, and the box and the number describing it then
        // cannot come from two different documents.
        let roleIndex = editor.roleIndex(atFlatOffset: occurrence.range.location) ?? 0
        let block = editor.engine.attributedBlocks[roleIndex]
        let local = occurrence.range.location - editor.flatOffset(ofRoleAt: roleIndex)
        guard let emoji = block.attribute(.attachment, at: local, effectiveRange: nil)
                as? EmojiTextAttachment else { return XCTFail("no emoji attachment in the engine") }
        let boost = emoji.renderBoost
        XCTAssertGreaterThan(boost, 0, "the fixture must be a style that boosts, or this proves nothing")
        XCTAssertEqual(expanded.height, reserved.height + boost, accuracy: 0.01,
                       "the VISIBLE box is the reservation grown by renderBoost — what legacy draws")
    }

    // MARK: - Task 6: a spoiler in a folded quote stays hidden

    /// THE leak case. A spoiler hides TEXT with a foreground colour, which does nothing to a hosted
    /// view — so an emoji inside a spoiler would sit fully visible behind the dust. The live editor
    /// fixes this and records that LEGACY HAS THE BUG TODAY.
    ///
    /// All three assertions live in one case on purpose: satisfied separately they are three
    /// features that happen to coexist; together they are the invariant. A folded quote is also the
    /// one place a reader cannot open the spoiler to check.
    func test_aSpoilerInAFoldedQuoteHidesItsTextItsEmojiAndIsDusted() {
        loadFoldedWithEmoji([para("a", [
            run("open "),
            run("secret", spoiler: true),
            run("", spoiler: true, emoji: EmojiRef(id: "e1", instanceID: "i1")),
        ])])
        defer { teardownWindow() }
        guard let preview = editor.collapsedQuoteViews[BlockID("q")] else {
            return XCTFail("no preview view")
        }
        XCTAssertFalse(preview.hiddenSpoilerRangesForTesting.isEmpty,
                       "the spoilered run's glyphs are hidden")
        XCTAssertFalse(preview.dustViews.isEmpty, "and dusted")
        XCTAssertEqual(preview.emojiViews["i1"]?.isHidden, true,
                       "AND the hosted emoji is hidden — a foreground colour does nothing to a view")
    }

    /// The other half of the same rule: nothing is hidden when nothing is spoilered, so the case
    /// above cannot pass by hiding everything.
    func test_aFoldedQuoteWithoutSpoilersHidesNothing() {
        loadFoldedWithEmoji([para("a", [run("open "), run("", emoji: EmojiRef(id: "e1", instanceID: "i1"))])])
        defer { teardownWindow() }
        guard let preview = editor.collapsedQuoteViews[BlockID("q")] else {
            return XCTFail("no preview view")
        }
        XCTAssertTrue(preview.hiddenSpoilerRangesForTesting.isEmpty)
        XCTAssertTrue(preview.dustViews.isEmpty)
        XCTAssertEqual(preview.emojiViews["i1"]?.isHidden, false)
    }
}
