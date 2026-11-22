import XCTest
import Postbox
@testable import TelegramCore

/// One peer's shared-media list: the server skeleton, and the layout joining it with the local
/// newest messages (the top section).
final class SparseMessageListLayoutTests: XCTestCase {
    private let channelId = SparseFixtures.channelId
    private let groupId = SparseFixtures.groupId

    /// The channel's messages `ids`, newest first, as the local top section holds them.
    private func channelMessages(_ ids: ClosedRange<Int32>) -> [Message] {
        return ids.reversed().map { SparseFixtures.message(self.channelId, $0, timestamp: 1_000_000 + $0) }
    }

    func testSkeletonKeepsTheLeadingRangeWhenAsked() {
        // Positions arrive in any order; the skeleton is newest first.
        let skeleton = sparseMessageSkeleton(
            peerId: self.groupId,
            positions: [
                SparseMessagePosition(id: 50, date: 500, offset: 20),
                SparseMessagePosition(id: 90, date: 900, offset: 5)
            ],
            totalCount: 30,
            includeLeadingRange: true
        )
        XCTAssertEqual(skeleton.items, [
            .range(count: 5),
            .anchor(id: SparseFixtures.messageId(self.groupId, 90), timestamp: 900, message: nil),
            .range(count: 14),
            .anchor(id: SparseFixtures.messageId(self.groupId, 50), timestamp: 500, message: nil),
            .range(count: 9)
        ])
    }

    func testSkeletonLeavesTheLeadingRangeToTheTopSection() {
        let skeleton = sparseMessageSkeleton(
            peerId: self.groupId,
            positions: [
                SparseMessagePosition(id: 90, date: 900, offset: 5),
                SparseMessagePosition(id: 50, date: 500, offset: 20)
            ],
            totalCount: 30,
            includeLeadingRange: false
        )
        XCTAssertEqual(skeleton.items, [
            .anchor(id: SparseFixtures.messageId(self.groupId, 90), timestamp: 900, message: nil),
            .range(count: 14),
            .anchor(id: SparseFixtures.messageId(self.groupId, 50), timestamp: 500, message: nil),
            .range(count: 9)
        ])
    }

    func testSkeletonWithoutPositionsIsEmpty() {
        let skeleton = sparseMessageSkeleton(peerId: self.groupId, positions: [], totalCount: 0, includeLeadingRange: true)
        XCTAssertEqual(skeleton.items, [])
    }

    func testRangeStraddlingTheTopSectionCountsOnlyItsOverflow() {
        // 180 local messages; the server knows positions 0, 150 and 300 of 301.
        let top = self.channelMessages(821 ... 1000)
        let skeleton = sparseMessageSkeleton(
            peerId: self.channelId,
            positions: [
                SparseMessagePosition(id: 1000, date: 0, offset: 0),
                SparseMessagePosition(id: 850, date: 0, offset: 150),
                SparseMessagePosition(id: 700, date: 0, offset: 300)
            ],
            totalCount: 301,
            includeLeadingRange: false
        )

        let layout = sparseMessageListSegmentItems(peerId: self.channelId, topMessages: top, skeleton: skeleton)

        // The run 151...299 straddles the top section's end. Before the fix it added all 149
        // messages instead of the 120 past the top section, putting position 300 at index 329.
        XCTAssertEqual(layout.totalCount, 301)
        XCTAssertEqual(layout.items.count, 181)
        XCTAssertEqual(SparseFixtures.cells(Array(layout.items.suffix(1))), [
            .placeholder(index: 300, id: SparseFixtures.messageId(self.channelId, 700))
        ])
    }

    func testRangesInsideTheTopSectionAddNothing() {
        // 100 local messages; the server knows positions 0, 40 and 100 of 150.
        let top = self.channelMessages(901 ... 1000)
        let skeleton = sparseMessageSkeleton(
            peerId: self.channelId,
            positions: [
                SparseMessagePosition(id: 1000, date: 0, offset: 0),
                SparseMessagePosition(id: 960, date: 0, offset: 40),
                SparseMessagePosition(id: 900, date: 0, offset: 100)
            ],
            totalCount: 150,
            includeLeadingRange: false
        )

        let layout = sparseMessageListSegmentItems(peerId: self.channelId, topMessages: top, skeleton: skeleton)

        XCTAssertEqual(layout.totalCount, 150)
        XCTAssertEqual(layout.items.count, 101)
        XCTAssertEqual(SparseFixtures.cells(Array(layout.items.prefix(1))), [
            .message(index: 0, id: SparseFixtures.messageId(self.channelId, 1000), isLocal: true)
        ])
        XCTAssertEqual(SparseFixtures.cells(Array(layout.items.suffix(1))), [
            .placeholder(index: 100, id: SparseFixtures.messageId(self.channelId, 900))
        ])
    }

    func testLoadedAnchorsAreRemoteMessages() {
        let loaded = SparseFixtures.message(self.groupId, 90, timestamp: 900)
        let skeleton = SparseMessageSkeleton(items: [
            .anchor(id: loaded.id, timestamp: 900, message: loaded),
            .range(count: 3),
            .anchor(id: SparseFixtures.messageId(self.groupId, 50), timestamp: 500, message: nil)
        ])

        let layout = sparseMessageListSegmentItems(peerId: self.groupId, topMessages: [], skeleton: skeleton)

        XCTAssertEqual(layout.totalCount, 5)
        XCTAssertEqual(SparseFixtures.cells(layout.items), [
            .message(index: 0, id: loaded.id, isLocal: false),
            .placeholder(index: 4, id: SparseFixtures.messageId(self.groupId, 50))
        ])
    }

    func testTopSectionIgnoresTheMigratedGroupsMessages() {
        // Postbox turns the channel's history view into its `.associated` merge with the group
        // on the next cached-data write, so the top section can end with group messages.
        let top = self.channelMessages(8 ... 10) + [
            SparseFixtures.message(self.groupId, 70, timestamp: 70),
            SparseFixtures.message(self.groupId, 60, timestamp: 60)
        ]
        let skeleton = sparseMessageSkeleton(
            peerId: self.channelId,
            positions: [
                SparseMessagePosition(id: 10, date: 0, offset: 0),
                SparseMessagePosition(id: 8, date: 0, offset: 2)
            ],
            totalCount: 3,
            includeLeadingRange: false
        )

        let layout = sparseMessageListSegmentItems(peerId: self.channelId, topMessages: top, skeleton: skeleton)

        XCTAssertEqual(layout.totalCount, 3)
        XCTAssertEqual(SparseFixtures.cells(layout.items), [
            .message(index: 0, id: SparseFixtures.messageId(self.channelId, 10), isLocal: true),
            .message(index: 1, id: SparseFixtures.messageId(self.channelId, 9), isLocal: true),
            .message(index: 2, id: SparseFixtures.messageId(self.channelId, 8), isLocal: true)
        ])
    }
}
