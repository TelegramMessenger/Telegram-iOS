import Foundation

private final class SignalQueueState<T, E> : Disposable {
    var lock: OSSpinLock = 0
    var executingSignal = false
    var terminated = false
    
    var disposable: Disposable = EmptyDisposable
    let currentDisposable = MetaDisposable()
    let subscriber: Subscriber<T, E>
    
    var queuedSignals: [Signal<T, E>] = []
    let queueMode: Bool
    let throttleMode: Bool
    
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
        OSSpinLockLock(&self.lock)
        if self.queueMode && self.executingSignal {
            if self.throttleMode {
                self.queuedSignals.removeAll()
            }
            self.queuedSignals.append(signal)
        } else {
            self.executingSignal = true
            startSignal = true
        }
        OSSpinLockUnlock(&self.lock)
        
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
            let leftFunction = Atomic(value: false)
            
            var nextSignal: Signal<T, E>! = nil
            
            var terminated = false
            OSSpinLockLock(&self.lock)
            self.executingSignal = false
            if self.queueMode {
                if self.queuedSignals.count != 0 {
                    nextSignal = self.queuedSignals[0]
                    self.queuedSignals.remove(at: 0)
                    self.executingSignal = true
                } else {
                    terminated = self.terminated
                }
            } else {
                terminated = self.terminated
            }
            OSSpinLockUnlock(&self.lock)
            
            if terminated {
                self.subscriber.putCompletion()
            } else if nextSignal != nil {
                let disposable = nextSignal.start(next: { next in
                    self.subscriber.putNext(next)
                }, error: { error in
                    self.subscriber.putError(error)
                }, completed: {
                    if leftFunction.swap(true) == true {
                        self.headCompleted()
                    }
                })
                
                currentDisposable.set(disposable)
            }
            
            if leftFunction.swap(true) == false {
                break
            }
        }
    }
    
    func beginCompletion() {
        var executingSignal = false
        OSSpinLockLock(&self.lock)
        executingSignal = self.executingSignal
        self.terminated = true
        OSSpinLockUnlock(&self.lock)
        
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

public func mapToSignal<T, R, E>(_ f: (T) -> Signal<R, E>) -> (Signal<T, E>) -> Signal<R, E> {
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

public func mapToSignalPromotingError<T, R, E>(_ f: (T) -> Signal<R, E>) -> (Signal<T, NoError>) -> Signal<R, E> {
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

public func mapToQueue<T, R, E>(_ f: (T) -> Signal<R, E>) -> (Signal<T, E>) -> Signal<R, E> {
    return { signal -> Signal<R, E> in
        return signal |> map { f($0) } |> queue
    }
}

public func mapToThrottled<T, R, E>(_ f: (T) -> Signal<R, E>) -> (Signal<T, E>) -> Signal<R, E> {
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

public func deferred<T, E>(_ generator: () -> Signal<T, E>) -> Signal<T, E> {
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
