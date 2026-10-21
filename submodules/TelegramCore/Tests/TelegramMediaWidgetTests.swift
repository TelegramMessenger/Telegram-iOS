import XCTest
import Postbox
import MtProtoKit
import TelegramApi
@testable import TelegramCore

/// The widget message media (`messageMediaWidget width:int height:int payload:bytes`, layer 233; widget-sandbox v0.1.0
/// tgw-format.md): the size anchors and the HTML gzipped by the server, which the client gunzips with no size check of
/// its own.
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

    func testTheHtmlIsThePayloadGunzipped() {
        guard let widget = TelegramMediaWidget(html: "<p>Hi</p>", width: 0, height: 0) else {
            return XCTFail("no widget")
        }
        XCTAssertEqual(widget.payload.prefix(2), Data([0x1f, 0x8b]))
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
