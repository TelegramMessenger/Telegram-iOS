import Foundation

public class Promise<T> {
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
