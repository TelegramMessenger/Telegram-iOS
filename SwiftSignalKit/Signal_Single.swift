import Foundation

public func single<T, E>(value: T, errorRype: E.Type) -> Signal<T, E> {
    return Signal<T, E> { subscriber in
        subscriber.putNext(value)
        subscriber.putCompletion()
        
        return EmptyDisposable
    }
}

public func fail<T, E>(valueType: T.Type, error: E) -> Signal<T, E> {
    return Signal<T, E> { subscriber in
        subscriber.putError(error)
        
        return EmptyDisposable
    }
}

public func complete<T, E>(valueType: T.Type, error: E.Type) -> Signal<T, E> {
    return Signal<T, E> { subscriber in
        subscriber.putCompletion()
        
        return EmptyDisposable
    }
}
