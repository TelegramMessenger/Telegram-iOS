import Foundation
import XCTest
import SwiftSignalKit
import Postbox
import TelegramApi
@testable import TelegramCore

/// The ghost tail of the archived dialogs a `.general` chat-list page brings along (followups, "Archived dialogs
/// cleared elsewhere"). A root page that references the archive makes `fetchChatList` fetch the archive's first page
/// too (a second `messages.getDialogs`, folder_id 1, sent once the root page and the pinned chats have answered), and
/// its dialogs are listed only in `peerGroupIds`. Until the fix their `top_message` was not merged into
/// `topMessageIds` and the top-0 rule of `storedCloudMessagesAboveTopMessages` looped over `chatPeerIds` alone, so an
/// archived dialog that came back with `top_message == 0` (its history cleared on another device, the chat kept) kept
/// its stale history, its cleared last message as the preview, until the archive's own page was fetched. Only the
/// account reset deletes a ghost tail (spec section 3 point 3, as amended 2026-10-24); the chat-list hole fill leaves
/// it.
final class ArchivedDialogGhostTailTests: StateSyncTestCase {
    /// The root list's first hole, at a `Namespaces.Peer.Empty` index, as the seed configuration and the reset add it.
    private let rootHole = ChatListHole(index: MessageIndex(id: MessageId(peerId: PeerId(namespace: Namespaces.Peer.Empty, id: PeerId.Id._internalFromInt64Value(0)), namespace: Namespaces.Message.Cloud, id: 1), timestamp: Int32.max - 1))

    /// `dialogFolder#71bd134c` for the archive (folder 1). `parseDialogs` reads only the folder's id and its muted
    /// counters; `peer` is a chat in the folder.
    private func archiveFolderDialog(peer: Api.Peer) -> Api.Dialog {
        return .dialogFolder(.init(flags: 0, folder: .folder(.init(flags: 0, id: 1, title: "Archived Chats", photo: nil)), peer: peer, topMessage: 0, unreadMutedPeersCount: 0, unreadUnmutedPeersCount: 0, unreadMutedMessagesCount: 0, unreadUnmutedMessagesCount: 0))
    }

    /// A root page whose only entry is the archive, so `fetchChatList` also fetches the archive's first page.
    private func rootPageReferencingTheArchive(peer: Api.Peer) -> Api.messages.Dialogs {
        return StateSyncApi.dialogs(dialogs: [self.archiveFolderDialog(peer: peer)])
    }

    /// The messages.getPinnedDialogs answer: no pinned chats.
    private func emptyPinnedDialogs() -> Api.messages.PeerDialogs {
        return StateSyncApi.peerDialogs(state: StateSyncApi.state(pts: 999, qts: 5, date: self.baseDate, seq: 10))
    }

    /// Builds the manager and starts a poll cycle that resets the account, as `startAccountReset` does, with two
    /// chat-list pages: `root` answers the reset's messages.getDialogs and `archive` the archive's, which
    /// `fetchChatList` sends only after the root page has answered, so the two one-shot answers are used in that
    /// order. (`startAccountReset` registers one page and starts at once: an archive answer registered after it
    /// could arrive late, and one registered before it would answer the root request.)
    private func startAccountResetWithArchive(root: Api.messages.Dialogs, archive: Api.messages.Dialogs) {
        self.makeStateManager()
        self.server.on(Name.getDifference, .result(StateSyncApi.differenceTooLong(pts: 999)))
        self.server.on(Name.getDialogs, .result(root))
        self.server.on(Name.getDialogs, .result(archive))
        self.server.on(Name.getPinnedDialogs, .result(self.emptyPinnedDialogs()))
        self.server.on(Name.getDifference, .result(StateSyncApi.differenceEmpty(date: self.baseDate + 120, seq: 10)))
        self.fixture.resetStateManager()
    }

