import Foundation
import RangeSet
import SwiftSignalKit

final class MediaBoxFileContextV2Impl: MediaBoxFileContext {
    private final class RangeRequest {
        let value: Range<Int64>
        let priority: MediaBoxFetchPriority
        let isFullRange: Bool
        let error: (MediaResourceDataFetchError) -> Void
        let completed: () -> Void
        
        init(
            value: Range<Int64>,
            priority: MediaBoxFetchPriority,
            isFullRange: Bool,
            error: @escaping (MediaResourceDataFetchError) -> Void,
            completed: @escaping () -> Void
        ) {
            self.value = value
            self.priority = priority
            self.isFullRange = isFullRange
            self.error = error
            self.completed = completed
        }
    }
    
    private final class StatusRequest {
        let size: Int64?
        let next: (MediaResourceStatus) -> Void
        let completed: () -> Void
        
        var reportedStatus: MediaResourceStatus?
        
        init(size: Int64?, next: @escaping (MediaResourceStatus) -> Void, completed: @escaping () -> Void) {
            self.size = size
            self.next = next
            self.completed = completed
        }
    }
    
    private final class PartialDataRequest {
        let range: Range<Int64>
        let next: (MediaResourceData) -> Void
        
        var waitingUntilAfterInitialFetch: Bool
        var reportedStatus: MediaResourceData?
        
        init(
            range: Range<Int64>,
            waitUntilAfterInitialFetch: Bool,
            next: @escaping (MediaResourceData) -> Void
        ) {
            self.range = range
            self.waitingUntilAfterInitialFetch = waitUntilAfterInitialFetch
            self.next = next
        }
    }
    
    private final class RangeStatusRequest {
        let next: (RangeSet<Int64>) -> Void
        let completed: () -> Void
        
        var reportedStatus: RangeSet<Int64>?
        
        init(
            next: @escaping (RangeSet<Int64>) -> Void,
            completed: @escaping () -> Void
        ) {
            self.next = next
            self.completed = completed
        }
    }
    
    private struct MaterializedRangeRequest: Equatable {
        let range: Range<Int64>
        let priority: MediaBoxFetchPriority
        
        init(
            range: Range<Int64>,
            priority: MediaBoxFetchPriority
        ) {
            self.range = range
            self.priority = priority
        }
    }
    
    private final class PendingFetch {
        let initialFilterRanges: RangeSet<Int64>
        let ranges = Promise<[(Range<Int64>, MediaBoxFetchPriority)]>()
        let disposable: Disposable
        
        init(initialFilterRanges: RangeSet<Int64>, disposable: Disposable) {
            self.initialFilterRanges = initialFilterRanges
            self.disposable = disposable
        }
    }
    
    private final class PartialState {
        private let queue: Queue
        private let manager: MediaBoxFileManager
        private let storageBox: StorageBox
        private let resourceId: Data
        private let partialPath: String
        private let fullPath: String
        private let metaPath: String
        
        private let destinationFile: MediaBoxFileManager.Item?
        
        private let fileMap: MediaBoxFileMap
        private var rangeRequests = Bag<RangeRequest>()
        private var statusRequests = Bag<StatusRequest>()
        private var rangeStatusRequests = Bag<RangeStatusRequest>()
        private var partialDataRequests = Bag<PartialDataRequest>()
        
        private var fetchImpl: ((Signal<[(Range<Int64>, MediaBoxFetchPriority)], NoError>) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError>)?
        
        private var materializedRangeRequests: [MaterializedRangeRequest] = []
        private var pendingFetch: PendingFetch?
        private var hasPerformedAnyFetch: Bool = false
        
        private var isComplete: Bool = false
        
