#if SSK_LEGACY
import SwiftSignalKitLegacy
#else
import SwiftSignalKit2
#endif
import Foundation

final class Hub {
    let id: Int
    let trace: Trace
    var subscribers: [(Int, Subscriber<Int, Int>)] = []
    var serial = 0
    var emitOnDispose: Int?

    init(id: Int, trace: Trace) {
        self.id = id
        self.trace = trace
    }

    func signal() -> Signal<Int, Int> {
        return Signal { [weak self] subscriber in
            guard let self = self else {
                return EmptyDisposable
            }
            let key = self.serial
            self.serial += 1
            self.trace.log("hub\(self.id) subscribe #\(key)")
            self.subscribers.append((key, subscriber))
            let trace = self.trace
            let id = self.id
            let emitOnDispose = self.emitOnDispose
            let emitTarget: Subscriber<Int, Int>? = emitOnDispose != nil ? subscriber : nil
            return ActionDisposable { [weak self] in
                trace.log("hub\(id) dispose #\(key)")
                if let emitOnDispose = emitOnDispose, let emitTarget = emitTarget {
                    emitTarget.putNext(emitOnDispose)
                }
                if let self = self {
                    self.subscribers.removeAll(where: { $0.0 == key })
                }
            }
        }
    }

    func emit(_ value: Int) {
        let subscribers = self.subscribers
        for (_, subscriber) in subscribers {
            subscriber.putNext(value)
        }
    }

    func complete() {
        let subscribers = self.subscribers
        for (_, subscriber) in subscribers {
            subscriber.putCompletion()
        }
    }

    func fail(_ error: Int) {
        let subscribers = self.subscribers
        for (_, subscriber) in subscribers {
            subscriber.putError(error)
        }
    }

    func drop() {
        self.subscribers.removeAll()
    }
}

func neverToInt(_ value: Never) -> Int {
}

final class HandleBox {
    var disposable: Disposable?
    var isStrict = false
}

final class FuzzWorld {
    let trace: Trace
    var rng: SplitMix64
    var hubs: [Hub] = []
    var valuePromises: [ValuePromise<Int>] = []
    var promises: [Promise<Int>] = []
    var pipes: [ValuePipe<Int>] = []
    var pipelines: [(String, Signal<Int, Int>)] = []
    var restartablePipelines: [(String, Signal<Int, Int>)] = []
    var handles: [Int: HandleBox] = [:]
    var metaDisposable = MetaDisposable()
    var disposableSet = DisposableSet()
    var sentinels: [WeakRef<Sentinel>] = []
    var sentinelCounter = 0
    var subscriptionCounter = 0
    var reentrancyBudget = 64
    var halted = false

    init(seed: UInt64) {
        self.trace = Trace()
        self.trace.limit = 20000
        self.rng = SplitMix64(seed: seed)
    }

    func sentinel(_ tag: String) -> Sentinel {
        self.sentinelCounter += 1
        let sentinel = Sentinel("\(tag)#\(self.sentinelCounter)", self.trace)
        self.sentinels.append(WeakRef(sentinel))
        return sentinel
    }

    func log(_ event: String) {
        self.trace.log(event)
    }

