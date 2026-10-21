import XCTest
import Postbox
import TelegramCore
@testable import ChatListUI

// A folder's badge adds one for every unread chat the folder names, on top of its categories.
// Pinning a cloud chat inside a folder keeps it in `includePeers.peers` as well as putting it in
// `includePeers.pinnedPeers`, so the list the badge walks must name each chat once.
final class ChatListFilterBadgePeerIdsTests: XCTestCase {
    private func userId(_ id: Int64) -> EnginePeer.Id {
        return EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(id))
    }

    private func secretChatId(_ id: Int64) -> EnginePeer.Id {
        return EnginePeer.Id(namespace: Namespaces.Peer.SecretChat, id: EnginePeer.Id.Id._internalFromInt64Value(id))
    }

    func testAPinnedChatIsNamedOnceWithoutSecretChats() {
        var includePeers = ChatListFilterIncludePeers()
        _ = includePeers.addPeer(self.userId(2))
        _ = includePeers.addPinnedPeer(self.userId(1))
        XCTAssertEqual(includePeers.peers, [self.userId(1), self.userId(2)])
        XCTAssertEqual(includePeers.pinnedPeers, [self.userId(1)])

        XCTAssertEqual(chatListFilterBadgeIncludedPeerIds(includePeers, secretChatsByUserId: [:]), [self.userId(1), self.userId(2)])
    }

    func testAPinnedChatIsNamedOnceWithSecretChats() {
        var includePeers = ChatListFilterIncludePeers()
        _ = includePeers.addPeer(self.userId(2))
        _ = includePeers.addPinnedPeer(self.userId(1))

        XCTAssertEqual(chatListFilterBadgeIncludedPeerIds(includePeers, secretChatsByUserId: [self.userId(1): [self.secretChatId(10)]]), [self.userId(1), self.secretChatId(10), self.userId(2)])
    }

    func testAPinnedSecretChatIsNamed() {
        // A secret chat is pinned without being a member (`isLocalOnlyChatListFilterPeer`).
        var includePeers = ChatListFilterIncludePeers()
        _ = includePeers.addPeer(self.userId(2))
        _ = includePeers.addPinnedPeer(self.secretChatId(10))
        XCTAssertEqual(includePeers.peers, [self.userId(2)])

        XCTAssertEqual(chatListFilterBadgeIncludedPeerIds(includePeers, secretChatsByUserId: [:]), [self.userId(2), self.secretChatId(10)])
    }
}
