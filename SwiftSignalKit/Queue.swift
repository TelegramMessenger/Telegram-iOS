import Foundation

private let QueueSpecificKey = DispatchSpecificKey<NSObject>()

private let globalMainQueue = Queue(queue: DispatchQueue.main, specialIsMainQueue: true)

public final class Queue {
    private let nativeQueue: DispatchQueue
    private var specific = NSObject()
    private let specialIsMainQueue: Bool
    
    public var queue: DispatchQueue {
        get {
            return self.nativeQueue
        }
    }
    
    public class func mainQueue() -> Queue {
        return globalMainQueue
    }
    
    public class func concurrentDefaultQueue() -> Queue {
        return Queue(queue: DispatchQueue.global(attributes: [.qosDefault]), specialIsMainQueue: false)
    }
    
    public class func concurrentBackgroundQueue() -> Queue {
        return Queue(queue: DispatchQueue.global(attributes: [.qosBackground]), specialIsMainQueue: false)
    }
    
    public init(queue: DispatchQueue) {
        self.nativeQueue = queue
        self.specialIsMainQueue = false
    }
    
    private init(queue: DispatchQueue, specialIsMainQueue: Bool) {
        self.nativeQueue = queue
        self.specialIsMainQueue = specialIsMainQueue
    }
    
    public init(name: String? = nil) {
        self.nativeQueue = DispatchQueue(label: name ?? "", attributes: [.serial], target: nil)
        
        self.specialIsMainQueue = false
        
        self.nativeQueue.setSpecific(key: QueueSpecificKey, value: self.specific)
    }
    
    func isCurrent() -> Bool {
        if DispatchQueue.getSpecific(key: QueueSpecificKey) === self.specific {
            return true
        } else if self.specialIsMainQueue && Thread.isMainThread() {
            return true
        } else {
            return false
        }
    }
    
    public func async(_ f: (Void) -> Void) {
        if self.isCurrent() {
            f()
        } else {
            self.nativeQueue.async(execute: f)
        }
    }
    
    public func sync(_ f: (Void) -> Void) {
        if self.isCurrent() {
            f()
        } else {
            self.nativeQueue.sync(execute: f)
        }
    }
    
    public func justDispatch(_ f: (Void) -> Void) {
        self.nativeQueue.async(execute: f)
    }
    
    public func after(_ delay: Double, _ f: (Void) -> Void) {
        let time: DispatchTime = DispatchTime.now() + Double(Int64(delay * Double(NSEC_PER_SEC)))
        self.nativeQueue.after(when: time, execute: f)
    }
}
