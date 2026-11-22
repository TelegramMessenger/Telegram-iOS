import XCTest
import Postbox
import TelegramCore
@testable import ChatListUI

/// A collapsed community row ("Show as One Chat") names the chat its last message came from. With folder tags the
/// row has one preview line, so the name must go in front of the preview rather than on a line of its own, which
/// pushed the preview onto the tags' line (issue #6).
final class ChatListCommunitySourceTests: XCTestCase {
    private let communityId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(100))
    private let groupId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(200))

    private var community: TelegramCommunity {
        return TelegramCommunity(id: self.communityId, accessHash: nil, title: "Community", photo: [], creationDate: 0, participationStatus: .member, flags: [], collapsedInDialogs: true, adminRights: nil, defaultBannedRights: nil)
    }

    private var group: TelegramGroup {
        return TelegramGroup(id: self.groupId, title: "Source Group", photo: [], participantCount: 1, role: .member, membership: .Member, flags: [], defaultBannedRights: nil, migrationReference: nil, creationDate: 0, version: 0)
    }

    private func message(in peerId: PeerId, peers: [Peer]) -> EngineMessage {
        var messagePeers: [PeerId: EnginePeer] = [:]
        for peer in peers {
            messagePeers[peer.id] = EnginePeer(peer)
        }
        return EngineMessage(stableId: 1, stableVersion: 0, id: MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: 1), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: 0, flags: [], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: nil, text: "Hello", attributes: [], media: [], peers: messagePeers, associatedMessages: [:], associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
    }

    private func communityRow() -> EngineRenderedPeer {
        return EngineRenderedPeer(peerId: self.communityId, peers: [self.communityId: EnginePeer(self.community)], associatedMedia: [:])
    }

    func testWithoutTagsTheSourceChatHasALineOfItsOwn() {
        let source = chatListCommunitySource(chatPeer: self.communityRow(), message: self.message(in: self.groupId, peers: [self.group]), hasTags: false)
        XCTAssertEqual(source?.peer.id, self.groupId)
        XCTAssertEqual(source?.placement, .authorLine)
    }

    func testWithTagsTheSourceChatPrefixesThePreview() {
        let source = chatListCommunitySource(chatPeer: self.communityRow(), message: self.message(in: self.groupId, peers: [self.group]), hasTags: true)
        XCTAssertEqual(source?.peer.id, self.groupId)
        XCTAssertEqual(source?.placement, .previewPrefix)
    }

    func testTheSourceChatIsFoundAmongTheRowsPeersWhenTheMessageLacksIt() {
        let row = EngineRenderedPeer(peerId: self.communityId, peers: [self.communityId: EnginePeer(self.community), self.groupId: EnginePeer(self.group)], associatedMedia: [:])
        let source = chatListCommunitySource(chatPeer: row, message: self.message(in: self.groupId, peers: []), hasTags: true)
        XCTAssertEqual(source?.peer.id, self.groupId)
        XCTAssertEqual(source?.placement, .previewPrefix)
    }

    func testAnUnknownSourceChatNamesNoSource() {
        XCTAssertNil(chatListCommunitySource(chatPeer: self.communityRow(), message: self.message(in: self.groupId, peers: []), hasTags: true))
    }

    func testAMessageOfTheCommunityItselfNamesNoSource() {
        XCTAssertNil(chatListCommunitySource(chatPeer: self.communityRow(), message: self.message(in: self.communityId, peers: []), hasTags: true))
    }

    func testARegularChatNamesNoSource() {
        let groupRow = EngineRenderedPeer(peerId: self.groupId, peers: [self.groupId: EnginePeer(self.group)], associatedMedia: [:])
        XCTAssertNil(chatListCommunitySource(chatPeer: groupRow, message: self.message(in: self.groupId, peers: [self.group]), hasTags: true))
    }

    // With tags the preview line reads "Author › Source: text", in the order of the line it replaces.

    func testWithTagsTheAuthorComesBeforeTheSourceChat() {
        let authorId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(300))
        XCTAssertEqual(chatListCommunityPreviewAuthor(authorTitle: "Alice", authorId: authorId, sourcePeerId: self.groupId), "Alice")
    }

    func testAPostByTheSourceChatItselfIsNotNamedTwice() {
        XCTAssertNil(chatListCommunityPreviewAuthor(authorTitle: "Source Group", authorId: self.groupId, sourcePeerId: self.groupId))
    }

    func testARowThatShowsNoAuthorPrefixesTheSourceChatAlone() {
        XCTAssertNil(chatListCommunityPreviewAuthor(authorTitle: nil, authorId: nil, sourcePeerId: self.groupId))
        XCTAssertNil(chatListCommunityPreviewAuthor(authorTitle: "", authorId: nil, sourcePeerId: self.groupId))
    }
}
