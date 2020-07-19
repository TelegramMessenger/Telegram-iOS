import Foundation
import SwiftSignalKit
private typealias SignalKitTimer = SwiftSignalKit.Timer


private func scanFiles(at path: String, olderThan minTimestamp: Int32, anyway: ((String, Int, Int32)) -> Void, unlink f: (String) -> Void) {
    guard let enumerator = FileManager.default.enumerator(at: URL(fileURLWithPath: path), includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey, .fileSizeKey], options: [.skipsSubdirectoryDescendants], errorHandler: nil) else {
        return
    }
    while let item = enumerator.nextObject() {
        guard let url = item as? NSURL else {
            continue
        }
        guard let resourceValues = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isDirectoryKey, .fileSizeKey]) else {
            continue
        }
        if let value = resourceValues[.isDirectoryKey] as? Bool, value {
            continue
        }
        if let value = resourceValues[.contentModificationDateKey] as? NSDate {
            var unlinked = false
            if Int32(value.timeIntervalSince1970) < minTimestamp {
                if let file = url.path {
                    f(file)
                    unlinked = true
                }
            }
            if let file = url.path, !unlinked {
                if let size = (resourceValues[.fileSizeKey] as? NSNumber)?.intValue {
                    anyway((file, size, Int32(value.timeIntervalSince1970)))
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
    private var gigabytesLimit: Int32?
    private let scheduledScanDisposable = MetaDisposable()
    
    
    private struct GeneralFile : Comparable, Equatable {
        let file: String
        let size: Int
        let timestamp:Int32
        static func == (lhs: GeneralFile, rhs: GeneralFile) -> Bool {
            return lhs.timestamp == rhs.timestamp && lhs.size == rhs.size && lhs.file == rhs.file
        }
        static func < (lhs: GeneralFile, rhs: GeneralFile) -> Bool {
            return lhs.timestamp < rhs.timestamp
        }
    }
    
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
    
    func setMaxStoreTimes(general: Int32, shortLived: Int32, gigabytesLimit: Int32) {
        if self.generalMaxStoreTime != general || self.shortLivedMaxStoreTime != shortLived || self.gigabytesLimit != gigabytesLimit {
            self.generalMaxStoreTime = general
            self.gigabytesLimit = gigabytesLimit
            self.shortLivedMaxStoreTime = shortLived
            self.resetScan(general: general, shortLived: shortLived, gigabytesLimit: gigabytesLimit)
        }
    }
    
    private func resetScan(general: Int32, shortLived: Int32, gigabytesLimit: Int32) {
        let generalPaths = self.generalPaths
        let shortLivedPaths = self.shortLivedPaths
        let scanOnce = Signal<Never, NoError> { subscriber in
            DispatchQueue.global(qos: .utility).async {
                var removedShortLivedCount: Int = 0
                var removedGeneralCount: Int = 0
                var removedGeneralLimitCount: Int = 0
                let timestamp = Int32(Date().timeIntervalSince1970)
                let bytesLimit = UInt64(gigabytesLimit) * 1024 * 1024 * 1024
                let oldestShortLivedTimestamp = timestamp - shortLived
                let oldestGeneralTimestamp = timestamp - general
                for path in shortLivedPaths {
                    scanFiles(at: path, olderThan: oldestShortLivedTimestamp, anyway: { _, _, _ in
                        
                    }, unlink: { file in
                        removedShortLivedCount += 1
                        unlink(file)
                    })
                }
                
                var checkFiles: [GeneralFile] = []
                
                var totalLimitSize: UInt64 = 0
                
                for path in generalPaths {
                    scanFiles(at: path, olderThan: oldestGeneralTimestamp, anyway: { file, size, timestamp in
                        checkFiles.append(GeneralFile(file: file, size: size, timestamp: timestamp))
                        totalLimitSize += UInt64(size)
                    }, unlink: { file in
                        removedGeneralCount += 1
                        unlink(file)
                    })
                }
                
                clear: for item in checkFiles.sorted(by: <) {
                    if totalLimitSize > bytesLimit {
                        unlink(item.file)
                        removedGeneralLimitCount += 1
                        if totalLimitSize > UInt64(item.size) {
                            totalLimitSize -= UInt64(item.size)
                        } else {
                            totalLimitSize = 0
                        }
                    } else {
                        break clear
                    }
                }
                
                if removedShortLivedCount != 0 || removedGeneralCount != 0 || removedGeneralLimitCount != 0 {
                    print("[TimeBasedCleanup] removed \(removedShortLivedCount) short-lived files, \(removedGeneralCount) general files, \(removedGeneralLimitCount) limit files")
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
    
    func setMaxStoreTimes(general: Int32, shortLived: Int32, gigabytesLimit: Int32) {
        self.impl.with { impl in
            impl.setMaxStoreTimes(general: general, shortLived: shortLived, gigabytesLimit: gigabytesLimit)
        }
    }
}
