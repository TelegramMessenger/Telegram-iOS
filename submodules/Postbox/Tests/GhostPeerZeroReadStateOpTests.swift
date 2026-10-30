// Regression tests for the ghost read-state synchronization operation
// (see TelegramMessenger/telegram-macos#194): an interactive read applied for an index
// whose peerId is 0 must not enqueue a synchronization operation — PeerId(0) is the
// minimum sentinel, never a real peer, and an operation queued for it can never
// complete on the consumer side.
//
// testStatelessPeerStillEnqueuesPushThenSync guards the chokepoint against
// over-blocking: a valid peer without read state keeps today's behavior.
// testZeroPeerInteractiveReadEnqueuesNothing fails on unfixed master.

import Foundation
import XCTest
import SwiftSignalKit
@testable import Postbox

final class GhostPeerZeroReadStateOpTests: XCTestCase {
    private var fixture: PostboxFixture!

    override func setUp() {
        super.setUp()
        self.fixture = PostboxFixture(name: "GhostPeerZeroReadStateOpTests")
    }

    override func tearDown() {
        self.fixture.close()
        self.fixture = nil
        super.tearDown()
    }

    // MARK: Helpers

    private var zeroPeer: PeerId {
        return PeerId(0)
    }

    private func readIndex(peerId: PeerId, id: Int32) -> MessageIndex {
        return MessageIndex(id: MessageId(peerId: peerId, namespace: PostboxFixture.messageNamespace, id: id), timestamp: 1000 + id)
    }

    private func currentSyncOperations() -> [PeerId: PeerReadStateSynchronizationOperation] {
        let semaphore = DispatchSemaphore(value: 0)
        var operations: [PeerId: PeerReadStateSynchronizationOperation]?
        let disposable = self.fixture.postbox.synchronizePeerReadStatesView().start(next: { view in
            operations = view.operations
            semaphore.signal()
        })
        let _ = semaphore.wait(timeout: .now() + 5.0)
        disposable.dispose()
        return operations ?? [:]
    }

    // MARK: Tests

    func testViewStartsEmpty() {
        XCTAssertEqual(self.currentSyncOperations(), [:])
    }

    /// An interactive read for an index whose peerId is 0 must not enqueue anything:
    /// PeerId(0) is the minimum sentinel, never a real peer, and an operation queued
    /// for it can never complete on the consumer side (it cannot resolve to an
    /// InputPeer), turning into an unbounded retry loop (telegram-macos#194).
    func testZeroPeerInteractiveReadEnqueuesNothing() {
        let zeroIndex = self.readIndex(peerId: self.zeroPeer, id: 1)
        self.fixture.transaction { transaction in
            let _ = transaction.applyInteractiveReadMaxIndex(zeroIndex)
        }

        let operations = self.currentSyncOperations()
        XCTAssertNil(operations[self.zeroPeer], "PeerId(0) must never get a synchronization operation, got: \(String(describing: operations[self.zeroPeer]))")
    }

    /// A stateless but *valid* peer must keep today's behavior: an interactive read
    /// enqueues Push(state: nil, thenSync: true) so the server state can be fetched.
    /// Guards the chokepoint fix against over-blocking.
    func testStatelessPeerStillEnqueuesPushThenSync() {
        let peer = PeerId(12345)
        self.fixture.transaction { transaction in
            let _ = transaction.applyInteractiveReadMaxIndex(self.readIndex(peerId: peer, id: 1))
        }

        let operations = self.currentSyncOperations()
        guard let operation = operations[peer] else {
            return XCTFail("expected a synchronization operation for \(peer)")
        }
        guard case let .Push(state, thenSync) = operation else {
            return XCTFail("expected .Push, got \(operation)")
        }
        XCTAssertNil(state)
        XCTAssertTrue(thenSync)
    }

    /// `loadedPeerWithId` of a missing row never emits: on the consumer side such an
    /// operation hangs instead of failing. This is why an *instantly* retrying loop
    /// (as observed in the incident) implies a stored peer record.
    func testLoadedPeerWithIdOfMissingPeerNeverEmits() {
        let emitted = DispatchSemaphore(value: 0)
        let disposable = self.fixture.postbox.loadedPeerWithId(self.zeroPeer).start(next: { _ in
            emitted.signal()
        })
        Thread.sleep(forTimeInterval: 0.5)
        let gotValue = emitted.wait(timeout: .now() + 0.01) == .success
        disposable.dispose()
        XCTAssertFalse(gotValue, "loadedPeerWithId of a missing peer must not emit")
    }
}
