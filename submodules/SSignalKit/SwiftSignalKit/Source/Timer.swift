import Foundation

public final class Timer {
    private let timer = Atomic<DispatchSourceTimer?>(value: nil)
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
        let _ = self.timer.modify { _ in
            return timer
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
        let _ = self.timer.modify { timer in
            timer?.cancel()
            return nil
        }
    }
}