    func leafSignal(allowSync: Bool) -> (String, Signal<Int, Int>) {
        let trace = self.trace
        let choice = allowSync ? self.rng.int(13) : self.rng.int(6)
        switch choice {
        case 0, 1, 2:
            let hub = self.hubs[self.rng.int(self.hubs.count)]
            return ("hub\(hub.id)", hub.signal())
        case 3:
            let index = self.rng.int(self.valuePromises.count)
            return ("vp\(index)", self.valuePromises[index].get() |> castError(Int.self))
        case 4:
            let index = self.rng.int(self.promises.count)
            return ("p\(index)", self.promises[index].get() |> castError(Int.self))
        case 5:
            let index = self.rng.int(self.pipes.count)
            return ("pipe\(index)", self.pipes[index].signal() |> castError(Int.self))
        case 6:
            let value = self.rng.int(10)
            return ("single(\(value))", .single(value))
        case 7:
            return ("complete", .complete())
        case 8:
            let value = self.rng.int(10)
            return ("fail(\(value))", .fail(value))
        case 9:
            return ("never", .never())
        case 10:
            let count = 1 + self.rng.int(3)
            let base = self.rng.int(10)
            let failAtEnd = self.rng.chance(30)
            let name = "sync\(base)x\(count)\(failAtEnd ? "!" : "")"
            return (name, Signal<Int, Int> { subscriber in
                for i in 0 ..< count {
                    subscriber.putNext(base + i)
                }
                if failAtEnd {
                    subscriber.putError(base)
                } else {
                    subscriber.putCompletion()
                }
                return ActionDisposable {
                    trace.log("\(name) dispose")
                }
            })
        case 11:
            let value = self.rng.int(10)
            return ("free.single(\(value))", single(value, Int.self))
        default:
            let disposableName = "cd\(self.rng.int(1000))"
            let value = self.rng.int(10)
            let completeSync = self.rng.chance(50)
            return ("counting(\(disposableName))", Signal<Int, Int> { subscriber in
                subscriber.putNext(value)
                if completeSync {
                    subscriber.putCompletion()
                }
                return CountingDisposable(disposableName, trace)
            })
        }
    }

    func restartableSignal() -> (String, Signal<Int, Int>) {
        let hub = self.hubs[self.rng.int(self.hubs.count)]
        let addend = self.rng.int(5)
        return ("hub\(hub.id)+\(addend)", hub.signal() |> map { $0 + addend })
    }

