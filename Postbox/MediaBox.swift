import Foundation
#if os(macOS)
    import SwiftSignalKitMac
#else
    import SwiftSignalKit
#endif

private final class ResourceStatusContext {
    var status: MediaResourceStatus?
    let subscribers = Bag<(MediaResourceStatus) -> Void>()
}

private final class ResourceDataContext {
    var data: MediaResourceData
    var processedFetch: Bool = false
    let progresiveDataSubscribers = Bag<(waitUntilFetchStatus: Bool, sink: (MediaResourceData) -> Void)>()
    let completeDataSubscribers = Bag<(waitUntilFetchStatus: Bool, sink: (MediaResourceData) -> Void)>()
    
    var fetchDisposable: Disposable?
    let fetchSubscribers = Bag<Void>()
    
    init(data: MediaResourceData) {
        self.data = data
    }
}

private func fileSize(_ path: String) -> Int? {
    var value = stat()
    if stat(path, &value) == 0 {
        return Int(value.st_size)
    } else {
        return nil
    }
}

public enum ResourceDataRangeMode {
    case complete
    case incremental
    case partial
}

public enum FetchResourceSourceType {
    case local
    case remote
}

private struct ResourceStorePaths {
    let partial: String
    let complete: String
}

public struct MediaResourceData {
    public let path: String
    public let size: Int
    public let complete: Bool
}

public enum MediaResourceDataFetchResult {
    case dataPart(data: Data, range: Range<Int>, complete: Bool)
    case replaceHeader(data: Data, range: Range<Int>)
    case moveLocalFile(path: String)
    case reset
}

/*public struct MediaResourceDataFetchResult {
    public let data: Data
    public let complete: Bool
    
    public init(data: Data, complete: Bool) {
        self.data = data
        self.complete = complete
    }
}*/

public struct CachedMediaResourceRepresentationResult {
    public let temporaryPath: String
    
    public init(temporaryPath: String) {
        self.temporaryPath = temporaryPath
    }
}

private struct CachedMediaResourceRepresentationKey: Hashable {
    let resourceId: MediaResourceId
    let representation: CachedMediaResourceRepresentation
    
    static func ==(lhs: CachedMediaResourceRepresentationKey, rhs: CachedMediaResourceRepresentationKey) -> Bool {
        return lhs.resourceId.isEqual(to: rhs.resourceId) && lhs.representation.isEqual(to: rhs.representation)
    }
    
    var hashValue: Int {
        return self.resourceId.hashValue
    }
}

private final class CachedMediaResourceRepresentationContext {
    let dataSubscribers = Bag<(MediaResourceData) -> Void>()
    var disposable: Disposable?
}

public enum ResourceDataRequestOption {
    case complete(waitUntilFetchStatus: Bool)
    case incremental(waitUntilFetchStatus: Bool)
}

public final class MediaBox {
    let basePath: String
    
    private let statusQueue = Queue()
    private let concurrentQueue = Queue.concurrentDefaultQueue()
    private let dataQueue = Queue()
    private let cacheQueue = Queue()
    
    private var statusContexts: [WrappedMediaResourceId: ResourceStatusContext] = [:]
    private var dataContexts: [WrappedMediaResourceId: ResourceDataContext] = [:]
    private var randomAccessContexts: [WrappedMediaResourceId: RandomAccessMediaResourceContext] = [:]
    private var cachedRepresentationContexts: [CachedMediaResourceRepresentationKey: CachedMediaResourceRepresentationContext] = [:]
    
    private var wrappedFetchResource = Promise<(MediaResource, Range<Int>, MediaResourceFetchTag?) -> Signal<MediaResourceDataFetchResult, NoError>>()
    public var fetchResource: ((MediaResource, Range<Int>, MediaResourceFetchTag?) -> Signal<MediaResourceDataFetchResult, NoError>)? {
        didSet {
            if let fetchResource = self.fetchResource {
                wrappedFetchResource.set(.single(fetchResource))
            } else {
                wrappedFetchResource.set(.never())
            }
        }
    }
    
    public var wrappedFetchCachedResourceRepresentation = Promise<(MediaResource, MediaResourceData, CachedMediaResourceRepresentation) -> Signal<CachedMediaResourceRepresentationResult, NoError>>()
    public var fetchCachedResourceRepresentation: ((MediaResource, MediaResourceData, CachedMediaResourceRepresentation) -> Signal<CachedMediaResourceRepresentationResult, NoError>)? {
        didSet {
            if let fetchCachedResourceRepresentation = self.fetchCachedResourceRepresentation {
                wrappedFetchCachedResourceRepresentation.set(.single(fetchCachedResourceRepresentation))
            } else {
                wrappedFetchCachedResourceRepresentation.set(.never())
            }
        }
    }
    
