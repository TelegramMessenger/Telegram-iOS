import XCTest
import Foundation
#if SSK_LEGACY
@testable import SwiftSignalKitLegacy
#else
@testable import SwiftSignalKit2
#endif

final class CoreSubscriberTests: XCTestCase {
    private struct Harness {
        let log: CoreEventLog
        let holder: CoreSubscriberHolder<Int, String>
        let inner: CoreCountingDisposable
        let handle: Disposable

        var subscriber: Subscriber<Int, String>? {
            return self.holder.subscriber
        }
    }

    private func makeHarness() -> Harness {
        let log = CoreEventLog()
        let holder = CoreSubscriberHolder<Int, String>()
        let inner = CoreCountingDisposable(log: log)
        let handle = Signal<Int, String> { subscriber in
            holder.subscriber = subscriber
            return inner
        }.start(next: { value in
            log.append("next \(value)")
        }, error: { error in
            log.append("error \(error)")
        }, completed: {
            log.append("completed")
        })
        return Harness(log: log, holder: holder, inner: inner, handle: handle)
    }

    func testPutNextDeliversValuesInOrder() {
        let harness = self.makeHarness()
        harness.subscriber?.putNext(1)
        harness.subscriber?.putNext(2)
        harness.subscriber?.putNext(3)
        XCTAssertEqual(harness.log.events, ["next 1", "next 2", "next 3"])
        XCTAssertEqual(harness.inner.disposeCount, 0)
        harness.handle.dispose()
    }

    func testCompletionDisposesInnerAfterCompletionCallback() {
        let harness = self.makeHarness()
        harness.subscriber?.putNext(1)
        harness.subscriber?.putCompletion()
        XCTAssertEqual(harness.log.events, ["next 1", "completed", "dispose"])
        XCTAssertEqual(harness.inner.disposeCount, 1)
    }

    func testErrorDisposesInnerAfterErrorCallback() {
        let harness = self.makeHarness()
        harness.subscriber?.putNext(1)
        harness.subscriber?.putError("e")
        XCTAssertEqual(harness.log.events, ["next 1", "error e", "dispose"])
        XCTAssertEqual(harness.inner.disposeCount, 1)
    }

    func testNothingDeliveredAfterCompletion() {
        let harness = self.makeHarness()
        harness.subscriber?.putCompletion()
        harness.subscriber?.putNext(1)
        harness.subscriber?.putError("e")
        harness.subscriber?.putCompletion()
        XCTAssertEqual(harness.log.events, ["completed", "dispose"])
        XCTAssertEqual(harness.inner.disposeCount, 1)
        harness.handle.dispose()
        XCTAssertEqual(harness.inner.disposeCount, 1)
    }

    func testNothingDeliveredAfterError() {
        let harness = self.makeHarness()
        harness.subscriber?.putError("first")
        harness.subscriber?.putNext(1)
        harness.subscriber?.putError("second")
        harness.subscriber?.putCompletion()
        XCTAssertEqual(harness.log.events, ["error first", "dispose"])
        XCTAssertEqual(harness.inner.disposeCount, 1)
        harness.handle.dispose()
        XCTAssertEqual(harness.inner.disposeCount, 1)
    }

    func testHandleDisposeDisposesInnerAndStopsDelivery() {
        let harness = self.makeHarness()
        harness.subscriber?.putNext(1)
        harness.handle.dispose()
        harness.subscriber?.putNext(2)
        harness.subscriber?.putError("e")
        harness.subscriber?.putCompletion()
        XCTAssertEqual(harness.log.events, ["next 1", "dispose"])
        XCTAssertEqual(harness.inner.disposeCount, 1)
    }

    func testHandleDisposeTwiceDisposesInnerOnce() {
        let harness = self.makeHarness()
        harness.handle.dispose()
        harness.handle.dispose()
        XCTAssertEqual(harness.inner.disposeCount, 1)
        XCTAssertEqual(harness.log.events, ["dispose"])
    }

    func testHandleDisposeAfterCompletionDoesNotDisposeInnerAgain() {
        let harness = self.makeHarness()
        harness.subscriber?.putCompletion()
        harness.handle.dispose()
        harness.handle.dispose()
        XCTAssertEqual(harness.inner.disposeCount, 1)
        XCTAssertEqual(harness.log.events, ["completed", "dispose"])
    }

