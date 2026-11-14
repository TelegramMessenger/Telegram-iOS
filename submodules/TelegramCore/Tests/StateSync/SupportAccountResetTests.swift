import Foundation
import XCTest
import SwiftSignalKit
import Postbox
import TelegramApi
@testable import TelegramCore

/// The account reset after differenceTooLong on a support account (`supportAccountResetChat`): one-to-one chats that
/// are already empty are left as they are, and those without a received message are cleared, instead of a hole each.
final class SupportAccountResetTests: StateSyncTestCase {
    private func seedSupportCustomerChat(_ id: Int64) -> PeerId {
        let peerId = StateSyncFixture.userPeerId(id)
        self.fixture.seedPeers([StateSyncFixture.makeUser(id: peerId, accessHash: 1, firstName: "U\(id)")])
        self.fixture.seedChat(peerId: peerId)
        return peerId
    }

    private func isInitialized(_ peerId: PeerId) -> Bool {
        return self.fixture.transaction { $0.isMessageHistoryInitialized(peerId: peerId) } ?? false
    }

    private func inclusion(_ peerId: PeerId) -> PeerChatListInclusion? {
        return self.fixture.transaction { $0.getPeerChatListInclusion(peerId) }
    }

    private func seedThreeChats() -> (untouched: PeerId, sentOnly: PeerId, received: PeerId) {
        let untouched = self.seedSupportCustomerChat(500)
        let sentOnly = self.seedSupportCustomerChat(501)
        self.fixture.storeMessage(peerId: sentOnly, id: 10, timestamp: self.baseDate - 100, authorId: StateSyncFixture.accountPeerId, text: "switched", incoming: false)
        let received = self.seedSupportCustomerChat(502)
        self.fixture.storeMessage(peerId: received, id: 20, timestamp: self.baseDate - 50, authorId: received, text: "hello", incoming: true)
        self.fixture.removeAllHoles(peerId: received)
        return (untouched, sentOnly, received)
    }

    func testSupportResetSkipsEmptyChatsAndClearsChatsWithOnlySentMessages() {
        let chats = self.seedThreeChats()
        self.fixture.seedAccount(state: self.state(pts: 100), accountPhone: "4240000000")
        self.startAccountReset(dialogs: StateSyncApi.dialogs())
        self.drainOperationQueue()

        XCTAssertFalse(self.isInitialized(chats.untouched), "the reset set up an empty chat's history")
        XCTAssertNil(self.fixture.message(MessageId(peerId: chats.sentOnly, namespace: Namespaces.Message.Cloud, id: 10)))
        XCTAssertFalse(self.isInitialized(chats.sentOnly))
        XCTAssertNotNil(self.fixture.message(MessageId(peerId: chats.received, namespace: Namespaces.Message.Cloud, id: 20)))
        XCTAssertTrue(self.fixture.holes(peerId: chats.received).contains(integersIn: 21 ... 1000), "a chat with a received message was not reset")
        for peerId in [chats.sentOnly, chats.received] {
            XCTAssertEqual(self.inclusion(peerId), .notIncluded)
        }
    }

    func testOrdinaryAccountResetStillResetsEveryChat() {
        let chats = self.seedThreeChats()
        self.fixture.seedAccount(state: self.state(pts: 100))
        self.startAccountReset(dialogs: StateSyncApi.dialogs())
        self.drainOperationQueue()

        XCTAssertTrue(self.isInitialized(chats.untouched))
        XCTAssertNotNil(self.fixture.message(MessageId(peerId: chats.sentOnly, namespace: Namespaces.Message.Cloud, id: 10)))
        XCTAssertTrue(self.fixture.holes(peerId: chats.sentOnly).contains(integersIn: 11 ... 1000))
        XCTAssertTrue(self.fixture.holes(peerId: chats.received).contains(integersIn: 21 ... 1000))
    }

