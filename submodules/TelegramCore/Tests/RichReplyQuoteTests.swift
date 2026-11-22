import XCTest
import Postbox
@testable import TelegramCore

/// Rich reply quotes are built and checked against the server's rule: one fragment per covered text
/// node, the first a suffix of its node, the last a prefix, every node between whole.
final class RichReplyQuoteTests: XCTestCase {
    private func page(_ blocks: [InstantPageBlock]) -> InstantPage {
        return InstantPage(blocks: blocks, media: [:], isComplete: true, rtl: false, url: "", views: nil)
    }

    private func id(_ path: [Int], _ part: InstantPageTextNodeId.Part = .text) -> InstantPageTextNodeId {
        return InstantPageTextNodeId(blockPath: path, part: part)
    }

    private func quote(_ nodes: [InstantPageQuotableNode], _ start: ([Int], Int), _ end: ([Int], Int), maxLength: Int = 1024) -> EngineMessageReplyQuote? {
        return makeRichReplyQuote(nodes: nodes, start: RichQuoteBoundary(node: id(start.0), flatOffset: start.1), end: RichQuoteBoundary(node: id(end.0), flatOffset: end.1), maxLength: maxLength)
    }

    private var specNodes: [InstantPageQuotableNode] {
        return page([
            .paragraph(.concat([.plain("Релиз в "), .bold(.plain("пятницу")), .plain(", не опаздывать")])),
            .paragraph(.plain("Созвон по ссылке в календаре"))
        ]).quotableNodes
    }

    func testSpecExample() {
        let result = quote(specNodes, ([0], 8), ([1], 9))
        XCTAssertEqual(result?.richText, [.concat([.bold(.plain("пятницу")), .plain(", не опаздывать")]), .plain("Созвон по")])
        XCTAssertEqual(result?.text, "пятницу, не опаздывать\nСозвон по")
        XCTAssertEqual(result?.offset, 8)
        XCTAssertTrue(richReplyQuoteMatches(result?.richText ?? [], nodes: specNodes))
    }

    func testSpecInvalidVariantsAreRejected() {
        let nodes = specNodes
        XCTAssertFalse(richReplyQuoteMatches([.plain("пятницу, не опаздывать"), .plain("Созвон по")], nodes: nodes))
        XCTAssertFalse(richReplyQuoteMatches([.bold(.plain("пятницу, не опаздывать")), .plain("Созвон по")], nodes: nodes))
        XCTAssertFalse(richReplyQuoteMatches([.concat([.plain("пятницу, не опаздывать"), .plain("Созвон по")])], nodes: nodes))
        // The fourth variant ("Созвон по" alone) is only wrong for a selection that began in the first
        // paragraph: the builder never produces it for one.
        XCTAssertNotEqual(quote(nodes, ([0], 8), ([1], 9))?.richText, [.plain("Созвон по")])
    }

    func testSelectionInsideOneNodeIsCutOnBothSides() {
        let result = quote(specNodes, ([0], 2), ([0], 12))
        XCTAssertEqual(result?.richText, [.concat([.plain("лиз в "), .bold(.plain("пятн"))])])
        XCTAssertEqual(result?.offset, 2)
        XCTAssertTrue(richReplyQuoteMatches(result?.richText ?? [], nodes: specNodes))
    }

    func testMiddleNodesAreKeptWhole() {
        let middle: RichText = .concat([.italic(.plain("mid ")), .url(text: .plain("link"), url: "https://t.me", webpageId: nil)])
        let nodes = page([.paragraph(.plain("first")), .paragraph(middle), .paragraph(.plain("last"))]).quotableNodes
        let result = quote(nodes, ([0], 2), ([2], 2))
        XCTAssertEqual(result?.richText, [.plain("rst"), middle, .plain("la")])
        XCTAssertEqual(result?.offset, 2)
        XCTAssertTrue(richReplyQuoteMatches(result?.richText ?? [], nodes: nodes))
    }