    func testHandleDisposeAfterErrorDoesNotDisposeInnerAgain() {
        let harness = self.makeHarness()
        harness.subscriber?.putError("e")
        harness.handle.dispose()
        XCTAssertEqual(harness.inner.disposeCount, 1)
        XCTAssertEqual(harness.log.events, ["error e", "dispose"])
    }

    func testSynchronousCompletionInGeneratorDisposesReturnedDisposableImmediately() {
        let log = CoreEventLog()
        let inner = CoreCountingDisposable(log: log)
        let handle = Signal<Int, String> { subscriber in
            log.append("generator begin")
            subscriber.putNext(1)
            subscriber.putCompletion()
            subscriber.putNext(2)
            log.append("generator end")
            return inner
        }.start(next: { value in
            log.append("next \(value)")
        }, error: { error in
            log.append("error \(error)")
        }, completed: {
            log.append("completed")
        })
        log.append("start returned")
        XCTAssertEqual(log.events, ["generator begin", "next 1", "completed", "generator end", "dispose", "start returned"])
        handle.dispose()
        handle.dispose()
        XCTAssertEqual(inner.disposeCount, 1)
    }

    func testSynchronousErrorInGeneratorDisposesReturnedDisposableImmediately() {
        let log = CoreEventLog()
        let inner = CoreCountingDisposable(log: log)
        let handle = Signal<Int, String> { subscriber in
            log.append("generator begin")
            subscriber.putError("e")
            subscriber.putCompletion()
            log.append("generator end")
            return inner
        }.start(next: { value in
            log.append("next \(value)")
        }, error: { error in
            log.append("error \(error)")
        }, completed: {
            log.append("completed")
        })
        log.append("start returned")
        XCTAssertEqual(log.events, ["generator begin", "error e", "generator end", "dispose", "start returned"])
        handle.dispose()
        XCTAssertEqual(inner.disposeCount, 1)
    }

    func testSynchronousCompletionWithStrictStartDisposesReturnedDisposableImmediately() {
        let log = CoreEventLog()
        let inner = CoreCountingDisposable(log: log)
        let handle = Signal<Int, String> { subscriber in
            subscriber.putCompletion()
            return inner
        }.startStrict(completed: {
            log.append("completed")
        })
        XCTAssertEqual(log.events, ["completed", "dispose"])
        handle.dispose()
        XCTAssertEqual(inner.disposeCount, 1)
    }

    func testNilCallbacksStillDisposeInnerOnTermination() {
        let log = CoreEventLog()
        let holder = CoreSubscriberHolder<Int, String>()
        let inner = CoreCountingDisposable(log: log)
        let handle = Signal<Int, String> { subscriber in
            holder.subscriber = subscriber
            return inner
        }.start()
        holder.subscriber?.putNext(1)
        holder.subscriber?.putCompletion()
        XCTAssertEqual(log.events, ["dispose"])
        handle.dispose()
        XCTAssertEqual(inner.disposeCount, 1)
    }

    func testOnlyNextCallbackProvided() {
        let log = CoreEventLog()
        let holder = CoreSubscriberHolder<Int, String>()
        let inner = CoreCountingDisposable(log: log)
        let handle = Signal<Int, String> { subscriber in
            holder.subscriber = subscriber
            return inner
        }.start(next: { value in
            log.append("next \(value)")
        })
        holder.subscriber?.putNext(1)
        holder.subscriber?.putError("e")
        holder.subscriber?.putNext(2)
        XCTAssertEqual(log.events, ["next 1", "dispose"])
        handle.dispose()
    }

    func testHandleDisposeFromInsideNextCallback() {
        let log = CoreEventLog()
        let holder = CoreSubscriberHolder<Int, String>()
        let inner = CoreCountingDisposable(log: log)
        var handle: Disposable?
        handle = Signal<Int, String> { subscriber in
            holder.subscriber = subscriber
            return inner
        }.start(next: { value in
            log.append("next \(value) begin")
            handle?.dispose()
            log.append("next \(value) end")
        }, error: { error in
            log.append("error \(error)")
        }, completed: {
            log.append("completed")
        })
        holder.subscriber?.putNext(1)
        holder.subscriber?.putNext(2)
        holder.subscriber?.putCompletion()
        XCTAssertEqual(log.events, ["next 1 begin", "dispose", "next 1 end"])
        XCTAssertEqual(inner.disposeCount, 1)
        handle?.dispose()
        XCTAssertEqual(inner.disposeCount, 1)
    }

