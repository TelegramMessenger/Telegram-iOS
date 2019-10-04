import Foundation

public func `catch`<T, E, R>(_ f: @escaping(E) -> Signal<T, R>) -> (Signal<T, E>) -> Signal<T, R> {
    return { signal in
        return Signal<T, R> { subscriber in
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
}

private func recursiveFunction(_ f: @escaping(@escaping() -> Void) -> Void) -> (() -> Void) {
    return {
        f(recursiveFunction(f))
    }
}

public func restart<T, E>(_ signal: Signal<T, E>) -> Signal<T, E> {
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
            let _ = shouldRestart.swap(false)
        }
    }
}

public func recurse<T, E>(_ latestValue: T?) -> (Signal<T, E>) -> Signal<T, E> {
    return { signal in
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
                let _ = shouldRestart.swap(false)
            }
        }
    }
}

public func retry<T, E>(_ delayIncrement: Double, maxDelay: Double, onQueue queue: Queue) -> (_ signal: Signal<T, E>) -> Signal<T, NoError> {
    return { signal in
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
                       
                        let time: DispatchTime = DispatchTime.now() + Double(delay)
                        queue.queue.asyncAfter(deadline: time, execute: {
                            recurse()
                        })
                    }, completed: {
                        let _ = shouldRetry.swap(false)
                        subscriber.putCompletion()
                    })
                    currentDisposable.set(disposable)
                }
            }
            
            start()
            
            return ActionDisposable {
                currentDisposable.dispose()
                let _ = shouldRetry.swap(false)
            }
        }
    }
}

public func retry<T, E>(retryOnError: @escaping (E) -> Bool, delayIncrement: Double, maxDelay: Double, maxRetries: Int, onQueue queue: Queue) -> (_ signal: Signal<T, E>) -> Signal<T, E> {
    return { signal in
        return Signal { subscriber in
            let shouldRetry = Atomic(value: true)
            let currentDelay = Atomic<(Double, Int)>(value: (0.0, 0))
            let currentDisposable = MetaDisposable()
            
            let start = recursiveFunction { recurse in
                let currentShouldRetry = shouldRetry.with { value in
                    return value
                }
                if currentShouldRetry {
                    let disposable = signal.start(next: { next in
                        subscriber.putNext(next)
                    }, error: { error in
                        if !retryOnError(error) {
                            subscriber.putError(error)
                        } else {
                            let (delay, count) = currentDelay.modify { value, count in
                                return (min(maxDelay, value + delayIncrement), count + 1)
                            }
                            
                            if count >= maxRetries {
                                subscriber.putError(error)
                            } else {
                                let time: DispatchTime = DispatchTime.now() + Double(delay)
                                queue.queue.asyncAfter(deadline: time, execute: {
                                    recurse()
                                })
                            }
                        }
                    }, completed: {
                        let _ = shouldRetry.swap(false)
                        subscriber.putCompletion()
                    })
                    currentDisposable.set(disposable)
                }
            }
            
            start()
            
            return ActionDisposable {
                currentDisposable.dispose()
                let _ = shouldRetry.swap(false)
            }
        }
    }
}

public func restartIfError<T, E>(_ signal: Signal<T, E>) -> Signal<T, NoError> {
    return Signal<T, NoError> { subscriber in
        let shouldRetry = Atomic(value: true)
        let currentDisposable = MetaDisposable()
        
        let start = recursiveFunction { recurse in
            let currentShouldRetry = shouldRetry.with { value in
                return value
            }
            if currentShouldRetry {
                let disposable = signal.start(next: { next in
                    subscriber.putNext(next)
                }, error: { error in
                    recurse()
                }, completed: {
                    let _ = shouldRetry.swap(false)
                    subscriber.putCompletion()
                })
                currentDisposable.set(disposable)
            }
        }
        
        start()
        
        return ActionDisposable {
            currentDisposable.dispose()
            let _ = shouldRetry.swap(false)
        }
    }
}

