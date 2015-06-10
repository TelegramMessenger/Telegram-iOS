import Foundation

public func reduceLeft<T, E>(value: T, f: (T, T) -> T)(signal: Signal<T, E>) -> Signal<T, E> {
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

public func reduceLeft<T, E>(value: T, f: (T, T, T -> Void) -> T)(signal: Signal<T, E>) -> Signal<T, E> {
    return Signal<T, E> { subscriber in
        var currentValue = value
        let emit: T -> Void = { next in
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