    func testHandleDisposeFromInsideCompletedCallbackDisposesInnerTwice() {
        let log = CoreEventLog()
        let holder = CoreSubscriberHolder<Int, String>()
        let inner = CoreCountingDisposable(log: log)
        var handle: Disposable?
        handle = Signal<Int, String> { subscriber in
            holder.subscriber = subscriber
            return inner
        }.start(next: { value in
            log.append("next \(value)")
        }, error: { error in
            log.append("error \(error)")
        }, completed: {
            log.append("completed begin")
            handle?.dispose()
            log.append("completed end")
        })
        holder.subscriber?.putCompletion()
        XCTAssertEqual(log.events, ["completed begin", "dispose", "completed end", "dispose"])
        XCTAssertEqual(inner.disposeCount, 2)
        handle?.dispose()
        XCTAssertEqual(inner.disposeCount, 2)
    }

    func testHandleDisposeFromInsideErrorCallbackDisposesInnerTwice() {
        let log = CoreEventLog()
        let holder = CoreSubscriberHolder<Int, String>()
        let inner = CoreCountingDisposable(log: log)
        var handle: Disposable?
        handle = Signal<Int, String> { subscriber in
            holder.subscriber = subscriber
            return inner
        }.start(next: { value in
            log.append("next \(value)")
        }, error: { error in
            log.append("error \(error) begin")
            handle?.dispose()
            log.append("error \(error) end")
        }, completed: {
            log.append("completed")
        })
        holder.subscriber?.putError("e")
        XCTAssertEqual(log.events, ["error e begin", "dispose", "error e end", "dispose"])
        XCTAssertEqual(inner.disposeCount, 2)
        handle?.dispose()
        XCTAssertEqual(inner.disposeCount, 2)
    }

    func testPutCompletionFromInsideNextCallback() {
        let log = CoreEventLog()
        let holder = CoreSubscriberHolder<Int, String>()
        let inner = CoreCountingDisposable(log: log)
        let handle = Signal<Int, String> { subscriber in
            holder.subscriber = subscriber
            return inner
        }.start(next: { value in
            log.append("next \(value) begin")
            holder.subscriber?.putCompletion()
            holder.subscriber?.putNext(value + 100)
            log.append("next \(value) end")
        }, error: { error in
            log.append("error \(error)")
        }, completed: {
            log.append("completed")
        })
        holder.subscriber?.putNext(1)
        holder.subscriber?.putNext(2)
        XCTAssertEqual(log.events, ["next 1 begin", "completed", "dispose", "next 1 end"])
        XCTAssertEqual(inner.disposeCount, 1)
        handle.dispose()
        XCTAssertEqual(inner.disposeCount, 1)
    }

    func testPutNextFromInsideCompletedCallbackIsDropped() {
        let log = CoreEventLog()
        let holder = CoreSubscriberHolder<Int, String>()
        let inner = CoreCountingDisposable(log: log)
        let handle = Signal<Int, String> { subscriber in
            holder.subscriber = subscriber
            return inner
        }.start(next: { value in
            log.append("next \(value)")
        }, error: { error in
            log.append("error \(error)")
        }, completed: {
            log.append("completed")
            holder.subscriber?.putNext(9)
            holder.subscriber?.putCompletion()
        })
        holder.subscriber?.putCompletion()
        XCTAssertEqual(log.events, ["completed", "dispose"])
        handle.dispose()
    }

    func testNextEmittedFromInnerDisposeDuringHandleDisposeIsDelivered() {
        let log = CoreEventLog()
        let holder = CoreSubscriberHolder<Int, String>()
        let inner = CoreCountingDisposable(log: log)
        inner.onDispose = {
            holder.subscriber?.putNext(99)
        }
        let handle = Signal<Int, String> { subscriber in
            holder.subscriber = subscriber
            return inner
        }.start(next: { value in
            log.append("next \(value)")
        }, error: { error in
            log.append("error \(error)")
        }, completed: {
            log.append("completed")
        })
        handle.dispose()
        XCTAssertEqual(log.events, ["dispose", "next 99"])
        holder.subscriber?.putNext(100)
        holder.subscriber?.putCompletion()
        XCTAssertEqual(log.events, ["dispose", "next 99"])
        XCTAssertEqual(inner.disposeCount, 1)
    }

