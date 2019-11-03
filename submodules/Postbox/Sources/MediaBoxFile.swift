import Foundation
import SwiftSignalKit

import Crc32


private final class MediaBoxFileMap {
    fileprivate(set) var sum: Int32
    private(set) var ranges: IndexSet
    private(set) var truncationSize: Int32?
    private(set) var progress: Float?

    init() {
        self.sum = 0
        self.ranges = IndexSet()
        self.truncationSize = nil
        self.progress = nil
    }
    
    init?(fd: ManagedFile) {
        guard let length = fd.getSize() else {
            return nil
        }
        
        var crc: UInt32 = 0
        var count: Int32 = 0
        var sum: Int32 = 0
        var ranges: IndexSet = IndexSet()
        
        guard fd.read(&crc, 4) == 4 else {
            return nil
        }
        guard fd.read(&count, 4) == 4 else {
            return nil
        }
        
        if count < 0 {
            return nil
        }
        
        if count < 0 || length < 4 + 4 + count * 2 * 4 {
            return nil
        }
        
        var truncationSizeValue: Int32 = 0
        
        var data = Data(count: Int(4 + count * 2 * 4))
        let dataCount = data.count
        if !(data.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<UInt8>) -> Bool in
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
                
                ranges.insert(integersIn: Int(intervalOffset) ..< Int(intervalOffset + intervalLength))
                
                sum += intervalLength
            }
            
            return true
        }) {
            return nil
        }

        self.sum = sum
        self.ranges = ranges
        if truncationSizeValue == -1 {
            self.truncationSize = nil
        } else {
            self.truncationSize = truncationSizeValue
        }
    }
    
    func serialize(to file: ManagedFile) {
        file.seek(position: 0)
        let buffer = WriteBuffer()
        var zero: Int32 = 0
        buffer.write(&zero, offset: 0, length: 4)
        
        let rangeView = self.ranges.rangeView
        var count: Int32 = Int32(rangeView.count)
        buffer.write(&count, offset: 0, length: 4)
        
        var truncationSizeValue: Int32 = self.truncationSize ?? -1
        buffer.write(&truncationSizeValue, offset: 0, length: 4)
        
        for range in rangeView {
            var intervalOffset = Int32(range.lowerBound)
            var intervalLength = Int32(range.count)
            buffer.write(&intervalOffset, offset: 0, length: 4)
            buffer.write(&intervalLength, offset: 0, length: 4)
        }
        var crc: UInt32 = Crc32(buffer.memory.advanced(by: 4 * 2), Int32(buffer.length - 4 * 2))
        memcpy(buffer.memory, &crc, 4)
        let written = file.write(buffer.memory, count: buffer.length)
        assert(written == buffer.length)
    }
    
    fileprivate func fill(_ range: Range<Int32>) {
        let intRange: Range<Int> = Int(range.lowerBound) ..< Int(range.upperBound)
        let previousCount = self.ranges.count(in: intRange)
        self.ranges.insert(integersIn: intRange)
        self.sum += Int32(range.count - previousCount)
    }
    
    fileprivate func truncate(_ size: Int32) {
        self.truncationSize = size
    }
    fileprivate func progressUpdated(_ progress: Float) {
        self.progress = progress
    }
    
    fileprivate func reset() {
        self.truncationSize = nil
        self.ranges.removeAll()
        self.sum = 0
        self.progress = nil
    }
    
    fileprivate func contains(_ range: Range<Int32>) -> Bool {
        let maxValue: Int
        if let truncationSize = self.truncationSize {
            maxValue = Int(truncationSize)
        } else {
            maxValue = Int.max
        }
        let intRange: Range<Int> = Int(range.lowerBound) ..< min(maxValue, Int(range.upperBound))
        return self.ranges.contains(integersIn: intRange)
    }
}

private class MediaBoxPartialFileDataRequest {
    let range: Range<Int32>
    var waitingUntilAfterInitialFetch: Bool
    let completion: (MediaResourceData) -> Void
    
    init(range: Range<Int32>, waitingUntilAfterInitialFetch: Bool, completion: @escaping (MediaResourceData) -> Void) {
        self.range = range
        self.waitingUntilAfterInitialFetch = waitingUntilAfterInitialFetch
        self.completion = completion
    }
}

