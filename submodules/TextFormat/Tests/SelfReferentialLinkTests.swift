import XCTest
import Postbox
import TelegramCore
import TextFormat

final class SelfReferentialLinkTests: XCTestCase {
    // MARK: - The predicate

    func test_exactMatch_isSelfReferential() {
        XCTAssertTrue(chatInputLinkIsSelfReferential(text: "https://example.com/foo", url: "https://example.com/foo"))
    }

    func test_differentTarget_isNotSelfReferential() {
        XCTAssertFalse(chatInputLinkIsSelfReferential(text: "https://a.com", url: "https://b.com"))
    }

    func test_labelledLink_isNotSelfReferential() {
        XCTAssertFalse(chatInputLinkIsSelfReferential(text: "click here", url: "https://example.com"))
    }

    /// The markdown parser adds the scheme to a bare `www.` autolink.
    func test_schemeAddedByParser_isSelfReferential() {
        XCTAssertTrue(chatInputLinkIsSelfReferential(text: "www.example.com", url: "http://www.example.com"))
        XCTAssertTrue(chatInputLinkIsSelfReferential(text: "www.example.com", url: "https://www.example.com"))
    }

    /// The markdown parser turns a bare email into a `mailto:` link.
    func test_mailtoPrefix_isSelfReferential() {
        XCTAssertTrue(chatInputLinkIsSelfReferential(text: "user@example.com", url: "mailto:user@example.com"))
    }

    /// A non-ASCII path is percent-encoded in the URL but not in the display text.
    func test_percentEncodedPath_isSelfReferential() {
        XCTAssertTrue(chatInputLinkIsSelfReferential(
            text: "https://ru.wikipedia.org/wiki/Привет",
            url: "https://ru.wikipedia.org/wiki/%D0%9F%D1%80%D0%B8%D0%B2%D0%B5%D1%82"
        ))
    }

    func test_trailingSlashAddedByParser_isSelfReferential() {
        XCTAssertTrue(chatInputLinkIsSelfReferential(text: "https://example.com", url: "https://example.com/"))
    }

    /// A different scheme is a different destination, even when the rest matches.
    func test_schemeMismatchOnAnExplicitlySchemedText_isNotSelfReferential() {
        XCTAssertFalse(chatInputLinkIsSelfReferential(text: "http://example.com", url: "https://example.com"))
    }

    func test_emptyOrWhitespaceText_isNotSelfReferential() {
        XCTAssertFalse(chatInputLinkIsSelfReferential(text: "", url: "https://example.com"))
        XCTAssertFalse(chatInputLinkIsSelfReferential(text: "   ", url: "https://example.com"))
    }

    /// A Telegram deep-link marker (mention / date) is never a plain URL a user typed.
    func test_telegramMarkers_areNotSelfReferential() {
        XCTAssertFalse(chatInputLinkIsSelfReferential(text: "Alice", url: "tg://user?id=1"))
    }

    // MARK: - Stripping over a ChatInputContent

    private func urlAttributes(_ url: String) -> ChatInputInlineAttributes {
        var attributes = ChatInputInlineAttributes()
        attributes.entity = .url(url)
        return attributes
    }

    private func paragraph(_ runs: [ChatInputRun], style: ChatInputParagraphStyle = .body) -> ChatInputBlock {
        return .paragraph(ChatInputParagraph(style: style, list: nil, runs: runs))
    }

    func test_strip_removesASelfReferentialURLEntity() {
        let content = ChatInputContent(blocks: [paragraph([
            ChatInputRun(text: "https://example.com", attributes: urlAttributes("https://example.com"))
        ])])
        let stripped = chatInputContentStrippingSelfReferentialLinks(content)
        guard case let .paragraph(result) = stripped.blocks[0] else { return XCTFail("expected a paragraph") }
        XCTAssertEqual(result.runs.count, 1)
        XCTAssertEqual(result.runs[0].text, "https://example.com")
        XCTAssertEqual(result.runs[0].attributes, ChatInputInlineAttributes())
    }

    func test_strip_keepsAGenuineTextLink() {
        let content = ChatInputContent(blocks: [paragraph([
            ChatInputRun(text: "click here", attributes: urlAttributes("https://example.com"))
        ])])
        let stripped = chatInputContentStrippingSelfReferentialLinks(content)
        XCTAssertEqual(stripped, content)
    }

    func test_strip_preservesOtherInlineAttributesOnTheStrippedRun() {
        var attributes = urlAttributes("https://example.com")
        attributes.bold = true
        let content = ChatInputContent(blocks: [paragraph([
            ChatInputRun(text: "https://example.com", attributes: attributes)
        ])])
        let stripped = chatInputContentStrippingSelfReferentialLinks(content)
        guard case let .paragraph(result) = stripped.blocks[0] else { return XCTFail("expected a paragraph") }
        XCTAssertNil(result.runs[0].attributes.entity)
        XCTAssertTrue(result.runs[0].attributes.bold)
    }

