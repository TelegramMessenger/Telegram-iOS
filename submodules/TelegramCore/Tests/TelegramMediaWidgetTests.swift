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
        let api = Api.MessageMedia.messageMediaWidget(.init(width: 300, height: 0, payload: Buffer(data: payload)))
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
}
