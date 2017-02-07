import Foundation

public func delay<T, E>(_ timeout: Double, queue: Queue) -> (_ signal: Signal<T, E>) -> Signal<T, E> {
    return { signal in
        return Signal<T, E> { subscriber in
            let disposable = MetaDisposable()
            queue.async {
                let timer = Timer(timeout: timeout, repeat: false, completion: {
                    disposable.set(signal.start(next: { next in
                        subscriber.putNext(next)
                    }, error: { error in
                        subscriber.putError(error)
                    }, completed: {
                        subscriber.putCompletion()
                    }))
                }, queue: queue)
                
                disposable.set(ActionDisposable {
                    queue.async {
                        timer.invalidate()
                    }
                })
                
                timer.start()
            }
            return disposable
        }
    }
}

public func timeout<T, E>(_ timeout: Double, queue: Queue, alternate: Signal<T, E>) -> (Signal<T, E>) -> Signal<T, E> {
    return { signal in
        return Signal<T, E> { subscriber in
            let disposable = MetaDisposable()
            let timer = Timer(timeout: timeout, repeat: false, completion: {
                disposable.set(alternate.start(next: { next in
                    subscriber.putNext(next)
                }, error: { error in
                    subscriber.putError(error)
                }, completed: {
                    subscriber.putCompletion()
                }))
            }, queue: queue)
            
            disposable.set(signal.start(next: { next in
                timer.invalidate()
                subscriber.putNext(next)
            }, error: { error in
                timer.invalidate()
                subscriber.putError(error)
            }, completed: {
                timer.invalidate()
                subscriber.putCompletion()
            }))
            timer.start()
            
            let disposableSet = DisposableSet()
            disposableSet.add(ActionDisposable {
                timer.invalidate()
            })
            disposableSet.add(disposable)
            
            return disposableSet
        }
    }
}
