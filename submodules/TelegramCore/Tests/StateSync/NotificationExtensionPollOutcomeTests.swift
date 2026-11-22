import Foundation
import XCTest
import SwiftSignalKit
import Postbox
import TelegramApi
@testable import TelegramCore

/// Two outcomes of the notification extension's poll (`standalonePollDifference`) that no other test reaches, pinned
/// before stage 4 moved the poll into `fetchAndApplyDifference(policy: .notificationExtension)`. Flow 12 and Q3 are in
/// `NotificationExtensionPollCharacterizationTests`.
final class NotificationExtensionPollOutcomeTests: StateSyncTestCase {
    override var fixtureProfile: StateSyncFixture.OpenProfile {
        return .notificationExtension
    }

    /// AUTH_KEY_DUPLICATED ends the extension's poll as done (true) after one request: it is not retried, and the
    /// stored state is untouched.
    func testAuthKeyDuplicatedReportsDoneAndWritesNothing() {
        self.fixture.seedAccount(state: self.state(pts: 100, qts: 5, seq: 10))
        self.makeStateManager()
        self.server.on(Name.getDifference, .error(code: 406, text: "AUTH_KEY_DUPLICATED"))

        XCTAssertEqual(self.fixture.wait(self.stateManager.standalonePollDifference()), true)

        XCTAssertEqual(self.server.requestNames, [Name.getDifference])
        self.assertGetDifference(0, pts: 100, date: Int32.max, qts: 5)
        XCTAssertEqual(self.fixture.accountState()?.state, self.state(pts: 100, qts: 5, seq: 10))
        XCTAssertEqual(self.isUpdating.values, [true])
    }

    /// A stored account state without an inner state (between login and the first updates.getState) ends the
    /// extension's poll as done (true) without a request: the extension does not bootstrap the state, the app's poll
    /// does.
    func testNoInnerStateReportsDoneWithoutARequest() {
        self.fixture.seedAccount(state: nil)
        self.makeStateManager()

        XCTAssertEqual(self.fixture.wait(self.stateManager.standalonePollDifference()), true)

        XCTAssertEqual(self.server.requestNames, [])
        XCTAssertNotNil(self.fixture.accountState())
        XCTAssertNil(self.fixture.accountState()?.state)
        XCTAssertEqual(self.isUpdating.values, [true])
    }
}
