import Foundation

public func `catch`<T, E>(f: E -> Signal<T, E>)(signal: Signal<T, E>) -> Signal<T, E> {
    return Signal<T, E> { subscriber in
        let disposable = DisposableSet()
        
        disposable.add(signal.start(next: { next in
            subscriber.putNext(next)
        }, error: { error in
            let anotherSignal = f(error)
            
            disposable.add(anotherSignal.start(next: { next in
                subscriber.putNext(next)
            }, error: { error in
               subscriber.putError(error)
            }, completed: {
                subscriber.putCompletion()
            }))
        }, completed: {
            subscriber.putCompletion()
        }))
        
        return disposable
    }
}

private func recursiveFunction(f: (Void -> Void) -> Void) -> (Void -> Void) {
    return {
        f(recursiveFunction(f))
    }
}

public func restart<T, E>(signal: Signal<T, E>) -> Signal<T, E> {
    return Signal { subscriber in
        let shouldRestart = Atomic(value: true)
        let currentDisposable = MetaDisposable()
        
        let start = recursiveFunction { recurse in
            let currentShouldRestart = shouldRestart.with { value in
                return value
            }
            if currentShouldRestart {
                let disposable = signal.start(next: { next in
                    subscriber.putNext(next)
                }, error: { error in
                    subscriber.putError(error)
                }, completed: {
                    recurse()
                })
                currentDisposable.set(disposable)
            }
        }
        
        start()
        
        return ActionDisposable {
            currentDisposable.dispose()
            shouldRestart.swap(false)
        }
    }
}

public func recurse<T, E>(latestValue: T?)(signal: Signal<T, E>) -> Signal<T, E> {
    return Signal { subscriber in
        let shouldRestart = Atomic(value: true)
        let currentDisposable = MetaDisposable()
        
        let start = recursiveFunction { recurse in
            let currentShouldRestart = shouldRestart.with { value in
                return value
            }
            if currentShouldRestart {
                let disposable = signal.start(next: { next in
                    subscriber.putNext(next)
                    }, error: { error in
                        subscriber.putError(error)
                    }, completed: {
                        recurse()
                })
                currentDisposable.set(disposable)
            }
        }
        
        start()
        
        return ActionDisposable {
            currentDisposable.dispose()
            shouldRestart.swap(false)
        }
    }
}

public func retry<T, E>(delayIncrement: Double, maxDelay: Double, onQueue queue: Queue)(signal: Signal<T, E>) -> Signal<T, NoError> {
    return Signal { subscriber in
        let shouldRetry = Atomic(value: true)
        let currentDelay = Atomic(value: 0.0)
        let currentDisposable = MetaDisposable()
        
        let start = recursiveFunction { recurse in
            let currentShouldRetry = shouldRetry.with { value in
                return value
            }
            if currentShouldRetry {
                let disposable = signal.start(next: { next in
                    subscriber.putNext(next)
                }, error: { error in
                    let delay = currentDelay.modify { value in
                        return min(maxDelay, value + delayIncrement)
                    }
                    
                    let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(delay * Double(NSEC_PER_SEC)))
                    dispatch_after(delayTime, queue.queue) {
                        recurse()
                    }
                }, completed: {
                    shouldRetry.swap(false)
                    subscriber.putCompletion()
                })
                currentDisposable.set(disposable)
            }
        }
        
        start()
        
        return ActionDisposable {
            currentDisposable.dispose()
            shouldRetry.swap(false)
        }
    }
}
