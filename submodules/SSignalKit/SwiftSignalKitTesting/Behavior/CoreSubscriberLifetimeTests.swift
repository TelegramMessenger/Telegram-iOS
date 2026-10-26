import XCTest
import Foundation
#if SSK_LEGACY
@testable import SwiftSignalKitLegacy
#else
@testable import SwiftSignalKit2
#endif

final class CoreSubscriberLifetimeTests: XCTestCase {
    private final class Owners {
        weak var next: CoreObject?
        weak var error: CoreObject?
        weak var completed: CoreObject?

        var allReleased: Bool {
            return self.next == nil && self.error == nil && self.completed == nil
        }

        var allAlive: Bool {
            return self.next != nil && self.error != nil && self.completed != nil
        }
    }

    private func startCapturingOwners(_ signal: Signal<Int, String>, owners: Owners) -> Disposable {
        let nextOwner = CoreObject(1)
        let errorOwner = CoreObject(2)
        let completedOwner = CoreObject(3)
        owners.next = nextOwner
        owners.error = errorOwner
        owners.completed = completedOwner
        return signal.start(next: { _ in
            withExtendedLifetime(nextOwner) {}
        }, error: { _ in
            withExtendedLifetime(errorOwner) {}
        }, completed: {
            withExtendedLifetime(completedOwner) {}
        })
    }

    private func holdingSignal(_ holder: CoreSubscriberHolder<Int, String>, disposable: Disposable = EmptyDisposable) -> Signal<Int, String> {
        return Signal { subscriber in
            holder.subscriber = subscriber
            return disposable
        }
    }

    func testCallbacksReleasedAfterCompletionWhileSubscriberStillReferenced() {
        let holder = CoreSubscriberHolder<Int, String>()
        let owners = Owners()
        let handle = self.startCapturingOwners(self.holdingSignal(holder), owners: owners)
        XCTAssertTrue(owners.allAlive)
        holder.subscriber?.putCompletion()
        XCTAssertTrue(owners.allReleased)
        XCTAssertNotNil(holder.subscriber)
        handle.dispose()
    }

    func testCallbacksReleasedAfterErrorWhileSubscriberStillReferenced() {
        let holder = CoreSubscriberHolder<Int, String>()
        let owners = Owners()
        let handle = self.startCapturingOwners(self.holdingSignal(holder), owners: owners)
        XCTAssertTrue(owners.allAlive)
        holder.subscriber?.putError("e")
        XCTAssertTrue(owners.allReleased)
        XCTAssertNotNil(holder.subscriber)
        handle.dispose()
    }

    func testCallbacksReleasedAfterHandleDisposeWhileSourceStillHoldsSubscriber() {
        let holder = CoreSubscriberHolder<Int, String>()
        let owners = Owners()
        let handle = self.startCapturingOwners(self.holdingSignal(holder), owners: owners)
        XCTAssertTrue(owners.allAlive)
        handle.dispose()
        XCTAssertTrue(owners.allReleased)
        XCTAssertNotNil(holder.subscriber)
    }

    func testCallbacksReleasedRightAfterStartForNeverSignal() {
        let owners = Owners()
        let handle = self.startCapturingOwners(Signal<Int, String>.never(), owners: owners)
        XCTAssertTrue(owners.allReleased)
        handle.dispose()
    }

    func testCallbacksReleasedRightAfterStartWhenGeneratorDoesNotRetainSubscriber() {
        let owners = Owners()
        let inner = CoreCountingDisposable()
        let handle = self.startCapturingOwners(Signal<Int, String> { _ in
            return inner
        }, owners: owners)
        XCTAssertTrue(owners.allReleased)
        XCTAssertEqual(inner.disposeCount, 0)
        handle.dispose()
        XCTAssertEqual(inner.disposeCount, 1)
    }

    func testCallbacksReleasedWhenSourceDropsSubscriberWithoutTerminating() {
        let holder = CoreSubscriberHolder<Int, String>()
        let owners = Owners()
        let inner = CoreCountingDisposable()
        let handle = self.startCapturingOwners(self.holdingSignal(holder, disposable: inner), owners: owners)
        XCTAssertTrue(owners.allAlive)
        holder.subscriber = nil
        XCTAssertTrue(owners.allReleased)
        XCTAssertEqual(inner.disposeCount, 0)
        handle.dispose()
        XCTAssertEqual(inner.disposeCount, 1)
    }

