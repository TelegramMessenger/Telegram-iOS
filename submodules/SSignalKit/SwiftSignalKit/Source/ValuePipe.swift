import Foundation

public final class ValuePipe<T> {
    private let subscribers = Atomic(value: Bag<(T) -> Void>())
    
    public init() {
    }
    
    public func signal() -> Signal<T, NoError> {
        return Signal { [weak self] subscriber in
            if let strongSelf = self {
                let index = strongSelf.subscribers.with { value -> Bag<T>.Index in
                    return value.add { next in
                        subscriber.putNext(next)
                    }
                }
                
                return ActionDisposable { [weak strongSelf] in
                    if let strongSelf = strongSelf {
                        strongSelf.subscribers.with { value -> Void in
                            value.remove(index)
                        }
                    }
                }
            } else {
                return EmptyDisposable
            }
        }
    }
    
    public func putNext(_ next: T) {
        let items = self.subscribers.with { value -> [(T) -> Void] in
            return value.copyItems()
        }
        for f in items {
            f(next)
        }
    }
}
