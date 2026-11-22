import XCTest
import Postbox
import TelegramCore
import ChatMessageItemCommon

/// Copy Link in a message's context menu. A channel's direct messages are a separate channel (a
/// monoforum) linked to the main channel, and only the main channel's admins who manage direct
/// messages are offered a link there: it is a `t.me/c/` link that nobody else can open.
final class ChatMessageCopyLinkTests: XCTestCase {
    private let mainChannelId: Int64 = 100
    private let directMessagesId: Int64 = 101
    private let user = makeUser(id: 2)

    private func makeMainChannel(flags: TelegramChannelFlags = TelegramChannelFlags(), adminRights: TelegramChatAdminRightsFlags? = nil) -> TelegramChannel {
        return makeChannel(
            id: self.mainChannelId,
            info: .broadcast(TelegramChannelBroadcastInfo(flags: TelegramChannelBroadcastFlags())),
            flags: flags,
            adminRights: adminRights.flatMap { TelegramChatAdminRights(rights: $0) },
            linkedMonoforumId: PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(self.directMessagesId))
        )
    }

    private func makeDirectMessages() -> TelegramChannel {
        return makeChannel(
            id: self.directMessagesId,
            info: .group(TelegramChannelGroupInfo(flags: TelegramChannelGroupFlags())),
            flags: [.isMonoforum],
            linkedMonoforumId: PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(self.mainChannelId))
        )
    }

    /// A message a user sent to the channel's direct messages, as an admin's history renders it: the
    /// main channel is among the message's peers, because it is the chat's associated peer.
    private func makeReceivedMessage(mainChannel: TelegramChannel?, media: [Media] = []) -> Message {
        return makeMessage(peer: self.makeDirectMessages(), author: self.user, media: media, extraPeers: mainChannel.flatMap { [$0] } ?? [])
    }

    func testSupergroupMessageHasChannelLink() {
        let message = makeMessage(peer: makeGroupChannel(id: 50), author: self.user)
        XCTAssertEqual(chatMessageCopyLinkKind(message: message), .channelMessage)
    }

    func testChannelPostHasChannelLink() {
        let channel = makeBroadcastChannel(id: 51, messagesShouldHaveProfiles: false)
        let message = makeMessage(peer: channel, author: channel)
        XCTAssertEqual(chatMessageCopyLinkKind(message: message), .channelMessage)
    }

    func testPrivateChatMessageHasNoLink() {
        let message = makeMessage(peer: makeUser(id: 3), author: self.user)
        XCTAssertNil(chatMessageCopyLinkKind(message: message))
    }

    func testServiceMessageHasNoLink() {
        let action = TelegramMediaAction(action: .historyCleared)
        let message = makeMessage(peer: makeGroupChannel(id: 50), author: self.user, media: [action])
        XCTAssertNil(chatMessageCopyLinkKind(message: message))
    }

    func testDirectMessagesAdminGetsDirectMessagesLink() {
        let message = self.makeReceivedMessage(mainChannel: self.makeMainChannel(adminRights: [.canManageDirect]))
        XCTAssertEqual(chatMessageCopyLinkKind(message: message), .directMessages)
    }

    func testDirectMessagesCreatorGetsDirectMessagesLink() {
        let message = self.makeReceivedMessage(mainChannel: self.makeMainChannel(flags: [.isCreator]))
        XCTAssertEqual(chatMessageCopyLinkKind(message: message), .directMessages)
    }

    /// The user on the other side of the conversation sees the same chat, and gets no link.
    func testDirectMessagesNonAdminGetsNoLink() {
        let message = self.makeReceivedMessage(mainChannel: self.makeMainChannel())
        XCTAssertNil(chatMessageCopyLinkKind(message: message))
    }

    func testDirectMessagesAdminWithoutDirectMessagesRightGetsNoLink() {
        let message = self.makeReceivedMessage(mainChannel: self.makeMainChannel(adminRights: [.canPostMessages, .canEditMessages]))
        XCTAssertNil(chatMessageCopyLinkKind(message: message))
    }

    func testDirectMessagesWithoutKnownMainChannelGetsNoLink() {
        let message = self.makeReceivedMessage(mainChannel: nil)
        XCTAssertNil(chatMessageCopyLinkKind(message: message))
    }

    func testDirectMessagesServiceMessageHasNoLink() {
        let action = TelegramMediaAction(action: .historyCleared)
        let message = self.makeReceivedMessage(mainChannel: self.makeMainChannel(adminRights: [.canManageDirect]), media: [action])
        XCTAssertNil(chatMessageCopyLinkKind(message: message))
    }

    func testDirectMessagesLinkUsesExportedLink() {
        let messageId = MessageId(peerId: self.makeDirectMessages().id, namespace: Namespaces.Message.Cloud, id: 42)
        XCTAssertEqual(directMessagesMessageLink(exportedLink: "https://t.me/c/101/42?single", messageId: messageId), "https://t.me/c/101/42?single")
    }

    func testDirectMessagesLinkFallsBackToPrivateChannelLink() {
        let messageId = MessageId(peerId: self.makeDirectMessages().id, namespace: Namespaces.Message.Cloud, id: 42)
        XCTAssertEqual(directMessagesMessageLink(exportedLink: nil, messageId: messageId), "https://t.me/c/101/42")
    }
}