    func testNodeTableOrder() {
        let image = MediaId(namespace: 0, id: 1)
        let caption = InstantPageCaption(text: .plain("ct"), credit: .plain("cc"))
        let button = InstantPageButton(text: .plain("b"), action: .url(""), color: nil)
        let cell = { (text: String) in InstantPageTableCell(text: .plain(text), header: false, alignment: .left, verticalAlignment: .top, colspan: 1, rowspan: 1) }
        let nodes = page([
            .heading(text: .plain("h"), level: 1),
            .list(items: [.text(.plain("li"), nil, nil), .blocks([.paragraph(.plain("lb"))], nil, nil)], ordered: false),
            .blockQuote(blocks: [.paragraph(.plain("q"))], caption: .plain("qc"), collapsed: false),
            .pullQuote(text: .plain("p"), caption: .plain("pc")),
            .table(title: .plain("tt"), rows: [InstantPageTableRow(cells: [cell("a"), cell("b")]), InstantPageTableRow(cells: [cell("c")])], bordered: false, striped: false, compact: false),
            .details(title: .plain("dt"), blocks: [.paragraph(.plain("d"))], expanded: false),
            .image(id: image, caption: caption, url: nil, webpageId: nil, spoiler: false),
            .collage(items: [.image(id: image, caption: caption, url: nil, webpageId: nil, spoiler: false)], caption: caption),
            .formula(latex: "x"),
            .divider,
            .anchor("a"),
            .buttonRow(alignment: .center, buttons: [button]),
            .document(id: image, caption: caption),
            .title(.plain("t")),
            .footer(.plain("f")),
            .thinking(.plain("th")),
            .preformatted(text: .plain("code"), language: nil)
        ]).quotableNodes
        XCTAssertEqual(nodes.map(\.id), [
            id([0]), id([1, 0]), id([1, 1, 0]), id([2, 0]), id([2], .captionText), id([3]), id([3], .captionText),
            id([4], .title), id([4], .cell(row: 0, column: 0)), id([4], .cell(row: 0, column: 1)), id([4], .cell(row: 1, column: 0)),
            id([5], .title), id([5, 0]), id([6], .captionText), id([6], .captionCredit),
            id([7, 0], .captionText), id([7, 0], .captionCredit), id([7], .captionText), id([7], .captionCredit),
            id([8]), id([14]), id([15]), id([16])
        ])
        XCTAssertEqual(nodes[19].text, .formula(latex: "x"))
    }

    func testEmptyNodesAreSkipped() {
        let nodes = page([
            .paragraph(.plain("")),
            .image(id: MediaId(namespace: 0, id: 1), caption: InstantPageCaption(text: .empty, credit: .empty), url: nil, webpageId: nil, spoiler: false),
            .table(title: .empty, rows: [InstantPageTableRow(cells: [InstantPageTableCell(text: nil, header: false, alignment: .left, verticalAlignment: .top, colspan: 1, rowspan: 1)])], bordered: false, striped: false, compact: false),
            .paragraph(.image(id: MediaId(namespace: 0, id: 2), dimensions: PixelDimensions(width: 1, height: 1))),
            .paragraph(.plain("x"))
        ]).quotableNodes
        XCTAssertEqual(nodes.map(\.id), [id([4])])
    }

    func testAtomsAreNeverCut() {
        // Flat text "a x^2 b 👍 c": the formula is 2..<5, the emoji 8..<10.
        let nodes = page([.paragraph(.concat([.plain("a "), .formula(latex: "x^2"), .plain(" b "), .textCustomEmoji(fileId: 1, alt: "👍"), .plain(" c")]))]).quotableNodes
        let intoFormula = quote(nodes, ([0], 3), ([0], 4))
        XCTAssertEqual(intoFormula?.richText, [.concat([.formula(latex: "x^2")])])
        XCTAssertEqual(intoFormula?.offset, 2)
        let intoEmoji = quote(nodes, ([0], 9), ([0], 12))
        XCTAssertEqual(intoEmoji?.richText, [.concat([.textCustomEmoji(fileId: 1, alt: "👍"), .plain(" c")])])
        XCTAssertEqual(intoEmoji?.offset, 8)
    }

    func testButtonsBecomePlainTextAndImagesAreDropped() {
        let button = InstantPageButton(text: .bold(.plain("Go")), action: .url(""), color: nil)
        let image: RichText = .image(id: MediaId(namespace: 0, id: 1), dimensions: PixelDimensions(width: 1, height: 1))
        let nodes = page([.paragraph(.plain("x")), .paragraph(.concat([.plain("a"), .textButton(button), image, .plain("b")])), .paragraph(.plain("y"))]).quotableNodes
        let result = quote(nodes, ([0], 0), ([2], 1))
        XCTAssertEqual(result?.richText, [.plain("x"), .concat([.plain("a"), .plain("Go"), .plain("b")]), .plain("y")])
        XCTAssertTrue(richReplyQuoteMatches(result?.richText ?? [], nodes: nodes))
    }

    func testHiddenMiddleNodesAreIncludedWhole() {
        let nodes = page([
            .paragraph(.plain("before")),
            .details(title: .plain("title"), blocks: [.paragraph(.plain("hidden"))], expanded: false),
            .paragraph(.plain("after"))
        ]).quotableNodes
        let result = quote(nodes, ([0], 3), ([2], 2))
        XCTAssertEqual(result?.richText, [.plain("ore"), .plain("title"), .plain("hidden"), .plain("af")])
        XCTAssertTrue(richReplyQuoteMatches(result?.richText ?? [], nodes: nodes))
    }

