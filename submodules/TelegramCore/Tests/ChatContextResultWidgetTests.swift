import Foundation
import XCTest
import Postbox
import TelegramApi
@testable import TelegramCore

/// A bot's inline result that is a widget (widget-sandbox v0.2, sdk-v1 §2.16; W3 plan Task 1): the result keeps its
/// widget, state and text (`botInlineMessageWidget`, the 2026-10-27 schema's `#baa17834`), persists in the results cache,
/// and its outgoing message carries the widget as the echo's media, except in a secret chat, which cannot carry one.
final class ChatContextResultWidgetTests: XCTestCase {
    private func apiWidgetMessage(message: String = "Play") -> Api.BotInlineMessage {
        let flags: Int32 = (1 << 0) | (1 << 1) | (1 << 3) | (1 << 4)
        return .botInlineMessageWidget(.init(flags: flags, width: 300, height: 0, payload: Buffer(data: Data([1, 2, 3])), publicData: "p", publicDataHash: 7, chatData: "c", replyMarkup: nil, widgetId: 42, message: message, entities: [.messageEntityBold(.init(offset: 0, length: 4))]))
    }

    private func widgetResultMessage(publicData: String = "p", caption: String = "Play") -> ChatContextResultMessage {
        let media = TelegramMediaWidget(width: 300, height: 0, payload: Data([1, 2, 3]), chatData: Data("c".utf8), publicData: Data(publicData.utf8), publicDataHash: 7, widgetId: 42)
        return .widget(media: media, caption: caption, entities: TextEntitiesMessageAttribute(entities: [MessageTextEntity(range: 0 ..< 4, type: .Bold)]), replyMarkup: ReplyMarkupMessageAttribute(rows: [], flags: [], placeholder: nil))
    }

    private func result(_ message: ChatContextResultMessage) -> ChatContextResult {
        return .externalReference(ChatContextResult.ExternalReference(queryId: 1, id: "w1", type: "widget", title: "Tic-tac-toe", description: nil, url: nil, content: nil, thumbnail: nil, message: message))
    }

    private func peer(_ namespace: PeerId.Namespace) -> PeerId {
        return PeerId(namespace: namespace, id: PeerId.Id._internalFromInt64Value(5))
    }

    func testAWidgetResultKeepsItsWidgetStateAndText() throws {
        guard case let .widget(media, caption, entities, replyMarkup) = ChatContextResultMessage(apiMessage: self.apiWidgetMessage()) else {
            return XCTFail("not a widget result")
        }
        XCTAssertEqual(media.width, 300)
        XCTAssertEqual(media.height, 0)
        XCTAssertEqual(media.payload, Data([1, 2, 3]))
        XCTAssertEqual(media.publicData, Data("p".utf8))
        XCTAssertEqual(media.publicDataHash, 7)
        XCTAssertEqual(media.chatData, Data("c".utf8))
        XCTAssertEqual(media.widgetId, 42)
        XCTAssertFalse(media.isCopy)
        XCTAssertFalse(media.canQuery)
        XCTAssertFalse(media.backgroundQuery)
        XCTAssertEqual(caption, "Play")
        XCTAssertEqual(entities?.entities, [MessageTextEntity(range: 0 ..< 4, type: .Bold)])
        XCTAssertNil(replyMarkup)
    }

    func testAWidgetResultRoundTripsThroughPostboxCoding() {
        let message = self.widgetResultMessage()
        let encoder = PostboxEncoder()
        message.encode(encoder)
        let decoded = ChatContextResultMessage(decoder: PostboxDecoder(buffer: MemoryBuffer(data: encoder.makeData())))
        XCTAssertEqual(decoded, message)
    }

    func testAWidgetResultRoundTripsThroughCodable() throws {
        let collection = ChatContextResultCollection(botId: self.peer(Namespaces.Peer.CloudUser), peerId: self.peer(Namespaces.Peer.CloudUser), query: "", geoPoint: nil, queryId: 1, nextOffset: nil, presentation: .list, switchPeer: nil, webView: nil, results: [self.result(self.widgetResultMessage())], cacheTimeout: 60)
        let data = try JSONEncoder().encode(collection)
        let decoded = try JSONDecoder().decode(ChatContextResultCollection.self, from: data)
        XCTAssertEqual(decoded, collection)
    }

    func testWidgetResultsDifferingInStateAreNotEqual() {
        XCTAssertEqual(self.widgetResultMessage(publicData: "p"), self.widgetResultMessage(publicData: "p"))
        XCTAssertNotEqual(self.widgetResultMessage(publicData: "p"), self.widgetResultMessage(publicData: "q"))
    }

    func testAWidgetResultsEchoIsTheWidgetWithItsText() throws {
        let message = self.widgetResultMessage()
        guard case let .widget(resultMedia, _, _, _) = message else {
            return XCTFail("not a widget result")
        }
        let outgoing = _internal_outgoingMessageWithChatContextResult(to: self.peer(Namespaces.Peer.CloudUser), threadId: nil, botId: self.peer(Namespaces.Peer.CloudUser), result: self.result(message), replyToMessageId: nil, replyToStoryId: nil, hideVia: false, silentPosting: false, scheduleTime: nil, sendPaidMessageStars: nil, postpone: false, correlationId: nil)
        guard case let .message(text, attributes, _, mediaReference, _, _, _, _, _, _) = try XCTUnwrap(outgoing) else {
            return XCTFail("not a message")
        }
        XCTAssertEqual(text, "Play")
        let widget = try XCTUnwrap(mediaReference?.media as? TelegramMediaWidget)
        XCTAssertTrue(widget.isEqual(to: resultMedia))
        XCTAssertFalse(widget.isCopy)
        XCTAssertFalse(widget.canQuery)
        XCTAssertFalse(widget.backgroundQuery)
        XCTAssertTrue(attributes.contains { $0 is OutgoingChatContextResultMessageAttribute })
        XCTAssertTrue(attributes.contains { $0 is InlineBotMessageAttribute })
        XCTAssertTrue(attributes.contains { ($0 as? TextEntitiesMessageAttribute)?.entities == [MessageTextEntity(range: 0 ..< 4, type: .Bold)] })
    }

    func testAWidgetResultInASecretChatSendsItsTextAlone() throws {
        let secretPeer = self.peer(Namespaces.Peer.SecretChat)
        let outgoing = _internal_outgoingMessageWithChatContextResult(to: secretPeer, threadId: nil, botId: self.peer(Namespaces.Peer.CloudUser), result: self.result(self.widgetResultMessage()), replyToMessageId: nil, replyToStoryId: nil, hideVia: false, silentPosting: false, scheduleTime: nil, sendPaidMessageStars: nil, postpone: false, correlationId: nil)
        guard case let .message(text, attributes, _, mediaReference, _, _, _, _, _, _) = try XCTUnwrap(outgoing) else {
            return XCTFail("not a message")
        }
        XCTAssertEqual(text, "Play")
        XCTAssertNil(mediaReference)
        XCTAssertFalse(attributes.contains { $0 is ReplyMarkupMessageAttribute })

        let empty = _internal_outgoingMessageWithChatContextResult(to: secretPeer, threadId: nil, botId: self.peer(Namespaces.Peer.CloudUser), result: self.result(self.widgetResultMessage(caption: "")), replyToMessageId: nil, replyToStoryId: nil, hideVia: false, silentPosting: false, scheduleTime: nil, sendPaidMessageStars: nil, postpone: false, correlationId: nil)
        XCTAssertNil(empty)
    }
}
