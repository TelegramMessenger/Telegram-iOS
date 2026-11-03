import Foundation

final class SignalQueueFlag {
    private var lock = os_unfair_lock()
    private var _value = false
    
    init() {
    }
    
    func swapToTrue() -> Bool {
        os_unfair_lock_lock(&self.lock)
        let previous = self._value
        self._value = true
        os_unfair_lock_unlock(&self.lock)
        return previous
    }
    
    var value: Bool {
        os_unfair_lock_lock(&self.lock)
        let value = self._value
        os_unfair_lock_unlock(&self.lock)
        return value
    }
}

private final class SignalQueueState<T, E>: Disposable {
    private var lock = os_unfair_lock()
    private var executingSignal = false
    private var terminated = false
    
    private var disposable: Disposable = EmptyDisposable
    private let currentDisposable = MetaDisposable()
    private let subscriber: Subscriber<T, E>
    
    private var queuedSignals: [Signal<T, E>] = []
    private let queueMode: Bool
    private let throttleMode: Bool
    
    init(subscriber: Subscriber<T, E>, queueMode: Bool, throttleMode: Bool) {
        self.subscriber = subscriber
        self.queueMode = queueMode
        self.throttleMode = throttleMode
    }
    
    func beginWithDisposable(_ disposable: Disposable) {
        self.disposable = disposable
    }
    
    func enqueueSignal(_ signal: Signal<T, E>) {
        var startSignal = false
        var droppedSignals: [Signal<T, E>]?
        os_unfair_lock_lock(&self.lock)
        if self.queueMode && self.executingSignal {
            if self.throttleMode {
                droppedSignals = self.queuedSignals
                self.queuedSignals.removeAll()
            }
            self.queuedSignals.append(signal)
        } else {
            self.executingSignal = true
            startSignal = true
        }
        os_unfair_lock_unlock(&self.lock)
        
        if droppedSignals != nil {
            droppedSignals = nil
        }
        
        if startSignal {
            let disposable = signal.start(next: { next in
                self.subscriber.putNext(next)
            }, error: { error in
                self.subscriber.putError(error)
            }, completed: {
                self.headCompleted()
            })
            self.currentDisposable.set(disposable)
        }
    }
    
    func headCompleted() {
        while true {
            let leftFunction = SignalQueueFlag()
            
            var nextSignal: Signal<T, E>! = nil
            
            var terminated = false
            os_unfair_lock_lock(&self.lock)
            self.executingSignal = false
            if self.queueMode {
                if self.queuedSignals.count != 0 {
                    nextSignal = self.queuedSignals.removeFirst()
                    self.executingSignal = true
                } else {
                    terminated = self.terminated
                }
            } else {
                terminated = self.terminated
            }
            os_unfair_lock_unlock(&self.lock)
            
            if terminated {
                self.subscriber.putCompletion()
            } else if nextSignal != nil {
                let disposable = nextSignal.start(next: { next in
                    self.subscriber.putNext(next)
                }, error: { error in
                    self.subscriber.putError(error)
                }, completed: {
                    if leftFunction.swapToTrue() == true {
                        self.headCompleted()
                    }
                })
                
                self.currentDisposable.set(disposable)
            }
            
            if leftFunction.swapToTrue() == false {
                break
            }
        }
    }
    
    func beginCompletion() {
        var executingSignal = false
        os_unfair_lock_lock(&self.lock)
        executingSignal = self.executingSignal
        self.terminated = true
        os_unfair_lock_unlock(&self.lock)
        
        if !executingSignal {
            self.subscriber.putCompletion()
        }
    }
    
    func dispose() {
        self.currentDisposable.dispose()
        self.disposable.dispose()
    }
}

public func switchToLatest<T, E>(_ signal: Signal<Signal<T, E>, E>) -> Signal<T, E> {
    return Signal { subscriber in
        let state = SignalQueueState(subscriber: subscriber, queueMode: false, throttleMode: false)
        state.beginWithDisposable(signal.start(next: { next in
            state.enqueueSignal(next)
        }, error: { error in
            subscriber.putError(error)
        }, completed: {
            state.beginCompletion()
        }))
        return state
    }
}