    func testWhitespaceTrimMovesOffset() {
        let nodes = page([.paragraph(.plain("Hello world")), .paragraph(.plain("  next"))]).quotableNodes
        let result = quote(nodes, ([0], 5), ([1], 2))
        XCTAssertEqual(result?.richText, [.plain("world")])
        XCTAssertEqual(result?.offset, 6)
    }

    func testReversedBoundariesAreOrdered() {
        XCTAssertEqual(quote(specNodes, ([1], 9), ([0], 8))?.richText, quote(specNodes, ([0], 8), ([1], 9))?.richText)
    }

    func testLimits() {
        let many = page((0 ..< 40).map { _ in .paragraph(.plain("p")) }).quotableNodes
        let manyQuote = makeRichReplyQuote(nodes: many, start: RichQuoteBoundary(node: many[0].id, flatOffset: 0), end: RichQuoteBoundary(node: many[39].id, flatOffset: 1), maxLength: 1024)
        XCTAssertEqual(manyQuote?.richText?.count, 32)

        let long = page([.paragraph(.plain(String(repeating: "a", count: 2000)))]).quotableNodes
        XCTAssertEqual(quote(long, ([0], 0), ([0], 2000))?.text.count, 1024)

        let two = page([.paragraph(.plain("aaaa")), .paragraph(.plain("bbbb"))]).quotableNodes
        XCTAssertEqual(quote(two, ([0], 0), ([1], 4), maxLength: 6)?.richText, [.plain("aaaa"), .plain("b")])
    }

    func testCutDoesNotSplitAtoms() {
        let nodes = page([.paragraph(.concat([.plain("abc"), .formula(latex: "xyz")]))]).quotableNodes
        XCTAssertEqual(quote(nodes, ([0], 0), ([0], 6), maxLength: 4)?.richText, [.concat([.plain("abc")])])
        let pair = page([.paragraph(.plain("ab😀"))]).quotableNodes
        XCTAssertEqual(quote(pair, ([0], 0), ([0], 4), maxLength: 3)?.richText, [.plain("ab")])
    }

    func testWholePageQuote() {
        let result = page([.paragraph(.plain("one")), .divider, .paragraph(.plain("two"))]).wholeRichReplyQuote(maxLength: 1024, media: nil)
        XCTAssertEqual(result?.richText, [.plain("one"), .plain("two")])
        XCTAssertEqual(result?.offset, 0)
    }

    // A table's spanning cell is laid out after its last row's cells, so a selection's runs arrive
    // out of document order: [[A (rowspan 2), B], [C]] lays out as B, A, C. Dragging from inside B
    // into A must quote from A to B, not the complement.
    func testSelectionBoundariesFollowDocumentOrder() {
        let cell = { (text: String, rowspan: Int32) in InstantPageTableCell(text: .plain(text), header: false, alignment: .left, verticalAlignment: .top, colspan: 1, rowspan: rowspan) }
        let nodes = page([.table(title: .empty, rows: [InstantPageTableRow(cells: [cell("Aaaa", 2), cell("Bbbb", 1)]), InstantPageTableRow(cells: [cell("Cccc", 1)])], bordered: false, striped: false, compact: false)]).quotableNodes
        let a = id([0], .cell(row: 0, column: 0))
        let b = id([0], .cell(row: 0, column: 1))
        let c = id([0], .cell(row: 1, column: 0))
        let bounds = richQuoteSelectionBoundaries(nodes: nodes, runs: [(id: b, range: 2 ..< 4), (id: a, range: 0 ..< 1)])
        XCTAssertEqual(bounds?.start, RichQuoteBoundary(node: a, flatOffset: 0))
        XCTAssertEqual(bounds?.end, RichQuoteBoundary(node: b, flatOffset: 4))
        let throughC = richQuoteSelectionBoundaries(nodes: nodes, runs: [(id: b, range: 2 ..< 4), (id: a, range: 0 ..< 4), (id: c, range: 0 ..< 2)])
        XCTAssertEqual(throughC?.start, RichQuoteBoundary(node: a, flatOffset: 0))
        XCTAssertEqual(throughC?.end, RichQuoteBoundary(node: c, flatOffset: 2))
    }

    // An empty list item is laid out as a placeholder space under an id the enumerator skips.
    func testSelectionRunsOfUnknownNodesAreIgnored() {
        let nodes = specNodes
        let stray = id([9])
        let bounds = richQuoteSelectionBoundaries(nodes: nodes, runs: [(id: id([0]), range: 8 ..< 30), (id: stray, range: 0 ..< 1)])
        XCTAssertEqual(bounds?.start, RichQuoteBoundary(node: id([0]), flatOffset: 8))
        XCTAssertEqual(bounds?.end, RichQuoteBoundary(node: id([0]), flatOffset: 30))
        XCTAssertNil(richQuoteSelectionBoundaries(nodes: nodes, runs: [(id: stray, range: 0 ..< 1)]))
    }

