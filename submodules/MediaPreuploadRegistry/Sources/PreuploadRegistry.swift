import Foundation
import SwiftSignalKit

/// A ref-counted registry of in-flight work, keyed by `Key`, producing `Value`.
///
/// Its whole job is deciding **who still wants a piece of work** and what happens when nobody does.
/// It knows nothing about media, networks or uploads — the caller injects a producer.
///
/// Two counts, deliberately separate: a **need** keeps the work alive; an **observer** only
/// watches. A passive UI observer must never keep an orphaned upload running.
public final class PreuploadRegistry<Key: Hashable, Value> {
    public typealias Producer = () -> Signal<PreuploadState<Value>, NoError>

    private final class Context {
        var needs: Int = 0
        var latest: PreuploadState<Value> = .progress(0.0)
        let disposable = MetaDisposable()
        let graceDisposable = MetaDisposable()

        deinit {
            self.disposable.dispose()
            self.graceDisposable.dispose()
        }
    }

    private final class Impl {
        var contexts: [Key: Context] = [:]
        var observers: [Key: Bag<(PreuploadState<Value>?) -> Void>] = [:]
        var suppressedUntil: [Key: Double] = [:]
    }

    private let impl = Atomic<Impl>(value: Impl())
    private let scheduler: PreuploadScheduler
    private let graceDelay: Double
    private let failureBackoff: Double

    public init(scheduler: PreuploadScheduler, graceDelay: Double = 1.0, failureBackoff: Double = 30.0) {
        self.scheduler = scheduler
        self.graceDelay = graceDelay
        self.failureBackoff = failureBackoff
    }

    /// Register interest in `key`, starting the work if nothing is doing it yet. Disposing the
    /// returned value releases the need; the LAST release starts the grace window.
    ///
    /// `ignoringBackoff` is for callers the user is waiting on (an explicit send): a failure
    /// suppression window must never block them.
    public func hold(_ key: Key, ignoringBackoff: Bool = false, produce: @escaping Producer) -> Disposable {
        var startSignal: Signal<PreuploadState<Value>, NoError>?
        var didHold = false
        var freshObservers: [(PreuploadState<Value>?) -> Void] = []

        self.impl.with { impl in
            if ignoringBackoff {
                impl.suppressedUntil.removeValue(forKey: key)
            } else if let until = impl.suppressedUntil[key], until > self.scheduler.now() {
                return
            }
            let context: Context
            if let existing = impl.contexts[key] {
                context = existing
                context.graceDisposable.set(nil)
            } else {
                context = Context()
                impl.contexts[key] = context
                startSignal = produce()
                freshObservers = impl.observers[key]?.copyItems() ?? []
            }
            context.needs += 1
            didHold = true
        }

        for observer in freshObservers {
            observer(.progress(0.0))
        }

        if let startSignal {
            let disposable = startSignal.start(next: { [weak self] state in
                self?.update(key: key, state: state)
            })
            self.impl.with { impl in
                impl.contexts[key]?.disposable.set(disposable)
            }
        }

        return ActionDisposable { [weak self] in
            guard didHold else {
                return
            }
            self?.release(key)
        }
    }

    /// Watch `key` without wanting it. Emits the current state immediately, then every change.
    /// `nil` means "there is no context for this key" — never started, or evicted.
    public func observe(_ key: Key) -> Signal<PreuploadState<Value>?, NoError> {
        return Signal { subscriber in
            var initial: PreuploadState<Value>?
            var index: Bag<(PreuploadState<Value>?) -> Void>.Index = -1

            self.impl.with { impl in
                initial = impl.contexts[key]?.latest
                let bag: Bag<(PreuploadState<Value>?) -> Void>
                if let existing = impl.observers[key] {
                    bag = existing
                } else {
                    bag = Bag()
                    impl.observers[key] = bag
                }
                index = bag.add({ state in
                    subscriber.putNext(state)
                })
            }

            subscriber.putNext(initial)

            // Strong `self`, matching the enclosing Signal closure's implicit capture. A live
            // subscription retaining the registry is harmless: the manager owns it for the
            // account's lifetime, and the capture ends when the subscription is disposed.
            return ActionDisposable {
                self.impl.with { impl in
                    impl.observers[key]?.remove(index)
                    if impl.observers[key]?.isEmpty ?? false {
                        impl.observers.removeValue(forKey: key)
                    }
                }
            }
        }
    }

