import XCTest
import Foundation
#if SSK_LEGACY
@testable import SwiftSignalKitLegacy
#else
@testable import SwiftSignalKit2
#endif

final class CorePromiseTests: XCTestCase {
    private func record<T>(_ signal: Signal<T, NoError>, label: String, into log: CoreEventLog) -> Disposable {
        return signal.start(next: { value in
            log.append("\(label) \(value)")
        }, completed: {
            log.append("\(label) completed")
        })
    }

    func testPromiseWithInitialValueEmitsItSynchronouslyOnSubscribe() {
        let log = CoreEventLog()
        let promise = Promise<Int>(1)
        let handle = self.record(promise.get(), label: "a", into: log)
        XCTAssertEqual(log.events, ["a 1"])
        handle.dispose()
    }

    func testPromiseWithoutValueEmitsNothingUntilSet() {
        let log = CoreEventLog()
        let promise = Promise<Int>()
        let handle = self.record(promise.get(), label: "a", into: log)
        XCTAssertEqual(log.events, [])
        promise.set(.single(2))
        XCTAssertEqual(log.events, ["a 2"])
        handle.dispose()
    }

    func testPromiseGetEmitsCurrentThenUpdatesAndNeverCompletes() {
        let log = CoreEventLog()
        let promise = Promise<Int>(1)
        let handle = self.record(promise.get(), label: "a", into: log)
        promise.set(.single(2))
        promise.set(Signal { subscriber in
            subscriber.putNext(3)
            subscriber.putNext(4)
            subscriber.putCompletion()
            return EmptyDisposable
        })
        XCTAssertEqual(log.events, ["a 1", "a 2", "a 3", "a 4"])
        let late = self.record(promise.get(), label: "b", into: log)
        XCTAssertEqual(log.events, ["a 1", "a 2", "a 3", "a 4", "b 4"])
        handle.dispose()
        late.dispose()
    }

    func testPromiseSetResetsValueBeforeNewSignalEmits() {
        let log = CoreEventLog()
        let promise = Promise<Int>(1)
        let first = self.record(promise.get(), label: "a", into: log)
        promise.set(.never())
        let second = self.record(promise.get(), label: "b", into: log)
        XCTAssertEqual(log.events, ["a 1"])
        promise.set(.complete())
        let third = self.record(promise.get(), label: "c", into: log)
        XCTAssertEqual(log.events, ["a 1"])
        first.dispose()
        second.dispose()
        third.dispose()
    }

    func testPromiseValueSurvivesSourceCompletion() {
        let log = CoreEventLog()
        let promise = Promise<Int>()
        promise.set(.single(4))
        let handle = self.record(promise.get(), label: "a", into: log)
        XCTAssertEqual(log.events, ["a 4"])
        handle.dispose()
    }

    func testPromiseSetDisposesPreviousSignalSubscription() {
        let log = CoreEventLog()
        let promise = Promise<Int>()
        promise.set(Signal { _ in
            return ActionDisposable {
                log.append("first disposed")
            }
        })
        XCTAssertEqual(log.events, [])
        promise.set(Signal { subscriber in
            log.append("second started")
            return ActionDisposable {
                log.append("second disposed")
            }
        })
        XCTAssertEqual(log.events, ["second started", "first disposed"])
        withExtendedLifetime(promise) {}
    }

    func testPromiseDeliversToSubscribersInSubscriptionOrder() {
        let log = CoreEventLog()
        let promise = Promise<Int>()
        let a = self.record(promise.get(), label: "a", into: log)
        let b = self.record(promise.get(), label: "b", into: log)
        let c = self.record(promise.get(), label: "c", into: log)
        promise.set(.single(1))
        XCTAssertEqual(log.events, ["a 1", "b 1", "c 1"])
        b.dispose()
        promise.set(.single(2))
        XCTAssertEqual(log.events, ["a 1", "b 1", "c 1", "a 2", "c 2"])
        let d = self.record(promise.get(), label: "d", into: log)
        promise.set(.single(3))
        XCTAssertEqual(log.events, ["a 1", "b 1", "c 1", "a 2", "c 2", "d 2", "a 3", "c 3", "d 3"])
        a.dispose()
        c.dispose()
        d.dispose()
    }

