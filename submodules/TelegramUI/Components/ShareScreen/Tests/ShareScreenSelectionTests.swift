import XCTest
import TelegramCore
@testable import ShareScreen

final class ShareScreenSelectionTests: XCTestCase {
    private func peer(_ id: Int64, name: String = "Alice") -> EnginePeer {
        return EnginePeer(TelegramUser(id: EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(id)), accessHash: nil, firstName: name, lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, subscriberCount: nil, verificationIconFileId: nil))
    }

    func testSelectionUsesPeerIdentityAcrossSearchAndRecommendations() {
        var selection = ShareScreenSelection()
        let fromRecommendations = self.peer(1)
        let fromSearch = self.peer(1, name: "Alice Updated")
        selection.toggle(fromRecommendations)
        XCTAssertTrue(selection.contains(fromSearch.id))
        selection.toggle(fromSearch)
        XCTAssertTrue(selection.peers.isEmpty)
    }

    func testDeselectionDoesNotReorderRemainingRecipients() {
        var selection = ShareScreenSelection()
        let peers = [self.peer(1), self.peer(2), self.peer(3)]
        peers.forEach { selection.toggle($0) }
        selection.toggle(peers[1])
        XCTAssertEqual(selection.peers.map(\.id), [peers[0].id, peers[2].id])
        selection.toggle(peers[1])
        XCTAssertEqual(selection.peers.map(\.id), [peers[0].id, peers[2].id, peers[1].id])
    }

    func testTopicDoesNotLeakIntoReselectedRecipient() {
        var selection = ShareScreenSelection()
        let peer = self.peer(1)
        selection.toggle(peer, topicId: 42)
        XCTAssertEqual(selection.topics[peer.id], 42)
        selection.toggle(peer)
        XCTAssertNil(selection.topics[peer.id])
        selection.toggle(peer, topicId: 99)
        XCTAssertEqual(selection.topics[peer.id], 99)
        XCTAssertEqual(selection.peers.count, 1)
    }
}
