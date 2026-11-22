import Foundation
import XCTest
import SwiftSignalKit
import Postbox
import TelegramApi
@testable import TelegramCore

/// G2's edge cases, pinned as today's safe behaviour. A seq range is `(end, count)` (`updatesCombined`:
/// `(seq, seq - seqStart + 1)`, UpdateMessageService.swift) and is applied only when `local == end - count`,
/// skipped when `local >= end`, a hole otherwise (`finalStateWithUpdateGroups`, Sync/SyncSequencing.swift). So a
/// container that starts at or below the local seq but ends above it, and one with `seq_start == 0`, are holes:
/// the gap wait and one getDifference, which fetches whatever they carried, where core.telegram.org/api/updates
/// would ignore them. Costly but safe; a change to either rule changes these pins on purpose.
final class SeqContainerEdgeTests: StateSyncTestCase {
    /// Pushes `container` and returns once the gap wait has ended in its getDifference and that cycle finished.
    private func pushHoleAndSettle(_ container: Api.Updates, file: StaticString = #filePath, line: UInt = #line) {
        self.server.push(container)
        self.isUpdating.wait(file: file, line: line, until: { $0 == [true, false, true, false] })
        self.drainOperationQueue(file: file, line: line)
    }

    /// `seqStart <= local < seq`: 10...11 with local seq 10 overlaps what is applied. Treated as a hole: one
    /// getDifference from the stored state, whose seq and date are then stored.
    func testUpdatesCombinedOverlappingTheLocalSeqIsAHole() {
        self.seedUserChat(200)
        self.launchIdle(state: self.state(pts: 100, seq: 10))
        self.server.on(Name.getDifference, .result(StateSyncApi.differenceEmpty(date: self.baseDate + 3, seq: 11)))

        self.pushHoleAndSettle(StateSyncApi.updatesCombined([StateSyncApi.updateUserTyping(userId: 200)], date: self.baseDate + 2, seqStart: 10, seq: 11))

        XCTAssertEqual(self.server.requestNames, [Name.getDifference, Name.getDifference])
        self.assertGetDifference(1, pts: 100, date: self.baseDate + 1, qts: 5)
        XCTAssertEqual(self.fixture.accountState()?.state, self.state(pts: 100, qts: 5, date: self.baseDate + 3, seq: 11))
    }

    /// `seq_start == 0` with `seq == 11` and local seq 10: the range is `(11, 12)`, so `10 == 11 - 12` fails and
    /// the container is a hole too: one getDifference from the stored state. (`seq == 0` is the other case: no
    /// seq range at all, a date group, applied at once.)
    func testUpdatesCombinedWithSeqStartZeroIsAHole() {
        self.seedUserChat(200)
        self.launchIdle(state: self.state(pts: 100, seq: 10))
        self.server.on(Name.getDifference, .result(StateSyncApi.differenceEmpty(date: self.baseDate + 3, seq: 11)))

        self.pushHoleAndSettle(StateSyncApi.updatesCombined([StateSyncApi.updateUserTyping(userId: 200)], date: self.baseDate + 2, seqStart: 0, seq: 11))

        XCTAssertEqual(self.server.requestNames, [Name.getDifference, Name.getDifference])
        self.assertGetDifference(1, pts: 100, date: self.baseDate + 1, qts: 5)
        XCTAssertEqual(self.fixture.accountState()?.state, self.state(pts: 100, qts: 5, date: self.baseDate + 3, seq: 11))
    }
}
