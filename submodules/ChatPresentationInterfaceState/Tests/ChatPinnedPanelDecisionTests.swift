import XCTest
import TelegramCore
import ChatPresentationInterfaceState

/// A channel's pinned panel shows its pinned list's answer once the list has loaded. Until then it shows the cached
/// pinned message (`CachedChannelData.pinnedMessageId`): the stored message if there is one, otherwise a skeleton.
final class ChatPinnedPanelDecisionTests: XCTestCase {
    private let channelId = EnginePeer.Id(namespace: Namespaces.Peer.CloudChannel, id: EnginePeer.Id.Id._internalFromInt64Value(1))

    private func messageId(_ id: Int32) -> EngineMessage.Id {
        return EngineMessage.Id(peerId: self.channelId, namespace: Namespaces.Message.Cloud, id: id)
    }

    func testResolvedListWinsOverTheCache() {
        XCTAssertEqual(chatPinnedPanelSource(list: .resolved(hasMessage: true), cachedPinnedMessageId: self.messageId(7), isCachedMessageStored: true), .list)
    }

    // The list said nothing is pinned: the cache is outdated and shows nothing. Also the never-pin subjects
    // (message options, the pinned list, scheduled), which start resolved to nil.
    func testResolvedEmptyListShowsNothingWhateverTheCache() {
        XCTAssertEqual(chatPinnedPanelSource(list: .resolved(hasMessage: false), cachedPinnedMessageId: self.messageId(7), isCachedMessageStored: false), .none)
        XCTAssertEqual(chatPinnedPanelSource(list: .resolved(hasMessage: false), cachedPinnedMessageId: self.messageId(7), isCachedMessageStored: true), .none)
    }

    func testUnresolvedWithAStoredCachedMessageShowsIt() {
        XCTAssertEqual(chatPinnedPanelSource(list: .unresolved, cachedPinnedMessageId: self.messageId(7), isCachedMessageStored: true), .storedCachedMessage)
    }

    func testUnresolvedWithoutTheMessageShowsTheSkeleton() {
        XCTAssertEqual(chatPinnedPanelSource(list: .unresolved, cachedPinnedMessageId: self.messageId(7), isCachedMessageStored: false), .skeleton(self.messageId(7)))
    }

    func testUnresolvedWithoutACachedIdShowsNothing() {
        XCTAssertEqual(chatPinnedPanelSource(list: .unresolved, cachedPinnedMessageId: nil, isCachedMessageStored: false), .none)
    }

    func testRealMessageShows() {
        XCTAssertTrue(chatPinnedPanelIsVisible(pinnedMessageTopId: self.messageId(7), skeletonId: nil, closedPinnedMessageId: nil, pendingUnpinnedAllMessages: false))
    }

    func testClosedRealMessageHides() {
        XCTAssertFalse(chatPinnedPanelIsVisible(pinnedMessageTopId: self.messageId(7), skeletonId: nil, closedPinnedMessageId: self.messageId(7), pendingUnpinnedAllMessages: false))
    }

    func testSkeletonShows() {
        XCTAssertTrue(chatPinnedPanelIsVisible(pinnedMessageTopId: nil, skeletonId: self.messageId(7), closedPinnedMessageId: self.messageId(3), pendingUnpinnedAllMessages: false))
    }

    // A pin the user dismissed does not come back as a skeleton.
    func testClosedSkeletonHides() {
        XCTAssertFalse(chatPinnedPanelIsVisible(pinnedMessageTopId: nil, skeletonId: self.messageId(7), closedPinnedMessageId: self.messageId(7), pendingUnpinnedAllMessages: false))
    }

    func testPendingUnpinAllHidesBoth() {
        XCTAssertFalse(chatPinnedPanelIsVisible(pinnedMessageTopId: self.messageId(7), skeletonId: nil, closedPinnedMessageId: nil, pendingUnpinnedAllMessages: true))
        XCTAssertFalse(chatPinnedPanelIsVisible(pinnedMessageTopId: nil, skeletonId: self.messageId(7), closedPinnedMessageId: nil, pendingUnpinnedAllMessages: true))
    }

    func testNothingToShowHides() {
        XCTAssertFalse(chatPinnedPanelIsVisible(pinnedMessageTopId: nil, skeletonId: nil, closedPinnedMessageId: nil, pendingUnpinnedAllMessages: false))
    }
}
