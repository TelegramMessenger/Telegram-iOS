import Foundation
import SwiftSignalKit
import Crc32
import ManagedFile
import RangeSet

final class MediaBoxFileManager {
    enum Mode {
        case read
        case readwrite
    }
    
    enum AccessError: Error {
        case generic
    }
    
    final class Item {
        final class Accessor {
            private let file: ManagedFile
            
            init(file: ManagedFile) {
                self.file = file
            }
            
            func write(_ data: UnsafeRawPointer, count: Int) -> Int {
                return self.file.write(data, count: count)
            }
            
            func read(_ data: UnsafeMutableRawPointer, _ count: Int) -> Int {
                return self.file.read(data, count)
            }
            
            func readData(count: Int) -> Data {
                return self.file.readData(count: count)
            }
            
            func seek(position: Int64) {
                self.file.seek(position: position)
            }
        }
        
        weak var manager: MediaBoxFileManager?
        let path: String
        let mode: Mode
        
        weak var context: ItemContext?
        
        init(manager: MediaBoxFileManager, path: String, mode: Mode) {
            self.manager = manager
            self.path = path
            self.mode = mode
        }
        
        deinit {
            if let manager = self.manager, let context = self.context {
                manager.discardItemContext(context: context)
            }
        }
        
        func access(_ f: (Accessor) throws -> Void) throws {
            if let context = self.context {
                try f(Accessor(file: context.file))
            } else {
                if let manager = self.manager {
                    if let context = manager.takeContext(path: self.path, mode: self.mode) {
                        self.context = context
                        try f(Accessor(file: context.file))
                    } else {
                        throw AccessError.generic
                    }
                } else {
                    throw AccessError.generic
                }
            }
        }
        
        func sync() {
            if let context = self.context {
                context.sync()
            }
        }
    }
    
    final class ItemContext {
        let id: Int
        let path: String
        let mode: Mode
        let file: ManagedFile
        
        private var isDisposed: Bool = false
        
        init?(id: Int, path: String, mode: Mode) {
            let mappedMode: ManagedFile.Mode
            switch mode {
            case .read:
                mappedMode = .read
            case .readwrite:
                mappedMode = .readwrite
            }
            
            guard let file = ManagedFile(queue: nil, path: path, mode: mappedMode) else {
                return nil
            }
            self.file = file
            
            self.id = id
            self.path = path
            self.mode = mode
        }
        
        deinit {
            assert(self.isDisposed)
        }
        
        func dispose() {
            if !self.isDisposed {
                self.isDisposed = true
                self.file._unsafeClose()
            } else {
                assertionFailure()
            }
        }
        
        func sync() {
            self.file.sync()
        }
    }
    
    private let queue: Queue?
    private var contexts: [Int: ItemContext] = [:]
    private var nextItemId: Int = 0
    private let maxOpenFiles: Int
    
    init(queue: Queue?) {
        self.queue = queue
        self.maxOpenFiles = 16
    }
    
    func open(path: String, mode: Mode) -> Item? {
        if let queue = self.queue {
            assert(queue.isCurrent())
        }
        
        return Item(manager: self, path: path, mode: mode)
    }
    
    private func takeContext(path: String, mode: Mode) -> ItemContext? {
        if let queue = self.queue {
            assert(queue.isCurrent())
        }
        
        if self.contexts.count > self.maxOpenFiles {
            if let minKey = self.contexts.keys.min(), let context = self.contexts[minKey] {
                self.discardItemContext(context: context)
            }
        }
        
        let id = self.nextItemId
        self.nextItemId += 1
        let context = ItemContext(id: id, path: path, mode: mode)
        self.contexts[id] = context
        return context
    }
    
    private func discardItemContext(context: ItemContext) {
        if let queue = self.queue {
            assert(queue.isCurrent())
        }
        
        if let context = self.contexts.removeValue(forKey: context.id) {
            context.dispose()
        }
    }
}

private final class MediaBoxFileMap {
    enum FileMapError: Error {
        case generic
    }
    
    fileprivate(set) var sum: Int64
    private(set) var ranges: RangeSet<Int64>
    private(set) var truncationSize: Int64?
    private(set) var progress: Float?

    init() {
        self.sum = 0
        self.ranges = RangeSet<Int64>()
        self.truncationSize = nil
        self.progress = nil
    }
    
    private init(
        sum: Int64,
        ranges: RangeSet<Int64>,
        truncationSize: Int64?,
        progress: Float?
    ) {
        self.sum = sum
        self.ranges = ranges
        self.truncationSize = truncationSize
        self.progress = progress
    }
    
