import Foundation
import XCTest
@testable import MessageWidget

/// The server's switch for message widgets is held by the module, set once per app configuration the host receives,
/// so a layout pass (on any thread) reads a flag instead of looking the key up in the app configuration.
class KillSwitchTests: XCTestCase {
    override func tearDown() {
        MessageWidgetKillSwitch.isEngaged = false
        super.tearDown()
    }

    func testWidgetsAreOnUntilTheServerSwitchesThemOff() {
        XCTAssertFalse(MessageWidgetKillSwitch.isEngaged)
        MessageWidgetKillSwitch.isEngaged = true
        XCTAssertTrue(MessageWidgetKillSwitch.isEngaged)
        MessageWidgetKillSwitch.isEngaged = false
        XCTAssertFalse(MessageWidgetKillSwitch.isEngaged)
    }

    func testTheSwitchIsReadFromAnyThread() {
        MessageWidgetKillSwitch.isEngaged = true
        let read = expectation(description: "read off main")
        DispatchQueue.global(qos: .userInitiated).async {
            XCTAssertTrue(MessageWidgetKillSwitch.isEngaged)
            read.fulfill()
        }
        wait(for: [read], timeout: 5.0)
    }

    func testTheKeyIsTheServersName() {
        XCTAssertEqual(MessageWidgetKillSwitch.appConfigurationKey, "ios_killswitch_disable_message_widgets")
    }
}
