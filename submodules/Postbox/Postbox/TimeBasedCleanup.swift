import Foundation
#if os(macOS)
import SwiftSignalKitMac
#else
import SwiftSignalKit
#endif

#if os(macOS)
private typealias SignalKitTimer = SwiftSignalKitMac.Timer
#else
private typealias SignalKitTimer = SwiftSignalKit.Timer
#endif

private func scanFiles(at path: String, olderThan minTimestamp: Int32, _ f: (String) -> Void) {
    guard let enumerator = FileManager.default.enumerator(at: URL(fileURLWithPath: path), includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey], options: [.skipsSubdirectoryDescendants], errorHandler: nil) else {
        return
    }
    while let item = enumerator.nextObject() {
        guard let url = item as? NSURL else {
            continue
        }
        guard let resourceValues = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isDirectoryKey]) else {
            continue
        }
        if let value = resourceValues[.isDirectoryKey] as? Bool, value {
            continue
        }
        if let value = resourceValues[.contentModificationDateKey] as? NSDate {
            if Int32(value.timeIntervalSince1970) < minTimestamp {
                if let file = url.path {
                    f(file)
                }
            }
        }
    }
}

private final class TimeBasedCleanupImpl {
    private let queue: Queue
    private let paths: [String]
    
    private var scheduledTouches: [String] = []
    private var scheduledTouchesTimer: SignalKitTimer?
    
    private var maxStoreTime: Int32?
    private let scheduledScanDisposable = MetaDisposable()
    
    init(queue: Queue, paths: [String]) {
        self.queue = queue
        self.paths = paths
    }
    
    deinit {
        assert(self.queue.isCurrent())
        self.scheduledTouchesTimer?.invalidate()
        self.scheduledScanDisposable.dispose()
    }
    
    public func setMaxStoreTime(_ maxStoreTime: Int32) {
        if self.maxStoreTime != maxStoreTime {
            self.maxStoreTime = maxStoreTime
            self.resetScan(maxStoreTime: maxStoreTime)
        }
    }
    
    private func resetScan(maxStoreTime: Int32) {
        let paths = self.paths
        let scanOnce = Signal<Never, NoError> { subscriber in
            DispatchQueue.global(qos: .utility).async {
                var removedCount: Int = 0
                let timestamp = Int32(Date().timeIntervalSince1970)
                let oldestTimestamp = timestamp - maxStoreTime
                for path in paths {
                    scanFiles(at: path, olderThan: oldestTimestamp, { file in
                        removedCount += 1
                        unlink(file)
                    })
                }
                if removedCount != 0 {
                    print("[TimeBasedCleanup] removed \(removedCount) files")
                }
                subscriber.putCompletion()
            }
            return EmptyDisposable
        }
        let scanFirstTime = scanOnce
        |> delay(10.0, queue: Queue.concurrentDefaultQueue())
        let scanRepeatedly = (
            scanOnce
            |> suspendAwareDelay(60.0 * 60.0, granularity: 10.0, queue: Queue.concurrentDefaultQueue())
        )
        |> restart
        let scan = scanFirstTime
        |> then(scanRepeatedly)
        self.scheduledScanDisposable.set((scan
        |> deliverOn(self.queue)).start())
    }
    
    func touch(paths: [String]) {
        self.scheduledTouches.append(contentsOf: paths)
        self.scheduleTouches()
    }
    
    private func scheduleTouches() {
        if self.scheduledTouchesTimer == nil {
            let timer = SignalKitTimer(timeout: 10.0, repeat: false, completion: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.scheduledTouchesTimer = nil
                strongSelf.processScheduledTouches()
            }, queue: self.queue)
            self.scheduledTouchesTimer = timer
            timer.start()
        }
    }
    
    private func processScheduledTouches() {
        let scheduledTouches = self.scheduledTouches
        DispatchQueue.global(qos: .utility).async {
            for item in Set(scheduledTouches) {
                utime(item, nil)
            }
        }
        self.scheduledTouches = []
    }
}

final class TimeBasedCleanup {
    private let queue = Queue()
    private let impl: QueueLocalObject<TimeBasedCleanupImpl>
    
    init(paths: [String]) {
        let queue = self.queue
        self.impl = QueueLocalObject(queue: self.queue, generate: {
            return TimeBasedCleanupImpl(queue: queue, paths: paths)
        })
    }
    
    func touch(paths: [String]) {
        self.impl.with { impl in
            impl.touch(paths: paths)
        }
    }
    
    func setMaxStoreTime(_ maxStoreTime: Int32) {
        self.impl.with { impl in
            impl.setMaxStoreTime(maxStoreTime)
        }
    }
}
