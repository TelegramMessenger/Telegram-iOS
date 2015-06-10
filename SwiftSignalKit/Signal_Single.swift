import Foundation

extension Signal {
    public static func single(value: T) -> Signal<T, E> {
        return Signal<T, E> { subscriber in
            subscriber.putNext(value)
            subscriber.putCompletion()
            
            return EmptyDisposable
        }
    }
    
    public static func fail(error: E) -> Signal<T, E> {
        return Signal<T, E> { subscriber in
            subscriber.putError(error)
            
            return EmptyDisposable
        }
    }
    
    public static func complete() -> Signal<T, E> {
        return Signal<T, E> { subscriber in
            subscriber.putCompletion()
            
            return EmptyDisposable
        }
    }
}