    static func read(manager: MediaBoxFileManager, path: String) throws -> MediaBoxFileMap {
        guard let length = fileSize(path) else {
            throw FileMapError.generic
        }
        guard let fileItem = manager.open(path: path, mode: .readwrite) else {
            throw FileMapError.generic
        }
        
        var result: MediaBoxFileMap?
        
        try fileItem.access { fd in
            var firstUInt32: UInt32 = 0
            guard fd.read(&firstUInt32, 4) == 4 else {
                throw FileMapError.generic
            }
            
            if firstUInt32 == 0x7bac1487 {
                var crc: UInt32 = 0
                guard fd.read(&crc, 4) == 4 else {
                    throw FileMapError.generic
                }
                
                var count: Int32 = 0
                var sum: Int64 = 0
                var ranges = RangeSet<Int64>()
                
                guard fd.read(&count, 4) == 4 else {
                    throw FileMapError.generic
                }
                
                if count < 0 {
                    throw FileMapError.generic
                }
                
                if count < 0 || length < 4 + 4 + 4 + 8 + count * 2 * 8 {
                    throw FileMapError.generic
                }
                
                var truncationSizeValue: Int64 = 0
                
                var data = Data(count: Int(8 + count * 2 * 8))
                let dataCount = data.count
                if !(data.withUnsafeMutableBytes { rawBytes -> Bool in
                    let bytes = rawBytes.baseAddress!.assumingMemoryBound(to: UInt8.self)

                    guard fd.read(bytes, dataCount) == dataCount else {
                        return false
                    }
                    
                    memcpy(&truncationSizeValue, bytes, 8)
                    
                    let calculatedCrc = Crc32(bytes, Int32(dataCount))
                    if calculatedCrc != crc {
                        return false
                    }
                    
                    var offset = 8
                    for _ in 0 ..< count {
                        var intervalOffset: Int64 = 0
                        var intervalLength: Int64 = 0
                        memcpy(&intervalOffset, bytes.advanced(by: offset), 8)
                        memcpy(&intervalLength, bytes.advanced(by: offset + 8), 8)
                        offset += 8 * 2
                        
                        ranges.insert(contentsOf: intervalOffset ..< (intervalOffset + intervalLength))
                        
                        sum += intervalLength
                    }
                    
                    return true
                }) {
                    throw FileMapError.generic
                }
                
                let mappedTruncationSize: Int64?
                if truncationSizeValue == -1 {
                    mappedTruncationSize = nil
                } else if truncationSizeValue < 0 {
                    mappedTruncationSize = nil
                } else {
                    mappedTruncationSize = truncationSizeValue
                }

                result = MediaBoxFileMap(
                    sum: sum,
                    ranges: ranges,
                    truncationSize: mappedTruncationSize,
                    progress: nil
                )
            } else {
                let crc: UInt32 = firstUInt32
                var count: Int32 = 0
                var sum: Int32 = 0
                var ranges = RangeSet<Int64>()
                
                guard fd.read(&count, 4) == 4 else {
                    throw FileMapError.generic
                }
                
                if count < 0 {
                    throw FileMapError.generic
                }
                
                if count < 0 || UInt64(length) < 4 + 4 + UInt64(count) * 2 * 4 {
                    throw FileMapError.generic
                }
                
                var truncationSizeValue: Int32 = 0
                
                var data = Data(count: Int(4 + count * 2 * 4))
                let dataCount = data.count
                if !(data.withUnsafeMutableBytes { rawBytes -> Bool in
                    let bytes = rawBytes.baseAddress!.assumingMemoryBound(to: UInt8.self)

                    guard fd.read(bytes, dataCount) == dataCount else {
                        return false
                    }
                    
                    memcpy(&truncationSizeValue, bytes, 4)
                    
                    let calculatedCrc = Crc32(bytes, Int32(dataCount))
                    if calculatedCrc != crc {
                        return false
                    }
                    
                    var offset = 4
                    for _ in 0 ..< count {
                        var intervalOffset: Int32 = 0
                        var intervalLength: Int32 = 0
                        memcpy(&intervalOffset, bytes.advanced(by: offset), 4)
                        memcpy(&intervalLength, bytes.advanced(by: offset + 4), 4)
                        offset += 8
                        
                        ranges.insert(contentsOf: Int64(intervalOffset) ..< Int64(intervalOffset + intervalLength))
                        
                        sum += intervalLength
                    }
                    
                    return true
                }) {
                    throw FileMapError.generic
                }
                
                let mappedTruncationSize: Int64?
                if truncationSizeValue == -1 {
                    mappedTruncationSize = nil
                } else {
                    mappedTruncationSize = Int64(truncationSizeValue)
                }
                
                result = MediaBoxFileMap(
                    sum: Int64(sum),
                    ranges: ranges,
                    truncationSize: mappedTruncationSize,
                    progress: nil
                )
            }
        }
        
        guard let result = result else {
            throw FileMapError.generic
        }
        return result
    }
    
    func serialize(manager: MediaBoxFileManager, to path: String) {
        guard let fileItem = manager.open(path: path, mode: .readwrite) else {
            postboxLog("MediaBoxFile: serialize: cannot open file")
            return
        }
        
        let _ = try? fileItem.access { file in
            file.seek(position: 0)
            let buffer = WriteBuffer()
            var magic: UInt32 = 0x7bac1487
            buffer.write(&magic, offset: 0, length: 4)
            
            var zero: Int32 = 0
            buffer.write(&zero, offset: 0, length: 4)
            
            let rangeView = self.ranges.ranges
            var count: Int32 = Int32(rangeView.count)
            buffer.write(&count, offset: 0, length: 4)
            
            var truncationSizeValue: Int64 = self.truncationSize ?? -1
            buffer.write(&truncationSizeValue, offset: 0, length: 8)
            
            for range in rangeView {
                var intervalOffset = range.lowerBound
                var intervalLength = range.upperBound - range.lowerBound
                buffer.write(&intervalOffset, offset: 0, length: 8)
                buffer.write(&intervalLength, offset: 0, length: 8)
            }
            var crc: UInt32 = Crc32(buffer.memory.advanced(by: 4 + 4 + 4), Int32(buffer.length - (4 + 4 + 4)))
            memcpy(buffer.memory.advanced(by: 4), &crc, 4)
            let written = file.write(buffer.memory, count: buffer.length)
            assert(written == buffer.length)
        }
    }
    
