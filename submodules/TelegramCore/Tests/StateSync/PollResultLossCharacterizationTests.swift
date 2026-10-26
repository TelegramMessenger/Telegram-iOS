import Foundation
import XCTest
import SwiftSignalKit
import Postbox
import TelegramApi
@testable import TelegramCore

/// A getDifference attempt's result reaches the poll (`runFetchDifference`) however its answer and the manager's
/// queue interleave (audit id Q13, fixed).
///
/// The main app's attempt is `transaction |> deliverOn(queue) |> mapToSignal { getDifference … }`
/// (`fetchAndApplyDifference(policy:)` in AccountStateManager.swift). The transaction delivers its value and its
/// completion to the manager's queue as two blocks queued back to back; the first sends the request. When the
/// answer, and everything it runs synchronously, has finished on the engine's thread before the queue runs the
/// second block, the inner signal is already complete, so that completion block ends the whole signal on the
/// manager's queue itself. Until the fix a trailing `deliverOn(queue)` then ran that completion inline
/// (`Queue.async`, Queue.swift:60-66), ahead of the result it had dispatched to the same queue a moment earlier,
/// and the terminated subscriber dropped the result (Subscriber.swift:152-163): the poll stayed at the head of the
/// operation queue, marked running, and neither `reset()` nor a pushed update got anything done until relaunch.
/// The `next` handler (`runFetchDifference`'s) now hops to the queue with `queue.async` itself, the result
/// captured in the block, so no completion can overtake it.
///
/// A real network round trip is far slower than one queue hop, so this exact interleaving needs the scripted
/// server's instant answers; unforced, it made the differenceTooLong test in DifferenceCharacterizationTests fail
/// about 2% of the time until that test held its answer. The same shape one boundary later (the replay
/// transaction on the Postbox thread racing the queue's next block) did not depend on the server; the same hop
/// covers it.
final class PollResultLossCharacterizationTests: StateSyncTestCase {
    /// Q13. A getDifference answered before the poll's queue moves on is delivered: the reset it asks for runs
    /// (the dialogs, then the cycle's follow-up getDifference from the reset's pts), the poll is removed from the
    /// head of the queue, and `reset()` polls again.
    func testDifferenceAnsweredBeforeThePollContinuesIsDelivered() {
        self.fixture.seedAccount(state: self.state(pts: 100))
        self.makeStateManager()
        self.server.on(Name.getDifference, .result(StateSyncApi.differenceTooLong(pts: 999)))
        self.server.on(Name.getDialogs, .result(StateSyncApi.dialogs()))
        self.server.on(Name.getPinnedDialogs, .result(StateSyncApi.peerDialogs(state: StateSyncApi.state(pts: 999, qts: 5, date: self.baseDate, seq: 10))))
        self.server.on(Name.getDifference, .result(StateSyncApi.differenceEmpty(date: self.baseDate + 100, seq: 10)))
        // The transaction's completion is queued on the manager's queue once its block has finished.
        self.server.answerBeforeCallerContinues(Name.getDifference, after: {
            Postbox.sharedQueue.sync {
            }
        })
        self.fixture.resetStateManager()

        XCTAssertTrue(self.server.waitForRequest(Name.getDifference))
        // The result was delivered: the reset it asks for fetches the chat list. Not from the block that receives
        // the result, as updates.getState was: fetchChatList reads the account state first.
        XCTAssertTrue(self.server.waitForRequest(Name.getDialogs))

        // The barrier sits behind the running poll and completes once the follow-up ended the cycle.
        self.drainOperationQueue()
        let names = self.server.requestNames
        XCTAssertEqual(names.count, 4, "log: \(names)")
        XCTAssertEqual(names.first, Name.getDifference)
        XCTAssertEqual(Set(names.dropFirst().prefix(2)), [Name.getDialogs, Name.getPinnedDialogs])
        self.assertGetDifference(3, pts: 999, date: self.baseDate, qts: 5)
        XCTAssertEqual(self.fixture.accountState()?.state, self.state(pts: 999, qts: 5, date: self.baseDate + 100, seq: 10))

        // Nothing is left running at the head: reset() polls again, from the state the cycle stored.
        self.server.on(Name.getDifference, .result(StateSyncApi.differenceEmpty(date: self.baseDate + 101, seq: 10)))
        self.fixture.resetStateManager()
        XCTAssertTrue(self.server.waitForRequest(Name.getDifference, count: 3))
        self.drainOperationQueue()
        XCTAssertEqual(self.server.requestNames.count, 5)
        self.assertGetDifference(4, pts: 999, date: self.baseDate + 100, qts: 5)
    }
}

