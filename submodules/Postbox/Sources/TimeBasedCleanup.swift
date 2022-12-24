import Foundation
import SwiftSignalKit
private typealias SignalKitTimer = SwiftSignalKit.Timer

struct InodeInfo {
    var inode: __darwin_ino64_t
    var timestamp: Int32
    var size: UInt32
}

private struct ScanFilesResult {
    var unlinkedCount = 0
    var totalSize: UInt64 = 0
}

public func printOpenFiles() {
    var flags: Int32 = 0
    var fd: Int32 = 0
    var buf = Data(count: Int(MAXPATHLEN) + 1)
    
    while fd < FD_SETSIZE {
        errno = 0;
        flags = fcntl(fd, F_GETFD, 0);
        if flags == -1 && errno != 0 {
            if errno != EBADF {
                return
            } else {
                continue
            }
        }
        
        buf.withUnsafeMutableBytes { buffer -> Void in
            let _ = fcntl(fd, F_GETPATH, buffer.baseAddress!)
            let string = String(cString: buffer.baseAddress!.assumingMemoryBound(to: CChar.self))
            print(string)
        }
        
        fd += 1
    }
}

private func scanFiles(at path: String, olderThan minTimestamp: Int32, inodes: inout [InodeInfo]) -> ScanFilesResult {
    var result = ScanFilesResult()
    
    if let dp = opendir(path) {
        let pathBuffer = malloc(2048).assumingMemoryBound(to: Int8.self)
        defer {
            free(pathBuffer)
        }
        
        while true {
            guard let dirp = readdir(dp) else {
                break
            }
            
            if strncmp(&dirp.pointee.d_name.0, ".", 1024) == 0 {
                continue
            }
            if strncmp(&dirp.pointee.d_name.0, "..", 1024) == 0 {
                continue
            }
            strncpy(pathBuffer, path, 1024)
            strncat(pathBuffer, "/", 1024)
            strncat(pathBuffer, &dirp.pointee.d_name.0, 1024)
            
            //puts(pathBuffer)
            //puts("\n")
            
            var value = stat()
            if stat(pathBuffer, &value) == 0 {
                if value.st_mtimespec.tv_sec < minTimestamp {
                    unlink(pathBuffer)
                    result.unlinkedCount += 1
                } else {
                    result.totalSize += UInt64(value.st_size)
                    inodes.append(InodeInfo(
                        inode: value.st_ino,
                        timestamp: Int32(clamping: value.st_mtimespec.tv_sec),
                        size: UInt32(clamping: value.st_size)
                    ))
                }
            }
        }
        closedir(dp)
    }
    
    return result
}

private func mapFiles(paths: [String], inodes: inout [InodeInfo], removeSize: UInt64, mainStoragePath: String, storageBox: StorageBox) {
    var removedSize: UInt64 = 0
    
    inodes.sort(by: { lhs, rhs in
        return lhs.timestamp < rhs.timestamp
    })
    
    var inodesToDelete = Set<__darwin_ino64_t>()
    
    for inode in inodes {
        inodesToDelete.insert(inode.inode)
        removedSize += UInt64(inode.size)
        if removedSize >= removeSize {
            break
        }
    }
    
    if inodesToDelete.isEmpty {
        return
    }
    
    let pathBuffer = malloc(2048).assumingMemoryBound(to: Int8.self)
    defer {
        free(pathBuffer)
    }
    
    var unlinkedResourceIds: [Data] = []
    
    for path in paths {
        let isMainPath = path == mainStoragePath
        if let dp = opendir(path) {
            while true {
                guard let dirp = readdir(dp) else {
                    break
                }
                
                if strncmp(&dirp.pointee.d_name.0, ".", 1024) == 0 {
                    continue
                }
                if strncmp(&dirp.pointee.d_name.0, "..", 1024) == 0 {
                    continue
                }
                strncpy(pathBuffer, path, 1024)
                strncat(pathBuffer, "/", 1024)
                strncat(pathBuffer, &dirp.pointee.d_name.0, 1024)
                
                //puts(pathBuffer)
                //puts("\n")
                
                var value = stat()
                if stat(pathBuffer, &value) == 0 {
                    if inodesToDelete.contains(value.st_ino) {
                        if isMainPath {
                            let nameLength = strnlen(&dirp.pointee.d_name.0, 1024)
                            let nameData = Data(bytesNoCopy: &dirp.pointee.d_name.0, count: Int(nameLength), deallocator: .none)
                            withExtendedLifetime(nameData, {
                                if let fileName = String(data: nameData, encoding: .utf8) {
                                    if let idData = MediaBox.idForFileName(name: fileName).data(using: .utf8) {
                                        unlinkedResourceIds.append(idData)
                                    }
                                }
                            })
                        }
                        unlink(pathBuffer)
                    }
                }
            }
            closedir(dp)
        }
    }
    
    if !unlinkedResourceIds.isEmpty {
        storageBox.remove(ids: unlinkedResourceIds)
    }
}

