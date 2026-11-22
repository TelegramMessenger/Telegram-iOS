import Foundation
import XCTest
import SwiftSignalKit
import Postbox
import TelegramApi
@testable import TelegramCore

extension StateSyncFixture {
    /// Stores the Debug Settings state-sync settings that `currentPtsTotalLimit` reads.
    func seedStateSyncDebugSettings(_ settings: StateSyncDebugSettings) {
        self.transaction { transaction -> Void in
            transaction.setPreferencesEntry(key: PreferencesKeys.stateSyncDebugSettings, value: PreferencesEntry(settings))
        }
    }
}

/// The Debug Settings override of `pts_total_limit` (`StateSyncDebugSettings.ptsTotalLimitOverride`). DEBUG builds
/// send it instead of the app configuration's value; other builds ignore it. The test target is built in DEBUG
/// (`Make.py test` forces `debug_sim_arm64`); the `#else` branches keep each test meaningful in any other build.
final class PtsTotalLimitDebugOverrideTests: StateSyncTestCase {
    /// A set override wins over the app configuration.
    func testOverrideWinsOverAppConfiguration() {
        self.fixture.seedAppConfiguration(["pts_total_limit": 500])
        self.fixture.seedStateSyncDebugSettings(StateSyncDebugSettings(ptsTotalLimitOverride: 10))
        self.launchIdle()

        #if DEBUG
        let expected: Int32? = 10
        #else
        let expected: Int32? = 500
        #endif
        XCTAssertEqual(self.server.requestNames, [Name.getDifference])
        self.assertGetDifference(0, pts: 100, date: self.baseDate, qts: 5, ptsTotalLimit: expected)
    }

    /// An override below 1 ("No limit") sends no limit, whatever the app configuration says.
    func testOverrideBelowOneSendsNoLimit() {
        self.fixture.seedAppConfiguration(["pts_total_limit": 500])
        self.fixture.seedStateSyncDebugSettings(StateSyncDebugSettings(ptsTotalLimitOverride: 0))
        self.launchIdle()

        #if DEBUG
        let expected: Int32? = nil
        #else
        let expected: Int32? = 500
        #endif
        XCTAssertEqual(self.server.requestNames, [Name.getDifference])
        self.assertGetDifference(0, pts: 100, date: self.baseDate, qts: 5, ptsTotalLimit: expected)
    }

    /// Stored settings without an override ("App config") leave the app configuration in charge.
    func testSettingsWithoutOverrideKeepTheAppConfiguration() {
        self.fixture.seedAppConfiguration(["pts_total_limit": 500])
        self.fixture.seedStateSyncDebugSettings(StateSyncDebugSettings(ptsTotalLimitOverride: nil))
        self.launchIdle()

        XCTAssertEqual(self.server.requestNames, [Name.getDifference])
        self.assertGetDifference(0, pts: 100, date: self.baseDate, qts: 5, ptsTotalLimit: 500)
    }
}

/// The notification extension reads the limit through the same function, so the override reaches it too.
final class PtsTotalLimitDebugOverrideNotificationExtensionTests: StateSyncTestCase {
    override var fixtureProfile: StateSyncFixture.OpenProfile {
        return .notificationExtension
    }

    func testExtensionSendsTheOverride() {
        self.fixture.seedAppConfiguration(["pts_total_limit": 500])
        self.fixture.seedStateSyncDebugSettings(StateSyncDebugSettings(ptsTotalLimitOverride: 10))
        self.fixture.seedAccount(state: self.state(pts: 100, qts: 5, seq: 10))
        self.makeStateManager()
        self.server.on(Name.getDifference, .result(StateSyncApi.difference(
            state: StateSyncApi.state(pts: 150, qts: 5, date: self.baseDate + 10, seq: 10)
        )))

        XCTAssertEqual(self.fixture.wait(self.stateManager.standalonePollDifference()), true)

        #if DEBUG
        let expected: Int32? = 10
        #else
        let expected: Int32? = 500
        #endif
        XCTAssertEqual(self.server.requestNames, [Name.getDifference])
        self.assertGetDifference(0, pts: 100, date: Int32.max, qts: 5, ptsTotalLimit: expected)
    }
}

/// `StateSyncDebugSettings` is a new persisted preferences entry; every value it can hold survives a round trip.
final class StateSyncDebugSettingsCodingTests: XCTestCase {
    func testRoundTripsThroughAPreferencesEntry() {
        for value in [nil, 0, 10, Int32.max] as [Int32?] {
            let settings = StateSyncDebugSettings(ptsTotalLimitOverride: value)
            XCTAssertEqual(PreferencesEntry(settings)?.get(StateSyncDebugSettings.self), settings, "override \(String(describing: value))")
        }
    }
}