    fileprivate func fill(_ range: Range<Int64>) {
        var previousCount: Int64 = 0
        for intersectionRange in self.ranges.intersection(RangeSet<Int64>(range)).ranges {
            previousCount += intersectionRange.upperBound - intersectionRange.lowerBound
        }
        
        self.ranges.insert(contentsOf: range)
        self.sum += (range.upperBound - range.lowerBound) - previousCount
    }
    
    fileprivate func truncate(_ size: Int64) {
        self.truncationSize = size
    }
    fileprivate func progressUpdated(_ progress: Float) {
        self.progress = progress
    }
    
    fileprivate func reset() {
        self.truncationSize = nil
        self.ranges = RangeSet<Int64>()
        self.sum = 0
        self.progress = nil
    }
    
    fileprivate func contains(_ range: Range<Int64>) -> Range<Int64>? {
        let maxValue: Int64
        if let truncationSize = self.truncationSize {
            maxValue = truncationSize
        } else {
            maxValue = Int64.max
        }
        let clippedUpperBound = min(maxValue, range.upperBound)
        let clippedRange: Range<Int64> = min(range.lowerBound, clippedUpperBound) ..< clippedUpperBound
        let clippedRangeSet = RangeSet<Int64>(clippedRange)
        
        if self.ranges.isSuperset(of: clippedRangeSet) {
            return clippedRange
        } else {
            return nil
        }
    }
}

private class MediaBoxPartialFileDataRequest {
    let range: Range<Int64>
    var waitingUntilAfterInitialFetch: Bool
    let completion: (MediaResourceData) -> Void
    
    init(range: Range<Int64>, waitingUntilAfterInitialFetch: Bool, completion: @escaping (MediaResourceData) -> Void) {
        self.range = range
        self.waitingUntilAfterInitialFetch = waitingUntilAfterInitialFetch
        self.completion = completion
    }
}

final class MediaBoxPartialFile {
    private let queue: Queue
    private let manager: MediaBoxFileManager
    private let path: String
    private let metaPath: String
    private let completePath: String
    private let completed: (Int64) -> Void
    private let fd: MediaBoxFileManager.Item
    fileprivate let fileMap: MediaBoxFileMap
    private var dataRequests = Bag<MediaBoxPartialFileDataRequest>()
    private let missingRanges: MediaBoxFileMissingRanges
    private let rangeStatusRequests = Bag<((RangeSet<Int64>) -> Void, () -> Void)>()
    private let statusRequests = Bag<((MediaResourceStatus) -> Void, Int64?)>()
    
    private let fullRangeRequests = Bag<Disposable>()
    
    private var currentFetch: (Promise<[(Range<Int64>, MediaBoxFetchPriority)]>, Disposable)?
    private var processedAtLeastOneFetch: Bool = false
    
    init?(queue: Queue, manager: MediaBoxFileManager, path: String, metaPath: String, completePath: String, completed: @escaping (Int64) -> Void) {
        assert(queue.isCurrent())
        self.manager = manager
        if let fd = manager.open(path: path, mode: .readwrite) {
            self.queue = queue
            self.path = path
            self.metaPath = metaPath
            self.completePath = completePath
            self.completed = completed
            self.fd = fd
            if let fileMap = try? MediaBoxFileMap.read(manager: manager, path: self.metaPath) {
                if !fileMap.ranges.isEmpty {
                    let upperBound = fileMap.ranges.ranges.last!.upperBound
                    if let actualSize = fileSize(path, useTotalFileAllocatedSize: false) {
                        if upperBound > actualSize {
                            self.fileMap = MediaBoxFileMap()
                        } else {
                            self.fileMap = fileMap
                        }
                    } else {
                        self.fileMap = MediaBoxFileMap()
                    }
                } else {
                    self.fileMap = fileMap
                }
            } else {
                self.fileMap = MediaBoxFileMap()
            }
            self.missingRanges = MediaBoxFileMissingRanges()
        } else {
            return nil
        }
    }
    
    deinit {
        self.currentFetch?.1.dispose()
    }
    
    static func extractPartialData(manager: MediaBoxFileManager, path: String, metaPath: String, range: Range<Int64>) -> Data? {
        guard let fd = ManagedFile(queue: nil, path: path, mode: .read) else {
            return nil
        }
        guard let fileMap = try? MediaBoxFileMap.read(manager: manager, path: metaPath) else {
            return nil
        }
        guard let clippedRange = fileMap.contains(range) else {
            return nil
        }
        fd.seek(position: Int64(clippedRange.lowerBound))
        return fd.readData(count: Int(clippedRange.upperBound - clippedRange.lowerBound))
    }
    
    var storedSize: Int64 {
        assert(self.queue.isCurrent())
        return self.fileMap.sum
    }
    
