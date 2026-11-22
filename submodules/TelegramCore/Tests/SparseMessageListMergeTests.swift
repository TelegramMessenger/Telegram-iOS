import XCTest
import Postbox
@testable import TelegramCore

/// The one list the grid shows for a channel and the group it was migrated from.
final class SparseMessageListMergeTests: XCTestCase {
    private let channelId = SparseFixtures.channelId
    private let groupId = SparseFixtures.groupId

    private var loading: SparseMessageList.State {
        return SparseMessageList.State(items: [], totalCount: 0, isLoading: true)
    }

    private var channelState: SparseMessageList.State {
        return SparseMessageList.State(items: [
            SparseMessageList.State.Item(index: 0, content: .message(message: SparseFixtures.message(self.channelId, 20, timestamp: 2000), isLocal: true)),
            SparseMessageList.State.Item(index: 5, content: .placeholder(id: SparseFixtures.messageId(self.channelId, 10), timestamp: 1000))
        ], totalCount: 8, isLoading: false)
    }

    private var groupState: SparseMessageList.State {
        return SparseMessageList.State(items: [
            SparseMessageList.State.Item(index: 0, content: .placeholder(id: SparseFixtures.messageId(self.groupId, 90), timestamp: 900)),
            SparseMessageList.State.Item(index: 3, content: .message(message: SparseFixtures.message(self.groupId, 50, timestamp: 500), isLocal: false))
        ], totalCount: 4, isLoading: false)
    }

    func testWithoutAGroupTheChannelPassesThrough() {
        let merged = mergedSparseMessageListState(main: self.channelState, mainCountIsFinal: true, legacy: nil, holdForLegacyFocus: false)
        XCTAssertEqual(SparseFixtures.summary(merged), SparseFixtures.summary(self.channelState))
    }

    func testNothingIsPublishedBeforeTheChannel() {
        XCTAssertNil(mergedSparseMessageListState(main: nil, mainCountIsFinal: true, legacy: self.groupState, holdForLegacyFocus: false))
    }

    func testGroupFollowsTheChannel() {
        let merged = mergedSparseMessageListState(main: self.channelState, mainCountIsFinal: true, legacy: self.groupState, holdForLegacyFocus: false)
        XCTAssertEqual(SparseFixtures.summary(merged), SparseFixtures.Summary(
            cells: [
                .message(index: 0, id: SparseFixtures.messageId(self.channelId, 20), isLocal: true),
                .placeholder(index: 5, id: SparseFixtures.messageId(self.channelId, 10)),
                .placeholder(index: 8, id: SparseFixtures.messageId(self.groupId, 90)),
                .message(index: 11, id: SparseFixtures.messageId(self.groupId, 50), isLocal: false)
            ],
            totalCount: 12,
            isLoading: false
        ))
    }

    func testGroupWaitsWhileTheChannelLoads() {
        // The channel's count is the group's offset, and it is not known while the channel
        // loads. The channel's own state is shown as it is, never replaced by an empty one.
        let channelLoading = SparseMessageList.State(items: [
            SparseMessageList.State.Item(index: 0, content: .placeholder(id: SparseFixtures.messageId(self.channelId, 10), timestamp: 1000))
        ], totalCount: 3, isLoading: true)
        let merged = mergedSparseMessageListState(main: channelLoading, mainCountIsFinal: true, legacy: self.groupState, holdForLegacyFocus: false)
        XCTAssertEqual(SparseFixtures.summary(merged), SparseFixtures.summary(channelLoading))
    }

    func testGroupFocusHoldsUntilBothListsSettle() {
        let unsettled: [(SparseMessageList.State?, SparseMessageList.State?)] = [
            (nil, nil),
            (self.channelState, nil),
            (self.channelState, self.loading),
            (self.loading, self.groupState)
        ]
        for (main, legacy) in unsettled {
            let merged = mergedSparseMessageListState(main: main, mainCountIsFinal: true, legacy: legacy, holdForLegacyFocus: true)
            XCTAssertEqual(SparseFixtures.summary(merged), SparseFixtures.summary(self.loading))
        }

        let settled = mergedSparseMessageListState(main: self.channelState, mainCountIsFinal: true, legacy: self.groupState, holdForLegacyFocus: true)
        XCTAssertEqual(settled?.totalCount, 12)
        XCTAssertEqual(settled?.isLoading, false)
    }

    func testGroupWaitsForTheChannelsServerList() {
        // Until the channel's positions arrive its count is only its local messages, not yet
        // the group's offset: the group would be drawn right after them and jump away later.
        let merged = mergedSparseMessageListState(main: self.channelState, mainCountIsFinal: false, legacy: self.groupState, holdForLegacyFocus: false)
        XCTAssertEqual(SparseFixtures.summary(merged), SparseFixtures.summary(self.channelState))

        let held = mergedSparseMessageListState(main: self.channelState, mainCountIsFinal: false, legacy: self.groupState, holdForLegacyFocus: true)
        XCTAssertEqual(SparseFixtures.summary(held), SparseFixtures.summary(self.loading))
    }

