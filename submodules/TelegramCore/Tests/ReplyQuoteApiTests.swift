import XCTest
import Postbox
import TelegramApi
@testable import TelegramCore

/// A rich quote travels as `quote_rich` alone (the server rejects it next to `quote_text` or
/// `quote_entities`); a received `quote_rich` becomes a rich quote with its flat form derived.
final class ReplyQuoteApiTests: XCTestCase {
    func testRichQuoteTravelsAsQuoteRichAlone() {
        let quote = EngineMessageReplyQuote(richText: [.bold(.plain("hi"))], offset: 4, media: nil)
        let fields = apiReplyQuoteFields(quote, peer: { _ in nil })
        XCTAssertEqual(fields.flags, (1 << 8) | (1 << 4))
        XCTAssertNil(fields.text)
        XCTAssertNil(fields.entities)
        XCTAssertEqual(fields.offset, 4)
        XCTAssertEqual(fields.rich.map { $0.map(RichText.init(apiText:)) }, [.bold(.plain("hi"))])
    }

    func testFlatQuoteIsUnchanged() {
        let fields = apiReplyQuoteFields(EngineMessageReplyQuote(text: "hi", offset: nil, entities: [], media: nil), peer: { _ in nil })
        XCTAssertEqual(fields.flags, 1 << 2)
        XCTAssertEqual(fields.text, "hi")
        XCTAssertNil(fields.entities)
        XCTAssertNil(fields.rich)
        XCTAssertNil(fields.offset)
        XCTAssertEqual(apiReplyQuoteFields(nil, peer: { _ in nil }).flags, 0)
    }

    func testFlatQuoteEntitiesSetTheirFlag() {
        let quote = EngineMessageReplyQuote(text: "hi", offset: 2, entities: [MessageTextEntity(range: 0 ..< 2, type: .Bold)], media: nil)
        let fields = apiReplyQuoteFields(quote, peer: { _ in nil })
        XCTAssertEqual(fields.flags, (1 << 2) | (1 << 3) | (1 << 4))
        XCTAssertEqual(fields.entities?.count, 1)
        XCTAssertNil(fields.rich)
    }

    func testReceivedRichQuote() {
        let quote = engineReplyQuote(text: nil, entities: nil, offset: 2, rich: [RichText.bold(.plain("x")).apiRichText(), RichText.plain("y").apiRichText()], media: nil)
        XCTAssertEqual(quote?.richText, [.bold(.plain("x")), .plain("y")])
        XCTAssertEqual(quote?.text, "x\ny")
        XCTAssertEqual(quote?.offset, 2)
    }

    func testReceivedFlatQuoteIsUnchanged() {
        XCTAssertEqual(engineReplyQuote(text: "t", entities: [], offset: nil, rich: nil, media: nil), EngineMessageReplyQuote(text: "t", offset: nil, entities: [], media: nil))
        XCTAssertNil(engineReplyQuote(text: nil, entities: nil, offset: nil, rich: nil, media: nil))
        XCTAssertNil(engineReplyQuote(text: nil, entities: nil, offset: nil, rich: [], media: nil))
    }
}