final class MediaBoxPartialFile {
    private let queue: Queue
    private let path: String
    private let metaPath: String
    private let completePath: String
    private let completed: (Int32) -> Void
    private let metadataFd: ManagedFile
    private let fd: ManagedFile
    fileprivate let fileMap: MediaBoxFileMap
    private var dataRequests = Bag<MediaBoxPartialFileDataRequest>()
    private let missingRanges: MediaBoxFileMissingRanges
    private let rangeStatusRequests = Bag<((IndexSet) -> Void, () -> Void)>()
    private let statusRequests = Bag<((MediaResourceStatus) -> Void, Int32?)>()
    
    private let fullRangeRequests = Bag<Disposable>()
    
    private var currentFetch: (Promise<[(Range<Int>, MediaBoxFetchPriority)]>, Disposable)?
    private var processedAtLeastOneFetch: Bool = false
    
    init?(queue: Queue, path: String, metaPath: String, completePath: String, completed: @escaping (Int32) -> Void) {
        assert(queue.isCurrent())
        if let metadataFd = ManagedFile(queue: queue, path: metaPath, mode: .readwrite), let fd = ManagedFile(queue: queue, path: path, mode: .readwrite) {
            self.queue = queue
            self.path = path
            self.metaPath = metaPath
            self.completePath = completePath
            self.completed = completed
            self.metadataFd = metadataFd
            self.fd = fd
            if let fileMap = MediaBoxFileMap(fd: self.metadataFd) {
                if !fileMap.ranges.isEmpty {
                    let upperBound = fileMap.ranges[fileMap.ranges.endIndex]
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
    
    var storedSize: Int32 {
        assert(self.queue.isCurrent())
        return self.fileMap.sum
    }
    
    func reset() {
        assert(self.queue.isCurrent())
        
        self.fileMap.reset()
        self.fileMap.serialize(to: self.metadataFd)
        
        for request in self.dataRequests.copyItems() {
            request.completion(MediaResourceData(path: self.path, offset: Int(request.range.lowerBound), size: 0, complete: false))
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
                    request.completion(MediaResourceData(path: self.completePath, offset: Int(request.range.lowerBound), size: max(0, size - Int(request.range.lowerBound)), complete: true))
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
        } catch {
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
                    request.completion(MediaResourceData(path: self.completePath, offset: Int(request.range.lowerBound), size: max(0, size - Int(request.range.lowerBound)), complete: true))
                }
                self.dataRequests.removeAll()
                
                for statusRequest in self.statusRequests.copyItems() {
                    statusRequest.0(.Local)
                }
                self.statusRequests.removeAll()
                
                self.completed(Int32(size))
            } else {
                assertionFailure()
            }
        } catch {
            assertionFailure()
        }
    }
    
    func truncate(_ size: Int32) {
        assert(self.queue.isCurrent())
        
        let range: Range<Int32> = size ..< Int32.max
        
        self.fileMap.truncate(size)
        self.fileMap.serialize(to: self.metadataFd)
        
        self.checkDataRequestsAfterFill(range: range)
    }
    
    func progressUpdated(_ progress: Float) {
        assert(self.queue.isCurrent())
        
        self.fileMap.progressUpdated(progress)
        self.updateStatuses()
    }
    
    func write(offset: Int32, data: Data, dataRange: Range<Int>) {
        assert(self.queue.isCurrent())
        
        self.fd.seek(position: Int64(offset))
        let written = data.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> Int in
            return self.fd.write(bytes.advanced(by: dataRange.lowerBound), count: dataRange.count)
        }
        assert(written == dataRange.count)
        let range: Range<Int32> = offset ..< (offset + Int32(dataRange.count))
        self.fileMap.fill(range)
        self.fileMap.serialize(to: self.metadataFd)
        
        self.checkDataRequestsAfterFill(range: range)
    }
    
    func checkDataRequestsAfterFill(range: Range<Int32>) {
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
                    let intRange: Range<Int> = Int(request.range.lowerBound) ..< Int(min(maxValue, request.range.upperBound))
                    if self.fileMap.ranges.contains(integersIn: intRange) {
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
                request.completion(MediaResourceData(path: self.path, offset: Int(request.range.lowerBound), size: Int(maxValue) - Int(request.range.lowerBound), complete: true))
            }
        }
        
        var isCompleted = false
        if let truncationSize = self.fileMap.truncationSize, self.fileMap.contains(0 ..< truncationSize) {
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
    
    func read(range: Range<Int32>) -> Data? {
        assert(self.queue.isCurrent())
        
        if self.fileMap.contains(range) {
            self.fd.seek(position: Int64(range.lowerBound))
            var data = Data(count: range.count)
            let dataCount = data.count
            let readBytes = data.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<Int8>) -> Int in
                return self.fd.read(bytes, dataCount)
            }
            if readBytes == data.count {
                return data
            } else {
                return nil
            }
        } else {
            return nil
        }
    }
    
