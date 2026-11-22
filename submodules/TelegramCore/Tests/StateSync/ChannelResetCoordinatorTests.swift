import Foundation
import XCTest
import SwiftSignalKit
import Postbox
@testable import TelegramCore

/// `ChannelResetCoordinator` (state-sync spec 3.5) on its own, without a state manager, at the end of a difference
/// chain that needs no request. The asynchronous paths (a reset answering, the unverified replay, the queue start
/// after it) run end to end in the harness: `ChannelSyncCharacterizationTests`, `EventDeliveryOrderTests`.
final class ChannelResetCoordinatorTests: StateSyncTestCase {
    /// The coordinator's `cycleEnded` calls, recorded on its queue and read on the test thread.
    private final class EndLog {
        private let lock = NSLock()
        private var entries: [(events: AccountFinalStateEvents?, startsFirstOperation: Bool)] = []

        func append(events: AccountFinalStateEvents?, startsFirstOperation: Bool) {
            self.lock.lock()
            self.entries.append((events, startsFirstOperation))
            self.lock.unlock()
        }

        var values: [(events: AccountFinalStateEvents?, startsFirstOperation: Bool)] {
            self.lock.lock()
            defer {
                self.lock.unlock()
            }
            return self.entries
        }
    }

    private func makeCoordinator(queue: Queue, log: EndLog) -> ChannelResetCoordinator {
        return self.makeCoordinator(queue: queue, cycleEnded: { events, startsFirstOperation in
            log.append(events: events, startsFirstOperation: startsFirstOperation)
        })
    }

    private func makeCoordinator(queue: Queue, cycleEnded: @escaping (AccountFinalStateEvents?, Bool) -> Void) -> ChannelResetCoordinator {
        let replayer = FinalStateReplayer(accountManager: self.fixture.accountManager, postbox: self.fixture.postbox, accountPeerId: StateSyncFixture.accountPeerId, encryptionProvider: UnusedEncryptionProvider(), auxiliaryMethods: StateSyncFixture.makeAuxiliaryMethods(), messagesRemovedContext: MessagesRemovedContext())
        return ChannelResetCoordinator(queue: queue, accountPeerId: StateSyncFixture.accountPeerId, postbox: self.fixture.postbox, network: self.network, currentValidityMarker: 1, replayer: replayer, cycleEnded: cycleEnded)
    }

    private func chainEvents() -> AccountFinalStateEvents {
        return AccountFinalStateEvents.testing(displayAlerts: [(text: "alert", isDropAuth: false)])
    }

    /// Without resets in the cycle the end of the chain is the caller's (`finishPollCycle` ends the cycle itself):
    /// the coordinator takes nothing and `cycleEnded` does not run.
    func testWithoutPendingResetsTheCallerEndsTheCycle() {
        let queue = Queue(name: "ChannelResetCoordinatorTests")
        let log = EndLog()
        let coordinator = self.makeCoordinator(queue: queue, log: log)
        var tookTheChain = true
        queue.sync {
            tookTheChain = coordinator.endDifferenceChain(events: self.chainEvents())
        }
        XCTAssertFalse(tookTheChain)
        XCTAssertEqual(log.values.count, 0)
    }

    /// A difference whose recovery asked for an asynchronous reset of no channel (none of them had a peer) still opens
    /// a context. The end of the chain goes there, and since no reset is pending or answered the cycle ends at once,
    /// inside `endDifferenceChain`, with the chain's events and without starting the queue (its caller does). The
    /// context is gone afterwards: the next chain's end is the caller's again.
    func testAContextWithoutResetsEndsTheCycleWhenTheChainEnds() {
        let queue = Queue(name: "ChannelResetCoordinatorTests")
        let log = EndLog()
        let coordinator = self.makeCoordinator(queue: queue, log: log)
        var endsBeforeTheChainEnded = -1
        var tookTheChain = false
        var tookTheNextChain = true
        queue.sync {
            coordinator.addAsyncResetChannels(peers: [])
            endsBeforeTheChainEnded = log.values.count
            tookTheChain = coordinator.endDifferenceChain(events: self.chainEvents())
            tookTheNextChain = coordinator.endDifferenceChain(events: AccountFinalStateEvents())
        }
        XCTAssertEqual(endsBeforeTheChainEnded, 0)
        XCTAssertTrue(tookTheChain)
        XCTAssertFalse(tookTheNextChain)
        let ends = log.values
        XCTAssertEqual(ends.count, 1)
        XCTAssertEqual(ends.first?.events?.displayAlerts.map { $0.text }, ["alert"])
        XCTAssertEqual(ends.first?.startsFirstOperation, false)
    }

    /// `cycleEnded` runs only once the context is dropped: the Impl ends the cycle through `finishPollCycle`, which
    /// hands the chain's end to `endDifferenceChain(events:)` again, and that call must find no context. Were the
    /// context still set, it would take the chain again, and a context without resets would end the cycle again
    /// inside it, without bound. The re-entry here is made once (`reentered` is set before it), so a regression fails
    /// on the assertion instead of overflowing the stack.
    func testTheCycleEndsAfterTheContextIsDropped() {
        final class Reentry {
            weak var coordinator: ChannelResetCoordinator?
            var reentered = false
            var reentryTookTheChain: Bool?
        }
        let queue = Queue(name: "ChannelResetCoordinatorTests")
        let box = Reentry()
        let coordinator = self.makeCoordinator(queue: queue, cycleEnded: { _, _ in
            guard !box.reentered, let coordinator = box.coordinator else {
                return
            }
            box.reentered = true
            box.reentryTookTheChain = coordinator.endDifferenceChain(events: AccountFinalStateEvents())
        })
        box.coordinator = coordinator
        var tookTheChain = false
        queue.sync {
            coordinator.addAsyncResetChannels(peers: [])
            tookTheChain = coordinator.endDifferenceChain(events: self.chainEvents())
        }
        XCTAssertTrue(tookTheChain)
        XCTAssertTrue(box.reentered)
        XCTAssertEqual(box.reentryTookTheChain, false)
    }
}