        init(
            queue: Queue,
            manager: MediaBoxFileManager,
            storageBox: StorageBox,
            resourceId: Data,
            partialPath: String,
            fullPath: String,
            metaPath: String
        ) {
            self.queue = queue
            self.manager = manager
            self.storageBox = storageBox
            self.resourceId = resourceId
            self.partialPath = partialPath
            self.fullPath = fullPath
            self.metaPath = metaPath
            
            if !FileManager.default.fileExists(atPath: self.partialPath) {
                let _ = try? FileManager.default.removeItem(atPath: self.metaPath)
                self.fileMap = MediaBoxFileMap()
                self.fileMap.serialize(manager: self.manager, to: self.metaPath)
            } else {
                do {
                    self.fileMap = try MediaBoxFileMap.read(manager: self.manager, path: self.metaPath)
                } catch {
                    let _ = try? FileManager.default.removeItem(atPath: self.metaPath)
                    self.fileMap = MediaBoxFileMap()
                }
            }
            
            self.destinationFile = self.manager.open(path: self.partialPath, mode: .readwrite)
            
            if FileManager.default.fileExists(atPath: self.fullPath) {
                self.isComplete = true
            }
        }
        
        func request(
            range: Range<Int64>,
            isFullRange: Bool,
            priority: MediaBoxFetchPriority,
            fetch: @escaping (Signal<[(Range<Int64>, MediaBoxFetchPriority)], NoError>) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError>,
            error: @escaping (MediaResourceDataFetchError) -> Void,
            completed: @escaping () -> Void
        ) -> Disposable {
            assert(self.queue.isCurrent())
            
            self.fetchImpl = fetch
            
            let request = RangeRequest(
                value: range,
                priority: priority,
                isFullRange: isFullRange,
                error: error,
                completed: completed
            )
            if self.updateRangeRequest(request: request) {
                if !self.isComplete, let truncationSize = self.fileMap.truncationSize, truncationSize == self.fileMap.sum {
                    self.isComplete = true
                    
                    let linkResult = link(self.partialPath, self.fullPath)
                    if linkResult != 0 {
                        postboxLog("MediaBoxFileContextV2Impl: error while linking \(self.partialPath): \(linkResult)")
                    }
                }
                
                self.updateRequests()
                
                return EmptyDisposable
            } else {
                let index = self.rangeRequests.add(request)
                
                self.updateRequests()
                
                let queue = self.queue
                return ActionDisposable { [weak self] in
                    queue.async {
                        guard let `self` = self else {
                            return
                        }
                        self.rangeRequests.remove(index)
                        self.updateRequests()
                    }
                }
            }
        }
        
        func cancelFullRangeFetches() {
            for (index, rangeRequest) in self.rangeRequests.copyItemsWithIndices() {
                if rangeRequest.isFullRange {
                    self.rangeRequests.remove(index)
                }
            }
            self.updateRequests()
        }
        
        func status(next: @escaping (MediaResourceStatus) -> Void, completed: @escaping () -> Void, size: Int64?) -> Disposable {
            assert(self.queue.isCurrent())
            
            let request = StatusRequest(
                size: size,
                next: next,
                completed: completed
            )
            if self.updateStatusRequest(request: request) {
                return EmptyDisposable
            } else {
                let index = self.statusRequests.add(request)
                
                let queue = self.queue
                return ActionDisposable { [weak self] in
                    queue.async {
                        guard let `self` = self else {
                            return
                        }
                        self.statusRequests.remove(index)
                    }
                }
            }
        }
        
        func partialData(range: Range<Int64>, waitUntilAfterInitialFetch: Bool, next: @escaping (MediaResourceData) -> Void) -> Disposable {
            let request = PartialDataRequest(
                range: range,
                waitUntilAfterInitialFetch: waitUntilAfterInitialFetch && !self.hasPerformedAnyFetch,
                next: next
            )
            if self.updatePartialDataRequest(request: request) {
                return EmptyDisposable
            } else {
                let index = self.partialDataRequests.add(request)
                
                let queue = self.queue
                return ActionDisposable { [weak self] in
                    queue.async {
                        guard let `self` = self else {
                            return
                        }
                        self.partialDataRequests.remove(index)
                    }
                }
            }
        }
        
        func rangeStatus(
            next: @escaping (RangeSet<Int64>) -> Void,
            completed: @escaping () -> Void
        ) -> Disposable {
            assert(self.queue.isCurrent())
            
            let request = RangeStatusRequest(
                next: next,
                completed: completed
            )
            if self.updateRangeStatusRequest(request: request) {
                return EmptyDisposable
            } else {
                let index = self.rangeStatusRequests.add(request)
                
                let queue = self.queue
                return ActionDisposable { [weak self] in
                    queue.async {
                        guard let `self` = self else {
                            return
                        }
                        self.rangeStatusRequests.remove(index)
                    }
                }
            }
        }
        
