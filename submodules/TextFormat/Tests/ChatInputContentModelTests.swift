import XCTest
import TelegramCore
import Postbox
@testable import TextFormat

final class ChatInputContentModelTests: XCTestCase {
    func test_inlineEntity_equatable_byValue() {
        XCTAssertEqual(ChatInputInlineEntity.mention(EnginePeer.Id(7)), .mention(EnginePeer.Id(7)))
        XCTAssertNotEqual(ChatInputInlineEntity.mention(EnginePeer.Id(7)), .mention(EnginePeer.Id(8)))
        XCTAssertEqual(ChatInputInlineEntity.url("a"), .url("a"))
        XCTAssertEqual(ChatInputInlineEntity.date(5), .date(5))
        XCTAssertNotEqual(ChatInputInlineEntity.url("a"), .date(5))
    }

    func test_run_equatable() {
        var a = ChatInputInlineAttributes(); a.bold = true
        XCTAssertEqual(ChatInputRun(text: "x", attributes: a), ChatInputRun(text: "x", attributes: a))
        var b = ChatInputInlineAttributes(); b.italic = true
        XCTAssertNotEqual(ChatInputRun(text: "x", attributes: a), ChatInputRun(text: "x", attributes: b))
    }

    func test_content_equatable_andText() {
        let p = ChatInputParagraph(style: .body, runs: [ChatInputRun(text: "ab")])
        let code = ChatInputCode(language: "swift", runs: [ChatInputRun(text: "x\ny")])
        let c1 = ChatInputContent(blocks: [.paragraph(p), .code(code)])
        XCTAssertEqual(c1, ChatInputContent(blocks: [.paragraph(p), .code(code)]))
        XCTAssertNotEqual(c1, ChatInputContent(blocks: [.paragraph(p)]))
    }

    // MARK: - Structural selection + content-aware bridge (Piece 5 stage 1)

    /// Fixture: body "ab" / code "x\ny" / blockQuote(collapsed: true) — plainText "ab\nx\ny\n " (length 8).
    private func bridgeFixture() -> ChatInputContent {
        ChatInputContent(blocks: [
            .paragraph(ChatInputParagraph(style: .body, runs: [ChatInputRun(text: "ab")])),
            .code(ChatInputCode(language: "swift", runs: [ChatInputRun(text: "x\ny")])),
            .blockQuote(ChatInputBlockQuote(
                content: ChatInputContent(blocks: [.paragraph(ChatInputParagraph(style: .body, runs: [ChatInputRun(text: "z")]))]),
                collapsed: true)),
        ])
    }

    /// The bridge must be a bijection over flat offsets: `init(nsRange:in:)` then `nsRange(in:)` = identity for
    /// every range (including collapsed carets and ranges straddling inter-block "\n").
    func test_selection_bridge_roundTripsEveryFlatNSRange() {
        let content = bridgeFixture()
        let total = (content.plainText as NSString).length
        XCTAssertEqual(total, 8)
        for loc in 0 ... total {
            for len in 0 ... (total - loc) {
                let r = NSRange(location: loc, length: len)
                XCTAssertEqual(ChatInputSelection(nsRange: r, in: content).nsRange(in: content), r, "round-trip failed for \(r)")
            }
        }
    }

    /// Depth-1 positions + the inter-block boundary convention (`end of block i` and `start of block i+1` are
    /// distinct consecutive offsets straddling the separator "\n").
    func test_position_depth1_blockBoundaries() {
        let content = bridgeFixture() // "ab"=[0,2] \n=2 "x\ny"=[3,6] \n=6 " "=[7,8]
        XCTAssertEqual(content.position(forFlatOffset: 2), ChatInputPosition(path: [ChatInputPathStep(blockIndex: 0)], offset: 2)) // end of block 0
        XCTAssertEqual(content.position(forFlatOffset: 3), ChatInputPosition(path: [ChatInputPathStep(blockIndex: 1)], offset: 0)) // start of block 1
        XCTAssertEqual(content.position(forFlatOffset: 7), ChatInputPosition(path: [ChatInputPathStep(blockIndex: 2)], offset: 0)) // before collapsed placeholder
        XCTAssertEqual(content.position(forFlatOffset: 8), ChatInputPosition(path: [ChatInputPathStep(blockIndex: 2)], offset: 1)) // after it
        // flatOffset is the inverse
        XCTAssertEqual(content.flatOffset(for: ChatInputPosition(path: [ChatInputPathStep(blockIndex: 1)], offset: 0)), 3)
        XCTAssertEqual(content.flatOffset(for: ChatInputPosition(path: [ChatInputPathStep(blockIndex: 2)], offset: 1)), 8)
    }

    func test_selection_isCollapsed_andEquatable() {
        let content = ChatInputContent(blocks: [.paragraph(ChatInputParagraph(style: .body, runs: [ChatInputRun(text: "abcd")]))])
        XCTAssertTrue(ChatInputSelection(nsRange: NSRange(location: 2, length: 0), in: content).isCollapsed)
        XCTAssertFalse(ChatInputSelection(nsRange: NSRange(location: 1, length: 3), in: content).isCollapsed)
        XCTAssertEqual(
            ChatInputSelection(nsRange: NSRange(location: 1, length: 3), in: content),
            ChatInputSelection(nsRange: NSRange(location: 1, length: 3), in: content)
        )
    }