    func testPromiseSubscriberDisposedByEarlierSubscriberDuringEmissionIsSkipped() {
        let log = CoreEventLog()
        let promise = Promise<Int>()
        var second: Disposable?
        let first = promise.get().start(next: { value in
            log.append("a \(value)")
            second?.dispose()
        })
        second = self.record(promise.get(), label: "b", into: log)
        promise.set(.single(1))
        XCTAssertEqual(log.events, ["a 1"])
        first.dispose()
    }

    func testPromiseSubscriberAddedDuringEmissionGetsCurrentValueOnly() {
        let log = CoreEventLog()
        let promise = Promise<Int>()
        var added: Disposable?
        let first = promise.get().start(next: { value in
            log.append("a \(value)")
            if added == nil {
                added = self.record(promise.get(), label: "b", into: log)
            }
        })
        promise.set(.single(1))
        XCTAssertEqual(log.events, ["a 1", "b 1"])
        promise.set(.single(2))
        XCTAssertEqual(log.events, ["a 1", "b 1", "a 2", "b 2"])
        first.dispose()
        added?.dispose()
    }

    func testPromiseInitializeOnFirstAccessStartsLazilyOnce() {
        let starts = CoreCounter()
        let log = CoreEventLog()
        let promise = Promise<Int>(initializeOnFirstAccess: Signal { subscriber in
            starts.increment()
            subscriber.putNext(10)
            return EmptyDisposable
        })
        let signal = promise.get()
        XCTAssertEqual(starts.value, 0)
        let a = self.record(signal, label: "a", into: log)
        XCTAssertEqual(starts.value, 1)
        XCTAssertEqual(log.events, ["a 10"])
        let b = self.record(promise.get(), label: "b", into: log)
        XCTAssertEqual(starts.value, 1)
        XCTAssertEqual(log.events, ["a 10", "b 10"])
        a.dispose()
        b.dispose()
        let c = self.record(promise.get(), label: "c", into: log)
        XCTAssertEqual(starts.value, 1)
        XCTAssertEqual(log.events, ["a 10", "b 10", "c 10"])
        c.dispose()
    }

    func testPromiseInitializeOnFirstAccessNilBehavesLikeEmptyPromise() {
        let log = CoreEventLog()
        let promise = Promise<Int>(initializeOnFirstAccess: nil)
        let handle = self.record(promise.get(), label: "a", into: log)
        XCTAssertEqual(log.events, [])
        promise.set(.single(1))
        XCTAssertEqual(log.events, ["a 1"])
        handle.dispose()
    }

    func testPromiseExplicitSetBeforeFirstAccessIsReplacedByInitializer() {
        let log = CoreEventLog()
        let promise = Promise<Int>(initializeOnFirstAccess: .single(10))
        promise.set(.single(5))
        let handle = self.record(promise.get(), label: "a", into: log)
        XCTAssertEqual(log.events, ["a 5", "a 10"])
        handle.dispose()
    }

    func testPromiseOnDeinitThenDisposesCurrentSignal() {
        let log = CoreEventLog()
        weak var weakPromise: Promise<Int>?
        do {
            let promise = Promise<Int>()
            weakPromise = promise
            promise.onDeinit = {
                log.append("onDeinit")
            }
            promise.set(Signal { _ in
                return ActionDisposable {
                    log.append("signal disposed")
                }
            })
        }
        XCTAssertNil(weakPromise)
        XCTAssertEqual(log.events, ["onDeinit", "signal disposed"])
    }

    func testPromiseIsNotRetainedByItsOwnSetSignal() {
        weak var weakPromise: Promise<Int>?
        let holder = CoreSubscriberHolder<Int, NoError>()
        do {
            let promise = Promise<Int>()
            weakPromise = promise
            promise.set(Signal { subscriber in
                holder.subscriber = subscriber
                return EmptyDisposable
            })
        }
        XCTAssertNil(weakPromise)
        holder.subscriber?.putNext(1)
    }

