import XCTest
import Postbox
import MtProtoKit
import TelegramApi
@testable import TelegramCore

/// The widget message media (`messageMediaWidget width:int height:int payload:bytes`, layer 233; widget-sandbox
/// tgw-format.md): the size anchors and the HTML compressed by the server, zlib since v0.1.3 (gzip before), which the
/// client inflates with no size check of its own.
final class TelegramMediaWidgetTests: XCTestCase {
    /// The server's `messageMediaWidget` is stored as the widget media, anchors and gzip payload unchanged.
    func testTheApiWidgetBecomesATelegramMediaWidget() {
        let payload = MTGzip.compress("<p>Hi</p>".data(using: .utf8)!)!
        let api = Api.MessageMedia.messageMediaWidget(.init(flags: 0, width: 300, height: 0, payload: Buffer(data: payload), publicData: nil, publicDataHash: nil, chatData: nil, widgetId: nil))
        let parsed = textMediaAndExpirationTimerFromApiMedia(api, PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(1)))
        guard let widget = parsed.media as? TelegramMediaWidget else {
            return XCTFail("parsed as \(String(describing: parsed.media))")
        }
        XCTAssertEqual(widget.width, 300)
        XCTAssertEqual(widget.height, 0)
        XCTAssertEqual(widget.payload, payload)
        XCTAssertEqual(widget.html(), "<p>Hi</p>")
        XCTAssertNil(parsed.expirationTimer)
    }

    /// widget-sandbox v0.2: the server's flags (`is_copy` bit 0, `can_query` 1, `background_query` 2) and the bot's state
    /// (`public_data` flag 3, `chat_data` 4) with the shared widget's id (flag 5) reach the media as they are.
    func testTheApiWidgetCarriesItsFlagsAndState() {
        let payload = MTGzip.compress("<p>Hi</p>".data(using: .utf8)!)!
        let api = Api.MessageMedia.messageMediaWidget(.init(flags: (1 << 0) | (1 << 1) | (1 << 3) | (1 << 4) | (1 << 5), width: 300, height: 0, payload: Buffer(data: payload), publicData: "p", publicDataHash: 5, chatData: "c", widgetId: 77))
        let parsed = textMediaAndExpirationTimerFromApiMedia(api, PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(1)))
        guard let widget = parsed.media as? TelegramMediaWidget else {
            return XCTFail("parsed as \(String(describing: parsed.media))")
        }
        XCTAssertTrue(widget.isCopy)
        XCTAssertTrue(widget.canQuery)
        XCTAssertFalse(widget.backgroundQuery)
        XCTAssertEqual(widget.chatData, Data("c".utf8))
        XCTAssertEqual(widget.publicData, Data("p".utf8))
        XCTAssertEqual(widget.publicDataHash, 5)
        XCTAssertEqual(widget.widgetId, 77)
        XCTAssertEqual(widget.payload, payload)
    }

    /// The state is the server's bytes: text that is not UTF-8, a NUL and an oversized value are stored as they came, so
    /// the runtime's checks (not a lenient decode here) decide what the widget sees.
    func testTheStateIsStoredAsBytes() {
        let chatData = Data([0xff, 0x00, 0xfe])
        let publicData = Data(repeating: 0x61, count: 1025)
        let widget = TelegramMediaWidget(width: 0, height: 0, payload: Data([1]), isCopy: false, canQuery: true, backgroundQuery: true, chatData: chatData, publicData: publicData, publicDataHash: 6, widgetId: 9)
        let encoder = PostboxEncoder()
        widget.encode(encoder)
        let decoded = TelegramMediaWidget(decoder: PostboxDecoder(buffer: MemoryBuffer(data: encoder.makeData())))
        XCTAssertEqual(decoded.chatData, chatData)
        XCTAssertEqual(decoded.publicData, publicData)
        XCTAssertFalse(decoded.isCopy)
        XCTAssertTrue(decoded.canQuery)
        XCTAssertTrue(decoded.backgroundQuery)
        XCTAssertEqual(decoded.widgetId, 9)
        XCTAssertEqual(decoded.publicDataHash, 6)
        XCTAssertTrue(decoded.isEqual(to: widget))
        XCTAssertFalse(decoded.isEqual(to: TelegramMediaWidget(width: 0, height: 0, payload: Data([1]), isCopy: false, canQuery: true, backgroundQuery: true, chatData: chatData, publicData: publicData, publicDataHash: 7, widgetId: 9)), "the shared state's hash is part of equality")
    }

    /// A message stored before v0.2 has only `w`, `h` and `p`: no flags, no state, no widget id.
    func testAnOldEncodingDecodesWithNoState() {
        let encoder = PostboxEncoder()
        encoder.encodeInt32(300, forKey: "w")
        encoder.encodeInt32(0, forKey: "h")
        encoder.encodeData(Data([1, 2]), forKey: "p")
        let decoded = TelegramMediaWidget(decoder: PostboxDecoder(buffer: MemoryBuffer(data: encoder.makeData())))
        XCTAssertEqual(decoded.width, 300)
        XCTAssertEqual(decoded.payload, Data([1, 2]))
        XCTAssertNil(decoded.publicDataHash)
        XCTAssertFalse(decoded.isCopy)
        XCTAssertFalse(decoded.canQuery)
        XCTAssertFalse(decoded.backgroundQuery)
        XCTAssertNil(decoded.chatData)
        XCTAssertNil(decoded.publicData)
        XCTAssertNil(decoded.widgetId)
    }

    func testWidgetsDifferingInStateAreNotEqual() {
        let a = TelegramMediaWidget(width: 0, height: 0, payload: Data([1]), chatData: Data("a".utf8))
        XCTAssertFalse(a.isEqual(to: TelegramMediaWidget(width: 0, height: 0, payload: Data([1]), chatData: Data("b".utf8))))
        XCTAssertFalse(a.isEqual(to: TelegramMediaWidget(width: 0, height: 0, payload: Data([1]), canQuery: true, chatData: Data("a".utf8))))
        XCTAssertFalse(a.isEqual(to: TelegramMediaWidget(width: 0, height: 0, payload: Data([1]), chatData: Data("a".utf8), widgetId: 1)))
        XCTAssertTrue(a.isEqual(to: TelegramMediaWidget(width: 0, height: 0, payload: Data([1]), chatData: Data("a".utf8))))
    }

    func testCodingRoundTrips() {
        let widget = TelegramMediaWidget(width: 300, height: 0, payload: Data([0x1f, 0x8b, 1, 2, 3]))
        let encoder = PostboxEncoder()
        widget.encode(encoder)
        let decoded = TelegramMediaWidget(decoder: PostboxDecoder(buffer: MemoryBuffer(data: encoder.makeData())))
        XCTAssertEqual(decoded.width, 300)
        XCTAssertEqual(decoded.height, 0)
        XCTAssertEqual(decoded.payload, Data([0x1f, 0x8b, 1, 2, 3]))
        XCTAssertTrue(decoded.isEqual(to: widget))
        XCTAssertNil(decoded.id)
        XCTAssertTrue(decoded.peerIds.isEmpty)
    }

    /// The server's payload since widget-sandbox v0.1.3: PHP's `gzcompress($html, 9)`, a zlib stream (here zlib's own
    /// `compress(html, 9)`, the same bytes).
    static let serverPayload = Data([0x78, 0xda, 0xb3, 0x29, 0xb0, 0xf3, 0xc8, 0xb4, 0xd1, 0x2f, 0xb0, 0x03, 0x00, 0x0d, 0xaf, 0x02, 0xb5])

    func testAServerZlibPayloadInflates() {
        XCTAssertEqual(TelegramMediaWidget(width: 0, height: 0, payload: TelegramMediaWidgetTests.serverPayload).html(), "<p>Hi</p>")
    }

    /// A message stored before the server switched to zlib keeps its gzip payload.
    func testAGzipPayloadStillInflates() {
        let payload = MTGzip.compress("<p>Hi</p>".data(using: .utf8)!)!
        XCTAssertEqual(payload.prefix(2), Data([0x1f, 0x8b]))
        XCTAssertEqual(TelegramMediaWidget(width: 0, height: 0, payload: payload).html(), "<p>Hi</p>")
    }

    func testATruncatedZlibStreamIsNil() {
        let truncated = TelegramMediaWidgetTests.serverPayload.prefix(TelegramMediaWidgetTests.serverPayload.count - 4)
        XCTAssertNil(TelegramMediaWidget(width: 0, height: 0, payload: Data(truncated)).html())
    }

    /// `78 DB` fails zlib's header check (CMF·256 + FLG is not a multiple of 31): no inflate is tried.
    func testABadZlibHeaderIsNil() {
        var payload = TelegramMediaWidgetTests.serverPayload
        payload[payload.startIndex + 1] = 0xdb
        XCTAssertNil(TelegramMediaWidget(width: 0, height: 0, payload: payload).html())
    }

    /// A local widget (debug insertion) is compressed as the server compresses: zlib at level 9.
    func testALocalPayloadIsZlibLevel9() {
        guard let widget = TelegramMediaWidget(html: "<p>Hi</p>", width: 0, height: 0) else {
            return XCTFail("no widget")
        }
        XCTAssertEqual(widget.payload, TelegramMediaWidgetTests.serverPayload)
        XCTAssertEqual(widget.html(), "<p>Hi</p>")
    }

    func testACorruptPayloadHasNoHtml() {
        XCTAssertNil(TelegramMediaWidget(width: 0, height: 0, payload: Data([1, 2, 3])).html())
        let notUTF8 = MTGzip.compress(Data([0xff, 0xfe]))!
        XCTAssertNil(TelegramMediaWidget(width: 0, height: 0, payload: notUTF8).html())
    }

    func testEngineMediaWrapsAWidget() {
        let widget = TelegramMediaWidget(width: 0, height: 120, payload: Data([0x1f, 0x8b]))
        let media = EngineMedia(widget)
        guard case let .widget(wrapped) = media else {
            return XCTFail("\(media)")
        }
        XCTAssertTrue(wrapped === widget)
        XCTAssertTrue(media._asMedia() === widget)
        XCTAssertNil(media.id)
        XCTAssertEqual(media, EngineMedia(TelegramMediaWidget(width: 0, height: 120, payload: Data([0x1f, 0x8b]))))
    }

    func testWidgetsDifferingInPayloadAreNotEqual() {
        let a = TelegramMediaWidget(width: 0, height: 0, payload: Data([1]))
        XCTAssertFalse(a.isEqual(to: TelegramMediaWidget(width: 0, height: 0, payload: Data([2]))))
        XCTAssertFalse(a.isEqual(to: TelegramMediaWidget(width: 1, height: 0, payload: Data([1]))))
        XCTAssertTrue(a.isEqual(to: TelegramMediaWidget(width: 0, height: 0, payload: Data([1]))))
    }

    /// widget-sandbox v0.2 (tgw-format.md): a forward is a copy, with no queries and no chat state; its shared state and
    /// widget id stay (a shared widget's copy follows the shared state).
    func testAForwardedCopyKeepsOnlyWhatACopyMayHave() {
        let widget = TelegramMediaWidget(width: 300, height: 120, payload: Data([1, 2]), isCopy: false, canQuery: true, backgroundQuery: true, chatData: Data("c".utf8), publicData: Data("p".utf8), widgetId: 42)
        let copy = widget.forwardedCopy()
        XCTAssertTrue(copy.isCopy)
        XCTAssertFalse(copy.canQuery)
        XCTAssertFalse(copy.backgroundQuery)
        XCTAssertNil(copy.chatData)
        XCTAssertEqual(copy.width, 300)
        XCTAssertEqual(copy.height, 120)
        XCTAssertEqual(copy.payload, Data([1, 2]))
        XCTAssertEqual(copy.publicData, Data("p".utf8))
        XCTAssertEqual(copy.widgetId, 42)
    }
}
