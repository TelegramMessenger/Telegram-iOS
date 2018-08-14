import Foundation
#if os(macOS)
    import SwiftSignalKitMac
#else
    import SwiftSignalKit
#endif

private final class ResourceStatusContext {
    var status: MediaResourceStatus?
    let subscribers = Bag<(MediaResourceStatus) -> Void>()
    let disposable: Disposable
    
    init(disposable: Disposable) {
        self.disposable = disposable
    }
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
    public let offset: Int
    public let size: Int
    public let complete: Bool
    
    public init(path: String, offset: Int, size: Int, complete: Bool) {
        self.path = path
        self.offset = offset
        self.size = size
        self.complete = complete
    }
}

public protocol MediaResourceDataFetchCopyLocalItem {
    func copyTo(url: URL) -> Bool
}

public enum MediaResourceDataFetchResult {
    case dataPart(resourceOffset: Int, data: Data, range: Range<Int>, complete: Bool)
    case resourceSizeUpdated(Int)
    case replaceHeader(data: Data, range: Range<Int>)
    case moveLocalFile(path: String)
    case copyLocalItem(MediaResourceDataFetchCopyLocalItem)
    case reset
}

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
    var currentData: MediaResourceData?
    let dataSubscribers = Bag<(MediaResourceData) -> Void>()
    var disposable: Disposable?
}

public enum ResourceDataRequestOption {
    case complete(waitUntilFetchStatus: Bool)
    case incremental(waitUntilFetchStatus: Bool)
}

public final class MediaBox {
    public let basePath: String
    
    private let statusQueue = Queue()
    private let concurrentQueue = Queue.concurrentDefaultQueue()
    private let dataQueue = Queue()
    private let cacheQueue = Queue()
    
    private var statusContexts: [WrappedMediaResourceId: ResourceStatusContext] = [:]
    private var cachedRepresentationContexts: [CachedMediaResourceRepresentationKey: CachedMediaResourceRepresentationContext] = [:]
    
    private var fileContexts: [WrappedMediaResourceId: MediaBoxFileContext] = [:]
    
