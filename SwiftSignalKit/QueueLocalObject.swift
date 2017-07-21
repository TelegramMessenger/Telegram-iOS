import Foundation

public final class QueueLocalObject<T: AnyObject> {
    private let queue: Queue
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
    
    public func with(_ f: @escaping (T) -> Void) {
        self.queue.async {
            if let valueRef = self.valueRef {
                let value = valueRef.takeUnretainedValue()
                f(value)
            }
        }
    }
}