    func pipeline(depth: Int, allowSync: Bool = true) -> (String, Signal<Int, Int>) {
        if depth <= 0 || self.rng.chance(15) {
            return self.leafSignal(allowSync: allowSync)
        }
        let trace = self.trace
        let operatorIndex = self.rng.int(45)
        switch operatorIndex {
        case 0:
            let (name, signal) = self.pipeline(depth: depth - 1, allowSync: allowSync)
            let sentinel = self.sentinel("map")
            let k = self.rng.int(5)
            return ("map(\(name))", signal |> map { value in
                sentinel.touch()
                return value * 2 + k
            })
        case 1:
            let (name, signal) = self.pipeline(depth: depth - 1, allowSync: allowSync)
            let m = 2 + self.rng.int(3)
            return ("filter(\(name))", signal |> filter { $0 % m != 0 })
        case 2:
            let (name, signal) = self.pipeline(depth: depth - 1, allowSync: allowSync)
            let n = self.rng.int(4)
            return ("take\(n)(\(name))", signal |> take(n))
        case 3:
            let (name, signal) = self.pipeline(depth: depth - 1, allowSync: allowSync)
            return ("distinct(\(name))", signal |> distinctUntilChanged)
        case 4:
            let (name, signal) = self.pipeline(depth: depth - 1, allowSync: allowSync)
            return ("distinctIsEqual(\(name))", signal |> distinctUntilChanged(isEqual: { $0 / 2 == $1 / 2 }))
        case 5, 6, 7:
            let (name, signal) = self.pipeline(depth: depth - 1, allowSync: allowSync)
            var inners: [(String, Signal<Int, Int>)] = []
            for _ in 0 ..< 3 {
                inners.append(self.pipeline(depth: depth - 2, allowSync: allowSync))
            }
            let world = self
            let tag = "mapToSignal"
            return ("mapToSignal(\(name) -> [\(inners.map { $0.0 }.joined(separator: ","))])", signal |> mapToSignal { value -> Signal<Int, Int> in
                let inner = inners[abs(value) % inners.count]
                trace.log("\(tag) f(\(value)) -> \(inner.0)")
                let sentinel = world.sentinel("inner")
                return inner.1 |> map { innerValue in
                    sentinel.touch()
                    return innerValue + value
                }
            })
        case 8:
            let (name, signal) = self.pipeline(depth: depth - 1, allowSync: allowSync)
            let inners = (0 ..< 2).map { _ in self.pipeline(depth: depth - 2, allowSync: allowSync) }
            return ("mapToQueue(\(name))", signal |> mapToQueue { value -> Signal<Int, Int> in
                let inner = inners[abs(value) % inners.count]
                trace.log("mapToQueue f(\(value)) -> \(inner.0)")
                return inner.1 |> map { $0 + value * 100 }
            })
        case 9:
            let (name, signal) = self.pipeline(depth: depth - 1, allowSync: allowSync)
            let inners = (0 ..< 2).map { _ in self.pipeline(depth: depth - 2, allowSync: allowSync) }
            return ("mapToThrottled(\(name))", signal |> mapToThrottled { value -> Signal<Int, Int> in
                let inner = inners[abs(value) % inners.count]
                trace.log("mapToThrottled f(\(value)) -> \(inner.0)")
                return inner.1 |> map { $0 + value * 100 }
            })
        case 10:
            let (a, sa) = self.pipeline(depth: depth - 1, allowSync: allowSync)
            let (b, sb) = self.pipeline(depth: depth - 1, allowSync: allowSync)
            return ("combine(\(a),\(b))", combineLatest(sa, sb) |> map { $0 &* 10 &+ $1 })
        case 11:
            let (a, sa) = self.pipeline(depth: depth - 1, allowSync: allowSync)
            let (b, sb) = self.pipeline(depth: depth - 1, allowSync: allowSync)
            let ia = self.rng.int(5)
            let ib = self.rng.int(5)
            return ("combineInit(\(a),\(b))", combineLatest(sa, ia, sb, ib) |> map { $0 &* 10 &+ $1 })
        case 12:
            let (a, sa) = self.pipeline(depth: depth - 1, allowSync: allowSync)
            let (b, sb) = self.pipeline(depth: depth - 1, allowSync: allowSync)
            let (c, sc) = self.pipeline(depth: depth - 1, allowSync: allowSync)
            return ("combine3(\(a),\(b),\(c))", combineLatest(sa, sb, sc) |> map { $0 &* 100 &+ $1 &* 10 &+ $2 })
        case 13:
            let count = self.rng.int(4)
            let items = (0 ..< count).map { _ in self.pipeline(depth: depth - 1, allowSync: allowSync) }
            return ("combineArray(\(items.map { $0.0 }.joined(separator: ",")))", combineLatest(items.map { $0.1 }) |> map { values in values.reduce(count, { $0 &* 7 &+ $1 }) })
        case 14:
            let (a, sa) = self.pipeline(depth: depth - 1, allowSync: allowSync)
            let (b, sb) = self.pipeline(depth: depth - 1, allowSync: allowSync)
            return ("then(\(a),\(b))", sa |> then(sb))
        case 15:
            let (a, sa) = self.pipeline(depth: depth - 1, allowSync: allowSync)
            let alternatives = (0 ..< 2).map { _ in self.pipeline(depth: depth - 1, allowSync: allowSync) }
            return ("catch(\(a))", sa |> `catch` { error -> Signal<Int, Int> in
                let alternative = alternatives[abs(error) % alternatives.count]
                trace.log("catch f(\(error)) -> \(alternative.0)")
                return alternative.1
            })
        case 16:
            let (a, sa) = self.pipeline(depth: depth - 1, allowSync: allowSync)
            return ("mapError(\(a))", sa |> mapError { $0 + 100 })
        case 17:
            let (a, sa) = self.restartableSignal()
            return ("restartIfError(\(a))", restartIfError(sa) |> castError(Int.self))
        case 18:
            let (a, sa) = self.restartableSignal()
            return ("restartOrMapError(\(a))", sa |> restartOrMapError(condition: { error -> RestartOrMapErrorCondition<Int> in
                trace.log("restartOrMapError condition(\(error))")
                if error % 2 == 0 {
                    return .restart
                } else {
                    return .error(error + 1000)
                }
            }))
        case 19:
            let (a, sa) = self.restartableSignal()
            return ("restart(\(a))", restart(sa))
        case 20:
            let (a, sa) = self.restartableSignal()
            return ("recurse(\(a))", sa |> recurse(nil))
        case 21:
            let (a, sa) = self.pipeline(depth: depth - 1, allowSync: allowSync)
            return ("ignoreValues(\(a))", sa |> ignoreValues |> map(neverToInt))
        case 22:
            let (a, sa) = self.pipeline(depth: depth - 1, allowSync: allowSync)
            return ("takeLast(\(a))", sa |> takeLast)
        case 23:
            let (a, sa) = self.pipeline(depth: depth - 1, allowSync: allowSync)
            return ("last(\(a))", last(signal: sa) |> map { $0 ?? -7 })
        case 24:
            let (a, sa) = self.pipeline(depth: depth - 1, allowSync: allowSync)
            return ("takeUntil(\(a))", sa |> take(until: { value in
                return SignalTakeAction(passthrough: value % 3 != 0, complete: value % 5 == 0)
            }))
        case 25:
            let (a, sa) = self.pipeline(depth: depth - 1, allowSync: allowSync)
            return ("reduceLeft(\(a))", sa |> reduceLeft(value: 1, f: { $0 &+ $1 }))
        case 26:
            let (a, sa) = self.pipeline(depth: depth - 1, allowSync: allowSync)
            return ("reduceLeftEmit(\(a))", sa |> reduceLeft(value: 0, f: { (current: Int, next: Int, emit: (Int) -> Void) -> Int in
                if next % 2 == 0 {
                    emit(current)
                }
                return current &+ next
            }))
        case 27:
            let (a, sa) = self.pipeline(depth: depth - 1, allowSync: allowSync)
            let hub = self.hubs[self.rng.int(self.hubs.count)]
            let useHub = self.rng.chance(30)
            return ("reduceLeftGenerator(\(a))", sa |> reduceLeft(0, generator: { (current: Int, next: Int) -> Signal<(Int, Passthrough<Int>), Int> in
                trace.log("reduceGenerator(\(current), \(next))")
                if useHub && next % 3 == 0 {
                    return hub.signal() |> take(1) |> map { value in
                        return (current &+ value, Passthrough.Some(value))
                    }
                }
                return .single((current &+ next, next % 2 == 0 ? Passthrough.Some(current) : Passthrough.None))
            }))
        case 28:
            let (a, sa) = self.pipeline(depth: depth - 1, allowSync: allowSync)
            return ("beforeNext(\(a))", sa |> beforeNext { value in
                trace.log("beforeNext \(value)")
            })
        case 29:
            let (a, sa) = self.pipeline(depth: depth - 1, allowSync: allowSync)
            return ("afterNext(\(a))", sa |> afterNext { value in
                trace.log("afterNext \(value)")
            })
        case 30:
            let (a, sa) = self.pipeline(depth: depth - 1, allowSync: allowSync)
            return ("beforeStarted(\(a))", sa |> beforeStarted {
                trace.log("beforeStarted")
            })
        case 31:
            let (a, sa) = self.pipeline(depth: depth - 1, allowSync: allowSync)
            return ("beforeCompleted(\(a))", sa |> beforeCompleted {
                trace.log("beforeCompleted")
            })
        case 32:
            let (a, sa) = self.pipeline(depth: depth - 1, allowSync: allowSync)
            return ("afterCompleted(\(a))", sa |> afterCompleted {
                trace.log("afterCompleted")
            })
        case 33:
            let (a, sa) = self.pipeline(depth: depth - 1, allowSync: allowSync)
            let sentinel = self.sentinel("afterDisposed")
            return ("afterDisposed(\(a))", sa |> afterDisposed {
                sentinel.touch()
                trace.log("afterDisposed")
            })
        case 34:
            let (a, sa) = self.pipeline(depth: depth - 1, allowSync: allowSync)
            let world = self
            return ("withState(\(a))", withState(sa, { () -> Sentinel in
                return world.sentinel("state")
            }, next: { value, state in
                trace.log("withState next \(value) \(state.name)")
            }, error: { error, state in
                trace.log("withState error \(error) \(state.name)")
            }, completed: { state in
                trace.log("withState completed \(state.name)")
            }, disposed: { state in
                trace.log("withState disposed \(state.name)")
            }))
        case 35:
            let (a, sa) = self.pipeline(depth: depth - 1, allowSync: allowSync)
            return ("deferred(\(a))", deferred { () -> Signal<Int, Int> in
                trace.log("deferred generator")
                return sa
            })
        case 36:
            let (a, sa) = self.pipeline(depth: depth - 1, allowSync: allowSync)
            return ("materialize(\(a))", materialize(signal: dematerialize(signal: sa)))
        case 37:
            let (a, sa) = self.pipeline(depth: depth - 1, allowSync: allowSync)
            return ("deliverOnMain(\(a))", sa |> deliverOnMainQueue)
        case 38:
            let (a, sa) = self.pipeline(depth: depth - 1, allowSync: allowSync)
            return ("runOnMain(\(a))", sa |> runOn(Queue.mainQueue()))
        case 39:
            let (a, sa) = self.pipeline(depth: depth - 1, allowSync: allowSync)
            let inners = (0 ..< 2).map { _ in self.pipeline(depth: depth - 2, allowSync: allowSync) }
            let mode = self.rng.int(3)
            let nested: Signal<Signal<Int, Int>, Int> = sa |> map { value -> Signal<Int, Int> in
                let inner = inners[abs(value) % inners.count]
                trace.log("nested(\(value)) -> \(inner.0)")
                return inner.1
            }
            switch mode {
            case 0:
                return ("switchToLatest(\(a))", nested |> switchToLatest)
            case 1:
                return ("queue(\(a))", nested |> queue)
            default:
                return ("throttled(\(a))", nested |> throttled)
            }
        case 40:
            let index = self.rng.int(self.promises.count)
            let inners = (0 ..< 2).map { _ in self.pipeline(depth: depth - 1, allowSync: allowSync) }
            return ("mapToSignalPromotingError(p\(index))", self.promises[index].get() |> mapToSignalPromotingError { value -> Signal<Int, Int> in
                let inner = inners[abs(value) % inners.count]
                trace.log("promoting f(\(value)) -> \(inner.0)")
                return inner.1
            })
        case 41:
            let (a, sa) = self.pipeline(depth: depth - 1, allowSync: allowSync)
            let hub = self.hubs[self.rng.int(self.hubs.count)]
            return ("thenHub(\(a))", sa |> then(hub.signal() |> take(1)))
        case 42:
            let (a, sa) = self.pipeline(depth: depth - 1, allowSync: allowSync)
            return ("flatMapOptional(\(a))", (sa |> map { value -> Int? in value % 4 == 0 ? nil : value }) |> flatMap { $0 * 3 } |> map { $0 ?? -1 })
        case 43:
            let (a, sa) = self.pipeline(depth: depth - 1, allowSync: allowSync)
            let world = self
            return ("keepAlive(\(a))", Signal<Int, Int> { subscriber in
                subscriber.keepAlive(world.sentinel("keepAlive"))
                return sa.start(next: { value in
                    subscriber.putNext(value)
                }, error: { error in
                    subscriber.putError(error)
                }, completed: {
                    subscriber.putCompletion()
                })
            })
        default:
            let (a, sa) = self.pipeline(depth: depth - 1, allowSync: allowSync)
            let (b, sb) = self.pipeline(depth: depth - 1, allowSync: allowSync)
            return ("combineQueueMain(\(a),\(b))", combineLatest(queue: Queue.mainQueue(), sa, sb) |> map { $0 &- $1 })
        }
    }