public func queue<T, E>(_ signal: Signal<Signal<T, E>, E>) -> Signal<T, E> {
    return Signal { subscriber in
        let state = SignalQueueState(subscriber: subscriber, queueMode: true, throttleMode: false)
        state.beginWithDisposable(signal.start(next: { next in
            state.enqueueSignal(next)
        }, error: { error in
            subscriber.putError(error)
        }, completed: {
            state.beginCompletion()
        }))
        return state
    }
}

public func throttled<T, E>(_ signal: Signal<Signal<T, E>, E>) -> Signal<T, E> {
    return Signal { subscriber in
        let state = SignalQueueState(subscriber: subscriber, queueMode: true, throttleMode: true)
        state.beginWithDisposable(signal.start(next: { next in
            state.enqueueSignal(next)
        }, error: { error in
            subscriber.putError(error)
        }, completed: {
            state.beginCompletion()
        }))
        return state
    }
}

public func mapToSignal<T, R, E>(_ f: @escaping(T) -> Signal<R, E>) -> (Signal<T, E>) -> Signal<R, E> {
    return { signal -> Signal<R, E> in
        return Signal<Signal<R, E>, E> { subscriber in
            return signal.start(next: { next in
                subscriber.putNext(f(next))
            }, error: { error in
                subscriber.putError(error)
            }, completed: {
                subscriber.putCompletion()
            })
        } |> switchToLatest
    }
}

public func ignoreValues<T, E>(_ signal: Signal<T, E>) -> Signal<Never, E> {
    return Signal { subscriber in
        return signal.start(error: { error in
            subscriber.putError(error)
        }, completed: {
            subscriber.putCompletion()
        })
    }
}

public func mapToSignalPromotingError<T, R, E>(_ f: @escaping(T) -> Signal<R, E>) -> (Signal<T, NoError>) -> Signal<R, E> {
    return { signal -> Signal<R, E> in
        return Signal<Signal<R, E>, E> { subscriber in
            return signal.start(next: { next in
                subscriber.putNext(f(next))
            }, completed: { 
                subscriber.putCompletion()
            })
        } |> switchToLatest
    }
}

public func mapToQueue<T, R, E>(_ f: @escaping(T) -> Signal<R, E>) -> (Signal<T, E>) -> Signal<R, E> {
    return { signal -> Signal<R, E> in
        return signal |> map { f($0) } |> queue
    }
}

public func mapToThrottled<T, R, E>(_ f: @escaping(T) -> Signal<R, E>) -> (Signal<T, E>) -> Signal<R, E> {
    return { signal -> Signal<R, E> in
        return signal |> map { f($0) } |> throttled
    }
}

public func then<T, E>(_ nextSignal: Signal<T, E>) -> (Signal<T, E>) -> Signal<T, E> {
    return { signal -> Signal<T, E> in
        return Signal<T, E> { subscriber in
            let disposable = DisposableSet()
            
            disposable.add(signal.start(next: { next in
                subscriber.putNext(next)
            }, error: { error in
                subscriber.putError(error)
            }, completed: {
                disposable.add(nextSignal.start(next: { next in
                    subscriber.putNext(next)
                }, error: { error in
                    subscriber.putError(error)
                }, completed: {
                    subscriber.putCompletion()
                }))
            }))
            
            return disposable
        }
    }
}

public func deferred<T, E>(_ generator: @escaping() -> Signal<T, E>) -> Signal<T, E> {
    return Signal { subscriber in
        return generator().start(next: { next in
            subscriber.putNext(next)
        }, error: { error in
            subscriber.putError(error)
        }, completed: {
            subscriber.putCompletion()
        })
    }
}

public func debug_measureTimeToFirstEvent<T, E>(label: String) -> (Signal<T, E>) -> Signal<T, E> {
    return { signal in
        #if DEBUG || true
        if "".isEmpty {
            var isFirst = true
            return Signal { subscriber in
                let startTimestamp = CFAbsoluteTimeGetCurrent()
                return signal.start(next: { value in
                    if isFirst {
                        isFirst = false
                        let deltaTime = (CFAbsoluteTimeGetCurrent() - startTimestamp) * 1000.0
                        print("measureTimeToFirstEvent(\(label): \(deltaTime) ms")
                    }
                    subscriber.putNext(value)
                }, error: subscriber.putError, completed: subscriber.putCompletion)
            }
        }
        #endif
        return signal
    }
}
