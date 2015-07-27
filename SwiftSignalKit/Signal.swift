import Foundation

internal let doNothing: () -> Void = { _ in }

public typealias NoError = Void

public func identity<A>(a: A) -> A {
    return a;
}

infix operator |> { associativity left precedence 95 }

public func |> <T, U>(value: T, function: (T -> U)) -> U {
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

public struct Signal<T, E> {
    private let generator: Subscriber<T, E> -> Disposable
    
    public init(_ generator: Subscriber<T, E> -> Disposable) {
        self.generator = generator
    }
    
    public func start(next next: (T -> Void)! = nil, error: (E -> Void)! = nil, completed: (() -> Void)! = nil) -> Disposable {
        let subscriber = Subscriber<T, E>(next: next, error: error, completed: completed)
        let disposable = self.generator(subscriber)
        subscriber.assignDisposable(disposable)
        return SubscriberDisposable(subscriber: subscriber, disposable: disposable)
    }
}