    func reset() {
        assert(self.queue.isCurrent())
        
        self.fileMap.reset()
        self.fileMap.serialize(manager: self.manager, to: self.metaPath)
        
        for request in self.dataRequests.copyItems() {
            request.completion(MediaResourceData(path: self.path, offset: request.range.lowerBound, size: 0, complete: false))
        }
        
        if let updatedRanges = self.missingRanges.reset(fileMap: self.fileMap) {
            self.updateRequestRanges(updatedRanges, fetch: nil)
        }
        
        if !self.rangeStatusRequests.isEmpty {
            let ranges = self.fileMap.ranges
            for (f, _) in self.rangeStatusRequests.copyItems() {
                f(ranges)
            }
        }
        
        self.updateStatuses()
    }
    
    func moveLocalFile(tempPath: String) {
        assert(self.queue.isCurrent())
        
        do {
            try FileManager.default.moveItem(atPath: tempPath, toPath: self.completePath)
            
            if let size = fileSize(self.completePath) {
                unlink(self.path)
                unlink(self.metaPath)
                
                for (_, completion) in self.missingRanges.clear() {
                    completion()
                }
                
                if let (_, disposable) = self.currentFetch {
                    self.currentFetch = nil
                    disposable.dispose()
                }
                
                for request in self.dataRequests.copyItems() {
                    request.completion(MediaResourceData(path: self.completePath, offset: request.range.lowerBound, size: max(0, size - request.range.lowerBound), complete: true))
                }
                self.dataRequests.removeAll()
                
                for statusRequest in self.statusRequests.copyItems() {
                    statusRequest.0(.Local)
                }
                self.statusRequests.removeAll()
                
                self.completed(self.fileMap.sum)
            } else {
                assertionFailure()
            }
        } catch let e {
            postboxLog("moveLocalFile error: \(e)")
            assertionFailure()
        }
    }
    
    func copyLocalItem(_ item: MediaResourceDataFetchCopyLocalItem) {
        assert(self.queue.isCurrent())
        
        do {
            if item.copyTo(url: URL(fileURLWithPath: self.completePath)) {
                
            } else {
                return
            }
            
            if let size = fileSize(self.completePath) {
                unlink(self.path)
                unlink(self.metaPath)
                
                for (_, completion) in self.missingRanges.clear() {
                    completion()
                }
                
                if let (_, disposable) = self.currentFetch {
                    self.currentFetch = nil
                    disposable.dispose()
                }
                
                for request in self.dataRequests.copyItems() {
                    request.completion(MediaResourceData(path: self.completePath, offset: request.range.lowerBound, size: max(0, size - request.range.lowerBound), complete: true))
                }
                self.dataRequests.removeAll()
                
                for statusRequest in self.statusRequests.copyItems() {
                    statusRequest.0(.Local)
                }
                self.statusRequests.removeAll()
                
                self.completed(size)
            } else {
                assertionFailure()
            }
        }
    }
    
    func truncate(_ size: Int64) {
        assert(self.queue.isCurrent())
        
        let range: Range<Int64> = size ..< Int64.max
        
        self.fileMap.truncate(size)
        self.fileMap.serialize(manager: self.manager, to: self.metaPath)
        
        self.checkDataRequestsAfterFill(range: range)
    }
    
    func progressUpdated(_ progress: Float) {
        assert(self.queue.isCurrent())
        
        self.fileMap.progressUpdated(progress)
        self.updateStatuses()
    }
    
    func write(offset: Int64, data: Data, dataRange: Range<Int64>) {
        assert(self.queue.isCurrent())
        
        do {
            try self.fd.access { fd in
                fd.seek(position: offset)
                let written = data.withUnsafeBytes { rawBytes -> Int in
                    let bytes = rawBytes.baseAddress!.assumingMemoryBound(to: UInt8.self)

                    return fd.write(bytes.advanced(by: Int(dataRange.lowerBound)), count: dataRange.count)
                }
                assert(written == dataRange.count)
            }
        } catch let e {
            postboxLog("MediaBoxPartialFile.write error: \(e)")
        }
        
        let range: Range<Int64> = offset ..< (offset + Int64(dataRange.count))
        self.fileMap.fill(range)
        self.fileMap.serialize(manager: self.manager, to: self.metaPath)
        
        self.checkDataRequestsAfterFill(range: range)
    }
    