    // A long rich message shows a partial page until Show more; its last node may be cut short and
    // the rest of the page is not there. The pre-send check verifies what it can.
    func testPartialPageValidation() {
        let partial = page([.paragraph(.plain("one")), .paragraph(.plain("two")), .paragraph(.plain("thr"))]).quotableNodes
        // Wholly inside verified nodes: checked strictly, so an edit is caught.
        XCTAssertTrue(richReplyQuoteMatches([.plain("ne"), .plain("tw")], nodes: partial, isPartialPage: true, offset: 1))
        XCTAssertFalse(richReplyQuoteMatches([.plain("nX"), .plain("tw")], nodes: partial, isPartialPage: true, offset: 1))
        // Running into the cut node: the fragment may be longer than what is shown.
        XCTAssertTrue(richReplyQuoteMatches([.plain("two"), .plain("three")], nodes: partial, isPartialPage: true, offset: 4))
        XCTAssertFalse(richReplyQuoteMatches([.plain("two"), .plain("tXree")], nodes: partial, isPartialPage: true, offset: 4))
        // Running past the shown nodes, or starting in the cut node: unverifiable, let through.
        XCTAssertTrue(richReplyQuoteMatches([.plain("two"), .plain("three"), .plain("four")], nodes: partial, isPartialPage: true, offset: 4))
        XCTAssertTrue(richReplyQuoteMatches([.plain("ee"), .plain("four")], nodes: partial, isPartialPage: true, offset: 11))
        XCTAssertTrue(richReplyQuoteMatches([.plain("anything")], nodes: partial, isPartialPage: true, offset: nil))
        // A complete page is checked strictly as before.
        XCTAssertFalse(richReplyQuoteMatches([.plain("two"), .plain("three")], nodes: partial, isPartialPage: false, offset: 4))
    }

    // A block this build cannot decode (or a list item of unknown kind) may hold text the server counts:
    // a quote across it would skip that text, so it ends before it.
    func testOpaqueContentEndsTheQuote() {
        let nodes = page([
            .paragraph(.plain("aa")),
            .unsupported,
            .paragraph(.plain("bb")),
            .list(items: [.unknown, .text(.plain("cc"), nil, nil)], ordered: false)
        ]).quotableNodes
        XCTAssertEqual(nodes.map(\.followsOpaqueContent), [false, true, true])
        XCTAssertEqual(quote(nodes, ([0], 1), ([2], 2))?.richText, [.plain("a")])
        XCTAssertEqual(quote(nodes, ([2], 0), ([3, 1], 2))?.richText, [.plain("bb")])
        XCTAssertEqual(quote(nodes, ([2], 1), ([2], 2))?.richText, [.plain("b")])
    }

    // An emoji sequence (a skin tone, a flag) is several UTF-16 units and is never split.
    func testBoundariesAndCutsKeepGraphemeClustersWhole() {
        let skin = page([.paragraph(.plain("ab👍🏽"))]).quotableNodes
        XCTAssertEqual(quote(skin, ([0], 0), ([0], 6), maxLength: 4)?.richText, [.plain("ab")])
        let flag = page([.paragraph(.plain("ab🇺🇦cd"))]).quotableNodes
        let result = quote(flag, ([0], 4), ([0], 8))
        XCTAssertEqual(result?.richText, [.plain("🇺🇦cd")])
        XCTAssertEqual(result?.offset, 2)
    }

    // A length cut is a new end: it is trimmed like the selection's own.
    func testLengthCutIsTrimmed() {
        let nodes = page([.paragraph(.plain("aaaa")), .paragraph(.plain("bb  cc"))]).quotableNodes
        XCTAssertEqual(quote(nodes, ([0], 0), ([1], 6), maxLength: 8)?.richText, [.plain("aaaa"), .plain("bb")])
    }

    func testNodeRangesFindNearestOccurrence() {
        let nodes = page([.paragraph(.plain("ab ab")), .paragraph(.plain("ab"))]).quotableNodes
        XCTAssertEqual(richReplyQuoteFlatText(nodes), "ab ab\nab")
        let near = richReplyQuoteNodeRanges(nodes: nodes, quoteText: "ab", offset: 6)
        XCTAssertEqual(near.map(\.id), [id([1])])
        XCTAssertEqual(near.map(\.range), [0 ..< 2])
        let spanning = richReplyQuoteNodeRanges(nodes: nodes, quoteText: "ab\nab", offset: 3)
        XCTAssertEqual(spanning.map(\.id), [id([0]), id([1])])
        XCTAssertEqual(spanning.map(\.range), [3 ..< 5, 0 ..< 2])
        XCTAssertTrue(richReplyQuoteNodeRanges(nodes: nodes, quoteText: "zz", offset: nil).isEmpty)
    }
}