        private func updateRequests() {
            var rangesByPriority: [MediaBoxFetchPriority: RangeSet<Int64>] = [:]
            for (index, rangeRequest) in self.rangeRequests.copyItemsWithIndices() {
                if self.updateRangeRequest(request: rangeRequest) {
                    self.rangeRequests.remove(index)
                    continue
                }
                
                if rangesByPriority[rangeRequest.priority] == nil {
                    rangesByPriority[rangeRequest.priority] = RangeSet()
                }
                rangesByPriority[rangeRequest.priority]?.formUnion(RangeSet<Int64>(rangeRequest.value))
            }
            
            let initialFilterRanges: RangeSet<Int64>
            if let current = self.pendingFetch {
                initialFilterRanges = current.initialFilterRanges
            } else {
                initialFilterRanges = self.fileMap.ranges
            }
            
            var materializedRangeRequests: [MaterializedRangeRequest] = []
            for (priority, ranges) in rangesByPriority.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
                let filteredRanges = ranges.subtracting(initialFilterRanges)
                for range in filteredRanges.ranges {
                    materializedRangeRequests.append(MaterializedRangeRequest(range: range, priority: priority))
                }
            }
            
            if self.materializedRangeRequests != materializedRangeRequests {
                self.materializedRangeRequests = materializedRangeRequests
                
                if !materializedRangeRequests.isEmpty {
                    if let fetchImpl = self.fetchImpl {
                        let pendingFetch: PendingFetch
                        if let current = self.pendingFetch {
                            pendingFetch = current
                        } else {
                            let disposable = MetaDisposable()
                            pendingFetch = PendingFetch(initialFilterRanges: initialFilterRanges, disposable: disposable)
                            self.pendingFetch = pendingFetch
                            self.hasPerformedAnyFetch = true
                            
                            let queue = self.queue
                            disposable.set(fetchImpl(pendingFetch.ranges.get()).start(next: { [weak self] result in
                                queue.async {
                                    guard let `self` = self else {
                                        return
                                    }
                                    self.processFetchResult(result: result)
                                }
                            }, error: { [weak self] error in
                                queue.async {
                                    guard let `self` = self else {
                                        return
                                    }
                                    self.processFetchError(error: error)
                                }
                            }))
                        }
                        pendingFetch.ranges.set(.single(materializedRangeRequests.map { request -> (Range<Int64>, MediaBoxFetchPriority) in
                            return (request.range, request.priority)
                        }))
                    }
                } else {
                    if let pendingFetch = self.pendingFetch {
                        self.pendingFetch = nil
                        pendingFetch.disposable.dispose()
                    }
                }
            }
            
            self.updateStatusRequests()
        }
        
