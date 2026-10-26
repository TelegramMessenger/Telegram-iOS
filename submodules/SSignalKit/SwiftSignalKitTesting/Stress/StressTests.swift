import XCTest
import Foundation
#if SSK_LEGACY
import SwiftSignalKitLegacy
#else
import SwiftSignalKit2
#endif

private final class StressCounter {
    private var lock = pthread_mutex_t()
    private var storage = 0

    init() {
        pthread_mutex_init(&self.lock, nil)
    }

    deinit {
        pthread_mutex_destroy(&self.lock)
    }

    func increment() {
        pthread_mutex_lock(&self.lock)
        self.storage += 1
        pthread_mutex_unlock(&self.lock)
    }

    var value: Int {
        pthread_mutex_lock(&self.lock)
        let value = self.storage
        pthread_mutex_unlock(&self.lock)
        return value
    }
}

private let createdTrackedObjects = StressCounter()
private let destroyedTrackedObjects = StressCounter()

private final class Tracked {
    init() {
        createdTrackedObjects.increment()
    }

    deinit {
        destroyedTrackedObjects.increment()
    }

    @inline(never)
    func touch() {
    }
}

private final class CountingDisposable: Disposable {
    let counter: StressCounter

    init(_ counter: StressCounter) {
        self.counter = counter
    }

    func dispose() {
        self.counter.increment()
    }
}

private final class SubscriberHolder {
    private var lock = pthread_mutex_t()
    private var subscribers: [Subscriber<Int, NoError>] = []

    init() {
        pthread_mutex_init(&self.lock, nil)
    }

    deinit {
        pthread_mutex_destroy(&self.lock)
    }

    func add(_ subscriber: Subscriber<Int, NoError>) {
        pthread_mutex_lock(&self.lock)
        self.subscribers.append(subscriber)
        pthread_mutex_unlock(&self.lock)
    }

    func snapshot() -> [Subscriber<Int, NoError>] {
        pthread_mutex_lock(&self.lock)
        let result = self.subscribers
        pthread_mutex_unlock(&self.lock)
        return result
    }

    func removeAll() {
        pthread_mutex_lock(&self.lock)
        let removed = self.subscribers
        self.subscribers = []
        pthread_mutex_unlock(&self.lock)
        withExtendedLifetime(removed, {})
    }
}

final class StressTests: XCTestCase {
    private var trackedBaseline = 0
    
    override func setUp() {
        super.setUp()
        self.trackedBaseline = createdTrackedObjects.value - destroyedTrackedObjects.value
    }
    
    private func waitOrFail(_ group: DispatchGroup, file: StaticString = #filePath, line: UInt = #line) {
        if group.wait(timeout: .now() + 10.0) == .timedOut {
            XCTFail("timed out: possible deadlock", file: file, line: line)
        }
    }
    
    private var iterations: Int {
        return Int(ProcessInfo.processInfo.environment["SSK_STRESS_ITERATIONS"] ?? "") ?? 300
    }

    private func assertNoTrackedLeaks(file: StaticString = #filePath, line: UInt = #line) {
        let deadline = Date().addingTimeInterval(5.0)
        while createdTrackedObjects.value - destroyedTrackedObjects.value != self.trackedBaseline && Date() < deadline {
            usleep(1000)
        }
        XCTAssertEqual(createdTrackedObjects.value - destroyedTrackedObjects.value, self.trackedBaseline, "tracked objects leaked", file: file, line: line)
    }

    func testConcurrentPutNextAndDispose() {
        for _ in 0 ..< self.iterations {
            let holder = SubscriberHolder()
            let innerDisposeCount = StressCounter()
            let terminalCount = StressCounter()
            let tracked = Tracked()
            let signal = Signal<Int, NoError> { subscriber in
                holder.add(subscriber)
                return CountingDisposable(innerDisposeCount)
            }
            let handle = signal.start(next: { _ in
                tracked.touch()
            }, completed: {
                tracked.touch()
                terminalCount.increment()
            })
            let group = DispatchGroup()
            for t in 0 ..< 4 {
                DispatchQueue.global().async(group: group) {
                    for i in 0 ..< 50 {
                        for subscriber in holder.snapshot() {
                            if t == 3 && i == 25 {
                                subscriber.putCompletion()
                            } else {
                                subscriber.putNext(i)
                            }
                        }
                    }
                }
            }
            DispatchQueue.global().async(group: group) {
                handle.dispose()
            }
            self.waitOrFail(group)
            holder.removeAll()
            XCTAssertLessThanOrEqual(terminalCount.value, 1)
            XCTAssertGreaterThanOrEqual(innerDisposeCount.value, 1)
            XCTAssertLessThanOrEqual(innerDisposeCount.value, 2)
        }
        self.assertNoTrackedLeaks()
    }

