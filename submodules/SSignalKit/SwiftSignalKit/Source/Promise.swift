import Foundation

public final class Promise<T> {
    private var initializeOnFirstAccess: Signal<T, NoError>?
    private var value: T?
    private let lock = createOSUnfairLock()
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
        self.lock.lock()
        self.value = nil
        self.lock.unlock()

        self.disposable.set(signal.start(next: { [weak self] next in
            if let strongSelf = self {
                strongSelf.lock.lock()
                strongSelf.value = next
                let subscribers = strongSelf.subscribers.copyItems()
                strongSelf.lock.unlock()
                
                for subscriber in subscribers {
                    subscriber(next)
                }
            }
        }))
    }

    public func get() -> Signal<T, NoError> {
        return Signal { subscriber in
            self.lock.lock()
            var initializeOnFirstAccessNow: Signal<T, NoError>?
            if let initializeOnFirstAccess = self.initializeOnFirstAccess {
                initializeOnFirstAccessNow = initializeOnFirstAccess
                self.initializeOnFirstAccess = nil
            }
            let currentValue = self.value
            let index = self.subscribers.add({ next in
                subscriber.putNext(next)
            })
            self.lock.unlock()

            if let currentValue = currentValue {
                subscriber.putNext(currentValue)
            }
            
            if let initializeOnFirstAccessNow = initializeOnFirstAccessNow {
                self.set(initializeOnFirstAccessNow)
            }

            return ActionDisposable {
                self.lock.lock()
                self.subscribers.remove(index)
                self.lock.unlock()
            }
        }
    }
}

public final class ValuePromise<T: Equatable> {
    private var value: T?
    private let lock = createOSUnfairLock()
    private let subscribers = Bag<(T) -> Void>()
    public let ignoreRepeated: Bool
    
    public init(_ value: T, ignoreRepeated: Bool = false) {
        self.value = value
        self.ignoreRepeated = ignoreRepeated
    }
    
    public init(ignoreRepeated: Bool = false) {
        self.ignoreRepeated = ignoreRepeated
    }
    
    deinit {
    }
    
    public func set(_ value: T) {
        self.lock.lock()
        let subscribers: [(T) -> Void]
        if !self.ignoreRepeated || self.value != value {
            self.value = value
            subscribers = self.subscribers.copyItems()
        } else {
            subscribers = []
        }
        self.lock.unlock()
        
        for subscriber in subscribers {
            subscriber(value)
        }
    }
    
    public func get() -> Signal<T, NoError> {
        return Signal { subscriber in
            self.lock.lock()
            let currentValue = self.value
            let index = self.subscribers.add({ next in
                subscriber.putNext(next)
            })
            self.lock.unlock()
            
            if let currentValue = currentValue {
                subscriber.putNext(currentValue)
            }
            
            return ActionDisposable {
                self.lock.lock()
                self.subscribers.remove(index)
                self.lock.unlock()
            }
        }
    }
}