    func checkDataRequestsAfterFill(range: Range<Int64>) {
        var removeIndices: [(Int, MediaBoxPartialFileDataRequest)] = []
        for (index, request) in self.dataRequests.copyItemsWithIndices() {
            if request.range.overlaps(range) {
                var maxValue = request.range.upperBound
                if let truncationSize = self.fileMap.truncationSize {
                    maxValue = truncationSize
                }
                if request.range.lowerBound > maxValue {
                    assertionFailure()
                    removeIndices.append((index, request))
                } else {
                    let intRange: Range<Int64> = request.range.lowerBound ..< min(maxValue, request.range.upperBound)
                    if self.fileMap.ranges.isSuperset(of: RangeSet<Int64>(intRange)) {
                        removeIndices.append((index, request))
                    }
                }
            }
        }
        if !removeIndices.isEmpty {
            for (index, request) in removeIndices {
                self.dataRequests.remove(index)
                var maxValue = request.range.upperBound
                if let truncationSize = self.fileMap.truncationSize, truncationSize < maxValue {
                    maxValue = truncationSize
                }
                request.completion(MediaResourceData(path: self.path, offset: request.range.lowerBound, size: maxValue - request.range.lowerBound, complete: true))
            }
        }
        
        var isCompleted = false
        if let truncationSize = self.fileMap.truncationSize, let _ = self.fileMap.contains(0 ..< truncationSize) {
            isCompleted = true
        }
        
        if isCompleted {
            for (_, completion) in self.missingRanges.clear() {
                completion()
            }
        } else {
            if let (updatedRanges, completions) = self.missingRanges.fill(range) {
                self.updateRequestRanges(updatedRanges, fetch: nil)
                completions.forEach({ $0() })
            }
        }
        
        if !self.rangeStatusRequests.isEmpty {
            let ranges = self.fileMap.ranges
            for (f, completed) in self.rangeStatusRequests.copyItems() {
                f(ranges)
                if isCompleted {
                    completed()
                }
            }
            if isCompleted {
                self.rangeStatusRequests.removeAll()
            }
        }
        
        self.updateStatuses()
        
        if isCompleted {
            for statusRequest in self.statusRequests.copyItems() {
                statusRequest.0(.Local)
            }
            self.statusRequests.removeAll()
            self.fd.sync()
            let linkResult = link(self.path, self.completePath)
            if linkResult != 0 {
                //assert(linkResult == 0)
            }
            self.completed(self.fileMap.sum)
        }
    }
    
    func read(range: Range<Int64>) -> Data? {
        assert(self.queue.isCurrent())
        
        if let actualRange = self.fileMap.contains(range) {
            do {
                var result: Data?
                try self.fd.access { fd in
                    fd.seek(position: Int64(actualRange.lowerBound))
                    var data = Data(count: actualRange.count)
                    let dataCount = data.count
                    let readBytes = data.withUnsafeMutableBytes { rawBytes -> Int in
                        let bytes = rawBytes.baseAddress!.assumingMemoryBound(to: Int8.self)
                        return fd.read(bytes, dataCount)
                    }
                    if readBytes == data.count {
                        result = data
                    } else {
                        result = nil
                    }
                }
                return result
            } catch let e {
                postboxLog("MediaBoxPartialFile.read error: \(e)")
                return nil
            }
        } else {
            return nil
        }
    }
    
    func data(range: Range<Int64>, waitUntilAfterInitialFetch: Bool, next: @escaping (MediaResourceData) -> Void) -> Disposable {
        assert(self.queue.isCurrent())
        
        if let actualRange = self.fileMap.contains(range) {
            next(MediaResourceData(path: self.path, offset: actualRange.lowerBound, size: Int64(actualRange.count), complete: true))
            return EmptyDisposable
        }
        
        var waitingUntilAfterInitialFetch = false
        if waitUntilAfterInitialFetch && !self.processedAtLeastOneFetch {
            waitingUntilAfterInitialFetch = true
        } else {
            next(MediaResourceData(path: self.path, offset: range.lowerBound, size: 0, complete: false))
        }
        
        let index = self.dataRequests.add(MediaBoxPartialFileDataRequest(range: range, waitingUntilAfterInitialFetch: waitingUntilAfterInitialFetch, completion: { data in
            next(data)
        }))
        
        let queue = self.queue
        return ActionDisposable { [weak self] in
            queue.async {
                if let strongSelf = self {
                    strongSelf.dataRequests.remove(index)
                }
            }
        }
    }
    
    func fetched(range: Range<Int64>, priority: MediaBoxFetchPriority, fetch: @escaping (Signal<[(Range<Int64>, MediaBoxFetchPriority)], NoError>) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError>, error: @escaping (MediaResourceDataFetchError) -> Void, completed: @escaping () -> Void) -> Disposable {
        assert(self.queue.isCurrent())
        
        if let _ = self.fileMap.contains(range) {
            completed()
            return EmptyDisposable
        }
        
        let (index, updatedRanges) = self.missingRanges.addRequest(fileMap: self.fileMap, range: range, priority: priority, error: error, completion: {
            completed()
        })
        if let updatedRanges = updatedRanges {
            self.updateRequestRanges(updatedRanges, fetch: fetch)
        }
        
        let queue = self.queue
        return ActionDisposable { [weak self] in
            queue.async {
                if let strongSelf = self {
                    if let updatedRanges = strongSelf.missingRanges.removeRequest(fileMap: strongSelf.fileMap, index: index) {
                        strongSelf.updateRequestRanges(updatedRanges, fetch: nil)
                    }
                }
            }
        }
    }
    
    func fetchedFullRange(fetch: @escaping (Signal<[(Range<Int64>, MediaBoxFetchPriority)], NoError>) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError>, error: @escaping (MediaResourceDataFetchError) -> Void, completed: @escaping () -> Void) -> Disposable {
        let queue = self.queue
        let disposable = MetaDisposable()
        
        let index = self.fullRangeRequests.add(disposable)
        self.updateStatuses()
        
        disposable.set(self.fetched(range: 0 ..< Int64.max, priority: .default, fetch: fetch, error: { e in
            error(e)
        }, completed: { [weak self] in
            queue.async {
                if let strongSelf = self {
                    strongSelf.fullRangeRequests.remove(index)
                    if strongSelf.fullRangeRequests.isEmpty {
                        strongSelf.updateStatuses()
                    }
                }
                completed()
            }
        }))
        
        return ActionDisposable { [weak self] in
            queue.async {
                if let strongSelf = self {
                    strongSelf.fullRangeRequests.remove(index)
                    disposable.dispose()
                    if strongSelf.fullRangeRequests.isEmpty {
                        strongSelf.updateStatuses()
                    }
                }
            }
        }
    }
    