    func testPromiseGetSignalKeepsPromiseAlive() {
        weak var weakPromise: Promise<Int>?
        var signal: Signal<Int, NoError>?
        do {
            let promise = Promise<Int>(3)
            weakPromise = promise
            signal = promise.get()
        }
        XCTAssertNotNil(weakPromise)
        XCTAssertNotNil(signal)
        signal = nil
        XCTAssertNil(weakPromise)
    }

    func testPromiseSubscriptionKeepsPromiseAliveUntilHandleDispose() {
        let log = CoreEventLog()
        weak var weakPromise: Promise<Int>?
        let handle: Disposable
        do {
            let promise = Promise<Int>(1)
            weakPromise = promise
            handle = self.record(promise.get(), label: "a", into: log)
        }
        XCTAssertNotNil(weakPromise)
        weakPromise?.set(.single(2))
        XCTAssertEqual(log.events, ["a 1", "a 2"])
        handle.dispose()
        XCTAssertNil(weakPromise)
    }

    func testPromiseKeepsSubscriberAliveWhenHandleIsDropped() {
        let log = CoreEventLog()
        let promise = Promise<Int>()
        do {
            let _ = self.record(promise.get(), label: "a", into: log)
        }
        promise.set(.single(1))
        promise.set(.single(2))
        XCTAssertEqual(log.events, ["a 1", "a 2"])
    }

    func testPromiseHandleDisposeReleasesSubscriberCallbacks() {
        weak var weakOwner: CoreObject?
        let promise = Promise<Int>(1)
        let handle: Disposable
        do {
            let owner = CoreObject()
            weakOwner = owner
            handle = promise.get().start(next: { _ in
                withExtendedLifetime(owner) {}
            })
        }
        XCTAssertNotNil(weakOwner)
        handle.dispose()
        XCTAssertNil(weakOwner)
    }

    func testPromiseSetReleasesPreviousValueBeforeStartingNewSignal() {
        let log = CoreEventLog()
        let promise = Promise<CoreDeinitProbe>(CoreDeinitProbe {
            log.append("first released")
        })
        promise.set(Signal { _ in
            log.append("new signal started")
            return EmptyDisposable
        })
        XCTAssertEqual(log.events, ["first released", "new signal started"])
    }

    func testPromiseReleasesPreviousValueBeforeNotifyingSubscribersOfReplacement() {
        let log = CoreEventLog()
        let promise = Promise<CoreDeinitProbe>()
        let handle = promise.get().start(next: { _ in
            log.append("next")
        })
        promise.set(Signal { subscriber in
            subscriber.putNext(CoreDeinitProbe {
                log.append("a released")
            })
            subscriber.putNext(CoreDeinitProbe {
                log.append("b released")
            })
            return EmptyDisposable
        })
        XCTAssertEqual(log.events, ["next", "a released", "next"])
        handle.dispose()
    }

    func testValuePromiseReleasesPreviousValueBeforeNotifyingSubscribers() {
        let log = CoreEventLog()
        let promise = ValuePromise<CoreEquatableProbe>(CoreEquatableProbe(1) {
            log.append("1 released")
        })
        let handle = promise.get().start(next: { value in
            log.append("next \(value.id)")
        })
        promise.set(CoreEquatableProbe(2) {
            log.append("2 released")
        })
        XCTAssertEqual(log.events, ["next 1", "1 released", "next 2"])
        handle.dispose()
    }

    func testValuePromiseIgnoredRepeatedValueIsReleasedAndCurrentKept() {
        let log = CoreEventLog()
        let promise = ValuePromise<CoreEquatableProbe>(CoreEquatableProbe(1) {
            log.append("original released")
        }, ignoreRepeated: true)
        promise.set(CoreEquatableProbe(1) {
            log.append("duplicate released")
        })
        XCTAssertEqual(log.events, ["duplicate released"])
        let handle = promise.get().start(next: { value in
            log.append("next \(value.id)")
        })
        XCTAssertEqual(log.events, ["duplicate released", "next 1"])
        handle.dispose()
    }

