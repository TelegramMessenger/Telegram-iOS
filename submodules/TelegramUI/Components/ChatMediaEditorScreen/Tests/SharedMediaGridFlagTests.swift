import XCTest
import AccountContext

final class SharedMediaGridFlagTests: XCTestCase {
    func testEnabledByDefault() {
        XCTAssertTrue(sharedMediaGridV2Enabled(legacyOverride: false, killswitchPresent: false))
    }

    func testLegacyOverrideDisables() {
        XCTAssertFalse(sharedMediaGridV2Enabled(legacyOverride: true, killswitchPresent: false))
    }

    func testKillswitchDisables() {
        XCTAssertFalse(sharedMediaGridV2Enabled(legacyOverride: false, killswitchPresent: true))
        XCTAssertFalse(sharedMediaGridV2Enabled(legacyOverride: true, killswitchPresent: true))
    }

    func testKillswitchKey() {
        XCTAssertEqual(sharedMediaGridV2KillswitchKey, "ios_killswitch_disable_shared_media_grid_v2")
    }
}
