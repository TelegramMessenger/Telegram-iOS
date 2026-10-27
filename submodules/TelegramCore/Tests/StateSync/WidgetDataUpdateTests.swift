import Foundation
import XCTest
import SwiftSignalKit
import Postbox
import TelegramApi
@testable import TelegramCore

private let getHistory = "messages.getHistory"

/// widget-sandbox v0.2 (W2 plan, Task 3): `updateMessageWidgetData`, the bot's edit of a message widget's state in a
/// private chat or basic group, in the account's pts sequence. A field it carries replaces the stored one (an empty one
/// clears it), a field it leaves out stays, and nothing else of the message changes; its pts is sequenced like any
/// other, so it opens no gap. The edit is recorded, so a fill already in flight keeps it.
final class WidgetDataUpdateTests: StateSyncTestCase {
    private func widget(chatData: String?, publicData: String?) -> TelegramMediaWidget {
        return TelegramMediaWidget(width: 0, height: 0, payload: Data("<p>w</p>".utf8), chatData: chatData.map { Data($0.utf8) }, publicData: publicData.map { Data($0.utf8) })
    }

    private func storedWidget(_ id: MessageId) -> TelegramMediaWidget? {
        return self.fixture.message(id)?.media.first(where: { $0 is TelegramMediaWidget }) as? TelegramMediaWidget
    }

    private func push(_ update: Api.Update) {
        self.server.push(StateSyncApi.updates([update], users: [StateSyncApi.user(id: 500, firstName: "U500")], date: self.baseDate + 20, seq: 0))
        self.drainOperationQueue()
    }

    func testAPushEditsTheStoredWidgetInSequence() {
        let peerId = self.seedUserChat(500)
        self.fixture.storeMessage(peerId: peerId, id: 12, timestamp: self.baseDate + 12, authorId: peerId, text: "", media: [self.widget(chatData: "c1", publicData: "p1")])
        self.launchIdle()

        self.push(StateSyncApi.updateMessageWidgetData(userId: 500, msgId: 12, chatData: "c2", publicData: nil, pts: 101))

        let widget = self.storedWidget(self.messageId(peerId, 12))
        XCTAssertEqual(widget?.chatData, Data("c2".utf8))
        XCTAssertEqual(widget?.publicData, Data("p1".utf8))
        XCTAssertEqual(widget?.payload, Data("<p>w</p>".utf8))
        XCTAssertEqual(self.fixture.accountState()?.state?.pts, 101)
        XCTAssertEqual(self.server.requestNames, [Name.getDifference])
    }

    /// upstream integration.md: an empty field clears the state (stored as none, as a message without it parses), an
    /// absent one leaves it.
    func testAnEmptyFieldClearsAndAnAbsentOneIsUnchanged() {
        let peerId = self.seedUserChat(500)
        self.fixture.storeMessage(peerId: peerId, id: 12, timestamp: self.baseDate + 12, authorId: peerId, text: "", media: [self.widget(chatData: "c1", publicData: "p1")])
        self.launchIdle()

        self.push(StateSyncApi.updateMessageWidgetData(userId: 500, msgId: 12, chatData: nil, publicData: "", pts: 101))

        let widget = self.storedWidget(self.messageId(peerId, 12))
        XCTAssertEqual(widget?.chatData, Data("c1".utf8))
        XCTAssertNil(widget?.publicData)
        XCTAssertEqual(self.fixture.accountState()?.state?.pts, 101)
    }

    /// The shared state comes with its hash (2026-10-27 schema, `public_data_hash`), stored beside it, so a later poll
    /// of a shared widget starts from it.
    func testThePushedSharedStateKeepsItsHash() {
        let peerId = self.seedUserChat(500)
        self.fixture.storeMessage(peerId: peerId, id: 12, timestamp: self.baseDate + 12, authorId: peerId, text: "", media: [self.widget(chatData: "c1", publicData: "p1")])
        self.launchIdle()

        self.push(StateSyncApi.updateMessageWidgetData(userId: 500, msgId: 12, chatData: nil, publicData: "p2", publicDataHash: 77, pts: 101))

        let widget = self.storedWidget(self.messageId(peerId, 12))
        XCTAssertEqual(widget?.publicData, Data("p2".utf8))
        XCTAssertEqual(widget?.publicDataHash, 77)
        XCTAssertEqual(widget?.chatData, Data("c1".utf8))
    }

    /// A push for a message that is not stored, or that has no widget, changes nothing but the pts: no gap, no request.
    func testAPushForAMessageNotStoredOrWithoutAWidgetOnlyAdvances() {
        let peerId = self.seedUserChat(500)
        self.fixture.storeMessage(peerId: peerId, id: 13, timestamp: self.baseDate + 13, authorId: peerId, text: "plain")
        self.launchIdle()

        self.push(StateSyncApi.updateMessageWidgetData(userId: 500, msgId: 99, chatData: "c2", publicData: nil, pts: 101))
        self.push(StateSyncApi.updateMessageWidgetData(userId: 500, msgId: 13, chatData: "c2", publicData: nil, pts: 102))

        XCTAssertNil(self.fixture.message(self.messageId(peerId, 99)))
        XCTAssertEqual(self.fixture.message(self.messageId(peerId, 13))?.text, "plain")
        XCTAssertTrue(self.fixture.message(self.messageId(peerId, 13))?.media.isEmpty ?? false)
        XCTAssertEqual(self.fixture.accountState()?.state?.pts, 102)
        XCTAssertEqual(self.server.requestNames, [Name.getDifference])
    }

    /// As RecentEditTests.testStoredMessageEditedWhileTheRequestWasInFlightKeepsTheEdit: the state is edited while a
    /// history fill is in flight, and the fill's answer, produced before the edit, holds the old state. The fill keeps
    /// the edit.
    func testAFillInFlightDoesNotOverwriteThePushedState() {
        let peerId = self.seedUserChat(500)
        self.fixture.storeMessage(peerId: peerId, id: 12, timestamp: self.baseDate + 12, authorId: peerId, text: "", media: [self.widget(chatData: "c1", publicData: "p1")])
        self.launchIdle()
        self.addHistoryFillHole(peerId)
        self.server.on(getHistory, .hold)

        let results = self.fixture.observe(self.historyFill(peerInput: .direct(peerId: peerId, threadId: nil), direction: self.downwardFillDirection(peerId)))

        XCTAssertTrue(self.server.waitForRequest(getHistory), "no fill was sent: \(self.server.requestNames)")
        self.push(StateSyncApi.updateMessageWidgetData(userId: 500, msgId: 12, chatData: "c2", publicData: nil, pts: 101))
        XCTAssertEqual(self.storedWidget(self.messageId(peerId, 12))?.chatData, Data("c2".utf8), "precondition: the replay edited the stored widget")
        XCTAssertTrue(self.server.release(getHistory, with: .result(StateSyncApi.messages([
            StateSyncApi.privateMessage(id: 12, peerUserId: 500, fromUserId: 500, date: self.baseDate + 12, text: "", media: StateSyncApi.widgetMedia(chatData: "c1", publicData: "p1")),
            StateSyncApi.privateMessage(id: 10, peerUserId: 500, fromUserId: 500, date: self.baseDate + 10, text: "original")
        ]))))
        results.wait { !$0.isEmpty }

        XCTAssertEqual(self.storedWidget(self.messageId(peerId, 12))?.chatData, Data("c2".utf8), "the fill's older answer undid the bot's state edit made while it was in flight")
    }
}
