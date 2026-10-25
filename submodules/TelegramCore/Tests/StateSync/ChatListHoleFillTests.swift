import Foundation
import XCTest
import SwiftSignalKit
import Postbox
import TelegramApi
@testable import TelegramCore

/// `fetchChatListHole` (Holes.swift), which loads a chat-list page the account does not have yet; it is how
/// chats beyond the account reset's top 100 get their top message. Driven directly, like
/// ForumHistoryFillTests: the fill needs an authorized account state and the network, no state manager.
///
/// The hole is the root list's first one, at a `Namespaces.Peer.Empty` index as the seed configuration and the
/// reset add it, so `fetchChatList` asks from the top: `messages.getDialogs` and `messages.getPinnedDialogs`
/// run in parallel, in no fixed order, and every other request comes after both.
final class ChatListHoleFillTests: StateSyncTestCase {
    private let rootHole = ChatListHole(index: MessageIndex(id: MessageId(peerId: PeerId(namespace: Namespaces.Peer.Empty, id: PeerId.Id._internalFromInt64Value(0)), namespace: Namespaces.Message.Cloud, id: 1), timestamp: Int32.max - 1))

    /// Answers the page's two requests: `dialogs` in getDialogs, nothing pinned.
    private func scriptPage(dialogs: [Api.Dialog], messages: [Api.Message], chats: [Api.Chat] = [], users: [Api.User] = []) {
        self.server.on(Name.getDialogs, .result(StateSyncApi.dialogs(dialogs: dialogs, messages: messages, chats: chats, users: users)))
        self.server.on(Name.getPinnedDialogs, .result(StateSyncApi.peerDialogs(state: StateSyncApi.state(pts: 100, date: self.baseDate, seq: 10))))
    }

    /// Runs the fill to completion.
    private func fillRootHole(file: StaticString = #filePath, line: UInt = #line) {
        let finished: Signal<Bool, NoError> = fetchChatListHole(postbox: self.fixture.postbox, network: self.network, accountPeerId: StateSyncFixture.accountPeerId, groupId: .root, hole: self.rootHole)
        |> map { _ -> Bool in }
        |> then(Signal<Bool, NoError>.single(true))
        XCTAssertEqual(self.fixture.wait(finished, file: file, line: line), true, "the fill did not complete", file: file, line: line)
    }

    /// The root list's chat-list holes.
    private func rootChatListHoles() -> [ChatListHole] {
        return self.fixture.transaction { transaction -> [ChatListHole] in
            return transaction.allChatListHoles(groupId: .root)
        } ?? []
    }

    /// The requests after the page's own two.
    private func requestsAfterThePage(file: StaticString = #filePath, line: UInt = #line) -> [ScriptedRequest] {
        let requests = self.server.requests
        XCTAssertEqual(Set(requests.prefix(2).map { $0.name }), Set([Name.getDialogs, Name.getPinnedDialogs]), file: file, line: line)
        return Array(requests.dropFirst(2))
    }