    func setup() {
        let hubCount = 2 + self.rng.int(3)
        for i in 0 ..< hubCount {
            let hub = Hub(id: i, trace: self.trace)
            if self.rng.chance(15) {
                hub.emitOnDispose = 900 + i
            }
            self.hubs.append(hub)
        }
        for _ in 0 ..< 2 {
            if self.rng.chance(50) {
                self.valuePromises.append(ValuePromise<Int>(self.rng.int(5), ignoreRepeated: self.rng.chance(50)))
            } else {
                self.valuePromises.append(ValuePromise<Int>(ignoreRepeated: self.rng.chance(50)))
            }
        }
        for _ in 0 ..< 2 {
            if self.rng.chance(50) {
                self.promises.append(Promise<Int>(self.rng.int(5)))
            } else {
                self.promises.append(Promise<Int>())
            }
        }
        for _ in 0 ..< 2 {
            self.pipes.append(ValuePipe<Int>())
        }
        let pipelineCount = 2 + self.rng.int(4)
        for _ in 0 ..< pipelineCount {
            self.pipelines.append(self.pipeline(depth: 1 + self.rng.int(4)))
        }
        for (index, pipeline) in self.pipelines.enumerated() {
            self.log("pipeline\(index) = \(pipeline.0)")
        }
    }

