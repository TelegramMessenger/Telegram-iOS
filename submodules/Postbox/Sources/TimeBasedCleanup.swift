import Foundation
import SwiftSignalKit
private typealias SignalKitTimer = SwiftSignalKit.Timer


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
    private let generalPaths: [String]
    private let shortLivedPaths: [String]
    
    private var scheduledTouches: [String] = []
    private var scheduledTouchesTimer: SignalKitTimer?
    
    private var generalMaxStoreTime: Int32?
    private var shortLivedMaxStoreTime: Int32?
    private let scheduledScanDisposable = MetaDisposable()
    
    init(queue: Queue, generalPaths: [String], shortLivedPaths: [String]) {
        self.queue = queue
        self.generalPaths = generalPaths
        self.shortLivedPaths = shortLivedPaths
    }
    
    deinit {
        assert(self.queue.isCurrent())
        self.scheduledTouchesTimer?.invalidate()
        self.scheduledScanDisposable.dispose()
    }
    
    func setMaxStoreTimes(general: Int32, shortLived: Int32) {
        if self.generalMaxStoreTime != general || self.shortLivedMaxStoreTime != shortLived {
            self.generalMaxStoreTime = general
            self.shortLivedMaxStoreTime = shortLived
            self.resetScan(general: general, shortLived: shortLived)
        }
    }
    
    private func resetScan(general: Int32, shortLived: Int32) {
        let generalPaths = self.generalPaths
        let shortLivedPaths = self.shortLivedPaths
        let scanOnce = Signal<Never, NoError> { subscriber in
            DispatchQueue.global(qos: .utility).async {
                var removedShortLivedCount: Int = 0
                var removedGeneralCount: Int = 0
                let timestamp = Int32(Date().timeIntervalSince1970)
                let oldestShortLivedTimestamp = timestamp - shortLived
                let oldestGeneralTimestamp = timestamp - general
                for path in shortLivedPaths {
                    scanFiles(at: path, olderThan: oldestShortLivedTimestamp, { file in
                        removedShortLivedCount += 1
                        unlink(file)
                    })
                }
                for path in generalPaths {
                    scanFiles(at: path, olderThan: oldestGeneralTimestamp, { file in
                        removedGeneralCount += 1
                        unlink(file)
                    })
                }
                if removedShortLivedCount != 0 || removedGeneralCount != 0 {
                    print("[TimeBasedCleanup] removed \(removedShortLivedCount) short-lived files, \(removedGeneralCount) general files")
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
    
    init(generalPaths: [String], shortLivedPaths: [String]) {
        let queue = self.queue
        self.impl = QueueLocalObject(queue: self.queue, generate: {
            return TimeBasedCleanupImpl(queue: queue, generalPaths: generalPaths, shortLivedPaths: shortLivedPaths)
        })
    }
    
    func touch(paths: [String]) {
        self.impl.with { impl in
            impl.touch(paths: paths)
        }
    }
    
    func setMaxStoreTimes(general: Int32, shortLived: Int32) {
        self.impl.with { impl in
            impl.setMaxStoreTimes(general: general, shortLived: shortLived)
        }
    }
}