        private func processFetchResult(result: MediaResourceDataFetchResult) {
            assert(self.queue.isCurrent())
            
            switch result {
            case let .dataPart(resourceOffset, data, dataRange, complete):
                self.processWrite(resourceOffset: resourceOffset, data: data, dataRange: dataRange)
                
                if complete {
                    if let maxOffset = self.fileMap.ranges.ranges.reversed().first?.upperBound {
                        let maxValue = max(resourceOffset + Int64(dataRange.count), Int64(maxOffset))
                        if self.fileMap.truncationSize != maxValue {
                            self.fileMap.truncate(maxValue)
                            self.fileMap.serialize(manager: self.manager, to: self.metaPath)
                        }
                    }
                }
            case let .resourceSizeUpdated(size):
                if self.fileMap.truncationSize != size {
                    self.fileMap.truncate(size)
                    self.fileMap.serialize(manager: self.manager, to: self.metaPath)
                }
            case let .progressUpdated(progress):
                self.fileMap.progressUpdated(progress)
                self.updateStatusRequests()
            case let .replaceHeader(data, range):
                self.processWrite(resourceOffset: 0, data: data, dataRange: range)
            case let .moveLocalFile(path):
                do {
                    try FileManager.default.moveItem(atPath: path, toPath: self.fullPath)
                    self.processMovedFile()
                } catch let e {
                    postboxLog("MediaBoxFileContextV2Impl: error moving temp file at \(self.fullPath): \(e)")
                }
            case let .moveTempFile(file):
                do {
                    try FileManager.default.moveItem(atPath: file.path, toPath: self.fullPath)
                    self.processMovedFile()
                } catch let e {
                    postboxLog("MediaBoxFileContextV2Impl: error moving temp file at \(self.fullPath): \(e)")
                }
                TempBox.shared.dispose(file)
            case let .copyLocalItem(localItem):
                do {
                    if localItem.copyTo(url: URL(fileURLWithPath: self.fullPath)) {
                        unlink(self.partialPath)
                        unlink(self.metaPath)
                    }
                    self.processMovedFile()
                }
            case .reset:
                if !self.fileMap.ranges.isEmpty {
                    self.fileMap.reset()
                    self.fileMap.serialize(manager: self.manager, to: self.metaPath)
                }
                
            }
            
            if !self.isComplete, let truncationSize = self.fileMap.truncationSize, truncationSize == self.fileMap.sum {
                self.isComplete = true
                
                let linkResult = link(self.partialPath, self.fullPath)
                if linkResult != 0 {
                    postboxLog("MediaBoxFileContextV2Impl: error while linking \(self.partialPath): \(linkResult)")
                }
            }
            
            self.updateRequests()
        }
        
        private func processWrite(resourceOffset: Int64, data: Data, dataRange: Range<Int64>) {
            if let destinationFile = self.destinationFile {
                do {
                    var success = true
                    try destinationFile.access { fd in
                        if fd.seek(position: resourceOffset) {
                            let written = data.withUnsafeBytes { rawBytes -> Int in
                                let bytes = rawBytes.baseAddress!.assumingMemoryBound(to: UInt8.self)
                                
                                return fd.write(bytes.advanced(by: Int(dataRange.lowerBound)), count: dataRange.count)
                            }
                            assert(written == dataRange.count)
                        } else {
                            success = false
                        }
                    }
                    if success {
                        let range: Range<Int64> = resourceOffset ..< (resourceOffset + Int64(dataRange.count))
                        self.fileMap.fill(range)
                        self.fileMap.serialize(manager: self.manager, to: self.metaPath)
                        
                        self.storageBox.update(id: self.resourceId, size: self.fileMap.sum)
                    } else {
                        postboxLog("MediaBoxFileContextV2Impl: error seeking file to \(resourceOffset) at \(self.partialPath)")
                    }
                } catch let e {
                    postboxLog("MediaBoxFileContextV2Impl: error writing file at \(self.partialPath): \(e)")
                }
            }
        }
        
        private func processMovedFile() {
            if let size = fileSize(self.fullPath) {
                self.isComplete = true
                self.storageBox.update(id: self.resourceId, size: size)
            }
        }
        
        private func processFetchError(error: MediaResourceDataFetchError) {
            assert(self.queue.isCurrent())
            
            let rangeRequests = self.rangeRequests.copyItems()
            self.rangeRequests.removeAll()
            
            self.statusRequests.removeAll()
            self.rangeStatusRequests.removeAll()
            
            //TODO:set status to .remote?
            
            for rangeRequest in rangeRequests {
                rangeRequest.error(error)
            }
        }
        
        private func updateRangeRequest(request: RangeRequest) -> Bool {
            assert(self.queue.isCurrent())
            
            if self.fileMap.contains(request.value) != nil {
                request.completed()
                return true
            } else {
                return false
            }
        }
        
        private func updateStatusRequests() {
            for (index, partialDataRequest) in self.partialDataRequests.copyItemsWithIndices() {
                if self.updatePartialDataRequest(request: partialDataRequest) {
                    self.partialDataRequests.remove(index)
                }
            }
            for (index, statusRequest) in self.statusRequests.copyItemsWithIndices() {
                if self.updateStatusRequest(request: statusRequest) {
                    self.statusRequests.remove(index)
                }
            }
            for (index, rangeStatusRequest) in self.rangeStatusRequests.copyItemsWithIndices() {
                if self.updateRangeStatusRequest(request: rangeStatusRequest) {
                    self.rangeStatusRequests.remove(index)
                }
            }
        }
        
