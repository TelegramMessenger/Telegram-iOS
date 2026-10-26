import XCTest
import Postbox
@testable import TelegramCore

/// The media calendar's paging over a channel and the group it was migrated from.
final class SparseCalendarPagingTests: XCTestCase {
    private let channelId = SparseFixtures.channelId
    private let groupId = SparseFixtures.groupId
    private let day: Int32 = 86_400 * 20_000

    private func entry(_ peerId: PeerId, _ id: Int32, timestamp: Int32, count: Int) -> SparseMessageCalendar.Entry {
        return SparseMessageCalendar.Entry(message: SparseFixtures.message(peerId, id, timestamp: timestamp), count: count)
    }

    private func page(_ peerId: PeerId, nextOffset: Int32?, days: [Int32: SparseMessageCalendar.Entry] = [:], bounds: SparseCalendarPeerBounds? = nil) -> SparseCalendarPagingState.Page {
        return SparseCalendarPagingState.Page(peerId: peerId, messagesByDay: days, nextOffset: nextOffset, bounds: bounds)
    }

    func testFirstLoadAsksEveryPeer() {
        // The calendar screen reads `minTimestamp` once, so the group's must be known with the
        // channel's.
        let state = SparseCalendarPagingState(mainPeerId: self.channelId)
        XCTAssertTrue(state.hasMore)
        XCTAssertEqual(state.requests(peerIds: [self.channelId, self.groupId]), [
            SparseCalendarPagingState.Request(peerId: self.channelId, offset: 0),
            SparseCalendarPagingState.Request(peerId: self.groupId, offset: 0)
        ])
    }

    func testLaterLoadsPageTheChannelToItsEndFirst() {
        var state = SparseCalendarPagingState(mainPeerId: self.channelId)
        state.apply(peerIds: [self.channelId, self.groupId], pages: [
            self.page(self.channelId, nextOffset: 500),
            self.page(self.groupId, nextOffset: 70)
        ])
        XCTAssertEqual(state.requests(peerIds: [self.channelId, self.groupId]), [
            SparseCalendarPagingState.Request(peerId: self.channelId, offset: 500)
        ])

        state.apply(peerIds: [self.channelId, self.groupId], pages: [self.page(self.channelId, nextOffset: nil)])
        XCTAssertEqual(state.requests(peerIds: [self.channelId, self.groupId]), [
            SparseCalendarPagingState.Request(peerId: self.groupId, offset: 70)
        ])

        state.apply(peerIds: [self.channelId, self.groupId], pages: [self.page(self.groupId, nextOffset: nil)])
        XCTAssertFalse(state.hasMore)
        XCTAssertEqual(state.requests(peerIds: [self.channelId, self.groupId]), [])
    }

    func testAPeerThatCannotBeRequestedIsClosed() {
        // Without a peer record nothing can be requested. An open cursor would keep `hasMore`
        // true, and the calendar screen calls `loadMore` again whenever a load ends.
        var state = SparseCalendarPagingState(mainPeerId: self.channelId)
        state.apply(peerIds: [], pages: [])
        XCTAssertFalse(state.hasMore)
    }

    func testAGroupFoundLaterStartsAtItsNewestMessage() {
        var state = SparseCalendarPagingState(mainPeerId: self.channelId)
        state.apply(peerIds: [self.channelId], pages: [self.page(self.channelId, nextOffset: 500)])
        XCTAssertEqual(state.requests(peerIds: [self.channelId, self.groupId]), [
            SparseCalendarPagingState.Request(peerId: self.channelId, offset: 500)
        ])

        state.apply(peerIds: [self.channelId, self.groupId], pages: [self.page(self.channelId, nextOffset: nil)])
        XCTAssertEqual(state.requests(peerIds: [self.channelId, self.groupId]), [
            SparseCalendarPagingState.Request(peerId: self.groupId, offset: 0)
        ])
    }

    func testMigrationDayCountsBothPeersAndShowsTheOlderMessage() {
        let previousDay = self.day - 86_400
        var state = SparseCalendarPagingState(mainPeerId: self.channelId)
        state.apply(peerIds: [self.channelId, self.groupId], pages: [
            self.page(self.channelId, nextOffset: nil, days: [
                self.day: self.entry(self.channelId, 5, timestamp: self.day + 500, count: 3)
            ]),
            self.page(self.groupId, nextOffset: nil, days: [
                self.day: self.entry(self.groupId, 900, timestamp: self.day + 100, count: 2),
                previousDay: self.entry(self.groupId, 800, timestamp: previousDay + 100, count: 4)
            ])
        ])

        let days = state.messagesByDay
        XCTAssertEqual(days.count, 2)
        XCTAssertEqual(days[self.day]?.count, 5)
        XCTAssertEqual(days[self.day]?.message.id, SparseFixtures.messageId(self.groupId, 900))
        XCTAssertEqual(days[previousDay]?.count, 4)
    }

    func testDayMergeDoesNotDependOnPeerOrder() {
        let channelDays = [self.day: self.entry(self.channelId, 5, timestamp: self.day + 500, count: 3)]
        let groupDays = [self.day: self.entry(self.groupId, 900, timestamp: self.day + 100, count: 2)]
        for merged in [mergedSparseCalendarDays([channelDays, groupDays]), mergedSparseCalendarDays([groupDays, channelDays])] {
            XCTAssertEqual(merged[self.day]?.count, 5)
            XCTAssertEqual(merged[self.day]?.message.id, SparseFixtures.messageId(self.groupId, 900))
        }
    }

    func testALaterPageOfTheSamePeerReplacesItsDay() {
        // Only days of different peers are added together; a period is never counted twice.
        var state = SparseCalendarPagingState(mainPeerId: self.channelId)
        state.apply(peerIds: [self.channelId], pages: [
            self.page(self.channelId, nextOffset: 500, days: [self.day: self.entry(self.channelId, 600, timestamp: self.day + 50, count: 3)])
        ])
        state.apply(peerIds: [self.channelId], pages: [
            self.page(self.channelId, nextOffset: nil, days: [self.day: self.entry(self.channelId, 550, timestamp: self.day + 10, count: 2)])
        ])
        XCTAssertEqual(state.messagesByDay[self.day]?.count, 2)
    }

    func testMinTimestampIgnoresAPeerWithoutMedia() {
        XCTAssertEqual(sparseCalendarMinTimestamp(mainPeerId: self.channelId, bounds: [
            self.channelId: SparseCalendarPeerBounds(minDate: 2000, count: 10),
            self.groupId: SparseCalendarPeerBounds(minDate: 1000, count: 5)
        ]), 1000)
        XCTAssertEqual(sparseCalendarMinTimestamp(mainPeerId: self.channelId, bounds: [
            self.channelId: SparseCalendarPeerBounds(minDate: 2000, count: 10),
            self.groupId: SparseCalendarPeerBounds(minDate: 0, count: 0)
        ]), 2000)
        // Nothing matches anywhere: the channel's value, as before there was a second peer.
        XCTAssertEqual(sparseCalendarMinTimestamp(mainPeerId: self.channelId, bounds: [
            self.channelId: SparseCalendarPeerBounds(minDate: 123, count: 0),
            self.groupId: SparseCalendarPeerBounds(minDate: 0, count: 0)
        ]), 123)
        XCTAssertNil(sparseCalendarMinTimestamp(mainPeerId: self.channelId, bounds: [:]))
    }
}
