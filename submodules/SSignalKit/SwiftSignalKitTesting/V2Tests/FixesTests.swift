import XCTest
import Foundation
@testable import SwiftSignalKit2

private final class Probe {
    let onDeinit: () -> Void

    init(_ onDeinit: @escaping () -> Void) {
        self.onDeinit = onDeinit
    }

    deinit {
        self.onDeinit()
    }
}

private final class Counter {
    private var lock = os_unfair_lock()
    private var storage = 0

    func increment() {
        os_unfair_lock_lock(&self.lock)
        self.storage += 1
        os_unfair_lock_unlock(&self.lock)
    }

    var value: Int {
        os_unfair_lock_lock(&self.lock)
        let value = self.storage
        os_unfair_lock_unlock(&self.lock)
        return value
    }
}

private final class CountingDisposable: Disposable {
    let counter: Counter

    init(_ counter: Counter) {
        self.counter = counter
    }

    func dispose() {
        self.counter.increment()
    }
}

final class FixesTests: XCTestCase {
    private func runWithDeadlockGuard(_ name: String, timeout: TimeInterval = 2.0, _ body: @escaping () -> Void, file: StaticString = #filePath, line: UInt = #line) {
        let done = DispatchSemaphore(value: 0)
        let thread = Thread {
            body()
            done.signal()
        }
        thread.start()
        if done.wait(timeout: .now() + timeout) == .timedOut {
            XCTFail("\(name) deadlocked", file: file, line: line)
        }
    }

    func testDisposableDictSetNilRemovesTheEntry() {
        let dict = DisposableDict<String>()
        let count = Counter()
        weak var weakDisposable: CountingDisposable?
        do {
            let disposable = CountingDisposable(count)
            weakDisposable = disposable
            dict.set(disposable, forKey: "a")
        }
        dict.set(nil, forKey: "a")
        XCTAssertEqual(count.value, 1)
        XCTAssertNil(weakDisposable)
        dict.set(nil, forKey: "a")
        dict.dispose()
        XCTAssertEqual(count.value, 1)
    }

    func testDisposableSetRemoveLastOnEmptySetIsANoOp() {
        let set = DisposableSet()
        set.removeLast()
        let count = Counter()
        set.add(CountingDisposable(count))
        set.removeLast()
        set.removeLast()
        set.dispose()
        XCTAssertEqual(count.value, 0)
    }

    func testTimerStartTwiceKeepsOneActiveSource() {
        let queue = Queue()
        let fired = Counter()
        let timer = SwiftSignalKit2.Timer(timeout: 0.02, repeat: true, completion: {
            fired.increment()
        }, queue: queue)
        timer.start()
        timer.start()
        Thread.sleep(forTimeInterval: 0.21)
        timer.invalidate()
        queue.sync {
        }
        let firedAfterInvalidate = fired.value
        Thread.sleep(forTimeInterval: 0.1)
        queue.sync {
        }
        XCTAssertEqual(fired.value, firedAfterInvalidate)
        XCTAssertLessThanOrEqual(firedAfterInvalidate, 14)
        XCTAssertGreaterThanOrEqual(firedAfterInvalidate, 2)
    }
    
    func testMulticastDisposesUpstreamWhenLastSubscriberLeaves() {
        let multicast = Multicast<Int>()
        let upstreamDisposed = Counter()
        let upstream = Signal<Int, NoError> { subscriber in
            subscriber.putNext(1)
            return ActionDisposable {
                upstreamDisposed.increment()
            }
        }
        var received: [Int] = []
        let handle = multicast.get(key: "k", signal: upstream).start(next: { received.append($0) })
        XCTAssertEqual(received, [1])
        XCTAssertEqual(upstreamDisposed.value, 0)
        handle.dispose()
        XCTAssertEqual(upstreamDisposed.value, 1)
    }

    func testFeedbackLoopReleasesItsStateAfterDispose() {
        weak var weakProbe: Probe?
        let handle: Disposable
        do {
            let probe = Probe({})
            weakProbe = probe
            let signal: Signal<Int, NoError> = feedbackLoop(once: { _ -> Signal<Int, NoError>? in
                withExtendedLifetime(probe, {})
                return .never()
            }, reduce: { $0 + $1 })
            handle = signal.start()
        }
        XCTAssertNotNil(weakProbe)
        handle.dispose()
        XCTAssertNil(weakProbe)
    }
    
    func testFeedbackLoopCompletingReleasesItsState() {
        weak var weakProbe: Probe?
        var completed = false
        var iterations = 0
        do {
            let probe = Probe({})
            weakProbe = probe
            let signal: Signal<Int, NoError> = feedbackLoop(once: { _ -> Signal<Int, NoError>? in
                withExtendedLifetime(probe, {})
                iterations += 1
                if iterations > 3 {
                    return nil
                }
                return .complete()
            }, reduce: { $0 + $1 })
            let _ = signal.start(completed: {
                completed = true
            })
        }
        XCTAssertTrue(completed)
        XCTAssertEqual(iterations, 4)
        XCTAssertNil(weakProbe)
    }
    
