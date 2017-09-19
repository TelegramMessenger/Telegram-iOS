import Foundation

public final class Timer {
    private let timer = Atomic<DispatchSourceTimer?>(value: nil)
    private let timeout: Double
    private let `repeat`: Bool
    private let completion: () -> Void
    private let queue: Queue
    
    public init(timeout: Double, `repeat`: Bool, completion: @escaping() -> Void, queue: Queue) {
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
        self.timer.modify { _ in
            return timer
        }
        
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
        self.timer.modify { timer in
            timer?.cancel()
            return nil
        }
    }
}