    func cancelFullRangeFetches() {
        self.fullRangeRequests.copyItems().forEach({ $0.dispose() })
        self.fullRangeRequests.removeAll()
        
        self.updateStatuses()
    }
    
    private func updateStatuses() {
        if !self.statusRequests.isEmpty {
            for (f, size) in self.statusRequests.copyItems() {
                let status = self.immediateStatus(size: size)
                f(status)
            }
        }
    }
    
    func rangeStatus(next: @escaping (RangeSet<Int64>) -> Void, completed: @escaping () -> Void) -> Disposable {
        assert(self.queue.isCurrent())
        
        next(self.fileMap.ranges)
        if let truncationSize = self.fileMap.truncationSize, let _ = self.fileMap.contains(0 ..< truncationSize) {
            completed()
            return EmptyDisposable
        }
        
        let index = self.rangeStatusRequests.add((next, completed))
        
        let queue = self.queue
        return ActionDisposable { [weak self] in
            queue.async {
                if let strongSelf = self {
                    strongSelf.rangeStatusRequests.remove(index)
                }
            }
        }
    }
    
    private func immediateStatus(size: Int64?) -> MediaResourceStatus {
        let status: MediaResourceStatus
        if self.fullRangeRequests.isEmpty && self.currentFetch == nil {
            if let truncationSize = self.fileMap.truncationSize, self.fileMap.sum == truncationSize {
                status = .Local
            } else {
                let progress: Float
                if let truncationSize = self.fileMap.truncationSize, truncationSize != 0 {
                    progress = Float(self.fileMap.sum) / Float(truncationSize)
                } else if let size = size {
                    progress = Float(self.fileMap.sum) / Float(size)
                } else {
                    progress = self.fileMap.progress ?? 0.0
                }
                status = .Remote(progress: progress)
            }
        } else {
            let progress: Float
            if let truncationSize = self.fileMap.truncationSize, truncationSize != 0 {
                progress = Float(self.fileMap.sum) / Float(truncationSize)
            } else if let size = size {
                progress = Float(self.fileMap.sum) / Float(size)
            } else {
                progress = self.fileMap.progress ?? 0.0
            }
            status = .Fetching(isActive: true, progress: progress)
        }
        return status
    }
    
    func status(next: @escaping (MediaResourceStatus) -> Void, completed: @escaping () -> Void, size: Int64?) -> Disposable {
        let index = self.statusRequests.add((next, size))
        
        let value = self.immediateStatus(size: size)
        next(value)
        if case .Local = value {
            completed()
            return EmptyDisposable
        } else {
            let queue = self.queue
            return ActionDisposable { [weak self] in
                queue.async {
                    if let strongSelf = self {
                        strongSelf.statusRequests.remove(index)
                    }
                }
            }
        }
    }
    
    private func updateRequestRanges(_ intervals: [(Range<Int64>, MediaBoxFetchPriority)], fetch: ((Signal<[(Range<Int64>, MediaBoxFetchPriority)], NoError>) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError>)?) {
        assert(self.queue.isCurrent())
        
        #if DEBUG
        for interval in intervals {
            assert(!interval.0.isEmpty)
        }
        #endif
        if intervals.isEmpty {
            if let (_, disposable) = self.currentFetch {
                self.currentFetch = nil
                self.updateStatuses()
                disposable.dispose()
            }
        } else {
            if let (promise, _) = self.currentFetch {
                promise.set(.single(intervals))
            } else if let fetch = fetch {
                let promise = Promise<[(Range<Int64>, MediaBoxFetchPriority)]>()
                let disposable = MetaDisposable()
                self.currentFetch = (promise, disposable)
                self.updateStatuses()
                disposable.set((fetch(promise.get())
                |> deliverOn(self.queue)).start(next: { [weak self] data in
                    if let strongSelf = self {
                        switch data {
                            case .reset:
                                if !strongSelf.fileMap.ranges.isEmpty {
                                    strongSelf.reset()
                                }
                            case let .resourceSizeUpdated(size):
                                strongSelf.truncate(size)
                            case let .dataPart(resourceOffset, data, range, complete):
                                if !data.isEmpty {
                                    strongSelf.write(offset: resourceOffset, data: data, dataRange: range)
                                }
                                if complete {
                                    if let maxOffset = strongSelf.fileMap.ranges.ranges.reversed().first?.upperBound {
                                        let maxValue = max(resourceOffset + Int64(range.count), Int64(maxOffset))
                                        strongSelf.truncate(maxValue)
                                    }
                                }
                            case let .replaceHeader(data, range):
                                strongSelf.write(offset: 0, data: data, dataRange: range)
                            case let .moveLocalFile(path):
                                strongSelf.moveLocalFile(tempPath: path)
                            case let .moveTempFile(file):
                                strongSelf.moveLocalFile(tempPath: file.path)
                                TempBox.shared.dispose(file)
                            case let .copyLocalItem(item):
                                strongSelf.copyLocalItem(item)
                            case let .progressUpdated(progress):
                                strongSelf.progressUpdated(progress)
                        }
                        if !strongSelf.processedAtLeastOneFetch {
                            strongSelf.processedAtLeastOneFetch = true
                            for request in strongSelf.dataRequests.copyItems() {
                                if request.waitingUntilAfterInitialFetch {
                                    request.waitingUntilAfterInitialFetch = false
                                    
                                    if let actualRange = strongSelf.fileMap.contains(request.range) {
                                        request.completion(MediaResourceData(path: strongSelf.path, offset: actualRange.lowerBound, size: Int64(actualRange.count), complete: true))
                                    } else {
                                        request.completion(MediaResourceData(path: strongSelf.path, offset: request.range.lowerBound, size: 0, complete: false))
                                    }
                                }
                            }
                        }
                    }
                }, error: { [weak self] e in
                    guard let strongSelf = self else {
                        return
                    }
                    for (error, _) in strongSelf.missingRanges.clear() {
                        error(e)
                    }
                }))
                promise.set(.single(intervals))
            }
        }
    }
}