    private var wrappedFetchResource = Promise<(MediaResource, Signal<IndexSet, NoError>, MediaResourceFetchParameters?) -> Signal<MediaResourceDataFetchResult, NoError>>()
    public var fetchResource: ((MediaResource, Signal<IndexSet, NoError>, MediaResourceFetchParameters?) -> Signal<MediaResourceDataFetchResult, NoError>)? {
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
    
    public func moveResourceData(_ id: MediaResourceId, fromTempPath: String) {
        self.dataQueue.async {
            let paths = self.storePathsForId(id)
            let _ = try? FileManager.default.moveItem(at: URL(fileURLWithPath: fromTempPath), to: URL(fileURLWithPath: paths.complete))
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
                        let resourceId = WrappedMediaResourceId(resource.id)
                        let statusContext: ResourceStatusContext
                        var statusUpdateDisposable: MetaDisposable?
                        if let current = self.statusContexts[resourceId] {
                            statusContext = current
                        } else {
                            let statusUpdateDisposableValue = MetaDisposable()
                            statusContext = ResourceStatusContext(disposable: statusUpdateDisposableValue)
                            self.statusContexts[resourceId] = statusContext
                            statusUpdateDisposable = statusUpdateDisposableValue
                        }
                        
                        let index = statusContext.subscribers.add({ status in
                            subscriber.putNext(status)
                        })
                        
                        if let status = statusContext.status {
                            subscriber.putNext(status)
                        }
                        
                        if let statusUpdateDisposable = statusUpdateDisposable {
                            let statusQueue = self.statusQueue
                            self.dataQueue.async {
                                if let fileContext = self.fileContext(for: resource) {
                                    //let reference = fileContext.addReference()
                                    statusUpdateDisposable.set(fileContext.status(next: { [weak statusContext] value in
                                        statusQueue.async {
                                            if let current = self.statusContexts[resourceId], current === statusContext, current.status != value {
                                                current.status = value
                                                for subscriber in current.subscribers.copyItems() {
                                                    subscriber(value)
                                                }
                                            }
                                        }
                                    }, completed: { [weak statusContext] in
                                        statusQueue.async {
                                            if let current = self.statusContexts[resourceId], current ===  statusContext {
                                                current.subscribers.remove(index)
                                                if current.subscribers.isEmpty {
                                                    self.statusContexts.removeValue(forKey: resourceId)
                                                    current.disposable.dispose()
                                                }
                                            }
                                        }
                                    }, size: resource.size.flatMap(Int32.init)))
                                }
                            }
                        }
                        
                        disposable.set(ActionDisposable { [weak statusContext] in
                            self.statusQueue.async {
                                if let current = self.statusContexts[WrappedMediaResourceId(resource.id)], current ===  statusContext {
                                    current.subscribers.remove(index)
                                    if current.subscribers.isEmpty {
                                        self.statusContexts.removeValue(forKey: WrappedMediaResourceId(resource.id))
                                        current.disposable.dispose()
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
                        subscriber.putNext(MediaResourceData(path: symlinkPath, offset: 0, size: completeSize, complete: true))
                        subscriber.putCompletion()
                    } else {
                        subscriber.putNext(MediaResourceData(path: paths.complete, offset: 0, size: completeSize, complete: true))
                        subscriber.putCompletion()
                    }
                } else {
                    self.dataQueue.async {
                        if let fileContext = self.fileContext(for: resource) {
                            let waitUntilAfterInitialFetch: Bool
                            switch option {
                                case let .complete(waitUntilFetchStatus):
                                    waitUntilAfterInitialFetch = waitUntilFetchStatus
                                case let .incremental(waitUntilFetchStatus):
                                    waitUntilAfterInitialFetch = waitUntilFetchStatus
                            }
                            let dataDisposable = fileContext.data(range: 0 ..< Int32.max, waitUntilAfterInitialFetch: waitUntilAfterInitialFetch, next: { value in
                                self.dataQueue.async {
                                    if value.complete {
                                        if let pathExtension = pathExtension {
                                            let symlinkPath = paths.complete + ".\(pathExtension)"
                                            if fileSize(symlinkPath) == nil {
                                                let _ = try? FileManager.default.createSymbolicLink(atPath: symlinkPath, withDestinationPath: URL(fileURLWithPath: paths.complete).lastPathComponent)
                                            }
                                            subscriber.putNext(MediaResourceData(path: symlinkPath, offset: 0, size: value.size, complete: true))
                                        } else {
                                            subscriber.putNext(value)
                                        }
                                        subscriber.putCompletion()
                                    } else {
                                        subscriber.putNext(value)
                                    }
                                }
                            })
                            disposable.set(ActionDisposable {
                                dataDisposable.dispose()
                            })
                        }
                        
                        /*let currentContext: ResourceDataContext? = self.dataContexts[resourceId]
                        if let currentContext = currentContext, currentContext.data.complete {
                            if let pathExtension = pathExtension {
                                let symlinkPath = paths.complete + ".\(pathExtension)"
                                if fileSize(symlinkPath) == nil {
                                    let _ = try? FileManager.default.createSymbolicLink(atPath: symlinkPath, withDestinationPath: URL(fileURLWithPath: paths.complete).lastPathComponent)
                                }
                                subscriber.putNext(MediaResourceData(path: symlinkPath, offset: 0, size: currentContext.data.size, complete: currentContext.data.complete))
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
                                subscriber.putNext(MediaResourceData(path: symlinkPath, offset: 0, size: completeSize, complete: true))
                                subscriber.putCompletion()
                            } else {
                                subscriber.putNext(MediaResourceData(path: paths.complete, offset: 0, size: completeSize, complete: true))
                                subscriber.putCompletion()
                            }
                        } else {
                            let dataContext: ResourceDataContext
                            if let currentContext = currentContext {
                                dataContext = currentContext
                            } else {
                                let partialSize = fileSize(paths.partial) ?? 0
                                dataContext = ResourceDataContext(data: MediaResourceData(path: paths.partial, offset: 0, size: partialSize, complete: false))
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
                                            subscriber.putNext(MediaResourceData(path: symlinkPath, offset: 0, size: data.size, complete: data.complete))
                                            if data.complete {
                                                subscriber.putCompletion()
                                            }
                                        } else {
                                            subscriber.putNext(data)
                                            subscriber.putCompletion()
                                        }
                                    }))
                                    if !waitUntilFetchStatus || dataContext.processedFetch {
                                        subscriber.putNext(MediaResourceData(path: dataContext.data.path, offset: 0, size: 0, complete: false))
                                    }
                                case let .incremental(waitUntilFetchStatus):
                                    index = dataContext.progresiveDataSubscribers.add((waitUntilFetchStatus, { data in
                                        if let pathExtension = pathExtension, data.complete {
                                            let symlinkPath = paths.complete + ".\(pathExtension)"
                                            if fileSize(symlinkPath) == nil {
                                                let _ = try? FileManager.default.createSymbolicLink(atPath: symlinkPath, withDestinationPath: URL(fileURLWithPath: paths.complete).lastPathComponent)
                                            }
                                            subscriber.putNext(MediaResourceData(path: symlinkPath, offset: 0, size: data.size, complete: data.complete))
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
                        }*/
                    }
                }
            }
            
            return disposable
        }
    }
    
    private func fileContext(for resource: MediaResource) -> MediaBoxFileContext? {
        assert(self.dataQueue.isCurrent())
        
        let resourceId = WrappedMediaResourceId(resource.id)
        
        if let current = self.fileContexts[resourceId] {
            return current
        } else {
            let paths = self.storePathsForId(resource.id)
            if let fileContext = MediaBoxFileContext(queue: self.dataQueue, path: paths.complete, partialPath: paths.partial) {
                self.fileContexts[resourceId] = fileContext
                return fileContext
            } else {
                return nil
            }
        }
    }
    
    public func fetchedResourceData(_ resource: MediaResource, in range: Range<Int>, parameters: MediaResourceFetchParameters?) -> Signal<Void, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            
            self.dataQueue.async {
                let fileContext = self.fileContext(for: resource)
                
                let fetchResource = self.wrappedFetchResource.get()
                let fetchedDisposable = fileContext?.fetched(range: Int32(range.lowerBound) ..< Int32(range.upperBound), fetch: { ranges in
                    return fetchResource |> mapToSignal { fetch in
                        return fetch(resource, ranges, parameters)
                    }
                }, completed: {
                    subscriber.putCompletion()
                })
                
                disposable.set(ActionDisposable {
                    fetchedDisposable?.dispose()
                })
            }
            
            return disposable
        }
    }
    
    public func resourceData(_ resource: MediaResource, size: Int, in range: Range<Int>, mode: ResourceDataRangeMode = .complete) -> Signal<Data, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            
            self.dataQueue.async {
                let fileContext = self.fileContext(for: resource)
                
                let dataDisposable = fileContext?.data(range: Int32(range.lowerBound) ..< Int32(range.upperBound), waitUntilAfterInitialFetch: false, next: { result in
                    if let data = try? Data(contentsOf: URL(fileURLWithPath: result.path), options: .mappedRead) {
                        if result.complete {
                            let resultData = data.subdata(in: result.offset ..< (result.offset + result.size))
                            subscriber.putNext(resultData)
                            subscriber.putCompletion()
                        } else {
                            switch mode {
                                case .complete:
                                    break
                                case .incremental:
                                    break
                                case .partial:
                                    break
                            }
                        }
                    }
                })
                
                disposable.set(ActionDisposable {
                    dataDisposable?.dispose()
                })
            }
            
            return disposable
        }
    }
    
    public func resourceRangesStatus(_ resource: MediaResource) -> Signal<IndexSet, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            
            self.dataQueue.async {
                let fileContext = self.fileContext(for: resource)
                
                let statusDisposable = fileContext?.rangeStatus(next: { result in
                    subscriber.putNext(result)
                }, completed: {
                    subscriber.putCompletion()
                })
                
                disposable.set(ActionDisposable {
                    statusDisposable?.dispose()
                })
            }
            
            return disposable
        }
    }
    
    public func fetchedResource(_ resource: MediaResource, parameters: MediaResourceFetchParameters?, implNext: Bool = false) -> Signal<FetchResourceSourceType, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            
            self.dataQueue.async {
                let paths = self.storePathsForId(resource.id)
                
                if let _ = fileSize(paths.complete) {
                    if implNext {
                        subscriber.putNext(.local)
                    }
                    subscriber.putCompletion()
                } else {
                    if let fileContext = self.fileContext(for: resource) {
                        let fetchResource = self.wrappedFetchResource.get()
                        let fetchedDisposable = fileContext.fetchedFullRange(fetch: { ranges in
                            return fetchResource |> mapToSignal { fetch in
                                return fetch(resource, ranges, parameters)
                            }
                        }, completed: {
                            if implNext {
                                subscriber.putNext(.remote)
                            }
                            subscriber.putCompletion()
                        })
                        disposable.set(fetchedDisposable)
                    }
                }
            }
            
            return disposable
        }
    }
    
    public func cancelInteractiveResourceFetch(_ resource: MediaResource) {
        self.dataQueue.async {
            if let fileContext = self.fileContext(for: resource) {
                fileContext.cancelFullRangeFetches()
            }
        }
    }
    
    public func storeCachedResourceRepresentation(_ resource: MediaResource, representation: CachedMediaResourceRepresentation, data: Data) {
        self.dataQueue.async {
            let path = self.cachedRepresentationPathForId(resource.id, representation: representation)
            let _ = try? data.write(to: URL(fileURLWithPath: path))
        }
    }
    
    public func cachedResourceRepresentation(_ resource: MediaResource, representation: CachedMediaResourceRepresentation, complete: Bool) -> Signal<MediaResourceData, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.concurrentQueue.async {
                let path = self.cachedRepresentationPathForId(resource.id, representation: representation)
                if let size = fileSize(path) {
                    subscriber.putNext(MediaResourceData(path: path, offset: 0, size: size, complete: true))
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
                        if let currentData = context.currentData {
                            if !complete || currentData.complete {
                                subscriber.putNext(currentData)
                            }
                            if currentData.complete {
                                subscriber.putCompletion()
                            }
                        } else if !complete {
                            subscriber.putNext(MediaResourceData(path: path, offset: 0, size: 0, complete: false))
                        }
                        
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
                                                    |> map(Optional.init)
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
                                            let data = MediaResourceData(path: path, offset: 0, size: size, complete: true)
                                            context.currentData = data
                                            for subscriber in context.dataSubscribers.copyItems() {
                                                subscriber(data)
                                            }
                                        }
                                    }
                                } else {
                                    if let strongSelf = self, let context = strongSelf.cachedRepresentationContexts[key] {
                                        let data = MediaResourceData(path: path, offset: 0, size: 0, complete: false)
                                        context.currentData = data
                                        for subscriber in context.dataSubscribers.copyItems() {
                                            subscriber(data)
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
    
    public func collectOtherResourceUsage(excludeIds: Set<WrappedMediaResourceId>) -> Signal<(Int64, [String], Int64), NoError> {
        return Signal { subscriber in
            self.dataQueue.async {
                var result: Int64 = 0
                
                var excludeNames = Set<String>()
                for id in excludeIds {
                    let partial = "\(self.fileNameForId(id.id))_partial"
                    let meta = "\(self.fileNameForId(id.id))_meta"
                    let complete = self.fileNameForId(id.id)
                    
                    excludeNames.insert(meta)
                    excludeNames.insert(partial)
                    excludeNames.insert(complete)
                }
                
                var fileIds = Set<Data>()
                
                var paths: [String] = []
                
                if let enumerator = FileManager.default.enumerator(at: URL(fileURLWithPath: self.basePath), includingPropertiesForKeys: [.fileSizeKey, .fileResourceIdentifierKey], options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants], errorHandler: nil) {
                    loop: for url in enumerator {
                        if let url = url as? URL {
                            if excludeNames.contains(url.lastPathComponent) {
                                continue loop
                            }
                            
                            if let fileId = (try? url.resourceValues(forKeys: Set([.fileResourceIdentifierKey])))?.fileResourceIdentifier as? Data {
                                if fileIds.contains(fileId) {
                                    paths.append(url.lastPathComponent)
                                    continue loop
                                }
                            
                                if let value = (try? url.resourceValues(forKeys: Set([.fileSizeKey])))?.fileSize, value != 0 {
                                    fileIds.insert(fileId)
                                    paths.append(url.lastPathComponent)
                                    result += Int64(value)
                                }
                            }
                        }
                    }
                }
                
                var cacheResult: Int64 = 0
                
                if let enumerator = FileManager.default.enumerator(at: URL(fileURLWithPath: self.basePath + "/cache"), includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants], errorHandler: nil) {
                    loop: for url in enumerator {
                        if let url = url as? URL {
                            if let value = (try? url.resourceValues(forKeys: Set([.fileSizeKey])))?.fileSize, value != 0 {
                                cacheResult += Int64(value)
                            }
                        }
                    }
                }
                
                subscriber.putNext((result, paths, cacheResult))
                subscriber.putCompletion()
            }
            return EmptyDisposable
        }
    }
    
    public func removeOtherCachedResources(paths: [String]) -> Signal<Void, NoError> {
        return Signal { subscriber in
            self.dataQueue.async {
                for path in paths {
                    unlink(self.basePath + "/" + path)
                }
                if let enumerator = FileManager.default.enumerator(at: URL(fileURLWithPath: self.basePath + "/cache"), includingPropertiesForKeys: [], options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants], errorHandler: nil) {
                    loop: for url in enumerator {
                        if let url = url as? URL {
                            unlink(url.path)
                        }
                    }
                }
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
                    unlink(paths.partial + ".meta")
                    self.fileContexts.removeValue(forKey: id)

                }
                subscriber.putCompletion()
            }
            return EmptyDisposable
        }
    }
    
    public func clearFileContexts() -> Signal<Void, NoError> {
        return Signal { subscriber in
            self.dataQueue.async {
                self.fileContexts.removeAll()
                subscriber.putCompletion()
            }
            return EmptyDisposable
        }
    }
}