    func testSubscriberReleaseRacingHandleDispose() {
        for _ in 0 ..< self.iterations * 4 {
            let holder = SubscriberHolder()
            let innerDisposeCount = StressCounter()
            let tracked = Tracked()
            let signal = Signal<Int, NoError> { subscriber in
                holder.add(subscriber)
                return CountingDisposable(innerDisposeCount)
            }
            let handle = signal.start(next: { _ in
                tracked.touch()
            })
            let group = DispatchGroup()
            DispatchQueue.global().async(group: group) {
                holder.removeAll()
            }
            DispatchQueue.global().async(group: group) {
                handle.dispose()
            }
            self.waitOrFail(group)
            XCTAssertLessThanOrEqual(innerDisposeCount.value, 1)
        }
        self.assertNoTrackedLeaks()
    }

    func testMetaDisposableConcurrentSetAndDispose() {
        for _ in 0 ..< self.iterations {
            let meta = MetaDisposable()
            let setCount = StressCounter()
            let disposeCount = StressCounter()
            DispatchQueue.concurrentPerform(iterations: 8) { t in
                for i in 0 ..< 40 {
                    if t == 7 && i == 20 {
                        meta.dispose()
                    } else {
                        setCount.increment()
                        meta.set(ActionDisposable {
                            disposeCount.increment()
                        })
                    }
                }
            }
            meta.dispose()
            XCTAssertEqual(setCount.value, disposeCount.value)
        }
    }

    func testDisposableSetConcurrentAddAndDispose() {
        for _ in 0 ..< self.iterations {
            let set = DisposableSet()
            let addCount = StressCounter()
            let disposeCount = StressCounter()
            DispatchQueue.concurrentPerform(iterations: 8) { t in
                for i in 0 ..< 40 {
                    if t == 0 && i == 20 {
                        set.dispose()
                    } else {
                        addCount.increment()
                        set.add(ActionDisposable {
                            disposeCount.increment()
                        })
                    }
                }
            }
            set.dispose()
            XCTAssertEqual(addCount.value, disposeCount.value)
        }
    }

    func testActionDisposableRunsOnceUnderContention() {
        for _ in 0 ..< self.iterations {
            let count = StressCounter()
            let disposable = ActionDisposable {
                count.increment()
            }
            DispatchQueue.concurrentPerform(iterations: 8) { _ in
                disposable.dispose()
            }
            XCTAssertEqual(count.value, 1)
        }
    }

    func testValuePromiseConcurrentSetAndSubscribe() {
        for _ in 0 ..< self.iterations / 3 {
            let promise = ValuePromise<Int>(0, ignoreRepeated: true)
            let handles = Atomic<[Disposable]>(value: [])
            let tracked = Tracked()
            DispatchQueue.concurrentPerform(iterations: 8) { t in
                for i in 0 ..< 30 {
                    if t % 2 == 0 {
                        promise.set(t * 1000 + i)
                    } else {
                        let handle = promise.get().start(next: { _ in
                            tracked.touch()
                        })
                        let _ = handles.modify { $0 + [handle] }
                        if i % 3 == 0 {
                            handle.dispose()
                        }
                    }
                }
            }
            promise.set(-1)
            var last: Int?
            promise.get().start(next: { last = $0 }).dispose()
            XCTAssertEqual(last, -1)
            for handle in handles.swap([]) {
                handle.dispose()
            }
        }
        self.assertNoTrackedLeaks()
    }

    func testPromiseConcurrentSetSignal() {
        for _ in 0 ..< self.iterations / 3 {
            let promise = Promise<Int>()
            let received = StressCounter()
            let handle = promise.get().start(next: { _ in
                received.increment()
            })
            DispatchQueue.concurrentPerform(iterations: 8) { t in
                for i in 0 ..< 20 {
                    promise.set(.single(t * 100 + i))
                }
            }
            promise.set(.single(-1))
            var last: Int?
            promise.get().start(next: { last = $0 }).dispose()
            XCTAssertEqual(last, -1)
            handle.dispose()
            XCTAssertGreaterThan(received.value, 0)
        }
    }

    func testMapToSignalConcurrentOuterEmissionsDisposeEverything() {
        for _ in 0 ..< self.iterations / 3 {
            let pipe = ValuePipe<Int>()
            let subscribeCount = StressCounter()
            let disposeCount = StressCounter()
            let tracked = Tracked()
            let signal = pipe.signal() |> mapToSignal { value -> Signal<Int, NoError> in
                return Signal { subscriber in
                    subscribeCount.increment()
                    subscriber.putNext(value)
                    return ActionDisposable {
                        disposeCount.increment()
                    }
                }
            }
            let handle = signal.start(next: { _ in
                tracked.touch()
            })
            DispatchQueue.concurrentPerform(iterations: 8) { t in
                for i in 0 ..< 30 {
                    pipe.putNext(t * 100 + i)
                }
            }
            handle.dispose()
            XCTAssertEqual(subscribeCount.value, disposeCount.value)
        }
        self.assertNoTrackedLeaks()
    }