    func testGroupStoredMediaLeadsWhenTheChannelHasNone() {
        // `SparseItemGrid` asks for holes only once some cell holds a loaded message, so a list of
        // placeholders alone never loads. A just-upgraded channel has no media of its own; the
        // group's list must then start with its stored messages, as the channel's always does.
        let stored = [
            SparseFixtures.message(self.groupId, 12413, timestamp: 3000),
            SparseFixtures.message(self.groupId, 12412, timestamp: 2000),
            SparseFixtures.message(self.groupId, 12411, timestamp: 1000)
        ]
        let skeleton = sparseMessageSkeleton(
            peerId: self.groupId,
            positions: [
                SparseMessagePosition(id: 12413, date: 3000, offset: 0),
                SparseMessagePosition(id: 12412, date: 2000, offset: 1),
                SparseMessagePosition(id: 12411, date: 1000, offset: 2)
            ],
            totalCount: 3,
            includeLeadingRange: false
        )
        let groupLayout = sparseMessageListSegmentItems(peerId: self.groupId, topMessages: stored, skeleton: skeleton)
        let groupState = SparseMessageList.State(items: groupLayout.items, totalCount: groupLayout.totalCount, isLoading: false)
        let channelState = SparseMessageList.State(items: [], totalCount: 0, isLoading: false)

        let merged = mergedSparseMessageListState(main: channelState, mainCountIsFinal: true, legacy: groupState, holdForLegacyFocus: false)

        XCTAssertEqual(SparseFixtures.summary(merged), SparseFixtures.Summary(
            cells: [
                .message(index: 0, id: SparseFixtures.messageId(self.groupId, 12413), isLocal: true),
                .message(index: 1, id: SparseFixtures.messageId(self.groupId, 12412), isLocal: true),
                .message(index: 2, id: SparseFixtures.messageId(self.groupId, 12411), isLocal: true)
            ],
            totalCount: 3,
            isLoading: false
        ))
    }

    // MARK: - When the channel's count is final

    func testAChannelsCountIsFinalOnceItsServerListArrives() {
        XCTAssertTrue(sparseMessageListSegmentCountIsFinal(peerId: self.channelId, topMessages: [], skeleton: SparseMessageSkeleton(items: [])))
    }

    func testAChannelsCountIsNotFinalWhileItsLocalWindowStopsShortOfTheGroup() {
        let top = [SparseFixtures.message(self.channelId, 20, timestamp: 2000), SparseFixtures.message(self.channelId, 10, timestamp: 1000)]
        XCTAssertFalse(sparseMessageListSegmentCountIsFinal(peerId: self.channelId, topMessages: top, skeleton: nil))
    }

    func testAChannelsCountIsFinalWhenItsLocalWindowReachesTheGroup() {
        // Every group message predates every channel message, and a history view stops at a gap:
        // a window that reaches the group holds the channel's whole history.
        let top = [SparseFixtures.message(self.channelId, 20, timestamp: 2000), SparseFixtures.message(self.groupId, 90, timestamp: 900)]
        XCTAssertTrue(sparseMessageListSegmentCountIsFinal(peerId: self.channelId, topMessages: top, skeleton: nil))
    }

    func testAJustUpgradedChannelShowsTheGroupsStoredMediaOffline() {
        // No server list for either peer (offline). The channel's `.associated` window holds only
        // the group's stored media, so the channel has none of its own, and that is final.
        let stored = [
            SparseFixtures.message(self.groupId, 12413, timestamp: 3000),
            SparseFixtures.message(self.groupId, 12412, timestamp: 2000),
            SparseFixtures.message(self.groupId, 12411, timestamp: 1000)
        ]
        let channelLayout = sparseMessageListSegmentItems(peerId: self.channelId, topMessages: stored, skeleton: nil)
        let channelState = SparseMessageList.State(items: channelLayout.items, totalCount: channelLayout.totalCount, isLoading: false)
        let groupLayout = sparseMessageListSegmentItems(peerId: self.groupId, topMessages: stored, skeleton: nil)
        let groupState = SparseMessageList.State(items: groupLayout.items, totalCount: groupLayout.totalCount, isLoading: false)

        let merged = mergedSparseMessageListState(
            main: channelState,
            mainCountIsFinal: sparseMessageListSegmentCountIsFinal(peerId: self.channelId, topMessages: stored, skeleton: nil),
            legacy: groupState,
            holdForLegacyFocus: false
        )

        XCTAssertEqual(SparseFixtures.summary(merged), SparseFixtures.Summary(
            cells: [
                .message(index: 0, id: SparseFixtures.messageId(self.groupId, 12413), isLocal: true),
                .message(index: 1, id: SparseFixtures.messageId(self.groupId, 12412), isLocal: true),
                .message(index: 2, id: SparseFixtures.messageId(self.groupId, 12411), isLocal: true)
            ],
            totalCount: 3,
            isLoading: false
        ))
    }