    func startSubscription(nested: Bool) {
        let pipelineIndex = self.rng.int(self.pipelines.count)
        let pipeline = self.pipelines[pipelineIndex].1
        self.subscriptionCounter += 1
        let id = self.subscriptionCounter
        let box = HandleBox()
        self.handles[id] = box
        let trace = self.trace
        let sentinel = self.sentinel("sub\(id)")
        let disposeOnValue: Int? = self.rng.chance(20) ? self.rng.int(30) : nil
        let emitOnValue: (Int, Int, Int)? = self.rng.chance(15) ? (self.rng.int(30), self.rng.int(self.hubs.count), self.rng.int(30)) : nil
        let startOnValue: Int? = self.rng.chance(10) ? self.rng.int(30) : nil
        let disposeOnCompletion = self.rng.chance(15)
        let startMode = self.rng.int(4)
        let nilCallbacks = self.rng.chance(10)
        self.log("start s\(id) pipeline\(pipelineIndex) mode\(startMode)\(nested ? " nested" : "")")

        let next: (Int) -> Void = { [weak self] value in
            sentinel.touch()
            trace.log("s\(id) next \(value)")
            guard let self = self, !self.halted else {
                return
            }
            if let disposeOnValue = disposeOnValue, disposeOnValue == value {
                trace.log("s\(id) dispose-self")
                box.disposable?.dispose()
            }
            if let (onValue, hubIndex, emitValue) = emitOnValue, onValue == value, self.reentrancyBudget > 0 {
                self.reentrancyBudget -= 1
                trace.log("s\(id) reentrant emit hub\(hubIndex) \(emitValue)")
                self.hubs[hubIndex].emit(emitValue)
            }
            if let startOnValue = startOnValue, startOnValue == value, self.reentrancyBudget > 0 {
                self.reentrancyBudget -= 1
                self.startSubscription(nested: true)
            }
        }
        let error: (Int) -> Void = { value in
            sentinel.touch()
            trace.log("s\(id) error \(value)")
        }
        let completed: () -> Void = {
            sentinel.touch()
            trace.log("s\(id) completed")
            if disposeOnCompletion {
                trace.log("s\(id) dispose-on-completion")
                box.disposable?.dispose()
            }
        }

        let disposable: Disposable
        switch startMode {
        case 0:
            if nilCallbacks {
                disposable = pipeline.start()
            } else {
                disposable = pipeline.start(next: next, error: error, completed: completed)
            }
        case 1:
            disposable = pipeline.startStandalone(next: next, error: error, completed: completed)
        case 2:
            disposable = pipeline.startStrict(next: next, error: error, completed: completed)
            box.isStrict = true
        default:
            if nilCallbacks {
                disposable = pipeline.start(next: next)
            } else {
                disposable = pipeline.start(next: next, error: error, completed: completed)
            }
        }
        box.disposable = disposable
        self.log("started s\(id)")
    }

