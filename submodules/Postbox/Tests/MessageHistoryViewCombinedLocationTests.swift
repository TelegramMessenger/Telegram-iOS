import Foundation
import XCTest
import SwiftSignalKit
@testable import Postbox

/// `orderStatistics: .combinedLocation` gives every entry its place among the view's messages
/// (the media gallery's "N of M"). A channel migrated from a basic group shows both histories
/// in one `.associated` view, so the numbering must run across both peers rather than restart
/// in each.
final class MessageHistoryViewCombinedLocationTests: XCTestCase {
    private var fixture: PostboxFixture!

    private let tag = MessageTags(rawValue: 1 << 0)
    private let channel = FixturePeer(id: MessageHistoryTableFixture.peerId(600), title: "channel")
    private let group = FixturePeer(id: MessageHistoryTableFixture.peerId(601), title: "group")
    private let otherNamespace: MessageId.Namespace = 1

    override func setUp() {
        super.setUp()
        self.fixture = PostboxFixture(name: "MessageHistoryViewCombinedLocationTests")
        self.fixture.transaction { transaction in
            transaction.updatePeersInternal([self.channel, self.group], update: { _, updated in updated })
        }
    }

    override func tearDown() {
        self.fixture.close()
        self.fixture = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func store(_ peer: FixturePeer, namespace: MessageId.Namespace = PostboxFixture.messageNamespace, ids: [Int32], timestamps: [Int32]) {
        self.fixture.transaction { transaction in
            let messages = zip(ids, timestamps).map { id, timestamp in
                MessageHistoryTableFixture.storeMessage(id: MessageId(peerId: peer.id, namespace: namespace, id: id), timestamp: timestamp, tags: self.tag)
            }
            let _ = transaction.addMessages(messages, location: .Random)
        }
    }

    private func migrateChannel(lastGroupMessage: MessageId) {
        self.fixture.transaction { transaction in
            transaction.updatePeerCachedData(peerIds: [self.channel.id], update: { _, _ in FixtureCachedPeerData(peerIds: [], associatedHistoryMessageId: lastGroupMessage) })
        }
    }

    /// The tagged history of the channel, as the gallery opens it, kept live.
    private func observeChannelHistory() -> PostboxFixture.Recorder<MessageHistoryView> {
        let signal = self.fixture.postbox.aroundMessageHistoryViewForLocation(.peer(peerId: self.channel.id, threadId: nil), anchor: .upperBound, ignoreMessagesInTimestampRange: nil, ignoreMessageIds: [], count: 20, fixedCombinedReadStates: nil, topTaggedMessageIdNamespaces: [], tag: .tag(self.tag), appendMessagesFromTheSameGroup: false, namespaces: .all, orderStatistics: .combinedLocation)
        return self.fixture.observe(signal |> map { $0.0 })
    }

    /// A view's entries, oldest first: each entry's message id and its "index of count".
    private func describe(_ view: MessageHistoryView?) -> [String] {
        return (view?.entries ?? []).map { entry in
            let peer = entry.message.id.peerId == self.channel.id ? "channel" : "group"
            let location = entry.location.map { "\($0.index) of \($0.count)" } ?? "none"
            return "\(peer) \(entry.message.id.namespace):\(entry.message.id.id) \(location)"
        }
    }

    private func locations() -> [String] {
        return self.describe(self.observeChannelHistory().waitForValues(count: 1).last)
    }

    private func delete(_ peer: FixturePeer, _ id: Int32) {
        self.fixture.transaction { transaction in
            transaction.deleteMessages([MessageId(peerId: peer.id, namespace: PostboxFixture.messageNamespace, id: id)], forEachMedia: nil)
        }
    }

    private func storeMigratedHistory() {
        self.store(self.group, ids: [1, 2, 3], timestamps: [100, 200, 300])
        self.store(self.channel, ids: [1, 2], timestamps: [1000, 2000])
        self.migrateChannel(lastGroupMessage: MessageId(peerId: self.group.id, namespace: PostboxFixture.messageNamespace, id: 3))
    }

    // MARK: - Tests

    func testMigratedChannelNumbersBothHistoriesInOneSequence() {
        self.storeMigratedHistory()

        XCTAssertEqual(self.locations(), [
            "group 0:1 0 of 5",
            "group 0:2 1 of 5",
            "group 0:3 2 of 5",
            "channel 0:1 3 of 5",
            "channel 0:2 4 of 5"
        ])
    }

    func testRemovingAChannelMessageRenumbersTheGroupsMessages() {
        // A removal refills only the space it happened in; the other peer's entries must follow.
        self.storeMigratedHistory()
        let recorder = self.observeChannelHistory()
        recorder.waitForValues(count: 1)

        self.delete(self.channel, 2)

        XCTAssertEqual(self.describe(recorder.waitForValues(count: 2).last), [
            "group 0:1 0 of 4",
            "group 0:2 1 of 4",
            "group 0:3 2 of 4",
            "channel 0:1 3 of 4"
        ])
    }

    func testRemovingAGroupMessageRenumbersTheChannelsMessages() {
        self.storeMigratedHistory()
        let recorder = self.observeChannelHistory()
        recorder.waitForValues(count: 1)

        self.delete(self.group, 1)

        XCTAssertEqual(self.describe(recorder.waitForValues(count: 2).last), [
            "group 0:2 0 of 4",
            "group 0:3 1 of 4",
            "channel 0:1 2 of 4",
            "channel 0:2 3 of 4"
        ])
    }

    func testAHoleBelowTheChannelsStoredMessagesKeepsTheGroupOutOfTheWindow() {
        // The shared-media list counts a channel's stored media as its full length once its
        // `.associated` window reaches a group message. That is only sound because a hole below the
        // channel's stored messages clips every older entry, the group's included, out of the window.
        self.store(self.group, ids: [1, 2, 3], timestamps: [100, 200, 300])
        self.store(self.channel, ids: [10, 11], timestamps: [1000, 1100])
        self.fixture.transaction { transaction in
            transaction.addHole(peerId: self.channel.id, threadId: nil, namespace: PostboxFixture.messageNamespace, space: .tag(self.tag), range: 1 ... 9)
        }
        self.migrateChannel(lastGroupMessage: MessageId(peerId: self.group.id, namespace: PostboxFixture.messageNamespace, id: 3))

        XCTAssertEqual(self.locations().map { $0.components(separatedBy: " ").prefix(2).joined(separator: " ") }, [
            "channel 0:10",
            "channel 0:11"
        ])
    }

    func testChannelWithoutAGroupNumbersOnlyItsOwnMessages() {
        self.store(self.group, ids: [1, 2, 3], timestamps: [100, 200, 300])
        self.store(self.channel, ids: [1, 2], timestamps: [1000, 2000])

        XCTAssertEqual(self.locations(), [
            "channel 0:1 0 of 2",
            "channel 0:2 1 of 2"
        ])
    }

    func testOnePeersNamespacesKeepTheirOwnNumbering() {
        // Only other peers are added in; a single peer's view stays exactly as it was.
        self.store(self.channel, ids: [1, 2], timestamps: [1000, 2000])
        self.store(self.channel, namespace: self.otherNamespace, ids: [1], timestamps: [1500])

        XCTAssertEqual(self.locations(), [
            "channel 0:1 0 of 2",
            "channel 1:1 0 of 1",
            "channel 0:2 1 of 2"
        ])
    }
}
