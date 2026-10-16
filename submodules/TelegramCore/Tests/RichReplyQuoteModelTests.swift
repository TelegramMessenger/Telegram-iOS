import XCTest
import Postbox
@testable import TelegramCore

/// A reply quote of a rich message keeps its fragments (what is sent as `quote_rich`) next to the
/// flat text and entities every display and search path reads.
final class RichReplyQuoteModelTests: XCTestCase {
    private let replyMessageId = MessageId(peerId: PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(1)), namespace: Namespaces.Message.Cloud, id: 10)

    private func roundTrip(_ attribute: ReplyMessageAttribute) -> ReplyMessageAttribute {
        let encoder = PostboxEncoder()
        attribute.encode(encoder)
        return ReplyMessageAttribute(decoder: PostboxDecoder(buffer: MemoryBuffer(data: encoder.makeData())))
    }

    func testFlatTextAndEntities() {
        let flat = richReplyQuoteTextAndEntities([
            .concat([.bold(.plain("a")), .textCustomEmoji(fileId: 5, alt: "😀"), .italic(.plain("b"))]),
            .textSpoiler(text: .plain("c"))
        ])
        XCTAssertEqual(flat.text, "a😀b\nc")
        XCTAssertEqual(flat.entities, [
            MessageTextEntity(range: 0 ..< 1, type: .Bold),
            MessageTextEntity(range: 1 ..< 3, type: .CustomEmoji(stickerPack: nil, fileId: 5)),
            MessageTextEntity(range: 3 ..< 4, type: .Italic),
            MessageTextEntity(range: 5 ..< 6, type: .Spoiler)
        ])
    }

    func testFlatTextOfAtoms() {
        let button = InstantPageButton(text: .bold(.plain("Go")), action: .url(""), color: nil)
        let image: RichText = .image(id: MediaId(namespace: 0, id: 1), dimensions: PixelDimensions(width: 1, height: 1))
        let flat = richReplyQuoteTextAndEntities([.concat([.formula(latex: "x^2"), .textButton(button), image, .textDate(text: .plain("today"), date: 1, format: nil)])])
        XCTAssertEqual(flat.text, "x^2Gotoday")
        XCTAssertEqual(flat.entities, [])
    }

    func testRichInitDerivesFlatForm() {
        let quote = EngineMessageReplyQuote(richText: [.bold(.plain("hi")), .plain("there")], offset: 3, media: nil)
        XCTAssertEqual(quote.text, "hi\nthere")
        XCTAssertEqual(quote.entities, [MessageTextEntity(range: 0 ..< 2, type: .Bold)])
        XCTAssertEqual(quote.offset, 3)
        XCTAssertEqual(quote.richText, [.bold(.plain("hi")), .plain("there")])
    }

    func testRichTextTakesPartInEquality() {
        let rich = EngineMessageReplyQuote(richText: [.bold(.plain("hi"))], offset: nil, media: nil)
        let flat = EngineMessageReplyQuote(text: "hi", offset: nil, entities: [MessageTextEntity(range: 0 ..< 2, type: .Bold)], media: nil)
        XCTAssertNotEqual(rich, flat)
    }

    func testReplyAttributeRoundTripKeepsRichText() {
        let quote = EngineMessageReplyQuote(richText: [.concat([.bold(.plain("a")), .formula(latex: "x")]), .plain("b")], offset: 7, media: nil)
        let decoded = self.roundTrip(ReplyMessageAttribute(messageId: self.replyMessageId, threadMessageId: nil, quote: quote, isQuote: true, innerSubject: nil))
        XCTAssertEqual(decoded.quote, quote)
        XCTAssertEqual(decoded.quote?.richText, quote.richText)
        XCTAssertTrue(decoded.isQuote)
    }

    // A cross-chat reply stores the replied message's text as a display-only quote (`isQuote == false`);
    // a resend must not turn it into a quote the user never chose.
    func testResendKeepsOnlyARequestedQuote() {
        let quote = EngineMessageReplyQuote(text: "t", offset: nil, entities: [], media: nil)
        let display = ReplyMessageAttribute(messageId: self.replyMessageId, threadMessageId: nil, quote: quote, isQuote: false, innerSubject: nil)
        XCTAssertNil(resentReplySubject(display).quote)
        let requested = ReplyMessageAttribute(messageId: self.replyMessageId, threadMessageId: nil, quote: quote, isQuote: true, innerSubject: nil)
        XCTAssertEqual(resentReplySubject(requested).quote, quote)
        XCTAssertEqual(resentReplySubject(requested).messageId, self.replyMessageId)
    }

    func testFlatQuoteRoundTripHasNoRichText() {
        let quote = EngineMessageReplyQuote(text: "hi", offset: nil, entities: [], media: nil)
        let decoded = self.roundTrip(ReplyMessageAttribute(messageId: self.replyMessageId, threadMessageId: nil, quote: quote, isQuote: true, innerSubject: nil))
        XCTAssertEqual(decoded.quote, quote)
        XCTAssertNil(decoded.quote?.richText)
    }
}
