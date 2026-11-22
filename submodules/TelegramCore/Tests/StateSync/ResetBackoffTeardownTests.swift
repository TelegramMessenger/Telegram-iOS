import Foundation
import XCTest
import SwiftSignalKit
import Postbox
import TelegramApi
@testable import TelegramCore

/// A differenceTooLong reset that waits out its backoff (`AccountStateManager.consecutiveResetDelay`, up to 60 s)
/// belongs to its manager: when the manager goes (the account is torn down), the waiting reset is cancelled
/// instead of resetting the account's storage after the wait. Until the fix the poll started the reset and
/// dropped its disposable, so nothing could stop it.
final class ResetBackoffTeardownTests: StateSyncTestCase {
    /// differenceTooLong twice in a row: the first reset runs at once and writes pts 500, the second waits 1 s
    /// (this test's backoff). The manager is released during that wait. The second reset never sends its
    /// messages.getDialogs and the stored pts stays 500, although its answers are scripted: a reset that ran
    /// anyway would complete and write pts 999.
    func testAResetWaitingOutItsBackoffDoesNotRunAfterItsManagerIsReleased() {
        let originalDelay = AccountStateManager.consecutiveResetDelay
        self.addTeardownBlock {
            AccountStateManager.consecutiveResetDelay = originalDelay
        }
        // Long enough that a stalled test thread does not reach the checks below after a correct wait ended.
        AccountStateManager.consecutiveResetDelay = { n in
            return n >= 2 ? 1.0 : 0.0
        }
        self.fixture.seedAccount(state: self.state(pts: 100))
        let emptyPinnedDialogs = StateSyncApi.peerDialogs(state: StateSyncApi.state(pts: 999, qts: 5, date: self.baseDate, seq: 10))
        self.server.on(Name.getDifference, .result(StateSyncApi.differenceTooLong(pts: 500)))
        self.server.on(Name.getDialogs, .result(StateSyncApi.dialogs()))
        self.server.on(Name.getPinnedDialogs, .result(emptyPinnedDialogs))
        self.server.on(Name.getDifference, .result(StateSyncApi.differenceTooLong(pts: 999)))
        self.server.on(Name.getDialogs, .result(StateSyncApi.dialogs()))
        self.server.on(Name.getPinnedDialogs, .result(emptyPinnedDialogs))
        self.server.on(Name.getDifference, .result(StateSyncApi.differenceEmpty(date: self.baseDate + 120, seq: 10)))

        // Built here, not with `makeStateManager`: the fixture keeps the manager it makes until `close()`, and this
        // test must hold the only reference.
        var manager: AccountStateManager? = AccountStateManager(
            accountPeerId: StateSyncFixture.accountPeerId,
            accountManager: self.fixture.accountManager,
            postbox: self.fixture.postbox,
            network: self.network,
            callSessionManager: nil,
            shouldKeepOnlinePresence: .single(false),
            peerInputActivityManager: nil,
            auxiliaryMethods: StateSyncFixture.makeAuxiliaryMethods(),
            ignoresShortSentMessages: false,
            gapWaitTimeout: StateSyncFixture.gapWaitTimeout
        )
        manager?.reset()

        // The second answer is handed over and handled on the manager queue; its reset is now waiting 1 s.
        XCTAssertTrue(self.server.waitForRequest(Name.getDifference, count: 2))
        self.server.flush()
        if let manager = manager {
            // A round trip on the manager's queue (`isUpdating` subscribes there).
            let _ = self.fixture.wait(manager.isUpdating |> take(1))
        }
        // A reset that did not wait would have sent its getDialogs from fetchChatList's Postbox hop by now.
        Postbox.sharedQueue.sync {}
        self.server.flush()
        XCTAssertEqual(self.server.requestNames.filter { $0 == Name.getDialogs }.count, 1, "precondition: the second reset is waiting out its backoff: \(self.server.requestNames)")
        XCTAssertEqual(self.fixture.accountState()?.state?.pts, 500, "precondition: the first reset wrote its pts")

        weak var releasedManager = manager
        manager = nil
        XCTAssertNil(releasedManager, "precondition: the test held the only reference to the manager")

        // Three times the backoff.
        XCTAssertFalse(self.server.waitForRequest(Name.getDialogs, count: 2, timeout: 3.0), "the reset ran after its manager was released: \(self.server.requestNames)")
        Postbox.sharedQueue.sync {}
        XCTAssertEqual(self.fixture.accountState()?.state?.pts, 500, "the reset wrote after its manager was released")
    }
}
