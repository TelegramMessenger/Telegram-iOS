import Foundation
import XCTest
import SwiftSignalKit
import Postbox
import TelegramApi
@testable import TelegramCore

/// `pollStateUpdateCompletion()`: a help.test round trip used as a barrier ("everything the server queued
/// before this answer has been processed"), pinned as it behaves at 171825ce49.
final class StateBarrierCharacterizationTests: StateSyncTestCase {
    /// Flow 13 A. On an idle queue the barrier sends help.test at once and completes with no ids.
    func testBarrierSendsHelpTestWhenIdle() {
        self.launchIdle()
        self.server.on(Name.helpTest, .result(StateSyncApi.boolTrue()))

        let ids = self.fixture.wait(self.stateManager.pollStateUpdateCompletion())

        XCTAssertEqual(ids, [])
        XCTAssertEqual(self.server.requestNames, [Name.getDifference, Name.helpTest])
    }

    /// Flow 13 B. A barrier requested while a poll runs waits behind it (no help.test while the poll is in
    /// flight), collects the ids of the incoming messages the poll dispatched, and then sends help.test.
    func testBarrierWaitsForRunningPollAndCarriesItsIncomingIds() {
        let user = self.seedUserChat(200)
        self.fixture.seedAccount(state: self.state(pts: 100))
        self.makeStateManager()
        self.server.on(Name.getDifference, .hold)
        self.fixture.resetStateManager()
        XCTAssertTrue(self.server.waitForRequest(Name.getDifference))

        let barrier = self.fixture.observe(self.stateManager.pollStateUpdateCompletion())
        self.server.on(Name.helpTest, .result(StateSyncApi.boolTrue()))
        XCTAssertFalse(self.server.waitForRequest(Name.helpTest, timeout: 0.2))
        XCTAssertEqual(self.server.requestNames, [Name.getDifference])

        XCTAssertTrue(self.server.release(Name.getDifference, with: .result(StateSyncApi.difference(
            newMessages: [self.incomingMessage(101, from: 200)],
            users: [StateSyncApi.user(id: 200, firstName: "U200")],
            state: StateSyncApi.state(pts: 101, qts: 5, date: self.baseDate + 1, seq: 10)
        ))))

        barrier.wait { $0.count == 1 }
        XCTAssertEqual(barrier.values[0], [self.messageId(user, 101)])
        XCTAssertEqual(self.server.requestNames, [Name.getDifference, Name.helpTest])
    }
}
