import XCTest
import Postbox
import TelegramApi
@testable import TelegramCore

final class NonMemberChannelReadStateTests: XCTestCase {
    private func channel(_ participationStatus: TelegramChannelParticipationStatus, isBroadcast: Bool = true, flags: TelegramChannelFlags = []) -> TelegramChannel {
        let info: TelegramChannelInfo = isBroadcast ? .broadcast(TelegramChannelBroadcastInfo(flags: [])) : .group(TelegramChannelGroupInfo(flags: []))
        return TelegramChannel(id: PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(1234)), accessHash: nil, title: "Channel", username: nil, photo: [], creationDate: 0, version: 0, participationStatus: participationStatus, info: info, flags: flags, restrictionInfo: nil, adminRights: nil, bannedRights: nil, defaultBannedRights: nil, usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, emojiStatus: nil, approximateBoostLevel: nil, subscriptionUntilDate: nil, verificationIconFileId: nil, sendPaidMessageStars: nil, linkedMonoforumId: nil)
    }

    private let legacyReset: PeerReadState = .idBased(maxIncomingReadId: 1, maxOutgoingReadId: 1, maxKnownId: 1, count: 0, markedUnread: false)

    // MARK: - The rule

    func testAMemberChannelKeepsReadState() {
        XCTAssertTrue(peerKeepsReadState(self.channel(.member)))
    }

    /// For You channels and channels added only to News (a light join) are both `.left`.
    func testALeftChannelHasNoReadState() {
        XCTAssertFalse(peerKeepsReadState(self.channel(.left)))
    }

    func testAKickedChannelHasNoReadState() {
        XCTAssertFalse(peerKeepsReadState(self.channel(.kicked)))
    }

    func testALeftSupergroupHasNoReadState() {
        XCTAssertFalse(peerKeepsReadState(self.channel(.left, isBroadcast: false)))
        XCTAssertTrue(peerKeepsReadState(self.channel(.member, isBroadcast: false)))
    }

    /// Basic groups (and users, secret chats) are not channels: unaffected even when left.
    func testOtherPeerKindsKeepReadState() {
        let group = TelegramGroup(id: PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(1)), title: "G", photo: [], participantCount: 1, role: .member, membership: .Left, flags: [], defaultBannedRights: nil, migrationReference: nil, creationDate: 0, version: 0)
        XCTAssertTrue(peerKeepsReadState(group))
    }

    /// A monoforum is a user's direct messages with a channel: its replies and read receipts matter whatever
    /// the participation status says.
    func testAMonoforumKeepsReadState() {
        XCTAssertTrue(peerKeepsReadState(self.channel(.left, isBroadcast: false, flags: [.isMonoforum])))
    }

    func testAPeerThatIsNotStoredKeepsReadState() {
        XCTAssertTrue(peerKeepsReadState(nil))
    }

    // MARK: - The state

    /// Postbox's `NonMemberChannelReadStateTests` pins what Postbox does with exactly this value.
    func testTheNonMemberStateIsThePostboxTestsLiteral() {
        XCTAssertEqual(nonMemberChannelReadState, .idBased(maxIncomingReadId: 0, maxOutgoingReadId: 1, maxKnownId: Int32.max - 1, count: 0, markedUnread: false))
    }

    // MARK: - Opening

    func testOpeningANonMemberChannelInstallsTheNonMemberState() {
        XCTAssertEqual(channelReadStateOnOpenOutsideChatList(peer: self.channel(.left)), nonMemberChannelReadState)
        XCTAssertEqual(channelReadStateOnOpenOutsideChatList(peer: self.channel(.kicked)), nonMemberChannelReadState)
    }

    func testOpeningAMemberOutsideTheChatListKeepsTodaysReset() {
        XCTAssertEqual(channelReadStateOnOpenOutsideChatList(peer: self.channel(.member)), self.legacyReset)
        XCTAssertEqual(channelReadStateOnOpenOutsideChatList(peer: nil), self.legacyReset)
    }

    // MARK: - Server read-state operations (R3)

    private var channelId: PeerId {
        return PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(1234))
    }

    private func readStateOperations() -> [AccountStateMutationOperation] {
        return [
            .ReadInbox(MessageId(peerId: self.channelId, namespace: Namespaces.Message.Cloud, id: 5)),
            .ResetReadState(peerId: self.channelId, namespace: Namespaces.Message.Cloud, maxIncomingReadId: 5, maxOutgoingReadId: 0, maxKnownId: 5, count: 1, markedUnread: nil),
            .ResetIncomingReadState(groupId: .root, peerId: self.channelId, namespace: Namespaces.Message.Cloud, maxIncomingReadId: 5, count: 0, pts: 1),
            .UpdatePeerChatUnreadMark(self.channelId, nil, Namespaces.Message.Cloud, true)
        ]
    }

    func testServerWritesForANonMemberAreSkipped() {
        let left = self.channel(.left)
        for operation in self.readStateOperations() {
            XCTAssertTrue(readStateOperationTargetsNonMember(operation, getPeer: { _ in left }), "\(operation)")
        }
    }

    /// Joining: the dialog fetch's reset is replayed after the channel's merge, so the stored channel is
    /// already a member when the reset is judged.
    func testServerWritesForAMemberAreApplied() {
        let member = self.channel(.member)
        for operation in self.readStateOperations() {
            XCTAssertFalse(readStateOperationTargetsNonMember(operation, getPeer: { _ in member }), "\(operation)")
        }
    }

    /// Forum topics and comment threads keep their own read marks.
    func testAThreadUnreadMarkIsNeverSkipped() {
        let left = self.channel(.left)
        XCTAssertFalse(readStateOperationTargetsNonMember(.UpdatePeerChatUnreadMark(self.channelId, 7, Namespaces.Message.Cloud, true), getPeer: { _ in left }))
    }

    func testOtherOperationsAreNeverSkipped() {
        let left = self.channel(.left)
        XCTAssertFalse(readStateOperationTargetsNonMember(.ReadOutbox(MessageId(peerId: self.channelId, namespace: Namespaces.Message.Cloud, id: 5), nil), getPeer: { _ in left }))
        XCTAssertFalse(readStateOperationTargetsNonMember(.UpdatePeerChatInclusion(peerId: self.channelId, groupId: .root, changedGroup: false), getPeer: { _ in left }))
        XCTAssertFalse(readStateOperationTargetsNonMember(.UpdateIsContact(self.channelId, true), getPeer: { _ in left }))
    }

    // MARK: - Joining

    /// Opening the chat stored the channel's notification settings, so the join builds chat info from them
    /// and fetches no dialog: the stored channel that just became a member must ask for its read state.
    func testJoiningAStoredNonMemberChannelAsksForTheServersReadState() {
        XCTAssertTrue(channelJoinNeedsServerReadState(previous: self.channel(.left), updated: self.channel(.member)))
        XCTAssertTrue(channelJoinNeedsServerReadState(previous: self.channel(.kicked), updated: self.channel(.member)))
        XCTAssertTrue(channelJoinNeedsServerReadState(previous: self.channel(.left, isBroadcast: false), updated: self.channel(.member, isBroadcast: false)))
    }

    func testOtherMembershipChangesDoNotAsk() {
        XCTAssertFalse(channelJoinNeedsServerReadState(previous: nil, updated: self.channel(.member)))
        XCTAssertFalse(channelJoinNeedsServerReadState(previous: self.channel(.member), updated: self.channel(.member)))
        XCTAssertFalse(channelJoinNeedsServerReadState(previous: self.channel(.member), updated: self.channel(.left)))
        XCTAssertFalse(channelJoinNeedsServerReadState(previous: self.channel(.left), updated: self.channel(.left)))
        let group = TelegramGroup(id: PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(1)), title: "G", photo: [], participantCount: 1, role: .member, membership: .Member, flags: [], defaultBannedRights: nil, migrationReference: nil, creationDate: 0, version: 0)
        XCTAssertFalse(channelJoinNeedsServerReadState(previous: group, updated: group))
    }

    // MARK: - The server's read mark

    /// The local mark is below any server mark, 0 included, so neither the replay nor validation keeps the
    /// non-member state over the server's. A join reporting nothing read and some unread would otherwise be
    /// refused, and validation would retry it without end.
    func testTheNonMemberStateIsNeverAheadOfTheServer() {
        guard case let .idBased(localMark, _, _, _, _) = nonMemberChannelReadState else {
            XCTFail("not id-based")
            return
        }
        for serverMark: Int32 in [0, 1, 1000] {
            XCTAssertFalse(localReadMarkIsAheadOfServer(localMaxIncomingReadId: localMark, serverMaxIncomingReadId: serverMark, serverCount: 3, serverMarkedUnread: false), "server mark \(serverMark)")
            XCTAssertFalse(localReadMarkIsAheadOfServer(localMaxIncomingReadId: localMark, serverMaxIncomingReadId: serverMark, serverCount: 0, serverMarkedUnread: true), "server mark \(serverMark), marked unread")
        }
    }

    /// The rule both sites share: a local mark ahead of a server that still reports something unread is kept.
    func testALocalMarkAheadOfAServerWithUnreadIsKept() {
        XCTAssertTrue(localReadMarkIsAheadOfServer(localMaxIncomingReadId: 5, serverMaxIncomingReadId: 0, serverCount: 3, serverMarkedUnread: false))
        XCTAssertTrue(localReadMarkIsAheadOfServer(localMaxIncomingReadId: 5, serverMaxIncomingReadId: 0, serverCount: 0, serverMarkedUnread: true))
        XCTAssertFalse(localReadMarkIsAheadOfServer(localMaxIncomingReadId: 5, serverMaxIncomingReadId: 0, serverCount: 0, serverMarkedUnread: false))
        XCTAssertFalse(localReadMarkIsAheadOfServer(localMaxIncomingReadId: 5, serverMaxIncomingReadId: 5, serverCount: 3, serverMarkedUnread: false))
    }

    // MARK: - The replay's read marks for topic counting

    func testTheReplaysReadMarksLeaveOutNonMembers() {
        let left = self.channel(.left)
        let member = self.channel(.member)
        let otherId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(99))
        let operations: [AccountStateMutationOperation] = [
            .ReadInbox(MessageId(peerId: self.channelId, namespace: Namespaces.Message.Cloud, id: 5)),
            .ResetReadState(peerId: otherId, namespace: Namespaces.Message.Cloud, maxIncomingReadId: 7, maxOutgoingReadId: 0, maxKnownId: 7, count: 0, markedUnread: nil),
            .ReadInbox(MessageId(peerId: otherId, namespace: Namespaces.Message.Cloud, id: 9)),
            .ResetIncomingReadState(groupId: .root, peerId: otherId, namespace: Namespaces.Message.Cloud, maxIncomingReadId: 8, count: 0, pts: 1)
        ]
        let marks = cloudReadInboxMarks(operations, getPeer: { $0 == self.channelId ? left : member })
        XCTAssertNil(marks[self.channelId])
        XCTAssertEqual(marks[otherId], 9)
    }

    func testTheReplaysReadMarksCountCloudMessagesOnly() {
        let member = self.channel(.member)
        let marks = cloudReadInboxMarks([.ReadInbox(MessageId(peerId: self.channelId, namespace: Namespaces.Message.Local, id: 5))], getPeer: { _ in member })
        XCTAssertTrue(marks.isEmpty)
    }

    // MARK: - Dialogs fetched for chat folders

    private func apiChannel(left: Bool) -> Api.Chat {
        var flags: Int32 = 1 << 5 // broadcast
        if left {
            flags |= 1 << 2
        }
        return Api.Chat.channel(.init(flags: flags, flags2: 0, id: 1234, accessHash: 5678, title: "Channel", username: nil, photo: .chatPhotoEmpty, date: 0, restrictionReason: nil, adminRights: nil, bannedRights: nil, defaultBannedRights: nil, participantsCount: nil, usernames: nil, storiesMaxId: nil, color: nil, profileColor: nil, emojiStatus: nil, level: nil, subscriptionUntilDate: nil, botVerificationIcon: nil, sendPaidMessagesStars: nil, linkedMonoforumId: nil, linkedCommunityId: nil, pinnedMsgId: nil))
    }

    func testAFolderDialogsReadStateIsSkippedForANonMember() {
        XCTAssertFalse(dialogReadStateIsKept(peerId: self.channelId, responseChats: [self.apiChannel(left: true)], storedPeer: self.channel(.member)))
    }

    /// The response is newer than the stored channel: a channel joined since keeps the server's state.
    func testAFolderDialogsReadStateIsKeptForAMember() {
        XCTAssertTrue(dialogReadStateIsKept(peerId: self.channelId, responseChats: [self.apiChannel(left: false)], storedPeer: self.channel(.left)))
    }

    func testAFolderDialogWithoutItsChatFallsBackToTheStoredPeer() {
        XCTAssertFalse(dialogReadStateIsKept(peerId: self.channelId, responseChats: [], storedPeer: self.channel(.left)))
        XCTAssertTrue(dialogReadStateIsKept(peerId: self.channelId, responseChats: [], storedPeer: nil))
    }
}
