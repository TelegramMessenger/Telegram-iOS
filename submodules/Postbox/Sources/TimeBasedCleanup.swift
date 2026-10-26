import Foundation
import SwiftSignalKit
import DarwinDirStat

private typealias SignalKitTimer = SwiftSignalKit.Timer

struct InodeInfo {
    var inode: __darwin_ino64_t
    var timestamp: Int32
    var size: UInt32
}

struct ScanFilesResult {
    var unlinkedCount = 0
    var totalSize: UInt64 = 0
}

public func printOpenFiles() {
    var flags: Int32 = 0
    var fd: Int32 = 0
    var buf = Data(count: Int(MAXPATHLEN) + 1)
    let maxFd = min(1024, FD_SETSIZE)
    
    while fd < maxFd {
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
            postboxLog("f: \(string)")
        }
        
        fd += 1
    }
}

/// Identifies an inode, so that several directory entries that are hard links to one
/// file can be recognised as the same storage.
struct FileIdentity: Hashable {
    let device: UInt64
    let inode: UInt64
}

final class TempScanDatabase {
    private let queue: Queue
    let valueBox: SqliteValueBox
    
    private let accessTimeTable: ValueBoxTable
    
    private var nextId: Int32 = 0
    
    private let accessTimeKey = ValueBoxKey(length: 4 + 4)
    private let accessInfoBuffer = WriteBuffer()
    
    /// Rows that were registered with a `FileIdentity`, so later hard links to the same
    /// inode can be appended to them and evicted together.
    private var rowKeysByIdentity: [FileIdentity: ValueBoxKey] = [:]
    
    init?(queue: Queue, basePath: String) {
        self.queue = queue
        guard let valueBox = SqliteValueBox(basePath: basePath, queue: queue, isTemporary: true, isReadOnly: false, useCaches: true, removeDatabaseOnError: true, encryptionParameters: nil, upgradeProgress: { _ in }, inMemory: true) else {
            return nil
        }
        self.valueBox = valueBox
        
        self.accessTimeTable = ValueBoxTable(id: 2, keyType: .binary, compactValuesOnCreation: true)
    }
    
    func begin() {
        self.valueBox.begin()
    }
    
    func commit() {
        self.valueBox.commit()
    }
    
    func dispose() {
        self.valueBox.internalClose()
    }
    
    /// Row value layout: `[size: Int64]` followed by the UTF-8 paths of every directory
    /// entry for this storage, separated by NUL (a path cannot contain NUL).
    private static let pathSeparator: UInt8 = 0
    
    /// Registers a file. Pass `identity` for a file that has more than one hard link, so
    /// that `addLink` can attach the other links to this row.
    func add(pathBuffer: UnsafeMutablePointer<Int8>, pathSize: Int, size: Int64, timestamp: Int32, identity: FileIdentity? = nil) {
        let id = self.nextId
        self.nextId += 1
        
        var size = size
        self.accessInfoBuffer.reset()
        self.accessInfoBuffer.write(&size, length: 8)
        self.accessInfoBuffer.write(pathBuffer, length: pathSize)
        
        self.accessTimeKey.setInt32(0, value: timestamp)
        self.accessTimeKey.setInt32(4, value: id)
        self.valueBox.set(self.accessTimeTable, key: self.accessTimeKey, value: self.accessInfoBuffer)
        
        if let identity = identity {
            let key = ValueBoxKey(length: 4 + 4)
            memcpy(key.memory, self.accessTimeKey.memory, 8)
            self.rowKeysByIdentity[identity] = key
        }
    }
    
