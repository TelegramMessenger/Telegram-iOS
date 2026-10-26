import Foundation
import XCTest
import SwiftSignalKit
@testable import Postbox

/// TelegramCore gives a channel the account is not a member of a fixed read state
/// (`nonMemberChannelReadState`, TelegramCore `Sources/State/NonMemberChannelReadState.swift`): nothing
/// unread and nothing ever counted, with the incoming read mark left at 0 so the server's state replaces it
/// when the account joins. These tests pin what Postbox does with that state, beside the reset TelegramCore
/// installed before (which members outside the chat list still get). TelegramCore's
/// `NonMemberChannelReadStateTests` pins that its constant is `nonMemberState` below.
final class NonMemberChannelReadStateTests: XCTestCase {
    private var fixture: PostboxFixture!

    private let channel = FixturePeer(id: MessageHistoryTableFixture.peerId(910), title: "channel")
    private let namespace = PostboxFixture.messageNamespace

    /// Keep in step with TelegramCore's `nonMemberChannelReadState`.
    private let nonMemberState: PeerReadState = .idBased(maxIncomingReadId: 0, maxOutgoingReadId: 1, maxKnownId: Int32.max - 1, count: 0, markedUnread: false)
    /// The reset TelegramCore installed on every opening of a channel outside the chat list before.
    private let legacyResetState: PeerReadState = .idBased(maxIncomingReadId: 1, maxOutgoingReadId: 1, maxKnownId: 1, count: 0, markedUnread: false)

    override func setUp() {
        super.setUp()
        self.fixture = PostboxFixture(name: "NonMemberChannelReadStateTests")
    }

    override func tearDown() {
        self.fixture.close()
        self.fixture = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func message(_ id: Int32) -> StoreMessage {
        return StoreMessage(id: MessageId(peerId: self.channel.id, namespace: self.namespace, id: id), customStableId: nil, globallyUniqueId: nil, groupingKey: nil, threadId: nil, timestamp: 1000 + id, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: nil, text: "post \(id)", attributes: [], media: [])
    }

    private func install(_ state: PeerReadState) {
        self.fixture.transaction { transaction in
            transaction.updatePeersInternal([self.channel], update: { _, updated in updated })
            transaction.resetIncomingReadStates([self.channel.id: [self.namespace: state]])
        }
    }

    private func store(_ ids: ClosedRange<Int32>, location: AddMessagesLocation) {
        self.fixture.transaction { transaction in
            let _ = transaction.addMessages(ids.map(self.message), location: location)
        }
    }

    private func readState() -> PeerReadState? {
        return self.fixture.transaction { transaction -> PeerReadState? in
            return transaction.getPeerReadStates(self.channel.id)?.first(where: { $0.0 == self.namespace })?.1
        } ?? nil
    }

    private func unreadCount() -> Int32? {
        return self.fixture.transaction { transaction -> Int32? in
            return transaction.getCombinedPeerReadState(self.channel.id)?.count
        } ?? nil
    }

    private func openHistoryWithoutHoles() -> MessageHistoryView {
        self.fixture.transaction { transaction in
            transaction.removeHole(peerId: self.channel.id, threadId: nil, namespace: self.namespace, space: .everywhere, range: 1 ... (Int32.max - 1))
        }
        return self.fixture.observeHistory(peerId: self.channel.id, additionalData: []).waitForValues(count: 1).last!
    }

    // MARK: - Counting

    /// A hole fill (`.Random`) and a poll's new posts (`.UpperHistoryBlock`) both store incoming posts.
    func testPostsStoredAfterTheNonMemberStateAreNotCounted() {
        self.install(self.nonMemberState)
        self.store(2 ... 6, location: .Random)
        self.store(7 ... 9, location: .UpperHistoryBlock)
        XCTAssertEqual(self.unreadCount(), 0)
    }

    /// Why the state changes: the old reset counts every incoming post stored after it, which put a count
    /// on a non-member channel's scroll-down button.
    func testPostsStoredAfterTheLegacyResetAreCounted() {
        self.install(self.legacyResetState)
        self.store(2 ... 6, location: .Random)
        self.store(7 ... 9, location: .UpperHistoryBlock)
        XCTAssertEqual(self.unreadCount(), 8)
    }

    // MARK: - The history view

    func testAHistoryViewOverTheNonMemberStateHasNoReadIndex() {
        self.install(self.nonMemberState)
        self.store(2 ... 6, location: .Random)
        let view = self.openHistoryWithoutHoles()
        XCTAssertEqual(view.entries.count, 5)
        XCTAssertNil(view.maxReadIndex)
    }

    /// The old reset with posts counted gives the view a read index; the chat then hid its separator only
    /// because the index fell before the first entry.
    func testAHistoryViewOverTheLegacyResetHasAReadIndex() {
        self.install(self.legacyResetState)
        self.store(2 ... 6, location: .Random)
        let view = self.openHistoryWithoutHoles()
        XCTAssertEqual(view.entries.count, 5)
        XCTAssertNotNil(view.maxReadIndex)
    }

    // MARK: - Reading and joining

    /// What TelegramCore's guards are for: Postbox itself moves the read mark and schedules a push for this
    /// state, which the synchronizer would send as `channels.readHistory` for a channel the server keeps no
    /// read state for.
    func testAnInteractiveReadOnTheNonMemberStateSchedulesAPush() {
        self.install(self.nonMemberState)
        self.store(2 ... 4, location: .Random)
        let operations = self.fixture.observe(self.fixture.postbox.synchronizePeerReadStatesView() |> map { $0.operations })
        XCTAssertNil(operations.waitForValues(count: 1).last?[self.channel.id])

        self.fixture.transaction { transaction in
            let _ = transaction.applyInteractiveReadMaxIndex(MessageIndex(id: MessageId(peerId: self.channel.id, namespace: self.namespace, id: 4), timestamp: 1004))
        }

        guard let operation = operations.waitForValues(count: 2).last?[self.channel.id], case .Push = operation else {
            XCTFail("expected a push to be scheduled")
            return
        }
    }

    /// Joining: the server's state replaces the non-member state exactly, and posts above its known id count
    /// again. A join can report nothing read with some unread (mark 0). (TelegramCore's replay keeps a local
    /// read mark that is ahead of the server's; this state's mark of 0 never is.)
    func testAServerResetReplacesTheNonMemberState() {
        self.install(self.nonMemberState)
        self.store(2 ... 6, location: .Random)
        let server: PeerReadState = .idBased(maxIncomingReadId: 0, maxOutgoingReadId: 0, maxKnownId: 6, count: 5, markedUnread: false)
        self.fixture.transaction { transaction in
            transaction.resetIncomingReadStates([self.channel.id: [self.namespace: server]])
        }
        XCTAssertEqual(self.readState(), server)

        self.store(7 ... 7, location: .UpperHistoryBlock)
        XCTAssertEqual(self.unreadCount(), 6)
    }
}
