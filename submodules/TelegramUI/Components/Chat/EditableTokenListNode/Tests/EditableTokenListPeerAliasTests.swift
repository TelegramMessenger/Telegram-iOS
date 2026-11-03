import XCTest
import Postbox
import TelegramCore
import AvatarNode
import EditableTokenListNode

/// A chat picker's token names your own peer "Saved Messages" and the replies bot "Replies", so the
/// token has to draw those chats' icons too, not the peer's profile photo.
final class EditableTokenListPeerAliasTests: XCTestCase {
    private let accountPeer = makeUser(id: 1)

    // bugs.telegram.org/c/65867: picking Saved Messages for a folder showed a token titled
    // "Saved Messages" with the account's own profile photo.
    func testAccountPeerIsSavedMessages() {
        let alias = EditableTokenListPeerAlias(peer: .user(self.accountPeer), accountPeerId: self.accountPeer.id)

        XCTAssertEqual(alias, .savedMessages)
        XCTAssertEqual(alias?.avatarOverride, .savedMessagesIcon)
    }

    func testRepliesPeerIsReplies() {
        let replies = makeUser(id: 708513)
        let alias = EditableTokenListPeerAlias(peer: .user(replies), accountPeerId: self.accountPeer.id)

        XCTAssertEqual(alias, .replies)
        XCTAssertEqual(alias?.avatarOverride, .repliesIcon)
    }

    func testOtherPeerIsNotAliased() {
        let other = makeUser(id: 2)

        XCTAssertNil(EditableTokenListPeerAlias(peer: .user(other), accountPeerId: self.accountPeer.id))
    }
}

private func makeUser(id: Int64) -> TelegramUser {
    return TelegramUser(
        id: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(id)),
        accessHash: nil,
        firstName: "U\(id)",
        lastName: nil,
        username: nil,
        phone: nil,
        photo: [],
        botInfo: nil,
        restrictionInfo: nil,
        flags: UserInfoFlags(),
        emojiStatus: nil,
        usernames: [],
        storiesHidden: nil,
        nameColor: nil,
        backgroundEmojiId: nil,
        profileColor: nil,
        profileBackgroundEmojiId: nil,
        subscriberCount: nil,
        verificationIconFileId: nil
    )
}
