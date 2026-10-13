import XCTest
import TelegramApi
@testable import TelegramCore

/// What survives a send: `blockQuote.collapsed` across `apiInputBlock()` → the wire → `init(apiBlock:)`.
///
/// This matters because a rich message's own page does NOT survive the send — the pending message
/// renders the client's `InstantPage`, and the confirmed one is rebuilt from what the server echoes
/// back (`RichTextMessageAttribute(apiRichMessage:)` in `StoreMessage_Telegram`). Anything the wire
/// drops therefore reappears as "it looked right until I sent it".
final class InstantPageBlockQuoteCollapsedWireTests: XCTestCase {
    /// `block` encoded to its API constructor, serialised, parsed back and decoded — the exact path a
    /// quote takes between the composer and the confirmed message.
    private func wireRoundTrip(_ block: InstantPageBlock) -> InstantPageBlock? {
        guard let apiBlock = block.apiInputBlock() else {
            return nil
        }
        let buffer = Buffer()
        // Unboxed: `Api.parse(_:signature:)` is internal to TelegramApi, so the per-constructor
        // parsers are called directly and must not be handed a leading constructor id.
        apiBlock.serialize(buffer, false)
        let reader = BufferReader(buffer)
        let parsed: Api.PageBlock?
        switch apiBlock {
        case .pageBlockBlockquote:
            parsed = Api.PageBlock.parse_pageBlockBlockquote(reader)
        case .pageBlockBlockquoteBlocks:
            parsed = Api.PageBlock.parse_pageBlockBlockquoteBlocks(reader)
        default:
            parsed = nil
        }
        return parsed.map { InstantPageBlock(apiBlock: $0) }
    }

    private func collapsedState(_ block: InstantPageBlock?) -> Bool? {
        guard case let .blockQuote(_, _, collapsed) = block else {
            return nil
        }
        return collapsed
    }

    private func quote(paragraphs: [String], collapsed: Bool) -> InstantPageBlock {
        return .blockQuote(
            blocks: paragraphs.map { .paragraph(.plain($0)) },
            caption: .empty,
            collapsed: collapsed)
    }

    // MARK: The one shape that survives

    /// A quote of exactly ONE paragraph encodes as `pageBlockBlockquote`, which carries `flags.0`.
    func test_singleParagraphQuoteKeepsCollapsedAcrossTheWire() {
        let sent = self.quote(paragraphs: ["a long enough quote to be worth collapsing"], collapsed: true)
        XCTAssertEqual(self.collapsedState(self.wireRoundTrip(sent)), true)
    }

    func test_singleParagraphQuoteKeepsNotCollapsedAcrossTheWire() {
        let sent = self.quote(paragraphs: ["one line"], collapsed: false)
        XCTAssertEqual(self.collapsedState(self.wireRoundTrip(sent)), false)
    }

    // MARK: The gap

    /// **Everything else loses the flag.** `apiInputBlock` can only reach for
    /// `pageBlockBlockquoteBlocks` once a quote holds more than a lone paragraph, and that
    /// constructor has no `flags` field at all — so a collapsed quote the reader can actually
    /// collapse (four lines and up is usually four Returns, not one wrapped sentence) arrives
    /// expanded and un-collapsible.
    ///
    /// Pinned as a test rather than left as a comment because the symptom — "it was collapsed in the
    /// composer and is not collapsed in the chat" — reads as a rendering bug and sends you looking in
    /// the wrong module. Closing it needs `pageBlockBlockquoteBlocks flags:# collapsed:flags.0?true`,
    /// which is a coordinated schema change; when that lands, this assertion is the one that fails.
    func test_multiParagraphQuoteLosesCollapsedAcrossTheWire() {
        let sent = self.quote(paragraphs: ["first line", "second line", "third line", "fourth line"], collapsed: true)
        XCTAssertEqual(self.collapsedState(self.wireRoundTrip(sent)), false, "known gap: pageBlockBlockquoteBlocks has no flags")
    }

    /// Not about paragraph COUNT — about the shape. A quote holding one heading takes the same
    /// flagless constructor as a four-paragraph one.
    func test_singleNonParagraphQuoteAlsoLosesCollapsed() {
        let sent = InstantPageBlock.blockQuote(
            blocks: [.heading(text: .plain("a heading"), level: 2)],
            caption: .empty,
            collapsed: true)
        XCTAssertEqual(self.collapsedState(self.wireRoundTrip(sent)), false)
    }

    /// The encoder's fork, asserted directly, so a future edit that changes WHICH constructor is
    /// chosen shows up here rather than only as a lost flag three tests down.
    func test_encoderPicksTheFlaglessConstructorForAnythingButALoneParagraph() {
        guard case .pageBlockBlockquote = self.quote(paragraphs: ["only"], collapsed: true).apiInputBlock() else {
            return XCTFail("a lone paragraph must take the constructor that has flags")
        }
        guard case .pageBlockBlockquoteBlocks = self.quote(paragraphs: ["one", "two"], collapsed: true).apiInputBlock() else {
            return XCTFail("more than one block must take pageBlockBlockquoteBlocks")
        }
    }
}