    /// Attaches another directory entry to the row registered by `add` for `identity`.
    /// The link contributes no size (the inode is already counted) and is evicted
    /// together with the other entries of that row.
    func addLink(pathBuffer: UnsafeMutablePointer<Int8>, pathSize: Int, identity: FileIdentity) {
        guard let key = self.rowKeysByIdentity[identity], let existing = self.valueBox.get(self.accessTimeTable, key: key) else {
            return
        }
        
        self.accessInfoBuffer.reset()
        self.accessInfoBuffer.write(existing.memory, length: existing.length)
        var separator = TempScanDatabase.pathSeparator
        self.accessInfoBuffer.write(&separator, length: 1)
        self.accessInfoBuffer.write(pathBuffer, length: pathSize)
        
        self.valueBox.set(self.accessTimeTable, key: key, value: self.accessInfoBuffer)
    }
    
    /// Visits registered storage oldest first. Each visit carries the file's size once
    /// and every directory entry (hard link) that refers to it; the closure must unlink
    /// all of them for the space to be released. Returning false ends the walk.
    func topByAccessTime(_ f: (Int64, [String]) -> Bool) {
        var startKey = ValueBoxKey(length: 4)
        startKey.setInt32(0, value: 0)
        
        let endKey = ValueBoxKey(length: 4)
        endKey.setInt32(0, value: Int32.max)
        
        while true {
            var lastKey: ValueBoxKey?
            var stopped = false
            self.valueBox.range(self.accessTimeTable, start: startKey, end: endKey, values: { key, value in
                var result = true
                withExtendedLifetime(value, {
                    let readBuffer = ReadBuffer(memoryBufferNoCopy: value)
                    
                    var size: Int64 = 0
                    readBuffer.read(&size, offset: 0, length: 8)
                    
                    var pathData = Data(count: value.length - 8)
                    pathData.withUnsafeMutableBytes { buffer -> Void in
                        readBuffer.read(buffer.baseAddress!, offset: 0, length: buffer.count)
                    }
                    
                    let paths = pathData.split(separator: TempScanDatabase.pathSeparator, omittingEmptySubsequences: true).compactMap { String(data: $0, encoding: .utf8) }
                    if !paths.isEmpty {
                        result = f(size, paths)
                    }
                })
                
                lastKey = key
                if !result {
                    stopped = true
                }
                
                return result
            }, limit: 512)
            
            // A `false` from `f` ends the whole walk, not just the current page. The
            // eviction closure unlinks every file it is handed before it re-checks the
            // limit, so resuming from `lastKey` here would delete the rest of the cache.
            if stopped {
                break
            }
            
            if let lastKey = lastKey {
                startKey = lastKey
            } else {
                break
            }
        }
    }
}

func scanTimestamp(_ seconds: Int) -> Int32 {
    return Int32(clamping: max(0, min(seconds, Int(Int32.max) - 1)))
}

