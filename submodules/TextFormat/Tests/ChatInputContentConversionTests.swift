import XCTest
import UIKit
import TelegramCore
import Postbox
@testable import TextFormat

final class ChatInputContentConversionTests: XCTestCase {

    /// End-to-end guard for the LIVE legacy composer path: after `setInputContent` sets the field's
    /// `attributedText = attributedString(from: content)`, the field runs `refreshChatTextInputAttributes`
    /// (→ `refreshBlockQuotes`) as decoration. This verifies that a one-blockQuote multi-line quote's single
    /// contiguous `.block` run SURVIVES that decoration (does not re-split at the interior newline), which is
    /// what determines the number of on-screen quote boxes.
    func test_liveDecoration_multiLineQuote_staysOneContiguousBlock() {
        // What `attributedString(from: .blockQuote([para AAA, para BBB]))` produces: "AAA\nBBB" with ONE
        // `.block` object over the whole range (interior "\n" included).
        let content = ChatInputContent(blocks: [
            .blockQuote(ChatInputBlockQuote(
                content: ChatInputContent(blocks: [
                    .paragraph(ChatInputParagraph(style: .body, runs: [ChatInputRun(text: "AAA")])),
                    .paragraph(ChatInputParagraph(style: .body, runs: [ChatInputRun(text: "BBB")])),
                ]),
                collapsed: false))
        ])
        let textView = UITextView()
        textView.attributedText = attributedString(from: content)

        refreshChatTextInputAttributes(
            context: NSObject(),
            textView: textView,
            primaryTextColor: .black,
            accentTextColor: .blue,
            baseFontSize: 17.0,
            spoilersRevealed: false,
            availableEmojis: Set(),
            emojiViewProvider: nil,
            makeCollapsedQuoteAttachment: nil)

        XCTAssertEqual(textView.textStorage.string, "AAA\nBBB")
        var ranges: [NSRange] = []
        textView.textStorage.enumerateAttribute(ChatTextInputAttributes.block, in: NSRange(location: 0, length: textView.textStorage.length), options: []) { value, range, _ in
            if let v = value as? ChatTextInputTextQuoteAttribute, case .quote = v.kind { ranges.append(range) }
        }
        XCTAssertEqual(ranges, [NSRange(location: 0, length: 7)], "decoration must keep ONE contiguous quote box, not two")
    }

    // MARK: - Task 4: attributedString(from:)

    func test_attributedString_emitsSemanticAttributes() {
        var a = ChatInputInlineAttributes(); a.bold = true
        let content = ChatInputContent(blocks: [
            .paragraph(ChatInputParagraph(style: .body, runs: [ChatInputRun(text: "Hi", attributes: a)]))
        ])
        let s = attributedString(from: content)
        XCTAssertEqual(s.string, "Hi")
        XCTAssertNotNil(s.attribute(ChatTextInputAttributes.bold, at: 0, effectiveRange: nil))
    }

    func test_attributedString_renderListMarkers_prependsBulletAndNumberText() {
        let content = ChatInputContent(blocks: [
            .paragraph(ChatInputParagraph(style: .body, list: ChatInputListMembership(marker: .bullet, level: 0), runs: [ChatInputRun(text: "First")])),
            .paragraph(ChatInputParagraph(style: .body, list: ChatInputListMembership(marker: .bullet, level: 0), runs: [ChatInputRun(text: "Second")])),
            .paragraph(ChatInputParagraph(style: .body, list: ChatInputListMembership(marker: .ordered, level: 0), runs: [ChatInputRun(text: "One")])),
            .paragraph(ChatInputParagraph(style: .body, list: ChatInputListMembership(marker: .ordered, level: 0), runs: [ChatInputRun(text: "Two")])),
        ])
        // Default (unchanged legacy behavior): list membership is ignored, markers not rendered.
        XCTAssertEqual(attributedString(from: content).string, "First\nSecond\nOne\nTwo")
        // Opt-in: markers rendered as literal text (bullet, then a fresh 1./2. ordered run).
        XCTAssertEqual(attributedString(from: content, renderListMarkers: true).string, "• First\n• Second\n1. One\n2. Two")
    }