    func testCompletionEmittedFromInnerDisposeDuringHandleDisposeIsDeliveredAndDisposesInnerAgain() {
        let log = CoreEventLog()
        let holder = CoreSubscriberHolder<Int, String>()
        let inner = CoreCountingDisposable(log: log)
        inner.onDispose = {
            holder.subscriber?.putCompletion()
        }
        let handle = Signal<Int, String> { subscriber in
            holder.subscriber = subscriber
            return inner
        }.start(next: { value in
            log.append("next \(value)")
        }, error: { error in
            log.append("error \(error)")
        }, completed: {
            log.append("completed")
        })
        handle.dispose()
        XCTAssertEqual(log.events, ["dispose", "completed", "dispose"])
        XCTAssertEqual(inner.disposeCount, 2)
        handle.dispose()
        XCTAssertEqual(inner.disposeCount, 2)
    }

    func testErrorEmittedFromInnerDisposeDuringHandleDisposeIsDelivered() {
        let log = CoreEventLog()
        let holder = CoreSubscriberHolder<Int, String>()
        let inner = CoreCountingDisposable(log: log)
        inner.onDispose = {
            holder.subscriber?.putError("from dispose")
        }
        let handle = Signal<Int, String> { subscriber in
            holder.subscriber = subscriber
            return inner
        }.start(next: { value in
            log.append("next \(value)")
        }, error: { error in
            log.append("error \(error)")
        }, completed: {
            log.append("completed")
        })
        handle.dispose()
        XCTAssertEqual(log.events, ["dispose", "error from dispose", "dispose"])
        XCTAssertEqual(inner.disposeCount, 2)
    }

    func testReentrantHandleDisposeFromInnerDisposeIsNoop() {
        let log = CoreEventLog()
        let holder = CoreSubscriberHolder<Int, String>()
        let inner = CoreCountingDisposable(log: log)
        var handle: Disposable?
        inner.onDispose = {
            log.append("reentrant dispose")
            handle?.dispose()
        }
        handle = Signal<Int, String> { subscriber in
            holder.subscriber = subscriber
            return inner
        }.start(next: { value in
            log.append("next \(value)")
        })
        handle?.dispose()
        XCTAssertEqual(log.events, ["dispose", "reentrant dispose"])
        XCTAssertEqual(inner.disposeCount, 1)
        holder.subscriber?.putNext(1)
        XCTAssertEqual(log.events, ["dispose", "reentrant dispose"])
        inner.onDispose = nil
    }

    func testDescriptionsInsideInnerDisposeDuringHandleDispose() {
        let holder = CoreSubscriberHolder<Int, String>()
        let inner = CoreCountingDisposable()
        var handle: Disposable?
        var subscriberDescription: String?
        var handleDescription: String?
        inner.onDispose = {
            subscriberDescription = holder.subscriber?.description
            handleDescription = handle.map { String(describing: $0) }
        }
        handle = Signal<Int, String> { subscriber in
            holder.subscriber = subscriber
            return inner
        }.start(next: { _ in
        })
        handle?.dispose()
        XCTAssertEqual(subscriberDescription, "Subscriber { next: hasValue, error: nil, completed: nil, disposable: hasValue, terminated: false }")
        XCTAssertEqual(handleDescription, "SubscriberDisposable { disposable: nil }")
        XCTAssertEqual(holder.subscriber?.description, "Subscriber { next: nil, error: nil, completed: nil, disposable: nil, terminated: true }")
        inner.onDispose = nil
    }

    func testDescriptionsInsideCallbacks() {
        let holder = CoreSubscriberHolder<Int, String>()
        var handle: Disposable?
        var duringNext: String?
        var duringCompleted: String?
        var handleDuringCompleted: String?
        handle = Signal<Int, String> { subscriber in
            holder.subscriber = subscriber
            return CoreCountingDisposable()
        }.start(next: { _ in
            duringNext = holder.subscriber?.description
        }, completed: {
            duringCompleted = holder.subscriber?.description
            handleDuringCompleted = handle.map { String(describing: $0) }
        })
        holder.subscriber?.putNext(1)
        holder.subscriber?.putCompletion()
        XCTAssertEqual(duringNext, "Subscriber { next: hasValue, error: nil, completed: hasValue, disposable: hasValue, terminated: false }")
        XCTAssertEqual(duringCompleted, "Subscriber { next: nil, error: nil, completed: nil, disposable: nil, terminated: true }")
        XCTAssertEqual(handleDuringCompleted, "SubscriberDisposable { disposable: hasValue }")
        handle?.dispose()
    }

