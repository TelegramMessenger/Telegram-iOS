import XCTest
import Postbox
@testable import TelegramCore

/// The decisions `SparseMessageList` makes between its two segments: where an initial focus goes,
/// what a change of the channel's migrated-from group does, when a held focus is let go, and which
/// segment a hole request loads in.
final class SparseMessageListWiringTests: XCTestCase {
    private let channelId = SparseFixtures.channelId
    private let groupId = SparseFixtures.groupId
    private let otherGroupId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(3))

    private func index(_ peerId: PeerId, _ id: Int32) -> MessageIndex {
        return MessageIndex(id: SparseFixtures.messageId(peerId, id), timestamp: id)
    }

    // MARK: - Initial focus

    func testAFocusOnTheChannelsOwnMessageGoesToItsSegment() {
        let focus = self.index(self.channelId, 5)
        XCTAssertEqual(sparseMessageListFocus(initialMessageIndex: focus, peerId: self.channelId, threadId: nil), SparseMessageListFocus(main: focus, legacy: nil))
    }

    func testAFocusOnAnotherChatsMessageWaitsForTheGroupSegment() {
        let focus = self.index(self.groupId, 5)
        XCTAssertEqual(sparseMessageListFocus(initialMessageIndex: focus, peerId: self.channelId, threadId: nil), SparseMessageListFocus(main: nil, legacy: focus))
    }

    func testInAThreadAFocusOnAnotherChatsMessageIsDropped() {
        // A thread has no migrated-from group to hold it.
        XCTAssertEqual(sparseMessageListFocus(initialMessageIndex: self.index(self.groupId, 5), peerId: self.channelId, threadId: 1), SparseMessageListFocus(main: nil, legacy: nil))
    }

    func testWithoutAFocusNeitherSegmentHasOne() {
        XCTAssertEqual(sparseMessageListFocus(initialMessageIndex: nil, peerId: self.channelId, threadId: nil), SparseMessageListFocus(main: nil, legacy: nil))
    }

    // MARK: - The channel's migrated-from group changes

    func testAGroupNamedForTheFirstTimeGetsASegmentWithItsFocus() {
        let focus = self.index(self.groupId, 5)
        XCTAssertEqual(sparseMessageListLegacyPeerChange(currentPeerId: nil, updatedPeerId: self.groupId, focus: focus), SparseMessageListLegacyPeerChange(replacesSegment: true, focus: focus))
    }

    func testAFocusTheCachedDataNamesNoGroupForIsDropped() {
        // The list must not wait for a group that is not coming.
        XCTAssertEqual(sparseMessageListLegacyPeerChange(currentPeerId: nil, updatedPeerId: nil, focus: self.index(self.groupId, 5)), SparseMessageListLegacyPeerChange(replacesSegment: false, focus: nil))
    }

    func testAFocusOnAnotherGroupIsDropped() {
        XCTAssertEqual(sparseMessageListLegacyPeerChange(currentPeerId: nil, updatedPeerId: self.groupId, focus: self.index(self.otherGroupId, 5)), SparseMessageListLegacyPeerChange(replacesSegment: true, focus: nil))
    }

    func testTheSameGroupAgainChangesNothing() {
        XCTAssertEqual(sparseMessageListLegacyPeerChange(currentPeerId: self.groupId, updatedPeerId: self.groupId, focus: nil), SparseMessageListLegacyPeerChange(replacesSegment: false, focus: nil))
    }

    func testLosingTheGroupReplacesItsSegment() {
        XCTAssertEqual(sparseMessageListLegacyPeerChange(currentPeerId: self.groupId, updatedPeerId: nil, focus: nil), SparseMessageListLegacyPeerChange(replacesSegment: true, focus: nil))
    }

    // MARK: - Releasing a held focus

    func testAHeldFocusIsReleasedByTheFirstSettledState() {
        // The pane looks for its focus in the first state that is not loading; afterwards a
        // reload of either list must show what it has rather than hold the grid empty again.
        let focus = self.index(self.groupId, 5)
        let loading = SparseMessageList.State(items: [], totalCount: 0, isLoading: true)
        let settled = SparseMessageList.State(items: [], totalCount: 3, isLoading: false)
        XCTAssertEqual(sparseMessageListHeldFocus(afterPublishing: loading, focus: focus), focus)
        XCTAssertNil(sparseMessageListHeldFocus(afterPublishing: settled, focus: focus))
    }

    // MARK: - Hole requests

    private func skeleton(_ items: [SparseMessageSkeleton.Item]) -> SparseMessageSkeleton {
        return SparseMessageSkeleton(items: items)
    }

    private func anchor(_ peerId: PeerId, _ id: Int32) -> SparseMessageSkeleton.Item {
        return .anchor(id: SparseFixtures.messageId(peerId, id), timestamp: id, message: nil)
    }

    func testAChannelAnchorLoadsInTheChannelSegment() {
        let target = sparseMessageListHoleTarget(requested: SparseFixtures.messageId(self.channelId, 20), mainPeerId: self.channelId, mainSkeleton: self.skeleton([self.anchor(self.channelId, 20)]), legacyPeerId: self.groupId, legacySkeleton: self.skeleton([self.anchor(self.groupId, 90)]))
        XCTAssertEqual(target, SparseMessageListHoleTarget(segment: .main, anchor: SparseFixtures.messageId(self.channelId, 20)))
    }

    func testAGroupAnchorLoadsInTheGroupSegment() {
        let target = sparseMessageListHoleTarget(requested: SparseFixtures.messageId(self.groupId, 50), mainPeerId: self.channelId, mainSkeleton: self.skeleton([self.anchor(self.channelId, 20)]), legacyPeerId: self.groupId, legacySkeleton: self.skeleton([self.anchor(self.groupId, 90), .range(count: 2), self.anchor(self.groupId, 50)]))
        XCTAssertEqual(target, SparseMessageListHoleTarget(segment: .legacy, anchor: SparseFixtures.messageId(self.groupId, 50)))
    }

    func testAnAnchorOfAGroupWithoutASegmentLoadsNothing() {
        // The anchor outlived its segment (the group was replaced or dropped).
        let target = sparseMessageListHoleTarget(requested: SparseFixtures.messageId(self.groupId, 50), mainPeerId: self.channelId, mainSkeleton: self.skeleton([self.anchor(self.channelId, 20)]), legacyPeerId: nil, legacySkeleton: nil)
        XCTAssertNil(target)
    }

    func testABoundaryRequestIsRoutedWhereTheRedirectSends() {
        let target = sparseMessageListHoleTarget(requested: SparseFixtures.messageId(self.groupId, 90), mainPeerId: self.channelId, mainSkeleton: self.skeleton([self.anchor(self.channelId, 20), .range(count: 2)]), legacyPeerId: self.groupId, legacySkeleton: self.skeleton([self.anchor(self.groupId, 90)]))
        XCTAssertEqual(target, SparseMessageListHoleTarget(segment: .main, anchor: SparseFixtures.messageId(self.channelId, 20)))
    }
}
