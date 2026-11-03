import Foundation

public final class Promise<T> {
    private var initializeOnFirstAccess: Signal<T, NoError>?
    private var value: T?
    private var lock = os_unfair_lock()
    private let disposable = MetaDisposable()
    private let subscribers = Bag<(T) -> Void>()
    
    public var onDeinit: (() -> Void)?
    
    public init(initializeOnFirstAccess: Signal<T, NoError>?) {
        self.initializeOnFirstAccess = initializeOnFirstAccess
    }
    
    public init(_ value: T) {
        self.value = value
    }
    
    public init() {
    }

    deinit {
        self.onDeinit?()
        self.disposable.dispose()
    }
    
    public func set(_ signal: Signal<T, NoError>) {
        os_unfair_lock_lock(&self.lock)
        var previousValue = self.value
        self.value = nil
        os_unfair_lock_unlock(&self.lock)
        if previousValue != nil {
            previousValue = nil
        }

        self.disposable.set(signal.start(next: { [weak self] next in
            if let strongSelf = self {
                os_unfair_lock_lock(&strongSelf.lock)
                var previousValue = strongSelf.value
                strongSelf.value = next
                let subscribers = strongSelf.subscribers.copyItems()
                os_unfair_lock_unlock(&strongSelf.lock)
                if previousValue != nil {
                    previousValue = nil
                }
                
                for subscriber in subscribers {
                    subscriber(next)
                }
            }
        }))
    }

    public func get() -> Signal<T, NoError> {
        return Signal { subscriber in
            os_unfair_lock_lock(&self.lock)
            var initializeOnFirstAccessNow: Signal<T, NoError>?
            if let initializeOnFirstAccess = self.initializeOnFirstAccess {
                initializeOnFirstAccessNow = initializeOnFirstAccess
                self.initializeOnFirstAccess = nil
            }
            let currentValue = self.value
            let index = self.subscribers.add({ next in
                subscriber.putNext(next)
            })
            os_unfair_lock_unlock(&self.lock)

            if let currentValue = currentValue {
                subscriber.putNext(currentValue)
            }
            
            if let initializeOnFirstAccessNow = initializeOnFirstAccessNow {
                self.set(initializeOnFirstAccessNow)
            }

            return ActionDisposable {
                os_unfair_lock_lock(&self.lock)
                let item = self.subscribers.get(index)
                self.subscribers.remove(index)
                os_unfair_lock_unlock(&self.lock)
                withExtendedLifetime(item, {})
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
        var previousValue: T?
        if !self.ignoreRepeated || self.value != value {
            previousValue = self.value
            self.value = value
            subscribers = self.subscribers.copyItems()
        } else {
            subscribers = []
        }
        pthread_mutex_unlock(&self.lock);
        if previousValue != nil {
            previousValue = nil
        }
        
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
                let item = self.subscribers.get(index)
                self.subscribers.remove(index)
                pthread_mutex_unlock(&self.lock)
                withExtendedLifetime(item, {})
            }
        }
    }
}
