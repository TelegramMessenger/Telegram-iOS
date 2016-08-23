import Foundation

public final class Timer {
    private var timer: DispatchSourceTimer?
    private var timeout: Double
    private var `repeat`: Bool
    private var completion: (Void) -> Void
    private var queue: Queue
    
    public init(timeout: Double, `repeat`: Bool, completion: @escaping(Void) -> Void, queue: Queue) {
        self.timeout = timeout
        self.`repeat` = `repeat`
        self.completion = completion
        self.queue = queue
    }
    
    deinit {
        self.invalidate()
    }
    
    public func start() {
        let timer = DispatchSource.makeTimerSource(queue: self.queue.queue)
        timer.setEventHandler(handler: { [weak self] in
            if let strongSelf = self {
                strongSelf.completion()
                if !strongSelf.`repeat` {
                    strongSelf.invalidate()
                }
            }
        })
        self.timer = timer
        
        if self.`repeat` {
            let time: DispatchTime = DispatchTime.now() + self.timeout
            timer.scheduleRepeating(deadline: time, interval: self.timeout)
        } else {
            let time: DispatchTime = DispatchTime.now() + self.timeout
            timer.scheduleOneshot(deadline: time)
        }
        
        timer.resume()
    }
    
    public func invalidate() {
        if let timer = self.timer {
            timer.cancel()
            self.timer = nil
        }
    }
}
