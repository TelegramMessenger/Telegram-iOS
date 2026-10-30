import Foundation
import XCTest
import SwiftSignalKit
import Postbox
@testable import TelegramCore

/// Marking a whole chat read from the chat list (`_internal_readPeerHistoryToTopInteractively`, behind the swipe and
/// "Mark as Read") reads up to the server's newest message, which the read state holds as `maxKnownId`, also when this
/// device never stored that message. Pushed as `channels.readHistory(max_id:)` / `messages.readHistory(max_id:)`, a
/// mark short of it left that message unread on the server, which answered with it still unread
/// (`updateReadChannelInbox` with `still_unread_count`, or the validation the push ran): the chat came back unread.
/// Driven over the harness's Postbox, without a state manager.
final class ChatListMarkReadTests: StateSyncTestCase {
    private let channel = StateSyncFixture.channelPeerId(400)
    private let user = StateSyncFixture.userPeerId(401)

    private func seedChannel(participationStatus: TelegramChannelParticipationStatus = .member) {
        self.fixture.seedChannel(StateSyncFixture.makeChannel(id: self.channel, accessHash: 1, title: "SPL", participationStatus: participationStatus), state: ChannelState(pts: 50, invalidatedPts: nil, synchronizedUntilMessageId: nil))
        self.fixture.seedChat(peerId: self.channel)
    }

    private func storeMessages(peerId: PeerId, ids: ClosedRange<Int32>) {
        for id in ids {
            self.fixture.storeMessage(peerId: peerId, id: id, timestamp: self.baseDate + id, authorId: nil, text: "m\(id)")
        }
    }

    private func markRead(peerId: PeerId) {
        self.fixture.transaction { transaction -> Void in
            guard let peer = transaction.getPeer(peerId) else {
                XCTFail("no peer")
                return
            }
            _internal_readPeerHistoryToTopInteractively(transaction: transaction, peer: peer, principalNamespace: Namespaces.Message.Cloud)
        }
    }

    private func cloudReadState(_ peerId: PeerId) -> PeerReadState? {
        return self.fixture.transaction { transaction -> PeerReadState? in
            return transaction.getPeerReadStates(peerId)?.first(where: { $0.0 == Namespaces.Message.Cloud })?.1
        } ?? nil
    }

    private func scheduledOperation(_ peerId: PeerId) -> PeerReadStateSynchronizationOperation? {
        return self.fixture.wait(self.fixture.postbox.synchronizePeerReadStatesView() |> map { $0.operations[peerId] }) ?? nil
    }

    /// Issue #98's chat: one unread post, the server's newest (10), which this device never stored; it stored up to 9,
    /// all read. Reading up to 9 left 10 unread on the server, and the chat came back with its "1".
    func testTheServersNewestMessageThatWasNeverStoredIsRead() {
        self.seedChannel()
        self.storeMessages(peerId: self.channel, ids: 1 ... 9)
        self.fixture.seedReadState(peerId: self.channel, maxIncomingReadId: 9, maxOutgoingReadId: 0, maxKnownId: 10, count: 1)

        self.markRead(peerId: self.channel)

        XCTAssertEqual(self.cloudReadState(self.channel), .idBased(maxIncomingReadId: 10, maxOutgoingReadId: 0, maxKnownId: 10, count: 0, markedUnread: false))
        guard case .Push? = self.scheduledOperation(self.channel) else {
            XCTFail("no push scheduled: \(String(describing: self.scheduledOperation(self.channel)))")
            return
        }
    }

    /// Stored unread messages and newer ones never stored: all of them are read, and the count clears at once.
    func testStoredAndUnstoredUnreadMessagesAreAllRead() {
        self.seedChannel()
        self.storeMessages(peerId: self.channel, ids: 1 ... 9)
        self.fixture.seedReadState(peerId: self.channel, maxIncomingReadId: 6, maxOutgoingReadId: 0, maxKnownId: 12, count: 6)

        self.markRead(peerId: self.channel)

        XCTAssertEqual(self.cloudReadState(self.channel), .idBased(maxIncomingReadId: 12, maxOutgoingReadId: 0, maxKnownId: 12, count: 0, markedUnread: false))
    }

