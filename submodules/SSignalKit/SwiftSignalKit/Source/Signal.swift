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

private final class SubscriberDisposable<T, E>: Disposable, CustomStringConvertible {
    private weak var subscriber: Subscriber<T, E>?
    
    private var lock = pthread_mutex_t()
    private var disposable: Disposable?
    
    init(subscriber: Subscriber<T, E>, disposable: Disposable?) {
        self.subscriber = subscriber
        self.disposable = disposable
        
        pthread_mutex_init(&self.lock, nil)
    }
    
    deinit {
        pthread_mutex_destroy(&self.lock)
    }
    
    func dispose() {
        var subscriber: Subscriber<T, E>?
        
        var disposeItem: Disposable?
        pthread_mutex_lock(&self.lock)
        disposeItem = self.disposable
        subscriber = self.subscriber
        self.subscriber = nil
        self.disposable = nil
        pthread_mutex_unlock(&self.lock)
        
        disposeItem?.dispose()
        subscriber?.markTerminatedWithoutDisposal()
    }
    
    public var description: String {
        return "SubscriberDisposable { disposable: \(self.disposable == nil ? "nil" : "hasValue") }"
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
        let wrappedDisposable = subscriber.assignDisposable(disposable)
        return SubscriberDisposable(subscriber: subscriber, disposable: wrappedDisposable)
    }
    
    public func startStandalone(next: ((T) -> Void)! = nil, error: ((E) -> Void)! = nil, completed: (() -> Void)! = nil) -> Disposable {
        let subscriber = Subscriber<T, E>(next: next, error: error, completed: completed)
        let disposable = self.generator(subscriber)
        let wrappedDisposable = subscriber.assignDisposable(disposable)
        return SubscriberDisposable(subscriber: subscriber, disposable: wrappedDisposable)
    }
    
    public func startStrict(next: ((T) -> Void)! = nil, error: ((E) -> Void)! = nil, completed: (() -> Void)! = nil, file: String = #file, line: Int = #line) -> Disposable {
        let subscriber = Subscriber<T, E>(next: next, error: error, completed: completed)
        let disposable = self.generator(subscriber)
        let wrappedDisposable = subscriber.assignDisposable(disposable)
        return SubscriberDisposable(subscriber: subscriber, disposable: wrappedDisposable).strict(file: file, line: line)
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
