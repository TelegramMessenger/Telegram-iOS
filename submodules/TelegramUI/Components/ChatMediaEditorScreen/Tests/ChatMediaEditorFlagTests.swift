import XCTest
import AccountContext

final class ChatMediaEditorFlagTests: XCTestCase {
    func testOnByDefault() {
        XCTAssertTrue(chatMediaEditorV2Enabled(legacyOverride: false, killswitchPresent: false))
    }

    func testLegacyOverrideDisables() {
        XCTAssertFalse(chatMediaEditorV2Enabled(legacyOverride: true, killswitchPresent: false))
    }

    func testKillswitchDisables() {
        XCTAssertFalse(chatMediaEditorV2Enabled(legacyOverride: false, killswitchPresent: true))
        XCTAssertFalse(chatMediaEditorV2Enabled(legacyOverride: true, killswitchPresent: true))
    }

    func testKillswitchKey() {
        XCTAssertEqual(chatMediaEditorV2KillswitchKey, "ios_killswitch_disable_chat_media_editor_v2")
    }
}