    func step() {
        let action = self.rng.int(100)
        switch action {
        case 0 ..< 18:
            self.startSubscription(nested: false)
        case 18 ..< 38:
            let hub = self.hubs[self.rng.int(self.hubs.count)]
            let value = self.rng.int(30)
            self.log("action hub\(hub.id) emit \(value)")
            hub.emit(value)
        case 38 ..< 43:
            let hub = self.hubs[self.rng.int(self.hubs.count)]
            self.log("action hub\(hub.id) complete")
            hub.complete()
        case 43 ..< 47:
            let hub = self.hubs[self.rng.int(self.hubs.count)]
            let value = self.rng.int(30)
            self.log("action hub\(hub.id) fail \(value)")
            hub.fail(value)
        case 47 ..< 50:
            let hub = self.hubs[self.rng.int(self.hubs.count)]
            self.log("action hub\(hub.id) drop")
            hub.drop()
        case 50 ..< 62:
            let ids = self.handles.keys.sorted()
            if !ids.isEmpty {
                let id = ids[self.rng.int(ids.count)]
                self.log("action dispose s\(id)")
                if let box = self.handles[id] {
                    box.disposable?.dispose()
                    if self.rng.chance(50) {
                        self.handles.removeValue(forKey: id)
                    }
                }
            }
        case 62 ..< 67:
            let ids = self.handles.keys.sorted()
            if !ids.isEmpty {
                let id = ids[self.rng.int(ids.count)]
                if let box = self.handles[id], !box.isStrict {
                    self.log("action release s\(id)")
                    self.handles.removeValue(forKey: id)
                    box.disposable = nil
                }
            }
        case 67 ..< 73:
            let index = self.rng.int(self.valuePromises.count)
            let value = self.rng.int(30)
            self.log("action vp\(index) set \(value)")
            self.valuePromises[index].set(value)
        case 73 ..< 78:
            let index = self.rng.int(self.promises.count)
            let value = self.rng.int(30)
            if self.rng.chance(70) {
                self.log("action p\(index) set single \(value)")
                self.promises[index].set(.single(value))
            } else {
                let hub = self.hubs[self.rng.int(self.hubs.count)]
                self.log("action p\(index) set hub\(hub.id)")
                self.promises[index].set(hub.signal() |> `catch` { _ in .complete() })
            }
        case 78 ..< 84:
            let index = self.rng.int(self.pipes.count)
            let value = self.rng.int(30)
            self.log("action pipe\(index) put \(value)")
            self.pipes[index].putNext(value)
        case 84 ..< 88:
            let ids = self.handles.keys.sorted()
            if !ids.isEmpty {
                let id = ids[self.rng.int(ids.count)]
                if let box = self.handles[id], let disposable = box.disposable {
                    self.log("action meta set s\(id)")
                    self.metaDisposable.set(disposable)
                }
            }
        case 88 ..< 90:
            self.log("action meta set nil")
            self.metaDisposable.set(nil)
        case 90 ..< 94:
            let ids = self.handles.keys.sorted()
            if !ids.isEmpty {
                let id = ids[self.rng.int(ids.count)]
                if let box = self.handles[id], let disposable = box.disposable {
                    self.log("action set add s\(id)")
                    self.disposableSet.add(disposable)
                }
            }
        case 94 ..< 96:
            self.log("action set dispose")
            self.disposableSet.dispose()
            self.disposableSet = DisposableSet()
        default:
            let hub = self.hubs[self.rng.int(self.hubs.count)]
            let value = self.rng.int(30)
            self.log("action hub\(hub.id) emit-twice \(value)")
            hub.emit(value)
            hub.emit(value)
        }
    }