    func testValuePromiseReplacedValueDeinitMayReenterThePromise() {
        final class Box: Equatable {
            let probe: Probe?
            init(_ probe: Probe?) {
                self.probe = probe
            }
            static func ==(lhs: Box, rhs: Box) -> Bool {
                return lhs === rhs
            }
        }
        self.runWithDeadlockGuard("ValuePromise.set") {
            var promise: ValuePromise<Box>!
            promise = ValuePromise<Box>(Box(Probe({
                promise.get().start().dispose()
            })))
            promise.set(Box(nil))
        }
    }

    func testPromiseReplacedValueDeinitMayReenterThePromise() {
        self.runWithDeadlockGuard("Promise.set") {
            var promise: Promise<Probe>!
            promise = Promise<Probe>(Probe({
                promise.get().start().dispose()
            }))
            promise.set(.single(Probe({})))
        }
    }

    func testAtomicReplacedValueDeinitMayReenterTheAtomic() {
        self.runWithDeadlockGuard("Atomic.modify") {
            var atomic: Atomic<Probe?>!
            atomic = Atomic<Probe?>(value: Probe({
                let _ = atomic.with { $0 }
            }))
            let _ = atomic.modify { _ in nil }
        }
    }

    func testValuePipeSubscriptionDisposeMayReenterThePipe() {
        self.runWithDeadlockGuard("ValuePipe dispose") {
            let pipe = ValuePipe<Int>()
            let handle: Disposable
            do {
                let probe = Probe({
                    pipe.putNext(1)
                })
                handle = pipe.signal().start(next: { _ in
                    withExtendedLifetime(probe, {})
                })
            }
            handle.dispose()
        }
    }

    func testSubscriberClosureDeinitMayReenterTheSameSubscriber() {
        self.runWithDeadlockGuard("Subscriber markTerminated") {
            var captured: Subscriber<Int, NoError>?
            let handle: Disposable
            do {
                let signal = Signal<Int, NoError> { subscriber in
                    captured = subscriber
                    return EmptyDisposable
                }
                let probe = Probe({
                    captured?.putNext(2)
                    captured?.putCompletion()
                })
                handle = signal.start(next: { _ in
                    withExtendedLifetime(probe, {})
                })
            }
            handle.dispose()
            captured = nil
        }
    }

    func testDisposableSetRemoveLastReleasesOutsideTheLock() {
        self.runWithDeadlockGuard("DisposableSet.removeLast") {
            let set = DisposableSet()
            do {
                let probe = Probe({
                    set.add(EmptyDisposable)
                })
                set.add(ActionDisposable {
                    withExtendedLifetime(probe, {})
                })
            }
            set.removeLast()
            set.dispose()
        }
    }
    
    func testThrottledDroppedSignalDeinitMayReenterTheSubscription() {
        self.runWithDeadlockGuard("throttled drop") {
            let pipe = ValuePipe<Int>()
            let gate = ValuePipe<Int>()
            let reentered = Counter()
            var handle: Disposable?
            handle = (pipe.signal() |> mapToThrottled { value -> Signal<Int, NoError> in
                let probe = Probe({
                    if value == 2 && reentered.value == 0 {
                        reentered.increment()
                        pipe.putNext(-1)
                    }
                })
                return Signal { subscriber in
                    withExtendedLifetime(probe, {})
                    return gate.signal().start(next: { subscriber.putNext($0 + value) })
                }
            }).start()
            pipe.putNext(1)
            pipe.putNext(2)
            pipe.putNext(3)
            handle?.dispose()
            handle = nil
            XCTAssertEqual(reentered.value, 1)
        }
    }

    func testRunOnCancellationFlagIsRaceFree() {
        let queue = Queue()
        for _ in 0 ..< 200 {
            let started = Counter()
            let handle = (Signal<Int, NoError> { _ in
                started.increment()
                return EmptyDisposable
            } |> runOn(queue)).start()
            DispatchQueue.global().async {
                handle.dispose()
            }
            queue.sync {
            }
            XCTAssertLessThanOrEqual(started.value, 1)
        }
    }

    func testSubscriberCoreReleasesInnerDisposableAfterTermination() {
        weak var weakInner: CountingDisposable?
        let count = Counter()
        var captured: Subscriber<Int, NoError>?
        let handle: Disposable
        do {
            let inner = CountingDisposable(count)
            weakInner = inner
            handle = Signal<Int, NoError> { subscriber in
                captured = subscriber
                return inner
            }.start()
        }
        XCTAssertNotNil(weakInner)
        captured?.putCompletion()
        XCTAssertNil(weakInner)
        XCTAssertEqual(count.value, 1)
        handle.dispose()
        XCTAssertEqual(count.value, 1)
        captured = nil
    }

    func testHandleKeepsNoClosuresAliveAfterSourceDropsTheSubscriber() {
        weak var weakProbe: Probe?
        var handle: Disposable?
        do {
            let probe = Probe({})
            weakProbe = probe
            handle = Signal<Int, NoError>.never().start(next: { _ in
                withExtendedLifetime(probe, {})
            })
        }
        XCTAssertNil(weakProbe)
        XCTAssertNotNil(handle)
        handle?.dispose()
    }
}
