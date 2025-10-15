import Foundation

private let QueueSpecificKey = DispatchSpecificKey<NSObject>()

private let globalMainQueue = Queue(queue: DispatchQueue.main, specialIsMainQueue: true)
private let globalDefaultQueue = Queue(queue: DispatchQueue.global(qos: .default), specialIsMainQueue: false)
private let globalBackgroundQueue = Queue(queue: DispatchQueue.global(qos: .background), specialIsMainQueue: false)

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
        return globalDefaultQueue
    }
    
    public class func concurrentBackgroundQueue() -> Queue {
        return globalBackgroundQueue
    }
    
    public init(queue: DispatchQueue) {
        self.nativeQueue = queue
        self.specialIsMainQueue = false
    }
    
    fileprivate init(queue: DispatchQueue, specialIsMainQueue: Bool) {
        self.nativeQueue = queue
        self.specialIsMainQueue = specialIsMainQueue
    }
    
    public init(name: String? = nil, qos: DispatchQoS = .default) {
        self.nativeQueue = DispatchQueue(label: name ?? "", qos: qos)
        
        self.specialIsMainQueue = false
        
        self.nativeQueue.setSpecific(key: QueueSpecificKey, value: self.specific)
    }
    
    public func isCurrent() -> Bool {
        if DispatchQueue.getSpecific(key: QueueSpecificKey) === self.specific {
            return true
        } else if self.specialIsMainQueue && Thread.isMainThread {
            return true
        } else {
            return false
        }
    }
    
    public func async(_ f: @escaping () -> Void) {
        if self.isCurrent() {
            f()
        } else {
            self.nativeQueue.async(execute: f)
        }
    }
    
    public func sync(_ f: () -> Void) {
        if self.isCurrent() {
            f()
        } else {
            self.nativeQueue.sync(execute: f)
        }
    }
    
    public func justDispatch(_ f: @escaping () -> Void) {
        self.nativeQueue.async(execute: f)
    }
    
    public func justDispatchWithQoS(qos: DispatchQoS, _ f: @escaping () -> Void) {
        self.nativeQueue.async(group: nil, qos: qos, flags: [.enforceQoS], execute: f)
    }
    
    public func after(_ delay: Double, _ f: @escaping() -> Void) {
        let time: DispatchTime = DispatchTime.now() + delay
        self.nativeQueue.asyncAfter(deadline: time, execute: f)
    }
}