    func testDescriptionInsideErrorCallback() {
        let holder = CoreSubscriberHolder<Int, String>()
        var duringError: String?
        let handle = Signal<Int, String> { subscriber in
            holder.subscriber = subscriber
            return CoreCountingDisposable()
        }.start(next: { _ in
        }, error: { _ in
            duringError = holder.subscriber?.description
        })
        holder.subscriber?.putError("e")
        XCTAssertEqual(duringError, "Subscriber { next: nil, error: nil, completed: nil, disposable: nil, terminated: true }")
        handle.dispose()
    }

    func testDroppedHandleDoesNotStopDeliveryAndCompletionStillDisposesInner() {
        let log = CoreEventLog()
        let holder = CoreSubscriberHolder<Int, String>()
        let inner = CoreCountingDisposable(log: log)
        do {
            let _ = Signal<Int, String> { subscriber in
                holder.subscriber = subscriber
                return inner
            }.start(next: { value in
                log.append("next \(value)")
            }, error: { error in
                log.append("error \(error)")
            }, completed: {
                log.append("completed")
            })
        }
        holder.subscriber?.putNext(1)
        holder.subscriber?.putCompletion()
        XCTAssertEqual(log.events, ["next 1", "completed", "dispose"])
        XCTAssertEqual(inner.disposeCount, 1)
    }

    func testDroppedHandleThenErrorStillDisposesInner() {
        let log = CoreEventLog()
        let holder = CoreSubscriberHolder<Int, String>()
        let inner = CoreCountingDisposable(log: log)
        do {
            let _ = Signal<Int, String> { subscriber in
                holder.subscriber = subscriber
                return inner
            }.start(error: { error in
                log.append("error \(error)")
            })
        }
        holder.subscriber?.putError("e")
        XCTAssertEqual(log.events, ["error e", "dispose"])
    }

    func testHandleDisposeDisposesInnerEvenAfterSubscriberWasReleased() {
        let log = CoreEventLog()
        let inner = CoreCountingDisposable(log: log)
        let handle = Signal<Int, String> { _ in
            return inner
        }.start(next: { value in
            log.append("next \(value)")
        })
        XCTAssertEqual(log.events, [])
        handle.dispose()
        handle.dispose()
        XCTAssertEqual(log.events, ["dispose"])
        XCTAssertEqual(inner.disposeCount, 1)
    }

    func testHandleDisposeAfterSourceDroppedSubscriberDisposesInnerOnce() {
        let log = CoreEventLog()
        let holder = CoreSubscriberHolder<Int, String>()
        let inner = CoreCountingDisposable(log: log)
        let handle = Signal<Int, String> { subscriber in
            holder.subscriber = subscriber
            return inner
        }.start(next: { value in
            log.append("next \(value)")
        })
        holder.subscriber?.putNext(1)
        holder.subscriber = nil
        handle.dispose()
        handle.dispose()
        XCTAssertEqual(log.events, ["next 1", "dispose"])
        XCTAssertEqual(inner.disposeCount, 1)
    }

    func testDirectlyConstructedSubscriberDeliversUntilTerminated() {
        let log = CoreEventLog()
        let subscriber = Subscriber<Int, String>(next: { value in
            log.append("next \(value)")
        }, error: { error in
            log.append("error \(error)")
        }, completed: {
            log.append("completed")
        })
        subscriber.putNext(1)
        subscriber.putNext(2)
        subscriber.putCompletion()
        subscriber.putNext(3)
        subscriber.putError("e")
        subscriber.putCompletion()
        XCTAssertEqual(log.events, ["next 1", "next 2", "completed"])
    }

    func testDirectlyConstructedSubscriberErrorTerminates() {
        let log = CoreEventLog()
        let subscriber = Subscriber<Int, String>(next: { value in
            log.append("next \(value)")
        }, error: { error in
            log.append("error \(error)")
        }, completed: {
            log.append("completed")
        })
        subscriber.putError("first")
        subscriber.putError("second")
        subscriber.putNext(1)
        subscriber.putCompletion()
        XCTAssertEqual(log.events, ["error first"])
    }