    func test_attributedString_renderListMarkers_orderedResetsAfterNonListParagraph() {
        let content = ChatInputContent(blocks: [
            .paragraph(ChatInputParagraph(style: .body, list: ChatInputListMembership(marker: .ordered, level: 0), runs: [ChatInputRun(text: "A")])),
            .paragraph(ChatInputParagraph(style: .body, runs: [ChatInputRun(text: "gap")])),
            .paragraph(ChatInputParagraph(style: .body, list: ChatInputListMembership(marker: .ordered, level: 0), runs: [ChatInputRun(text: "B")])),
        ])
        XCTAssertEqual(attributedString(from: content, renderListMarkers: true).string, "1. A\ngap\n1. B")
    }

    func test_attributedString_blocksJoinedByNewline_andCodeContiguous() {
        let content = ChatInputContent(blocks: [
            .paragraph(ChatInputParagraph(style: .body, runs: [ChatInputRun(text: "a")])),
            .code(ChatInputCode(language: "py", runs: [ChatInputRun(text: "b\nc")]))
        ])
        let s = attributedString(from: content)
        XCTAssertEqual(s.string, "a\nb\nc")
        let q = s.attribute(ChatTextInputAttributes.block, at: 2, effectiveRange: nil) as? ChatTextInputTextQuoteAttribute
        if case .code(let lang)? = q?.kind { XCTAssertEqual(lang, "py") } else { XCTFail("expected .code") }
    }

    // MARK: - Task 0 (1b-ii): multi-line quote contiguity

    /// A `.blockQuote(collapsed: false)` with multiple inner paragraphs emits as ONE contiguous `.block` range
    /// (interior "\n"s included) — the content.plainText joins inner paragraphs with "\n", and a single
    /// `.block` attribute covers the whole range.
    func test_attributedString_multiLineBlockQuote_emitsOneContiguousBlock() {
        let content = ChatInputContent(blocks: [
            .paragraph(ChatInputParagraph(style: .body, runs: [ChatInputRun(text: "x")])),
            .blockQuote(ChatInputBlockQuote(
                content: ChatInputContent(blocks: [
                    .paragraph(ChatInputParagraph(style: .body, runs: [ChatInputRun(text: "a")])),
                    .paragraph(ChatInputParagraph(style: .body, runs: [ChatInputRun(text: "b")])),
                ]),
                collapsed: false))
        ])
        let s = attributedString(from: content)
        XCTAssertEqual(s.string, "x\na\nb")
        var ranges: [NSRange] = []
        var objects = Set<ObjectIdentifier>()
        s.enumerateAttribute(ChatTextInputAttributes.block, in: NSRange(location: 0, length: s.length), options: []) { value, range, _ in
            if let v = value as? ChatTextInputTextQuoteAttribute, case .quote = v.kind {
                ranges.append(range); objects.insert(ObjectIdentifier(v))
            }
        }
        XCTAssertEqual(ranges, [NSRange(location: 2, length: 3)], "blockQuote must emit as one contiguous range incl. the interior newline")
        XCTAssertEqual(objects.count, 1, "the whole blockQuote emits one attribute object")
        // The inverse round-trip is lossless: the one contiguous `.block` range parses back to a single
        // multi-paragraph `.blockQuote` (see `test_chatInputContent_contiguousMultiLineQuote_mapsToSingleBlockQuote`
        // and `test_modelRoundTrip_identity_multiParagraphBlockQuote`).
    }

    /// The BUG regression guard: a single `.block`/.quote object spanning an interior "\n" (how the legacy
    /// UITextView represents a multi-line quote) must parse to ONE multi-paragraph `.blockQuote`, not one
    /// `.blockQuote` per line. Previously the per-"\n" split fragmented it, so a save/restore round-trip
    /// (persisted `content`) turned one quote into several.
    func test_chatInputContent_contiguousMultiLineQuote_mapsToSingleBlockQuote() {
        let s = NSMutableAttributedString(string: "AAA\nBBB")
        s.addAttribute(ChatTextInputAttributes.block,
            value: ChatTextInputTextQuoteAttribute(kind: .quote, isCollapsed: false),
            range: NSRange(location: 0, length: 7))
        let parsed = chatInputContent(from: s)
        XCTAssertEqual(parsed.blocks.count, 1, "one contiguous quote run → one blockQuote")
        guard case let .blockQuote(bq) = parsed.blocks[0] else { XCTFail("expected a blockQuote"); return }
        XCTAssertFalse(bq.collapsed)
        XCTAssertEqual(bq.content.blocks.count, 2, "the interior newline becomes two inner paragraphs")
        // And the projection back emits a SINGLE contiguous quote range (one box), not two.
        let back = attributedString(from: parsed)
        XCTAssertEqual(back.string, "AAA\nBBB")
        var ranges: [NSRange] = []
        back.enumerateAttribute(ChatTextInputAttributes.block, in: NSRange(location: 0, length: back.length), options: []) { value, range, _ in
            if let v = value as? ChatTextInputTextQuoteAttribute, case .quote = v.kind { ranges.append(range) }
        }
        XCTAssertEqual(ranges, [NSRange(location: 0, length: 7)], "one quote box, not two")
    }

