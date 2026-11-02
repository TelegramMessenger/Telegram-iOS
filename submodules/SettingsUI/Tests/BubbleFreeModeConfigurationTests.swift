import XCTest
import TelegramCore
@testable import SettingsUI

/// The bubble-free mode's settings (the Bubble Mode switch, the New York text choice) are offered to dev accounts and to
/// accounts the server turns them on for; anyone else sees one only while it is in use, to turn it back.
final class BubbleFreeModeConfigurationTests: XCTestCase {
    private func configuration(_ value: JSON?, dev: Double? = nil) -> AppConfiguration {
        var configuration = AppConfiguration.defaultValue
        var data: [String: JSON] = [:]
        if let value {
            data[bubbleFreeModeAppConfigurationKey] = value
        }
        if let dev {
            data["dev"] = .number(dev)
        }
        if !data.isEmpty {
            configuration.data = .dictionary(data)
        }
        return configuration
    }

    func testOffByDefault() {
        XCTAssertFalse(isBubbleFreeModeAvailable(appConfiguration: AppConfiguration.defaultValue))
        XCTAssertFalse(isBubbleFreeModeAvailable(appConfiguration: self.configuration(nil, dev: 0.0)))
    }

    func testDevAccountsHaveIt() {
        XCTAssertTrue(isBubbleFreeModeAvailable(appConfiguration: self.configuration(nil, dev: 1.0)))
        XCTAssertTrue(isBubbleFreeModeAvailable(appConfiguration: self.configuration(.bool(false), dev: 1.0)))
    }

    func testServerSwitchTurnsItOn() {
        XCTAssertTrue(isBubbleFreeModeAvailable(appConfiguration: self.configuration(.bool(true))))
        XCTAssertTrue(isBubbleFreeModeAvailable(appConfiguration: self.configuration(.number(1.0))))
        XCTAssertFalse(isBubbleFreeModeAvailable(appConfiguration: self.configuration(.bool(false))))
        XCTAssertFalse(isBubbleFreeModeAvailable(appConfiguration: self.configuration(.number(0.0))))
        XCTAssertFalse(isBubbleFreeModeAvailable(appConfiguration: self.configuration(.string("true"))))
    }

    func testSettingsShowWhereAvailable() {
        XCTAssertTrue(showsBubbleFreeModeSetting(isBubbleFreeModeAvailable: true, isInUse: false))
        XCTAssertTrue(showsBubbleFreeModeSetting(isBubbleFreeModeAvailable: true, isInUse: true))
    }

    /// Bubbles already off, or New York already chosen: the setting stays, so that it can be turned back.
    func testSettingsHiddenElseUnlessInUse() {
        XCTAssertFalse(showsBubbleFreeModeSetting(isBubbleFreeModeAvailable: false, isInUse: false))
        XCTAssertTrue(showsBubbleFreeModeSetting(isBubbleFreeModeAvailable: false, isInUse: true))
    }
}
