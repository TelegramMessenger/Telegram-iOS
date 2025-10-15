import Foundation

public final class ThreadPoolTaskState {
    public let cancelled = Atomic<Bool>(value: false)
}

public final class ThreadPoolTask {
    private let state = ThreadPoolTaskState()
    private let action: (ThreadPoolTaskState) -> ()
    
    public init(_ action: @escaping(ThreadPoolTaskState) -> ()) {
        self.action = action
    }
    
    public func execute() {
        if !state.cancelled.with({ $0 })  {
            self.action(self.state)
        }
    }
    
    public func cancel() {
        let _ = self.state.cancelled.swap(true)
    }
}

public final class ThreadPoolQueue : Equatable {
    private weak var threadPool: ThreadPool?
    private var tasks: [ThreadPoolTask] = []
    
    public init(threadPool: ThreadPool) {
        self.threadPool = threadPool
    }
    
    public func addTask(_ task: ThreadPoolTask) {
        if let threadPool = self.threadPool {
            threadPool.workOnQueue(self, action: {
                self.tasks.append(task)
            })
        }
    }
    
    fileprivate func popFirstTask() -> ThreadPoolTask? {
        if self.tasks.count != 0 {
            let task = self.tasks[0];
            self.tasks.remove(at: 0)
            return task
        } else {
            return nil
        }
    }
    
    fileprivate func hasTasks() -> Bool {
        return self.tasks.count != 0
    }
}

public func ==(lhs: ThreadPoolQueue, rhs: ThreadPoolQueue) -> Bool {
    return lhs === rhs
}

@objc public final class ThreadPool: NSObject {
    private var threads: [Thread] = []
    private var queues: [ThreadPoolQueue] = []
    private var takenQueues: [ThreadPoolQueue] = []
    private var mutex: pthread_mutex_t
    private var condition: pthread_cond_t
    
    @objc class func threadEntryPoint(_ threadPool: ThreadPool) {
        var queue: ThreadPoolQueue!
        
        while (true) {
            var task: ThreadPoolTask!
            
            pthread_mutex_lock(&threadPool.mutex);
            
            if queue != nil {
                if let index = threadPool.takenQueues.firstIndex(of: queue) {
                    threadPool.takenQueues.remove(at: index)
                }
                
                if queue.hasTasks() {
                    threadPool.queues.append(queue);
                }
            }
            
            while (true)
            {
                while threadPool.queues.count == 0 {
                    pthread_cond_wait(&threadPool.condition, &threadPool.mutex);
                }
                
                if threadPool.queues.count != 0 {
                    queue = threadPool.queues[0]
                }
                
                if queue != nil {
                    task = queue.popFirstTask()
                    threadPool.takenQueues.append(queue)
                    
                    if let index = threadPool.queues.firstIndex(of: queue) {
                        threadPool.queues.remove(at: index)
                    }
                    
                    break
                }
            }
            pthread_mutex_unlock(&threadPool.mutex);
            
            if task != nil {
                autoreleasepool {
                    task.execute()
                }
            }
        }
    }
    
    public init(threadCount: Int, threadPriority: Double) {
        assert(threadCount > 0, "threadCount < 0")
        
        self.mutex = pthread_mutex_t()
        self.condition = pthread_cond_t()
        pthread_mutex_init(&self.mutex, nil)
        pthread_cond_init(&self.condition, nil)
        
        super.init()
        
        for _ in 0 ..< threadCount {
            let thread = Thread(target: ThreadPool.self, selector: #selector(ThreadPool.threadEntryPoint(_:)), object: self)
            thread.threadPriority = threadPriority
            self.threads.append(thread)
            thread.start()
        }
    }
    
    deinit {
        pthread_mutex_destroy(&self.mutex)
        pthread_cond_destroy(&self.condition)
    }
    
    public func addTask(_ task: ThreadPoolTask) {
        let tempQueue = self.nextQueue()
        tempQueue.addTask(task)
    }
    
    fileprivate func workOnQueue(_ queue: ThreadPoolQueue, action: () -> ()) {
        pthread_mutex_lock(&self.mutex)
        action()
        if !self.queues.contains(queue) && !self.takenQueues.contains(queue) {
            self.queues.append(queue)
        }
        pthread_cond_broadcast(&self.condition)
        pthread_mutex_unlock(&self.mutex)
    }
    
    public func nextQueue() -> ThreadPoolQueue {
        return ThreadPoolQueue(threadPool: self)
    }
    
    public func isCurrentThreadInPool() -> Bool {
        let currentThread = Thread.current
        for thread in self.threads {
            if currentThread.isEqual(thread) {
                return true
            }
        }
        return false
    }
}