    func testCallbacksReleasedAfterSynchronousCompletion() {
        let owners = Owners()
        let handle = self.startCapturingOwners(Signal<Int, String>.single(1), owners: owners)
        XCTAssertTrue(owners.allReleased)
        handle.dispose()
    }

    func testCallbackCapturingHandleDoesNotKeepOwnerAliveForNeverSignal() {
        weak var weakOwner: CoreObject?
        var handle: Disposable?
        do {
            let owner = CoreObject()
            weakOwner = owner
            handle = Signal<Int, String>.never().start(next: { _ in
                withExtendedLifetime(owner) {}
                handle?.dispose()
            })
        }
        XCTAssertNil(weakOwner)
        XCTAssertNotNil(handle)
        handle?.dispose()
    }

    func testDirectlyConstructedSubscriberReleasesCallbacksOnCompletion() {
        weak var weakOwner: CoreObject?
        let subscriber: Subscriber<Int, String>
        do {
            let owner = CoreObject()
            weakOwner = owner
            subscriber = Subscriber(next: { _ in
                withExtendedLifetime(owner) {}
            })
        }
        XCTAssertNotNil(weakOwner)
        subscriber.putNext(1)
        XCTAssertNotNil(weakOwner)
        subscriber.putCompletion()
        XCTAssertNil(weakOwner)
    }

    func testDirectlyConstructedSubscriberReleasesCallbacksOnError() {
        weak var weakOwner: CoreObject?
        let subscriber: Subscriber<Int, String>
        do {
            let owner = CoreObject()
            weakOwner = owner
            subscriber = Subscriber(completed: {
                withExtendedLifetime(owner) {}
            })
        }
        XCTAssertNotNil(weakOwner)
        subscriber.putError("e")
        XCTAssertNil(weakOwner)
    }

    func testDirectlyConstructedSubscriberReleasesCallbacksOnDeinit() {
        weak var weakOwner: CoreObject?
        var subscriber: Subscriber<Int, String>?
        do {
            let owner = CoreObject()
            weakOwner = owner
            subscriber = Subscriber(next: { _ in
                withExtendedLifetime(owner) {}
            })
        }
        XCTAssertNotNil(weakOwner)
        XCTAssertNotNil(subscriber)
        subscriber = nil
        XCTAssertNil(weakOwner)
    }

    func testKeepAliveRetainedUntilCompletionThenReleasedAfterInnerDispose() {
        let log = CoreEventLog()
        let holder = CoreSubscriberHolder<Int, String>()
        let inner = CoreCountingDisposable(log: log)
        let handle = Signal<Int, String> { subscriber in
            holder.subscriber = subscriber
            subscriber.keepAlive(CoreDeinitProbe {
                log.append("keepAlive released")
            })
            return inner
        }.start(completed: {
            log.append("completed")
        })
        XCTAssertEqual(log.events, [])
        holder.subscriber?.putNext(1)
        XCTAssertEqual(log.events, [])
        holder.subscriber?.putCompletion()
        XCTAssertEqual(log.events, ["completed", "dispose", "keepAlive released"])
        handle.dispose()
        XCTAssertEqual(log.events, ["completed", "dispose", "keepAlive released"])
    }

    func testKeepAliveRetainedUntilErrorThenReleasedAfterInnerDispose() {
        let log = CoreEventLog()
        let holder = CoreSubscriberHolder<Int, String>()
        let inner = CoreCountingDisposable(log: log)
        let handle = Signal<Int, String> { subscriber in
            holder.subscriber = subscriber
            subscriber.keepAlive(CoreDeinitProbe {
                log.append("keepAlive released")
            })
            return inner
        }.start(error: { error in
            log.append("error \(error)")
        })
        XCTAssertEqual(log.events, [])
        holder.subscriber?.putError("e")
        XCTAssertEqual(log.events, ["error e", "dispose", "keepAlive released"])
        handle.dispose()
    }

    func testKeepAliveRetainedUntilHandleDisposeThenReleasedAfterInnerDispose() {
        let log = CoreEventLog()
        let holder = CoreSubscriberHolder<Int, String>()
        let inner = CoreCountingDisposable(log: log)
        let handle = Signal<Int, String> { subscriber in
            holder.subscriber = subscriber
            subscriber.keepAlive(CoreDeinitProbe {
                log.append("keepAlive released")
            })
            return inner
        }.start()
        XCTAssertEqual(log.events, [])
        handle.dispose()
        XCTAssertEqual(log.events, ["dispose", "keepAlive released"])
        XCTAssertNotNil(holder.subscriber)
    }