private final class MediaBoxFileMissingRange {
    var range: Range<Int64>
    let priority: MediaBoxFetchPriority
    var remainingRanges: RangeSet<Int64>
    let error: (MediaResourceDataFetchError) -> Void
    let completion: () -> Void
    
    init(range: Range<Int64>, priority: MediaBoxFetchPriority, error: @escaping (MediaResourceDataFetchError) -> Void, completion: @escaping () -> Void) {
        self.range = range
        self.priority = priority
        self.remainingRanges = RangeSet<Int64>(range)
        self.error = error
        self.completion = completion
    }
}

private final class MediaBoxFileMissingRanges {
    private var requestedRanges = Bag<MediaBoxFileMissingRange>()
    
    private var missingRangesFlattened = RangeSet<Int64>()
    private var missingRangesByPriority: [MediaBoxFetchPriority: RangeSet<Int64>] = [:]
    
    func clear() -> [((MediaResourceDataFetchError) -> Void, () -> Void)] {
        let errorsAndCompletions = self.requestedRanges.copyItems().map({ ($0.error, $0.completion) })
        self.requestedRanges.removeAll()
        return errorsAndCompletions
    }
    
    func reset(fileMap: MediaBoxFileMap) -> [(Range<Int64>, MediaBoxFetchPriority)]? {
        return self.update(fileMap: fileMap)
    }
    
    private func missingRequestedIntervals() -> [(Range<Int64>, MediaBoxFetchPriority)] {
        var intervalsByPriority: [MediaBoxFetchPriority: RangeSet<Int64>] = [:]
        var remainingIntervals = RangeSet<Int64>()
        for item in self.requestedRanges.copyItems() {
            var requestedInterval = RangeSet<Int64>(item.range)
            requestedInterval.formIntersection(self.missingRangesFlattened)
            if !requestedInterval.isEmpty {
                if intervalsByPriority[item.priority] == nil {
                    intervalsByPriority[item.priority] = RangeSet<Int64>()
                }
                intervalsByPriority[item.priority]?.formUnion(requestedInterval)
                remainingIntervals.formUnion(requestedInterval)
            }
        }
        
        var result: [(Range<Int64>, MediaBoxFetchPriority)] = []
        
        for priority in intervalsByPriority.keys.sorted(by: { $0.rawValue > $1.rawValue }) {
            let currentIntervals = intervalsByPriority[priority]!.intersection(remainingIntervals)
            remainingIntervals.subtract(currentIntervals)
            for range in currentIntervals.ranges {
                if !range.isEmpty {
                    result.append((range, priority))
                }
            }
        }
        
        return result
    }
    
    func fill(_ range: Range<Int64>) -> ([(Range<Int64>, MediaBoxFetchPriority)], [() -> Void])? {
        if self.missingRangesFlattened.intersects(range) {
            self.missingRangesFlattened.remove(contentsOf: range)
            for priority in self.missingRangesByPriority.keys {
                self.missingRangesByPriority[priority]!.remove(contentsOf: range)
            }
            
            var completions: [() -> Void] = []
            for (index, item) in self.requestedRanges.copyItemsWithIndices() {
                if item.range.overlaps(range) {
                    item.remainingRanges.remove(contentsOf: range)
                    if item.remainingRanges.isEmpty {
                        self.requestedRanges.remove(index)
                        completions.append(item.completion)
                    }
                }
            }
            
            return (self.missingRequestedIntervals(), completions)
        } else {
            return nil
        }
    }
    
    func addRequest(fileMap: MediaBoxFileMap, range: Range<Int64>, priority: MediaBoxFetchPriority, error: @escaping (MediaResourceDataFetchError) -> Void, completion: @escaping () -> Void) -> (Int, [(Range<Int64>, MediaBoxFetchPriority)]?) {
        let index = self.requestedRanges.add(MediaBoxFileMissingRange(range: range, priority: priority, error: error, completion: completion))
        
        return (index, self.update(fileMap: fileMap))
    }
    