    /// The chat-list hole fill leaves every stored message above a dialog's top message alone and asks nothing about
    /// it (owner, 2026-10-24; spec section 3 point 3 as amended). The fill does not move pts, so a message that
    /// arrived and was applied while its page was in flight would never be delivered again if the fill deleted it.
    /// Only the account reset deletes a ghost tail. Covers a private chat, a dialog whose top_message is 0 and a
    /// channel.
    func testChatListFillLeavesStoredMessagesAboveTheTopAlone() {
        self.fixture.seedAccount(state: self.state(pts: 100))
        let user = self.seedUserChat(200)
        let cleared = self.seedUserChat(201)
        let channel = self.seedChannel(300, pts: 60, storedMessageId: 20)
        self.fixture.storeMessage(peerId: user, id: 10, timestamp: self.baseDate, authorId: user, text: "top")
        self.fixture.storeMessage(peerId: user, id: 11, timestamp: self.baseDate + 1, authorId: user, text: "above the top")
        self.fixture.storeMessage(peerId: cleared, id: 5, timestamp: self.baseDate - 2, authorId: cleared, text: "above top 0")
        self.fixture.storeMessage(peerId: channel, id: 21, timestamp: self.baseDate + 1, authorId: nil, text: "above the top")
        self.scriptPage(
            dialogs: [
                StateSyncApi.dialog(peer: StateSyncApi.peerUser(200), topMessage: 10),
                StateSyncApi.dialog(peer: StateSyncApi.peerChannel(300), topMessage: 20, pts: 60),
                StateSyncApi.dialog(peer: StateSyncApi.peerUser(201), topMessage: 0)
            ],
            messages: [self.incomingMessage(10, from: 200, date: self.baseDate), StateSyncApi.channelPost(id: 20, channelId: 300, date: self.baseDate)],
            chats: [StateSyncApi.broadcastChannel(id: 300, title: "C300")],
            users: [StateSyncApi.user(id: 200, firstName: "U200"), StateSyncApi.user(id: 201, firstName: "U201")]
        )

        self.fillRootHole()

        XCTAssertEqual(self.requestsAfterThePage().map { $0.name }, [])
        XCTAssertFalse(self.rootChatListHoles().contains(self.rootHole), "the fill did not complete")
        XCTAssertNotNil(self.fixture.message(self.messageId(user, 10)))
        XCTAssertEqual(self.fixture.message(self.messageId(user, 11))?.text, "above the top")
        XCTAssertEqual(self.fixture.message(self.messageId(cleared, 5))?.text, "above top 0")
        XCTAssertNotNil(self.fixture.message(self.messageId(channel, 20)))
        XCTAssertEqual(self.fixture.message(self.messageId(channel, 21))?.text, "above the top")
    }

    /// A private chat's stored messages above the top the page names stay, but under a hole (owner, 2026-10-25): after
    /// an account reset, a chat beyond its first page is where a message deleted during the gap waits, which the reset
    /// could not delete and this fill may not. The chat's next history fill asks the server about them and deletes only
    /// those it no longer has. Found by the truth server (large-world seeds 698 and 916). 11 is such a ghost: the fill
    /// leaves it stored under a hole; the history fill's confirmation gets `messageEmpty` for it and deletes it, and 10
    /// stays.
    func testChatListFillLeavesMessagesAboveATopUnderAHoleTheNextHistoryFillConfirms() {
        self.fixture.seedAccount(state: self.state(pts: 100))
        let user = self.seedUserChat(200)
        self.fixture.storeMessage(peerId: user, id: 10, timestamp: self.baseDate, authorId: user, text: "top", location: .UpperHistoryBlock)
        self.fixture.storeMessage(peerId: user, id: 11, timestamp: self.baseDate + 1, authorId: user, text: "deleted on the server")
        XCTAssertFalse(self.fixture.holes(peerId: user).contains(11), "precondition: 11 is not under a hole")
        self.scriptPage(
            dialogs: [StateSyncApi.dialog(peer: StateSyncApi.peerUser(200), topMessage: 10)],
            messages: [self.incomingMessage(10, from: 200, date: self.baseDate)],
            users: [StateSyncApi.user(id: 200, firstName: "U200")]
        )

        self.fillRootHole()

        XCTAssertEqual(self.requestsAfterThePage().map { $0.name }, [], "the chat-list fill asked about the messages above the top")
        XCTAssertNotNil(self.fixture.message(self.messageId(user, 11)), "the chat-list fill deleted a message above the top")
        XCTAssertTrue(self.fixture.holes(peerId: user).contains(11), "the message above the top is not under a hole")
        XCTAssertFalse(self.fixture.holes(peerId: user).contains(10), "the top itself is under a hole")

        self.server.on("messages.getHistory", .result(StateSyncApi.messages([self.incomingMessage(10, from: 200, date: self.baseDate)])))
        self.server.on("messages.getMessages", .result(StateSyncApi.messages([.messageEmpty(.init(flags: 0, id: 11, peerId: nil))])))
        let _ = self.runHistoryFill(peerInput: .direct(peerId: user, threadId: nil), direction: self.downwardFillDirection(user))

        XCTAssertNil(self.fixture.message(self.messageId(user, 11)), "the history fill kept a message the server no longer has")
        XCTAssertNotNil(self.fixture.message(self.messageId(user, 10)))
    }