    func test_isEmpty_matchesPlainTextIsEmpty() {
        func p(_ s: String) -> ChatInputBlock { .paragraph(ChatInputParagraph(style: .body, runs: s.isEmpty ? [] : [ChatInputRun(text: s)])) }
        let cases: [ChatInputContent] = [
            ChatInputContent(),                                   // no blocks
            ChatInputContent(blocks: [p("")]),                    // single empty paragraph
            ChatInputContent(blocks: [p("a")]),                   // single non-empty
            ChatInputContent(blocks: [p(""), p("")]),             // two empty paragraphs -> "\n" -> non-empty
            ChatInputContent(blocks: [.blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: [p("x")]), collapsed: true))]), // collapsed placeholder -> non-empty
            ChatInputContent(blocks: [.code(ChatInputCode(runs: []))]),                      // single empty code
        ]
        for c in cases {
            XCTAssertEqual(c.isEmpty, c.plainText.isEmpty, "isEmpty must match plainText.isEmpty for \(c.plainText.debugDescription)")
            XCTAssertEqual(c.isEmpty, c.length == 0)
        }
    }

    func test_position_emptyContent_isSafe() {
        let empty = ChatInputContent()
        XCTAssertEqual(empty.position(forFlatOffset: 0), ChatInputPosition(path: [ChatInputPathStep(blockIndex: 0)], offset: 0))
        XCTAssertEqual(empty.flatOffset(for: ChatInputPosition(path: [ChatInputPathStep(blockIndex: 0)], offset: 0)), 0)
        XCTAssertEqual(ChatInputSelection(nsRange: NSRange(location: 0, length: 0), in: empty).nsRange(in: empty), NSRange(location: 0, length: 0))
    }

    /// Media/table blocks are OFF the flat coordinate axis — they contribute ZERO characters AND no separator,
    /// exactly as `attributedString(from:)` drops them and the editor's `composerParagraphs()` skips them.
    /// (Regression for the native-composer caret drift: media/table were given a 1-char placeholder bracketed
    /// by separators, so the model's flat space disagreed with the editor's `composerSelectedRange` — the caret
    /// drifted into the non-text block by the count of preceding non-text blocks. `.blockQuote(collapsed: true)`
    /// is the only off-string block that DOES contribute a " " placeholder.)
    func test_flatCoordinates_mediaAndTable_areOffAxis() {
        func p(_ s: String) -> ChatInputBlock { .paragraph(ChatInputParagraph(style: .body, runs: [ChatInputRun(text: s)])) }
        let image = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 7), representations: [], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
        let media = ChatInputMedia(media: image, kind: .image, naturalSize: ChatInputSize(width: 1.0, height: 1.0))
        let table = ChatInputTable(columns: [ChatInputColumnSpec(width: 10.0)], rows: [])
        // [ "ab", media, "xy", table ] — the two non-text blocks sit between/after the paragraphs.
        let content = ChatInputContent(blocks: [p("ab"), .media(media), p("xy"), .table(table)])

        // The flat text drops media/table entirely: paragraphs joined by ONE "\n", no placeholder, no extra
        // separator — and it equals the `NSAttributedString` projection exactly (the documented invariant).
        XCTAssertEqual(content.plainText, "ab\nxy")
        XCTAssertEqual(content.length, 5)
        XCTAssertEqual(content.plainText, attributedString(from: content).string)

        // The caret at the end of "xy" is flat offset 5 (NOT 6/7 with phantom media/table placeholders).
        XCTAssertEqual(content.flatOffset(for: ChatInputPosition(path: [ChatInputPathStep(blockIndex: 2)], offset: 2)), 5)
        // The start of "xy" is flat offset 3 — and the inverse maps offset 3 back to block 2 (the paragraph),
        // never the intervening media block (block 1, which has no flat position).
        XCTAssertEqual(content.flatOffset(for: ChatInputPosition(path: [ChatInputPathStep(blockIndex: 2)], offset: 0)), 3)
        XCTAssertEqual(content.position(forFlatOffset: 3), ChatInputPosition(path: [ChatInputPathStep(blockIndex: 2)], offset: 0))
        XCTAssertEqual(content.position(forFlatOffset: 2), ChatInputPosition(path: [ChatInputPathStep(blockIndex: 0)], offset: 2))

        // Full bijection over every flat NSRange (collapsed carets + spanning ranges).
        let total = (content.plainText as NSString).length
        for loc in 0 ... total {
            for len in 0 ... (total - loc) {
                let r = NSRange(location: loc, length: len)
                XCTAssertEqual(ChatInputSelection(nsRange: r, in: content).nsRange(in: content), r, "round-trip failed for \(r)")
            }
        }

        // A media-only content has empty flat text but is NOT `isEmpty` (a media block is content).
        let mediaOnly = ChatInputContent(blocks: [.media(media)])
        XCTAssertEqual(mediaOnly.plainText, "")
        XCTAssertTrue(mediaOnly.plainText.isEmpty)
        XCTAssertFalse(mediaOnly.isEmpty)
    }

    // MARK: - Codable round-trip

    /// The content model round-trips losslessly through JSON for every block/run/entity/style case. Note: the
    /// `customEmoji` `file` is intentionally not persisted (decoded as nil) — but the model's `==` compares only
    /// fileId + enableAnimation, so dropping `file` still yields identity.
    func test_codable_roundTripsModelIdentity() throws {
        var bold = ChatInputInlineAttributes(); bold.bold = true
        var emoji = ChatInputInlineAttributes(); emoji.entity = .customEmoji(fileId: 42, file: nil, enableAnimation: true)
        var mention = ChatInputInlineAttributes(); mention.entity = .mention(EnginePeer.Id(7))
        var formula = ChatInputInlineAttributes(); formula.formula = "e^{I\\pi}=-1"

        let bodyParagraph = ChatInputParagraph(style: .body, runs: [
            ChatInputRun(text: "plain"),
            ChatInputRun(text: "strong", attributes: bold),
            ChatInputRun(text: "\u{FFFC}", attributes: emoji),
            ChatInputRun(text: "@me", attributes: mention),
            ChatInputRun(text: "e^{I\\pi}=-1", attributes: formula),
        ])
        let heading1 = ChatInputParagraph(style: .heading1, runs: [ChatInputRun(text: "first line")])
        let heading2 = ChatInputParagraph(style: .heading2, runs: [ChatInputRun(text: "second line")])
        let code = ChatInputCode(language: "swift", runs: [ChatInputRun(text: "let x = 1\nprint(x)")])
        let folded = ChatInputContent(blocks: [
            .paragraph(ChatInputParagraph(style: .body, runs: [ChatInputRun(text: "hidden")])),
        ])

        let content = ChatInputContent(schemaVersion: 2, blocks: [
            .paragraph(bodyParagraph),
            .paragraph(heading1),
            .paragraph(heading2),
            .code(code),
            .blockQuote(ChatInputBlockQuote(content: folded, collapsed: true)),
        ])

        // Encode via AdaptedPostbox — the REAL persistence path (ChatTextInputState stores the model under "cm"
        // through AdaptedPostboxEncoder), NOT JSON. JSON masks the Postbox coder's lack of `singleValueContainer`
        // (which a `RawRepresentable` enum's synthesized Codable uses) and bare `Int` support, so the enum
        // discriminators must persist as `Int32` rawValues — this test guards exactly that.
        let data = try AdaptedPostboxEncoder().encode(content)
        let decoded = try AdaptedPostboxDecoder().decode(ChatInputContent.self, from: data)
        XCTAssertEqual(decoded, content)
    }

    // MARK: - Structural (Document-parity) Codable round-trip

    /// The full Document-parity block set — a heading, two list paragraphs (bullet then ordered), a table (2
    /// columns, a header row + a body row, inline-text cells, one cell with a background), and a
    /// media block (a real `TelegramMediaImage` carried as a Postbox object blob) — round-trips losslessly through
    /// the REAL persistence path (`AdaptedPostbox*coder`), NOT JSON. This guards the new raw enums' keyed-rawValue
    /// Codable (no `singleValueContainer`) and the `Media`-blob encode/decode.
    func test_codable_structuralBlocks_roundTripsViaAdaptedPostbox() throws {
        let heading = ChatInputParagraph(style: .heading1, runs: [ChatInputRun(text: "Title")])
        let bullet = ChatInputParagraph(
            style: .body,
            list: ChatInputListMembership(marker: .bullet, level: 0),
            runs: [ChatInputRun(text: "first item")]
        )
        let ordered = ChatInputParagraph(
            style: .body,
            list: ChatInputListMembership(marker: .ordered, level: 1),
            runs: [ChatInputRun(text: "second item")]
        )

        let table = ChatInputTable(
            columns: [
                ChatInputColumnSpec(width: 100.0),
                ChatInputColumnSpec(width: 200.0),
            ],
            rows: [
                ChatInputTableRow(height: 30.0, isHeader: true, cells: [
                    ChatInputTableCell(runs: [ChatInputRun(text: "H1")]),
                    ChatInputTableCell(runs: [ChatInputRun(text: "H2")], background: ChatInputColor(red: 0.1, green: 0.2, blue: 0.3, alpha: 1.0)),
                ]),
                ChatInputTableRow(height: nil, isHeader: false, cells: [
                    ChatInputTableCell(runs: [ChatInputRun(text: "a")]),
                    ChatInputTableCell(runs: [ChatInputRun(text: "b")]),
                ]),
            ]
        )

        let image = TelegramMediaImage(
            imageId: MediaId(namespace: 0, id: 42),
            representations: [],
            immediateThumbnailData: nil,
            reference: nil,
            partialReference: nil,
            flags: []
        )
        let media = ChatInputMedia(
            media: image,
            kind: .image,
            naturalSize: ChatInputSize(width: 640.0, height: 480.0),
            displayWidth: 320.0,
            alignment: .center,
            caption: [ChatInputRun(text: "caption")]
        )

        let content = ChatInputContent(schemaVersion: 3, blocks: [
            .paragraph(heading),
            .paragraph(bullet),
            .paragraph(ordered),
            .table(table),
            .media(media),
        ])

        let data = try AdaptedPostboxEncoder().encode(content)
        let decoded = try AdaptedPostboxDecoder().decode(ChatInputContent.self, from: data)
        XCTAssertEqual(decoded, content)
    }

    /// Belt-and-suspenders: a table with NON-DEFAULT colspan/rowspan round-trips through the REAL
    /// persistence path (`AdaptedPostbox*coder`). The structural test above only exercises the default
    /// span (1); this pins that the span wire encoding (`Int` bridged as `Int32` — Postbox has no bare-`Int`
    /// container, which `assertionFailure`s in debug) survives a non-1 value too.
    func test_codable_tableWithSpans_roundTripsViaAdaptedPostbox() throws {
        var merged = ChatInputTableCell(runs: [ChatInputRun(text: "M")])
        merged.colspan = 2
        merged.rowspan = 2
        let table = ChatInputTable(
            columns: [ChatInputColumnSpec(width: 100.0), ChatInputColumnSpec(width: 100.0)],
            rows: [
                // Row 0: one 2x2 anchor (covers both columns, both rows) — the other three slots are absent.
                ChatInputTableRow(height: nil, cells: [merged]),
                // Row 1: fully covered by the rowspan — no declared cells.
                ChatInputTableRow(height: nil, cells: []),
            ]
        )
        let content = ChatInputContent(schemaVersion: 3, blocks: [.table(table)])
        let data = try AdaptedPostboxEncoder().encode(content)
        let decoded = try AdaptedPostboxDecoder().decode(ChatInputContent.self, from: data)
        XCTAssertEqual(decoded, content)
        // Explicitly confirm the spans survived (not just structural equality).
        guard case .table(let out)? = decoded.blocks.first, let cell = out.rows.first?.cells.first else {
            return XCTFail("expected a table with a spanning cell")
        }
        XCTAssertEqual(cell.colspan, 2)
        XCTAssertEqual(cell.rowspan, 2)
    }

    func test_codable_compactTable_roundTripsViaAdaptedPostbox() throws {
        let table = ChatInputTable(
            columns: [ChatInputColumnSpec(width: 100.0)],
            rows: [ChatInputTableRow(height: nil, cells: [ChatInputTableCell(runs: [ChatInputRun(text: "X")])])],
            compact: true
        )
        let content = ChatInputContent(schemaVersion: 3, blocks: [.table(table)])
        let data = try AdaptedPostboxEncoder().encode(content)
        let decoded = try AdaptedPostboxDecoder().decode(ChatInputContent.self, from: data)
        XCTAssertEqual(decoded, content)
        guard case .table(let out)? = decoded.blocks.first else { return XCTFail("expected a table") }
        XCTAssertTrue(out.compact)
    }

    func test_codable_unborderedTable_roundTripsViaAdaptedPostbox() throws {
        let table = ChatInputTable(
            columns: [ChatInputColumnSpec(width: 100.0)],
            rows: [ChatInputTableRow(height: nil, cells: [ChatInputTableCell(runs: [ChatInputRun(text: "X")])])],
            bordered: false
        )
        let content = ChatInputContent(schemaVersion: 3, blocks: [.table(table)])
        let data = try AdaptedPostboxEncoder().encode(content)
        let decoded = try AdaptedPostboxDecoder().decode(ChatInputContent.self, from: data)
        XCTAssertEqual(decoded, content)
        guard case .table(let out)? = decoded.blocks.first else { return XCTFail("expected a table") }
        XCTAssertFalse(out.bordered)
    }

    /// A draft written before `bordered` existed must still decode, defaulting to TRUE — such a table was
    /// always drawn with its grid, and the forward converter hard-coded `bordered: true`.
    func test_codable_tableWithoutBorderedKey_decodesAsBordered() throws {
        let json = Data(#"{"rows":[],"columns":[]}"#.utf8)
        let table = try JSONDecoder().decode(ChatInputTable.self, from: json)
        XCTAssertTrue(table.bordered)
    }

    /// A draft written before `compact` existed must still decode, defaulting to false.
    func test_codable_tableWithoutCompactKey_decodesAsNonCompact() throws {
        let json = Data(#"{"columns":[{"width":100}],"rows":[{"cells":[]}]}"#.utf8)
        let table = try JSONDecoder().decode(ChatInputTable.self, from: json)
        XCTAssertFalse(table.compact)
    }

    // MARK: - Per-cell H+V alignment (ChatInputTableCell)

    func testTableCellAlignmentRoundTrips() throws {
        var cell = ChatInputTableCell(runs: [ChatInputRun(text: "X")])
        cell.horizontalAlignment = .right
        cell.verticalAlignment = .bottom
        let data = try JSONEncoder().encode(cell)
        let back = try JSONDecoder().decode(ChatInputTableCell.self, from: data)
        XCTAssertEqual(back.horizontalAlignment, .right)
        XCTAssertEqual(back.verticalAlignment, .bottom)
    }

    func testLegacyTableCellDecodesToAlignmentDefaults() throws {
        let json = #"{"runs":[]}"#.data(using: .utf8)!
        let cell = try JSONDecoder().decode(ChatInputTableCell.self, from: json)
        XCTAssertEqual(cell.horizontalAlignment, .center)
        XCTAssertEqual(cell.verticalAlignment, .top)
    }

    /// Heading / list-paragraph / table / media blocks are NOT entity-expressible (they require the structured
    /// `InstantPage` branch); a plain/quote paragraph and a code block ARE.
    func test_isEntityExpressible_structural_false() {
        func single(_ block: ChatInputBlock) -> ChatInputContent { ChatInputContent(blocks: [block]) }

        let heading = single(.paragraph(ChatInputParagraph(style: .heading2, runs: [ChatInputRun(text: "h")])))
        let list = single(.paragraph(ChatInputParagraph(style: .body, list: ChatInputListMembership(marker: .bullet, level: 0), runs: [ChatInputRun(text: "x")])))
        let table = single(.table(ChatInputTable(columns: [ChatInputColumnSpec(width: 10.0)], rows: [])))
        let image = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 1), representations: [], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
        let media = single(.media(ChatInputMedia(media: image, kind: .image, naturalSize: ChatInputSize(width: 1.0, height: 1.0))))
        XCTAssertFalse(heading.isEntityExpressible())
        XCTAssertFalse(list.isEntityExpressible())
        XCTAssertFalse(table.isEntityExpressible())
        XCTAssertFalse(media.isEntityExpressible())

        let plain = single(.paragraph(ChatInputParagraph(style: .body, runs: [ChatInputRun(text: "p")])))
        let bq = single(.blockQuote(ChatInputBlockQuote(
            content: ChatInputContent(blocks: [.paragraph(ChatInputParagraph(style: .body, runs: [ChatInputRun(text: "q")]))]),
            collapsed: false)))
        let code = single(.code(ChatInputCode(language: "swift", runs: [ChatInputRun(text: "c")])))
        XCTAssertTrue(plain.isEntityExpressible())
        XCTAssertTrue(bq.isEntityExpressible())  // flat non-collapsed single-paragraph blockQuote → expressible
        XCTAssertTrue(code.isEntityExpressible())
    }

    func test_isEntityExpressible_formula_false() {
        var formula = ChatInputInlineAttributes()
        formula.formula = "x^2+y^2=z^2"
        let content = ChatInputContent(blocks: [
            .paragraph(ChatInputParagraph(style: .body, runs: [
                ChatInputRun(text: "x^2+y^2=z^2", attributes: formula)
            ]))
        ])

        XCTAssertFalse(content.isEntityExpressible())
        XCTAssertFalse(content.isEntityExpressible(options: [.quotesRequireRichContent]))
    }

    /// With `.quotesRequireRichContent`, a non-collapsed flat single-paragraph `.blockQuote` is no longer
    /// entity-expressible — so quote-bearing content routes onto the rich (InstantPage) path — while a plain /
    /// code-only content stays entity-expressible. A collapsed `.blockQuote` is never entity-expressible.
    func test_isEntityExpressible_quotesRequireRichContent() {
        func single(_ block: ChatInputBlock) -> ChatInputContent { ChatInputContent(blocks: [block]) }

        let plain = single(.paragraph(ChatInputParagraph(style: .body, runs: [ChatInputRun(text: "p")])))
        let bq = single(.blockQuote(ChatInputBlockQuote(
            content: ChatInputContent(blocks: [.paragraph(ChatInputParagraph(style: .body, runs: [ChatInputRun(text: "q")]))]),
            collapsed: false)))
        let collapsed = single(.blockQuote(ChatInputBlockQuote(
            content: ChatInputContent(blocks: [.paragraph(ChatInputParagraph(style: .body, runs: [ChatInputRun(text: "z")]))]),
            collapsed: true)))

        // Default options: a flat non-collapsed single-paragraph blockQuote stays entity-expressible.
        XCTAssertTrue(bq.isEntityExpressible())
        // A collapsed blockQuote is never entity-expressible (regardless of options).
        XCTAssertFalse(collapsed.isEntityExpressible())

        // With the option: a blockquote requires the rich path; non-quote content is unaffected.
        XCTAssertTrue(plain.isEntityExpressible(options: [.quotesRequireRichContent]))
        XCTAssertFalse(bq.isEntityExpressible(options: [.quotesRequireRichContent]))
        XCTAssertFalse(collapsed.isEntityExpressible(options: [.quotesRequireRichContent]))
    }

    // MARK: - Entity-expressibility + InstantPage plainText fallback

    /// Every entity-expressible block type today (paragraph, code, flat non-collapsed single-paragraph blockQuote)
    /// yields a content that takes the `.textEntities` branch (never `.instantPage`).
    func test_isEntityExpressible_allCurrentBlocks_true() {
        let content = ChatInputContent(blocks: [
            .paragraph(ChatInputParagraph(style: .body, runs: [ChatInputRun(text: "ab")])),
            .code(ChatInputCode(language: "swift", runs: [ChatInputRun(text: "x\ny")])),
            .blockQuote(ChatInputBlockQuote(
                content: ChatInputContent(blocks: [.paragraph(ChatInputParagraph(style: .body, runs: [ChatInputRun(text: "z")]))]),
                collapsed: false)),
        ])
        XCTAssertTrue(content.isEntityExpressible())
    }

    // MARK: - Pull-quote block (ChatInputBlock.pullQuote)

    /// `ChatInputBlock.pullQuote` Codable round-trip through AdaptedPostbox (the REAL persistence path).
    func test_pullQuote_codableRoundTrip() throws {
        let block = ChatInputBlock.pullQuote(ChatInputPullQuote(runs: [ChatInputRun(text: "a\nb")]))
        let data = try AdaptedPostboxEncoder().encode(block)
        XCTAssertEqual(try AdaptedPostboxDecoder().decode(ChatInputBlock.self, from: data), block)
    }

    /// `.pullQuote` is unconditionally NOT entity-expressible — it always forces the rich (InstantPage) path,
    /// regardless of the `quotesRequireRichContent` option.
    func test_pullQuote_notEntityExpressible() {
        let c = ChatInputContent(blocks: [.pullQuote(ChatInputPullQuote(runs: [ChatInputRun(text: "hi")]))])
        XCTAssertFalse(c.isEntityExpressible())
        XCTAssertFalse(c.isEntityExpressible(options: [.quotesRequireRichContent]))   // unconditional
    }

    /// `.pullQuote` lives on the flat axis: its text contributes to `plainText` and `blockFlatLength`.
    func test_pullQuote_flatAxisContribution() {
        let pq = ChatInputPullQuote(runs: [ChatInputRun(text: "hello")])
        let c = ChatInputContent(blocks: [
            .paragraph(ChatInputParagraph(style: .body, runs: [ChatInputRun(text: "before")])),
            .pullQuote(pq),
        ])
        XCTAssertEqual(c.plainText, "before\nhello")
        XCTAssertEqual(c.length, (("before\nhello") as NSString).length)
    }

    // MARK: - Quote author line (ChatInputBlockQuote/ChatInputPullQuote.author)

    func test_pullQuote_author_codableRoundTrip_viaAdaptedPostbox() throws {
        let block = ChatInputBlock.pullQuote(ChatInputPullQuote(runs: [ChatInputRun(text: "q")], author: [ChatInputRun(text: "Jobs")]))
        let data = try AdaptedPostboxEncoder().encode(block)
        XCTAssertEqual(try AdaptedPostboxDecoder().decode(ChatInputBlock.self, from: data), block)
    }

    func test_blockQuote_author_codableRoundTrip_viaAdaptedPostbox() throws {
        let inner = ChatInputContent(blocks: [.paragraph(ChatInputParagraph(style: .body, runs: [ChatInputRun(text: "body")]))])
        let block = ChatInputBlock.blockQuote(ChatInputBlockQuote(content: inner, collapsed: false, author: [ChatInputRun(text: "Ada")]))
        let data = try AdaptedPostboxEncoder().encode(block)
        XCTAssertEqual(try AdaptedPostboxDecoder().decode(ChatInputBlock.self, from: data), block)
    }

    func test_blockQuote_withAuthor_isNotEntityExpressible_andPlainTextExcludesAuthor() {
        let inner = ChatInputContent(blocks: [.paragraph(ChatInputParagraph(style: .body, runs: [ChatInputRun(text: "body")]))])
        let withAuthor = ChatInputContent(blocks: [.blockQuote(ChatInputBlockQuote(content: inner, collapsed: false, author: [ChatInputRun(text: "Ada")]))])
        XCTAssertFalse(withAuthor.isEntityExpressible())            // author → rich path
        XCTAssertFalse(withAuthor.plainText.contains("Ada"))       // author off the flat axis
        XCTAssertTrue(withAuthor.plainText.contains("body"))
        let noAuthor = ChatInputContent(blocks: [.blockQuote(ChatInputBlockQuote(content: inner, collapsed: false, author: []))])
        XCTAssertTrue(noAuthor.isEntityExpressible())               // empty author → unchanged (entity path)
    }

    /// The old-client text fallback joins paragraph / blockQuote / preformatted text with "\n", skipping empty
    /// pieces (a blockQuote contributes its inner blocks' text, recursively).
    func test_instantPage_plainText() {
        let page = InstantPage(
            blocks: [
                .paragraph(.plain("a")),
                .blockQuote(blocks: [.paragraph(.plain("b"))], caption: .empty, collapsed: nil),
                .paragraph(.plain("c")),
            ],
            media: [:],
            isComplete: true,
            rtl: false,
            url: "",
            views: nil
        )
        XCTAssertEqual(page.plainText, "a\nb\nc")
    }

    func test_isEmptyWhitespaceTrimmed_contentAwareAndWhitespaceTrimmed() {
        func p(_ s: String) -> ChatInputBlock { .paragraph(ChatInputParagraph(style: .body, runs: s.isEmpty ? [] : [ChatInputRun(text: s)])) }
        let image = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 7), representations: [], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
        let media = ChatInputMedia(media: image, kind: .image, naturalSize: ChatInputSize(width: 1.0, height: 1.0))
        let table = ChatInputTable(columns: [ChatInputColumnSpec(width: 10.0)], rows: [])

        // Whitespace-only text is EMPTY here — including several blank paragraphs (unlike raw isEmpty).
        XCTAssertTrue(ChatInputContent().isEmptyWhitespaceTrimmed)                                     // no blocks
        XCTAssertTrue(ChatInputContent(blocks: [p("   ")]).isEmptyWhitespaceTrimmed)                   // spaces only
        XCTAssertTrue(ChatInputContent(blocks: [p("\n\t ")]).isEmptyWhitespaceTrimmed)                 // mixed whitespace
        XCTAssertTrue(ChatInputContent(blocks: [p(""), p(""), p("")]).isEmptyWhitespaceTrimmed)        // several blank paragraphs
        XCTAssertTrue(ChatInputContent(blocks: [.code(ChatInputCode(runs: []))]).isEmptyWhitespaceTrimmed) // empty code
        XCTAssertTrue(ChatInputContent(blocks: [.pullQuote(ChatInputPullQuote(runs: [ChatInputRun(text: "  ")]))]).isEmptyWhitespaceTrimmed) // whitespace pull quote

        // Non-whitespace text is NOT empty.
        XCTAssertFalse(ChatInputContent(blocks: [p("a")]).isEmptyWhitespaceTrimmed)
        XCTAssertFalse(ChatInputContent(blocks: [p("  x  ")]).isEmptyWhitespaceTrimmed)
        XCTAssertFalse(ChatInputContent(blocks: [p("  "), p("x")]).isEmptyWhitespaceTrimmed)

        // Structural blocks are ALWAYS content — the media / empty-table fix.
        XCTAssertFalse(ChatInputContent(blocks: [.media(media)]).isEmptyWhitespaceTrimmed)
        XCTAssertFalse(ChatInputContent(blocks: [.table(table)]).isEmptyWhitespaceTrimmed)             // empty table
        XCTAssertFalse(ChatInputContent(blocks: [p("  "), .table(table)]).isEmptyWhitespaceTrimmed)    // whitespace + table
        XCTAssertFalse(ChatInputContent(blocks: [.blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: [p("")]), collapsed: true))]).isEmptyWhitespaceTrimmed)

        // Contrast with raw isEmpty: several blank paragraphs are NON-empty raw, but whitespace-empty here.
        XCTAssertFalse(ChatInputContent(blocks: [p(""), p("")]).isEmpty)
        XCTAssertTrue(ChatInputContent(blocks: [p(""), p("")]).isEmptyWhitespaceTrimmed)
    }

    // MARK: - ChatInputMedia container (items array)

    func test_chatInputMedia_container_codableViaAdaptedPostbox() throws {
        let img = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 1), representations: [], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
        let file = TelegramMediaFile(fileId: MediaId(namespace: 0, id: 2), partialReference: nil, resource: EmptyMediaResource(), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "video/mp4", size: nil, attributes: [], alternativeRepresentations: [])
        let media = ChatInputMedia(items: [
            ChatInputMediaItem(media: img, kind: .image, naturalSize: ChatInputSize(width: 100, height: 50)),
            ChatInputMediaItem(media: file, kind: .video, naturalSize: ChatInputSize(width: 60, height: 90)),
        ], displayWidth: nil, alignment: .center, caption: [])
        let data = try AdaptedPostboxEncoder().encode(media)
        let decoded = try AdaptedPostboxDecoder().decode(ChatInputMedia.self, from: data)
        XCTAssertEqual(decoded, media)
    }

    /// `displayMode` is a `String`-raw enum: its synthesized `RawRepresentable` Codable uses a
    /// `singleValueContainer`, which `AdaptedPostboxEncoder` does not support (it crashed on encode). Guards the
    /// custom keyed Codable by round-tripping a NON-default `.slideshow` value through AdaptedPostbox.
    func test_chatInputMedia_displayMode_codableViaAdaptedPostbox() throws {
        let img = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 1), representations: [], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
        for mode in [ChatInputMediaDisplayMode.mosaic, .slideshow] {
            let media = ChatInputMedia(items: [
                ChatInputMediaItem(media: img, kind: .image, naturalSize: ChatInputSize(width: 100, height: 50)),
            ], displayMode: mode)
            let data = try AdaptedPostboxEncoder().encode(media)
            let decoded = try AdaptedPostboxDecoder().decode(ChatInputMedia.self, from: data)
            XCTAssertEqual(decoded.displayMode, mode)
            XCTAssertEqual(decoded, media)
        }
    }

    func test_chatInputMedia_convenienceInit_isOneItem() {
        let img = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 1), representations: [], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
        let media = ChatInputMedia(media: img, kind: .image, naturalSize: ChatInputSize(width: 1, height: 1))
        XCTAssertEqual(media.items.count, 1)
        XCTAssertTrue(media.media.isEqual(to: img))   // accessor -> first item
    }

    /// Emits the pre-container `ChatInputMedia` wire shape (top-level `media`/`mediaType`/`kind`/`naturalSize`/
    /// `alignment`/`caption`, deliberately NO `items` key) so the test can exercise `ChatInputMedia.init(from:)`'s
    /// `else` branch (see ChatInputContentModel.swift), which is unreachable from `ChatInputMedia.encode(to:)`
    /// itself (that always emits `items`).
    private struct LegacyChatInputMediaPayload: Encodable {
        let media: TelegramMediaImage
        let mediaType: Int32
        let kind: ChatInputMediaKind
        let naturalSize: ChatInputSize
        let alignment: ChatInputMediaAlignment
        let caption: [ChatInputRun]

        private enum CodingKeys: String, CodingKey {
            case media, mediaType, kind, naturalSize, alignment, caption
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(PostboxEncoder().encodeObjectToRawData(self.media), forKey: .media)
            try container.encode(self.mediaType, forKey: .mediaType)
            try container.encode(self.kind, forKey: .kind)
            try container.encode(self.naturalSize, forKey: .naturalSize)
            try container.encode(self.alignment, forKey: .alignment)
            try container.encode(self.caption, forKey: .caption)
        }
    }

    /// Back-compat: a legacy (pre-container) single-media payload — no `items` key — decodes into a
    /// one-element `items` array (the `else` branch of `ChatInputMedia.init(from:)`).
    func test_chatInputMedia_legacySingleMediaPayload_decodesIntoOneItem() throws {
        let img = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 99), representations: [], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
        let size = ChatInputSize(width: 42, height: 24)
        let legacy = LegacyChatInputMediaPayload(
            media: img,
            mediaType: 0, // MediaType.image, per ChatInputMedia's private MediaType discriminator
            kind: .image,
            naturalSize: size,
            alignment: .center,
            caption: []
        )
        let data = try AdaptedPostboxEncoder().encode(legacy)
        let decoded = try AdaptedPostboxDecoder().decode(ChatInputMedia.self, from: data)

        XCTAssertEqual(decoded.items.count, 1)
        XCTAssertTrue(decoded.items[0].media.isEqual(to: img))
        XCTAssertEqual(decoded.items[0].kind, .image)
        XCTAssertEqual(decoded.naturalSize, size)
        XCTAssertFalse(decoded.items[0].isSpoiler) // legacy payload has no isSpoiler key -> back-compat false
    }

    // MARK: - ChatInputMediaItem.isSpoiler

    func test_chatInputMediaItem_spoiler_roundTripsViaAdaptedPostbox() throws {
        let image = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 42), representations: [], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
        var item = ChatInputMediaItem(media: image, kind: .image, naturalSize: ChatInputSize(width: 4, height: 3))
        item.isSpoiler = true
        let data = try AdaptedPostboxEncoder().encode(item)
        let decoded = try AdaptedPostboxDecoder().decode(ChatInputMediaItem.self, from: data)
        XCTAssertTrue(decoded.isSpoiler)
        XCTAssertEqual(decoded, item)
    }

    func test_chatInputMediaItem_defaultsSpoilerFalse() throws {
        let image = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 7), representations: [], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
        let item = ChatInputMediaItem(media: image, kind: .image, naturalSize: ChatInputSize(width: 1, height: 1))
        let data = try AdaptedPostboxEncoder().encode(item)
        XCTAssertFalse(try AdaptedPostboxDecoder().decode(ChatInputMediaItem.self, from: data).isSpoiler)
    }

    // MARK: - ChatInputTableCell.isHeader / ChatInputTableRow derived header

    func test_chatInputTableRow_headerIsDerivedFromCells_andNotEncoded() throws {
        let hdr = ChatInputTableCell(runs: [ChatInputRun(text: "H")], isHeader: true)
        let body = ChatInputTableCell(runs: [ChatInputRun(text: "B")])
        XCTAssertTrue(ChatInputTableRow(cells: [hdr]).isHeader)
        XCTAssertFalse(ChatInputTableRow(cells: [hdr, body]).isHeader)
        let data = try JSONEncoder().encode(ChatInputTableRow(isHeader: true, cells: [ChatInputTableCell(runs: [])]))
        // `ChatInputTableCell`'s synthesized `encode` always emits its own `isHeader` key, so a naive
        // substring check on the whole payload would false-positive. Assert instead that the ROW object
        // itself (the top-level JSON object) has no `isHeader` key — the per-cell keys are expected.
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertFalse(json.keys.contains("isHeader"))
        XCTAssertTrue(json.keys.contains("cells"))
    }

    func test_chatInputTableRow_legacyHeader_migratesIntoCells() throws {
        let json = #"{"cells":[{"runs":[]},{"runs":[]}],"isHeader":true}"#.data(using: .utf8)!
        let row = try JSONDecoder().decode(ChatInputTableRow.self, from: json)
        XCTAssertTrue(row.cells.allSatisfy { $0.isHeader })
        XCTAssertTrue(row.isHeader)
    }

    func test_chatInputTableRow_initHeaderParam_seedsCells() {
        let row = ChatInputTableRow(isHeader: true, cells: [ChatInputTableCell(runs: []), ChatInputTableCell(runs: [])])
        XCTAssertTrue(row.cells.allSatisfy { $0.isHeader })
    }

    // MARK: - ChatInputTableCell.colspan / rowspan

    func test_chatInputTableCell_spanDefaultsAndRoundTrips() throws {
        XCTAssertEqual(ChatInputTableCell(runs: []).colspan, 1)
        XCTAssertEqual(ChatInputTableCell(runs: []).rowspan, 1)
        var c = ChatInputTableCell(runs: []); c.colspan = 2; c.rowspan = 3
        let back = try JSONDecoder().decode(ChatInputTableCell.self, from: try JSONEncoder().encode(c))
        XCTAssertEqual(back.colspan, 2); XCTAssertEqual(back.rowspan, 3)
    }

    func test_chatInputTableCell_legacyWithoutSpan_decodesToOne() throws {
        let json = #"{"runs":[]}"#.data(using: .utf8)!
        let c = try JSONDecoder().decode(ChatInputTableCell.self, from: json)
        XCTAssertEqual(c.colspan, 1); XCTAssertEqual(c.rowspan, 1)
    }

    // MARK: - InstantPage buttons

    private func buttonRow(_ alignment: InstantPageButtonRowAlignment = .justify) -> ChatInputButtonRow {
        ChatInputButtonRow(
            buttons: [
                ChatInputButton(label: [ChatInputRun(text: "Open")], action: .url("https://telegram.org"), color: .primary, isLink: false),
                ChatInputButton(label: [ChatInputRun(text: "Pay")], action: .payment, color: .danger, isLink: true),
            ],
            alignment: alignment
        )
    }

    /// LOAD-BEARING: a button has no message-entity form, so button-bearing content must route to the
    /// rich `.instantPage` send path. Returning true here would send the message as plain text +
    /// entities and destroy the buttons on the way out.
    func test_buttonRowBlock_isNotEntityExpressible() {
        XCTAssertFalse(ChatInputContent(blocks: [.buttonRow(buttonRow())]).isEntityExpressible())
    }

    func test_inlineButtonRun_isNotEntityExpressible() {
        var attributes = ChatInputInlineAttributes()
        attributes.entity = .button(ChatInputButton(label: [ChatInputRun(text: "Go")], action: .url("https://telegram.org")))
        let content = ChatInputContent(blocks: [.paragraph(ChatInputParagraph(style: .body, runs: [
            ChatInputRun(text: "before "),
            ChatInputRun(text: "\u{FFFC}", attributes: attributes),
        ]))])
        XCTAssertFalse(content.isEntityExpressible())
    }

    /// Via the REAL persistence path (`AdaptedPostbox*coder`), not JSON — the action rides as a Postbox
    /// object blob and the colour/alignment as keyed Int32 rawValues, neither of which JSON would exercise.
    func test_codable_buttonRow_roundTripsViaAdaptedPostbox() throws {
        let content = ChatInputContent(blocks: [.buttonRow(buttonRow(.right))])
        let data = try AdaptedPostboxEncoder().encode(content)
        XCTAssertEqual(try AdaptedPostboxDecoder().decode(ChatInputContent.self, from: data), content)
    }

    func test_codable_inlineButtonRun_roundTripsViaAdaptedPostbox() throws {
        var attributes = ChatInputInlineAttributes(bold: true)
        attributes.entity = .button(ChatInputButton(
            label: [ChatInputRun(text: "Go")],
            action: .callback(requiresPassword: true, data: MemoryBuffer(data: Data([1, 2, 3]))),
            color: .success,
            isLink: true
        ))
        let content = ChatInputContent(blocks: [.paragraph(ChatInputParagraph(style: .body, runs: [
            ChatInputRun(text: "\u{FFFC}", attributes: attributes),
        ]))])
        let data = try AdaptedPostboxEncoder().encode(content)
        XCTAssertEqual(try AdaptedPostboxDecoder().decode(ChatInputContent.self, from: data), content)
    }

    /// The discriminator is persisted in drafts. 8 is the next free value: `details` is 7, and 2 is a
    /// deliberate gap left by the retired `collapsedQuote`. Never renumber.
    func test_buttonRow_discriminatorIsEight() throws {
        let object = try JSONSerialization.jsonObject(
            with: try JSONEncoder().encode(ChatInputBlock.buttonRow(ChatInputButtonRow(buttons: [])))
        ) as? [String: Any]
        XCTAssertEqual(object?["kind"] as? Int, 8)
    }

    /// An older build must skip an unknown block rather than failing the whole draft — the lenient
    /// per-element decode. Simulated by decoding a block whose discriminator this build does not know.
    func test_unknownBlockDiscriminator_isSkippedNotFatal() throws {
        let content = ChatInputContent(blocks: [
            .paragraph(ChatInputParagraph(style: .body, runs: [ChatInputRun(text: "keep me")])),
            .buttonRow(buttonRow()),
        ])
        let data = try AdaptedPostboxEncoder().encode(content)
        XCTAssertEqual(try AdaptedPostboxDecoder().decode(ChatInputContent.self, from: data).blocks.count, 2)
    }

    func testAllMediaFindsNestedMedia() {
        let image = TelegramMediaImage(
            imageId: EngineMedia.Id(namespace: Namespaces.Media.LocalImage, id: 1),
            representations: [],
            immediateThumbnailData: nil,
            reference: nil,
            partialReference: nil,
            flags: []
        )
        let mediaBlock = ChatInputBlock.media(ChatInputMedia(
            media: image,
            kind: .image,
            naturalSize: ChatInputSize(width: 10.0, height: 10.0)
        ))
        let quoted = ChatInputBlock.blockQuote(ChatInputBlockQuote(
            content: ChatInputContent(blocks: [mediaBlock]),
            collapsed: false
        ))
        let content = ChatInputContent(blocks: [quoted])

        XCTAssertEqual(content.allMedia.count, 1)
        XCTAssertEqual(content.allMedia.first?.id, image.imageId)
    }
}