    func removeRequest(fileMap: MediaBoxFileMap, index: Int) -> [(Range<Int64>, MediaBoxFetchPriority)]? {
        self.requestedRanges.remove(index)
        return self.update(fileMap: fileMap)
    }
    
    private func update(fileMap: MediaBoxFileMap) -> [(Range<Int64>, MediaBoxFetchPriority)]? {
        var byPriority: [MediaBoxFetchPriority: RangeSet<Int64>] = [:]
        var flattened = RangeSet<Int64>()
        for item in self.requestedRanges.copyItems() {
            let intRange: Range<Int64> = item.range
            if byPriority[item.priority] == nil {
                byPriority[item.priority] = RangeSet<Int64>()
            }
            byPriority[item.priority]!.insert(contentsOf: intRange)
            flattened.insert(contentsOf: intRange)
        }
        for priority in byPriority.keys {
            byPriority[priority]!.subtract(fileMap.ranges)
        }
        flattened.subtract(fileMap.ranges)
        if byPriority != self.missingRangesByPriority {
            self.missingRangesByPriority = byPriority
            self.missingRangesFlattened = flattened
            
            return self.missingRequestedIntervals()
        }
        return nil
    }
}

private enum MediaBoxFileContent {
    case complete(String, Int64)
    case partial(MediaBoxPartialFile)
}

final class MediaBoxFileContext {
    private let queue: Queue
    private let path: String
    private let partialPath: String
    private let metaPath: String
    
    private var content: MediaBoxFileContent
    
    private let references = CounterBag()
    
    var isEmpty: Bool {
        return self.references.isEmpty
    }
    
    init?(queue: Queue, manager: MediaBoxFileManager, path: String, partialPath: String, metaPath: String) {
        assert(queue.isCurrent())
        
        self.queue = queue
        self.path = path
        self.partialPath = partialPath
        self.metaPath = metaPath
        
        var completeImpl: ((Int64) -> Void)?
        if let size = fileSize(path) {
            self.content = .complete(path, size)
        } else if let file = MediaBoxPartialFile(queue: queue, manager: manager, path: partialPath, metaPath: metaPath, completePath: path, completed: { size in
            completeImpl?(size)
        }) {
            self.content = .partial(file)
            completeImpl = { [weak self] size in
                queue.async {
                    if let strongSelf = self {
                        strongSelf.content = .complete(path, size)
                    }
                }
            }
        } else {
            return nil
        }
    }
    
    deinit {
        assert(self.queue.isCurrent())
    }
    
    func addReference() -> Int {
        return self.references.add()
    }
    
    func removeReference(_ index: Int) {
        self.references.remove(index)
    }
    
    func data(range: Range<Int64>, waitUntilAfterInitialFetch: Bool, next: @escaping (MediaResourceData) -> Void) -> Disposable {
        switch self.content {
            case let .complete(path, size):
                var lowerBound = range.lowerBound
                if lowerBound < 0 {
                    lowerBound = 0
                }
                if lowerBound > size {
                    lowerBound = size
                }
                var upperBound = range.upperBound
                if upperBound < 0 {
                    upperBound = 0
                }
                if upperBound > size {
                    upperBound = size
                }
                if upperBound < lowerBound {
                    upperBound = lowerBound
                }
                
                next(MediaResourceData(path: path, offset: lowerBound, size: upperBound - lowerBound, complete: true))
                return EmptyDisposable
            case let .partial(file):
                return file.data(range: range, waitUntilAfterInitialFetch: waitUntilAfterInitialFetch, next: next)
        }
    }
    
    func fetched(range: Range<Int64>, priority: MediaBoxFetchPriority, fetch: @escaping (Signal<[(Range<Int64>, MediaBoxFetchPriority)], NoError>) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError>, error: @escaping (MediaResourceDataFetchError) -> Void, completed: @escaping () -> Void) -> Disposable {
        switch self.content {
            case .complete:
                completed()
                return EmptyDisposable
            case let .partial(file):
                return file.fetched(range: range, priority: priority, fetch: fetch, error: error, completed: completed)
        }
    }
    
    func fetchedFullRange(fetch: @escaping (Signal<[(Range<Int64>, MediaBoxFetchPriority)], NoError>) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError>, error: @escaping (MediaResourceDataFetchError) -> Void, completed: @escaping () -> Void) -> Disposable {
        switch self.content {
            case .complete:
                return EmptyDisposable
            case let .partial(file):
                return file.fetchedFullRange(fetch: fetch, error: error, completed: completed)
        }
    }
    
    func cancelFullRangeFetches() {
        switch self.content {
            case .complete:
                break
            case let .partial(file):
                file.cancelFullRangeFetches()
        }
    }
    
    func rangeStatus(next: @escaping (RangeSet<Int64>) -> Void, completed: @escaping () -> Void) -> Disposable {
        switch self.content {
            case let .complete(_, size):
                next(RangeSet<Int64>(0 ..< size))
                completed()
                return EmptyDisposable
            case let .partial(file):
                return file.rangeStatus(next: next, completed: completed)
        }
    }
    
    func status(next: @escaping (MediaResourceStatus) -> Void, completed: @escaping () -> Void, size: Int64?) -> Disposable {
        switch self.content {
            case .complete:
                next(.Local)
                return EmptyDisposable
            case let .partial(file):
                return file.status(next: next, completed: completed, size: size)
        }
    }
}
