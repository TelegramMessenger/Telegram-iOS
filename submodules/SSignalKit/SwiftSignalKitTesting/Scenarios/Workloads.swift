#if SSK_LEGACY
import SwiftSignalKitLegacy
#else
import SwiftSignalKit2
#endif
import Foundation

public struct Workload {
    public let name: String
    public let operations: Int
    public let run: () -> Void
}

@inline(never)
func blackHole<T>(_ value: T) {
}

final class Counter {
    var value = 0
}

public func memoryWorkloads() -> [(String, Int, (Int) -> [AnyObject])] {
    return [
        ("live never().start", 20000, { count in
            var result: [AnyObject] = []
            result.reserveCapacity(count)
            let signal = Signal<Int, NoError>.never()
            for _ in 0 ..< count {
                result.append(signal.start(next: { blackHole($0) }))
            }
            return result
        }),
        ("live pipe |> map x5 subscription", 20000, { count in
            var result: [AnyObject] = []
            result.reserveCapacity(count + 1)
            let pipe = ValuePipe<Int>()
            result.append(pipe)
            let signal = pipe.signal() |> map { $0 + 1 } |> map { $0 + 1 } |> map { $0 + 1 } |> map { $0 + 1 } |> map { $0 + 1 }
            for _ in 0 ..< count {
                result.append(signal.start(next: { blackHole($0) }))
            }
            return result
        }),
        ("live combineLatest(3 promises)", 20000, { count in
            var result: [AnyObject] = []
            result.reserveCapacity(count + 3)
            let a = ValuePromise<Int>(1)
            let b = ValuePromise<Int>(2)
            let c = ValuePromise<Int>(3)
            result.append(a)
            result.append(b)
            result.append(c)
            let signal = combineLatest(a.get(), b.get(), c.get())
            for _ in 0 ..< count {
                result.append(signal.start(next: { blackHole($0) }))
            }
            return result
        }),
        ("live mapToSignal(pipe -> never)", 20000, { count in
            var result: [AnyObject] = []
            result.reserveCapacity(count + 1)
            let promise = ValuePromise<Int>(1)
            result.append(promise)
            let signal = promise.get() |> mapToSignal { value -> Signal<Int, NoError> in
                return Signal<Int, NoError>.never() |> map { $0 + value }
            }
            for _ in 0 ..< count {
                result.append(signal.start(next: { blackHole($0) }))
            }
            return result
        }),
        ("completed single().start handles kept", 20000, { count in
            var result: [AnyObject] = []
            result.reserveCapacity(count)
            let signal = Signal<Int, NoError>.single(1)
            for _ in 0 ..< count {
                result.append(signal.start(next: { blackHole($0) }))
            }
            return result
        }),
        ("MetaDisposable + ActionDisposable", 20000, { count in
            var result: [AnyObject] = []
            result.reserveCapacity(count)
            for i in 0 ..< count {
                let meta = MetaDisposable()
                meta.set(ActionDisposable {
                    blackHole(i)
                })
                result.append(meta)
            }
            return result
        }),
        ("Atomic<Int>", 20000, { count in
            var result: [AnyObject] = []
            result.reserveCapacity(count)
            for i in 0 ..< count {
                result.append(Atomic<Int>(value: i))
            }
            return result
        }),
    ]
}