private final class TimeBasedCleanupImpl {
    private let queue: Queue
    private let storageBox: StorageBox
    private let generalPaths: [String]
    private let totalSizeBasedPath: String
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
    
    init(queue: Queue, storageBox: StorageBox, generalPaths: [String], totalSizeBasedPath: String, shortLivedPaths: [String]) {
        self.queue = queue
        self.storageBox = storageBox
        self.generalPaths = generalPaths
        self.totalSizeBasedPath = totalSizeBasedPath
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
        let totalSizeBasedPath = self.totalSizeBasedPath
        let shortLivedPaths = self.shortLivedPaths
        let storageBox = self.storageBox
        let scanOnce = Signal<Never, NoError> { subscriber in
            DispatchQueue.global(qos: .background).async {
                var removedShortLivedCount: Int = 0
                var removedGeneralCount: Int = 0
                let removedGeneralLimitCount: Int = 0
                
                let startTime = CFAbsoluteTimeGetCurrent()
                
                var inodes: [InodeInfo] = []
                var paths: [String] = []
                
                let timestamp = Int32(Date().timeIntervalSince1970)
                
                /*#if DEBUG
                let bytesLimit: UInt64 = 10 * 1024 * 1024
                #else*/
                let bytesLimit = UInt64(gigabytesLimit) * 1024 * 1024 * 1024
                //#endif
                
                let oldestShortLivedTimestamp = timestamp - shortLived
                let oldestGeneralTimestamp = timestamp - general
                for path in shortLivedPaths {
                    let scanResult = scanFiles(at: path, olderThan: oldestShortLivedTimestamp, inodes: &inodes)
                    if !paths.contains(path) {
                        paths.append(path)
                    }
                    removedShortLivedCount += scanResult.unlinkedCount
                }
                
                var totalLimitSize: UInt64 = 0
                
                for path in generalPaths {
                    let scanResult = scanFiles(at: path, olderThan: oldestGeneralTimestamp, inodes: &inodes)
                    if !paths.contains(path) {
                        paths.append(path)
                    }
                    removedGeneralCount += scanResult.unlinkedCount
                    totalLimitSize += scanResult.totalSize
                }
                do {
                    let scanResult = scanFiles(at: totalSizeBasedPath, olderThan: 0, inodes: &inodes)
                    if !paths.contains(totalSizeBasedPath) {
                        paths.append(totalSizeBasedPath)
                    }
                    removedGeneralCount += scanResult.unlinkedCount
                    totalLimitSize += scanResult.totalSize
                }
                
                if totalLimitSize > bytesLimit {
                    mapFiles(paths: paths, inodes: &inodes, removeSize: totalLimitSize - bytesLimit, mainStoragePath: totalSizeBasedPath, storageBox: storageBox)
                }
                
                if removedShortLivedCount != 0 || removedGeneralCount != 0 || removedGeneralLimitCount != 0 {
                    postboxLog("[TimeBasedCleanup] \(CFAbsoluteTimeGetCurrent() - startTime) s removed \(removedShortLivedCount) short-lived files, \(removedGeneralCount) general files, \(removedGeneralLimitCount) limit files")
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
    
    init(storageBox: StorageBox, generalPaths: [String], totalSizeBasedPath: String, shortLivedPaths: [String]) {
        let queue = self.queue
        self.impl = QueueLocalObject(queue: self.queue, generate: {
            return TimeBasedCleanupImpl(queue: queue, storageBox: storageBox, generalPaths: generalPaths, totalSizeBasedPath: totalSizeBasedPath, shortLivedPaths: shortLivedPaths)
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