    func data(range: Range<Int32>, waitUntilAfterInitialFetch: Bool, next: @escaping (MediaResourceData) -> Void) -> Disposable {
        assert(self.queue.isCurrent())
        
        if self.fileMap.contains(range) {
            next(MediaResourceData(path: self.path, offset: Int(range.lowerBound), size: range.count, complete: true))
            return EmptyDisposable
        }
        
        var waitingUntilAfterInitialFetch = false
        if waitUntilAfterInitialFetch && !self.processedAtLeastOneFetch {
            waitingUntilAfterInitialFetch = true
        } else {
            next(MediaResourceData(path: self.path, offset: Int(range.lowerBound), size: 0, complete: false))
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
    
    func fetched(range: Range<Int32>, priority: MediaBoxFetchPriority, fetch: @escaping (Signal<[(Range<Int>, MediaBoxFetchPriority)], NoError>) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError>, error: @escaping (MediaResourceDataFetchError) -> Void, completed: @escaping () -> Void) -> Disposable {
        assert(self.queue.isCurrent())
        
        if self.fileMap.contains(range) {
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
    
    func fetchedFullRange(fetch: @escaping (Signal<[(Range<Int>, MediaBoxFetchPriority)], NoError>) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError>, error: @escaping (MediaResourceDataFetchError) -> Void, completed: @escaping () -> Void) -> Disposable {
        let queue = self.queue
        let disposable = MetaDisposable()
        
        let index = self.fullRangeRequests.add(disposable)
        self.updateStatuses()
        
        disposable.set(self.fetched(range: 0 ..< Int32.max, priority: .default, fetch: fetch, error: { e in
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
    
    func rangeStatus(next: @escaping (IndexSet) -> Void, completed: @escaping () -> Void) -> Disposable {
        assert(self.queue.isCurrent())
        
        next(self.fileMap.ranges)
        if let truncationSize = self.fileMap.truncationSize, self.fileMap.contains(0 ..< truncationSize) {
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
    
    private func immediateStatus(size: Int32?) -> MediaResourceStatus {
        let status: MediaResourceStatus
        if self.fullRangeRequests.isEmpty {
            if let truncationSize = self.fileMap.truncationSize, self.fileMap.sum == truncationSize {
                status = .Local
            } else {
                status = .Remote
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
    
    func status(next: @escaping (MediaResourceStatus) -> Void, completed: @escaping () -> Void, size: Int32?) -> Disposable {
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
    
    private func updateRequestRanges(_ intervals: [(Range<Int>, MediaBoxFetchPriority)], fetch: ((Signal<[(Range<Int>, MediaBoxFetchPriority)], NoError>) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError>)?) {
        assert(self.queue.isCurrent())
        
        #if DEBUG
        for interval in intervals {
            assert(!interval.0.isEmpty)
        }
        #endif
        if intervals.isEmpty {
            if let (_, disposable) = self.currentFetch {
                self.currentFetch = nil
                disposable.dispose()
            }
        } else {
            if let (promise, _) = self.currentFetch {
                promise.set(.single(intervals))
            } else if let fetch = fetch {
                let promise = Promise<[(Range<Int>, MediaBoxFetchPriority)]>()
                let disposable = MetaDisposable()
                self.currentFetch = (promise, disposable)
                disposable.set((fetch(promise.get())
                |> deliverOn(self.queue)).start(next: { [weak self] data in
                    if let strongSelf = self {
                        switch data {
                            case .reset:
                                if !strongSelf.fileMap.ranges.isEmpty {
                                    strongSelf.reset()
                                }
                            case let .resourceSizeUpdated(size):
                                strongSelf.truncate(Int32(size))
                            case let .dataPart(resourceOffset, data, range, complete):
                                if !data.isEmpty {
                                    strongSelf.write(offset: Int32(resourceOffset), data: data, dataRange: range)
                                }
                                if complete {
                                    if let maxOffset = strongSelf.fileMap.ranges.rangeView.reversed().first?.upperBound {
                                        let maxValue = max(resourceOffset + range.count, maxOffset)
                                        strongSelf.truncate(Int32(maxValue))
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
                                    
                                    if strongSelf.fileMap.contains(request.range) {
                                        request.completion(MediaResourceData(path: strongSelf.path, offset: Int(request.range.lowerBound), size: request.range.count, complete: true))
                                    } else {
                                        request.completion(MediaResourceData(path: strongSelf.path, offset: Int(request.range.lowerBound), size: 0, complete: false))
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
    var range: Range<Int32>
    let priority: MediaBoxFetchPriority
    var remainingRanges: IndexSet
    let error: (MediaResourceDataFetchError) -> Void
    let completion: () -> Void
    
    init(range: Range<Int32>, priority: MediaBoxFetchPriority, error: @escaping (MediaResourceDataFetchError) -> Void, completion: @escaping () -> Void) {
        self.range = range
        self.priority = priority
        let intRange: Range<Int> = Int(range.lowerBound) ..< Int(range.upperBound)
        self.remainingRanges = IndexSet(integersIn: intRange)
        self.error = error
        self.completion = completion
    }
}

private final class MediaBoxFileMissingRanges {
    private var requestedRanges = Bag<MediaBoxFileMissingRange>()
    
    private var missingRangesFlattened = IndexSet()
    private var missingRangesByPriority: [MediaBoxFetchPriority: IndexSet] = [:]
    
    func clear() -> [((MediaResourceDataFetchError) -> Void, () -> Void)] {
        let errorsAndCompletions = self.requestedRanges.copyItems().map({ ($0.error, $0.completion) })
        self.requestedRanges.removeAll()
        return errorsAndCompletions
    }
    
    func reset(fileMap: MediaBoxFileMap) -> [(Range<Int>, MediaBoxFetchPriority)]? {
        return self.update(fileMap: fileMap)
    }
    
    private func missingRequestedIntervals() -> [(Range<Int>, MediaBoxFetchPriority)] {
        var intervalsByPriority: [MediaBoxFetchPriority: IndexSet] = [:]
        var remainingIntervals = IndexSet()
        for item in self.requestedRanges.copyItems() {
            var requestedInterval = IndexSet(integersIn: Int(item.range.lowerBound) ..< Int(item.range.upperBound))
            requestedInterval.formIntersection(self.missingRangesFlattened)
            if !requestedInterval.isEmpty {
                if intervalsByPriority[item.priority] == nil {
                    intervalsByPriority[item.priority] = IndexSet()
                }
                intervalsByPriority[item.priority]?.formUnion(requestedInterval)
                remainingIntervals.formUnion(requestedInterval)
            }
        }
        
        var result: [(Range<Int>, MediaBoxFetchPriority)] = []
        
        for priority in intervalsByPriority.keys.sorted(by: { $0.rawValue > $1.rawValue }) {
            let currentIntervals = intervalsByPriority[priority]!.intersection(remainingIntervals)
            remainingIntervals.subtract(currentIntervals)
            for range in currentIntervals.rangeView {
                if !range.isEmpty {
                    result.append((range, priority))
                }
            }
        }
        
        return result
    }
    
    func fill(_ range: Range<Int32>) -> ([(Range<Int>, MediaBoxFetchPriority)], [() -> Void])? {
        let intRange: Range<Int> = Int(range.lowerBound) ..< Int(range.upperBound)
        if self.missingRangesFlattened.intersects(integersIn: intRange) {
            self.missingRangesFlattened.remove(integersIn: intRange)
            for priority in self.missingRangesByPriority.keys {
                self.missingRangesByPriority[priority]!.remove(integersIn: intRange)
            }
            
            var completions: [() -> Void] = []
            for (index, item) in self.requestedRanges.copyItemsWithIndices() {
                if item.range.overlaps(range) {
                    item.remainingRanges.remove(integersIn: intRange)
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
    
    func addRequest(fileMap: MediaBoxFileMap, range: Range<Int32>, priority: MediaBoxFetchPriority, error: @escaping (MediaResourceDataFetchError) -> Void, completion: @escaping () -> Void) -> (Int, [(Range<Int>, MediaBoxFetchPriority)]?) {
        let index = self.requestedRanges.add(MediaBoxFileMissingRange(range: range, priority: priority, error: error, completion: completion))
        
        return (index, self.update(fileMap: fileMap))
    }
    
    func removeRequest(fileMap: MediaBoxFileMap, index: Int) -> [(Range<Int>, MediaBoxFetchPriority)]? {
        self.requestedRanges.remove(index)
        return self.update(fileMap: fileMap)
    }
    
    private func update(fileMap: MediaBoxFileMap) -> [(Range<Int>, MediaBoxFetchPriority)]? {
        var byPriority: [MediaBoxFetchPriority: IndexSet] = [:]
        var flattened = IndexSet()
        for item in self.requestedRanges.copyItems() {
            let intRange: Range<Int> = Int(item.range.lowerBound) ..< Int(item.range.upperBound)
            if byPriority[item.priority] == nil {
                byPriority[item.priority] = IndexSet()
            }
            byPriority[item.priority]!.insert(integersIn: intRange)
            flattened.insert(integersIn: intRange)
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
    case complete(String, Int)
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
    
    init?(queue: Queue, path: String, partialPath: String, metaPath: String) {
        assert(queue.isCurrent())
        
        self.queue = queue
        self.path = path
        self.partialPath = partialPath
        self.metaPath = metaPath
        
        var completeImpl: ((Int32) -> Void)?
        if let size = fileSize(path) {
            self.content = .complete(path, size)
        } else if let file = MediaBoxPartialFile(queue: queue, path: partialPath, metaPath: metaPath, completePath: path, completed: { size in
            completeImpl?(size)
        }) {
            self.content = .partial(file)
            completeImpl = { [weak self] size in
                queue.async {
                    if let strongSelf = self {
                        strongSelf.content = .complete(path, Int(size))
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
    
    func data(range: Range<Int32>, waitUntilAfterInitialFetch: Bool, next: @escaping (MediaResourceData) -> Void) -> Disposable {
        switch self.content {
            case let .complete(path, size):
                next(MediaResourceData(path: path, offset: Int(range.lowerBound), size: min(Int(range.upperBound), size) - Int(range.lowerBound), complete: true))
                return EmptyDisposable
            case let .partial(file):
                return file.data(range: range, waitUntilAfterInitialFetch: waitUntilAfterInitialFetch, next: next)
        }
    }
    
    func fetched(range: Range<Int32>, priority: MediaBoxFetchPriority, fetch: @escaping (Signal<[(Range<Int>, MediaBoxFetchPriority)], NoError>) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError>, error: @escaping (MediaResourceDataFetchError) -> Void, completed: @escaping () -> Void) -> Disposable {
        switch self.content {
            case .complete:
                return EmptyDisposable
            case let .partial(file):
                return file.fetched(range: range, priority: priority, fetch: fetch, error: error, completed: completed)
        }
    }
    
    func fetchedFullRange(fetch: @escaping (Signal<[(Range<Int>, MediaBoxFetchPriority)], NoError>) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError>, error: @escaping (MediaResourceDataFetchError) -> Void, completed: @escaping () -> Void) -> Disposable {
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
    
    func rangeStatus(next: @escaping (IndexSet) -> Void, completed: @escaping () -> Void) -> Disposable {
        switch self.content {
            case let .complete(_, size):
                next(IndexSet(integersIn: 0 ..< size))
                completed()
                return EmptyDisposable
            case let .partial(file):
                return file.rangeStatus(next: next, completed: completed)
        }
    }
    
    func status(next: @escaping (MediaResourceStatus) -> Void, completed: @escaping () -> Void, size: Int32?) -> Disposable {
        switch self.content {
            case .complete:
                next(.Local)
                return EmptyDisposable
            case let .partial(file):
                return file.status(next: next, completed: completed, size: size)
        }
    }
}
