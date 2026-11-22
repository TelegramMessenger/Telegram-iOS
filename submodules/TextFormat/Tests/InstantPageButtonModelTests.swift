import XCTest
import Postbox
import FlatBuffers
// The flatc-generated TelegramCore_* types live in this module, not in TelegramCore.
import FlatSerialization
import TelegramCore

/// Round-trips `InstantPageButton` through both codecs. The FlatBuffers half matters most: it is
/// brand new (reply markups were Postbox-only until page buttons needed them), and in DEBUG
/// `FlatBuffers_getRoot` uses `getCheckedRoot`, so these tests also exercise buffer verification.
final class InstantPageButtonModelTests: XCTestCase {
    private func postboxRoundTrip(_ button: InstantPageButton) -> InstantPageButton {
        let encoder = PostboxEncoder()
        button.encode(encoder)
        return InstantPageButton(decoder: PostboxDecoder(buffer: MemoryBuffer(data: encoder.makeData())))
    }

    private func flatBuffersRoundTrip(_ button: InstantPageButton) throws -> InstantPageButton {
        var builder = FlatBufferBuilder(initialSize: 1024)
        let offset = button.encodeToFlatBuffers(builder: &builder)
        builder.finish(offset: offset)
        var byteBuffer = ByteBuffer(data: builder.data)
        let object: TelegramCore_InstantPageButton = FlatBuffers_getRoot(byteBuffer: &byteBuffer)
        return try InstantPageButton(flatBuffersObject: object)
    }

    /// Exactly the 10 actions reachable from Api.InlineButtonType — i.e. the 10 union members.
    private static let inlineReachableActions: [ReplyMarkupButtonAction] = [
        .url("https://t.me"),
        .urlAuth(url: "https://a", buttonId: 7),
        .openWebView(url: "https://w", simple: false),
        .callback(requiresPassword: true, data: MemoryBuffer(data: Data([1, 2, 3]))),
        .openWebApp,
        .payment,
        .switchInline(samePeer: true, query: "q", peerTypes: ReplyMarkupButtonAction.PeerTypes.users),
        .openUserProfile(peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(42))),
        .copyText(payload: "abc"),
        .disabled
    ]

    private static let allColors: [ReplyMarkupButton.Style.Color?] = [nil, .primary, .danger, .success]

    func test_postboxRoundTrip_everyActionAndColor() {
        for action in Self.inlineReachableActions {
            for color in Self.allColors {
                let button = InstantPageButton(text: .plain("Go"), action: action, color: color)
                XCTAssertEqual(self.postboxRoundTrip(button), button,
                               "action \(action), color \(String(describing: color))")
            }
        }
    }

    func test_flatBuffersRoundTrip_everyActionAndColor() throws {
        for action in Self.inlineReachableActions {
            for color in Self.allColors {
                let button = InstantPageButton(text: .plain("Go"), action: action, color: color)
                XCTAssertEqual(try self.flatBuffersRoundTrip(button), button,
                               "action \(action), color \(String(describing: color))")
            }
        }
    }

    /// A button label is full RichText, so nesting must survive — this is what makes textButton an
    /// inline construct rather than a plain string.
    func test_nestedRichTextLabelSurvivesBothCodecs() throws {
        let button = InstantPageButton(
            text: .concat([.bold(.plain("Bold")), .plain(" and "), .italic(.plain("italic"))]),
            action: .url("https://t.me"),
            color: .primary
        )
        XCTAssertEqual(self.postboxRoundTrip(button), button)
        XCTAssertEqual(try self.flatBuffersRoundTrip(button), button)
    }

    /// Empty callback data is a real wire case and must not be confused with a missing field.
    func test_callbackWithEmptyDataRoundTrips() throws {
        let button = InstantPageButton(
            text: .plain("Tap"),
            action: .callback(requiresPassword: false, data: MemoryBuffer(data: Data())),
            color: nil
        )
        XCTAssertEqual(self.postboxRoundTrip(button), button)
        XCTAssertEqual(try self.flatBuffersRoundTrip(button), button)
    }

    /// nil colour must stay nil rather than decoding as .primary (rawValue 0) — the -1 sentinel is
    /// the only thing separating "no style" from "primary".
    func test_nilColorIsNotConfusedWithPrimary() throws {
        let noColor = InstantPageButton(text: .plain("x"), action: .payment, color: nil)
        XCTAssertNil(self.postboxRoundTrip(noColor).color)
        XCTAssertNil(try self.flatBuffersRoundTrip(noColor).color)

        let primary = InstantPageButton(text: .plain("x"), action: .payment, color: .primary)
        XCTAssertEqual(self.postboxRoundTrip(primary).color, .primary)
        XCTAssertEqual(try self.flatBuffersRoundTrip(primary).color, .primary)
    }

    /// The five keyboard-only actions cannot occur on a page button. The FlatBuffers codec collapses
    /// them onto .disabled rather than trapping; assert that contract explicitly so a future change
    /// to it is a deliberate one. Note Postbox coding is lossless for these, so only the
    /// FlatBuffers direction collapses.
    func test_keyboardOnlyActionsCollapseToDisabledInFlatBuffers() throws {
        for action in [ReplyMarkupButtonAction.text, .requestPhone, .requestMap,
                       .setupPoll(isQuiz: nil), .requestPeer(
                        peerType: .user(ReplyMarkupButtonRequestPeerType.User(isBot: nil, isPremium: nil)),
                        buttonId: 1, maxQuantity: 1)] {
            let button = InstantPageButton(text: .plain("x"), action: action, color: nil)
            XCTAssertEqual(try self.flatBuffersRoundTrip(button).action, .disabled,
                           "\(action) should collapse to .disabled")
        }
    }

    func test_switchInlinePeerTypesSurviveAsRawValue() throws {
        var types = ReplyMarkupButtonAction.PeerTypes()
        types.insert(.bots)
        types.insert(.channels)
        let button = InstantPageButton(
            text: .plain("x"),
            action: .switchInline(samePeer: false, query: "hello", peerTypes: types),
            color: nil
        )
        guard case let .switchInline(samePeer, query, decoded) = try self.flatBuffersRoundTrip(button).action else {
            return XCTFail("expected switchInline")
        }
        XCTAssertFalse(samePeer)
        XCTAssertEqual(query, "hello")
        XCTAssertTrue(decoded.contains(.bots))
        XCTAssertTrue(decoded.contains(.channels))
        XCTAssertFalse(decoded.contains(.users))
    }
}