    func testPromiseReentrantSetDuringSynchronousEmissionIsOverriddenByOuterSignal() {
        let log = CoreEventLog()
        let promise = Promise<Int>()
        let handle = promise.get().start(next: { value in
            log.append("next \(value)")
            if value == 1 {
                promise.set(.single(10))
            }
        })
        promise.set(Signal { subscriber in
            subscriber.putNext(1)
            subscriber.putNext(2)
            return EmptyDisposable
        })
        XCTAssertEqual(log.events, ["next 1", "next 10", "next 2"])
        let late = self.record(promise.get(), label: "late", into: log)
        XCTAssertEqual(log.events, ["next 1", "next 10", "next 2", "late 2"])
        handle.dispose()
        late.dispose()
    }

    func testValuePromiseReentrantSetFromSubscriberNotifiesNestedBeforeOuterContinues() {
        let log = CoreEventLog()
        let promise = ValuePromise<Int>()
        let a = promise.get().start(next: { value in
            log.append("a \(value)")
            if value == 1 {
                promise.set(2)
            }
        })
        let b = self.record(promise.get(), label: "b", into: log)
        promise.set(1)
        XCTAssertEqual(log.events, ["a 1", "a 2", "b 2", "b 1"])
        let late = self.record(promise.get(), label: "late", into: log)
        XCTAssertEqual(log.events.last, "late 2")
        a.dispose()
        b.dispose()
        late.dispose()
    }

    func testValuePipeReentrantPutNextFromSubscriberNotifiesNestedBeforeOuterContinues() {
        let log = CoreEventLog()
        let pipe = ValuePipe<Int>()
        let a = pipe.signal().start(next: { value in
            log.append("a \(value)")
            if value == 1 {
                pipe.putNext(2)
            }
        })
        let b = self.record(pipe.signal(), label: "b", into: log)
        pipe.putNext(1)
        XCTAssertEqual(log.events, ["a 1", "a 2", "b 2", "b 1"])
        a.dispose()
        b.dispose()
    }

    func testValuePromiseWithInitialValueEmitsItOnSubscribe() {
        let log = CoreEventLog()
        let promise = ValuePromise<Int>(5)
        XCTAssertFalse(promise.ignoreRepeated)
        let handle = self.record(promise.get(), label: "a", into: log)
        XCTAssertEqual(log.events, ["a 5"])
        handle.dispose()
    }

    func testValuePromiseWithoutValueEmitsNothingUntilSet() {
        let log = CoreEventLog()
        let promise = ValuePromise<Int>()
        let handle = self.record(promise.get(), label: "a", into: log)
        XCTAssertEqual(log.events, [])
        promise.set(1)
        XCTAssertEqual(log.events, ["a 1"])
        handle.dispose()
    }

    func testValuePromiseWithoutIgnoreRepeatedEmitsEverySet() {
        let log = CoreEventLog()
        let promise = ValuePromise<Int>(1, ignoreRepeated: false)
        let handle = self.record(promise.get(), label: "a", into: log)
        promise.set(1)
        promise.set(1)
        promise.set(2)
        promise.set(2)
        XCTAssertEqual(log.events, ["a 1", "a 1", "a 1", "a 2", "a 2"])
        handle.dispose()
    }

    func testValuePromiseIgnoreRepeatedSkipsEqualValues() {
        let log = CoreEventLog()
        let promise = ValuePromise<Int>(1, ignoreRepeated: true)
        XCTAssertTrue(promise.ignoreRepeated)
        let handle = self.record(promise.get(), label: "a", into: log)
        promise.set(1)
        promise.set(2)
        promise.set(2)
        promise.set(1)
        promise.set(1)
        XCTAssertEqual(log.events, ["a 1", "a 2", "a 1"])
        handle.dispose()
    }

    func testValuePromiseIgnoreRepeatedWithoutInitialValueEmitsFirstSet() {
        let log = CoreEventLog()
        let promise = ValuePromise<Int>(ignoreRepeated: true)
        let handle = self.record(promise.get(), label: "a", into: log)
        promise.set(0)
        promise.set(0)
        XCTAssertEqual(log.events, ["a 0"])
        handle.dispose()
    }

