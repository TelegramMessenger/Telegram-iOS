import Foundation

public final class QueueLocalObject<T: AnyObject> {
    public let queue: Queue
    private var valueRef: Unmanaged<T>?
    
    public init(queue: Queue, generate: @escaping () -> T) {
        self.queue = queue
        
        self.queue.async {
            let value = generate()
            self.valueRef = Unmanaged.passRetained(value)
        }
    }
    
    deinit {
        let valueRef = self.valueRef
        self.queue.async {
            valueRef?.release()
        }
    }
    
    public func unsafeGet() -> T? {
        assert(self.queue.isCurrent())
        return self.valueRef?.takeUnretainedValue()
    }
    
    public func with(_ f: @escaping (T) -> Void) {
        self.queue.async {
            if let valueRef = self.valueRef {
                let value = valueRef.takeUnretainedValue()
                f(value)
            }
        }
    }
    
    public func syncWith<R>(_ f: @escaping (T) -> R) -> R {
        var result: R?
        self.queue.sync {
            if let valueRef = self.valueRef {
                let value = valueRef.takeUnretainedValue()
                result = f(value)
            }
        }
        return result!
    }
    
    public func signalWith<R, E>(_ f: @escaping (T, Subscriber<R, E>) -> Disposable) -> Signal<R, E> {
        return Signal { [weak self] subscriber in
            if let strongSelf = self, let valueRef = strongSelf.valueRef {
                let value = valueRef.takeUnretainedValue()
                return f(value, subscriber)
            } else {
                return EmptyDisposable
            }
        } |> runOn(self.queue)
    }
}
