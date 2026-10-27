import Foundation
import XCTest
import SwiftSignalKit
import Postbox
import TelegramApi
@testable import TelegramCore

/// `updateShortSentMessage`, the RPC result of a sent message, which `UpdateMessageService` turns into
/// `[.updatePts(pts:ptsCount:)]`. A manager made with `ignoresShortSentMessages` drops it: a supplementary account's
/// (the share extension's) and `standaloneStateManager`'s (master `e6d99316c6`).
final class ShortSentMessageTests: StateSyncTestCase {
    /// The app's own account: the sent message's pts is applied, with no request.
    func testShortSentMessageMovesPts() {
        self.launchIdle()

        self.fixture.addUpdates(StateSyncApi.updateShortSentMessage(id: 101, pts: 101, date: self.baseDate + 2))
        self.drainOperationQueue()

        XCTAssertEqual(self.server.requestNames, [Name.getDifference])
        XCTAssertEqual(self.fixture.accountState()?.state?.pts, 101)
    }

    /// A supplementary account: the update is dropped, so pts stays and nothing is asked.
    func testASupplementaryAccountIgnoresShortSentMessages() {
        self.launchIdle(ignoresShortSentMessages: true)

        self.fixture.addUpdates(StateSyncApi.updateShortSentMessage(id: 101, pts: 101, date: self.baseDate + 2))
        self.drainOperationQueue()

        XCTAssertEqual(self.server.requestNames, [Name.getDifference])
        XCTAssertEqual(self.fixture.accountState()?.state?.pts, 100, "a supplementary account applied a sent message's pts")
    }
}
