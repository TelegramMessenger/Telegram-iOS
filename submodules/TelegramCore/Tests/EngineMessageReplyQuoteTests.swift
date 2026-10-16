import XCTest
import Postbox
import TelegramApi
@testable import TelegramCore

final class EngineMessageReplyQuoteTests: XCTestCase {
    func testRichQuoteCodableRoundTrip() throws {
        let richText: [RichText] = [.bold(.plain("Hello 😀")), .formula(latex: "x^2"), .textCustomEmoji(fileId: 123, alt: "👍")]
        let quote = EngineMessageReplyQuote(text: "", offset: nil, entities: [], media: nil, richText: richText)
        let decoded = try JSONDecoder().decode(EngineMessageReplyQuote.self, from: JSONEncoder().encode(quote))
        XCTAssertEqual(decoded, quote)
        XCTAssertEqual(decoded.richText, richText)
        XCTAssertEqual(decoded.text, "Hello 😀\nx^2\n👍")
    }

    func testLegacyQuoteStillDecodes() throws {
        let data = Data(#"{"t":"legacy","o":7,"e":[]}"#.utf8)
        let quote = try JSONDecoder().decode(EngineMessageReplyQuote.self, from: data)
        XCTAssertEqual(quote.text, "legacy")
        XCTAssertEqual(quote.offset, 7)
        XCTAssertNil(quote.richText)
    }

    func testQuoteEqualityIncludesRichFormatting() {
        let plain = EngineMessageReplyQuote(text: "text", offset: nil, entities: [], media: nil, richText: [.plain("text")])
        let bold = EngineMessageReplyQuote(text: "text", offset: nil, entities: [], media: nil, richText: [.bold(.plain("text"))])
        XCTAssertNotEqual(plain, bold)
    }

    func testReplyAttributePersistencePreservesRichQuote() {
        let quote = EngineMessageReplyQuote(text: "", offset: nil, entities: [], media: nil, richText: [.italic(.plain("quote"))])
        let messageId = MessageId(peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: ._internalFromInt64Value(1)), namespace: Namespaces.Message.Cloud, id: 2)
        let attribute = ReplyMessageAttribute(messageId: messageId, threadMessageId: nil, quote: quote, isQuote: true, innerSubject: nil)
        let encoder = PostboxEncoder()
        attribute.encode(encoder)
        let decoded = ReplyMessageAttribute(decoder: PostboxDecoder(buffer: MemoryBuffer(data: encoder.makeData())))
        XCTAssertEqual(decoded.quote, quote)
        XCTAssertTrue(decoded.isQuote)
    }

    func testRichTextApiRoundTrip() {
        let text: RichText = .concat([.marked(.plain("quote")), .formula(latex: "x^2"), .textCustomEmoji(fileId: 123, alt: "😀")])
        XCTAssertEqual(RichText(apiText: text.apiRichText()), text)
    }

    func testRichOnlyDraftRestoresQuote() throws {
        let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: ._internalFromInt64Value(1))
        let richText: [RichText] = [.bold(.plain("draft quote")), .formula(latex: "x^2")]
        let replyTo = Api.InputReplyTo.inputReplyToMessage(.init(flags: 1 << 8, replyToMsgId: 42, topMsgId: nil, replyToPeerId: nil, quoteText: nil, quoteEntities: nil, quoteOffset: nil, monoforumPeerId: nil, todoItemId: nil, pollOption: nil, quoteRich: richText.map { $0.apiRichText() }))
        let draft = Api.DraftMessage.draftMessage(.init(flags: 1 << 4, replyTo: replyTo, message: "reply", entities: nil, media: nil, date: 1, effect: nil, suggestedPost: nil, richMessage: nil))
        let state = try XCTUnwrap(_internal_synchronizeableChatInputState(accountPeerId: peerId, peerId: peerId, apiDraft: draft))
        let quote = try XCTUnwrap(state.replySubject?.quote)
        XCTAssertEqual(quote.richText, richText)
        XCTAssertEqual(quote.text, "draft quote\nx^2")
        XCTAssertNil(quote.offset)
    }

}