        private func updatePartialDataRequest(request: PartialDataRequest) -> Bool {
            assert(self.queue.isCurrent())
            
            if self.isComplete, let size = fileSize(self.fullPath) {
                var clampedLowerBound = request.range.lowerBound
                var clampedUpperBound = request.range.upperBound
                if clampedUpperBound > size {
                    clampedUpperBound = size
                }
                if clampedLowerBound > clampedUpperBound {
                    clampedLowerBound = clampedUpperBound
                }
                
                let updatedStatus = MediaResourceData(path: self.fullPath, offset: clampedLowerBound, size: clampedUpperBound - clampedLowerBound, complete: true)
                if request.reportedStatus != updatedStatus {
                    request.reportedStatus = updatedStatus
                    request.next(updatedStatus)
                }
                return true
            } else if self.fileMap.contains(request.range) != nil {
                let updatedStatus = MediaResourceData(path: self.partialPath, offset: request.range.lowerBound, size: request.range.upperBound - request.range.lowerBound, complete: true)
                if request.reportedStatus != updatedStatus {
                    request.reportedStatus = updatedStatus
                    request.next(updatedStatus)
                }
                return true
            } else {
                let updatedStatus = MediaResourceData(path: self.partialPath, offset: request.range.lowerBound, size: 0, complete: false)
                if request.reportedStatus != updatedStatus {
                    if request.waitingUntilAfterInitialFetch {
                        if self.hasPerformedAnyFetch {
                            request.waitingUntilAfterInitialFetch = false
                            request.reportedStatus = updatedStatus
                            request.next(updatedStatus)
                        }
                    } else {
                        request.reportedStatus = updatedStatus
                        request.next(updatedStatus)
                    }
                }
                return false
            }
        }
        
        private func updateStatusRequest(request: StatusRequest) -> Bool {
            assert(self.queue.isCurrent())
            
            let updatedStatus: MediaResourceStatus
            if self.isComplete {
                updatedStatus = .Local
            } else if let totalSize = self.fileMap.truncationSize ?? request.size {
                let progress = Float(self.fileMap.sum) / Float(totalSize)
                if self.pendingFetch != nil {
                    updatedStatus = .Fetching(isActive: true, progress: progress)
                } else {
                    updatedStatus = .Remote(progress: progress)
                }
            } else if self.pendingFetch != nil {
                if let progress = self.fileMap.progress {
                    updatedStatus = .Fetching(isActive: true, progress: progress)
                } else {
                    updatedStatus = .Fetching(isActive: true, progress: 0.0)
                }
            } else {
                updatedStatus = .Remote(progress: 0.0)
            }
            
            if request.reportedStatus != updatedStatus {
                request.reportedStatus = updatedStatus
                request.next(updatedStatus)
            }
            
            return false
        }
        
