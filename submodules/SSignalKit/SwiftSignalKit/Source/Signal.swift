import Foundation

let doNothing: () -> Void = { }

public enum NoValue {
}

public enum NoError {
}

public func identity<A>(a: A) -> A {
    return a
}

precedencegroup PipeRight {
    associativity: left
    higherThan: DefaultPrecedence
}

infix operator |> : PipeRight

public func |> <T, U>(value: T, function: ((T) -> U)) -> U {
    return function(value)
}

private final class SubscriberDisposable<T, E> : Disposable {
    private let subscriber: Subscriber<T, E>
    private let disposable: Disposable
    
    init(subscriber: Subscriber<T, E>, disposable: Disposable) {
        self.subscriber = subscriber
        self.disposable = disposable
    }
    
    func dispose() {
        subscriber.markTerminatedWithoutDisposal()
        disposable.dispose()
    }
}

public final class Signal<T, E> {
    private let generator: (Subscriber<T, E>) -> Disposable
    
    public init(_ generator: @escaping(Subscriber<T, E>) -> Disposable) {
        self.generator = generator
    }
    
    public func start(next: ((T) -> Void)! = nil, error: ((E) -> Void)! = nil, completed: (() -> Void)! = nil) -> Disposable {
        let subscriber = Subscriber<T, E>(next: next, error: error, completed: completed)
        let disposable = self.generator(subscriber)
        subscriber.assignDisposable(disposable)
        return SubscriberDisposable(subscriber: subscriber, disposable: disposable)
    }
    
    public static func single(_ value: T) -> Signal<T, E> {
        return Signal<T, E> { subscriber in
            subscriber.putNext(value)
            subscriber.putCompletion()
            
            return EmptyDisposable
        }
    }
    
    public static func complete() -> Signal<T, E> {
        return Signal<T, E> { subscriber in
            subscriber.putCompletion()
            
            return EmptyDisposable
        }
    }
    
    public static func fail(_ error: E) -> Signal<T, E> {
        return Signal<T, E> { subscriber in
            subscriber.putError(error)
            
            return EmptyDisposable
        }
    }
    
    public static func never() -> Signal<T, E> {
        return Signal<T, E> { _ in
            return EmptyDisposable
        }
    }
}