    // MARK: - Hole requests at the boundary

    private func skeleton(_ items: [SparseMessageSkeleton.Item]) -> SparseMessageSkeleton {
        return SparseMessageSkeleton(items: items)
    }

    private func anchor(_ peerId: PeerId, _ id: Int32) -> SparseMessageSkeleton.Item {
        return .anchor(id: SparseFixtures.messageId(peerId, id), timestamp: id, message: nil)
    }

    /// The channel's server list ending in a run after its last known position.
    private var channelWithTail: SparseMessageSkeleton {
        return self.skeleton([self.anchor(self.channelId, 20), .range(count: 3), self.anchor(self.channelId, 10), .range(count: 2)])
    }

    private var channelWithoutTail: SparseMessageSkeleton {
        return self.skeleton([self.anchor(self.channelId, 20), .range(count: 3), self.anchor(self.channelId, 10)])
    }

    /// The group's server list starting with a run before its first known position.
    private var groupWithHead: SparseMessageSkeleton {
        return self.skeleton([.range(count: 4), self.anchor(self.groupId, 90), .range(count: 5), self.anchor(self.groupId, 50)])
    }

    private var groupWithoutHead: SparseMessageSkeleton {
        return self.skeleton([self.anchor(self.groupId, 90), .range(count: 5), self.anchor(self.groupId, 50)])
    }

    func testGroupHeadRequestLoadsTheChannelsTailFirst() {
        // A missing cell in the channel's tail can be nearer the group's first anchor; the
        // group's load never reaches the channel's cells, and the grid asks again at once.
        let target = sparseMessageListHoleAnchor(requested: SparseFixtures.messageId(self.groupId, 90), main: self.channelWithTail, legacy: self.groupWithHead)
        XCTAssertEqual(target, SparseFixtures.messageId(self.channelId, 10))
    }

    func testChannelTailRequestLoadsTheGroupsHeadFirst() {
        let target = sparseMessageListHoleAnchor(requested: SparseFixtures.messageId(self.channelId, 10), main: self.channelWithoutTail, legacy: self.groupWithHead)
        XCTAssertEqual(target, SparseFixtures.messageId(self.groupId, 90))
    }

    func testLoadedEdgesLeaveBoundaryRequestsAlone() {
        XCTAssertEqual(sparseMessageListHoleAnchor(requested: SparseFixtures.messageId(self.groupId, 90), main: self.channelWithoutTail, legacy: self.groupWithoutHead), SparseFixtures.messageId(self.groupId, 90))
        XCTAssertEqual(sparseMessageListHoleAnchor(requested: SparseFixtures.messageId(self.channelId, 10), main: self.channelWithoutTail, legacy: self.groupWithoutHead), SparseFixtures.messageId(self.channelId, 10))
    }

    func testRequestsAwayFromTheBoundaryAreUnchanged() {
        XCTAssertEqual(sparseMessageListHoleAnchor(requested: SparseFixtures.messageId(self.channelId, 20), main: self.channelWithTail, legacy: self.groupWithHead), SparseFixtures.messageId(self.channelId, 20))
        XCTAssertEqual(sparseMessageListHoleAnchor(requested: SparseFixtures.messageId(self.groupId, 50), main: self.channelWithTail, legacy: self.groupWithHead), SparseFixtures.messageId(self.groupId, 50))
    }

    func testWithoutAGroupRequestsAreUnchanged() {
        XCTAssertEqual(sparseMessageListHoleAnchor(requested: SparseFixtures.messageId(self.channelId, 10), main: self.channelWithTail, legacy: nil), SparseFixtures.messageId(self.channelId, 10))
    }

    func testAChannelTailBehindALoadedAnchorDoesNotTakeGroupRequests() {
        // The walk from a loaded last anchor could not take the run after it (longer than one
        // load), so loading there again makes no progress; the group's request is loaded instead.
        let loaded = SparseFixtures.message(self.channelId, 10, timestamp: 10)
        let channel = self.skeleton([self.anchor(self.channelId, 20), .range(count: 3), .anchor(id: loaded.id, timestamp: 10, message: loaded), .range(count: 200)])
        let target = sparseMessageListHoleAnchor(requested: SparseFixtures.messageId(self.groupId, 90), main: channel, legacy: self.groupWithHead)
        XCTAssertEqual(target, SparseFixtures.messageId(self.groupId, 90))
    }

    func testAGroupHeadBehindALoadedAnchorDoesNotTakeChannelRequests() {
        let loaded = SparseFixtures.message(self.groupId, 90, timestamp: 90)
        let group = self.skeleton([.range(count: 200), .anchor(id: loaded.id, timestamp: 90, message: loaded), .range(count: 5), self.anchor(self.groupId, 50)])
        let target = sparseMessageListHoleAnchor(requested: SparseFixtures.messageId(self.channelId, 10), main: self.channelWithoutTail, legacy: group)
        XCTAssertEqual(target, SparseFixtures.messageId(self.channelId, 10))
    }
}