        private func updateRangeStatusRequest(request: RangeStatusRequest) -> Bool {
            assert(self.queue.isCurrent())
            
            let status: RangeSet<Int64>
            if self.isComplete, let size = fileSize(self.fullPath) {
                status = RangeSet(0 ..< size)
            } else {
                status = self.fileMap.ranges
            }
            if request.reportedStatus != status {
                request.reportedStatus = status
                request.next(status)
                
                if let truncationSize = self.fileMap.truncationSize, self.fileMap.sum == truncationSize {
                    request.completed()
                    return true
                }
            }
            
            return false
        }
    }
    
    private let queue: Queue
    private let manager: MediaBoxFileManager
    private let storageBox: StorageBox
    private let resourceId: Data
    private let path: String
    private let partialPath: String
    private let metaPath: String
    
    private let references = Bag<Void>()
    
    private var partialState: PartialState?
    
    var isEmpty: Bool {
        return self.references.isEmpty
    }
    
    init?(
        queue: Queue,
        manager: MediaBoxFileManager,
        storageBox: StorageBox,
        resourceId: Data,
        path: String,
        partialPath: String,
        metaPath: String
    ) {
        self.queue = queue
        self.manager = manager
        self.storageBox = storageBox
        self.resourceId = resourceId
        self.path = path
        self.partialPath = partialPath
        self.metaPath = metaPath
    }
    
    func addReference() -> Int {
        assert(self.queue.isCurrent())
        return self.references.add(Void())
    }
    
    func removeReference(_ index: Int) {
        assert(self.queue.isCurrent())
        return self.references.remove(index)
    }
    
    private func withPartialState<T>(_ f: (PartialState) -> T) -> T {
        if let partialState = self.partialState {
            return f(partialState)
        } else {
            let partialState = PartialState(
                queue: self.queue,
                manager: self.manager,
                storageBox: self.storageBox,
                resourceId: self.resourceId,
                partialPath: self.partialPath,
                fullPath: self.path,
                metaPath: self.metaPath
            )
            self.partialState = partialState
            return f(partialState)
        }
    }
    
    func data(range: Range<Int64>, waitUntilAfterInitialFetch: Bool, next: @escaping (MediaResourceData) -> Void) -> Disposable {
        assert(self.queue.isCurrent())
        
        if let size = fileSize(self.path) {
            var clampedLowerBound = range.lowerBound
            var clampedUpperBound = range.upperBound
            if clampedUpperBound > size {
                clampedUpperBound = size
            }
            if clampedLowerBound > clampedUpperBound {
                clampedLowerBound = clampedUpperBound
            }
            next(MediaResourceData(path: self.path, offset: clampedLowerBound, size: clampedUpperBound - clampedLowerBound, complete: true))
            return EmptyDisposable
        } else {
            return self.withPartialState { partialState in
                return partialState.partialData(
                    range: range,
                    waitUntilAfterInitialFetch: waitUntilAfterInitialFetch,
                    next: next
                )
            }
        }
    }
    
    func fetched(
        range: Range<Int64>,
        priority: MediaBoxFetchPriority,
        fetch: @escaping (Signal<[(Range<Int64>, MediaBoxFetchPriority)], NoError>) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError>,
        error: @escaping (MediaResourceDataFetchError) -> Void,
        completed: @escaping () -> Void
    ) -> Disposable {
        assert(self.queue.isCurrent())
        
        if FileManager.default.fileExists(atPath: self.path) {
            completed()
            return EmptyDisposable
        } else {
            return self.withPartialState { partialState in
                return partialState.request(
                    range: range,
                    isFullRange: false,
                    priority: priority,
                    fetch: fetch,
                    error: error,
                    completed: completed
                )
            }
        }
    }
    
    func fetchedFullRange(
        fetch: @escaping (Signal<[(Range<Int64>, MediaBoxFetchPriority)], NoError>) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError>,
        error: @escaping (MediaResourceDataFetchError) -> Void,
        completed: @escaping () -> Void
    ) -> Disposable {
        assert(self.queue.isCurrent())
        
        if FileManager.default.fileExists(atPath: self.path) {
            completed()
            return EmptyDisposable
        } else {
            return self.withPartialState { partialState in
                return partialState.request(
                    range: 0 ..< Int64.max,
                    isFullRange: true,
                    priority: .default,
                    fetch: fetch,
                    error: error,
                    completed: completed
                )
            }
        }
    }
    
    func cancelFullRangeFetches() {
        assert(self.queue.isCurrent())
        
        if let partialState = self.partialState {
            partialState.cancelFullRangeFetches()
        }
    }
    
    func rangeStatus(next: @escaping (RangeSet<Int64>) -> Void, completed: @escaping () -> Void) -> Disposable {
        assert(self.queue.isCurrent())
        
        if let size = fileSize(self.path) {
            next(RangeSet<Int64>([0 ..< Int64(size) as Range<Int64>]))
            completed()
            
            return EmptyDisposable
        } else {
            return self.withPartialState { partialState in
                return partialState.rangeStatus(next: next, completed: completed)
            }
        }
    }
    
    func status(next: @escaping (MediaResourceStatus) -> Void, completed: @escaping () -> Void, size: Int64?) -> Disposable {
        assert(self.queue.isCurrent())
        
        if let _ = fileSize(self.path) {
            next(.Local)
            completed()
            
            return EmptyDisposable
        } else {
            return self.withPartialState { partialState in
                return partialState.status(next: next, completed: completed, size: size)
            }
        }
    }
}