    /// A multi-paragraph `.blockQuote` now survives the NSAttributedString round-trip unchanged (was lossy).
    func test_modelRoundTrip_identity_multiParagraphBlockQuote() {
        let content = ChatInputContent(blocks: [
            .paragraph(ChatInputParagraph(style: .body, runs: [ChatInputRun(text: "x")])),
            .blockQuote(ChatInputBlockQuote(
                content: ChatInputContent(blocks: [
                    .paragraph(ChatInputParagraph(style: .body, runs: [ChatInputRun(text: "a")])),
                    .paragraph(ChatInputParagraph(style: .body, runs: [ChatInputRun(text: "b")])),
                ]),
                collapsed: false)),
        ])
        XCTAssertEqual(chatInputContent(from: attributedString(from: content)), content)
    }

    /// Per-line `.quote`-attributed spans map to separate `.blockQuote` blocks on parse (Task 16b). The resulting
    /// content's attributed-string projection then emits each blockQuote as its own range. No coalescing.
    func test_chatCurrencyRoundTrip_perLineQuoteAttrs_mapToSeparateBlockQuotes() {
        let s = NSMutableAttributedString(string: "before\nq1\nq2\nafter")
        // "before"=[0,6] \n=6 "q1"=[7,2] \n=9 "q2"=[10,2] \n=12 "after"=[13,5]
        s.addAttribute(ChatTextInputAttributes.block,
            value: ChatTextInputTextQuoteAttribute(kind: .quote, isCollapsed: false),
            range: NSRange(location: 7, length: 2))
        s.addAttribute(ChatTextInputAttributes.block,
            value: ChatTextInputTextQuoteAttribute(kind: .quote, isCollapsed: false),
            range: NSRange(location: 10, length: 2))

        let parsed = chatInputContent(from: s)
        // Each quote paragraph becomes its own `.blockQuote` block.
        XCTAssertEqual(parsed.blocks.count, 4, "before + bq1 + bq2 + after")
        guard case .paragraph = parsed.blocks[0],
              case .blockQuote = parsed.blocks[1],
              case .blockQuote = parsed.blocks[2],
              case .paragraph = parsed.blocks[3] else {
            XCTFail("expected paragraph/blockQuote/blockQuote/paragraph"); return
        }

        let back = attributedString(from: parsed)
        XCTAssertEqual(back.string, "before\nq1\nq2\nafter")
        var ranges: [NSRange] = []
        back.enumerateAttribute(ChatTextInputAttributes.block, in: NSRange(location: 0, length: back.length), options: []) { value, range, _ in
            if let v = value as? ChatTextInputTextQuoteAttribute, case .quote = v.kind {
                ranges.append(range)
            }
        }
        // Two separate ranges — one per blockQuote block.
        XCTAssertEqual(ranges.count, 2, "two separate blockQuote blocks emit two separate ranges")
    }

    // MARK: - Task 5: chatInputContent(from:)

    func test_chatInputContent_parsesInlineAndBlocks() {
        let s = NSMutableAttributedString(string: "a\nq")
        s.addAttribute(ChatTextInputAttributes.bold, value: true as NSNumber, range: NSRange(location: 0, length: 1))
        s.addAttribute(ChatTextInputAttributes.block,
            value: ChatTextInputTextQuoteAttribute(kind: .quote, isCollapsed: false),
            range: NSRange(location: 2, length: 1))
        let c = chatInputContent(from: s)
        XCTAssertEqual(c.blocks.count, 2)
        guard case let .paragraph(p0) = c.blocks[0],
              case let .blockQuote(bq) = c.blocks[1] else { return XCTFail("expected paragraph + blockQuote") }
        XCTAssertTrue(p0.runs.first?.attributes.bold == true)
        XCTAssertFalse(bq.collapsed, "expanded quote maps to collapsed:false")
    }

