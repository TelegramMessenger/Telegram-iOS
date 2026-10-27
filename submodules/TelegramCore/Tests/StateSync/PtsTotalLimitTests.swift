import Foundation
import XCTest
import SwiftSignalKit
import Postbox
import TelegramApi
@testable import TelegramCore

/// `pts_total_limit` on the main app's `updates.getDifference` (audit Q14; spec
/// `docs/superpowers/specs/2026-10-15-difference-too-long-design.md`, section 5). The value is the app-configuration
/// key `pts_total_limit`, read in the transaction that starts each poll (`currentPtsTotalLimit`): 10000 when the key
/// is absent, no limit (flags.0 clear) below 1, and it goes with every request of a chain, slices included.
final class PtsTotalLimitTests: StateSyncTestCase {
    /// With no `pts_total_limit` in the app configuration the request carries 10000 (flags.0 set).
    func testAbsentKeySendsTheDefaultLimit() {
        self.launchIdle()

        XCTAssertEqual(self.server.requestNames, [Name.getDifference])
        self.assertGetDifference(0, pts: 100, date: self.baseDate, qts: 5, ptsTotalLimit: 10000)
    }

    /// The configured value is sent as it is.
    func testConfiguredValueIsSent() {
        self.fixture.seedAppConfiguration(["pts_total_limit": 500])
        self.launchIdle()

        XCTAssertEqual(self.server.requestNames, [Name.getDifference])
        self.assertGetDifference(0, pts: 100, date: self.baseDate, qts: 5, ptsTotalLimit: 500)
    }

    /// Zero is the server's off switch: the request is the one sent before the limit existed, flags 0 and no limit.
    func testZeroSendsNoLimit() {
        self.fixture.seedAppConfiguration(["pts_total_limit": 0])
        self.launchIdle()

        XCTAssertEqual(self.server.requestNames, [Name.getDifference])
        self.assertGetDifference(0, pts: 100, date: self.baseDate, qts: 5, ptsTotalLimit: nil)
    }

    /// Every request of a slice chain carries the limit: the continuation is a poll of its own and reads the value
    /// in its own state transaction.
    func testEverySliceCarriesTheLimit() {
        self.fixture.seedAppConfiguration(["pts_total_limit": 500])
        self.fixture.seedAccount(state: self.state(pts: 100))
        self.makeStateManager()
        self.server.on(Name.getDifference, .result(StateSyncApi.differenceSlice(
            intermediateState: StateSyncApi.state(pts: 150, qts: 5, date: self.baseDate + 10, seq: 10)
        )))
        self.server.on(Name.getDifference, .result(StateSyncApi.difference(
            state: StateSyncApi.state(pts: 200, qts: 5, date: self.baseDate + 20, seq: 10)
        )))
        self.fixture.resetStateManager()

        self.isUpdating.wait { $0.last == false }
        self.drainOperationQueue()

        XCTAssertEqual(self.server.requestNames, [Name.getDifference, Name.getDifference])
        self.assertGetDifference(0, pts: 100, date: self.baseDate, qts: 5, ptsTotalLimit: 500)
        self.assertGetDifference(1, pts: 150, date: self.baseDate + 10, qts: 5, ptsTotalLimit: 500)
        XCTAssertEqual(self.fixture.accountState()?.state, self.state(pts: 200, qts: 5, date: self.baseDate + 20, seq: 10))
    }

    /// Each poll reads the value again, so a changed app configuration applies from the next poll on.
    func testEachPollReadsTheCurrentValue() {
        self.fixture.seedAppConfiguration(["pts_total_limit": 500])
        self.launchIdle()

        self.fixture.seedAppConfiguration(["pts_total_limit": 700])
        self.server.on(Name.getDifference, .result(StateSyncApi.differenceEmpty(date: self.baseDate + 2, seq: 10)))
        self.fixture.resetStateManager()
        XCTAssertTrue(self.server.waitForRequest(Name.getDifference, count: 2))
        self.drainOperationQueue()

        XCTAssertEqual(self.server.requestNames, [Name.getDifference, Name.getDifference])
        self.assertGetDifference(0, pts: 100, date: self.baseDate, qts: 5, ptsTotalLimit: 500)
        self.assertGetDifference(1, pts: 100, date: self.baseDate + 1, qts: 5, ptsTotalLimit: 700)
    }

