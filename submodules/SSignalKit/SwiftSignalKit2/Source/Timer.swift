import Foundation

public final class Timer {
    private var lock = os_unfair_lock()
    private var timer: DispatchSourceTimer?
    private let timeout: Double
    private let `repeat`: Bool
    private let completion: (Timer) -> Void
    private let queue: Queue
    
    public init(timeout: Double, `repeat`: Bool, completion: @escaping () -> Void, queue: Queue) {
        self.timeout = timeout
        self.`repeat` = `repeat`
        self.completion = { _ in
            completion()
        }
        self.queue = queue
    }
    
    public init(timeout: Double, `repeat`: Bool, completion: @escaping (Timer) -> Void, queue: Queue) {
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
                strongSelf.completion(strongSelf)
                if !strongSelf.`repeat` {
                    strongSelf.invalidate()
                }
            }
        })
        
        os_unfair_lock_lock(&self.lock)
        var previousTimer = self.timer
        self.timer = timer
        os_unfair_lock_unlock(&self.lock)
        
        if let previousTimerValue = previousTimer {
            previousTimer = nil
            previousTimerValue.cancel()
        }
        
        if self.`repeat` {
            let time: DispatchTime = DispatchTime.now() + self.timeout
            timer.schedule(deadline: time, repeating: self.timeout)
        } else {
            let time: DispatchTime = DispatchTime.now() + self.timeout
            timer.schedule(deadline: time)
        }
        
        timer.resume()
    }
    
    public func invalidate() {
        os_unfair_lock_lock(&self.lock)
        let timer = self.timer
        self.timer = nil
        os_unfair_lock_unlock(&self.lock)
        
        timer?.cancel()
    }
}