    // MARK: - Task 6: round-trip identity

    private func file(_ id: Int64) -> TelegramMediaFile {
        TelegramMediaFile(
            fileId: MediaId(namespace: 0, id: id),
            partialReference: nil,
            resource: LocalFileMediaResource(fileId: id),
            previewRepresentations: [],
            videoThumbnails: [],
            immediateThumbnailData: nil,
            mimeType: "image/webp",
            size: nil,
            attributes: [],
            alternativeRepresentations: []
        )
    }

    func test_modelRoundTrip_identity_overCoveredFeatures() {
        var bold = ChatInputInlineAttributes(); bold.bold = true
        var emoji = ChatInputInlineAttributes(); emoji.entity = .customEmoji(fileId: 42, file: file(42), enableAnimation: true)
        var mention = ChatInputInlineAttributes(); mention.entity = .mention(EnginePeer.Id(9))
        let content = ChatInputContent(blocks: [
            .paragraph(ChatInputParagraph(style: .body, runs: [
                ChatInputRun(text: "Hi "),
                ChatInputRun(text: "bold", attributes: bold),
                ChatInputRun(text: "\u{FFFC}", attributes: emoji),
                ChatInputRun(text: "@x", attributes: mention),
            ])),
            .blockQuote(ChatInputBlockQuote(
                content: ChatInputContent(blocks: [
                    .paragraph(ChatInputParagraph(style: .body, runs: [ChatInputRun(text: "q")])),
                ]),
                collapsed: false)),
            .code(ChatInputCode(language: "swift", runs: [ChatInputRun(text: "let x = 1\nlet y = 2")])),
        ])
        XCTAssertEqual(chatInputContent(from: attributedString(from: content)), content)
    }

    // MARK: - Piece 4: model affordances must match the attributed string exactly

    /// A rich fixture exercising every block kind + inline attribute, so `plainText`/`length` parity is
    /// meaningfully tested (body run + bold + custom emoji + mention, an expanded blockQuote, a code block with an
    /// interior newline, and a collapsed blockQuote).
    private func richFixture() -> ChatInputContent {
        var bold = ChatInputInlineAttributes(); bold.bold = true
        var emoji = ChatInputInlineAttributes(); emoji.entity = .customEmoji(fileId: 7, file: nil, enableAnimation: true)
        var mention = ChatInputInlineAttributes(); mention.entity = .mention(EnginePeer.Id(3))
        let collapsedNested = ChatInputContent(blocks: [
            .paragraph(ChatInputParagraph(style: .body, runs: [ChatInputRun(text: "folded")]))
        ])
        return ChatInputContent(blocks: [
            .paragraph(ChatInputParagraph(style: .body, runs: [
                ChatInputRun(text: "Hi "),
                ChatInputRun(text: "bold", attributes: bold),
                ChatInputRun(text: "\u{FFFC}", attributes: emoji),
                ChatInputRun(text: "@x", attributes: mention),
            ])),
            .blockQuote(ChatInputBlockQuote(
                content: ChatInputContent(blocks: [
                    .paragraph(ChatInputParagraph(style: .body, runs: [ChatInputRun(text: "q1")])),
                    .paragraph(ChatInputParagraph(style: .body, runs: [ChatInputRun(text: "q2")])),
                ]),
                collapsed: false)),
            .code(ChatInputCode(language: "swift", runs: [ChatInputRun(text: "let a = 1\nlet b = 2")])),
            .blockQuote(ChatInputBlockQuote(content: collapsedNested, collapsed: true)),
        ])
    }

    func test_plainText_matchesAttributedStringString() {
        let content = richFixture()
        XCTAssertEqual(content.plainText, attributedString(from: content).string)
    }

    func test_length_matchesAttributedStringLength() {
        let content = richFixture()
        XCTAssertEqual(content.length, attributedString(from: content).length)
    }