    /// App-configuration numbers arrive as Double. A fraction is rounded toward zero, anything below 1 sends no limit,
    /// a value above Int32.max is capped, and a value that is not a number counts as absent (10000). One poll per
    /// value, each started by `reset()`.
    func testValuesAreNormalised() {
        self.launchIdle()

        let cases: [(value: Any, expected: Int32?)] = [
            (250.9, 250),
            (0.5, nil),
            (-5, nil),
            (1e12, Int32.max),
            ("100", 10000)
        ]
        for (offset, item) in cases.enumerated() {
            let index = offset + 1
            self.fixture.seedAppConfiguration(["pts_total_limit": item.value])
            self.server.on(Name.getDifference, .result(StateSyncApi.differenceEmpty(date: self.baseDate + 1, seq: 10)))
            self.fixture.resetStateManager()
            XCTAssertTrue(self.server.waitForRequest(Name.getDifference, count: index + 1))
            self.drainOperationQueue()
            self.assertGetDifference(index, pts: 100, date: self.baseDate + 1, qts: 5, ptsTotalLimit: item.expected)
        }
        XCTAssertEqual(self.server.requestNames.count, cases.count + 1)
    }
}

/// The notification extension's `standalonePollDifference` sends the same `pts_total_limit` as the app, read
/// before each request. On a larger gap the server answers differenceTooLong, which the extension leaves to the
/// app (Q3, pinned in NotificationExtensionPollCharacterizationTests).
final class PtsTotalLimitNotificationExtensionTests: StateSyncTestCase {
    override var fixtureProfile: StateSyncFixture.OpenProfile {
        return .notificationExtension
    }

    /// With no `pts_total_limit` in the app configuration the extension sends 10000.
    func testAbsentKeySendsTheDefaultLimit() {
        self.fixture.seedAccount(state: self.state(pts: 100, qts: 5, seq: 10))
        self.makeStateManager()
        self.server.on(Name.getDifference, .result(StateSyncApi.difference(
            state: StateSyncApi.state(pts: 150, qts: 5, date: self.baseDate + 10, seq: 10)
        )))

        XCTAssertEqual(self.fixture.wait(self.stateManager.standalonePollDifference()), true)

        XCTAssertEqual(self.server.requestNames, [Name.getDifference])
        self.assertGetDifference(0, pts: 100, date: Int32.max, qts: 5, ptsTotalLimit: 10000)
    }

    /// The configured value goes with every call, the one after a slice included.
    func testConfiguredValueIsSentOnEveryCall() {
        self.fixture.seedAppConfiguration(["pts_total_limit": 500])
        self.fixture.seedAccount(state: self.state(pts: 100, qts: 5, seq: 10))
        self.makeStateManager()
        self.server.on(Name.getDifference, .result(StateSyncApi.differenceSlice(
            intermediateState: StateSyncApi.state(pts: 150, qts: 6, date: self.baseDate + 10, seq: 11)
        )))
        self.server.on(Name.getDifference, .result(StateSyncApi.difference(
            state: StateSyncApi.state(pts: 200, qts: 7, date: self.baseDate + 20, seq: 12)
        )))

        XCTAssertEqual(self.fixture.wait(self.stateManager.standalonePollDifference()), false)
        XCTAssertEqual(self.fixture.wait(self.stateManager.standalonePollDifference()), true)

        XCTAssertEqual(self.server.requestNames, [Name.getDifference, Name.getDifference])
        self.assertGetDifference(0, pts: 100, date: Int32.max, qts: 5, ptsTotalLimit: 500)
        self.assertGetDifference(1, pts: 150, date: Int32.max, qts: 6, ptsTotalLimit: 500)
    }

    /// Zero sends no limit, as in the app.
    func testZeroSendsNoLimit() {
        self.fixture.seedAppConfiguration(["pts_total_limit": 0])
        self.fixture.seedAccount(state: self.state(pts: 100, qts: 5, seq: 10))
        self.makeStateManager()
        self.server.on(Name.getDifference, .result(StateSyncApi.difference(
            state: StateSyncApi.state(pts: 150, qts: 5, date: self.baseDate + 10, seq: 10)
        )))

        XCTAssertEqual(self.fixture.wait(self.stateManager.standalonePollDifference()), true)

        XCTAssertEqual(self.server.requestNames, [Name.getDifference])
        self.assertGetDifference(0, pts: 100, date: Int32.max, qts: 5, ptsTotalLimit: nil)
    }

    /// The gap is larger than the configured limit, so the server answers differenceTooLong: the extension
    /// reports the poll done and writes nothing (Q3), and the request carried the limit.
    func testDifferenceTooLongWithTheLimitSentReportsDoneAndWritesNothing() {
        self.fixture.seedAppConfiguration(["pts_total_limit": 500])
        self.fixture.seedAccount(state: self.state(pts: 100, qts: 5, seq: 10))
        self.makeStateManager()
        self.server.on(Name.getDifference, .result(StateSyncApi.differenceTooLong(pts: 999)))

        XCTAssertEqual(self.fixture.wait(self.stateManager.standalonePollDifference()), true)

        XCTAssertEqual(self.server.requestNames, [Name.getDifference])
        self.assertGetDifference(0, pts: 100, date: Int32.max, qts: 5, ptsTotalLimit: 500)
        XCTAssertEqual(self.fixture.accountState()?.state, self.state(pts: 100, qts: 5, seq: 10))
    }
}
