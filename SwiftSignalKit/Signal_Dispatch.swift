import Foundation

public func deliverOn<T, E>(queue: Queue)(signal: Signal<T, E>) -> Signal<T, E> {
    return Signal { subscriber in
        return signal.start(next: { next in
            queue.dispatch {
                subscriber.putNext(next)
            }
        }, error: { error in
            queue.dispatch {
                subscriber.putError(error)
            }
        }, completed: {
            queue.dispatch {
                subscriber.putCompletion()
            }
        })
    }
}

public func deliverOnMainQueue<T, E>(signal: Signal<T, E>) -> Signal<T, E> {
    return signal |> deliverOn(Queue.mainQueue())
}

public func deliverOn<T, E>(threadPool: ThreadPool)(signal: Signal<T, E>) -> Signal<T, E> {
    return Signal { subscriber in
        let queue = threadPool.nextQueue()
        return signal.start(next: { next in
            queue.addTask(ThreadPoolTask { state in
                if !state.cancelled {
                    subscriber.putNext(next)
                }
            })
        }, error: { error in
            queue.addTask(ThreadPoolTask { state in
                if !state.cancelled {
                    subscriber.putError(error)
                }
            })
        }, completed: {
            queue.addTask(ThreadPoolTask { state in
                if !state.cancelled {
                    subscriber.putCompletion()
                }
            })
        })
    }
}

public func runOn<T, E>(threadPool: ThreadPool)(signal: Signal<T, E>) -> Signal<T, E> {
    return Signal { subscriber in
        let cancelled = false
        let disposable = MetaDisposable()
        
        let task = ThreadPoolTask { state in
            if cancelled || state.cancelled {
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

public func bufferOn<T, E>(queue: Queue, timeout: Double)(signal: Signal<T, E>) -> Signal<[T], E> {
    return Signal { subscriber in
        let timer = Timer(timeout: timeout, `repeat`: false, completion: {
            
        }, queue: queue)
        return signal.start(next: { next in
            
        }, error: { error in
            subscriber.putError(error)
        }, completed: {
            
        })
    }
}