    /// The link text can be split over several runs (e.g. a formatted span inside the label); the whole
    /// span, not each run, is what must equal the URL.
    func test_strip_joinsAdjacentRunsSharingTheSameURL() {
        let attributes = urlAttributes("https://example.com/foo")
        let content = ChatInputContent(blocks: [paragraph([
            ChatInputRun(text: "https://example.com", attributes: attributes),
            ChatInputRun(text: "/foo", attributes: attributes)
        ])])
        let stripped = chatInputContentStrippingSelfReferentialLinks(content)
        guard case let .paragraph(result) = stripped.blocks[0] else { return XCTFail("expected a paragraph") }
        XCTAssertNil(result.runs[0].attributes.entity)
        XCTAssertNil(result.runs[1].attributes.entity)
    }

    func test_strip_doesNotJoinRunsOfTwoDifferentLinks() {
        let content = ChatInputContent(blocks: [paragraph([
            ChatInputRun(text: "https://a.com", attributes: urlAttributes("https://a.com")),
            ChatInputRun(text: " and ", attributes: ChatInputInlineAttributes()),
            ChatInputRun(text: "label", attributes: urlAttributes("https://b.com"))
        ])])
        let stripped = chatInputContentStrippingSelfReferentialLinks(content)
        guard case let .paragraph(result) = stripped.blocks[0] else { return XCTFail("expected a paragraph") }
        XCTAssertNil(result.runs[0].attributes.entity)
        XCTAssertEqual(result.runs[2].attributes.entity, .url("https://b.com"))
    }

    func test_strip_leavesMentionAndDateEntitiesAlone() {
        var mention = ChatInputInlineAttributes()
        mention.entity = .mention(EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(1)))
        let content = ChatInputContent(blocks: [paragraph([ChatInputRun(text: "Alice", attributes: mention)])])
        XCTAssertEqual(chatInputContentStrippingSelfReferentialLinks(content), content)
    }

    func test_strip_recursesIntoNestedContainers() {
        let selfLink = ChatInputRun(text: "https://example.com", attributes: urlAttributes("https://example.com"))
        let content = ChatInputContent(blocks: [
            .code(ChatInputCode(language: nil, runs: [selfLink])),
            .pullQuote(ChatInputPullQuote(runs: [selfLink], author: [selfLink])),
            .blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: [paragraph([selfLink])]), collapsed: false)),
            .table(ChatInputTable(columns: [], rows: [ChatInputTableRow(cells: [ChatInputTableCell(runs: [selfLink])])])),
            .media(ChatInputMedia(items: [], caption: [selfLink]))
        ])
        let stripped = chatInputContentStrippingSelfReferentialLinks(content)

        guard case let .code(code) = stripped.blocks[0] else { return XCTFail("expected code") }
        XCTAssertNil(code.runs[0].attributes.entity)
        guard case let .pullQuote(pullQuote) = stripped.blocks[1] else { return XCTFail("expected a pull quote") }
        XCTAssertNil(pullQuote.runs[0].attributes.entity)
        XCTAssertNil(pullQuote.author[0].attributes.entity)
        guard case let .blockQuote(blockQuote) = stripped.blocks[2] else { return XCTFail("expected a block quote") }
        guard case let .paragraph(inner) = blockQuote.content.blocks[0] else { return XCTFail("expected a paragraph") }
        XCTAssertNil(inner.runs[0].attributes.entity)
        guard case let .table(table) = stripped.blocks[3] else { return XCTFail("expected a table") }
        XCTAssertNil(table.rows[0].cells[0].runs[0].attributes.entity)
        guard case let .media(media) = stripped.blocks[4] else { return XCTFail("expected media") }
        XCTAssertNil(media.caption[0].attributes.entity)
    }

    // MARK: - The paste gate

    /// The bug: a pasted bare URL parses as a markdown autolink, and the link entity alone made the paste
    /// look "richer than plain" — so it was routed to the rich paste path and landed as a text link.
    func test_gate_bareURLParagraph_isNotRicherThanPlain_afterStripping() {
        let content = ChatInputContent(blocks: [paragraph([
            ChatInputRun(text: "https://example.com/foo", attributes: urlAttributes("https://example.com/foo"))
        ])])
        XCTAssertTrue(pastedMarkdownContentIsRicherThanPlain(content), "precondition: the link entity is what makes it rich")
        XCTAssertFalse(pastedMarkdownContentIsRicherThanPlain(chatInputContentStrippingSelfReferentialLinks(content)))
    }

    func test_gate_genuineTextLink_staysRicherThanPlain() {
        let content = ChatInputContent(blocks: [paragraph([
            ChatInputRun(text: "click here", attributes: urlAttributes("https://example.com"))
        ])])
        XCTAssertTrue(pastedMarkdownContentIsRicherThanPlain(chatInputContentStrippingSelfReferentialLinks(content)))
    }
}