    func testKeepAliveReleasedWhenSourceDropsSubscriberWithoutTerminating() {
        let log = CoreEventLog()
        let holder = CoreSubscriberHolder<Int, String>()
        let handle = Signal<Int, String> { subscriber in
            holder.subscriber = subscriber
            subscriber.keepAlive(CoreDeinitProbe {
                log.append("keepAlive released")
            })
            return CoreCountingDisposable("dispose", log: log)
        }.start()
        XCTAssertEqual(log.events, [])
        holder.subscriber = nil
        XCTAssertEqual(log.events, ["keepAlive released"])
        handle.dispose()
        XCTAssertEqual(log.events, ["keepAlive released", "dispose"])
    }

    func testKeepAliveReleasedRightAfterStartWhenSubscriberNotRetained() {
        let log = CoreEventLog()
        let handle = Signal<Int, String> { subscriber in
            subscriber.keepAlive(CoreDeinitProbe {
                log.append("keepAlive released")
            })
            log.append("generator end")
            return EmptyDisposable
        }.start()
        log.append("start returned")
        XCTAssertEqual(log.events, ["generator end", "keepAlive released", "start returned"])
        handle.dispose()
    }

    func testKeepAliveReleasedDuringSynchronousCompletionInsideGenerator() {
        let log = CoreEventLog()
        let inner = CoreCountingDisposable(log: log)
        let handle = Signal<Int, String> { subscriber in
            subscriber.keepAlive(CoreDeinitProbe {
                log.append("keepAlive released")
            })
            subscriber.putCompletion()
            log.append("generator end")
            return inner
        }.start(completed: {
            log.append("completed")
        })
        XCTAssertEqual(log.events, ["completed", "keepAlive released", "generator end", "dispose"])
        handle.dispose()
    }

    func testKeepAliveRegisteredInsideInnerDisposeDuringHandleDisposeIsReleasedByIt() {
        let log = CoreEventLog()
        let holder = CoreSubscriberHolder<Int, String>()
        let inner = CoreCountingDisposable(log: log)
        inner.onDispose = {
            holder.subscriber?.keepAlive(CoreDeinitProbe {
                log.append("keepAlive released")
            })
        }
        let handle = Signal<Int, String> { subscriber in
            holder.subscriber = subscriber
            return inner
        }.start()
        handle.dispose()
        XCTAssertEqual(log.events, ["dispose", "keepAlive released"])
        XCTAssertNotNil(holder.subscriber)
        inner.onDispose = nil
    }

    func testKeepAliveRegisteredInsideCompletedCallbackIsHeldUntilHandleDispose() {
        let log = CoreEventLog()
        let holder = CoreSubscriberHolder<Int, String>()
        let inner = CoreCountingDisposable(log: log)
        let handle = Signal<Int, String> { subscriber in
            holder.subscriber = subscriber
            return inner
        }.start(completed: {
            log.append("completed")
            holder.subscriber?.keepAlive(CoreDeinitProbe {
                log.append("keepAlive released")
            })
        })
        holder.subscriber?.putCompletion()
        XCTAssertEqual(log.events, ["completed", "dispose"])
        handle.dispose()
        XCTAssertEqual(log.events, ["completed", "dispose", "keepAlive released"])
    }

    func testMultipleKeepAliveObjectsAllReleasedOnTermination() {
        let holder = CoreSubscriberHolder<Int, String>()
        weak var first: CoreObject?
        weak var second: CoreObject?
        let handle = Signal<Int, String> { subscriber in
            holder.subscriber = subscriber
            let a = CoreObject(1)
            let b = CoreObject(2)
            first = a
            second = b
            subscriber.keepAlive(a)
            subscriber.keepAlive(b)
            return EmptyDisposable
        }.start()
        XCTAssertNotNil(first)
        XCTAssertNotNil(second)
        holder.subscriber?.putCompletion()
        XCTAssertNil(first)
        XCTAssertNil(second)
        handle.dispose()
    }