    func test_plainText_emptyAndSingleBlock() {
        XCTAssertEqual(ChatInputContent().plainText, "")
        XCTAssertEqual(ChatInputContent().length, 0)
        let single = ChatInputContent(blocks: [.paragraph(ChatInputParagraph(style: .body, runs: [ChatInputRun(text: "abc")]))])
        XCTAssertEqual(single.plainText, "abc")
        XCTAssertEqual(single.plainText, attributedString(from: single).string)
        XCTAssertEqual(single.length, 3)
    }

    // MARK: - Piece 3: value-equality unlock (emoji object identity must NOT defeat equality)

    /// The mechanism `ChatTextInputState.==` relies on in Piece 3: two composer strings that carry the SAME
    /// custom emoji (same `fileId` + `enableAnimation`) but as DISTINCT attribute objects — and even differing
    /// `interactivelySelectedFromPackId` / `file` resolution — must convert to EQUAL `ChatInputContent` models.
    /// `ChatTextInputTextCustomEmojiAttribute.isEqual` is reference-based, so `NSAttributedString.isEqual(to:)`
    /// would call these strings unequal; the value model is what makes the model-routed GET read-back compare
    /// equal instead of churning change-detection.
    func test_modelEquality_sameEmojiDistinctObjects_areEqual() {
        let lhs = NSMutableAttributedString(string: "\u{FFFC}")
        lhs.addAttribute(ChatTextInputAttributes.customEmoji,
            value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: EngineItemCollectionId(namespace: 0, id: 111), fileId: 42, file: nil, enableAnimation: true),
            range: NSRange(location: 0, length: 1))
        let rhs = NSMutableAttributedString(string: "\u{FFFC}")
        rhs.addAttribute(ChatTextInputAttributes.customEmoji,
            value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 42, file: file(42), enableAnimation: true),
            range: NSRange(location: 0, length: 1))

        XCTAssertFalse(lhs.isEqual(to: rhs), "precondition: reference-based isEqual treats distinct emoji objects as unequal")
        XCTAssertEqual(chatInputContent(from: lhs), chatInputContent(from: rhs), "value model must ignore object identity / packId / file resolution")
    }

    /// Guard the other direction: a genuinely different emoji (different `fileId`) must convert to a DIFFERENT
    /// model — coarser-or-equal equality must not collapse distinct content.
    func test_modelEquality_differentFileId_areNotEqual() {
        let lhs = NSMutableAttributedString(string: "\u{FFFC}")
        lhs.addAttribute(ChatTextInputAttributes.customEmoji,
            value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 42, file: nil, enableAnimation: true),
            range: NSRange(location: 0, length: 1))
        let rhs = NSMutableAttributedString(string: "\u{FFFC}")
        rhs.addAttribute(ChatTextInputAttributes.customEmoji,
            value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 99, file: nil, enableAnimation: true),
            range: NSRange(location: 0, length: 1))

        XCTAssertNotEqual(chatInputContent(from: lhs), chatInputContent(from: rhs))
    }

    func test_modelRoundTrip_customEmoji_withNilFile_preservesFileId() {
        var e = ChatInputInlineAttributes(); e.entity = .customEmoji(fileId: 77, file: nil, enableAnimation: true)
        let content = ChatInputContent(blocks: [.paragraph(ChatInputParagraph(style: .body, runs: [ChatInputRun(text: "\u{FFFC}", attributes: e)]))])
        XCTAssertEqual(chatInputContent(from: attributedString(from: content)), content)
    }

    // MARK: - Task 0 (1b-ii): customEmoji enableAnimation fidelity

    func test_modelRoundTrip_customEmoji_preservesEnableAnimationFalse() {
        // enableAnimation defaults to true in the chat attribute; dropping it would silently
        // re-animate a non-animated emoji. The model must carry it (matching ChatTextInputStateText).
        var e = ChatInputInlineAttributes(); e.entity = .customEmoji(fileId: 5, file: nil, enableAnimation: false)
        let content = ChatInputContent(blocks: [.paragraph(ChatInputParagraph(style: .body, runs: [ChatInputRun(text: "\u{FFFC}", attributes: e)]))])
        XCTAssertEqual(chatInputContent(from: attributedString(from: content)), content)
    }

    // MARK: - Task 0 (1b-ii): collapsed-quote fidelity

    func test_modelRoundTrip_collapsedBlockQuote_preservesNestedContent() {
        var bold = ChatInputInlineAttributes(); bold.bold = true
        let nested = ChatInputContent(blocks: [
            .paragraph(ChatInputParagraph(style: .body, runs: [
                ChatInputRun(text: "secret "),
                ChatInputRun(text: "stuff", attributes: bold),
            ]))
        ])
        let content = ChatInputContent(blocks: [
            .paragraph(ChatInputParagraph(style: .body, runs: [ChatInputRun(text: "before")])),
            .blockQuote(ChatInputBlockQuote(content: nested, collapsed: true)),
            .paragraph(ChatInputParagraph(style: .body, runs: [ChatInputRun(text: "after")])),
        ])
        XCTAssertEqual(chatInputContent(from: attributedString(from: content)), content)
    }

    func test_modelRoundTrip_collapsedBlockQuote_atStart() {
        let nested = ChatInputContent(blocks: [.paragraph(ChatInputParagraph(style: .body, runs: [ChatInputRun(text: "q")]))])
        let content = ChatInputContent(blocks: [
            .blockQuote(ChatInputBlockQuote(content: nested, collapsed: true)),
            .paragraph(ChatInputParagraph(style: .body, runs: [ChatInputRun(text: "after")])),
        ])
        XCTAssertEqual(chatInputContent(from: attributedString(from: content)), content)
    }

    /// The chat-currency direction: a hand-built FOLDED `.collapsedBlock` string (exactly what
    /// `textAttributedStringForStateText` consumes) must survive model round-trip with its nested
    /// content + placement intact — proving the legacy composer's display path stays byte-identical.
    func test_chatCurrencyRoundTrip_collapsedBlock_preserved() {
        let nested = NSMutableAttributedString(string: "hi")
        nested.addAttribute(ChatTextInputAttributes.bold, value: true as NSNumber, range: NSRange(location: 0, length: 2))
        let s = NSMutableAttributedString(string: "before\n \nafter")
        s.addAttribute(ChatTextInputAttributes.collapsedBlock, value: nested, range: NSRange(location: 7, length: 1))

        let back = attributedString(from: chatInputContent(from: s))
        XCTAssertEqual(back.string, "before\n \nafter")
        var found = false
        back.enumerateAttribute(ChatTextInputAttributes.collapsedBlock, in: NSRange(location: 0, length: back.length), options: []) { value, range, _ in
            if let v = value as? NSAttributedString {
                found = true
                XCTAssertEqual(range, NSRange(location: 7, length: 1))
                XCTAssertEqual(v.string, "hi")
                XCTAssertNotNil(v.attribute(ChatTextInputAttributes.bold, at: 0, effectiveRange: nil))
            }
        }
        XCTAssertTrue(found, "collapsedBlock attribute must survive the round-trip")
    }

    // Legacy composer render-only filter: the flat `NSAttributedString` projection drops `.media`/`.table` blocks and
    // renders heading/list paragraphs as plain text (the legacy UITextView can't carry structural content).
    func test_attributedString_filtersStructuralBlocksForLegacyComposer() {
        let image = TelegramMediaImage(imageId: MediaId(namespace: 1, id: 1001), representations: [], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
        let media = ChatInputMedia(media: image, kind: .image, naturalSize: ChatInputSize(width: 0, height: 0), displayWidth: nil, alignment: .center, caption: [ChatInputRun(text: "CAPTION")])
        let table = ChatInputTable(columns: [ChatInputColumnSpec(width: 0)], rows: [ChatInputTableRow(height: nil, isHeader: false, cells: [ChatInputTableCell(runs: [ChatInputRun(text: "CELL")], background: nil)])])
        let content = ChatInputContent(blocks: [
            .paragraph(ChatInputParagraph(style: .heading1, runs: [ChatInputRun(text: "Title")])),
            .paragraph(ChatInputParagraph(style: .body, list: ChatInputListMembership(marker: .bullet, level: 0), runs: [ChatInputRun(text: "item")])),
            .table(table),
            .media(media),
            .paragraph(ChatInputParagraph(style: .body, runs: [ChatInputRun(text: "after")]))
        ])
        let attr = attributedString(from: content)
        // Heading/list render as plain text; media/table (and their cell/caption text) are dropped — no crash.
        XCTAssertEqual(attr.string, "Title\nitem\nafter")
        XCTAssertFalse(attr.string.contains("CELL"), "table cell text must be dropped")
        XCTAssertFalse(attr.string.contains("CAPTION"), "media caption must be dropped")
    }
}
