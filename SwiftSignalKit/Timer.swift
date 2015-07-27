import Foundation

public final class Timer {
    private var timer: dispatch_source_t!
    private var timeout: NSTimeInterval
    private var `repeat`: Bool
    private var completion: Void -> Void
    private var queue: Queue
    
    public init(timeout: NSTimeInterval, `repeat`: Bool, completion: Void -> Void, queue: Queue) {
        self.timeout = timeout
        self.`repeat` = `repeat`
        self.completion = completion
        self.queue = queue
    }
    
    deinit {
        self.invalidate()
    }
    
    public func start() {
        self.timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.queue.queue)
        dispatch_source_set_timer(self.timer, dispatch_time(DISPATCH_TIME_NOW, Int64(self.timeout * NSTimeInterval(NSEC_PER_SEC))), self.`repeat` ? UInt64(self.timeout * NSTimeInterval(NSEC_PER_SEC)) : DISPATCH_TIME_FOREVER, 0);
        dispatch_source_set_event_handler(self.timer,  { [weak self] in
            if let strongSelf = self {
                strongSelf.completion()
                if !strongSelf.`repeat` {
                    strongSelf.invalidate()
                }
            }
        })
        dispatch_resume(self.timer)
    }
    
    public func invalidate() {
        if self.timer != nil {
            dispatch_source_cancel(self.timer)
            self.timer = nil
        }
    }
}