    /// An archived dialog whose top_message is 0 has top 0: the reset's transaction deletes both of its stored
    /// messages, asking nothing. The other archived dialog, whose top message (12) the archive's page carries, is
    /// unaffected: nothing is stored above its top, so both of its messages stay.
    func testResetDeletesTheStoredHistoryOfAnArchivedDialogWithoutATopMessage() {
        let cleared = self.seedUserChat(201)
        let kept = self.seedUserChat(203)
        self.fixture.storeMessage(peerId: cleared, id: 5, timestamp: self.baseDate + 5, authorId: cleared, text: "cleared")
        self.fixture.storeMessage(peerId: cleared, id: 6, timestamp: self.baseDate + 6, authorId: cleared, text: "cleared")
        self.fixture.storeMessage(peerId: kept, id: 11, timestamp: self.baseDate + 11, authorId: kept, text: "older")
        self.fixture.storeMessage(peerId: kept, id: 12, timestamp: self.baseDate + 12, authorId: kept, text: "top")
        self.fixture.seedAccount(state: self.state(pts: 100))
        self.startAccountResetWithArchive(
            root: self.rootPageReferencingTheArchive(peer: StateSyncApi.peerUser(201)),
            archive: StateSyncApi.dialogs(
                dialogs: [
                    StateSyncApi.dialog(peer: StateSyncApi.peerUser(201), topMessage: 0),
                    StateSyncApi.dialog(peer: StateSyncApi.peerUser(203), topMessage: 12)
                ],
                messages: [StateSyncApi.privateMessage(id: 12, peerUserId: 203, fromUserId: 203, date: self.baseDate + 12, text: "top")],
                users: [StateSyncApi.user(id: 201, firstName: "U201"), StateSyncApi.user(id: 203, firstName: "U203")]
            )
        )

        // The barrier sits behind the running poll and completes once the follow-up ended the cycle.
        self.drainOperationQueue()

        let names = self.server.requestNames
        XCTAssertEqual(names.count, 5, "log: \(names)")
        XCTAssertEqual(names.filter { $0 == Name.getDialogs }.count, 2, "the root page and the archive's: \(names)")
        XCTAssertFalse(names.contains(Name.messagesGetMessages), "log: \(names)")
        XCTAssertNil(self.fixture.message(self.messageId(cleared, 5)))
        XCTAssertNil(self.fixture.message(self.messageId(cleared, 6)))
        XCTAssertNotNil(self.fixture.message(self.messageId(kept, 11)))
        XCTAssertEqual(self.fixture.message(self.messageId(kept, 12))?.text, "top")
        XCTAssertEqual(self.fixture.accountState()?.state?.pts, 999)
    }

    /// The archive's page names an archived dialog's top message (10) but does not carry it. The dialog's top still
    /// comes from its `top_message`, merged into `topMessageIds`, so nothing is stored above it and nothing is
    /// deleted. Green before the fix and after it. It fails if the top-0 rule covers the archived dialogs without
    /// their tops being merged: that reads this dialog as top 0 and deletes its whole history.
    func testResetLeavesAnArchivedDialogWhoseTopMessageThePageDoesNotCarry() {
        let user = self.seedUserChat(202)
        self.fixture.storeMessage(peerId: user, id: 9, timestamp: self.baseDate + 9, authorId: user, text: "older")
        self.fixture.storeMessage(peerId: user, id: 10, timestamp: self.baseDate + 10, authorId: user, text: "top")
        self.fixture.seedAccount(state: self.state(pts: 100))
        self.startAccountResetWithArchive(
            root: self.rootPageReferencingTheArchive(peer: StateSyncApi.peerUser(202)),
            archive: StateSyncApi.dialogs(
                dialogs: [StateSyncApi.dialog(peer: StateSyncApi.peerUser(202), topMessage: 10)],
                messages: [],
                users: [StateSyncApi.user(id: 202, firstName: "U202")]
            )
        )

        self.drainOperationQueue()

        let names = self.server.requestNames
        XCTAssertEqual(names.count, 5, "log: \(names)")
        XCTAssertFalse(names.contains(Name.messagesGetMessages), "log: \(names)")
        XCTAssertNotNil(self.fixture.message(self.messageId(user, 9)))
        XCTAssertNotNil(self.fixture.message(self.messageId(user, 10)))
    }

    /// The chat-list hole fill does not take the rule (owner, 2026-10-24): filling the root list's first hole fetches
    /// the archive's page too, and an archived dialog with top_message 0 there keeps its stored history; nothing is
    /// asked about it.
    func testRootChatListFillLeavesTheStoredHistoryOfAnArchivedDialogWithoutATopMessage() {
        self.fixture.seedAccount(state: self.state(pts: 100))
        let user = self.seedUserChat(201)
        self.fixture.storeMessage(peerId: user, id: 5, timestamp: self.baseDate + 5, authorId: user, text: "cleared")
        self.fixture.storeMessage(peerId: user, id: 6, timestamp: self.baseDate + 6, authorId: user, text: "cleared")
        self.server.on(Name.getDialogs, .result(self.rootPageReferencingTheArchive(peer: StateSyncApi.peerUser(201))))
        self.server.on(Name.getDialogs, .result(StateSyncApi.dialogs(
            dialogs: [StateSyncApi.dialog(peer: StateSyncApi.peerUser(201), topMessage: 0)],
            messages: [],
            users: [StateSyncApi.user(id: 201, firstName: "U201")]
        )))
        self.server.on(Name.getPinnedDialogs, .result(self.emptyPinnedDialogs()))

        let finished: Signal<Bool, NoError> = fetchChatListHole(postbox: self.fixture.postbox, network: self.network, accountPeerId: StateSyncFixture.accountPeerId, groupId: .root, hole: self.rootHole)
        |> map { _ -> Bool in }
        |> then(Signal<Bool, NoError>.single(true))
        XCTAssertEqual(self.fixture.wait(finished), true, "the fill did not complete")

        let names = self.server.requestNames
        XCTAssertEqual(names.count, 3, "log: \(names)")
        XCTAssertEqual(names.filter { $0 == Name.getDialogs }.count, 2, "the root page and the archive's: \(names)")
        XCTAssertFalse(names.contains(Name.messagesGetMessages), "log: \(names)")
        XCTAssertNotNil(self.fixture.message(self.messageId(user, 5)))
        XCTAssertNotNil(self.fixture.message(self.messageId(user, 6)))
    }
}
