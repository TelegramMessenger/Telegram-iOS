import Foundation
import XCTest
import Intents
import SwiftSignalKit
import Postbox
import TelegramCore
@testable import IntentsExtensionLib

/// "Read my messages" without any filter: the unread scan over the chat list, run against a
/// real store seeded the way the account does it (peers, chat-list inclusion, incoming
/// messages, read states).
final class UnreadMessagesScanTests: XCTestCase {
    private var store: TestPostbox!
    private var postbox: Postbox { return self.store.postbox }

    private let alice = IntentMessageFixtures.user(1001, firstName: "Alice", phone: "15551234567")
    private let bob = IntentMessageFixtures.user(1002, firstName: "Bob", phone: "15557654321")
    private let ride = IntentMessageFixtures.group(2001, title: "Weekend Ride")
    private let news = IntentMessageFixtures.broadcastChannel(4001, title: "Daily News")

    override func setUpWithError() throws {
        try super.setUpWithError()
        self.store = try TestPostbox(name: "unread-scan")
        // A fresh store carries the seed configuration's chat-list hole until the first
        // chat-list fetch replaces it; the chat list is not readable beneath that hole.
        self.transaction { transaction in
            if let hole = telegramPostboxSeedConfiguration.initializeChatListWithHole.topLevel {
                transaction.replaceChatListHole(groupId: .root, index: hole.index, hole: nil)
            }
        }
    }

    override func tearDownWithError() throws {
        self.store.close()
        self.store = nil
        try super.tearDownWithError()
    }

    private func transaction(_ f: @escaping (Transaction) -> Void) {
        self.store.transaction(f)
    }

    private func incoming(_ id: Int32, in chat: Peer, from author: Peer, text: String, timestamp: Int32) -> StoreMessage {
        return StoreMessage(id: MessageId(peerId: chat.id, namespace: Namespaces.Message.Cloud, id: id), customStableId: nil, globallyUniqueId: nil, groupingKey: nil, threadId: nil, timestamp: timestamp, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: author.id, text: text, attributes: [], media: [])
    }

    /// A chat in the main list whose incoming messages up to `readUpTo` are read.
    private func seed(chat: Peer, author: Peer, messages: [(Int32, String)], readUpTo: Int32, startingAt baseTimestamp: Int32 = 1_700_000_000) {
        self.transaction { transaction in
            transaction.updatePeersInternal([chat, author], update: { _, updated in updated })
            transaction.updatePeerChatListInclusion(chat.id, inclusion: .ifHasMessagesOrOneOf(groupId: .root, pinningIndex: nil, minTimestamp: nil))
            let _ = transaction.addMessages(messages.enumerated().map { offset, message in
                return self.incoming(message.0, in: chat, from: author, text: message.1, timestamp: baseTimestamp + Int32(offset))
            }, location: .UpperHistoryBlock)
            let unread = Int32(messages.filter { $0.0 > readUpTo }.count)
            transaction.resetIncomingReadStates([chat.id: [Namespaces.Message.Cloud: .idBased(maxIncomingReadId: readUpTo, maxOutgoingReadId: 0, maxKnownId: messages.map { $0.0 }.max() ?? 0, count: unread, markedUnread: false)]])
        }
    }

    private func scan() -> [INMessage] {
        return self.store.first(unreadMessages(postbox: self.postbox)) ?? []
    }

    func testUnreadPrivateMessageIsFound() {
        self.seed(chat: self.alice, author: self.alice, messages: [(10, "hi"), (11, "are you there?")], readUpTo: 10)

        let messages = self.scan()

        XCTAssertEqual(messages.map { $0.content }, ["are you there?"], self.storeState([self.alice]))
        XCTAssertEqual(messages.first?.sender?.displayName, "Alice")
    }

    func testUnreadGroupMessageIsFoundWithItsGroupName() {
        self.seed(chat: self.ride, author: self.bob, messages: [(20, "leaving at 9")], readUpTo: 0)

        let messages = self.scan()

        XCTAssertEqual(messages.map { $0.content }, ["leaving at 9"], self.storeState([self.ride, self.bob]))
        XCTAssertEqual(messages.first?.sender?.displayName, "Bob")
        XCTAssertEqual(messages.first?.groupName?.spokenPhrase, "Weekend Ride")
    }

