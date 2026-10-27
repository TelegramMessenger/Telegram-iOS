import XCTest
import AccountContext

final class MediaPickerGridFlagTests: XCTestCase {
    func testOnByDefault() {
        XCTAssertTrue(mediaPickerGridV2Enabled(legacyOverride: false, killswitchPresent: false))
    }

    func testLegacyOverrideDisables() {
        XCTAssertFalse(mediaPickerGridV2Enabled(legacyOverride: true, killswitchPresent: false))
    }

    func testKillswitchDisables() {
        XCTAssertFalse(mediaPickerGridV2Enabled(legacyOverride: false, killswitchPresent: true))
        XCTAssertFalse(mediaPickerGridV2Enabled(legacyOverride: true, killswitchPresent: true))
    }

    func testKillswitchKey() {
        XCTAssertEqual(mediaPickerGridV2KillswitchKey, "ios_killswitch_disable_media_grid_v2")
    }
}
