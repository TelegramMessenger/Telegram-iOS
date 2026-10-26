import Foundation

public final class ValuePipe<T> {
    private var lock = os_unfair_lock()
    private let subscribers = Bag<(T) -> Void>()
    
    public init() {
    }
    
    public func signal() -> Signal<T, NoError> {
        return Signal { [weak self] subscriber in
            if let strongSelf = self {
                os_unfair_lock_lock(&strongSelf.lock)
                let index = strongSelf.subscribers.add { next in
                    subscriber.putNext(next)
                }
                os_unfair_lock_unlock(&strongSelf.lock)
                
                return ActionDisposable { [weak strongSelf] in
                    if let strongSelf = strongSelf {
                        strongSelf.removeSubscriber(index)
                    }
                }
            } else {
                return EmptyDisposable
            }
        }
    }
    
    private func removeSubscriber(_ index: Bag<(T) -> Void>.Index) {
        os_unfair_lock_lock(&self.lock)
        let item = self.subscribers.get(index)
        self.subscribers.remove(index)
        os_unfair_lock_unlock(&self.lock)
        
        withExtendedLifetime(item, {})
    }
    
    public func putNext(_ next: T) {
        os_unfair_lock_lock(&self.lock)
        let items = self.subscribers.copyItems()
        os_unfair_lock_unlock(&self.lock)
        
        for f in items {
            f(next)
        }
    }
}
