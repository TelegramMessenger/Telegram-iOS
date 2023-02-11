import Foundation
import SwiftSignalKit
import DarwinDirStat

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

private final class TempScanDatabase {
    private let queue: Queue
    private let valueBox: SqliteValueBox
    
    private let accessTimeTable: ValueBoxTable
    
    private var nextId: Int32 = 0
    
    private let accessTimeKey = ValueBoxKey(length: 4 + 4)
    private let accessInfoBuffer = WriteBuffer()
    
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
    
    func add(pathBuffer: UnsafeMutablePointer<Int8>, pathSize: Int, size: Int64, timestamp: Int32) {
        let id = self.nextId
        self.nextId += 1
        
        var size = size
        self.accessInfoBuffer.reset()
        self.accessInfoBuffer.write(&size, length: 8)
        self.accessInfoBuffer.write(pathBuffer, length: pathSize)
        
        self.accessTimeKey.setInt32(0, value: timestamp)
        self.accessTimeKey.setInt32(4, value: id)
        self.valueBox.set(self.accessTimeTable, key: self.accessTimeKey, value: self.accessInfoBuffer)
    }
    
    func topByAccessTime(_ f: (Int64, String) -> Bool) {
        var startKey = ValueBoxKey(length: 4)
        startKey.setInt32(0, value: 0)
        
        let endKey = ValueBoxKey(length: 4)
        endKey.setInt32(0, value: Int32.max)
        
        while true {
            var lastKey: ValueBoxKey?
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
                    
                    if let path = String(data: pathData, encoding: .utf8) {
                        result = f(size, path)
                    }
                })
                
                lastKey = key
                
                return result
            }, limit: 512)
            
            if let lastKey = lastKey {
                startKey = lastKey
            } else {
                break
            }
        }
    }
}

private func scanFiles(at path: String, olderThan minTimestamp: Int32, includeSubdirectories: Bool, performSizeMapping: Bool, tempDatabase: TempScanDatabase) -> ScanFilesResult {
    var result = ScanFilesResult()
    
    var subdirectories: [String] = []
    
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
            
            var value = stat()
            if stat(pathBuffer, &value) == 0 {
                if (((value.st_mode) & S_IFMT) == S_IFDIR) {
                    if includeSubdirectories {
                        if let subPath = String(data: Data(bytes: pathBuffer, count: strnlen(pathBuffer, 1024)), encoding: .utf8) {
                            subdirectories.append(subPath)
                        }
                    }
                } else {
                    if value.st_mtimespec.tv_sec < minTimestamp {
                        unlink(pathBuffer)
                        result.unlinkedCount += 1
                    } else {
                        result.totalSize += UInt64(value.st_size)
                        if performSizeMapping {
                            tempDatabase.add(pathBuffer: pathBuffer, pathSize: strnlen(pathBuffer, 1024), size: Int64(value.st_size), timestamp: Int32(value.st_mtimespec.tv_sec))
                        }
                    }
                }
            }
        }
        closedir(dp)
    }
    
    if includeSubdirectories {
        for subPath in subdirectories {
            let subResult = scanFiles(at: subPath, olderThan: minTimestamp, includeSubdirectories: true, performSizeMapping: performSizeMapping, tempDatabase: tempDatabase)
            result.totalSize += subResult.totalSize
            result.unlinkedCount += subResult.unlinkedCount
        }
    }
    
    return result
}