    func testDirectlyConstructedSubscriberWithoutCallbacks() {
        let subscriber = Subscriber<Int, String>()
        subscriber.putNext(1)
        subscriber.putError("e")
        subscriber.putCompletion()
        XCTAssertEqual(subscriber.description, "Subscriber { next: nil, error: nil, completed: nil, disposable: nil, terminated: true }")
    }

    func testSubscriberDescriptionThroughLifecycle() {
        let holder = CoreSubscriberHolder<Int, String>()
        var insideGenerator = ""
        let handle = Signal<Int, String> { subscriber in
            holder.subscriber = subscriber
            insideGenerator = subscriber.description
            return CoreCountingDisposable()
        }.start(next: { _ in
        })
        XCTAssertEqual(insideGenerator, "Subscriber { next: hasValue, error: nil, completed: nil, disposable: nil, terminated: false }")
        XCTAssertEqual(holder.subscriber?.description, "Subscriber { next: hasValue, error: nil, completed: nil, disposable: hasValue, terminated: false }")
        holder.subscriber?.putCompletion()
        XCTAssertEqual(holder.subscriber?.description, "Subscriber { next: nil, error: nil, completed: nil, disposable: nil, terminated: true }")
        handle.dispose()
        XCTAssertEqual(holder.subscriber?.description, "Subscriber { next: nil, error: nil, completed: nil, disposable: nil, terminated: true }")
    }

    func testSubscriberDescriptionWithAllCallbacksAndHandleDispose() {
        let holder = CoreSubscriberHolder<Int, String>()
        let handle = Signal<Int, String> { subscriber in
            holder.subscriber = subscriber
            return EmptyDisposable
        }.start(next: { _ in
        }, error: { _ in
        }, completed: {
        })
        XCTAssertEqual(holder.subscriber?.description, "Subscriber { next: hasValue, error: hasValue, completed: hasValue, disposable: hasValue, terminated: false }")
        handle.dispose()
        XCTAssertEqual(holder.subscriber?.description, "Subscriber { next: nil, error: nil, completed: nil, disposable: nil, terminated: true }")
    }

    func testSubscriberDescriptionAfterError() {
        let holder = CoreSubscriberHolder<Int, String>()
        let handle = Signal<Int, String> { subscriber in
            holder.subscriber = subscriber
            return EmptyDisposable
        }.start(error: { _ in
        })
        XCTAssertEqual(holder.subscriber?.description, "Subscriber { next: nil, error: hasValue, completed: nil, disposable: hasValue, terminated: false }")
        holder.subscriber?.putError("e")
        XCTAssertEqual(holder.subscriber?.description, "Subscriber { next: nil, error: nil, completed: nil, disposable: nil, terminated: true }")
        handle.dispose()
    }

    func testSubscriberDescriptionAfterSynchronousCompletionInGeneratorAndDroppedHandle() {
        let holder = CoreSubscriberHolder<Int, String>()
        let handle = Signal<Int, String> { subscriber in
            holder.subscriber = subscriber
            subscriber.putCompletion()
            return CoreCountingDisposable()
        }.start(next: { _ in
        }, completed: {
        })
        XCTAssertEqual(holder.subscriber?.description, "Subscriber { next: nil, error: nil, completed: nil, disposable: nil, terminated: true }")
        handle.dispose()

        let liveHolder = CoreSubscriberHolder<Int, String>()
        do {
            let _ = Signal<Int, String> { subscriber in
                liveHolder.subscriber = subscriber
                return CoreCountingDisposable()
            }.start(completed: {
            })
        }
        XCTAssertEqual(liveHolder.subscriber?.description, "Subscriber { next: nil, error: nil, completed: hasValue, disposable: hasValue, terminated: false }")
    }

    func testDirectlyConstructedSubscriberDescription() {
        let subscriber = Subscriber<Int, String>(next: { _ in
        }, completed: {
        })
        XCTAssertEqual(subscriber.description, "Subscriber { next: hasValue, error: nil, completed: hasValue, disposable: nil, terminated: false }")
        XCTAssertEqual(String(describing: subscriber), subscriber.description)
    }

