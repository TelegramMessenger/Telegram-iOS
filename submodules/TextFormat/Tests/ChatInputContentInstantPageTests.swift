import XCTest
import Postbox
import TelegramCore

final class ChatInputContentInstantPageTests: XCTestCase {
    private func assertRoundTrips(_ c: ChatInputContent, _ msg: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(chatInputContent(fromInstantPage: instantPage(from: c)), c, msg, file: file, line: line)
    }

    private func body(_ runs: [ChatInputRun]) -> ChatInputBlock {
        return .paragraph(ChatInputParagraph(style: .body, runs: runs))
    }

    // Matches the inline representation construction already used in `test_media_recoversNaturalSizeFromMedia`.
    private func imageRep(_ width: Int32, _ height: Int32) -> TelegramMediaImageRepresentation {
        return TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: width, height: height),
                                                resource: EmptyMediaResource(), progressiveSizes: [], immediateThumbnailData: nil)
    }

    // 1. Plain + each inline attribute separately, plus several combined into one run.
    func test_plainAndInlineAttributes() {
        var bold = ChatInputInlineAttributes(); bold.bold = true
        var italic = ChatInputInlineAttributes(); italic.italic = true
        var mono = ChatInputInlineAttributes(); mono.monospace = true
        var strike = ChatInputInlineAttributes(); strike.strikethrough = true
        var under = ChatInputInlineAttributes(); under.underline = true
        var spoiler = ChatInputInlineAttributes(); spoiler.spoiler = true

        assertRoundTrips(ChatInputContent(blocks: [body([
            ChatInputRun(text: "plain"),
            ChatInputRun(text: "b", attributes: bold),
            ChatInputRun(text: "i", attributes: italic),
            ChatInputRun(text: "m", attributes: mono),
            ChatInputRun(text: "s", attributes: strike),
            ChatInputRun(text: "u", attributes: under),
            ChatInputRun(text: "p", attributes: spoiler)
        ])]), "each inline attribute as a separate run")

        var all = ChatInputInlineAttributes()
        all.bold = true; all.italic = true; all.monospace = true
        all.strikethrough = true; all.underline = true; all.spoiler = true
        assertRoundTrips(ChatInputContent(blocks: [body([
            ChatInputRun(text: "combined", attributes: all)
        ])]), "all inline attributes combined in one run")

        // A subset combination too.
        var subset = ChatInputInlineAttributes()
        subset.bold = true; subset.underline = true
        assertRoundTrips(ChatInputContent(blocks: [body([
            ChatInputRun(text: "bu", attributes: subset)
        ])]), "bold+underline combined run")
    }

    // 2. Custom emoji run.
    func test_customEmoji() {
        var attrs = ChatInputInlineAttributes()
        attrs.entity = .customEmoji(fileId: 42, file: nil, enableAnimation: true)
        assertRoundTrips(ChatInputContent(blocks: [body([
            ChatInputRun(text: "\u{FFFC}", attributes: attrs)
        ])]), "custom emoji run")
    }

    // `enableAnimation` has no `RichText` carrier and is canonicalized to `true` on the reverse — matching the
    // production `.textEntities` draft path (the `CustomEmoji` entity carries no animation flag, so it's re-derived
    // at decoration). This pins that contract: an `enableAnimation: false` input round-trips to `true` (NOT strict
    // identity for this render-time flag — everything else about the run is preserved).
    func test_customEmoji_enableAnimationFalse() {
        var attrs = ChatInputInlineAttributes()
        attrs.entity = .customEmoji(fileId: 42, file: nil, enableAnimation: false)
        let input = ChatInputContent(blocks: [body([ChatInputRun(text: "\u{FFFC}", attributes: attrs)])])

        var expectedAttrs = ChatInputInlineAttributes()
        expectedAttrs.entity = .customEmoji(fileId: 42, file: nil, enableAnimation: true)
        let expected = ChatInputContent(blocks: [body([ChatInputRun(text: "\u{FFFC}", attributes: expectedAttrs)])])

        XCTAssertEqual(chatInputContent(fromInstantPage: instantPage(from: input)), expected,
                       "enableAnimation:false canonicalizes to true on the InstantPage round-trip")
    }

    // 3. Mention / date / url entity runs.
    func test_entityRuns() {
        var mention = ChatInputInlineAttributes(); mention.entity = .mention(EnginePeer.Id(123))
        var date = ChatInputInlineAttributes(); date.entity = .date(1717171717)
        var url = ChatInputInlineAttributes(); url.entity = .url("https://example.com")
        assertRoundTrips(ChatInputContent(blocks: [body([
            ChatInputRun(text: "John", attributes: mention),
            ChatInputRun(text: "tomorrow", attributes: date),
            ChatInputRun(text: "link", attributes: url)
        ])]), "mention/date/url entity runs")
    }

    // 4. Entity run that ALSO carries inline attributes (e.g. a bold mention).
    func test_entityWithAttributes() {
        var boldMention = ChatInputInlineAttributes()
        boldMention.bold = true
        boldMention.entity = .mention(EnginePeer.Id(999))
        assertRoundTrips(ChatInputContent(blocks: [body([
            ChatInputRun(text: "Alice", attributes: boldMention)
        ])]), "bold mention")

        var spoilerUrl = ChatInputInlineAttributes()
        spoilerUrl.spoiler = true
        spoilerUrl.italic = true
        spoilerUrl.entity = .url("https://hidden.example")
        assertRoundTrips(ChatInputContent(blocks: [body([
            ChatInputRun(text: "secret", attributes: spoilerUrl)
        ])]), "spoiler+italic url")
    }

    func test_formulaRun_roundTripsAsStandaloneFormulaBlock() {
        var formula = ChatInputInlineAttributes()
        formula.formula = "e^{I\\pi}=-1"
        let content = ChatInputContent(blocks: [body([
            ChatInputRun(text: "e^{I\\pi}=-1", attributes: formula)
        ])])

        assertRoundTrips(content, "standalone formula run")

        let page = instantPage(from: content)
        guard case let .formula(latex) = page.blocks.first else {
            XCTFail("standalone formula run should emit an InstantPage formula block")
            return
        }
        XCTAssertEqual(latex, "e^{I\\pi}=-1")
    }

    func test_formulaRun_roundTripsInlineInsideParagraph() {
        var formula = ChatInputInlineAttributes()
        formula.formula = "x^2"
        let content = ChatInputContent(blocks: [body([
            ChatInputRun(text: "before "),
            ChatInputRun(text: "x^2", attributes: formula),
            ChatInputRun(text: " after")
        ])])

        assertRoundTrips(content, "inline formula inside paragraph")

        let page = instantPage(from: content)
        guard case let .paragraph(text) = page.blocks.first else {
            XCTFail("mixed text + formula should emit a paragraph")
            return
        }
        XCTAssertEqual(text.plainText, "before x^2 after")
    }

    // 5. Code blocks with and without a language.
    func test_codeBlocks() {
        assertRoundTrips(ChatInputContent(blocks: [
            .code(ChatInputCode(language: "swift", runs: [ChatInputRun(text: "let x = 1\nlet y = 2")]))
        ]), "code with language")

        assertRoundTrips(ChatInputContent(blocks: [
            .code(ChatInputCode(language: nil, runs: [ChatInputRun(text: "no language")]))
        ]), "code without language")
    }

    // 6. Collapsed blockquote round-trips (Task 16b: `.blockQuote(collapsed: true)` is the sole collapsed form).
    func test_collapsedQuote() {
        // Single collapsed blockQuote — canonical form.
        assertRoundTrips(ChatInputContent(blocks: [
            .blockQuote(ChatInputBlockQuote(
                content: ChatInputContent(blocks: [body([ChatInputRun(text: "folded body")])]),
                collapsed: true))
        ]), "single collapsed blockQuote (collapsed: true)")

        // Nested: a collapsed blockQuote inside a collapsed blockQuote.
        assertRoundTrips(ChatInputContent(blocks: [
            .blockQuote(ChatInputBlockQuote(
                content: ChatInputContent(blocks: [
                    body([ChatInputRun(text: "outer")]),
                    .blockQuote(ChatInputBlockQuote(
                        content: ChatInputContent(blocks: [body([ChatInputRun(text: "inner")])]),
                        collapsed: true))
                ]),
                collapsed: true))
        ]), "nested collapsed blockQuote inside collapsed blockQuote")
    }

    // 9. Two adjacent plain runs in one paragraph must survive as TWO runs (no-merge rule).
    func test_adjacentPlainRunsNotMerged() {
        let c = ChatInputContent(blocks: [body([
            ChatInputRun(text: "a"),
            ChatInputRun(text: "b")
        ])])
        assertRoundTrips(c, "two adjacent plain runs survive as two runs")
        // Explicitly assert they did not merge into one "ab" run.
        let restored = chatInputContent(fromInstantPage: instantPage(from: c))
        if case let .paragraph(p) = restored.blocks[0] {
            XCTAssertEqual(p.runs.count, 2, "adjacent runs must not merge")
        } else {
            XCTFail("expected a paragraph block")
        }
    }

    // 10. An empty body paragraph (runs: []).
    func test_emptyBodyParagraph() {
        assertRoundTrips(ChatInputContent(blocks: [
            body([])
        ]), "empty body paragraph")
    }

    // 11. Heading paragraphs at each level (1/2/3) round-trip identically.
    func test_headings() {
        func heading(_ style: ChatInputParagraphStyle, _ text: String) -> ChatInputBlock {
            return .paragraph(ChatInputParagraph(style: style, runs: [ChatInputRun(text: text)]))
        }
        assertRoundTrips(ChatInputContent(blocks: [heading(.heading1, "Title")]), "heading1")
        assertRoundTrips(ChatInputContent(blocks: [heading(.heading2, "Section")]), "heading2")
        assertRoundTrips(ChatInputContent(blocks: [heading(.heading3, "Subsection")]), "heading3")
        // All three levels in one document, plus a body paragraph (must not coalesce with headings).
        assertRoundTrips(ChatInputContent(blocks: [
            heading(.heading1, "H1"),
            heading(.heading2, "H2"),
            heading(.heading3, "H3"),
            body([ChatInputRun(text: "body")])
        ]), "all heading levels + body")
    }

    // 12. A bullet list and an ordered list (each 2 items, level 0) round-trip identically.
    func test_lists() {
        func listItem(_ marker: ChatInputListMarker, _ text: String) -> ChatInputBlock {
            return .paragraph(ChatInputParagraph(style: .body, list: ChatInputListMembership(marker: marker, level: 0), runs: [ChatInputRun(text: text)]))
        }
        assertRoundTrips(ChatInputContent(blocks: [
            listItem(.bullet, "first"),
            listItem(.bullet, "second")
        ]), "two-item bullet list")
        assertRoundTrips(ChatInputContent(blocks: [
            listItem(.ordered, "one"),
            listItem(.ordered, "two")
        ]), "two-item ordered list")
        // A bullet list directly followed by an ordered list — they must stay two distinct `.list` blocks and
        // each item must round-trip back to its own marker.
        assertRoundTrips(ChatInputContent(blocks: [
            listItem(.bullet, "b1"),
            listItem(.bullet, "b2"),
            listItem(.ordered, "o1"),
            listItem(.ordered, "o2")
        ]), "adjacent bullet then ordered list")
        // A list item carrying an inline attribute on its run still round-trips.
        var bold = ChatInputInlineAttributes(); bold.bold = true
        assertRoundTrips(ChatInputContent(blocks: [
            .paragraph(ChatInputParagraph(style: .body, list: ChatInputListMembership(marker: .bullet, level: 0), runs: [ChatInputRun(text: "bold", attributes: bold)]))
        ]), "bullet list item with a bold run")
    }

    // 13. A 2x2 table (header row, default column width, nil-background cells, and — per cell — non-default
    //     horizontal + vertical alignment) round-trips identically — built to match exactly what the reverse
    //     produces for the non-representable fields (column width = 0.0, cell background = nil; table title /
    //     colspan / rowspan dropped). Alignment is purely per-cell (columns carry only `width`), so every cell's
    //     H+V alignment — header or body — SURVIVES the round-trip independently, with no column-level coupling.
    func test_table() {
        var bold = ChatInputInlineAttributes(); bold.bold = true
        let table = ChatInputTable(
            columns: [
                ChatInputColumnSpec(width: 0.0),
                ChatInputColumnSpec(width: 0.0)
            ],
            rows: [
                ChatInputTableRow(height: nil, isHeader: true, cells: [
                    ChatInputTableCell(runs: [ChatInputRun(text: "H1")], background: nil, horizontalAlignment: .left, verticalAlignment: .middle),
                    ChatInputTableCell(runs: [ChatInputRun(text: "H2")], background: nil, horizontalAlignment: .center, verticalAlignment: .bottom)
                ]),
                ChatInputTableRow(height: nil, isHeader: false, cells: [
                    ChatInputTableCell(runs: [ChatInputRun(text: "a", attributes: bold)], background: nil, horizontalAlignment: .right, verticalAlignment: .top),
                    ChatInputTableCell(runs: [ChatInputRun(text: "b")], background: nil, horizontalAlignment: .left, verticalAlignment: .bottom)
                ])
            ]
        )
        assertRoundTrips(ChatInputContent(blocks: [.table(table)]), "2x2 table with header row + per-cell H+V alignment")
    }

    /// The identity invariant for an UNBORDERED table. The default (`bordered: true`) round-trips
    /// trivially even if the reverse converter discarded the flag, so only this case actually pins the
    /// reverse binding.
    func test_table_unbordered_roundTrips() {
        let table = ChatInputTable(
            columns: [ChatInputColumnSpec(width: 0.0)],
            rows: [ChatInputTableRow(height: nil, cells: [ChatInputTableCell(runs: [ChatInputRun(text: "a")])])],
            bordered: false
        )
        assertRoundTrips(ChatInputContent(blocks: [.table(table)]), "unbordered table")
    }

    // 13b. Per-cell header: a table whose header cells do NOT form a whole row still round-trips each cell's
    //      `isHeader` independently (the InstantPage layer carries per-cell `header`).
    func test_table_perCellHeader() {
        func c(_ t: String, header: Bool) -> ChatInputTableCell {
            ChatInputTableCell(runs: [ChatInputRun(text: t)], background: nil, horizontalAlignment: .left, verticalAlignment: .top, isHeader: header)
        }
        let table = ChatInputTable(
            columns: [ChatInputColumnSpec(width: 0.0), ChatInputColumnSpec(width: 0.0)],
            rows: [
                ChatInputTableRow(height: nil, cells: [c("H", header: true), c("x", header: false)]),  // partial header row
                ChatInputTableRow(height: nil, cells: [c("y", header: false), c("z", header: true)])
            ])
        assertRoundTrips(ChatInputContent(blocks: [.table(table)]), "2x2 table with per-cell (non-row-aligned) header cells")
    }

    // 13c. Per-cell colspan/rowspan round-trip through the InstantPage `Int32` seam (normalized back to the
    //      chat currency's `Int`, default 1).
    func test_table_colspanRowspan_roundTrips() {
        func c(_ t: String, cs: Int = 1, rs: Int = 1) -> ChatInputTableCell {
            var cell = ChatInputTableCell(runs: [ChatInputRun(text: t)], background: nil, horizontalAlignment: .left, verticalAlignment: .top, isHeader: false)
            cell.colspan = cs; cell.rowspan = rs
            return cell
        }
        // Top-left cell spans the whole first row (colspan 2); second row two normal cells.
        let table = ChatInputTable(
            columns: [ChatInputColumnSpec(width: 0.0), ChatInputColumnSpec(width: 0.0)],
            rows: [
                ChatInputTableRow(height: nil, cells: [c("H", cs: 2)]),
                ChatInputTableRow(height: nil, cells: [c("a"), c("b")])
            ])
        assertRoundTrips(ChatInputContent(blocks: [.table(table)]), "table with a colspan cell")
    }

    // 14. An image medium and a video medium round-trip identically — built with the default
    //     naturalSize/displayWidth/alignment the reverse restores (the InstantPage image/video block carries
    //     none of those, so they canonicalize to natural size .zero, nil display width, .center alignment).
    func test_media() {
        let imageId = MediaId(namespace: 1, id: 1001)
        let image = TelegramMediaImage(imageId: imageId, representations: [], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
        var caption = ChatInputInlineAttributes(); caption.italic = true
        let imageMedia = ChatInputMedia(
            media: image,
            kind: .image,
            naturalSize: ChatInputSize(width: 0.0, height: 0.0),
            displayWidth: nil,
            alignment: .center,
            caption: [ChatInputRun(text: "a photo", attributes: caption)]
        )
        assertRoundTrips(ChatInputContent(blocks: [.media(imageMedia)]), "image medium with a caption")

        let fileId = MediaId(namespace: 1, id: 2002)
        let file = TelegramMediaFile(
            fileId: fileId,
            partialReference: nil,
            resource: EmptyMediaResource(),
            previewRepresentations: [],
            videoThumbnails: [],
            immediateThumbnailData: nil,
            mimeType: "video/mp4",
            size: nil,
            attributes: [],
            alternativeRepresentations: []
        )
        let videoMedia = ChatInputMedia(
            media: file,
            kind: .video,
            naturalSize: ChatInputSize(width: 0.0, height: 0.0),
            displayWidth: nil,
            alignment: .center,
            caption: []
        )
        assertRoundTrips(ChatInputContent(blocks: [.media(videoMedia)]), "video medium with no caption")
    }

    // The InstantPage image/video block carries no size, so on the reverse the natural size (aspect) must be
    // recovered from the resolved `Media` itself — an image's largest representation, a video file's `.Video`
    // attribute — mirroring the size the editor computes at insertion. Without this a Document → InstantPage →
    // Document round-trip loses the aspect and the editor falls back to a 16:9 default (the reported "video item
    // size doesn't survive serialization" bug). Audio stays `.zero` (a fixed-height row; naturalSize is ignored).
    func test_media_recoversNaturalSizeFromMedia() {
        let image = TelegramMediaImage(
            imageId: MediaId(namespace: 1, id: 3003),
            representations: [TelegramMediaImageRepresentation(
                dimensions: PixelDimensions(width: 800, height: 600), resource: EmptyMediaResource(),
                progressiveSizes: [], immediateThumbnailData: nil)],
            immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
        let imageBack = chatInputContent(fromInstantPage: instantPage(from: ChatInputContent(blocks: [
            .media(ChatInputMedia(media: image, kind: .image,
                                  naturalSize: ChatInputSize(width: 800, height: 600),
                                  displayWidth: nil, alignment: .center, caption: []))])))
        guard case .media(let mi)? = imageBack.blocks.first else { return XCTFail("expected .media(image)") }
        XCTAssertEqual(mi.naturalSize, ChatInputSize(width: 800, height: 600),
                       "image natural size recovered from its largest representation")

        let file = TelegramMediaFile(
            fileId: MediaId(namespace: 1, id: 4004), partialReference: nil, resource: EmptyMediaResource(),
            previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "video/mp4",
            size: nil,
            attributes: [.Video(duration: 3, size: PixelDimensions(width: 1920, height: 1080), flags: [],
                                preloadSize: nil, coverTime: nil, videoCodec: nil)],
            alternativeRepresentations: [])
        let videoBack = chatInputContent(fromInstantPage: instantPage(from: ChatInputContent(blocks: [
            .media(ChatInputMedia(media: file, kind: .video,
                                  naturalSize: ChatInputSize(width: 1920, height: 1080),
                                  displayWidth: nil, alignment: .center, caption: []))])))
        guard case .media(let mv)? = videoBack.blocks.first else { return XCTFail("expected .media(video)") }
        XCTAssertEqual(mv.naturalSize, ChatInputSize(width: 1920, height: 1080),
                       "video natural size recovered from the .Video attribute")
    }

    // 23. A multi-item (>=2) media container round-trips through a single InstantPage .collage block (Task 9);
    //     a single-item container stays byte-identical to the plain .image/.video block (no .collage wrapper).
    func test_roundTrip_twoImageContainer_viaCollage() {
        let img1 = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 1), representations: [imageRep(100, 100)], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
        let img2 = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 2), representations: [imageRep(60, 90)], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
        let content = ChatInputContent(blocks: [.media(ChatInputMedia(items: [
            ChatInputMediaItem(media: img1, kind: .image, naturalSize: ChatInputSize(width: 100, height: 100)),
            ChatInputMediaItem(media: img2, kind: .video, naturalSize: ChatInputSize(width: 60, height: 90)),
        ], displayWidth: nil, alignment: .center, caption: []))])
        // Forward produces a single .collage block.
        let page = instantPage(from: content)
        guard case .collage = page.blocks.first else { return XCTFail("expected .collage") }
        // Reverse restores the container (naturalSize recovered from the resolved media).
        XCTAssertEqual(chatInputContent(fromInstantPage: page), content)
    }

    func test_singleImageContainer_stillEmitsPlainImageBlock() {
        let img = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 1), representations: [imageRep(100, 100)], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
        let content = ChatInputContent(blocks: [.media(ChatInputMedia(media: img, kind: .image, naturalSize: ChatInputSize(width: 100, height: 100)))])
        let page = instantPage(from: content)
        // count==1 stays byte-identical: a plain .image block, not .collage.
        guard case .image = page.blocks.first else { return XCTFail("expected .image (not collage)") }
        XCTAssertEqual(chatInputContent(fromInstantPage: page), content)
    }

    // Bonus: a mixed document combining several block kinds.
    // Uses the new canonical `.blockQuote` form (which round-trips 1:1); quote paragraphs and `.collapsedQuote`
    // still forward correctly but normalize to `.blockQuote` on the reverse, so those inputs cannot use assertRoundTrips.
    func test_mixedDocument() {
        var bold = ChatInputInlineAttributes(); bold.bold = true
        var mention = ChatInputInlineAttributes(); mention.entity = .mention(EnginePeer.Id(5))
        assertRoundTrips(ChatInputContent(blocks: [
            body([ChatInputRun(text: "intro "), ChatInputRun(text: "bold", attributes: bold)]),
            // Two quote paragraphs formerly used here. They forward as one coalesced blockQuote
            // (collapsed:false) with two inner body paragraphs — use the canonical blockQuote form.
            .blockQuote(ChatInputBlockQuote(
                content: ChatInputContent(blocks: [
                    body([ChatInputRun(text: "q1")]),
                    body([ChatInputRun(text: "q2")])
                ]),
                collapsed: false)),
            .code(ChatInputCode(language: "py", runs: [ChatInputRun(text: "print(1)")])),
            body([ChatInputRun(text: "by ", attributes: ChatInputInlineAttributes()), ChatInputRun(text: "@user", attributes: mention)]),
            // Formerly .collapsedQuote(...) — replaced by the canonical collapsed blockQuote form.
            .blockQuote(ChatInputBlockQuote(
                content: ChatInputContent(blocks: [body([ChatInputRun(text: "hidden")])]),
                collapsed: true))
        ]), "mixed multi-block document")
    }

    // Regression: a non-body paragraph that ALSO carries a list (a degenerate heading+list — the editor's heading/
    // quote styles and list membership are mutually exclusive in practice) previously infinite-looped the forward
    // because the list branch didn't guard on `.body`. It must return promptly and canonicalize to its style (the
    // list is dropped). If the guard regressed, this test would HANG (timeout), not just fail.
    func test_headingWithList_doesNotHang_canonicalizesToHeading() {
        let input = ChatInputContent(blocks: [
            .paragraph(ChatInputParagraph(style: .heading1, list: ChatInputListMembership(marker: .bullet, level: 0), runs: [ChatInputRun(text: "x")]))
        ])
        let expected = ChatInputContent(blocks: [
            .paragraph(ChatInputParagraph(style: .heading1, list: nil, runs: [ChatInputRun(text: "x")]))
        ])
        XCTAssertEqual(chatInputContent(fromInstantPage: instantPage(from: input)), expected,
                       "heading+list canonicalizes to a plain heading (list dropped), no hang")
    }

    // 17. A checklist with mixed checked state round-trips identically (checked=false/true/false).
    func test_checklist_roundTrips_withMixedCheckedState() {
        func checkItem(_ checked: Bool, _ text: String) -> ChatInputBlock {
            .paragraph(ChatInputParagraph(style: .body,
                list: ChatInputListMembership(marker: .checklist, level: 0, checked: checked),
                runs: [ChatInputRun(text: text)]))
        }
        assertRoundTrips(ChatInputContent(blocks: [
            checkItem(false, "todo"),
            checkItem(true, "done"),
            checkItem(false, "later"),
        ]), "checklist with mixed checked state")
    }

    private func makeAudioFile(id: Int64, isVoice: Bool) -> TelegramMediaFile {
        let audio: TelegramMediaFileAttribute = .Audio(isVoice: isVoice, duration: 5, title: isVoice ? nil : "Song",
                                                       performer: isVoice ? nil : "Artist", waveform: nil)
        return TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.CloudFile, id: id), partialReference: nil,
                                 resource: EmptyMediaResource(), previewRepresentations: [], videoThumbnails: [],
                                 immediateThumbnailData: nil, mimeType: "audio/mpeg", size: nil,
                                 attributes: [audio], alternativeRepresentations: [])
    }

    func testAudioMusicRoundTripContentToInstantPageToContent() {
        let file = makeAudioFile(id: 100, isVoice: false)
        let media = ChatInputMedia(media: file, kind: .audio, naturalSize: ChatInputSize(width: 0, height: 0),
                                   displayWidth: nil, alignment: .center, caption: [ChatInputRun(text: "cap")])
        let content = ChatInputContent(blocks: [.media(media)])

        let page = instantPage(from: content)
        // Forward: one .audio block, file stored in the page media dict.
        guard case .audio(let id, let caption)? = page.blocks.first else { return XCTFail("expected .audio block") }
        XCTAssertEqual(id, file.fileId)
        XCTAssertNotNil(page.media[id])
        XCTAssertEqual(caption.text.plainText, "cap")

        // Reverse: back to a .audio media block, file + caption preserved.
        let back = chatInputContent(fromInstantPage: page)
        guard case .media(let m)? = back.blocks.first else { return XCTFail("expected .media block") }
        XCTAssertEqual(m.kind, .audio)
        XCTAssertEqual(m.media.id, file.fileId)
    }

    func testAudioVoiceStaysVoiceOnRoundTrip() {
        let file = makeAudioFile(id: 101, isVoice: true)
        let content = ChatInputContent(blocks: [.media(ChatInputMedia(media: file, kind: .audio,
            naturalSize: ChatInputSize(width: 0, height: 0), displayWidth: nil, alignment: .center, caption: []))])
        let back = chatInputContent(fromInstantPage: instantPage(from: content))
        guard case .media(let m)? = back.blocks.first, let f = m.media as? TelegramMediaFile else {
            return XCTFail("expected .media(file)")
        }
        XCTAssertTrue(f.isVoice)
    }

    func test_location() {
        // A location media block round-trips through .map, canonicalizing to the editor's media defaults.
        let map = TelegramMediaMap(latitude: 37.7955, longitude: -122.3937, heading: nil, accuracyRadius: nil, venue: nil)
        let locationMedia = ChatInputMedia(
            media: map,
            kind: .location,
            naturalSize: ChatInputSize(width: 0.0, height: 0.0),
            displayWidth: nil,
            alignment: .center,
            caption: [ChatInputRun(text: "Ferry Building")]
        )
        let content = ChatInputContent(blocks: [.media(locationMedia)])

        // Forward: produces exactly one .map block carrying the coordinates + caption, with NO media-dict entry.
        let page = instantPage(from: content)
        XCTAssertEqual(page.blocks.count, 1, "one location block -> one .map block")
        guard case let .map(latitude, longitude, _, dimensions, caption) = page.blocks[0] else {
            return XCTFail("expected a .map block, got \(page.blocks[0])")
        }
        XCTAssertEqual(latitude, 37.7955, accuracy: 0.0001)
        XCTAssertEqual(longitude, -122.3937, accuracy: 0.0001)
        XCTAssertEqual(dimensions.width, 600, "zero naturalSize -> 600x300 fallback")
        XCTAssertEqual(dimensions.height, 300)
        XCTAssertEqual(caption.text, .plain("Ferry Building"))
        XCTAssertTrue(page.media.isEmpty, "a .map block carries coordinates inline; nothing goes in the media dict")

        // Round-trip identity (input built with the canonical defaults).
        XCTAssertEqual(chatInputContent(fromInstantPage: page), content, "location round-trips through .map")
    }

    // 15. Pull-quote: 1:1 round-trip preserving runs, bold attribute, and interior "\n".
    func test_pullQuote_instantPageRoundTrip() {
        // A pull quote with two runs: one bold and one plain, containing an interior newline.
        var bold = ChatInputInlineAttributes(); bold.bold = true
        let content = ChatInputContent(blocks: [
            .pullQuote(ChatInputPullQuote(runs: [
                ChatInputRun(text: "bold\nline", attributes: bold),
                ChatInputRun(text: "plain"),
            ]))
        ])

        // Forward: must produce exactly one .pullQuote block.
        let page = instantPage(from: content)
        XCTAssertEqual(page.blocks.count, 1, "one pullQuote block -> one InstantPage .pullQuote block")
        guard case let .pullQuote(rt, _) = page.blocks[0] else {
            return XCTFail("expected a .pullQuote block, got \(page.blocks[0])")
        }
        XCTAssertEqual(rt.plainText, "bold\nlineplain", "plain text is the joined run texts")

        // Reverse: runs are preserved (bold attribute + interior newline + plain run boundary).
        let restored = chatInputContent(fromInstantPage: page)
        XCTAssertEqual(restored, content, "pull-quote round-trips exactly through InstantPage")
        if case let .pullQuote(pq) = restored.blocks[0] {
            XCTAssertEqual(pq.runs.count, 2, "run boundary preserved")
            XCTAssertTrue(pq.runs[0].attributes.bold, "bold attribute preserved")
            XCTAssertEqual(pq.runs[0].text, "bold\nline", "interior newline preserved")
            XCTAssertEqual(pq.runs[1].text, "plain")
        } else {
            XCTFail("expected .pullQuote block after round-trip")
        }
    }

    // 16. ChatInputListMarker.checklist (rawValue 2) Codable round-trip, and back-compat: an old payload
    //     without `checked` decodes correctly (nil checked, marker preserved).
    func test_checklistMembership_codableRoundTrip_andBackCompat() throws {
        let m = ChatInputListMembership(marker: .checklist, level: 0, checked: true)
        let data = try JSONEncoder().encode(m)
        XCTAssertEqual(try JSONDecoder().decode(ChatInputListMembership.self, from: data), m)
        // Back-compat: an old payload without `checked` decodes to nil, marker preserved.
        let old = #"{"marker":{"raw":0},"level":0}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ChatInputListMembership.self, from: old)
        XCTAssertEqual(decoded.marker, .bullet)
        XCTAssertNil(decoded.checked)
    }

    // 18. ChatInputBlock.blockQuote — nested + collapsed round-trip through InstantPage 1:1.
    func test_chatInputBlockQuote_instantPageRoundTrip_nestedAndCollapsed() {
        let innerPara = ChatInputParagraph(style: .body, runs: [ChatInputRun(text: "hi")])
        let inner = ChatInputBlockQuote(content: ChatInputContent(blocks: [.paragraph(innerPara)]), collapsed: false)
        let outer = ChatInputBlockQuote(content: ChatInputContent(blocks: [.blockQuote(inner)]), collapsed: true)
        let content = ChatInputContent(blocks: [.blockQuote(outer)])
        let back = chatInputContent(fromInstantPage: instantPage(from: content))
        XCTAssertEqual(back, content, "nested + collapsed blockQuote must survive InstantPage round-trip 1:1")
    }

    // 19. isEntityExpressible flat-only rule for ChatInputBlock.blockQuote.
    func test_blockQuote_isEntityExpressible_flatOnly() {
        // Flat single-paragraph non-collapsed quote → entity-expressible.
        let flat = ChatInputContent(blocks: [
            .blockQuote(ChatInputBlockQuote(
                content: ChatInputContent(blocks: [
                    .paragraph(ChatInputParagraph(style: .body, runs: [ChatInputRun(text: "q")]))
                ]),
                collapsed: false))
        ])
        XCTAssertTrue(flat.isEntityExpressible(), "flat single-paragraph non-collapsed blockQuote → entity-expressible")

        // Nested quote (blockQuote inside blockQuote) → not entity-expressible.
        let nested = ChatInputContent(blocks: [
            .blockQuote(ChatInputBlockQuote(
                content: ChatInputContent(blocks: [
                    .blockQuote(ChatInputBlockQuote(
                        content: ChatInputContent(blocks: [
                            .paragraph(ChatInputParagraph(style: .body, runs: [ChatInputRun(text: "q")]))
                        ]),
                        collapsed: false))
                ]),
                collapsed: false))
        ])
        XCTAssertFalse(nested.isEntityExpressible(), "nested blockQuote → not entity-expressible")

        // Collapsed single-paragraph quote → not entity-expressible.
        let collapsed = ChatInputContent(blocks: [
            .blockQuote(ChatInputBlockQuote(
                content: ChatInputContent(blocks: [
                    .paragraph(ChatInputParagraph(style: .body, runs: [ChatInputRun(text: "q")]))
                ]),
                collapsed: true))
        ])
        XCTAssertFalse(collapsed.isEntityExpressible(), "collapsed blockQuote → not entity-expressible")
    }

    // 20. Pull-quote author line round-trips with a PLAIN author, and the emitted InstantPage caption is
    // BOLD+ITALIC-wrapped (so the recipient renders it bold+italic) even though `author` itself carries
    // neither attribute — both are ambient (forced forward, stripped in reverse), mirroring block-quote bold
    // but ALSO forcing italic (pull quotes only; see `test_blockQuote_authorRoundTrips_andEmitsBoldCaption`
    // below for the block-quote bold-only contrast). Identity holds here because the forced attributes
    // cancel out exactly for a plain input author.
    func test_pullQuote_authorRoundTrips_andEmitsBoldItalicCaption() {
        let pq = ChatInputPullQuote(runs: [ChatInputRun(text: "quote")], author: [ChatInputRun(text: "Ada")])
        assertRoundTrips(ChatInputContent(blocks: [.pullQuote(pq)]), "pull quote with a plain author")
        // The emitted InstantPage caption is bold+italic-wrapped (so the recipient renders bold+italic).
        let page = instantPage(from: ChatInputContent(blocks: [.pullQuote(pq)]))
        guard case let .pullQuote(_, caption)? = page.blocks.first else { return XCTFail("no pullQuote") }
        guard case let .italic(inner) = caption else { return XCTFail("caption should be italic-wrapped, got \(caption)") }
        if case .bold = inner {} else { XCTFail("caption should ALSO be bold-wrapped, got \(inner)") }
    }

    // 21. Block-quote author line round-trips, and the emitted InstantPage caption is bold-wrapped (so the
    // recipient renders it bold) even though `author` itself carries no bold attribute. Unlike a pull-quote
    // author (bold+italic, above), a block-quote author stays BOLD-ONLY — the caption must NOT be
    // italic-wrapped anywhere in the chain.
    func test_blockQuote_authorRoundTrips_andEmitsBoldCaption() {
        let inner = ChatInputContent(blocks: [.paragraph(ChatInputParagraph(style: .body, runs: [ChatInputRun(text: "body")]))])
        let bq = ChatInputBlockQuote(content: inner, collapsed: false, author: [ChatInputRun(text: "Jobs")])
        assertRoundTrips(ChatInputContent(blocks: [.blockQuote(bq)]), "block quote with an author")
        // The emitted InstantPage caption is bold (so the recipient renders bold) — and NOT italic-wrapped.
        let page = instantPage(from: ChatInputContent(blocks: [.blockQuote(bq)]))
        guard case let .blockQuote(_, caption, _)? = page.blocks.first else { return XCTFail("no blockQuote") }
        guard case let .bold(boldInner) = caption else { return XCTFail("caption should be bold-wrapped, got \(caption)") }
        if case .italic = boldInner { XCTFail("block-quote author caption must stay bold-only, not italic") }
    }

    // 22. An empty author still emits a `.empty` caption (unchanged forward output).
    func test_emptyAuthor_stillEmitsEmptyCaption() {
        let bq = ChatInputBlockQuote(content: ChatInputContent(blocks: [.paragraph(ChatInputParagraph(style: .body, runs: [ChatInputRun(text: "b")]))]), collapsed: false, author: [])
        let page = instantPage(from: ChatInputContent(blocks: [.blockQuote(bq)]))
        guard case let .blockQuote(_, caption, _)? = page.blocks.first else { return XCTFail() }
        if case .empty = caption {} else { XCTFail("empty author should emit .empty caption") }
    }

    // 23. The `spoiler` flag on `.image` survives a raw Postbox encode/decode via the `"sp"` key.
    func test_instantPageBlock_image_spoiler_postboxRoundTrip() {
        let block: InstantPageBlock = .image(id: MediaId(namespace: 1, id: 5),
                                             caption: InstantPageCaption(text: .empty, credit: .empty),
                                             url: nil, webpageId: nil, spoiler: true)
        let encoder = PostboxEncoder(); encoder.encodeObject(block, forKey: "b")
        let decoder = PostboxDecoder(buffer: MemoryBuffer(data: encoder.makeData()))
        guard case let .image(_, _, _, _, spoiler)? = decoder.decodeObjectForKey("b", decoder: { InstantPageBlock(decoder: $0) }) as? InstantPageBlock else { return XCTFail("decode") }
        XCTAssertTrue(spoiler)
    }

    // 24. A `.video` block with `spoiler: false` decodes back to false (absent → false default holds).
    func test_instantPageBlock_video_spoiler_defaultsFalse() {
        let block: InstantPageBlock = .video(id: MediaId(namespace: 1, id: 6),
                                             caption: InstantPageCaption(text: .empty, credit: .empty),
                                             autoplay: false, loop: false, spoiler: false)
        let encoder = PostboxEncoder(); encoder.encodeObject(block, forKey: "b")
        let decoder = PostboxDecoder(buffer: MemoryBuffer(data: encoder.makeData()))
        guard case let .video(_, _, _, _, spoiler)? = decoder.decodeObjectForKey("b", decoder: { InstantPageBlock(decoder: $0) }) as? InstantPageBlock else { return XCTFail("decode") }
        XCTAssertFalse(spoiler)
    }

    // 25. A single-item media block's `isSpoiler` survives ChatInputContent -> InstantPage -> ChatInputContent.
    func test_chatInputContent_mediaSpoiler_roundTripsThroughInstantPage_single() {
        let image = TelegramMediaImage(imageId: MediaId(namespace: 1, id: 11), representations: [], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
        var item = ChatInputMediaItem(media: image, kind: .image, naturalSize: ChatInputSize(width: 4, height: 3))
        item.isSpoiler = true
        let content = ChatInputContent(blocks: [.media(ChatInputMedia(items: [item]))])
        let back = chatInputContent(fromInstantPage: instantPage(from: content))
        guard case let .media(m)? = back.blocks.first, let first = m.items.first else { return XCTFail() }
        XCTAssertTrue(first.isSpoiler)
    }

    // 26. A collage's per-item `isSpoiler` survives the round-trip independently per item.
    func test_chatInputContent_mediaSpoiler_roundTripsThroughInstantPage_album() {
        let a = TelegramMediaImage(imageId: MediaId(namespace: 1, id: 1), representations: [], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
        let b = TelegramMediaImage(imageId: MediaId(namespace: 1, id: 2), representations: [], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
        var i0 = ChatInputMediaItem(media: a, kind: .image, naturalSize: ChatInputSize(width: 1, height: 1))
        let i1 = ChatInputMediaItem(media: b, kind: .image, naturalSize: ChatInputSize(width: 1, height: 1))
        i0.isSpoiler = true
        let content = ChatInputContent(blocks: [.media(ChatInputMedia(items: [i0, i1]))])
        let back = chatInputContent(fromInstantPage: instantPage(from: content))
        guard case let .media(m)? = back.blocks.first, m.items.count == 2 else { return XCTFail() }
        XCTAssertTrue(m.items[0].isSpoiler)
        XCTAssertFalse(m.items[1].isSpoiler)
    }

    // 27. Task 5: a mosaic-mode multi-item container forwards to `.collage` (not `.slideshow`) and the reverse
    // recovers `displayMode: .mosaic` explicitly (not just the Codable default — see the slideshow test below for
    // the case that actually distinguishes the two).
    func test_displayMode_mosaic_roundTripsViaCollage() {
        let img1 = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 1), representations: [imageRep(100, 100)], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
        let img2 = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 2), representations: [imageRep(60, 90)], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
        let content = ChatInputContent(blocks: [.media(ChatInputMedia(items: [
            ChatInputMediaItem(media: img1, kind: .image, naturalSize: ChatInputSize(width: 100, height: 100)),
            ChatInputMediaItem(media: img2, kind: .image, naturalSize: ChatInputSize(width: 60, height: 90)),
        ], displayWidth: nil, alignment: .center, displayMode: .mosaic, caption: []))])
        let page = instantPage(from: content)
        guard case .collage = page.blocks.first else { return XCTFail("expected .collage for mosaic mode") }
        let back = chatInputContent(fromInstantPage: page)
        guard case let .media(m)? = back.blocks.first else { return XCTFail("expected .media") }
        XCTAssertEqual(m.displayMode, .mosaic)
        XCTAssertEqual(back, content)
    }

    // 28. Task 5: a slideshow-mode multi-item container forwards to a `.slideshow` InstantPage block (NOT
    // `.collage`), and the reverse recovers `displayMode: .slideshow` — the round-trip that actually exercises
    // the new `.slideshow` production/consumption added by Task 5.
    func test_displayMode_slideshow_roundTripsViaSlideshowBlock() {
        let img1 = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 3), representations: [imageRep(100, 100)], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
        let img2 = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 4), representations: [imageRep(60, 90)], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
        let content = ChatInputContent(blocks: [.media(ChatInputMedia(items: [
            ChatInputMediaItem(media: img1, kind: .image, naturalSize: ChatInputSize(width: 100, height: 100)),
            ChatInputMediaItem(media: img2, kind: .video, naturalSize: ChatInputSize(width: 60, height: 90)),
        ], displayWidth: nil, alignment: .center, displayMode: .slideshow, caption: []))])
        // Forward produces a `.slideshow` block, not `.collage`.
        let page = instantPage(from: content)
        guard case .slideshow = page.blocks.first else { return XCTFail("expected .slideshow for slideshow mode") }
        // Reverse recovers `displayMode: .slideshow` and the full round-trip is identity.
        let back = chatInputContent(fromInstantPage: page)
        guard case let .media(m)? = back.blocks.first else { return XCTFail("expected .media") }
        XCTAssertEqual(m.displayMode, .slideshow)
        XCTAssertEqual(back, content)
    }

    // MARK: Document (generic file) blocks

    private func makeDocumentFile(id: Int64, name: String = "Report.pdf") -> TelegramMediaFile {
        return TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.CloudFile, id: id), partialReference: nil,
                                 resource: EmptyMediaResource(), previewRepresentations: [], videoThumbnails: [],
                                 immediateThumbnailData: nil, mimeType: "application/pdf", size: 1024,
                                 attributes: [.FileName(fileName: name)], alternativeRepresentations: [])
    }

    func testDocumentForwardEmitsADocumentBlock() {
        let file = makeDocumentFile(id: 200)
        let content = ChatInputContent(blocks: [.media(ChatInputMedia(
            media: file, kind: .document, naturalSize: ChatInputSize(width: 0, height: 0),
            displayWidth: nil, alignment: .center, caption: []))])

        let page = instantPage(from: content)
        guard case .document(let id, _)? = page.blocks.first else { return XCTFail("expected a .document block") }
        XCTAssertEqual(id, file.fileId)
        XCTAssertNotNil(page.media[id], "the file must be stored in the page media dict so it uploads")
    }

    func testDocumentIsNeverGroupedIntoACollage() {
        // Two media in ONE container: the image groups, the document is skipped (permanently single-item).
        let image = TelegramMediaImage(imageId: MediaId(namespace: Namespaces.Media.CloudImage, id: 201),
                                       representations: [imageRep(100, 80)], immediateThumbnailData: nil,
                                       reference: nil, partialReference: nil, flags: [])
        let content = ChatInputContent(blocks: [.media(ChatInputMedia(items: [
            ChatInputMediaItem(media: image, kind: .image, naturalSize: ChatInputSize(width: 100, height: 80)),
            ChatInputMediaItem(media: makeDocumentFile(id: 202), kind: .document,
                               naturalSize: ChatInputSize(width: 0, height: 0)),
        ], displayWidth: nil, alignment: .center, caption: []))])

        let page = instantPage(from: content)
        guard case .collage(let items, _)? = page.blocks.first else { return XCTFail("expected a .collage block") }
        XCTAssertEqual(items.count, 1, "the document must be skipped, leaving only the image")
        guard case .image = items[0] else { return XCTFail("expected the surviving item to be the image") }
    }

    func testDocumentRoundTripContentToInstantPageToContent() {
        let file = makeDocumentFile(id: 300)
        let media = ChatInputMedia(media: file, kind: .document, naturalSize: ChatInputSize(width: 0, height: 0),
                                   displayWidth: nil, alignment: .center, caption: [ChatInputRun(text: "cap")])
        let content = ChatInputContent(blocks: [.media(media)])

        let page = instantPage(from: content)
        guard case .document(let id, let caption)? = page.blocks.first else { return XCTFail("expected .document") }
        XCTAssertEqual(id, file.fileId)
        XCTAssertEqual(caption.text.plainText, "cap")

        // Reverse: back to a .document media block, file + caption preserved. (The EDITOR drops the caption
        // at the MediaBlockBox boundary — a document is caption-less on screen — but the chat currency
        // carries it, exactly as .audio does.)
        let back = chatInputContent(fromInstantPage: page)
        guard case .media(let m)? = back.blocks.first else { return XCTFail("expected .media") }
        XCTAssertEqual(m.kind, .document)
        XCTAssertEqual(m.media.id, file.fileId)
        XCTAssertEqual(m.caption.map(\.text).joined(), "cap")
    }

    func testDocumentMediaKindRawValueIsStable() {
        // Persisted in drafts (local + cross-device). Changing it invalidates stored drafts.
        XCTAssertEqual(ChatInputMediaKind.document.rawValue, 4)
    }

    // MARK: - InstantPage buttons

    /// The file's guaranteed invariant: `chatInputContent(fromInstantPage: instantPage(from: c)) == c`.
    /// Until now `.buttonRow` fell through the reverse `default:` and a button-bearing message lost its
    /// buttons on the edit round-trip — the data loss this whole feature exists to fix.
    func test_buttonRow_survivesTheIdentityRoundTrip() {
        let content = ChatInputContent(blocks: [.buttonRow(ChatInputButtonRow(
            buttons: [
                ChatInputButton(label: [ChatInputRun(text: "Open")], action: .url("https://telegram.org"), color: .primary, isLink: false),
                ChatInputButton(label: [ChatInputRun(text: "Pay")], action: .payment, color: .danger, isLink: true),
            ],
            alignment: .right
        ))])
        XCTAssertEqual(chatInputContent(fromInstantPage: instantPage(from: content)), content)
    }

    func test_inlineButton_survivesTheIdentityRoundTrip() {
        var attributes = ChatInputInlineAttributes()
        attributes.entity = .button(ChatInputButton(label: [ChatInputRun(text: "Go")], action: .url("https://telegram.org"), color: nil, isLink: true))
        let content = ChatInputContent(blocks: [.paragraph(ChatInputParagraph(style: .body, runs: [
            ChatInputRun(text: "tap "),
            ChatInputRun(text: "\u{FFFC}", attributes: attributes),
            ChatInputRun(text: " now"),
        ]))])
        XCTAssertEqual(chatInputContent(fromInstantPage: instantPage(from: content)), content)
    }

    /// A formatted button must round-trip too: the forward applies the wrapper chain to EVERY run
    /// uniformly, so the reverse has to unwrap through bold/italic to reach the `.textButton` leaf.
    func test_formattedInlineButton_survivesTheIdentityRoundTrip() {
        var attributes = ChatInputInlineAttributes(bold: true, italic: true)
        attributes.entity = .button(ChatInputButton(label: [ChatInputRun(text: "Go")], action: .disabled, color: .success, isLink: false))
        let content = ChatInputContent(blocks: [.paragraph(ChatInputParagraph(style: .body, runs: [
            ChatInputRun(text: "\u{FFFC}", attributes: attributes),
        ]))])
        XCTAssertEqual(chatInputContent(fromInstantPage: instantPage(from: content)), content)
    }

    /// A rich label (bold + a link) must survive inside the button.
    func test_richButtonLabel_survivesTheIdentityRoundTrip() {
        var linkAttributes = ChatInputInlineAttributes()
        linkAttributes.entity = .url("https://telegram.org")
        let content = ChatInputContent(blocks: [.buttonRow(ChatInputButtonRow(
            buttons: [ChatInputButton(
                label: [ChatInputRun(text: "bold", attributes: ChatInputInlineAttributes(bold: true)),
                        ChatInputRun(text: "link", attributes: linkAttributes)],
                action: .url("https://telegram.org")
            )],
            alignment: .left
        ))])
        XCTAssertEqual(chatInputContent(fromInstantPage: instantPage(from: content)), content)
    }

    /// The block must actually reach the InstantPage, not merely survive an internal round-trip.
    func test_buttonRow_emitsAPageBlock() {
        let content = ChatInputContent(blocks: [.buttonRow(ChatInputButtonRow(
            buttons: [ChatInputButton(label: [ChatInputRun(text: "Open")], action: .url("https://telegram.org"), color: nil, isLink: false)],
            alignment: .left
        ))])
        guard case let .buttonRow(alignment, buttons) = instantPage(from: content).blocks.first else {
            return XCTFail("expected an InstantPageBlock.buttonRow")
        }
        XCTAssertEqual(alignment, .left)
        XCTAssertEqual(buttons.count, 1)
        XCTAssertEqual(buttons[0].action, .url("https://telegram.org"))
    }

    /// And the inline one must reach the page as a `RichText.textButton`, not as its label text.
    func test_inlineButton_emitsATextButton() {
        var attributes = ChatInputInlineAttributes()
        attributes.entity = .button(ChatInputButton(label: [ChatInputRun(text: "Go")], action: .disabled))
        let content = ChatInputContent(blocks: [.paragraph(ChatInputParagraph(style: .body, runs: [
            ChatInputRun(text: "\u{FFFC}", attributes: attributes),
        ]))])
        guard case let .paragraph(text) = instantPage(from: content).blocks.first else {
            return XCTFail("expected a paragraph block")
        }
        guard case let .textButton(button) = text else {
            return XCTFail("expected a RichText.textButton, got \(text)")
        }
        XCTAssertEqual(button.text.plainText, "Go")
    }
}