public func workloads(scale: Int) -> [Workload] {
    var result: [Workload] = []

    let n = 200_000 * scale

    result.append(Workload(name: "single().start + dispose", operations: n, run: {
        let signal = Signal<Int, NoError>.single(1)
        for _ in 0 ..< n {
            signal.start(next: { blackHole($0) }).dispose()
        }
    }))

    result.append(Workload(name: "never().start + dispose", operations: n, run: {
        let signal = Signal<Int, NoError>.never()
        for _ in 0 ..< n {
            signal.start(next: { blackHole($0) }).dispose()
        }
    }))

    result.append(Workload(name: "subscribe single |> map x10", operations: n / 4, run: {
        var signal = Signal<Int, NoError>.single(1)
        for _ in 0 ..< 10 {
            signal = signal |> map { $0 &+ 1 }
        }
        for _ in 0 ..< n / 4 {
            let _ = signal.start(next: { blackHole($0) })
        }
    }))

    result.append(Workload(name: "pipe |> map x10, putNext", operations: n * 2, run: {
        let pipe = ValuePipe<Int>()
        var signal = pipe.signal()
        for _ in 0 ..< 10 {
            signal = signal |> map { $0 &+ 1 }
        }
        let disposable = signal.start(next: { blackHole($0) })
        for i in 0 ..< n * 2 {
            pipe.putNext(i)
        }
        disposable.dispose()
    }))

    result.append(Workload(name: "pipe |> filter |> distinct |> map, putNext", operations: n * 2, run: {
        let pipe = ValuePipe<Int>()
        let signal = pipe.signal() |> filter { $0 % 3 != 0 } |> map { $0 / 2 } |> distinctUntilChanged |> map { $0 &* 2 }
        let disposable = signal.start(next: { blackHole($0) })
        for i in 0 ..< n * 2 {
            pipe.putNext(i)
        }
        disposable.dispose()
    }))

    result.append(Workload(name: "pipe |> mapToSignal(single |> map), putNext", operations: n, run: {
        let pipe = ValuePipe<Int>()
        let signal = pipe.signal() |> mapToSignal { value -> Signal<Int, NoError> in
            return .single(value) |> map { $0 &+ 1 }
        }
        let disposable = signal.start(next: { blackHole($0) })
        for i in 0 ..< n {
            pipe.putNext(i)
        }
        disposable.dispose()
    }))

    result.append(Workload(name: "pipe |> mapToSignal(promise.get()), putNext", operations: n, run: {
        let pipe = ValuePipe<Int>()
        let promise = ValuePromise<Int>(1)
        let signal = pipe.signal() |> mapToSignal { value -> Signal<Int, NoError> in
            return promise.get() |> map { $0 &+ value }
        }
        let disposable = signal.start(next: { blackHole($0) })
        for i in 0 ..< n {
            pipe.putNext(i)
        }
        disposable.dispose()
    }))

    result.append(Workload(name: "combineLatest(3 promises), set", operations: n, run: {
        let a = ValuePromise<Int>(0)
        let b = ValuePromise<Int>(0)
        let c = ValuePromise<Int>(0)
        let disposable = combineLatest(a.get(), b.get(), c.get()).start(next: { blackHole($0) })
        for i in 0 ..< n {
            switch i % 3 {
            case 0:
                a.set(i)
            case 1:
                b.set(i)
            default:
                c.set(i)
            }
        }
        disposable.dispose()
    }))

    result.append(Workload(name: "combineLatest(8 singles) subscribe", operations: n / 8, run: {
        let signals = (0 ..< 8).map { Signal<Int, NoError>.single($0) }
        let signal = combineLatest(signals[0], signals[1], signals[2], signals[3], signals[4], signals[5], signals[6], signals[7])
        for _ in 0 ..< n / 8 {
            let _ = signal.start(next: { blackHole($0) })
        }
    }))

    result.append(Workload(name: "combineLatest([16 promises]) set", operations: n / 2, run: {
        let promises = (0 ..< 16).map { ValuePromise<Int>($0) }
        let disposable = combineLatest(promises.map { $0.get() }).start(next: { blackHole($0) })
        for i in 0 ..< n / 2 {
            promises[i % 16].set(i)
        }
        disposable.dispose()
    }))

    result.append(Workload(name: "Promise.set(single) with 3 subscribers", operations: n, run: {
        let promise = Promise<Int>()
        let d1 = promise.get().start(next: { blackHole($0) })
        let d2 = promise.get().start(next: { blackHole($0) })
        let d3 = promise.get().start(next: { blackHole($0) })
        for i in 0 ..< n {
            promise.set(.single(i))
        }
        d1.dispose()
        d2.dispose()
        d3.dispose()
    }))

    result.append(Workload(name: "ValuePromise.get() subscribe + dispose", operations: n, run: {
        let promise = ValuePromise<Int>(1)
        let signal = promise.get()
        for _ in 0 ..< n {
            signal.start(next: { blackHole($0) }).dispose()
        }
    }))

    result.append(Workload(name: "take(1) over promise subscribe", operations: n, run: {
        let promise = ValuePromise<Int>(1)
        let signal = promise.get() |> take(1)
        for _ in 0 ..< n {
            let _ = signal.start(next: { blackHole($0) })
        }
    }))

    result.append(Workload(name: "then/catch/deliverOnMain chain subscribe (main)", operations: n / 4, run: {
        let signal = (Signal<Int, Int>.fail(1) |> `catch` { _ in Signal<Int, Int>.single(2) }) |> then(.single(3)) |> deliverOnMainQueue |> mapError { $0 }
        for _ in 0 ..< n / 4 {
            let _ = signal.start(next: { blackHole($0) })
        }
    }))

    result.append(Workload(name: "MetaDisposable.set(ActionDisposable)", operations: n * 2, run: {
        let meta = MetaDisposable()
        for i in 0 ..< n * 2 {
            meta.set(ActionDisposable {
                blackHole(i)
            })
        }
        meta.dispose()
    }))

    result.append(Workload(name: "DisposableSet add x16 + dispose", operations: n, run: {
        for _ in 0 ..< n / 16 {
            let set = DisposableSet()
            for _ in 0 ..< 16 {
                set.add(EmptyDisposable)
            }
            set.dispose()
        }
    }))

    result.append(Workload(name: "Atomic.modify", operations: n * 4, run: {
        let atomic = Atomic<Int>(value: 0)
        for _ in 0 ..< n * 4 {
            let _ = atomic.modify { $0 &+ 1 }
        }
    }))

    result.append(Workload(name: "Bag add/remove with 64 items", operations: n, run: {
        let bag = Bag<Int>()
        var indices: [Int] = []
        for i in 0 ..< 64 {
            indices.append(bag.add(i))
        }
        for i in 0 ..< n {
            let slot = i % 64
            bag.remove(indices[slot])
            indices[slot] = bag.add(i)
        }
        blackHole(bag.copyItems())
    }))

    result.append(Workload(name: "Queue.isCurrent (main + custom)", operations: n * 4, run: {
        let queue = Queue()
        let main = Queue.mainQueue()
        var count = 0
        for _ in 0 ..< n * 2 {
            if queue.isCurrent() {
                count += 1
            }
            if main.isCurrent() {
                count += 1
            }
        }
        blackHole(count)
    }))

    result.append(Workload(name: "pipe |> deliverOn(queue), putNext x(n/2)", operations: n / 2, run: {
        let queue = Queue()
        let pipe = ValuePipe<Int>()
        let done = DispatchSemaphore(value: 0)
        let total = n / 2
        let counter = Counter()
        let disposable = (pipe.signal() |> deliverOn(queue)).start(next: { _ in
            counter.value += 1
            if counter.value == total {
                done.signal()
            }
        })
        for i in 0 ..< total {
            pipe.putNext(i)
        }
        done.wait()
        disposable.dispose()
    }))

    result.append(Workload(name: "8 threads x pipe |> map x4 putNext", operations: n * 2, run: {
        let pipe = ValuePipe<Int>()
        let signal = pipe.signal() |> map { $0 &+ 1 } |> map { $0 &+ 1 } |> map { $0 &+ 1 } |> map { $0 &+ 1 }
        let disposable = signal.start(next: { blackHole($0) })
        let per = n * 2 / 8
        DispatchQueue.concurrentPerform(iterations: 8) { t in
            for i in 0 ..< per {
                pipe.putNext(i &+ t)
            }
        }
        disposable.dispose()
    }))

    result.append(Workload(name: "8 threads x start/dispose map x3 over promise", operations: n, run: {
        let promise = ValuePromise<Int>(1)
        let signal = promise.get() |> map { $0 &+ 1 } |> map { $0 &+ 1 } |> map { $0 &+ 1 }
        let per = n / 8
        DispatchQueue.concurrentPerform(iterations: 8) { _ in
            for _ in 0 ..< per {
                signal.start(next: { blackHole($0) }).dispose()
            }
        }
    }))

    return result
}