    /// A one-to-one chat outside the list was hidden by an earlier reset, which put a hole over it, or deleted or
    /// cleaned up; the support reset reads nothing of it.
    func testSupportResetLeavesChatsOutsideTheListUntouched() {
        let hidden = self.seedSupportCustomerChat(503)
        self.fixture.storeMessage(peerId: hidden, id: 30, timestamp: self.baseDate - 30, authorId: hidden, text: "old", incoming: true)
        self.fixture.removeAllHoles(peerId: hidden)
        let _ = self.fixture.transaction { $0.updatePeerChatListInclusion(hidden, inclusion: .notIncluded) }
        self.fixture.seedAccount(state: self.state(pts: 100), accountPhone: "4240000000")
        self.startAccountReset(dialogs: StateSyncApi.dialogs())
        self.drainOperationQueue()

        XCTAssertNotNil(self.fixture.message(MessageId(peerId: hidden, namespace: Namespaces.Message.Cloud, id: 30)))
        XCTAssertFalse(self.fixture.holes(peerId: hidden).contains(31), "the reset touched a chat outside the list")
    }

    /// The hidden-chat sweep keeps a chat a folder names, so it can store loaded messages with no hole over them.
    func testSupportResetPutsAHoleOverAHiddenChatAFolderNames() {
        let named = self.seedSupportCustomerChat(504)
        self.fixture.storeMessage(peerId: named, id: 40, timestamp: self.baseDate - 30, authorId: named, text: "old", incoming: true)
        self.fixture.removeAllHoles(peerId: named)
        let folderData = ChatListFilterData(isShared: false, hasSharedLinks: false, categories: [], excludeMuted: false, excludeRead: false, excludeArchived: false, includePeers: ChatListFilterIncludePeers(peers: [named], pinnedPeers: []), excludePeers: [], color: nil)
        let folder = ChatListFilter.filter(id: 2, title: ChatFolderTitle(text: "F", entities: [], enableAnimations: false), emoticon: nil, data: folderData)
        let _ = self.fixture.transaction { transaction -> Void in
            transaction.updatePeerChatListInclusion(named, inclusion: .notIncluded)
            _internal_updateChatListFiltersInteractively(transaction: transaction, { _ in [folder] })
        }
        self.fixture.seedAccount(state: self.state(pts: 100), accountPhone: "4240000000")
        self.startAccountReset(dialogs: StateSyncApi.dialogs())
        self.drainOperationQueue()

        XCTAssertTrue(self.fixture.holes(peerId: named).contains(integersIn: 41 ... 1000), "a hidden chat a folder names was not reset")
    }

    func testSupportResetDoesNotClearAChatOnScreen() {
        let onScreen = self.seedSupportCustomerChat(505)
        self.fixture.storeMessage(peerId: onScreen, id: 50, timestamp: self.baseDate - 30, authorId: StateSyncFixture.accountPeerId, text: "switched", incoming: false)
        let views = self.fixture.observe(self.fixture.postbox.aroundMessageHistoryViewForLocation(.peer(peerId: onScreen, threadId: nil), anchor: .upperBound, ignoreMessagesInTimestampRange: nil, ignoreMessageIds: [], count: 20, fixedCombinedReadStates: nil, topTaggedMessageIdNamespaces: [], tag: nil, appendMessagesFromTheSameGroup: false, namespaces: .all, orderStatistics: []) |> map { $0.0 })
        views.wait { !$0.isEmpty }
        self.fixture.seedAccount(state: self.state(pts: 100), accountPhone: "4240000000")
        self.startAccountReset(dialogs: StateSyncApi.dialogs())
        self.drainOperationQueue()

        XCTAssertNotNil(self.fixture.message(MessageId(peerId: onScreen, namespace: Namespaces.Message.Cloud, id: 50)), "the reset cleared a chat on screen")
        XCTAssertTrue(self.fixture.holes(peerId: onScreen).contains(integersIn: 51 ... 1000), "a chat on screen did not get the reset's hole")
    }
}