    func testCombineLatestConcurrentEmittersSettlesOnLastValues() {
        for _ in 0 ..< self.iterations / 3 {
            let a = ValuePromise<Int>(0)
            let b = ValuePromise<Int>(0)
            let latest = Atomic<(Int, Int)?>(value: nil)
            let handle = combineLatest(a.get(), b.get()).start(next: { value in
                let _ = latest.swap(value)
            })
            DispatchQueue.concurrentPerform(iterations: 8) { t in
                for i in 0 ..< 30 {
                    if t % 2 == 0 {
                        a.set(t * 100 + i)
                    } else {
                        b.set(t * 100 + i)
                    }
                }
            }
            a.set(-1)
            b.set(-2)
            let final = latest.with { $0 }
            XCTAssertEqual(final?.0, -1)
            XCTAssertEqual(final?.1, -2)
            handle.dispose()
        }
    }

    func testDeliverOnPreservesOrderFromOneProducer() {
        let queue = Queue()
        for _ in 0 ..< max(1, self.iterations / 30) {
            let pipe = ValuePipe<Int>()
            let received = Atomic<[Int]>(value: [])
            let done = expectation(description: "delivered")
            let count = 500
            let handle = (pipe.signal() |> deliverOn(queue)).start(next: { value in
                let all = received.modify { $0 + [value] }
                if all.count == count {
                    done.fulfill()
                }
            })
            DispatchQueue.global().async {
                for i in 0 ..< count {
                    pipe.putNext(i)
                }
            }
            wait(for: [done], timeout: 10.0)
            XCTAssertEqual(received.with { $0 }, Array(0 ..< count))
            handle.dispose()
        }
    }

    func testRunOnDisposeRace() {
        let queue = Queue()
        for _ in 0 ..< self.iterations {
            let started = StressCounter()
            let disposed = StressCounter()
            let signal = Signal<Int, NoError> { _ in
                started.increment()
                return ActionDisposable {
                    disposed.increment()
                }
            } |> runOn(queue)
            let handle = signal.start()
            DispatchQueue.global().async {
                handle.dispose()
            }
            queue.sync {
            }
            usleep(50)
            queue.sync {
            }
            XCTAssertLessThanOrEqual(started.value, 1)
        }
    }

    func testAtomicConcurrentModify() {
        let atomic = Atomic<Int>(value: 0)
        DispatchQueue.concurrentPerform(iterations: 8) { _ in
            for _ in 0 ..< 10_000 {
                let _ = atomic.modify { $0 + 1 }
            }
        }
        XCTAssertEqual(atomic.with { $0 }, 80_000)
    }

    func testTimerStartInvalidateRace() {
        let queue = Queue()
        for _ in 0 ..< self.iterations {
            let fired = StressCounter()
            let timer = SwiftSignalKitTimer(timeout: 0.0005, repeat: false, completion: {
                fired.increment()
            }, queue: queue)
            timer.start()
            DispatchQueue.global().async {
                timer.invalidate()
            }
            queue.sync {
            }
            XCTAssertLessThanOrEqual(fired.value, 1)
        }
    }

    func testDeepChainsStartDisposeFromManyThreadsDoNotLeak() {
        do {
            let promise = ValuePromise<Int>(1)
            let tracked = Tracked()
            var signal = promise.get()
            for i in 0 ..< 6 {
                signal = signal |> map { $0 + i } |> distinctUntilChanged |> filter { _ in true }
            }
            let chained = signal |> mapToSignal { value -> Signal<Int, NoError> in
                return combineLatest(.single(value), promise.get()) |> map { $0 + $1 } |> take(1)
            }
            let iterations = self.iterations
            DispatchQueue.concurrentPerform(iterations: 8) { t in
                for i in 0 ..< iterations {
                    let handle = chained.start(next: { _ in
                        tracked.touch()
                    })
                    if i % 7 == t {
                        promise.set(i)
                    }
                    handle.dispose()
                }
            }
        }
        self.assertNoTrackedLeaks()
    }
}

#if SSK_LEGACY
private typealias SwiftSignalKitTimer = SwiftSignalKitLegacy.Timer
#else
private typealias SwiftSignalKitTimer = SwiftSignalKit2.Timer
#endif