func scanFiles(at path: String, olderThan minTimestamp: Int32, includeSubdirectories: Bool, performSizeMapping: Bool, tempDatabase: TempScanDatabase, reportMemoryUsageInterval: Int, reportMemoryUsageRemaining: inout Int, seenLinkedInodes: inout Set<FileIdentity>, isCancelled: () -> Bool = { false }, didUnlink: ((String) -> Void)? = nil) -> ScanFilesResult {
    var result = ScanFilesResult()
    
    var subdirectories: [String] = []
    
    if let dp = opendir(path) {
        let pathBuffer = malloc(2048).assumingMemoryBound(to: Int8.self)
        defer {
            free(pathBuffer)
        }
        
        while true {
            if isCancelled() {
                break
            }
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
            
            var isSymbolicLink = dirp.pointee.d_type == DT_LNK
            if dirp.pointee.d_type == DT_UNKNOWN {
                var linkValue = stat()
                isSymbolicLink = lstat(pathBuffer, &linkValue) == 0 && (linkValue.st_mode & S_IFMT) == S_IFLNK
            }
            
            var value = stat()
            if stat(pathBuffer, &value) == 0 {
                if (((value.st_mode) & S_IFMT) == S_IFDIR) {
                    if includeSubdirectories && !isSymbolicLink {
                        if let subPath = String(data: Data(bytes: pathBuffer, count: strnlen(pathBuffer, 1024)), encoding: .utf8) {
                            subdirectories.append(subPath)
                        }
                    }
                } else {
                    if value.st_mtimespec.tv_sec < minTimestamp {
                        unlink(pathBuffer)
                        result.unlinkedCount += 1
                        if let didUnlink = didUnlink {
                            didUnlink(String(cString: pathBuffer))
                        }
                    } else if isSymbolicLink {
                        var targetIdentity: FileIdentity?
                        if value.st_nlink > 1 {
                            targetIdentity = FileIdentity(device: UInt64(UInt32(bitPattern: value.st_dev)), inode: UInt64(value.st_ino))
                        }
                        if let targetIdentity = targetIdentity, seenLinkedInodes.contains(targetIdentity) {
                            if performSizeMapping {
                                tempDatabase.addLink(pathBuffer: pathBuffer, pathSize: strnlen(pathBuffer, 1024), identity: targetIdentity)
                            }
                        } else if performSizeMapping {
                            tempDatabase.add(pathBuffer: pathBuffer, pathSize: strnlen(pathBuffer, 1024), size: 0, timestamp: scanTimestamp(value.st_mtimespec.tv_sec))
                        }
                    } else {
                        // A completed download is two directory entries (`<id>` and
                        // `<id>_partial`) hard-linked to one inode. Count that storage
                        // once, and register the extra links on the same row so eviction
                        // removes them together; otherwise the size is counted (and
                        // "freed") twice, and unlinking one entry releases nothing.
                        var identity: FileIdentity?
                        var isAdditionalLink = false
                        if value.st_nlink > 1 {
                            let fileIdentity = FileIdentity(device: UInt64(UInt32(bitPattern: value.st_dev)), inode: UInt64(value.st_ino))
                            identity = fileIdentity
                            isAdditionalLink = !seenLinkedInodes.insert(fileIdentity).inserted
                        }
                        
                        if isAdditionalLink {
                            if performSizeMapping, let identity = identity {
                                tempDatabase.addLink(pathBuffer: pathBuffer, pathSize: strnlen(pathBuffer, 1024), identity: identity)
                            }
                        } else {
                            result.totalSize += UInt64(value.st_size)
                            if performSizeMapping {
                                tempDatabase.add(pathBuffer: pathBuffer, pathSize: strnlen(pathBuffer, 1024), size: Int64(value.st_size), timestamp: scanTimestamp(value.st_mtimespec.tv_sec), identity: identity)
                                
                                reportMemoryUsageRemaining -= 1
                                if reportMemoryUsageRemaining <= 0 {
                                    reportMemoryUsageRemaining = reportMemoryUsageInterval
                                    
                                    postboxLog("TimeBasedCleanup in-memory size: \(tempDatabase.valueBox.getDatabaseSize() / (1024 * 1024)) MB")
                                }
                            }
                        }
                    }
                }
            }
        }
        closedir(dp)
    }
    
    if includeSubdirectories {
        for subPath in subdirectories {
            if isCancelled() {
                break
            }
            let subResult = scanFiles(at: subPath, olderThan: minTimestamp, includeSubdirectories: true, performSizeMapping: performSizeMapping, tempDatabase: tempDatabase, reportMemoryUsageInterval: reportMemoryUsageInterval, reportMemoryUsageRemaining: &reportMemoryUsageRemaining, seenLinkedInodes: &seenLinkedInodes, isCancelled: isCancelled, didUnlink: didUnlink)
            result.totalSize += subResult.totalSize
            result.unlinkedCount += subResult.unlinkedCount
        }
    }
    
    return result
}

