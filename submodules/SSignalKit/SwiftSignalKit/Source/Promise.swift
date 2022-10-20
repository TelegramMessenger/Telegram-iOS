import Foundation

public final class Promise<T> {
    private var initializeOnFirstAccess: Signal<T, NoError>?
    private var value: T?
    private var lock = pthread_mutex_t()
    private let disposable = MetaDisposable()
    private let subscribers = Bag<(T) -> Void>()
    
    public var onDeinit: (() -> Void)?
    
    public init(initializeOnFirstAccess: Signal<T, NoError>?) {
        self.initializeOnFirstAccess = initializeOnFirstAccess
        pthread_mutex_init(&self.lock, nil)
    }
    
    public init(_ value: T) {
        self.value = value
        pthread_mutex_init(&self.lock, nil)
    }
    
    public init() {
        pthread_mutex_init(&self.lock, nil)
    }

    deinit {
        self.onDeinit?()
        pthread_mutex_destroy(&self.lock)
        self.disposable.dispose()
    }
    
    public func set(_ signal: Signal<T, NoError>) {
        pthread_mutex_lock(&self.lock)
        self.value = nil
        pthread_mutex_unlock(&self.lock)

        self.disposable.set(signal.start(next: { [weak self] next in
            if let strongSelf = self {
                pthread_mutex_lock(&strongSelf.lock)
                strongSelf.value = next
                let subscribers = strongSelf.subscribers.copyItems()
                pthread_mutex_unlock(&strongSelf.lock)
                
                for subscriber in subscribers {
                    subscriber(next)
                }
            }
        }))
    }

    public func get() -> Signal<T, NoError> {
        return Signal { subscriber in
            pthread_mutex_lock(&self.lock)
            var initializeOnFirstAccessNow: Signal<T, NoError>?
            if let initializeOnFirstAccess = self.initializeOnFirstAccess {
                initializeOnFirstAccessNow = initializeOnFirstAccess
                self.initializeOnFirstAccess = nil
            }
            let currentValue = self.value
            let index = self.subscribers.add({ next in
                subscriber.putNext(next)
            })
            pthread_mutex_unlock(&self.lock)

            if let currentValue = currentValue {
                subscriber.putNext(currentValue)
            }
            
            if let initializeOnFirstAccessNow = initializeOnFirstAccessNow {
                self.set(initializeOnFirstAccessNow)
            }

            return ActionDisposable {
                pthread_mutex_lock(&self.lock)
                self.subscribers.remove(index)
                pthread_mutex_unlock(&self.lock)
            }
        }
    }
}

public final class ValuePromise<T: Equatable> {
    private var value: T?
    private var lock = pthread_mutex_t()
    private let subscribers = Bag<(T) -> Void>()
    public let ignoreRepeated: Bool
    
    public init(_ value: T, ignoreRepeated: Bool = false) {
        self.value = value
        self.ignoreRepeated = ignoreRepeated
        pthread_mutex_init(&self.lock, nil)
    }
    
    public init(ignoreRepeated: Bool = false) {
        self.ignoreRepeated = ignoreRepeated
        pthread_mutex_init(&self.lock, nil)
    }
    
    deinit {
        pthread_mutex_destroy(&self.lock)
    }
    
    public func set(_ value: T) {
        pthread_mutex_lock(&self.lock)
        let subscribers: [(T) -> Void]
        if !self.ignoreRepeated || self.value != value {
            self.value = value
            subscribers = self.subscribers.copyItems()
        } else {
            subscribers = []
        }
        pthread_mutex_unlock(&self.lock);
        
        for subscriber in subscribers {
            subscriber(value)
        }
    }
    
    public func get() -> Signal<T, NoError> {
        return Signal { subscriber in
            pthread_mutex_lock(&self.lock)
            let currentValue = self.value
            let index = self.subscribers.add({ next in
                subscriber.putNext(next)
            })
            pthread_mutex_unlock(&self.lock)
            
            if let currentValue = currentValue {
                subscriber.putNext(currentValue)
            }
            
            return ActionDisposable {
                pthread_mutex_lock(&self.lock)
                self.subscribers.remove(index)
                pthread_mutex_unlock(&self.lock)
            }
        }
    }
}