/// SwiftSignalKit's `deliverOn`, the mechanism behind the result loss above, pinned on its own.
final class DeliverOnOrderingCharacterizationTests: XCTestCase {
    /// `deliverOn(queue)` dispatches an event that arrives on another thread but runs one that arrives on
    /// `queue` inline (Signal_Dispatch.swift:3-21, Queue.swift:60-66). A completion emitted on `queue`
    /// therefore overtakes a value another thread dispatched to `queue` just before, and the terminated
    /// subscriber drops the value. In `x |> deliverOn(q) |> mapToSignal { work elsewhere } |> deliverOn(q)`
    /// this happens whenever the inner work finishes before `q` runs x's completion.
    func testCompletionOnTheTargetQueueOvertakesADispatchedValue() {
        let queue = Queue(name: "DeliverOnOrdering.target")
        let other = Queue(name: "DeliverOnOrdering.other")
        let values = Atomic<[Int]>(value: [])
        let completed = Atomic<Bool>(value: false)

        let signal = self.outerDeliveredOn(queue)
        |> mapToSignal { _ -> Signal<Int, NoError> in
            // Runs in the first block on `queue`: the inner answers and completes on `other` before
            // that block returns.
            return Signal { subscriber in
                other.sync {
                    subscriber.putNext(42)
                    subscriber.putCompletion()
                }
                return EmptyDisposable
            }
        }
        |> deliverOn(queue)
        let disposable = signal.start(next: { value in
            let _ = values.modify { $0 + [value] }
        }, completed: {
            let _ = completed.swap(true)
        })
        // The first round trip may be queued before the value is dispatched (from the first block); the
        // second is queued after it.
        queue.sync {
        }
        queue.sync {
        }

        XCTAssertTrue(completed.with { $0 })
        XCTAssertEqual(values.with { $0 }, [])
        disposable.dispose()
    }

    /// Control: when the inner finishes after `queue` ran the outer completion, the value arrives.
    func testInnerFinishingAfterTheOuterCompletionKeepsTheValue() {
        let queue = Queue(name: "DeliverOnOrdering.target")
        let other = Queue(name: "DeliverOnOrdering.other")
        let values = Atomic<[Int]>(value: [])
        let done = DispatchSemaphore(value: 0)
        let outerCompletionDelivered = DispatchSemaphore(value: 0)

        let signal = self.outerDeliveredOn(queue, completionDelivered: outerCompletionDelivered)
        |> mapToSignal { _ -> Signal<Int, NoError> in
            return Signal { subscriber in
                other.justDispatch {
                    outerCompletionDelivered.wait()
                    subscriber.putNext(42)
                    subscriber.putCompletion()
                }
                return EmptyDisposable
            }
        }
        |> deliverOn(queue)
        let disposable = signal.start(next: { value in
            let _ = values.modify { $0 + [value] }
        }, completed: {
            done.signal()
        })

        XCTAssertEqual(done.wait(timeout: .now() + 10.0), .success)
        XCTAssertEqual(values.with { $0 }, [42])
        disposable.dispose()
    }

    /// Q13, the shape `standalonePollDifference` delivers its result with since the fix: the hop to `queue`
    /// is made inside the last inner signal, value and completion in one block, instead of by a
    /// `deliverOn(queue)` in front of the last `mapToSignal`. Under the interleaving that drops the value in
    /// `testCompletionOnTheTargetQueueOvertakesADispatchedValue` (the inner work has finished on `other`
    /// before `queue` runs the outer completion), the value arrives: the outer completion reaches the
    /// last `mapToSignal` while its inner signal is still running, and that inner signal completes only in
    /// the block that delivers the value. This pins the operator contract the fix relies on; no test reaches
    /// the extension's own boundary through the real code, which needs the manager queue stalled between
    /// two of its own blocks while the replay transaction runs.
    func testHopInsideTheLastInnerSignalKeepsTheValue() {
        let queue = Queue(name: "DeliverOnOrdering.target")
        let other = Queue(name: "DeliverOnOrdering.other")
        let values = Atomic<[Int]>(value: [])
        let completed = Atomic<Bool>(value: false)

        let signal = self.outerDeliveredOn(queue)
        |> mapToSignal { _ -> Signal<Int, NoError> in
            // As above: answers and completes on `other` before the first block on `queue` returns.
            return Signal { subscriber in
                other.sync {
                    subscriber.putNext(42)
                    subscriber.putCompletion()
                }
                return EmptyDisposable
            }
        }
        |> mapToSignal { value -> Signal<Int, NoError> in
            return Signal { subscriber in
                queue.async {
                    subscriber.putNext(value)
                    subscriber.putCompletion()
                }
                return EmptyDisposable
            }
        }
        let disposable = signal.start(next: { value in
            let _ = values.modify { $0 + [value] }
        }, completed: {
            let _ = completed.swap(true)
        })
        // The first round trip may be queued before the hop's block (dispatched from the first block); the
        // second is queued after it.
        queue.sync {
        }
        queue.sync {
        }

        XCTAssertTrue(completed.with { $0 })
        XCTAssertEqual(values.with { $0 }, [42])
        disposable.dispose()
    }

    /// One value and the completion, delivered on `queue` as two blocks queued back to back, as
    /// `postbox.transaction { … } |> deliverOn(queue)` delivers them. Both are queued before the first
    /// runs. `completionDelivered` is signalled after the second.
    private func outerDeliveredOn(_ queue: Queue, completionDelivered: DispatchSemaphore? = nil) -> Signal<Int, NoError> {
        return Signal { subscriber in
            let gate = DispatchSemaphore(value: 0)
            queue.justDispatch {
                gate.wait()
            }
            queue.justDispatch {
                subscriber.putNext(1)
            }
            queue.justDispatch {
                subscriber.putCompletion()
                completionDelivered?.signal()
            }
            gate.signal()
            return EmptyDisposable
        }
    }
}