    func testKeepAliveAfterTerminationIsHeldUntilSubscriberDeallocates() {
        let log = CoreEventLog()
        let holder = CoreSubscriberHolder<Int, String>()
        let handle = Signal<Int, String> { subscriber in
            holder.subscriber = subscriber
            return EmptyDisposable
        }.start()
        holder.subscriber?.putCompletion()
        holder.subscriber?.keepAlive(CoreDeinitProbe {
            log.append("late keepAlive released")
        })
        XCTAssertEqual(log.events, [])
        holder.subscriber?.putNext(1)
        XCTAssertEqual(log.events, [])
        holder.subscriber = nil
        XCTAssertEqual(log.events, ["late keepAlive released"])
        handle.dispose()
    }

    func testKeepAliveAfterTerminationIsReleasedByLaterTerminalCall() {
        let log = CoreEventLog()
        let holder = CoreSubscriberHolder<Int, String>()
        let handle = Signal<Int, String> { subscriber in
            holder.subscriber = subscriber
            return EmptyDisposable
        }.start()
        holder.subscriber?.putCompletion()
        holder.subscriber?.keepAlive(CoreDeinitProbe {
            log.append("late keepAlive released")
        })
        XCTAssertEqual(log.events, [])
        holder.subscriber?.putError("e")
        XCTAssertEqual(log.events, ["late keepAlive released"])
        XCTAssertNotNil(holder.subscriber)
        handle.dispose()
    }

    func testDirectlyConstructedSubscriberKeepAliveReleasedOnCompletion() {
        weak var weakObject: CoreObject?
        let subscriber = Subscriber<Int, String>()
        do {
            let object = CoreObject()
            weakObject = object
            subscriber.keepAlive(object)
        }
        XCTAssertNotNil(weakObject)
        subscriber.putNext(1)
        XCTAssertNotNil(weakObject)
        subscriber.putCompletion()
        XCTAssertNil(weakObject)
    }

    func testHandleDisposeReleasesCallbacksBeforeKeepAliveAfterInnerDispose() {
        let log = CoreEventLog()
        let holder = CoreSubscriberHolder<Int, String>()
        let inner = CoreCountingDisposable(log: log)
        let handle: Disposable
        do {
            let callbackProbe = CoreDeinitProbe {
                log.append("callbacks released")
            }
            handle = Signal<Int, String> { subscriber in
                holder.subscriber = subscriber
                subscriber.keepAlive(CoreDeinitProbe {
                    log.append("keepAlive released")
                })
                return inner
            }.start(next: { _ in
                withExtendedLifetime(callbackProbe) {}
            })
        }
        XCTAssertEqual(log.events, [])
        handle.dispose()
        XCTAssertEqual(log.events, ["dispose", "callbacks released", "keepAlive released"])
        XCTAssertNotNil(holder.subscriber)
    }

    func testSourceDroppingSubscriberInsideInnerDisposeDuringHandleDispose() {
        let log = CoreEventLog()
        let holder = CoreSubscriberHolder<Int, String>()
        let inner = CoreCountingDisposable(log: log)
        inner.onDispose = {
            holder.subscriber = nil
            log.append("source dropped subscriber")
        }
        weak var weakSubscriber: Subscriber<Int, String>?
        let handle: Disposable
        do {
            let callbackProbe = CoreDeinitProbe {
                log.append("callbacks released")
            }
            handle = Signal<Int, String> { subscriber in
                holder.subscriber = subscriber
                weakSubscriber = subscriber
                subscriber.keepAlive(CoreDeinitProbe {
                    log.append("keepAlive released")
                })
                return inner
            }.start(next: { _ in
                withExtendedLifetime(callbackProbe) {}
            })
        }
        XCTAssertNotNil(weakSubscriber)
        handle.dispose()
        XCTAssertNil(weakSubscriber)
        XCTAssertEqual(log.events, ["dispose", "source dropped subscriber", "callbacks released", "keepAlive released"])
        handle.dispose()
        XCTAssertEqual(inner.disposeCount, 1)
        inner.onDispose = nil
    }