    func teardown() {
        self.halted = true
        self.log("teardown")
        for id in self.handles.keys.sorted() {
            if let box = self.handles[id] {
                box.disposable?.dispose()
            }
        }
        self.handles.removeAll()
        self.metaDisposable.dispose()
        self.disposableSet.dispose()
        for hub in self.hubs {
            hub.drop()
        }
        self.log("teardown released")
        self.pipelines.removeAll()
        self.restartablePipelines.removeAll()
        self.hubs.removeAll()
        self.valuePromises.removeAll()
        self.promises.removeAll()
        self.pipes.removeAll()
        self.metaDisposable = MetaDisposable()
        self.disposableSet = DisposableSet()
        var leaked: [String] = []
        for sentinel in self.sentinels {
            if let value = sentinel.value {
                leaked.append(value.name)
            }
        }
        self.log("leaked sentinels: \(leaked.joined(separator: ","))")
    }
}

public struct FuzzResult {
    public let events: [String]
    public let overflowed: Bool
}

public func runFuzz(seed: UInt64, steps: Int) -> FuzzResult {
    let trace: Trace
    do {
        let world = FuzzWorld(seed: seed)
        trace = world.trace
        world.setup()
        for _ in 0 ..< steps {
            world.step()
        }
        world.teardown()
    }
    trace.log("world released")
    return FuzzResult(events: trace.events, overflowed: trace.overflowed)
}