private func statForDirectory(path: String) -> Int64 {
    if #available(macOS 10.13, *) {
        var s = darwin_dirstat()
        var result = dirstat_np(path, 1, &s, MemoryLayout<darwin_dirstat>.size)
        if result != -1 {
            return Int64(s.total_size)
        } else {
            result = dirstat_np(path, 0, &s, MemoryLayout<darwin_dirstat>.size)
            if result != -1 {
                return Int64(s.total_size)
            } else {
                return 0
            }
        }
    } else {
        let fileManager = FileManager.default
        let folderURL = URL(fileURLWithPath: path)
        var folderSize: Int64 = 0
        if let files = try? fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil, options: []) {
            for file in files {
                folderSize += (fileSize(file.path) ?? 0)
            }
        }
        return folderSize
    }
}

private final class TimeBasedCleanupImpl {
    private let queue: Queue
    private let storageBox: StorageBox
    private let cacheStorageBox: StorageBox
    private let generalPaths: [String]
    private let totalSizeBasedPath: String
    private let shortLivedPaths: [String]
    
    private var scheduledTouches = Set<String>()
    private var scheduledTouchesTimer: SignalKitTimer?
    
    private var generalMaxStoreTime: Int32?
    private var shortLivedMaxStoreTime: Int32?
    private var gigabytesLimit: Int32?
    private let scheduledScanDisposable = MetaDisposable()
    private let scanQueue = Queue(name: "TimeBasedCleanupScan", qos: .background)
    private let scanDelay: Double
    
