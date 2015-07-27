import Foundation

public func map<T, E, R>(f: T -> R)(signal: Signal<T, E>) -> Signal<R, E> {
    return Signal<R, E> { subscriber in
        return signal.start(next: { next in
            subscriber.putNext(f(next))
        }, error: { error in
            subscriber.putError(error)
        }, completed: {
            subscriber.putCompletion()
        })
    }
}

public func filter<T, E>(f: T -> Bool)(signal: Signal<T, E>) -> Signal<T, E> {
    return Signal<T, E> { subscriber in
        return signal.start(next: { next in
            if f(next) {
                subscriber.putNext(next)
            }
        }, error: { error in
            subscriber.putError(error)
        }, completed: {
            subscriber.putCompletion()
        })
    }
}

public func mapError<T, E, R>(f: E -> R)(signal: Signal<T, E>) -> Signal<T, R> {
    return Signal<T, R> { subscriber in
        return signal.start(next: { next in
            subscriber.putNext(next)
        }, error: { error in
            subscriber.putError(f(error))
        }, completed: {
            subscriber.putCompletion()
        })
    }
}