    func testUnreadChannelPostIsFound() {
        self.seed(chat: self.news, author: self.news, messages: [(30, "headline")], readUpTo: 0)

        let messages = self.scan()

        XCTAssertEqual(messages.map { $0.content }, ["headline"], self.storeState([self.news]))
        XCTAssertEqual(messages.first?.sender?.displayName, "Daily News")
    }

    func testReadChatsAreNotReported() {
        self.seed(chat: self.alice, author: self.alice, messages: [(10, "hi")], readUpTo: 10)

        XCTAssertEqual(self.scan(), [])
    }

    func testNewestUnreadComesFirstAcrossChats() {
        self.seed(chat: self.alice, author: self.alice, messages: [(10, "older")], readUpTo: 0, startingAt: 1_700_000_000)
        self.seed(chat: self.ride, author: self.bob, messages: [(20, "newer")], readUpTo: 0, startingAt: 1_700_000_100)

        XCTAssertEqual(self.scan().map { $0.content }, ["newer", "older"], self.storeState([self.alice, self.ride]))
    }

    /// The store as the scan would see it, for failure messages.
    private func storeState(_ peers: [Peer]) -> String {
        var lines: [String] = []
        self.transaction { transaction in
            for peer in peers {
                let index = transaction.getPeerChatListIndex(peer.id)
                let readState = transaction.getCombinedPeerReadState(peer.id)
                let inclusion = transaction.getPeerChatListInclusion(peer.id)
                let top = transaction.getTopPeerMessageIndex(peerId: peer.id)
                let stored = transaction.getPeer(peer.id).map { "\(type(of: $0))" } ?? "nil"
                lines.append("peer=\(peer.id) stored=\(stored) chatListIndex=\(String(describing: index)) inclusion=\(inclusion) readState=\(String(describing: readState)) top=\(String(describing: top))")
            }
        }
        let done = DispatchSemaphore(value: 0)
        let disposable = (self.postbox.tailChatListView(groupId: .root, count: 20, summaryComponents: ChatListEntrySummaryComponents()) |> take(1)).start(next: { view, _ in
            lines.append("chatList=" + view.entries.map { entry -> String in
                if case let .MessageEntry(d) = entry {
                    return "entry(\(d.index.messageIndex.id.peerId) readState=\(String(describing: d.readState)) removed=\(d.isRemovedFromTotalUnreadCount) msgs=\(d.messages.map { $0.id.id }))"
                }
                return "\(entry)"
            }.joined(separator: ", "))
            done.signal()
        })
        XCTAssertEqual(done.wait(timeout: .now() + 30.0), .success)
        disposable.dispose()
        for peer in peers {
            let historyDone = DispatchSemaphore(value: 0)
            let historyDisposable = (self.postbox.aroundMessageHistoryViewForLocation(.peer(peerId: peer.id, threadId: nil), anchor: .upperBound, ignoreMessagesInTimestampRange: nil, ignoreMessageIds: Set(), count: 10, fixedCombinedReadStates: nil, topTaggedMessageIdNamespaces: Set(), tag: nil, appendMessagesFromTheSameGroup: false, namespaces: .not(Namespaces.Message.allNonRegular), orderStatistics: .combinedLocation) |> take(1)).start(next: { view, _, _ in
                lines.append("history(\(peer.id)) isLoading=\(view.isLoading) holeEarlier=\(view.holeEarlier) holeLater=\(view.holeLater) entries=" + view.entries.map { entry -> String in
                    let message = entry.message
                    return "[\(message.id.id) author=\(String(describing: message.author?.id)) authorType=\(message.author.map { "\(type(of: $0))" } ?? "nil") peers=\(message.peers.count) text=\(message.text) converted=\(messageWithTelegramMessage(message) != nil)]"
                }.joined(separator: " "))
                historyDone.signal()
            })
            XCTAssertEqual(historyDone.wait(timeout: .now() + 30.0), .success)
            historyDisposable.dispose()
        }
        return lines.joined(separator: "\n")
    }
}