    init(queue: Queue, storageBox: StorageBox, cacheStorageBox: StorageBox, generalPaths: [String], totalSizeBasedPath: String, shortLivedPaths: [String], scanDelay: Double) {
        self.queue = queue
        self.storageBox = storageBox
        self.cacheStorageBox = cacheStorageBox
        self.generalPaths = generalPaths
        self.totalSizeBasedPath = totalSizeBasedPath
        self.shortLivedPaths = shortLivedPaths
        self.scanDelay = scanDelay
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
        let shortLived = gigabytesLimit == Int32.max ? Int32.max : shortLived
        
        if general == Int32.max && shortLived == Int32.max && gigabytesLimit == Int32.max {
            self.scheduledScanDisposable.set(nil)
            return
        }
        
        let generalPaths = self.generalPaths
        let totalSizeBasedPath = self.totalSizeBasedPath
        let shortLivedPaths = self.shortLivedPaths
        let storageBox = self.storageBox
        let cacheStorageBox = self.cacheStorageBox
        let scanQueue = self.scanQueue
        let scanOnce = Signal<Never, NoError> { subscriber in
            let cancelled = Atomic<Bool>(value: false)
            let isCancelled: () -> Bool = {
                return cancelled.with { $0 }
            }
            let queue = scanQueue
            queue.async {
                if isCancelled() {
                    subscriber.putCompletion()
                    return
                }
                let tempDirectory = TempBox.shared.tempDirectory()
                let randomId = UInt32.random(in: 0 ... UInt32.max)
                
                postboxLog("TimeBasedCleanup: reset scan id: \(randomId)")
                
                guard let tempDatabase = TempScanDatabase(queue: queue, basePath: tempDirectory.path) else {
                    postboxLog("TimeBasedCleanup: couldn't create temp database at \(tempDirectory.path)")
                    TempBox.shared.dispose(tempDirectory)
                    subscriber.putCompletion()
                    return
                }
                tempDatabase.begin()
                
                var removedShortLivedCount: Int = 0
                var removedGeneralCount: Int = 0
                var removedGeneralLimitCount: Int = 0
                
                let reportMemoryUsageInterval = 100
                var reportMemoryUsageRemaining: Int = reportMemoryUsageInterval
                var seenLinkedInodes = Set<FileIdentity>()
                
                let startTime = CFAbsoluteTimeGetCurrent()
                
                var paths: [String] = []
                
                let timestamp = scanTimestamp(Int(Date().timeIntervalSince1970))
                
                /*#if DEBUG
                let bytesLimit: UInt64 = 10 * 1024 * 1024
                #else*/
                let bytesLimit = UInt64(gigabytesLimit) * 1024 * 1024 * 1024
                //#endif
                
                var totalApproximateSize: Int64 = 0
                if gigabytesLimit < Int32.max {
                    for path in shortLivedPaths {
                        totalApproximateSize += statForDirectory(path: path)
                    }
                    for path in generalPaths {
                        totalApproximateSize += statForDirectory(path: path)
                    }
                    
                    if let enumerator = FileManager.default.enumerator(at: URL(fileURLWithPath: totalSizeBasedPath), includingPropertiesForKeys: [.fileSizeKey, .fileResourceIdentifierKey], options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants], errorHandler: nil) {
                        var fileIds = Set<Data>()
                        loop: for url in enumerator {
                            guard let url = url as? URL else {
                                continue
                            }
                            if let fileId = (try? url.resourceValues(forKeys: Set([.fileResourceIdentifierKey])))?.fileResourceIdentifier as? Data {
                                if fileIds.contains(fileId) {
                                    continue loop
                                }
                                
                                if let value = (try? url.resourceValues(forKeys: Set([.fileSizeKey])))?.fileSize, value != 0 {
                                    fileIds.insert(fileId)
                                    totalApproximateSize += Int64(value)
                                }
                            }
                        }
                    }
                }
                
                var performSizeMapping = true
                if totalApproximateSize <= bytesLimit {
                    performSizeMapping = false
                }
                #if DEBUG
                if "".isEmpty {
                    performSizeMapping = true
                }
                #endif
                
                print("TimeBasedCleanup: id: \(randomId) performSizeMapping: \(performSizeMapping)")
                
                let oldestShortLivedTimestamp = timestamp - shortLived
                let oldestGeneralTimestamp = timestamp - general
                
                var totalLimitSize: UInt64 = 0
                
                var removedCachePaths: [Data] = []
                let didUnlinkCacheFile: (String) -> Void = { path in
                    if let pathData = path.data(using: .utf8) {
                        removedCachePaths.append(pathData)
                    }
                }
                
                for path in shortLivedPaths {
                    let scanResult = scanFiles(at: path, olderThan: oldestShortLivedTimestamp, includeSubdirectories: true, performSizeMapping: performSizeMapping, tempDatabase: tempDatabase, reportMemoryUsageInterval: reportMemoryUsageInterval, reportMemoryUsageRemaining: &reportMemoryUsageRemaining, seenLinkedInodes: &seenLinkedInodes, isCancelled: isCancelled, didUnlink: didUnlinkCacheFile)
                    if !paths.contains(path) {
                        paths.append(path)
                    }
                    removedShortLivedCount += scanResult.unlinkedCount
                    totalLimitSize += scanResult.totalSize
                }
                
                if general < Int32.max || (gigabytesLimit < Int32.max && performSizeMapping) {
                    for path in generalPaths {
                        let scanResult = scanFiles(at: path, olderThan: oldestGeneralTimestamp, includeSubdirectories: true, performSizeMapping: performSizeMapping, tempDatabase: tempDatabase, reportMemoryUsageInterval: reportMemoryUsageInterval, reportMemoryUsageRemaining: &reportMemoryUsageRemaining, seenLinkedInodes: &seenLinkedInodes, isCancelled: isCancelled, didUnlink: didUnlinkCacheFile)
                        if !paths.contains(path) {
                            paths.append(path)
                        }
                        removedGeneralCount += scanResult.unlinkedCount
                        totalLimitSize += scanResult.totalSize
                    }
                }
                
                if gigabytesLimit < Int32.max {
                    let scanResult = scanFiles(at: totalSizeBasedPath, olderThan: 0, includeSubdirectories: false, performSizeMapping: performSizeMapping, tempDatabase: tempDatabase, reportMemoryUsageInterval: reportMemoryUsageInterval, reportMemoryUsageRemaining: &reportMemoryUsageRemaining, seenLinkedInodes: &seenLinkedInodes, isCancelled: isCancelled)
                    if !paths.contains(totalSizeBasedPath) {
                        paths.append(totalSizeBasedPath)
                    }
                    removedGeneralCount += scanResult.unlinkedCount
                    totalLimitSize += scanResult.totalSize
                }
                
                tempDatabase.commit()
                
                var unlinkedResourceIds: [Data] = []
                
                if totalLimitSize > bytesLimit && !isCancelled() {
                    var remainingSize = Int64(totalLimitSize)
                    var unlinkedResourceIdSet = Set<Data>()
                    tempDatabase.topByAccessTime { size, filePaths in
                        if isCancelled() {
                            return false
                        }
                        remainingSize -= size
                        
                        // Every path here is a hard link to the same inode; all of them
                        // must go for the space to be released.
                        for filePath in filePaths {
                            unlink(filePath)
                            removedGeneralLimitCount += 1
                            
                            if (filePath as NSString).deletingLastPathComponent == totalSizeBasedPath {
                                let fileName = (filePath as NSString).lastPathComponent
                                if !fileName.hasSuffix("_partial.meta"), let idData = MediaBox.idForFileName(name: fileName).data(using: .utf8), !unlinkedResourceIdSet.contains(idData) {
                                    unlinkedResourceIdSet.insert(idData)
                                    unlinkedResourceIds.append(idData)
                                }
                            } else {
                                didUnlinkCacheFile(filePath)
                            }
                        }
                        
                        if remainingSize <= Int64(bytesLimit) {
                            return false
                        }

                        return true
                    }
                }
                
                if !unlinkedResourceIds.isEmpty {
                    storageBox.remove(ids: unlinkedResourceIds)
                }
                if !removedCachePaths.isEmpty {
                    cacheStorageBox.remove(ids: removedCachePaths)
                }
                
                tempDatabase.dispose()
                TempBox.shared.dispose(tempDirectory)
                
                if removedShortLivedCount != 0 || removedGeneralCount != 0 || removedGeneralLimitCount != 0 {
                    postboxLog("[TimeBasedCleanup] \(CFAbsoluteTimeGetCurrent() - startTime) s removed \(removedShortLivedCount) short-lived files, \(removedGeneralCount) general files, \(removedGeneralLimitCount) limit files")
                }
                postboxLog("TimeBasedCleanup: scan id: \(randomId) finished\(isCancelled() ? " (cancelled)" : "")")
                subscriber.putCompletion()
            }
            return ActionDisposable {
                let _ = cancelled.swap(true)
            }
        }
        let scanFirstTime = scanOnce
        |> delay(self.scanDelay, queue: Queue.concurrentDefaultQueue())
        
        let scan = scanFirstTime
        self.scheduledScanDisposable.set((scan
        |> deliverOn(self.queue)).start())
    }
    
    func touch(paths: [String]) {
        for path in paths {
            self.scheduledTouches.insert(path)
        }
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
            for item in scheduledTouches {
                utime(item, nil)
            }
        }
        self.scheduledTouches = []
    }
}

final class TimeBasedCleanup {
    private let queue = Queue()
    private let impl: QueueLocalObject<TimeBasedCleanupImpl>
    
    init(storageBox: StorageBox, cacheStorageBox: StorageBox, generalPaths: [String], totalSizeBasedPath: String, shortLivedPaths: [String], scanDelay: Double = 10.0) {
        let queue = self.queue
        self.impl = QueueLocalObject(queue: self.queue, generate: {
            return TimeBasedCleanupImpl(queue: queue, storageBox: storageBox, cacheStorageBox: cacheStorageBox, generalPaths: generalPaths, totalSizeBasedPath: totalSizeBasedPath, shortLivedPaths: shortLivedPaths, scanDelay: scanDelay)
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
