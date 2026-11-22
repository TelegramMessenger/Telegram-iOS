import Foundation
import XCTest
import SwiftSignalKit
import Postbox
import TelegramApi
@testable import TelegramCore

private let getWidgetPublicData = "messages.getWidgetPublicData"

/// widget-sandbox v0.2 (W2 plan, Task 4): the shared-state poller against the scripted server. Two messages show the
/// shared widget 42 on screen and watch; one `messages.getWidgetPublicData` goes out at once, for the first (the
/// carrier) with hash 0, and a new shared state is written into both stored widgets; a not-modified answer leaves them.
final class WidgetPublicDataPollingTests: StateSyncTestCase {
    private func storeSharedWidget(_ peerId: PeerId, _ id: Int32, publicDataHash: Int64? = nil) {
        let widget = TelegramMediaWidget(width: 0, height: 0, payload: Data("<p>w</p>".utf8), publicData: Data("old".utf8), publicDataHash: publicDataHash, widgetId: 42)
        self.fixture.storeMessage(peerId: peerId, id: id, timestamp: self.baseDate + id, authorId: peerId, text: "", media: [widget])
    }

    private func publicData(_ id: MessageId) -> Data? {
        return (self.fixture.message(id)?.media.first(where: { $0 is TelegramMediaWidget }) as? TelegramMediaWidget)?.publicData
    }

    func testAPollWritesTheNewStateIntoEveryRegisteredMessage() {
        let peerId = self.seedUserChat(500)
        self.storeSharedWidget(peerId, 12)
        self.storeSharedWidget(peerId, 13)
        self.server.on(getWidgetPublicData, .result(Api.messages.WidgetPublicData.widgetPublicData(.init(hash: 9, data: "new", period: 3600))))
        let polling = WidgetPublicDataPolling(queue: Queue(), postbox: self.fixture.postbox, network: self.network)

        let first = polling.poll(messageId: self.messageId(peerId, 12), widgetId: 42).startStandalone()
        let second = polling.poll(messageId: self.messageId(peerId, 13), widgetId: 42).startStandalone()
        self.fixture.eventually { self.publicData(self.messageId(peerId, 13)) == Data("new".utf8) }

        XCTAssertEqual(self.publicData(self.messageId(peerId, 12)), Data("new".utf8))
        let polls = self.server.requests.filter { $0.name == getWidgetPublicData }
        XCTAssertEqual(polls.count, 1)
        XCTAssertEqual(polls.first?.payload, Api.functions.messages.getWidgetPublicData(peer: .inputPeerUser(.init(userId: 500, accessHash: 1)), msgId: 12, hash: 0).1.makeData(), "arguments: \(polls.first?.arguments ?? "none")")
        first.dispose()
        second.dispose()
    }

    /// A message that carries its shared state's hash (2026-10-27 schema) is polled with it, so an unchanged state
    /// answers "not modified"; a new state is stored with its hash.
    func testTheFirstPollSendsTheMessagesHash() {
        let peerId = self.seedUserChat(500)
        self.storeSharedWidget(peerId, 12, publicDataHash: 7)
        self.server.on(getWidgetPublicData, .result(Api.messages.WidgetPublicData.widgetPublicData(.init(hash: 9, data: "new", period: 3600))))
        let polling = WidgetPublicDataPolling(queue: Queue(), postbox: self.fixture.postbox, network: self.network)

        let subscription = polling.poll(messageId: self.messageId(peerId, 12), widgetId: 42).startStandalone()
        self.fixture.eventually { self.publicData(self.messageId(peerId, 12)) == Data("new".utf8) }

        let polls = self.server.requests.filter { $0.name == getWidgetPublicData }
        XCTAssertEqual(polls.first?.payload, Api.functions.messages.getWidgetPublicData(peer: .inputPeerUser(.init(userId: 500, accessHash: 1)), msgId: 12, hash: 7).1.makeData(), "arguments: \(polls.first?.arguments ?? "none")")
        let widget = self.fixture.message(self.messageId(peerId, 12))?.media.first(where: { $0 is TelegramMediaWidget }) as? TelegramMediaWidget
        XCTAssertEqual(widget?.publicDataHash, 9)
        subscription.dispose()
    }

    /// W2 final review, Important 4: a polled state is recorded as an edit, so a history fill already in flight, whose
    /// answer predates the poll, keeps it (as a pushed state edit is kept).
    func testAFillInFlightDoesNotOverwriteAPolledState() {
        let peerId = self.seedUserChat(500)
        self.storeSharedWidget(peerId, 12)
        self.launchIdle()
        self.addHistoryFillHole(peerId)
        self.server.on("messages.getHistory", .hold)
        let results = self.fixture.observe(self.historyFill(peerInput: .direct(peerId: peerId, threadId: nil), direction: self.downwardFillDirection(peerId)))
        XCTAssertTrue(self.server.waitForRequest("messages.getHistory"), "no fill was sent: \(self.server.requestNames)")

        self.server.on(getWidgetPublicData, .result(Api.messages.WidgetPublicData.widgetPublicData(.init(hash: 9, data: "new", period: 3600))))
        let polling = WidgetPublicDataPolling(queue: Queue(), postbox: self.fixture.postbox, network: self.network)
        let subscription = polling.poll(messageId: self.messageId(peerId, 12), widgetId: 42).startStandalone()
        self.fixture.eventually { self.publicData(self.messageId(peerId, 12)) == Data("new".utf8) }

        XCTAssertTrue(self.server.release("messages.getHistory", with: .result(StateSyncApi.messages([
            StateSyncApi.privateMessage(id: 12, peerUserId: 500, fromUserId: 500, date: self.baseDate + 12, text: "", media: StateSyncApi.widgetMedia(chatData: nil, publicData: "old", publicDataHash: 1, widgetId: 42))
        ]))))
        results.wait { !$0.isEmpty }

        XCTAssertEqual(self.publicData(self.messageId(peerId, 12)), Data("new".utf8), "the fill's older answer undid a polled state")
        subscription.dispose()
    }

    func testNotModifiedLeavesTheStoredState() {
        let peerId = self.seedUserChat(500)
        self.storeSharedWidget(peerId, 12)
        self.storeSharedWidget(peerId, 13)
        self.server.on(getWidgetPublicData, .result(Api.messages.WidgetPublicData.widgetPublicDataNotModified(.init(period: 3600))))
        let polling = WidgetPublicDataPolling(queue: Queue(), postbox: self.fixture.postbox, network: self.network)

        let first = polling.poll(messageId: self.messageId(peerId, 12), widgetId: 42).startStandalone()
        let second = polling.poll(messageId: self.messageId(peerId, 13), widgetId: 42).startStandalone()
        XCTAssertTrue(self.server.waitForRequest(getWidgetPublicData))
        // The answer is applied on the poller's queue after the request returns; give it the time a write would take.
        Thread.sleep(forTimeInterval: 0.5)

        XCTAssertEqual(self.publicData(self.messageId(peerId, 12)), Data("old".utf8))
        XCTAssertEqual(self.publicData(self.messageId(peerId, 13)), Data("old".utf8))
        first.dispose()
        second.dispose()
    }
}
