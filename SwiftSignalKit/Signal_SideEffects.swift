import Foundation

public func beforeNext<T, E, R>(f: T -> R)(signal: Signal<T, E>) -> Signal<T, E> {
    return Signal<T, E> { subscriber in
        return signal.start(next: { next in
            let _ = f(next)
            subscriber.putNext(next)
        }, error: { error in
            subscriber.putError(error)
        }, completed: {
            subscriber.putCompletion()
        })
    }
}

public func afterNext<T, E, R>(f: T -> R)(signal: Signal<T, E>) -> Signal<T, E> {
    return Signal<T, E> { subscriber in
        return signal.start(next: { next in
            subscriber.putNext(next)
            let _ = f(next)
        }, error: { error in
            subscriber.putError(error)
        }, completed: {
            subscriber.putCompletion()
        })
    }
}

public func afterDisposed<T, E, R>(f: Void -> R)(signal: Signal<T, E>) -> Signal<T, E> {
    return Signal<T, E> { subscriber in
        let disposable = DisposableSet()
        disposable.add(signal.start(next: { next in
            subscriber.putNext(next)
        }, error: { error in
            subscriber.putError(error)
        }, completed: {
            subscriber.putCompletion()
        }))
        disposable.add(ActionDisposable {
            let _ = f()
        })
        
        return disposable
    }
}