import XCTest
import TelegramCore
import MessageWidget
@testable import ChatMessageWidgetBubbleContentNode

/// widget-sandbox v0.2 (sdk-v1 §2.13, §2.14; the v0.2 design §4 call 10): a widget message's context, as the bubble
/// builds it: the media's server flags as they are, the chat's type from its peer, the account as the viewer.
final class MessageWidgetMessageContextTests: XCTestCase {
    private func user(_ id: Int64, firstName: String? = "Ann", lastName: String? = "Lee", username: String? = "ann_lee", premium: Bool = false) -> TelegramUser {
        return TelegramUser(
            id: EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(id)),
            accessHash: nil, firstName: firstName, lastName: lastName, username: username, phone: nil, photo: [], botInfo: nil,
            restrictionInfo: nil, flags: premium ? [.isPremium] : [], emojiStatus: nil, usernames: [], storiesHidden: nil, nameColor: nil,
            backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, subscriberCount: nil, verificationIconFileId: nil)
    }

    private func channel(_ info: TelegramChannelInfo) -> TelegramChannel {
        return TelegramChannel(id: EnginePeer.Id(namespace: Namespaces.Peer.CloudChannel, id: EnginePeer.Id.Id._internalFromInt64Value(1234)), accessHash: nil, title: "Channel", username: nil, photo: [], creationDate: 0, version: 0, participationStatus: .member, info: info, flags: [], restrictionInfo: nil, adminRights: nil, bannedRights: nil, defaultBannedRights: nil, usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, emojiStatus: nil, approximateBoostLevel: nil, subscriptionUntilDate: nil, verificationIconFileId: nil, sendPaidMessageStars: nil, linkedMonoforumId: nil)
    }

    private let widget = TelegramMediaWidget(width: 0, height: 0, payload: Data([1]))
    private let accountPeerId = EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(42))

    func testTheChatTypeFollowsThePeer() {
        let group = TelegramGroup(id: EnginePeer.Id(namespace: Namespaces.Peer.CloudGroup, id: EnginePeer.Id.Id._internalFromInt64Value(1)), title: "G", photo: [], participantCount: 1, role: .member, membership: .Member, flags: [], defaultBannedRights: nil, migrationReference: nil, creationDate: 0, version: 0)
        let cases: [(EnginePeer?, MessageWidgetChatType?)] = [
            (.user(self.user(7)), .private),
            (.legacyGroup(group), .group),
            (.channel(self.channel(.group(TelegramChannelGroupInfo(flags: [])))), .supergroup),
            (.channel(self.channel(.broadcast(TelegramChannelBroadcastInfo(flags: [])))), .channel),
            (nil, nil),
        ]
        for (peer, chatType) in cases {
            XCTAssertEqual(messageWidgetContext(widget: self.widget, chatPeer: peer, accountPeer: nil, accountPeerId: self.accountPeerId).chatType, chatType, "\(String(describing: peer))")
        }
    }

    /// The server's flags pass as they are: nothing is derived from the chat.
    func testTheFlagsPassAsTheMediaHasThem() {
        let peer = EnginePeer.channel(self.channel(.broadcast(TelegramChannelBroadcastInfo(flags: []))))
        let flags: [(Bool, Bool, Bool)] = [(true, false, false), (false, true, false), (false, false, true)]
        for (isCopy, canQuery, backgroundQuery) in flags {
            let widget = TelegramMediaWidget(width: 0, height: 0, payload: Data([1]), isCopy: isCopy, canQuery: canQuery, backgroundQuery: backgroundQuery)
            let context = messageWidgetContext(widget: widget, chatPeer: peer, accountPeer: nil, accountPeerId: self.accountPeerId)
            XCTAssertEqual([context.isCopy, context.canQuery, context.backgroundQuery], [isCopy, canQuery, backgroundQuery])
            XCTAssertFalse(context.isPreview)
        }
    }

    func testTheViewerIsTheAccountsUser() {
        let context = messageWidgetContext(widget: self.widget, chatPeer: nil, accountPeer: .user(self.user(42, premium: true)), accountPeerId: self.accountPeerId)
        XCTAssertEqual(context.viewer, MessageWidgetViewer(id: 42, firstName: "Ann", lastName: "Lee", username: "ann_lee", isPremium: true))
    }

    /// The history list fills the account peer from a signal: without it the viewer is the account's id alone.
    func testWithoutTheAccountPeerTheViewerIsIdOnly() {
        let context = messageWidgetContext(widget: self.widget, chatPeer: nil, accountPeer: nil, accountPeerId: self.accountPeerId)
        XCTAssertEqual(context.viewer, MessageWidgetViewer(id: 42))
    }
}
