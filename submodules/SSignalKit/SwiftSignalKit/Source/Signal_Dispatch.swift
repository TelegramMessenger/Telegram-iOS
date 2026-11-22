import Foundation

public func deliverOn<T, E>(_ queue: Queue) -> (Signal<T, E>) -> Signal<T, E> {
    return { signal in
        return Signal { subscriber in
            return signal.start(next: { next in
                queue.async {
                    subscriber.putNext(next)
                }
            }, error: { error in
                queue.async {
                    subscriber.putError(error)
                }
            }, completed: {
                queue.async {
                    subscriber.putCompletion()
                }
            })
        }
    }
}

public func deliverOnMainQueue<T, E>(_ signal: Signal<T, E>) -> Signal<T, E> {
    return signal |> deliverOn(Queue.mainQueue())
}

public func deliverOn<T, E>(_ threadPool: ThreadPool) -> (Signal<T, E>) -> Signal<T, E> {
    return { signal in
        return Signal { subscriber in
            let queue = threadPool.nextQueue()
            return signal.start(next: { next in
                queue.addTask(ThreadPoolTask { state in
                    if !state.cancelled.with({ $0 }) {
                        subscriber.putNext(next)
                    }
                })
            }, error: { error in
                queue.addTask(ThreadPoolTask { state in
                    if !state.cancelled.with({ $0 }) {
                        subscriber.putError(error)
                    }
                })
            }, completed: {
                queue.addTask(ThreadPoolTask { state in
                    if !state.cancelled.with({ $0 }) {
                        subscriber.putCompletion()
                    }
                })
            })
        }
    }
}

public func runOn<T, E>(_ queue: Queue) -> (Signal<T, E>) -> Signal<T, E> {
    return { signal in
        return Signal { subscriber in
            if queue.isCurrent() {
                return signal.start(next: { next in
                    subscriber.putNext(next)
                }, error: { error in
                    subscriber.putError(error)
                }, completed: {
                    subscriber.putCompletion()
                })
            } else {
                var cancelled = false
                let disposable = MetaDisposable()
                
                disposable.set(ActionDisposable {
                    cancelled = true
                })
                
                queue.async {
                    if cancelled {
                        return
                    }
                    
                    disposable.set(signal.start(next: { next in
                        subscriber.putNext(next)
                    }, error: { error in
                        subscriber.putError(error)
                    }, completed: {
                        subscriber.putCompletion()
                    }))
                }
                
                return disposable
            }
        }
    }
}

public func runOn<T, E>(_ threadPool: ThreadPool) -> (Signal<T, E>) -> Signal<T, E> {
    return { signal in
        return Signal { subscriber in
            let cancelled = false
            let disposable = MetaDisposable()
            
            let task = ThreadPoolTask { state in
                if cancelled || state.cancelled.with({ $0 }) {
                    return
                }
                
                disposable.set(signal.start(next: { next in
                    subscriber.putNext(next)
                }, error: { error in
                    subscriber.putError(error)
                }, completed: {
                    subscriber.putCompletion()
                }))
            }
            
            disposable.set(ActionDisposable {
                task.cancel()
            })
            
            threadPool.addTask(task)
            
            return disposable
        }
    }
}