    func testErrorReleasesNextAndCompletedCallbacksBeforeErrorCallbackRuns() {
        let holder = CoreSubscriberHolder<Int, String>()
        weak var weakNextOwner: CoreObject?
        weak var weakCompletedOwner: CoreObject?
        var nextOwnerAliveDuringError: Bool?
        var completedOwnerAliveDuringError: Bool?
        let handle: Disposable
        do {
            let nextOwner = CoreObject()
            let completedOwner = CoreObject()
            weakNextOwner = nextOwner
            weakCompletedOwner = completedOwner
            handle = Signal<Int, String> { subscriber in
                holder.subscriber = subscriber
                return EmptyDisposable
            }.start(next: { _ in
                withExtendedLifetime(nextOwner) {}
            }, error: { _ in
                nextOwnerAliveDuringError = weakNextOwner != nil
                completedOwnerAliveDuringError = weakCompletedOwner != nil
            }, completed: {
                withExtendedLifetime(completedOwner) {}
            })
        }
        XCTAssertNotNil(weakNextOwner)
        XCTAssertNotNil(weakCompletedOwner)
        holder.subscriber?.putError("e")
        XCTAssertEqual(nextOwnerAliveDuringError, false)
        XCTAssertEqual(completedOwnerAliveDuringError, false)
        handle.dispose()
    }

    func testHandleDisposeAfterCompletionReleasesLateKeepAlive() {
        let log = CoreEventLog()
        let holder = CoreSubscriberHolder<Int, String>()
        let handle = Signal<Int, String> { subscriber in
            holder.subscriber = subscriber
            return EmptyDisposable
        }.start()
        holder.subscriber?.putCompletion()
        holder.subscriber?.keepAlive(CoreDeinitProbe {
            log.append("late keepAlive released")
        })
        XCTAssertEqual(log.events, [])
        handle.dispose()
        XCTAssertEqual(log.events, ["late keepAlive released"])
        XCTAssertNotNil(holder.subscriber)
        holder.subscriber?.keepAlive(CoreDeinitProbe {
            log.append("second late keepAlive released")
        })
        handle.dispose()
        XCTAssertEqual(log.events, ["late keepAlive released"])
        holder.subscriber = nil
        XCTAssertEqual(log.events, ["late keepAlive released", "second late keepAlive released"])
    }

    func testInnerDisposableCapturingSubscriberKeepsItAliveUntilHandleDispose() {
        let log = CoreEventLog()
        weak var weakSubscriber: Subscriber<Int, String>?
        weak var weakOwner: CoreObject?
        let handle: Disposable
        do {
            let owner = CoreObject()
            weakOwner = owner
            handle = Signal<Int, String> { subscriber in
                weakSubscriber = subscriber
                return ActionDisposable {
                    log.append("action")
                    subscriber.putNext(7)
                }
            }.start(next: { value in
                withExtendedLifetime(owner) {}
                log.append("next \(value)")
            })
        }
        XCTAssertNotNil(weakSubscriber)
        XCTAssertNotNil(weakOwner)
        handle.dispose()
        XCTAssertEqual(log.events, ["action", "next 7"])
        XCTAssertNil(weakSubscriber)
        XCTAssertNil(weakOwner)
    }

    func testInnerDisposableCapturingSubscriberIsReleasedAfterCompletion() {
        let holder = CoreSubscriberHolder<Int, String>()
        weak var weakSubscriber: Subscriber<Int, String>?
        let handle = Signal<Int, String> { subscriber in
            holder.subscriber = subscriber
            weakSubscriber = subscriber
            return ActionDisposable {
                subscriber.putNext(0)
            }
        }.start()
        holder.subscriber?.putCompletion()
        holder.subscriber = nil
        XCTAssertNil(weakSubscriber)
        handle.dispose()
    }

    func testSubscriberDeallocationReleaseOrderWhenHandleWasDropped() {
        let log = CoreEventLog()
        let holder = CoreSubscriberHolder<Int, String>()
        do {
            let nextProbe = CoreDeinitProbe {
                log.append("next released")
            }
            let errorProbe = CoreDeinitProbe {
                log.append("error released")
            }
            let completedProbe = CoreDeinitProbe {
                log.append("completed released")
            }
            let _ = Signal<Int, String> { subscriber in
                holder.subscriber = subscriber
                subscriber.keepAlive(CoreDeinitProbe {
                    log.append("keepAlive released")
                })
                return CoreDeinitProbeDisposable {
                    log.append("inner released")
                }
            }.start(next: { _ in
                withExtendedLifetime(nextProbe) {}
            }, error: { _ in
                withExtendedLifetime(errorProbe) {}
            }, completed: {
                withExtendedLifetime(completedProbe) {}
            })
        }
        XCTAssertEqual(log.events, [])
        holder.subscriber = nil
        XCTAssertEqual(log.events, ["inner released", "keepAlive released", "next released", "error released", "completed released"])
    }

