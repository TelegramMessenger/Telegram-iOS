import Foundation

private let _QueueSpecificKey = NSObject()
private let QueueSpecificKey: UnsafePointer<Void> = UnsafePointer<Void>(Unmanaged<AnyObject>.passUnretained(_QueueSpecificKey).toOpaque())

private let globalMainQueue = Queue(queue: dispatch_get_main_queue(), specialIsMainQueue: true)

public final class Queue {
    private let nativeQueue: dispatch_queue_t
    private var specific: UnsafeMutablePointer<Void>
    private let specialIsMainQueue: Bool
    
    public var queue: dispatch_queue_t {
        get {
            return self.nativeQueue
        }
    }
    
    public class func mainQueue() -> Queue {
        return globalMainQueue
    }
    
    public class func concurrentDefaultQueue() -> Queue {
        return Queue(queue: dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), specialIsMainQueue: false)
    }
    
    public class func concurrentBackgroundQueue() -> Queue {
        return Queue(queue: dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), specialIsMainQueue: false)
    }
    
    public init(queue: dispatch_queue_t) {
        self.nativeQueue = queue
        self.specific = nil
        self.specialIsMainQueue = false
    }
    
    private init(queue: dispatch_queue_t, specialIsMainQueue: Bool) {
        self.nativeQueue = queue
        self.specific = nil
        self.specialIsMainQueue = specialIsMainQueue
    }
    
    public init(name: String? = nil) {
        if let name = name {
            self.nativeQueue = dispatch_queue_create(name, DISPATCH_QUEUE_SERIAL)
        } else {
            self.nativeQueue = dispatch_queue_create(nil, DISPATCH_QUEUE_SERIAL)
        }
        self.specific = nil
        self.specialIsMainQueue = false
        
        self.specific = UnsafeMutablePointer<Void>(Unmanaged<Queue>.passUnretained(self).toOpaque())
        dispatch_queue_set_specific(self.nativeQueue, QueueSpecificKey, self.specific, nil)
        dispatch_set_target_queue(self.nativeQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0))
    }
    
    func isCurrent() -> Bool {
        if self.specific != nil && dispatch_get_specific(QueueSpecificKey) == self.specific {
            return true
        } else if self.specialIsMainQueue && NSThread.isMainThread() {
            return true
        } else {
            return false
        }
    }
    
    public func async(f: Void -> Void) {
        if self.specific != nil && dispatch_get_specific(QueueSpecificKey) == self.specific {
            f()
        } else if self.specialIsMainQueue && NSThread.isMainThread() {
            f()
        } else {
            dispatch_async(self.nativeQueue, f)
        }
    }
    
    public func sync(f: Void -> Void) {
        if self.specific != nil && dispatch_get_specific(QueueSpecificKey) == self.specific {
            f()
        } else if self.specialIsMainQueue && NSThread.isMainThread() {
            f()
        } else {
            dispatch_sync(self.nativeQueue, f)
        }
    }
    
    public func dispatch(f: Void -> Void) {
        if self.specific != nil && dispatch_get_specific(QueueSpecificKey) == self.specific {
            f()
        } else if self.specialIsMainQueue && NSThread.isMainThread() {
            f()
        } else {
            dispatch_async(self.nativeQueue, f)
        }
    }
    
    public func justDispatch(f: Void -> Void) {
        dispatch_async(self.nativeQueue, f)
    }
    
    public func dispatchWithHighQoS(f: () -> Void) {
        let block = dispatch_block_create_with_qos_class(DISPATCH_BLOCK_ENFORCE_QOS_CLASS, QOS_CLASS_USER_INTERACTIVE, 0, {
            f()
        })
        dispatch_async(self.nativeQueue, block)
    }
    
    public func dispatchTiming(f: Void -> Void, _ file: String = #file, _ line: Int = #line) {
        self.justDispatch {
            let startTime = CFAbsoluteTimeGetCurrent()
            f()
            let delta = CFAbsoluteTimeGetCurrent() - startTime
            if delta > 0.002 {
                print("dispatchTiming \(delta * 1000.0) ms \(file):\(line)")
            }
        }
    }
    
    public func after(delay: Double, _ f: Void -> Void) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(delay * Double(NSEC_PER_SEC))), self.queue, f)
    }
}
