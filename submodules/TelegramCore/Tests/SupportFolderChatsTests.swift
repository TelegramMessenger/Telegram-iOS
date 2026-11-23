import XCTest
import Postbox
@testable import TelegramCore

/// A support account fetches the dialogs of the chats its folders name, in bounded batches, once each.
final class SupportFolderChatsTests: XCTestCase {
    private func user(_ id: Int64) -> PeerId {
        return PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(id))
    }

    private func folder(id: Int32, peers: [PeerId], pinned: [PeerId] = [], exclude: [PeerId] = []) -> ChatListFilter {
        let data = ChatListFilterData(isShared: false, hasSharedLinks: false, categories: [.contacts], excludeMuted: false, excludeRead: false, excludeArchived: false, includePeers: ChatListFilterIncludePeers(peers: peers, pinnedPeers: pinned), excludePeers: exclude, color: nil)
        return .filter(id: id, title: ChatFolderTitle(text: "F\(id)", entities: [], enableAnimations: false), emoticon: nil, data: data)
    }

    func testNamedPeersArePinnedThenIncludedWithoutDuplicates() {
        let filters: [ChatListFilter] = [
            .allChats,
            self.folder(id: 2, peers: [self.user(1), self.user(2), self.user(3)], pinned: [self.user(3)]),
            self.folder(id: 3, peers: [self.user(2), self.user(4)])
        ]
        XCTAssertEqual(supportFolderNamedPeerIds(filters: filters), [self.user(3), self.user(1), self.user(2), self.user(4)])
    }

    func testExcludedPeersAndSecretChatsAreNotNamed() {
        let secret = PeerId(namespace: Namespaces.Peer.SecretChat, id: PeerId.Id._internalFromInt64Value(7))
        let filters = [self.folder(id: 2, peers: [self.user(1), secret], exclude: [self.user(9)])]
        XCTAssertEqual(supportFolderNamedPeerIds(filters: filters), [self.user(1)])
    }

    func testOnlyChatsWithoutARowAndNotYetAttemptedAreFetched() {
        let named = [self.user(1), self.user(2), self.user(3), self.user(4)]
        let result = supportFolderChatsToFetch(namedPeerIds: named, attempted: Set([self.user(2)]), hasChatListRow: { $0 == self.user(3) })
        XCTAssertEqual(result, [self.user(1), self.user(4)])
    }

    func testBatchesNeverExceedTheLimit() {
        let items = Array(0 ..< 250)
        let batches = supportFolderChatBatches(items, size: supportFolderChatsBatchSize)
        XCTAssertEqual(batches.map(\.count), [100, 100, 50])
        XCTAssertEqual(batches.flatMap { $0 }, items)
        XCTAssertTrue(supportFolderChatBatches([Int](), size: supportFolderChatsBatchSize).isEmpty)
    }
}