    /// Create-or-join: the entry point for a caller that WANTS the result, not just to watch it.
    ///
    /// Holds a need for as long as the subscription lives, so work in flight cannot be evicted out
    /// from under a send when the UI that started it goes away. Completes on the first terminal
    /// state. Ignores any failure backoff — see `hold(_:ignoringBackoff:produce:)`.
    public func join(_ key: Key, produce: @escaping Producer) -> Signal<PreuploadState<Value>, NoError> {
        return Signal { subscriber in
            let need = self.hold(key, ignoringBackoff: true, produce: produce)
            let observed = self.observe(key).start(next: { state in
                guard let state else {
                    // Only reachable through an explicit evict() while we held a need.
                    subscriber.putNext(.failed)
                    subscriber.putCompletion()
                    return
                }
                subscriber.putNext(state)
                if state.isTerminal {
                    subscriber.putCompletion()
                }
            })
            return ActionDisposable {
                observed.dispose()
                need.dispose()
            }
        }
    }

    private func update(key: Key, state: PreuploadState<Value>) {
        var notify: [(PreuploadState<Value>?) -> Void] = []
        var didFail = false
        self.impl.with { impl in
            guard let context = impl.contexts[key] else {
                return
            }
            context.latest = state
            notify = impl.observers[key]?.copyItems() ?? []
            if case .failed = state {
                didFail = true
            }
        }
        for observer in notify {
            observer(state)
        }
        if didFail {
            self.failAndEvict(key)
        }
    }

    private func release(_ key: Key) {
        var shouldScheduleGrace = false
        self.impl.with { impl in
            guard let context = impl.contexts[key] else {
                return
            }
            context.needs -= 1
            shouldScheduleGrace = context.needs <= 0
        }
        guard shouldScheduleGrace else {
            return
        }
        // Scheduled OUTSIDE the lock: the scheduler may run the callback on another queue, and
        // graceExpired takes the same lock.
        let timer = self.scheduler.after(self.graceDelay, { [weak self] in
            self?.graceExpired(key)
        })
        var stillWanted = false
        self.impl.with { impl in
            guard let context = impl.contexts[key], context.needs <= 0 else {
                stillWanted = true
                return
            }
            context.graceDisposable.set(timer)
        }
        if stillWanted {
            // A hold landed between the two locks; the context is wanted again.
            timer.dispose()
        }
    }

    private func graceExpired(_ key: Key) {
        var evicted: Context?
        var notify: [(PreuploadState<Value>?) -> Void] = []
        self.impl.with { impl in
            guard let context = impl.contexts[key], context.needs <= 0 else {
                return
            }
            evicted = context
            impl.contexts.removeValue(forKey: key)
            notify = impl.observers[key]?.copyItems() ?? []
        }
        guard let evicted else {
            return
        }
        // Notify BEFORE tearing the work down, so no subscriber is left waiting on a context that
        // no longer exists.
        for observer in notify {
            observer(nil)
        }
        evicted.graceDisposable.set(nil)
        evicted.disposable.dispose()
    }

    /// A failed context is dropped immediately and its key enters a suppression window, so the
    /// declarative reconcile that keeps re-adding needs cannot spin on a persistent failure.
    /// Observers have already seen `.failed` by the time this runs.
    private func failAndEvict(_ key: Key) {
        var evicted: Context?
        self.impl.with { impl in
            evicted = impl.contexts.removeValue(forKey: key)
            impl.suppressedUntil[key] = self.scheduler.now() + self.failureBackoff
        }
        evicted?.graceDisposable.set(nil)
        evicted?.disposable.dispose()
    }

    /// Drop everything known about `key` — any live context and any suppression window.
    /// For callers that must not reuse a previous result at all, such as a forced re-upload.
    public func evict(_ key: Key) {
        var evicted: Context?
        var notify: [(PreuploadState<Value>?) -> Void] = []
        self.impl.with { impl in
            evicted = impl.contexts.removeValue(forKey: key)
            impl.suppressedUntil.removeValue(forKey: key)
            notify = impl.observers[key]?.copyItems() ?? []
        }
        for observer in notify {
            observer(nil)
        }
        evicted?.graceDisposable.set(nil)
        evicted?.disposable.dispose()
    }
}
