import Foundation

public func reduceLeft<T, E>(value: T, f: @escaping(T, T) -> T) -> (_ signal: Signal<T, E>) -> Signal<T, E> {
    return { signal in
        return Signal<T, E> { subscriber in
            var currentValue = value
            
            return signal.start(next: { next in
                currentValue = f(currentValue, next)
            }, error: { error in
                subscriber.putError(error)
            }, completed: {
                subscriber.putNext(currentValue)
                subscriber.putCompletion()
            })
        }
    }
}

public func reduceLeft<T, E>(value: T, f: @escaping(T, T, (T) -> Void) -> T) -> (_ signal: Signal<T, E>) -> Signal<T, E> {
    return { signal in
        return Signal<T, E> { subscriber in
            var currentValue = value
            let emit: (T) -> Void = { next in
                subscriber.putNext(next)
            }
            
            return signal.start(next: { next in
                currentValue = f(currentValue, next, emit)
                }, error: { error in
                    subscriber.putError(error)
                }, completed: {
                    subscriber.putNext(currentValue)
                    subscriber.putCompletion()
            })
        }
    }
}

public enum Passthrough<T> {
    case None
    case Some(T)
}

private final class ReduceQueueState<T, E> : Disposable {
    var lock: OSSpinLock = 0
    var executingSignal = false
    var terminated = false
    
    var disposable: Disposable = EmptyDisposable
    let currentDisposable = MetaDisposable()
    let subscriber: Subscriber<T, E>
    
    var queuedValues: [T] = []
    var generator: (T, T) -> Signal<(T, Passthrough<T>), E>
    var value: T
    
    init(subscriber: Subscriber<T, E>, value: T, generator: @escaping(T, T) -> Signal<(T, Passthrough<T>), E>) {
        self.subscriber = subscriber
        self.generator = generator
        self.value = value
    }
    
    func beginWithDisposable(_ disposable: Disposable) {
        self.disposable = disposable
    }
    
    func enqueueNext(_ next: T) {
        var startSignal = false
        var currentValue: T
        OSSpinLockLock(&self.lock)
        currentValue = self.value
        if self.executingSignal {
            self.queuedValues.append(next)
        } else {
            self.executingSignal = true
            startSignal = true
        }
        OSSpinLockUnlock(&self.lock)
        
        if startSignal {
            let disposable = generator(currentValue, next).start(next: { next in
                self.updateValue(next.0)
                switch next.1 {
                    case let .Some(value):
                        self.subscriber.putNext(value)
                    case .None:
                        break
                }
            }, error: { error in
                self.subscriber.putError(error)
            }, completed: {
                self.headCompleted()
            })
            self.currentDisposable.set(disposable)
        }
    }
    
    func updateValue(_ value: T) {
        OSSpinLockLock(&self.lock)
        self.value = value
        OSSpinLockUnlock(&self.lock)
    }
    
    func headCompleted() {
        while true {
            let leftFunction = Atomic(value: false)
            
            var nextSignal: Signal<(T, Passthrough<T>), E>! = nil
            
            var terminated = false
            var currentValue: T!
            OSSpinLockLock(&self.lock)
            self.executingSignal = false
            if self.queuedValues.count != 0 {
                nextSignal = self.generator(self.value, self.queuedValues[0])
                self.queuedValues.remove(at: 0)
                self.executingSignal = true
            } else {
                currentValue = self.value
                terminated = self.terminated
            }
            OSSpinLockUnlock(&self.lock)
            
            if terminated {
                self.subscriber.putNext(currentValue)
                self.subscriber.putCompletion()
            } else if nextSignal != nil {
                let disposable = nextSignal.start(next: { next in
                    self.updateValue(next.0)
                    switch next.1 {
                        case let .Some(value):
                            self.subscriber.putNext(value)
                        case .None:
                            break
                    }
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
        let currentValue: T
        OSSpinLockLock(&self.lock)
        executingSignal = self.executingSignal
        self.terminated = true
        currentValue = self.value
        OSSpinLockUnlock(&self.lock)
        
        if !executingSignal {
            self.subscriber.putNext(currentValue)
            self.subscriber.putCompletion()
        }
    }
    
    func dispose() {
        self.currentDisposable.dispose()
        self.disposable.dispose()
    }
}

public func reduceLeft<T, E>(_ value: T, generator: @escaping(T, T) -> Signal<(T, Passthrough<T>), E>) -> (_ signal: Signal<T, E>) -> Signal<T, E> {
    return { signal in
        return Signal { subscriber in
            let state = ReduceQueueState(subscriber: subscriber, value: value, generator: generator)
            state.beginWithDisposable(signal.start(next: { next in
                state.enqueueNext(next)
            }, error: { error in
                subscriber.putError(error)
            }, completed: {
                state.beginCompletion()
            }))
            return state
        }
    }
}
