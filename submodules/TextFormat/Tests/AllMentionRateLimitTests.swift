import Foundation
import XCTest
import Postbox
import TelegramUIPreferences

final class AllMentionRateLimitTests: XCTestCase {
    func testDisabledByDefaultAndCannotReserve() {
        let state = AllMentionGroupPermission()
        XCTAssertFalse(state.isEnabled)
        XCTAssertEqual(state.availableCalls(at: 1000), 0)
        XCTAssertNil(state.reservingCall(at: 1000))
    }

    func testThreeConsecutiveCallsThenFourthIsBlocked() throws {
        var state = AllMentionGroupPermission(isEnabled: true)
        for remaining in [2, 1, 0] {
            state = try XCTUnwrap(state.reservingCall(at: 1000))
            XCTAssertEqual(state.availableCalls(at: 1000), remaining)
        }
        XCTAssertEqual(state.burstResetsAt, 1300)
        XCTAssertEqual(state.remainingSeconds(at: 1000), 300)
        XCTAssertNil(state.reservingCall(at: 1000))
        XCTAssertNil(state.reservingCall(at: 1299.999))
    }

    func testBreakStartsAtThirdCall() throws {
        let first = try XCTUnwrap(AllMentionGroupPermission(isEnabled: true).reservingCall(at: 1000))
        let second = try XCTUnwrap(first.reservingCall(at: 1010))
        XCTAssertEqual(second.remainingSeconds(at: 1020), 0)
        let third = try XCTUnwrap(second.reservingCall(at: 1020.25))
        XCTAssertEqual(third.burstResetsAt, 1320.25)
        XCTAssertEqual(third.remainingSeconds(at: 1020.25), 300)
        XCTAssertEqual(third.remainingSeconds(at: 1319.26), 1)
        XCTAssertNil(third.reservingCall(at: 1320.249))
        XCTAssertNotNil(third.reservingCall(at: 1320.25))
    }

    func testExpirationRestoresCompleteBurstWithoutTimerMutation() throws {
        let exhausted = AllMentionGroupPermission(isEnabled: true, callsInBurst: 3, burstResetsAt: 1300)
        XCTAssertEqual(exhausted.availableCalls(at: 1300), 3)
        var state = try XCTUnwrap(exhausted.reservingCall(at: 5000))
        XCTAssertEqual(state.availableCalls(at: 5000), 2)
        XCTAssertEqual(state.burstResetsAt, 5300)
        state = try XCTUnwrap(state.reservingCall(at: 5000))
        state = try XCTUnwrap(state.reservingCall(at: 5000))
        XCTAssertEqual(state.burstResetsAt, 5300)
        XCTAssertNil(state.reservingCall(at: 5000))
    }

    func testPermissionTogglePreservesPartialBurstAndBreak() throws {
        let first = try XCTUnwrap(AllMentionGroupPermission(isEnabled: true).reservingCall(at: 1000))
        let disabled = first.withUpdatedIsEnabled(false)
        XCTAssertNil(disabled.reservingCall(at: 1001))
        let reenabled = disabled.withUpdatedIsEnabled(true)
        XCTAssertEqual(reenabled.availableCalls(at: 1001), 2)
        let exhausted = AllMentionGroupPermission(isEnabled: true, callsInBurst: 3, burstResetsAt: 1300)
        let toggled = exhausted.withUpdatedIsEnabled(false).withUpdatedIsEnabled(true)
        XCTAssertEqual(toggled, exhausted)
        XCTAssertNil(toggled.reservingCall(at: 1299))
        XCTAssertNotNil(toggled.reservingCall(at: 1300))
    }

    func testStoredStateRoundTripDoesNotRestoreQuota() throws {
        for state in [AllMentionGroupPermission(isEnabled: true, callsInBurst: 2, burstResetsAt: 1300), AllMentionGroupPermission(isEnabled: true, callsInBurst: 3, burstResetsAt: 1300.25)] {
            let data = try AdaptedPostboxEncoder().encode(state)
            let decoded = try AdaptedPostboxDecoder().decode(AllMentionGroupPermission.self, from: data)
            XCTAssertEqual(decoded, state)
            XCTAssertEqual(decoded.availableCalls(at: 1100), state.availableCalls(at: 1100))
        }
    }

    func testFiveMinutesOfSilenceStartsNewSeries() throws {
        let first = try XCTUnwrap(AllMentionGroupPermission(isEnabled: true).reservingCall(at: 1000))
        let second = try XCTUnwrap(first.reservingCall(at: 1180))
        XCTAssertEqual(second.availableCalls(at: 1479.999), 1)
        XCTAssertEqual(second.availableCalls(at: 1480), 3)
        let nextSeries = try XCTUnwrap(second.reservingCall(at: 1480))
        XCTAssertEqual(nextSeries.callsInBurst, 1)
        XCTAssertEqual(nextSeries.availableCalls(at: 1480), 2)
        XCTAssertEqual(nextSeries.remainingSeconds(at: 1480), 0)
        XCTAssertEqual(nextSeries.burstResetsAt, 1780)
        let afterOnlyOneCall = try XCTUnwrap(first.reservingCall(at: 1300))
        XCTAssertEqual(afterOnlyOneCall.callsInBurst, 1)
    }

    func testLegacyPreferenceMigration() throws {
        let enabled = try JSONDecoder().decode(AllMentionGroupPermission.self, from: Data("{\"isEnabled\":true}".utf8))
        XCTAssertEqual(enabled.availableCalls(at: 1000), 3)
        XCTAssertEqual(enabled.burstResetsAt, 0)
        let empty = try JSONDecoder().decode(AllMentionGroupPermission.self, from: Data("{}".utf8))
        XCTAssertFalse(empty.isEnabled)
    }
}
