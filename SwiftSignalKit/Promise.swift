import Foundation

public final class Promise<T> {
    private var value: T?
    private var lock: OSSpinLock = 0
    private let disposable = MetaDisposable()
    private let subscribers = Bag<(T) -> Void>()
    
    public init(_ value: T) {
        self.value = value
    }
    
    public init() {
    }

    deinit {
        self.disposable.dispose()
    }
    
    public func set(_ signal: Signal<T, NoError>) {
        OSSpinLockLock(&self.lock)
        self.value = nil
        OSSpinLockUnlock(&self.lock)

        self.disposable.set(signal.start(next: { [weak self] next in
            if let strongSelf = self {
                OSSpinLockLock(&strongSelf.lock)
                strongSelf.value = next
                let subscribers = strongSelf.subscribers.copyItems()
                OSSpinLockUnlock(&strongSelf.lock);
                
                for subscriber in subscribers {
                    subscriber(next)
                }
            }
        }))
    }

    public func get() -> Signal<T, NoError> {
        return Signal { subscriber in
            OSSpinLockLock(&self.lock)
            let currentValue = self.value
            let index = self.subscribers.add({ next in
                subscriber.putNext(next)
            })
            OSSpinLockUnlock(&self.lock)
            

            if let currentValue = currentValue {
                subscriber.putNext(currentValue)
            }

            return ActionDisposable {
                OSSpinLockLock(&self.lock)
                self.subscribers.remove(index)
                OSSpinLockUnlock(&self.lock)
            }
        }
    }
}

public final class ValuePromise<T: Equatable> {
    private var value: T?
    private var lock: OSSpinLock = 0
    private let subscribers = Bag<(T) -> Void>()
    public let ignoreRepeated: Bool
    
    public init(_ value: T, ignoreRepeated: Bool = false) {
        self.value = value
        self.ignoreRepeated = ignoreRepeated
    }
    
    public init(ignoreRepeated: Bool = false) {
        self.ignoreRepeated = ignoreRepeated
    }
    
    public func set(_ value: T) {
        OSSpinLockLock(&self.lock)
        let subscribers: [(T) -> Void]
        if !self.ignoreRepeated || self.value != value {
            self.value = value
            subscribers = self.subscribers.copyItems()
        } else {
            subscribers = []
        }
        OSSpinLockUnlock(&self.lock);
        
        for subscriber in subscribers {
            subscriber(value)
        }
    }
    
    public func get() -> Signal<T, NoError> {
        return Signal { subscriber in
            OSSpinLockLock(&self.lock)
            let currentValue = self.value
            let index = self.subscribers.add({ next in
                subscriber.putNext(next)
            })
            OSSpinLockUnlock(&self.lock)
            
            
            if let currentValue = currentValue {
                subscriber.putNext(currentValue)
            }
            
            return ActionDisposable {
                OSSpinLockLock(&self.lock)
                self.subscribers.remove(index)
                OSSpinLockUnlock(&self.lock)
            }
        }
    }
}
