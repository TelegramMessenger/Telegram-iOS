import XCTest
import Postbox
@testable import TelegramCore
@testable import TextFormat

/// The composer resolves custom-emoji `TelegramMediaFile`s asynchronously and writes them back into
/// the interface state. That write-back used to go through `ChatTextInputState(inputText:selectionRange:)`,
/// which re-derives the content from a FLATTENED `NSAttributedString` — so the moment a sticker
/// resolved, every heading / list / quote / table in the composer was retyped as a body paragraph.
/// Symptom: paste a rich message with custom emoji, see its headings, watch them vanish a beat later.
///
/// These pin the two properties the model-side resolver has to have: it fills the file in, and it
/// changes NOTHING else.
final class ChatInputContentCustomEmojiTests: XCTestCase {
    private let fileId: Int64 = 12345

    private func file(_ id: Int64) -> TelegramMediaFile {
        return TelegramMediaFile(
            fileId: MediaId(namespace: Namespaces.Media.CloudFile, id: id),
            partialReference: nil,
            resource: EmptyMediaResource(),
            previewRepresentations: [],
            videoThumbnails: [],
            immediateThumbnailData: nil,
            mimeType: "image/webp",
            size: nil,
            attributes: [],
            alternativeRepresentations: []
        )
    }

    private func emojiRun(_ id: Int64, file: TelegramMediaFile? = nil) -> ChatInputRun {
        var attributes = ChatInputInlineAttributes()
        attributes.entity = .customEmoji(fileId: id, file: file, enableAnimation: true)
        return ChatInputRun(text: "\u{FFFC}", attributes: attributes)
    }

    private func plainRun(_ text: String) -> ChatInputRun {
        return ChatInputRun(text: text, attributes: ChatInputInlineAttributes())
    }

