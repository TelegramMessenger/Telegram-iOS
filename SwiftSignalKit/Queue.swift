import Foundation

private let _QueueSpecificKey = NSObject()
private let QueueSpecificKey: UnsafePointer<Void> = UnsafePointer<Void>(Unmanaged<AnyObject>.passUnretained(_QueueSpecificKey).toOpaque())

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
        return Queue(queue: dispatch_get_main_queue(), specialIsMainQueue: true)
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
}
