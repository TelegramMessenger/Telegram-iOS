import XCTest
import Postbox
import SwiftSignalKit
@testable import TelegramCore

final class SupportSettingsTests: XCTestCase {
    private struct PartialSettings: Codable {
        var sendAllSilently: Bool
    }

    func testDefaultsMatchTDesktop() {
        let settings = SupportSettings.default
        XCTAssertFalse(settings.sendAllSilently)
    }

    func testRoundTrip() {
        let settings = SupportSettings(sendAllSilently: true)
        XCTAssertEqual(PreferencesEntry(settings)?.get(SupportSettings.self), settings)
        XCTAssertEqual(PreferencesEntry(SupportSettings.default)?.get(SupportSettings.self), .default)
    }

    func testMissingValuesTakeTheirDefaults() {
        var expected = SupportSettings.default
        expected.sendAllSilently = true
        XCTAssertEqual(PreferencesEntry(PartialSettings(sendAllSilently: true))?.get(SupportSettings.self), expected)
    }

    private func isMuted(_ attributes: [MessageAttribute]) -> Bool {
        return attributes.contains(where: { ($0 as? NotificationInfoMessageAttribute)?.flags.contains(.muted) == true })
    }

    func testSilentAttributeIsAddedOnce() {
        let once = supportSilentMessageAttributes([])
        XCTAssertTrue(self.isMuted(once))
        XCTAssertEqual(supportSilentMessageAttributes(once).count, 1)
    }

    func testSilentAttributeSurvivesEverySendShape() {
        let silent = supportSilentMessageAttributes([])
        XCTAssertTrue(self.isMuted(outgoingMessageAttributes(requestedAttributes: silent, isSecretChat: false, peerAutoremoveTimeout: nil)))
        XCTAssertTrue(self.isMuted(outgoingMessageAttributes(requestedAttributes: silent, isSecretChat: true, peerAutoremoveTimeout: nil)))
        XCTAssertTrue(self.isMuted(forwardedMessageAttributes(requestedAttributes: silent, sourceAttributes: [], forwardedMessageIds: nil)))
        XCTAssertTrue(self.isMuted(forwardCopyRequestedAttributes(sourceAttributes: [], forwardAttributes: silent, hidesCaption: false)))
    }
}