    func testHandleDescriptionBeforeAndAfterDispose() {
        let holder = CoreSubscriberHolder<Int, String>()
        let handle = Signal<Int, String> { subscriber in
            holder.subscriber = subscriber
            return CoreCountingDisposable()
        }.start()
        XCTAssertEqual(String(describing: handle), "SubscriberDisposable { disposable: hasValue }")
        handle.dispose()
        XCTAssertEqual(String(describing: handle), "SubscriberDisposable { disposable: nil }")
    }

    func testHandleDescriptionAfterAsynchronousCompletionWithoutDispose() {
        let holder = CoreSubscriberHolder<Int, String>()
        let handle = Signal<Int, String> { subscriber in
            holder.subscriber = subscriber
            return CoreCountingDisposable()
        }.start()
        holder.subscriber?.putCompletion()
        XCTAssertEqual(String(describing: handle), "SubscriberDisposable { disposable: hasValue }")
        handle.dispose()
        XCTAssertEqual(String(describing: handle), "SubscriberDisposable { disposable: nil }")
    }

    func testHandleDescriptionForSynchronouslyCompletedSignal() {
        let handle = Signal<Int, String>.single(1).start()
        XCTAssertEqual(String(describing: handle), "SubscriberDisposable { disposable: hasValue }")
        handle.dispose()
        XCTAssertEqual(String(describing: handle), "SubscriberDisposable { disposable: nil }")
    }

    func testHandleDescriptionForNeverSignal() {
        let handle = Signal<Int, String>.never().start(next: { _ in
        })
        XCTAssertEqual(String(describing: handle), "SubscriberDisposable { disposable: hasValue }")
        handle.dispose()
        XCTAssertEqual(String(describing: handle), "SubscriberDisposable { disposable: nil }")
    }

    func testConcurrentPutNextDeliversEveryValue() {
        let counter = CoreCounter()
        let holder = CoreSubscriberHolder<Int, String>()
        let handle = Signal<Int, String> { subscriber in
            holder.subscriber = subscriber
            return EmptyDisposable
        }.start(next: { _ in
            counter.increment()
        })
        let subscriber = holder.subscriber!
        DispatchQueue.concurrentPerform(iterations: 2000) { index in
            subscriber.putNext(index)
        }
        XCTAssertEqual(counter.value, 2000)
        handle.dispose()
    }

    func testConcurrentPutCompletionDeliversOnceAndDisposesInnerOnce() {
        for _ in 0 ..< 50 {
            let completions = CoreCounter()
            let errors = CoreCounter()
            let holder = CoreSubscriberHolder<Int, String>()
            let inner = CoreCountingDisposable()
            let handle = Signal<Int, String> { subscriber in
                holder.subscriber = subscriber
                return inner
            }.start(error: { _ in
                errors.increment()
            }, completed: {
                completions.increment()
            })
            let subscriber = holder.subscriber!
            DispatchQueue.concurrentPerform(iterations: 16) { index in
                if index % 2 == 0 {
                    subscriber.putCompletion()
                } else {
                    subscriber.putError("e")
                }
            }
            XCTAssertEqual(completions.value + errors.value, 1)
            XCTAssertEqual(inner.disposeCount, 1)
            handle.dispose()
            XCTAssertEqual(inner.disposeCount, 1)
        }
    }

    func testConcurrentHandleDisposeDisposesInnerOnce() {
        for _ in 0 ..< 50 {
            let holder = CoreSubscriberHolder<Int, String>()
            let inner = CoreCountingDisposable()
            let handle = Signal<Int, String> { subscriber in
                holder.subscriber = subscriber
                return inner
            }.start(next: { _ in
            })
            DispatchQueue.concurrentPerform(iterations: 16) { _ in
                handle.dispose()
            }
            XCTAssertEqual(inner.disposeCount, 1)
        }
    }

    func testNoDeliveryFromAnyThreadAfterHandleDisposeReturns() {
        let counter = CoreCounter()
        let holder = CoreSubscriberHolder<Int, String>()
        let handle = Signal<Int, String> { subscriber in
            holder.subscriber = subscriber
            return EmptyDisposable
        }.start(next: { _ in
            counter.increment()
        }, error: { _ in
            counter.increment()
        }, completed: {
            counter.increment()
        })
        handle.dispose()
        let subscriber = holder.subscriber!
        DispatchQueue.concurrentPerform(iterations: 200) { index in
            subscriber.putNext(index)
            if index == 100 {
                subscriber.putCompletion()
            }
        }
        XCTAssertEqual(counter.value, 0)
    }
}