    /// The shape a pasted rich message has: a heading, a quote, and a body paragraph with an emoji.
    private func richContent() -> ChatInputContent {
        return ChatInputContent(blocks: [
            .paragraph(ChatInputParagraph(style: .heading1, runs: [self.plainRun("Title")])),
            .blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: [
                .paragraph(ChatInputParagraph(style: .body, runs: [self.plainRun("quoted "), self.emojiRun(self.fileId)]))
            ]), collapsed: false, author: [])),
            .paragraph(ChatInputParagraph(style: .body, list: ChatInputListMembership(marker: .bullet, level: 0, checked: nil),
                                          runs: [self.plainRun("item "), self.emojiRun(self.fileId)]))
        ])
    }

    private func styles(_ content: ChatInputContent) -> [ChatInputParagraphStyle?] {
        return content.blocks.map { block in
            if case let .paragraph(p) = block { return p.style } else { return nil }
        }
    }

    // MARK: Detection

    /// The flat `inputText` projection drops whole blocks, so the old scan could not even SEE an emoji
    /// inside a quote or a table cell. The model walk must.
    func test_unresolvedIds_areFoundInsideNestedBlocks() {
        let content = ChatInputContent(blocks: [
            .blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: [
                .paragraph(ChatInputParagraph(style: .body, runs: [self.emojiRun(1)]))
            ]), collapsed: true, author: [])),
            .table(ChatInputTable(columns: [ChatInputColumnSpec(width: 90)], rows: [
                ChatInputTableRow(cells: [ChatInputTableCell(runs: [self.emojiRun(2)])])
            ])),
            .media(ChatInputMedia(items: [], caption: [self.emojiRun(3)])),
            .details(ChatInputDetails(content: ChatInputContent(blocks: [
                .paragraph(ChatInputParagraph(style: .body, runs: [self.emojiRun(4)]))
            ]), title: [self.emojiRun(5)], expanded: true))
        ])
        XCTAssertEqual(content.unresolvedCustomEmojiFileIds(), Set([1, 2, 3, 4, 5]))
    }

    /// An already-resolved run is not "unresolved" and must not be re-fetched every state update.
    func test_unresolvedIds_excludeAlreadyResolvedRuns() {
        let content = ChatInputContent(blocks: [
            .paragraph(ChatInputParagraph(style: .body, runs: [
                self.emojiRun(1, file: self.file(1)),
                self.emojiRun(2)
            ]))
        ])
        XCTAssertEqual(content.unresolvedCustomEmojiFileIds(), Set([2]))
    }

    // MARK: Resolution

    /// THE regression: resolving a sticker must fill in the file and leave the block structure alone.
    func test_resolving_fillsTheFileAndPreservesBlockStructure() throws {
        let content = self.richContent()
        XCTAssertEqual(self.styles(content), [.heading1, nil, .body], "precondition: a heading and a quote")

        let resolved = content.resolvingCustomEmojiFiles([self.fileId: self.file(self.fileId)])

        XCTAssertEqual(self.styles(resolved), [.heading1, nil, .body], "the heading must survive the resolution")
        guard case .blockQuote = resolved.blocks[1] else {
            return XCTFail("the quote must survive the resolution")
        }
        guard case let .paragraph(list) = resolved.blocks[2] else { return XCTFail() }
        XCTAssertEqual(list.list?.marker, .bullet, "the list membership must survive too")

        XCTAssertEqual(resolved.unresolvedCustomEmojiFileIds(), [], "every emoji got its file")
    }

    /// Nested emoji resolve, not just top-level ones.
    func test_resolving_reachesNestedRuns() throws {
        let resolved = self.richContent().resolvingCustomEmojiFiles([self.fileId: self.file(self.fileId)])
        guard case let .blockQuote(quote) = resolved.blocks[1],
              case let .paragraph(inner) = quote.content.blocks[0],
              case let .customEmoji(_, file, _) = inner.runs[1].attributes.entity else {
            return XCTFail("the quoted emoji run is still there")
        }
        XCTAssertNotNil(file, "the emoji inside the quote resolved")
    }

    /// Attribute-only: the flat text is byte-identical, which is what makes it safe for the caller to
    /// keep its existing selection across the async resolution.
    func test_resolving_doesNotChangeTheText() {
        let content = self.richContent()
        let resolved = content.resolvingCustomEmojiFiles([self.fileId: self.file(self.fileId)])
        XCTAssertEqual(resolved.length, content.length, "the flat length is what a ChatInputSelection is taken against")
        XCTAssertEqual(resolved.blocks.count, content.blocks.count)
    }

    /// A stale entry must never downgrade an already-resolved run, and an unrelated id must be a no-op.
    func test_resolving_leavesResolvedAndUnrelatedRunsAlone() throws {
        let content = ChatInputContent(blocks: [
            .paragraph(ChatInputParagraph(style: .body, runs: [self.emojiRun(1, file: self.file(1))]))
        ])
        let resolved = content.resolvingCustomEmojiFiles([2: self.file(2)])
        XCTAssertEqual(resolved, content, "resolving an id that is not present changes nothing")
    }

    func test_resolving_withNoFiles_isANoOp() {
        let content = self.richContent()
        XCTAssertEqual(content.resolvingCustomEmojiFiles([:]), content)
    }

    /// The reason the resolver has to exist at all, stated as a test: the `NSAttributedString` round-trip
    /// the old write-back went through is LOSSY for exactly this content. If someone ever "simplifies"
    /// `serviceTasksForChatPresentationIntefaceState` back to `ChatTextInputState(inputText:…)`, this is
    /// the assertion that explains why the headings disappear.
    func test_theFlatRoundTrip_isLossy_whichIsWhyTheModelPathExists() {
        let content = self.richContent()
        let flattened = chatInputContent(from: attributedString(from: content))

        XCTAssertEqual(self.styles(content).first, .heading1)
        XCTAssertNotEqual(self.styles(flattened).first, .heading1,
                          "the flat round-trip drops the heading — resolving emoji through it is what broke paste")
    }
}