    /// The usual case, the server's newest message stored here: read up to it, as before.
    func testTheNewestStoredMessageIsReadWhenItIsTheServersNewest() {
        self.seedChannel()
        self.storeMessages(peerId: self.channel, ids: 1 ... 9)
        self.fixture.seedReadState(peerId: self.channel, maxIncomingReadId: 6, maxOutgoingReadId: 0, maxKnownId: 9, count: 3)

        self.markRead(peerId: self.channel)

        XCTAssertEqual(self.cloudReadState(self.channel), .idBased(maxIncomingReadId: 9, maxOutgoingReadId: 0, maxKnownId: 9, count: 0, markedUnread: false))
    }

    /// Messages that arrived after the server last reported the dialog are above `maxKnownId`; the newest stored one
    /// is the top.
    func testMessagesNewerThanTheServersLastReportAreReadToTheNewestStored() {
        self.seedChannel()
        self.storeMessages(peerId: self.channel, ids: 1 ... 5)
        self.fixture.seedReadState(peerId: self.channel, maxIncomingReadId: 5, maxOutgoingReadId: 0, maxKnownId: 5, count: 0)
        self.storeMessages(peerId: self.channel, ids: 6 ... 8)
        XCTAssertEqual(self.cloudReadState(self.channel)?.count, 3)

        self.markRead(peerId: self.channel)

        XCTAssertEqual(self.cloudReadState(self.channel), .idBased(maxIncomingReadId: 8, maxOutgoingReadId: 0, maxKnownId: 5, count: 0, markedUnread: false))
    }

    /// A private chat's read state is id-based too: `messages.readHistory` gets the dialog's newest message.
    func testAPrivateChatIsReadToTheServersNewestMessage() {
        self.fixture.seedPeers([StateSyncFixture.makeUser(id: self.user, firstName: "U")])
        self.fixture.seedChat(peerId: self.user)
        self.storeMessages(peerId: self.user, ids: 1 ... 4)
        self.fixture.seedReadState(peerId: self.user, maxIncomingReadId: 4, maxOutgoingReadId: 0, maxKnownId: 7, count: 2)

        self.markRead(peerId: self.user)

        XCTAssertEqual(self.cloudReadState(self.user), .idBased(maxIncomingReadId: 7, maxOutgoingReadId: 0, maxKnownId: 7, count: 0, markedUnread: false))
    }

    /// A channel the account is not a member of holds `nonMemberChannelReadState`, whose `maxKnownId` (`Int32.max - 1`)
    /// is "everything", not a message: it is never read up to.
    func testANonMemberChannelIsNeverReadToItsPlaceholderMaxKnownId() {
        self.seedChannel(participationStatus: .left)
        self.storeMessages(peerId: self.channel, ids: 1 ... 9)
        self.fixture.transaction { transaction -> Void in
            transaction.resetIncomingReadStates([self.channel: [Namespaces.Message.Cloud: nonMemberChannelReadState]])
        }

        self.markRead(peerId: self.channel)

        guard case let .idBased(maxIncomingReadId, _, _, count, _)? = self.cloudReadState(self.channel) else {
            XCTFail("no id-based read state")
            return
        }
        XCTAssertLessThanOrEqual(maxIncomingReadId, 9)
        XCTAssertEqual(count, 0)
    }

    /// A read mark already past the newest stored message is never moved back.
    func testAMarkPastTheNewestStoredMessageStays() {
        self.seedChannel()
        self.storeMessages(peerId: self.channel, ids: 1 ... 9)
        self.fixture.seedReadState(peerId: self.channel, maxIncomingReadId: 11, maxOutgoingReadId: 0, maxKnownId: 10, count: 1)

        self.markRead(peerId: self.channel)

        XCTAssertEqual(self.cloudReadState(self.channel), .idBased(maxIncomingReadId: 11, maxOutgoingReadId: 0, maxKnownId: 10, count: 0, markedUnread: false))
    }
}