    lazy var ensureDirectoryCreated: Void = {
        try! FileManager.default.createDirectory(atPath: self.basePath, withIntermediateDirectories: true, attributes: nil)
        try! FileManager.default.createDirectory(atPath: self.basePath + "/cache", withIntermediateDirectories: true, attributes: nil)
    }()
    
    public init(basePath: String) {
        self.basePath = basePath
        
        let _ = self.ensureDirectoryCreated
    }
    
    private func fileNameForId(_ id: MediaResourceId) -> String {
        return "\(id.uniqueId)"
    }
    
    private func pathForId(_ id: MediaResourceId) -> String {
        return "\(self.basePath)/\(fileNameForId(id))"
    }
    
    private func storePathsForId(_ id: MediaResourceId) -> ResourceStorePaths {
        return ResourceStorePaths(partial: "\(self.basePath)/\(fileNameForId(id))_partial", complete: "\(self.basePath)/\(fileNameForId(id))")
    }
    
    private func cachedRepresentationPathForId(_ id: MediaResourceId, representation: CachedMediaResourceRepresentation) -> String {
        return "\(self.basePath)/cache/\(fileNameForId(id)):\(representation.uniqueId)"
    }
    
    public func storeResourceData(_ id: MediaResourceId, data: Data) {
        self.dataQueue.async {
            let paths = self.storePathsForId(id)
            let _ = try? data.write(to: URL(fileURLWithPath: paths.complete), options: [.atomic])
        }
    }
    
    public func moveResourceData(from: MediaResourceId, to: MediaResourceId) {
        self.dataQueue.async {
            let pathsFrom = self.storePathsForId(from)
            let pathsTo = self.storePathsForId(to)
            link(pathsFrom.partial, pathsTo.partial)
            link(pathsFrom.complete, pathsTo.complete)
        }
    }
    
    public func resourceStatus(_ resource: MediaResource) -> Signal<MediaResourceStatus, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            
            self.concurrentQueue.async {
                let paths = self.storePathsForId(resource.id)
                if let _ = fileSize(paths.complete) {
                    subscriber.putNext(.Local)
                    subscriber.putCompletion()
                } else {
                    self.statusQueue.async {
                        let statusContext: ResourceStatusContext
                        if let current = self.statusContexts[WrappedMediaResourceId(resource.id)] {
                            statusContext = current
                        } else {
                            statusContext = ResourceStatusContext()
                            self.statusContexts[WrappedMediaResourceId(resource.id)] = statusContext
                        }
                        
                        let index = statusContext.subscribers.add({ status in
                            subscriber.putNext(status)
                        })
                        
                        if let status = statusContext.status {
                            subscriber.putNext(status)
                        } else {
                            self.dataQueue.async {
                                let status: MediaResourceStatus
                                
                                if let _ = fileSize(paths.complete) {
                                    status = .Local
                                } else {
                                    var fetchingData = false
                                    if let dataContext = self.dataContexts[WrappedMediaResourceId(resource.id)] {
                                        fetchingData = dataContext.fetchDisposable != nil
                                    }
                                    
                                    if fetchingData {
                                        let currentSize = fileSize(paths.partial) ?? 0
                                        
                                        if let resourceSize = resource.size {
                                            status = .Fetching(progress: Float(currentSize) / Float(resourceSize))
                                        } else {
                                            status = .Fetching(progress: 0.0)
                                        }

                                    } else {
                                        status = .Remote
                                    }
                                }
                                
                                self.statusQueue.async {
                                    if let statusContext = self.statusContexts[WrappedMediaResourceId(resource.id)] , statusContext.status == nil {
                                        statusContext.status = status
                                        
                                        for subscriber in statusContext.subscribers.copyItems() {
                                            subscriber(status)
                                        }
                                    }
                                }
                            }
                        }
                        
                        disposable.set(ActionDisposable {
                            self.statusQueue.async {
                                if let current = self.statusContexts[WrappedMediaResourceId(resource.id)] {
                                    current.subscribers.remove(index)
                                    if current.subscribers.isEmpty {
                                        self.statusContexts.removeValue(forKey: WrappedMediaResourceId(resource.id))
                                    }
                                }
                            }
                        })
                    }
                }
            }
            