    func testValuePromiseEmitsToSubscribersInSubscriptionOrderAndLatestToNewSubscribers() {
        let log = CoreEventLog()
        let promise = ValuePromise<String>("x")
        let a = self.record(promise.get(), label: "a", into: log)
        let b = self.record(promise.get(), label: "b", into: log)
        promise.set("y")
        let c = self.record(promise.get(), label: "c", into: log)
        a.dispose()
        promise.set("z")
        XCTAssertEqual(log.events, ["a x", "b x", "a y", "b y", "c y", "b z", "c z"])
        b.dispose()
        c.dispose()
    }

    func testValuePromiseSetWithoutSubscribersUpdatesValue() {
        let log = CoreEventLog()
        let promise = ValuePromise<Int>()
        promise.set(1)
        promise.set(2)
        let handle = self.record(promise.get(), label: "a", into: log)
        XCTAssertEqual(log.events, ["a 2"])
        handle.dispose()
    }

    func testValuePromiseSubscriptionKeepsPromiseAliveUntilDispose() {
        weak var weakPromise: ValuePromise<Int>?
        let handle: Disposable
        do {
            let promise = ValuePromise<Int>(1)
            weakPromise = promise
            handle = promise.get().start()
        }
        XCTAssertNotNil(weakPromise)
        handle.dispose()
        XCTAssertNil(weakPromise)
    }

    func testValuePipeDoesNotReplay() {
        let log = CoreEventLog()
        let pipe = ValuePipe<Int>()
        pipe.putNext(0)
        let handle = self.record(pipe.signal(), label: "a", into: log)
        XCTAssertEqual(log.events, [])
        pipe.putNext(1)
        pipe.putNext(2)
        XCTAssertEqual(log.events, ["a 1", "a 2"])
        handle.dispose()
        pipe.putNext(3)
        XCTAssertEqual(log.events, ["a 1", "a 2"])
    }

    func testValuePipeDeliversToSubscribersInSubscriptionOrder() {
        let log = CoreEventLog()
        let pipe = ValuePipe<String>()
        let a = self.record(pipe.signal(), label: "a", into: log)
        let b = self.record(pipe.signal(), label: "b", into: log)
        pipe.putNext("x")
        a.dispose()
        let c = self.record(pipe.signal(), label: "c", into: log)
        pipe.putNext("y")
        XCTAssertEqual(log.events, ["a x", "b x", "b y", "c y"])
        b.dispose()
        c.dispose()
    }

    func testValuePipeSubscriberDisposedDuringDeliveryIsSkipped() {
        let log = CoreEventLog()
        let pipe = ValuePipe<Int>()
        var second: Disposable?
        let first = pipe.signal().start(next: { value in
            log.append("a \(value)")
            second?.dispose()
        })
        second = self.record(pipe.signal(), label: "b", into: log)
        pipe.putNext(1)
        pipe.putNext(2)
        XCTAssertEqual(log.events, ["a 1", "a 2"])
        first.dispose()
    }

    func testValuePipeSignalDoesNotRetainPipe() {
        weak var weakPipe: ValuePipe<Int>?
        var signal: Signal<Int, NoError>?
        do {
            let pipe = ValuePipe<Int>()
            weakPipe = pipe
            signal = pipe.signal()
        }
        XCTAssertNil(weakPipe)
        XCTAssertNotNil(signal)
    }

    func testValuePipeSubscriptionDoesNotRetainPipe() {
        weak var weakPipe: ValuePipe<Int>?
        let handle: Disposable
        do {
            let pipe = ValuePipe<Int>()
            weakPipe = pipe
            handle = pipe.signal().start(next: { _ in
            })
        }
        XCTAssertNil(weakPipe)
        handle.dispose()
    }

    func testValuePipeSubscriptionDiesWithPipe() {
        weak var weakOwner: CoreObject?
        var pipe: ValuePipe<Int>? = ValuePipe<Int>()
        let handle: Disposable
        do {
            let owner = CoreObject()
            weakOwner = owner
            handle = pipe!.signal().start(next: { _ in
                withExtendedLifetime(owner) {}
            })
        }
        XCTAssertNotNil(weakOwner)
        pipe = nil
        XCTAssertNil(weakOwner)
        handle.dispose()
    }