    func testSubscriberDeallocationReleaseOrderWhileHandleAlive() {
        let log = CoreEventLog()
        let holder = CoreSubscriberHolder<Int, String>()
        let handle: Disposable
        do {
            let nextProbe = CoreDeinitProbe {
                log.append("next released")
            }
            let completedProbe = CoreDeinitProbe {
                log.append("completed released")
            }
            handle = Signal<Int, String> { subscriber in
                holder.subscriber = subscriber
                subscriber.keepAlive(CoreDeinitProbe {
                    log.append("keepAlive released")
                })
                return CoreDeinitProbeDisposable {
                    log.append("inner released")
                }
            }.start(next: { _ in
                withExtendedLifetime(nextProbe) {}
            }, completed: {
                withExtendedLifetime(completedProbe) {}
            })
        }
        holder.subscriber = nil
        XCTAssertEqual(log.events, ["keepAlive released", "next released", "completed released"])
        handle.dispose()
        XCTAssertEqual(log.events, ["keepAlive released", "next released", "completed released", "inner released"])
    }

    func testInnerDisposableReleasedWithoutDisposeWhenHandleAndSubscriberAreDropped() {
        let log = CoreEventLog()
        weak var weakInner: CoreCountingDisposable?
        do {
            let inner = CoreCountingDisposable(log: log)
            weakInner = inner
            let handle = Signal<Int, String> { _ in
                return inner
            }.start(next: { _ in
            })
            XCTAssertNotNil(weakInner)
            withExtendedLifetime(handle) {}
        }
        XCTAssertNil(weakInner)
        XCTAssertEqual(log.events, [])
    }

    func testHandleKeepsInnerAliveAfterSubscriberIsGoneAndReleasesItOnDispose() {
        let log = CoreEventLog()
        weak var weakInner: CoreCountingDisposable?
        let handle: Disposable
        do {
            let inner = CoreCountingDisposable(log: log)
            weakInner = inner
            handle = Signal<Int, String> { _ in
                return inner
            }.start()
        }
        XCTAssertNotNil(weakInner)
        handle.dispose()
        XCTAssertNil(weakInner)
        XCTAssertEqual(log.events, ["dispose"])
    }

    func testInnerReleasedAfterAsynchronousCompletionWhileHandleAlive() {
        let log = CoreEventLog()
        let holder = CoreSubscriberHolder<Int, String>()
        weak var weakInner: CoreCountingDisposable?
        let handle: Disposable
        do {
            let inner = CoreCountingDisposable(log: log)
            weakInner = inner
            handle = self.holdingSignal(holder, disposable: inner).start()
        }
        XCTAssertNotNil(weakInner)
        holder.subscriber?.putCompletion()
        XCTAssertNil(weakInner)
        XCTAssertEqual(log.events, ["dispose"])
        XCTAssertNotNil(holder.subscriber)
        handle.dispose()
        XCTAssertEqual(log.events, ["dispose"])
    }

    func testInnerReleasedAfterSynchronousCompletionWhileHandleAlive() {
        let log = CoreEventLog()
        weak var weakInner: CoreCountingDisposable?
        let handle: Disposable
        do {
            let inner = CoreCountingDisposable(log: log)
            weakInner = inner
            handle = Signal<Int, String> { subscriber in
                subscriber.putCompletion()
                return inner
            }.start()
        }
        XCTAssertNil(weakInner)
        XCTAssertEqual(log.events, ["dispose"])
        handle.dispose()
        XCTAssertEqual(log.events, ["dispose"])
    }

    func testInnerReleasedAfterHandleDisposeWhileSourceStillHoldsSubscriber() {
        let log = CoreEventLog()
        let holder = CoreSubscriberHolder<Int, String>()
        weak var weakInner: CoreCountingDisposable?
        let handle: Disposable
        do {
            let inner = CoreCountingDisposable(log: log)
            weakInner = inner
            handle = self.holdingSignal(holder, disposable: inner).start()
        }
        XCTAssertNotNil(weakInner)
        handle.dispose()
        XCTAssertNil(weakInner)
        XCTAssertNotNil(holder.subscriber)
        XCTAssertEqual(log.events, ["dispose"])
    }

    func testSubscriberRetainedOnlyBySourceNotByHandle() {
        weak var weakSubscriber: Subscriber<Int, String>?
        let handle = Signal<Int, String> { subscriber in
            weakSubscriber = subscriber
            return EmptyDisposable
        }.start(next: { _ in
        })
        XCTAssertNil(weakSubscriber)
        handle.dispose()
    }
}