    /// A channel's posts above its top get no hole: its own revalidation (`invalidatedPts`) covers them.
    func testChatListFillLeavesAChannelsPostsAboveTheTopWithoutAHole() {
        self.fixture.seedAccount(state: self.state(pts: 100))
        let channel = self.seedChannel(300, pts: 60, storedMessageId: nil)
        self.fixture.storeMessage(peerId: channel, id: 20, timestamp: self.baseDate, authorId: nil, text: "top", location: .UpperHistoryBlock)
        self.fixture.storeMessage(peerId: channel, id: 21, timestamp: self.baseDate + 1, authorId: nil, text: "above the top")
        self.scriptPage(
            dialogs: [StateSyncApi.dialog(peer: StateSyncApi.peerChannel(300), topMessage: 20, pts: 60)],
            messages: [StateSyncApi.channelPost(id: 20, channelId: 300, date: self.baseDate)],
            chats: [StateSyncApi.broadcastChannel(id: 300, title: "C300")]
        )

        self.fillRootHole()

        XCTAssertFalse(self.fixture.holes(peerId: channel).contains(21))
        XCTAssertEqual(self.fixture.message(self.messageId(channel, 21))?.text, "above the top")
    }

    /// A page that moves a channel's pts raises its invalidatedPts to the new pts, so the channel's own
    /// revalidation runs for what was stored before. Until the fix only the pts moved.
    func testChannelWhosePtsMovesGetsInvalidatedPtsRaised() {
        self.fixture.seedAccount(state: self.state(pts: 100))
        let channel = self.seedChannel(301, pts: 50, storedMessageId: 20)
        self.scriptPage(dialogs: [StateSyncApi.dialog(peer: StateSyncApi.peerChannel(301), topMessage: 20, pts: 70)], messages: [StateSyncApi.channelPost(id: 20, channelId: 301, date: self.baseDate)], chats: [StateSyncApi.broadcastChannel(id: 301, title: "C301")])

        self.fillRootHole()

        XCTAssertEqual(self.requestsAfterThePage().map { $0.name }, [])
        let state = self.fixture.channelState(channel)
        XCTAssertEqual(state?.pts, 70)
        XCTAssertEqual(state?.invalidatedPts, 70)
    }

    /// invalidatedPts only rises: a page that reports a channel's pts below the stored one (60 under 80, an
    /// older page) leaves its invalidatedPts at 80, so the messages it marks for revalidation stay marked. Before
    /// the fix it followed the page's pts down to 60. The pts itself still follows the page, as before.
    func testPageNeverLowersAChannelsInvalidatedPts() {
        self.fixture.seedAccount(state: self.state(pts: 100))
        let channel = StateSyncFixture.channelPeerId(303)
        self.fixture.seedChannel(StateSyncFixture.makeChannel(id: channel, accessHash: 1, title: "C303"), state: ChannelState(pts: 80, invalidatedPts: 80, synchronizedUntilMessageId: nil))
        self.fixture.seedChat(peerId: channel)
        self.scriptPage(dialogs: [StateSyncApi.dialog(peer: StateSyncApi.peerChannel(303), topMessage: 20, pts: 60)], messages: [StateSyncApi.channelPost(id: 20, channelId: 303, date: self.baseDate)], chats: [StateSyncApi.broadcastChannel(id: 303, title: "C303")])

        self.fillRootHole()

        XCTAssertEqual(self.requestsAfterThePage().map { $0.name }, [])
        let state = self.fixture.channelState(channel)
        XCTAssertEqual(state?.pts, 60)
        XCTAssertEqual(state?.invalidatedPts, 80, "the page lowered invalidatedPts")
    }

    /// Control: a channel whose pts the page does not move is left alone.
    func testChannelWhosePtsDidNotMoveIsLeftAlone() {
        self.fixture.seedAccount(state: self.state(pts: 100))
        let channel = self.seedChannel(302, pts: 70, storedMessageId: 20)
        self.scriptPage(dialogs: [StateSyncApi.dialog(peer: StateSyncApi.peerChannel(302), topMessage: 20, pts: 70)], messages: [StateSyncApi.channelPost(id: 20, channelId: 302, date: self.baseDate)], chats: [StateSyncApi.broadcastChannel(id: 302, title: "C302")])

        self.fillRootHole()

        XCTAssertEqual(self.requestsAfterThePage().map { $0.name }, [])
        let state = self.fixture.channelState(channel)
        XCTAssertEqual(state?.pts, 70)
        XCTAssertNil(state?.invalidatedPts)
    }
}