    func testValuePipeSignalStartedAfterPipeDiedEmitsNothing() {
        let log = CoreEventLog()
        var signal: Signal<Int, NoError>?
        do {
            let pipe = ValuePipe<Int>()
            signal = pipe.signal()
        }
        let handle = signal.map { self.record($0, label: "a", into: log) }
        XCTAssertEqual(log.events, [])
        handle?.dispose()
    }

    func testValuePipePutNextWithoutSubscribers() {
        let pipe = ValuePipe<Int>()
        pipe.putNext(1)
        let log = CoreEventLog()
        let handle = self.record(pipe.signal(), label: "a", into: log)
        handle.dispose()
        pipe.putNext(2)
        XCTAssertEqual(log.events, [])
    }

    func testValuePipeConcurrentPutNextDeliversAll() {
        let counter = CoreCounter()
        let pipe = ValuePipe<Int>()
        let handle = pipe.signal().start(next: { _ in
            counter.increment()
        })
        DispatchQueue.concurrentPerform(iterations: 1000) { index in
            pipe.putNext(index)
        }
        XCTAssertEqual(counter.value, 1000)
        handle.dispose()
    }

    func testMulticastStartsUpstreamForEverySubscriberEvenWithSameKey() {
        let multicast = Multicast<Int>()
        let starts = CoreCounter()
        let upstream = Signal<Int, NoError> { subscriber in
            let count = starts.increment()
            subscriber.putNext(count * 100)
            return EmptyDisposable
        }
        let log = CoreEventLog()
        let a = self.record(multicast.get(key: "k", signal: upstream), label: "a", into: log)
        let b = self.record(multicast.get(key: "k", signal: upstream), label: "b", into: log)
        XCTAssertEqual(starts.value, 2)
        XCTAssertEqual(log.events, ["a 100", "b 200"])
        a.dispose()
        b.dispose()
    }

    func testMulticastDoesNotForwardCompletion() {
        let multicast = Multicast<Int>()
        let log = CoreEventLog()
        let a = self.record(multicast.get(key: "c", signal: .single(1)), label: "a", into: log)
        let twoValues = Signal<Int, NoError> { subscriber in
            subscriber.putNext(2)
            subscriber.putNext(3)
            subscriber.putCompletion()
            return EmptyDisposable
        }
        let b = self.record(multicast.get(key: "c", signal: twoValues), label: "b", into: log)
        XCTAssertEqual(log.events, ["a 1", "b 2", "b 3"])
        a.dispose()
        b.dispose()
        XCTAssertEqual(log.events, ["a 1", "b 2", "b 3"])
    }

    func testMulticastUpstreamValuesReachOnlyItsOwnSubscriber() {
        let multicast = Multicast<Int>()
        let first = CoreSubscriberHolder<Int, NoError>()
        let second = CoreSubscriberHolder<Int, NoError>()
        let log = CoreEventLog()
        let a = self.record(multicast.get(key: "k", signal: Signal { subscriber in
            first.subscriber = subscriber
            return EmptyDisposable
        }), label: "a", into: log)
        let b = self.record(multicast.get(key: "k", signal: Signal { subscriber in
            second.subscriber = subscriber
            return EmptyDisposable
        }), label: "b", into: log)
        first.subscriber?.putNext(1)
        second.subscriber?.putNext(2)
        XCTAssertEqual(log.events, ["a 1", "b 2"])
        a.dispose()
        first.subscriber?.putNext(3)
        second.subscriber?.putNext(4)
        XCTAssertEqual(log.events, ["a 1", "b 2", "b 4"])
        b.dispose()
    }

    func testMulticastUpstreamDisposalOnLastSubscriberLeavingDiffersBetweenImplementations() {
        let multicast = Multicast<Int>()
        let upstreamDisposable = CoreCountingDisposable()
        let handle = multicast.get(key: "k", signal: Signal { _ in
            return upstreamDisposable
        }).start(next: { _ in
        })
        XCTAssertEqual(upstreamDisposable.disposeCount, 0)
        handle.dispose()
        #if SSK_LEGACY
        XCTAssertEqual(upstreamDisposable.disposeCount, 0)
        #else
        XCTAssertEqual(upstreamDisposable.disposeCount, 1)
        #endif
    }
}