            return disposable
        }
    }
    
    public func completedResourcePath(_ resource: MediaResource, pathExtension: String? = nil) -> String? {
        let paths = self.storePathsForId(resource.id)
        if let _ = fileSize(paths.complete) {
            if let pathExtension = pathExtension {
                let symlinkPath = paths.complete + ".\(pathExtension)"
                if fileSize(symlinkPath) == nil {
                    let _ = try? FileManager.default.createSymbolicLink(atPath: symlinkPath, withDestinationPath: URL(fileURLWithPath: paths.complete).lastPathComponent)
                }
                return symlinkPath
            } else {
                return paths.complete
            }
        } else {
            return nil
        }
    }
    
    public func resourceData(_ resource: MediaResource, pathExtension: String? = nil, option: ResourceDataRequestOption = .complete(waitUntilFetchStatus: false)) -> Signal<MediaResourceData, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.concurrentQueue.async {
                let paths = self.storePathsForId(resource.id)
                if let completeSize = fileSize(paths.complete) {
                    if let pathExtension = pathExtension {
                        let symlinkPath = paths.complete + ".\(pathExtension)"
                        if fileSize(symlinkPath) == nil {
                            let _ = try? FileManager.default.createSymbolicLink(atPath: symlinkPath, withDestinationPath: URL(fileURLWithPath: paths.complete).lastPathComponent)
                        }
                        subscriber.putNext(MediaResourceData(path: symlinkPath, size: completeSize, complete: true))
                        subscriber.putCompletion()
                    } else {
                        subscriber.putNext(MediaResourceData(path: paths.complete, size: completeSize, complete: true))
                        subscriber.putCompletion()
                    }
                } else {
                    self.dataQueue.async {
                        let resourceId = WrappedMediaResourceId(resource.id)
                        let currentContext: ResourceDataContext? = self.dataContexts[resourceId]
                        if let currentContext = currentContext, currentContext.data.complete {
                            if let pathExtension = pathExtension {
                                let symlinkPath = paths.complete + ".\(pathExtension)"
                                if fileSize(symlinkPath) == nil {
                                    let _ = try? FileManager.default.createSymbolicLink(atPath: symlinkPath, withDestinationPath: URL(fileURLWithPath: paths.complete).lastPathComponent)
                                }
                                subscriber.putNext(MediaResourceData(path: symlinkPath, size: currentContext.data.size, complete: currentContext.data.complete))
                                subscriber.putCompletion()
                            } else {
                                subscriber.putNext(currentContext.data)
                                subscriber.putCompletion()
                            }
                        } else if let completeSize = fileSize(paths.complete) {
                            if let pathExtension = pathExtension {
                                let symlinkPath = paths.complete + ".\(pathExtension)"
                                if fileSize(symlinkPath) == nil {
                                    let _ = try? FileManager.default.createSymbolicLink(atPath: symlinkPath, withDestinationPath: URL(fileURLWithPath: paths.complete).lastPathComponent)
                                }
                                subscriber.putNext(MediaResourceData(path: symlinkPath, size: completeSize, complete: true))
                                subscriber.putCompletion()
                            } else {
                                subscriber.putNext(MediaResourceData(path: paths.complete, size: completeSize, complete: true))
                                subscriber.putCompletion()
                            }
                        } else {
                            let dataContext: ResourceDataContext
                            if let currentContext = currentContext {
                                dataContext = currentContext
                            } else {
                                let partialSize = fileSize(paths.partial) ?? 0
                                dataContext = ResourceDataContext(data: MediaResourceData(path: paths.partial, size: partialSize, complete: false))
                                self.dataContexts[resourceId] = dataContext
                            }

                            let index: Bag<(MediaResourceData) -> Void>.Index
                            switch option {
                                case let .complete(waitUntilFetchStatus):
                                    index = dataContext.completeDataSubscribers.add((waitUntilFetchStatus, { data in
                                        if let pathExtension = pathExtension, data.complete {
                                            let symlinkPath = paths.complete + ".\(pathExtension)"
                                            if fileSize(symlinkPath) == nil {
                                                let _ = try? FileManager.default.createSymbolicLink(atPath: symlinkPath, withDestinationPath: URL(fileURLWithPath: paths.complete).lastPathComponent)
                                            }
                                            subscriber.putNext(MediaResourceData(path: symlinkPath, size: data.size, complete: data.complete))
                                            subscriber.putCompletion()
                                        } else {
                                            subscriber.putNext(data)
                                            subscriber.putCompletion()
                                        }
                                    }))
                                    if !waitUntilFetchStatus || dataContext.processedFetch {
                                        subscriber.putNext(MediaResourceData(path: dataContext.data.path, size: 0, complete: false))
                                    }
                                case let .incremental(waitUntilFetchStatus):
                                    index = dataContext.progresiveDataSubscribers.add((waitUntilFetchStatus, { data in
                                        if let pathExtension = pathExtension, data.complete {
                                            let symlinkPath = paths.complete + ".\(pathExtension)"
                                            if fileSize(symlinkPath) == nil {
                                                let _ = try? FileManager.default.createSymbolicLink(atPath: symlinkPath, withDestinationPath: URL(fileURLWithPath: paths.complete).lastPathComponent)
                                            }
                                            subscriber.putNext(MediaResourceData(path: symlinkPath, size: data.size, complete: data.complete))
                                            subscriber.putCompletion()
                                        } else {
                                            subscriber.putNext(data)
                                            if data.complete {
                                                subscriber.putCompletion()
                                            }
                                        }
                                    }))
                                    if !waitUntilFetchStatus || dataContext.processedFetch {
                                        subscriber.putNext(dataContext.data)
                                    }
                            }
                            
                            disposable.set(ActionDisposable {
                                self.dataQueue.async {
                                    if let dataContext = self.dataContexts[resourceId] {
                                        switch option {
                                            case .complete:
                                                dataContext.completeDataSubscribers.remove(index)
                                            case .incremental:
                                                dataContext.progresiveDataSubscribers.remove(index)
                                        }
                                        
                                        if dataContext.progresiveDataSubscribers.isEmpty && dataContext.completeDataSubscribers.isEmpty && dataContext.fetchSubscribers.isEmpty {
                                            self.dataContexts.removeValue(forKey: resourceId)
                                        }
                                    }
                                }
                            })
                        }
                    }
                }
            }
            
            return disposable
        }
    }
    
    private func randomAccessContext(for resource: MediaResource, size: Int, tag: MediaResourceFetchTag?) -> RandomAccessMediaResourceContext {
        assert(self.dataQueue.isCurrent())
        
        let resourceId = WrappedMediaResourceId(resource.id)
        
        let dataContext: RandomAccessMediaResourceContext
        if let current = self.randomAccessContexts[resourceId] {
            dataContext = current
        } else {
            let path = self.pathForId(resource.id) + ".random"
            dataContext = RandomAccessMediaResourceContext(path: path, size: size, fetchRange: { [weak self] range in
                let disposable = MetaDisposable()
                
                if let strongSelf = self {
                    strongSelf.dataQueue.async {
                        let fetch = strongSelf.wrappedFetchResource.get() |> take(1) |> mapToSignal { fetch -> Signal<MediaResourceDataFetchResult, NoError> in
                            return fetch(resource, range, tag)
                        }
                        var offset = 0
                        disposable.set(fetch.start(next: { [weak strongSelf] result in
                            if let strongSelf = strongSelf {
                                strongSelf.dataQueue.async {
                                    if let dataContext = strongSelf.randomAccessContexts[resourceId] {
                                        switch result {
                                            case let .dataPart(data, dataRange, _):
                                                let storeRange = RandomAccessResourceStoreRange(offset: range.lowerBound + offset, data: data.subdata(in: dataRange))
                                                offset += data.count
                                                dataContext.storeRanges([storeRange])
                                            default:
                                                assertionFailure()
                                        }
                                    }
                                }
                            }
                        }))
                    }
                }
                
                return disposable
            })
            self.randomAccessContexts[resourceId] = dataContext
        }
        return dataContext
    }
    
    public func fetchedResourceData(_ resource: MediaResource, size: Int, in range: Range<Int>, tag: MediaResourceFetchTag?) -> Signal<Void, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            
            self.dataQueue.async {
                let resourceId = WrappedMediaResourceId(resource.id)
                let dataContext = self.randomAccessContext(for: resource, size: size, tag: tag)
                
                let listener = dataContext.addListenerForFetchedData(in: range)
                
                disposable.set(ActionDisposable { [weak self] in
                    if let strongSelf = self {
                        strongSelf.dataQueue.async {
                            if let dataContext = strongSelf.randomAccessContexts[resourceId] {
                                dataContext.removeListenerForFetchedData(listener)
                                if !dataContext.hasDataListeners() {
                                    //let _ = strongSelf.randomAccessContexts.removeValue(forKey: resourceId)
                                }
                            }
                        }
                    }
                })
            }
            
            return disposable
        }
    }
    
    public func resourceData(_ resource: MediaResource, size: Int, in range: Range<Int>, tag: MediaResourceFetchTag?, mode: ResourceDataRangeMode = .complete) -> Signal<Data, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            
            self.dataQueue.async {
                let resourceId = WrappedMediaResourceId(resource.id)
                let dataContext = self.randomAccessContext(for: resource, size: size, tag: tag)
                
                let listenerMode: RandomAccessResourceDataRangeMode
                switch mode {
                    case .complete:
                        listenerMode = .Complete
                    case .incremental:
                        listenerMode = .Incremental
                    case .partial:
                        listenerMode = .Partial
                }
                
                var offset = 0
                
                let listener = dataContext.addListenerForData(in: range, mode: listenerMode, updated: { [weak self] data in
                    if let strongSelf = self {
                        strongSelf.dataQueue.async {
                            subscriber.putNext(data)
                            
                            switch mode {
                                case .complete, .partial:
                                    offset = max(offset, data.count)
                                case .incremental:
                                    offset += data.count
                            }
                            if offset == range.count {
                                subscriber.putCompletion()
                            }
                        }
                    }
                })
                
                disposable.set(ActionDisposable { [weak self] in
                    if let strongSelf = self {
                        strongSelf.dataQueue.async {
                            if let dataContext = strongSelf.randomAccessContexts[resourceId] {
                                dataContext.removeListenerForData(listener)
                                if !dataContext.hasDataListeners() {
                                    //let _ = strongSelf.randomAccessContexts.removeValue(forKey: resourceId)
                                }
                            }
                        }
                    }
                })
            }
            
            return disposable
        }
    }
    
    public func fetchedResource(_ resource: MediaResource, tag: MediaResourceFetchTag?, implNext: Bool = false) -> Signal<FetchResourceSourceType, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            
            self.dataQueue.async {
                let resourceId = WrappedMediaResourceId(resource.id)
                let paths = self.storePathsForId(resource.id)
                
                if let _ = fileSize(paths.complete) {
                    if implNext {
                        subscriber.putNext(.local)
                    }
                    subscriber.putCompletion()
                } else {
                    let currentSize = fileSize(paths.partial) ?? 0
                    let dataContext: ResourceDataContext
                    if let current = self.dataContexts[resourceId] {
                        dataContext = current
                    } else {
                        dataContext = ResourceDataContext(data: MediaResourceData(path: paths.partial, size: currentSize, complete: false))
                        self.dataContexts[resourceId] = dataContext
                    }
                    
                    let index: Bag<Void>.Index = dataContext.fetchSubscribers.add(Void())
                    
                    if dataContext.fetchDisposable == nil {
                        let status: MediaResourceStatus
                        if let resourceSize = resource.size {
                            status = .Fetching(progress: Float(currentSize) / Float(resourceSize))
                        } else {
                            status = .Fetching(progress: 0.0)
                        }
                        self.statusQueue.async {
                            if let statusContext = self.statusContexts[resourceId] {
                                statusContext.status = status
                                for subscriber in statusContext.subscribers.copyItems() {
                                    subscriber(status)
                                }
                            }
                        }
                        
                        var offset = currentSize
                        var fd: Int32?
                        let dataQueue = self.dataQueue
                        dataContext.fetchDisposable = ((self.wrappedFetchResource.get() |> take(1) |> mapToSignal { fetch -> Signal<MediaResourceDataFetchResult, NoError> in
                            return fetch(resource, currentSize ..< Int.max, tag)
                        }) |> afterDisposed {
                            dataQueue.async {
                                if let thisFd = fd {
                                    close(thisFd)
                                    fd = nil
                                }
                            }
                        }).start(next: { resultOption in
                            self.dataQueue.async {
                                let _ = self.ensureDirectoryCreated
                                
                                switch resultOption {
                                    case let .dataPart(data, dataRange, complete):
                                        if fd == nil {
                                            let handle = open(paths.partial, O_WRONLY | O_CREAT | O_APPEND, S_IRUSR | S_IWUSR)
                                            if handle >= 0 {
                                                fd = handle
                                            }
                                        }
                                        
                                        if let thisFd = fd {
                                            if !dataRange.isEmpty {
                                                let writeResult = data.withUnsafeBytes { bytes -> Int in
                                                    return write(thisFd, bytes.advanced(by: dataRange.lowerBound), dataRange.count)
                                                }
                                                if writeResult != dataRange.count {
                                                    print("write error \(errno)")
                                                }
                                            }
                                            
                                            offset += dataRange.count
                                            let updatedSize = offset
                                            
                                            let updatedData: MediaResourceData
                                            if complete {
                                                let linkResult = link(paths.partial, paths.complete)
                                                assert(linkResult == 0)
                                                updatedData = MediaResourceData(path: paths.complete, size: updatedSize, complete: true)
                                            } else {
                                                updatedData = MediaResourceData(path: paths.partial, size: updatedSize, complete: false)
                                            }
                                            
                                            dataContext.data = updatedData
                                            
                                            let hadProcessedFetch = dataContext.processedFetch
                                            dataContext.processedFetch = true
                                            
                                            for (_, subscriber) in dataContext.progresiveDataSubscribers.copyItems() {
                                                subscriber(updatedData)
                                            }
                                            
                                            if updatedData.complete {
                                                for (_, subscriber) in dataContext.completeDataSubscribers.copyItems() {
                                                    subscriber(updatedData)
                                                }
                                            } else if !hadProcessedFetch {
                                                for (waitUntilFetchStatus, subscriber) in dataContext.completeDataSubscribers.copyItems() {
                                                    if waitUntilFetchStatus {
                                                        subscriber(updatedData)
                                                    }
                                                }
                                            }
                                            
                                            let status: MediaResourceStatus
                                            if updatedData.complete {
                                                status = .Local
                                                if implNext {
                                                    subscriber.putNext(.remote)
                                                }
                                                subscriber.putCompletion()
                                            } else {
                                                if let resourceSize = resource.size {
                                                    status = .Fetching(progress: Float(updatedSize) / Float(resourceSize))
                                                } else {
                                                    status = .Fetching(progress: 0.0)
                                                }
                                            }
                                            
                                            self.statusQueue.async {
                                                if let statusContext = self.statusContexts[resourceId] {
                                                    statusContext.status = status
                                                    for subscriber in statusContext.subscribers.copyItems() {
                                                        subscriber(status)
                                                    }
                                                }
                                            }
                                        }
                                    case let .replaceHeader(data, dataRange):
                                        if let thisFd = fd {
                                            close(thisFd)
                                            fd = nil
                                        }
                                        
                                        if fd == nil {
                                            let handle = open(paths.partial, O_CREAT | O_WRONLY, S_IRUSR | S_IWUSR)
                                            if handle >= 0 {
                                                fd = handle
                                            }
                                        }
                                        
                                        if let thisFd = fd {
                                            if !dataRange.isEmpty {
                                                lseek(thisFd, 0, SEEK_SET)
                                                let writeResult = data.withUnsafeBytes { bytes -> Int in
                                                    return write(thisFd, bytes.advanced(by: dataRange.lowerBound), dataRange.count)
                                                }
                                                lseek(thisFd, Int64(offset), SEEK_SET)
                                                if writeResult != dataRange.count {
                                                    print("write error \(errno)")
                                                }
                                                
                                                close(thisFd)
                                                fd = nil
                                            }
                                        }
                                    case .reset:
                                        if fd == nil {
                                            let handle = open(paths.partial, O_WRONLY | O_CREAT | O_APPEND, S_IRUSR | S_IWUSR)
                                            if handle >= 0 {
                                                fd = handle
                                            }
                                        }
                                        
                                        if let fd = fd {
                                            ftruncate(fd, 0)
                                            lseek(fd, 0, SEEK_SET)
                                        } else {
                                            assertionFailure()
                                        }
                                    
                                        offset = 0
                                        let updatedSize = offset
                                        
                                        let updatedData: MediaResourceData
                                        updatedData = MediaResourceData(path: paths.partial, size: updatedSize, complete: false)
                                        
                                        dataContext.data = updatedData
                                        
                                        let hadProcessedFetch = dataContext.processedFetch
                                        dataContext.processedFetch = true
                                        
                                        for (_, subscriber) in dataContext.progresiveDataSubscribers.copyItems() {
                                            subscriber(updatedData)
                                        }
                                        
                                        if updatedData.complete {
                                            for (_, subscriber) in dataContext.completeDataSubscribers.copyItems() {
                                                subscriber(updatedData)
                                            }
                                        } else if !hadProcessedFetch {
                                            for (waitUntilFetchStatus, subscriber) in dataContext.completeDataSubscribers.copyItems() {
                                                if waitUntilFetchStatus {
                                                    subscriber(updatedData)
                                                }
                                            }
                                        }
                                        
                                        let status: MediaResourceStatus
                                        if updatedData.complete {
                                            status = .Local
                                        } else {
                                            if let resourceSize = resource.size {
                                                status = .Fetching(progress: Float(updatedSize) / Float(resourceSize))
                                            } else {
                                                status = .Fetching(progress: 0.0)
                                            }
                                        }
                                        
                                        self.statusQueue.async {
                                            if let statusContext = self.statusContexts[resourceId] {
                                                statusContext.status = status
                                                for subscriber in statusContext.subscribers.copyItems() {
                                                    subscriber(status)
                                                }
                                            }
                                        }
                                    case let .moveLocalFile(tempPath):
                                        if let thisFd = thisFd {
                                            close(thisFd)
                                            fd = nil
                                        }
                                        unlink(paths.partial)
                                        do {
                                            try FileManager.default.moveItem(atPath: tempPath, toPath: paths.partial)
                                        } catch {
                                            assertionFailure()
                                        }
                                    
                                        guard let offset = fileSize(paths.partial) else {
                                            assertionFailure()
                                            return
                                        }
                                        let updatedSize = offset
                                        
                                        let updatedData: MediaResourceData
                                        let linkResult = link(paths.partial, paths.complete)
                                        assert(linkResult == 0)
                                        updatedData = MediaResourceData(path: paths.complete, size: updatedSize, complete: true)
                                        
                                        dataContext.data = updatedData
                                        
                                        let hadProcessedFetch = dataContext.processedFetch
                                        dataContext.processedFetch = true
                                        
                                        for (_, subscriber) in dataContext.progresiveDataSubscribers.copyItems() {
                                            subscriber(updatedData)
                                        }
                                        
                                        if updatedData.complete {
                                            for (_, subscriber) in dataContext.completeDataSubscribers.copyItems() {
                                                subscriber(updatedData)
                                            }
                                        } else if !hadProcessedFetch {
                                            for (waitUntilFetchStatus, subscriber) in dataContext.completeDataSubscribers.copyItems() {
                                                if waitUntilFetchStatus {
                                                    subscriber(updatedData)
                                                }
                                            }
                                        }
                                        
                                        let status: MediaResourceStatus
                                        if updatedData.complete {
                                            status = .Local
                                        } else {
                                            if let resourceSize = resource.size {
                                                status = .Fetching(progress: Float(updatedSize) / Float(resourceSize))
                                            } else {
                                                status = .Fetching(progress: 0.0)
                                            }
                                        }
                                        
                                        self.statusQueue.async {
                                            if let statusContext = self.statusContexts[resourceId] {
                                                statusContext.status = status
                                                for subscriber in statusContext.subscribers.copyItems() {
                                                    subscriber(status)
                                                }
                                            }
                                        }
                                }
                            }
                        })
                    }
                    
                    disposable.set(ActionDisposable {
                        self.dataQueue.async {
                            if let dataContext = self.dataContexts[resourceId] {
                                dataContext.fetchSubscribers.remove(index)
                                
                                if dataContext.fetchSubscribers.isEmpty {
                                    dataContext.fetchDisposable?.dispose()
                                    dataContext.fetchDisposable = nil
                                    
                                    let status: MediaResourceStatus
                                    if dataContext.data.complete {
                                        status = .Local
                                    } else {
                                        status = .Remote
                                    }
                                    
                                    self.statusQueue.async {
                                        if let statusContext = self.statusContexts[resourceId], statusContext.status != status {
                                            statusContext.status = status
                                            for subscriber in statusContext.subscribers.copyItems() {
                                                subscriber(status)
                                            }
                                        }
                                    }
                                }
                                
                                if dataContext.completeDataSubscribers.isEmpty && dataContext.progresiveDataSubscribers.isEmpty && dataContext.fetchSubscribers.isEmpty {
                                    self.dataContexts.removeValue(forKey: resourceId)
                                }
                            }
                        }
                    })
                }
            }
            
            return disposable
        }
    }
    
    public func cancelInteractiveResourceFetch(_ resource: MediaResource) {
        self.dataQueue.async {
            let resourceId = WrappedMediaResourceId(resource.id)
            if let dataContext = self.dataContexts[resourceId], dataContext.fetchDisposable != nil {
                dataContext.fetchDisposable?.dispose()
                dataContext.fetchDisposable = nil
                
                let status: MediaResourceStatus
                if dataContext.data.complete {
                    status = .Local
                } else {
                    status = .Remote
                }
                
                self.statusQueue.async {
                    if let statusContext = self.statusContexts[resourceId], statusContext.status != status {
                        statusContext.status = status
                        for subscriber in statusContext.subscribers.copyItems() {
                            subscriber(status)
                        }
                    }
                }
            }
        }
    }
    
    public func cachedResourceRepresentation(_ resource: MediaResource, representation: CachedMediaResourceRepresentation, complete: Bool) -> Signal<MediaResourceData, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.concurrentQueue.async {
                let path = self.cachedRepresentationPathForId(resource.id, representation: representation)
                if let size = fileSize(path) {
                    subscriber.putNext(MediaResourceData(path: path, size: size, complete: true))
                    subscriber.putCompletion()
                } else {
                    self.dataQueue.async {
                        let key = CachedMediaResourceRepresentationKey(resourceId: resource.id, representation: representation)
                        let context: CachedMediaResourceRepresentationContext
                        if let currentContext = self.cachedRepresentationContexts[key] {
                            context = currentContext
                        } else {
                            context = CachedMediaResourceRepresentationContext()
                            self.cachedRepresentationContexts[key] = context
                        }
                        
                        let index = context.dataSubscribers.add({ data in
                            if !complete || data.complete {
                                subscriber.putNext(data)
                            }
                            if data.complete {
                                subscriber.putCompletion()
                            }
                        })
                        
                        disposable.set(ActionDisposable {
                            self.dataQueue.async {
                                if let context = self.cachedRepresentationContexts[key] {
                                    context.dataSubscribers.remove(index)
                                    if context.dataSubscribers.isEmpty {
                                        context.disposable?.dispose()
                                        self.cachedRepresentationContexts.removeValue(forKey: key)
                                    }
                                }
                            }
                        })
                        
                        if context.disposable == nil {
                            let signal = self.resourceData(resource, option: .complete(waitUntilFetchStatus: false))
                                |> mapToSignal { resourceData -> Signal<CachedMediaResourceRepresentationResult?, NoError> in
                                    if resourceData.complete {
                                        return self.wrappedFetchCachedResourceRepresentation.get()
                                            |> take(1)
                                            |> mapToSignal { fetch in
                                                return fetch(resource, resourceData, representation)
                                                    |> map { Optional($0) }
                                            }
                                    } else {
                                        return .single(nil)
                                    }
                                }
                                |> deliverOn(self.dataQueue)
                            context.disposable = signal.start(next: { [weak self] next in
                                if let next = next {
                                    rename(next.temporaryPath, path)
                                    
                                    if let strongSelf = self, let context = strongSelf.cachedRepresentationContexts[key] {
                                        strongSelf.cachedRepresentationContexts.removeValue(forKey: key)
                                        if let size = fileSize(path) {
                                            for subscriber in context.dataSubscribers.copyItems() {
                                                subscriber(MediaResourceData(path: path, size: size, complete: true))
                                            }
                                        }
                                    }
                                } else {
                                    if let strongSelf = self, let context = strongSelf.cachedRepresentationContexts[key] {
                                        for subscriber in context.dataSubscribers.copyItems() {
                                            subscriber(MediaResourceData(path: path, size: 0, complete: false))
                                        }
                                    }
                                }
                            })
                        }
                    }
                }
            }
            return disposable
        }
    }
    
    public func collectResourceCacheUsage(_ ids: [MediaResourceId]) -> Signal<[WrappedMediaResourceId: Int64], NoError> {
        return Signal { subscriber in
            self.dataQueue.async {
                var result: [WrappedMediaResourceId: Int64] = [:]
                for id in ids {
                    let wrappedId = WrappedMediaResourceId(id)
                    let paths = self.storePathsForId(id)
                    if let size = fileSize(paths.complete) {
                        result[wrappedId] = Int64(size)
                    } else if let size = fileSize(paths.partial) {
                        result[wrappedId] = Int64(size)
                    }
                }
                subscriber.putNext(result)
                subscriber.putCompletion()
            }
            return EmptyDisposable
        }
    }
    
    public func removeCachedResources(_ ids: Set<WrappedMediaResourceId>) -> Signal<Void, NoError> {
        return Signal { subscriber in
            self.dataQueue.async {
                for id in ids {
                    let paths = self.storePathsForId(id.id)
                    unlink(paths.complete)
                    unlink(paths.partial)
                }
            }
            return EmptyDisposable
        }
    }
}
