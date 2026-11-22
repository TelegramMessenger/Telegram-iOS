import XCTest
import Postbox
import TelegramCore
import ChatMessageItemCommon

// The one decision every bubble-free layout reads: a bubble, a message without one, an outlined card, or a service
// message (spec 6.4).
final class ChatMessageBubbleStyleTests: XCTestCase {
    private let group = makeGroupChannel(id: 100)
    private let user = makeUser(id: 2)

    private func message(isOutgoing: Bool = false, media: [Media] = []) -> Message {
        return makeMessage(peer: self.group, author: self.user, isOutgoing: isOutgoing, media: media)
    }

    private func style(_ message: Message, bubbleMode: Bool = false, isMessageOptions: Bool = false) -> ChatMessageBubbleStyle {
        return chatMessageBubbleStyle(bubbleMode: bubbleMode, isMessageOptions: isMessageOptions, incoming: message.flags.contains(.Incoming), message: message)
    }

    func testBubbleModeIsAlwaysABubble() {
        XCTAssertEqual(self.style(self.message(), bubbleMode: true), .bubble)
        XCTAssertEqual(self.style(self.message(media: [TelegramMediaAction(action: .groupCreated(title: "G"))]), bubbleMode: true), .bubble)
        XCTAssertEqual(self.style(self.message(media: [makeTestPoll()]), bubbleMode: true), .bubble)
    }

    func testIncomingTextIsBubbleless() {
        XCTAssertEqual(self.style(self.message()), .bubbleless)
        XCTAssertTrue(ChatMessageBubbleStyle.bubbleless.isBubbleless)
        XCTAssertTrue(ChatMessageBubbleStyle.bubblelessCard.isBubbleless)
        XCTAssertFalse(ChatMessageBubbleStyle.bubblelessService.isBubbleless)
        XCTAssertFalse(ChatMessageBubbleStyle.bubble.isBubbleless)
    }

    func testOutgoingKeepsItsBubble() {
        XCTAssertEqual(self.style(self.message(isOutgoing: true)), .bubble)
    }

    func testMessageOptionsKeepTheirBubbles() {
        XCTAssertEqual(self.style(self.message(), isMessageOptions: true), .bubble)
    }

    func testServiceIsServiceInBothDirections() {
        let action = TelegramMediaAction(action: .groupCreated(title: "G"))
        XCTAssertEqual(self.style(self.message(media: [action])), .bubblelessService)
        XCTAssertEqual(self.style(self.message(isOutgoing: true, media: [action])), .bubblelessService)
    }

    // Without bubbles a person's messages in a chat with them carry their avatar, as in a group. The item's avatar header
    // and every item node's avatar column read this one answer: when they decided apart, the avatar landed on a sticker
    // and on the bubble of the reply-options preview.
    func testPrivateChatAvatarWithoutBubbles() {
        let person = EnginePeer(makeUser(id: 2))
        XCTAssertTrue(chatMessageBubblelessPrivateChatHasAvatar(style: .bubbleless, isPreview: false, chatPeer: person))
        XCTAssertTrue(chatMessageBubblelessPrivateChatHasAvatar(style: .bubblelessCard, isPreview: false, chatPeer: person))
    }

    func testPrivateChatAvatarFollowsTheStyle() {
        let person = EnginePeer(makeUser(id: 2))
        // Bubbles (reply options included) and service messages (expired media included) have none; nor do previews.
        XCTAssertFalse(chatMessageBubblelessPrivateChatHasAvatar(style: .bubble, isPreview: false, chatPeer: person))
        XCTAssertFalse(chatMessageBubblelessPrivateChatHasAvatar(style: .bubblelessService, isPreview: false, chatPeer: person))
        XCTAssertFalse(chatMessageBubblelessPrivateChatHasAvatar(style: .bubbleless, isPreview: true, chatPeer: person))
    }

    // Spec 3.2: bots get a name header and no avatar; a secret one-to-one chat gets neither.
    func testBotsAndSecretChatsHaveNoPrivateChatAvatar() {
        XCTAssertFalse(chatMessageBubblelessPrivateChatHasAvatar(style: .bubbleless, isPreview: false, chatPeer: EnginePeer(makeBot(id: 3))))
        XCTAssertFalse(chatMessageBubblelessPrivateChatHasAvatar(style: .bubbleless, isPreview: false, chatPeer: EnginePeer(makeSecretChat(id: 4, with: 2))))
        XCTAssertFalse(chatMessageBubblelessPrivateChatHasAvatar(style: .bubbleless, isPreview: false, chatPeer: nil))
    }

    func testSecretChatsHaveNoAuthorHeader() {
        XCTAssertFalse(chatMessageBubblelessChatShowsAuthor(chatPeerId: makeSecretChat(id: 4, with: 2).id))
        XCTAssertTrue(chatMessageBubblelessChatShowsAuthor(chatPeerId: makeUserPeerId(2)))
        XCTAssertTrue(chatMessageBubblelessChatShowsAuthor(chatPeerId: self.group.id))
    }

    func testExpiredMediaIsService() {
        XCTAssertEqual(self.style(self.message(media: [TelegramMediaExpiredContent(data: .image)])), .bubblelessService)
    }

    func testIncomingCallIsACard() {
        let call = TelegramMediaAction(action: .phoneCall(callId: 1, discardReason: nil, duration: 30, isVideo: false))
        XCTAssertEqual(self.style(self.message(media: [call])), .bubblelessCard)
        XCTAssertEqual(self.style(self.message(isOutgoing: true, media: [call])), .bubble)
    }

    func testPollsChecklistsGiveawaysAndWidgetsAreCards() {
        let cards: [Media] = [
            makeTestPoll(),
            TelegramMediaTodo(flags: [], text: "T", textEntities: [], items: []),
            TelegramMediaGiveaway(flags: [], channelPeerIds: [], countries: [], quantity: 1, prize: .premium(months: 3), untilDate: 0, prizeDescription: nil),
            TelegramMediaGiveawayResults(flags: [], launchMessageId: MessageId(peerId: self.group.id, namespace: Namespaces.Message.Cloud, id: 1), additionalChannelsCount: 0, winnersPeerIds: [], winnersCount: 1, unclaimedCount: 0, prize: .premium(months: 3), untilDate: 0, prizeDescription: nil),
            TelegramMediaWidget(width: 100, height: 100, payload: Data())
        ]
        for card in cards {
            XCTAssertEqual(self.style(self.message(media: [card])), .bubblelessCard, "\(type(of: card))")
        }
    }
}

func makeTestPoll() -> TelegramMediaPoll {
    return TelegramMediaPoll(pollId: MediaId(namespace: Namespaces.Media.CloudPoll, id: 1), publicity: .anonymous, kind: .poll(multipleAnswers: false), text: "Q", textEntities: [], options: [], correctAnswers: nil, results: TelegramMediaPollResults(voters: nil, totalVoters: nil, recentVoters: [], solution: nil, hasUnseenVotes: nil, canViewStats: false), isClosed: false, deadlineTimeout: nil, deadlineDate: nil, pollHash: 0)
}
