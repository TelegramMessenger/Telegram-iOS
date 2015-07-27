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
    
    init(subscriber: Subscriber<T, E>, queueMode: Bool) {
        self.subscriber = subscriber
        self.queueMode = queueMode
    }
    
    func beginWithDisposable(disposable: Disposable) {
        self.disposable = disposable
    }
    
    func enqueueSignal(signal: Signal<T, E>) {
        var startSignal = false
        OSSpinLockLock(&self.lock)
        if self.queueMode && self.executingSignal {
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
                    self.queuedSignals.removeAtIndex(0)
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

public func switchToLatest<T, E>(signal: Signal<Signal<T, E>, E>) -> Signal<T, E> {
    return Signal { subscriber in
        let state = SignalQueueState(subscriber: subscriber, queueMode: false)
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

public func queue<T, E>(signal: Signal<Signal<T, E>, E>) -> Signal<T, E> {
    return Signal { subscriber in
        let state = SignalQueueState(subscriber: subscriber, queueMode: true)
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

public func mapToSignal<T, R, E>(f: T -> Signal<R, E>)(signal: Signal<T, E>) -> Signal<R, E> {
    return signal |> map { f($0) } |> switchToLatest
}

public func mapToQueue<T, R, E>(f: T -> Signal<R, E>)(signal: Signal<T, E>) -> Signal<R, E> {
    return signal |> map { f($0) } |> queue
}

public func then<T, E>(nextSignal: Signal<T, E>)(signal: Signal<T, E>) -> Signal<T, E> {
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

public func `defer`<T, E>(generator: () -> Signal<T, E>) -> Signal<T, E> {
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