/*private func mapFiles(paths: [String], inodes: inout [InodeInfo], removeSize: UInt64, mainStoragePath: String, storageBox: StorageBox) {
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
                    if (((value.st_mode) & S_IFMT) == S_IFDIR) {
                        if let subPath = String(data: Data(bytes: pathBuffer, count: strnlen(pathBuffer, 1024)), encoding: .utf8) {
                            mapFiles(paths: <#T##[String]#>, inodes: &<#T##[InodeInfo]#>, removeSize: remov, mainStoragePath: mainStoragePath, storageBox: storageBox)
                        }
                    } else {
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
            }
            closedir(dp)
        }
    }
    
    if !unlinkedResourceIds.isEmpty {
        storageBox.remove(ids: unlinkedResourceIds)
    }
}*/

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
    private let generalPaths: [String]
    private let totalSizeBasedPath: String
    private let shortLivedPaths: [String]
    
    private var scheduledTouches: [String] = []
    private var scheduledTouchesTimer: SignalKitTimer?
    
    private var generalMaxStoreTime: Int32?
    private var shortLivedMaxStoreTime: Int32?
    private var gigabytesLimit: Int32?
    private let scheduledScanDisposable = MetaDisposable()
    
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
            let queue = Queue(name: "TimeBasedCleanupScan", qos: .background)
            queue.async {
                let tempDirectory = TempBox.shared.tempDirectory()
                guard let tempDatabase = TempScanDatabase(queue: queue, basePath: tempDirectory.path) else {
                    postboxLog("TimeBasedCleanup: couldn't create temp database at \(tempDirectory.path)")
                    subscriber.putCompletion()
                    return
                }
                tempDatabase.begin()
                
                var removedShortLivedCount: Int = 0
                var removedGeneralCount: Int = 0
                let removedGeneralLimitCount: Int = 0
                
                let startTime = CFAbsoluteTimeGetCurrent()
                
                var paths: [String] = []
                
                let timestamp = Int32(Date().timeIntervalSince1970)
                
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
                
                let oldestShortLivedTimestamp = timestamp - shortLived
                let oldestGeneralTimestamp = timestamp - general
                for path in shortLivedPaths {
                    let scanResult = scanFiles(at: path, olderThan: oldestShortLivedTimestamp, includeSubdirectories: true, performSizeMapping: performSizeMapping, tempDatabase: tempDatabase)
                    if !paths.contains(path) {
                        paths.append(path)
                    }
                    removedShortLivedCount += scanResult.unlinkedCount
                }
                
                var totalLimitSize: UInt64 = 0
                
                if general < Int32.max {
                    for path in generalPaths {
                        let scanResult = scanFiles(at: path, olderThan: oldestGeneralTimestamp, includeSubdirectories: true, performSizeMapping: performSizeMapping, tempDatabase: tempDatabase)
                        if !paths.contains(path) {
                            paths.append(path)
                        }
                        removedGeneralCount += scanResult.unlinkedCount
                        totalLimitSize += scanResult.totalSize
                    }
                }
                
                if gigabytesLimit < Int32.max {
                    let scanResult = scanFiles(at: totalSizeBasedPath, olderThan: 0, includeSubdirectories: false, performSizeMapping: performSizeMapping, tempDatabase: tempDatabase)
                    if !paths.contains(totalSizeBasedPath) {
                        paths.append(totalSizeBasedPath)
                    }
                    removedGeneralCount += scanResult.unlinkedCount
                    totalLimitSize += scanResult.totalSize
                }
                
                tempDatabase.commit()
                
                var unlinkedResourceIds: [Data] = []
                
                if totalLimitSize > bytesLimit {
                    var remainingSize = Int64(totalLimitSize)
                    tempDatabase.topByAccessTime { size, filePath in
                        remainingSize -= size
                        
                        unlink(filePath)
                        
                        if (filePath as NSString).deletingLastPathComponent == totalSizeBasedPath {
                            let fileName = (filePath as NSString).lastPathComponent
                            if let idData = MediaBox.idForFileName(name: fileName).data(using: .utf8) {
                                unlinkedResourceIds.append(idData)
                            }
                        }
                        //let fileName = filePath.lastPathComponent
                        
                        if remainingSize >= bytesLimit {
                            return false
                        }
                        
                        return true
                    }
                }
                
                if !unlinkedResourceIds.isEmpty {
                    storageBox.remove(ids: unlinkedResourceIds)
                }
                
                tempDatabase.dispose()
                TempBox.shared.dispose(tempDirectory)
                
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
