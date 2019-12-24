import Foundation
import SwiftSignalKit

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

public enum FetchResourceError {
    case generic
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

public enum MediaBoxFetchPriority: Int32 {
    case `default` = 0
    case elevated = 1
    case maximum = 2
}

public enum MediaResourceDataFetchResult {
    case dataPart(resourceOffset: Int, data: Data, range: Range<Int>, complete: Bool)
    case resourceSizeUpdated(Int)
    case progressUpdated(Float)
    case replaceHeader(data: Data, range: Range<Int>)
    case moveLocalFile(path: String)
    case moveTempFile(file: TempBoxFile)
    case copyLocalItem(MediaResourceDataFetchCopyLocalItem)
    case reset
}

public enum MediaResourceDataFetchError {
    case generic
}

public enum CachedMediaResourceRepresentationResult {
    case reset
    case data(Data)
    case done
    case temporaryPath(String)
    case tempFile(TempBoxFile)
}

public enum CachedMediaRepresentationKeepDuration {
    case general
    case shortLived
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

private final class CachedMediaResourceRepresentationSubscriber {
    let update: (MediaResourceData) -> Void
    let onlyComplete: Bool
    
    init(update: @escaping (MediaResourceData) -> Void, onlyComplete: Bool) {
        self.update = update
        self.onlyComplete = onlyComplete
    }
}

private final class CachedMediaResourceRepresentationContext {
    var currentData: MediaResourceData?
    let dataSubscribers = Bag<CachedMediaResourceRepresentationSubscriber>()
    let disposable = MetaDisposable()
    var initialized = false
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
    private let timeBasedCleanup: TimeBasedCleanup
    
    private var statusContexts: [WrappedMediaResourceId: ResourceStatusContext] = [:]
    private var cachedRepresentationContexts: [CachedMediaResourceRepresentationKey: CachedMediaResourceRepresentationContext] = [:]
    
    private var fileContexts: [WrappedMediaResourceId: MediaBoxFileContext] = [:]
    
    private var wrappedFetchResource = Promise<(MediaResource, Signal<[(Range<Int>, MediaBoxFetchPriority)], NoError>, MediaResourceFetchParameters?) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError>>()
    public var preFetchedResourcePath: (MediaResource) -> String? = { _ in return nil }
    public var fetchResource: ((MediaResource, Signal<[(Range<Int>, MediaBoxFetchPriority)], NoError>, MediaResourceFetchParameters?) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError>)? {
        didSet {
            if let fetchResource = self.fetchResource {
                wrappedFetchResource.set(.single(fetchResource))
            } else {
                wrappedFetchResource.set(.never())
            }
        }
    }
    
    public var wrappedFetchCachedResourceRepresentation = Promise<(MediaResource, CachedMediaResourceRepresentation) -> Signal<CachedMediaResourceRepresentationResult, NoError>>()
    public var fetchCachedResourceRepresentation: ((MediaResource, CachedMediaResourceRepresentation) -> Signal<CachedMediaResourceRepresentationResult, NoError>)? {
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
        try! FileManager.default.createDirectory(atPath: self.basePath + "/short-cache", withIntermediateDirectories: true, attributes: nil)
    }()
    
    public init(basePath: String) {
        self.basePath = basePath
        
        self.timeBasedCleanup = TimeBasedCleanup(generalPaths: [
            self.basePath,
            self.basePath + "/cache"
        ], shortLivedPaths: [
            self.basePath + "/short-cache"
        ])
        
        let _ = self.ensureDirectoryCreated
    }
    
    public func setMaxStoreTimes(general: Int32, shortLived: Int32) {
        self.timeBasedCleanup.setMaxStoreTimes(general: general, shortLived: shortLived)
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
    
    private func cachedRepresentationPathsForId(_ id: MediaResourceId, representation: CachedMediaResourceRepresentation) -> ResourceStorePaths {
        let cacheString: String
        switch representation.keepDuration {
            case .general:
                cacheString = "cache"
            case .shortLived:
                cacheString = "short-cache"
        }
        return ResourceStorePaths(partial:  "\(self.basePath)/\(cacheString)/\(fileNameForId(id))_partial:\(representation.uniqueId)", complete: "\(self.basePath)/\(cacheString)/\(fileNameForId(id)):\(representation.uniqueId)")
    }
    
    public func storeResourceData(_ id: MediaResourceId, data: Data, synchronous: Bool = false) {
        let begin = {
            let paths = self.storePathsForId(id)
            let _ = try? data.write(to: URL(fileURLWithPath: paths.complete), options: [.atomic])
        }
        if synchronous {
            begin()
        } else {
            self.dataQueue.async(begin)
        }
    }
    
    public func moveResourceData(_ id: MediaResourceId, fromTempPath: String) {
        self.dataQueue.async {
            let paths = self.storePathsForId(id)
            let _ = try? FileManager.default.moveItem(at: URL(fileURLWithPath: fromTempPath), to: URL(fileURLWithPath: paths.complete))
        }
    }
    
    public func copyResourceData(_ id: MediaResourceId, fromTempPath: String) {
        self.dataQueue.async {
            let paths = self.storePathsForId(id)
            let _ = try? FileManager.default.copyItem(at: URL(fileURLWithPath: fromTempPath), to: URL(fileURLWithPath: paths.complete))
        }
    }
    
    public func moveResourceData(from: MediaResourceId, to: MediaResourceId) {
        if from.isEqual(to: to) {
            return
        }
        self.dataQueue.async {
            let pathsFrom = self.storePathsForId(from)
            let pathsTo = self.storePathsForId(to)
            link(pathsFrom.partial, pathsTo.partial)
            link(pathsFrom.complete, pathsTo.complete)
            unlink(pathsFrom.partial)
            unlink(pathsFrom.complete)
        }
    }
    
    private func maybeCopiedPreFetchedResource(completePath: String, resource: MediaResource) {
        if let path = self.preFetchedResourcePath(resource) {
            let _ = try? FileManager.default.copyItem(atPath: path, toPath: completePath)
        }
    }
    
    public func resourceStatus(_ resource: MediaResource, approximateSynchronousValue: Bool = false) -> Signal<MediaResourceStatus, NoError> {
        let signal = Signal<MediaResourceStatus, NoError> { subscriber in
            let disposable = MetaDisposable()
            
            self.concurrentQueue.async {
                let paths = self.storePathsForId(resource.id)
                
                if let _ = fileSize(paths.complete) {
                    self.timeBasedCleanup.touch(paths: [
                        paths.complete
                    ])
                    subscriber.putNext(.Local)
                    subscriber.putCompletion()
                } else {
                    self.maybeCopiedPreFetchedResource(completePath: paths.complete, resource: resource)
                    if let _ = fileSize(paths.complete) {
                        self.timeBasedCleanup.touch(paths: [
                            paths.complete
                        ])
                        subscriber.putNext(.Local)
                        subscriber.putCompletion()
                        return
                    }
                    
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
                                if let (fileContext, releaseContext) = self.fileContext(for: resource) {
                                    let statusDisposable = fileContext.status(next: { [weak statusContext] value in
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
                                    }, size: resource.size.flatMap(Int32.init))
                                    statusUpdateDisposable.set(ActionDisposable {
                                        statusDisposable.dispose()
                                        releaseContext()
                                    })
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
        if approximateSynchronousValue {
            return Signal<Signal<MediaResourceStatus, NoError>, NoError> { subscriber in
                let paths = self.storePathsForId(resource.id)
                if let _ = fileSize(paths.complete) {
                    subscriber.putNext(.single(.Local))
                } else {
                    subscriber.putNext(.single(.Remote) |> then(signal))
                }
                subscriber.putCompletion()
                return EmptyDisposable
            } |> switchToLatest
        } else {
            return signal
        }
    }
    
    public func resourcePath(_ resource: MediaResource) -> String {
        let paths = self.storePathsForId(resource.id)
        return paths.complete
    }
    
    public func completedResourcePath(_ resource: MediaResource, pathExtension: String? = nil) -> String? {
        let paths = self.storePathsForId(resource.id)
        if let _ = fileSize(paths.complete) {
            self.timeBasedCleanup.touch(paths: [
                paths.complete
            ])
            if let pathExtension = pathExtension {
                let symlinkPath = paths.complete + ".\(pathExtension)"
                if fileSize(symlinkPath) == nil {
                    let _ = try? FileManager.default.linkItem(atPath: paths.complete, toPath: symlinkPath)
                }
                return symlinkPath
            } else {
                return paths.complete
            }
        } else {
            return nil
        }
    }
    
    public func resourceData(_ resource: MediaResource, pathExtension: String? = nil, option: ResourceDataRequestOption = .complete(waitUntilFetchStatus: false), attemptSynchronously: Bool = false) -> Signal<MediaResourceData, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            
            let begin: () -> Void = {
                let paths = self.storePathsForId(resource.id)
                
                var completeSize = fileSize(paths.complete)
                if completeSize == nil {
                    self.maybeCopiedPreFetchedResource(completePath: paths.complete, resource: resource)
                    completeSize = fileSize(paths.complete)
                }
                
                if let completeSize = fileSize(paths.complete) {
                    self.timeBasedCleanup.touch(paths: [
                        paths.complete
                    ])
                    if let pathExtension = pathExtension {
                        let symlinkPath = paths.complete + ".\(pathExtension)"
                        if fileSize(symlinkPath) == nil {
                            let _ = try? FileManager.default.linkItem(atPath: paths.complete, toPath: symlinkPath)
                        }
                        subscriber.putNext(MediaResourceData(path: symlinkPath, offset: 0, size: completeSize, complete: true))
                        subscriber.putCompletion()
                    } else {
                        subscriber.putNext(MediaResourceData(path: paths.complete, offset: 0, size: completeSize, complete: true))
                        subscriber.putCompletion()
                    }
                } else {
                    if attemptSynchronously, case .complete(false) = option {
                        subscriber.putNext(MediaResourceData(path: paths.partial, offset: 0, size: fileSize(paths.partial) ?? 0, complete: false))
                    }
                    self.dataQueue.async {
                        if let (fileContext, releaseContext) = self.fileContext(for: resource) {
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
                                                let _ = try? FileManager.default.linkItem(atPath: paths.complete, toPath: symlinkPath)
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
                                releaseContext()
                            })
                        }
                    }
                }
            }
            if attemptSynchronously {
                begin()
            } else {
                self.concurrentQueue.async(begin)
            }
            
            return disposable
        }
    }
    
    private func fileContext(for resource: MediaResource) -> (MediaBoxFileContext, () -> Void)? {
        assert(self.dataQueue.isCurrent())
        
        let resourceId = WrappedMediaResourceId(resource.id)
        
        var context: MediaBoxFileContext?
        if let current = self.fileContexts[resourceId] {
            context = current
        } else {
            let paths = self.storePathsForId(resource.id)
            self.timeBasedCleanup.touch(paths: [
                paths.complete,
                paths.partial,
                paths.partial + ".meta"
            ])
            if let fileContext = MediaBoxFileContext(queue: self.dataQueue, path: paths.complete, partialPath: paths.partial, metaPath: paths.partial + ".meta") {
                context = fileContext
                self.fileContexts[resourceId] = fileContext
            } else {
                return nil
            }
        }
        if let context = context {
            let index = context.addReference()
            let queue = self.dataQueue
            return (context, { [weak self, weak context] in
                queue.async {
                    guard let strongSelf = self, let previousContext = context, let context = strongSelf.fileContexts[resourceId], context === previousContext else {
                        return
                    }
                    context.removeReference(index)
                    if context.isEmpty {
                        strongSelf.fileContexts.removeValue(forKey: resourceId)
                    }
                }
            })
        } else {
            return nil
        }
    }
    
    public func fetchedResourceData(_ resource: MediaResource, in range: Range<Int>, priority: MediaBoxFetchPriority = .default, parameters: MediaResourceFetchParameters?) -> Signal<Void, FetchResourceError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            
            self.dataQueue.async {
                guard let (fileContext, releaseContext) = self.fileContext(for: resource) else {
                    subscriber.putCompletion()
                    return
                }
                
                let fetchResource = self.wrappedFetchResource.get()
                let fetchedDisposable = fileContext.fetched(range: Int32(range.lowerBound) ..< Int32(range.upperBound), priority: priority, fetch: { intervals in
                    return fetchResource
                    |> castError(MediaResourceDataFetchError.self)
                    |> mapToSignal { fetch in
                        return fetch(resource, intervals, parameters)
                    }
                }, error: { _ in
                    subscriber.putCompletion()
                }, completed: {
                    subscriber.putCompletion()
                })
                
                disposable.set(ActionDisposable {
                    fetchedDisposable.dispose()
                    releaseContext()
                })
            }
            
            return disposable
        }
    }
    
    public func resourceData(_ resource: MediaResource, size: Int, in range: Range<Int>, mode: ResourceDataRangeMode = .complete) -> Signal<Data, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            
            self.dataQueue.async {
                guard let (fileContext, releaseContext) = self.fileContext(for: resource) else {
                    subscriber.putCompletion()
                    return
                }
                
                let range = Int32(range.lowerBound) ..< Int32(range.upperBound)
                
                let dataDisposable = fileContext.data(range: range, waitUntilAfterInitialFetch: false, next: { result in
                    if let file = ManagedFile(queue: self.dataQueue, path: result.path, mode: .read), let fileSize = file.getSize() {
                        if result.complete {
                            if result.offset + result.size <= fileSize {
                                if fileSize >= result.offset + result.size {
                                    file.seek(position: Int64(result.offset))
                                    let resultData = file.readData(count: result.size)
                                    subscriber.putNext(resultData)
                                    subscriber.putCompletion()
                                } else {
                                    assertionFailure("data.count >= result.offset + result.size")
                                }
                            } else {
                                assertionFailure()
                            }
                        } else {
                            switch mode {
                                case .complete:
                                    break
                                case .incremental:
                                    break
                                case .partial:
                                    subscriber.putNext(Data())
                            }
                        }
                    }
                })
                
                disposable.set(ActionDisposable {
                    dataDisposable.dispose()
                    releaseContext()
                })
            }
            
            return disposable
        }
    }
    
    public func resourceRangesStatus(_ resource: MediaResource) -> Signal<IndexSet, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            
            self.dataQueue.async {
                guard let (fileContext, releaseContext) = self.fileContext(for: resource) else {
                    subscriber.putCompletion()
                    return
                }
                
                let statusDisposable = fileContext.rangeStatus(next: { result in
                    subscriber.putNext(result)
                }, completed: {
                    subscriber.putCompletion()
                })
                
                disposable.set(ActionDisposable {
                    statusDisposable.dispose()
                    releaseContext()
                })
            }
            
            return disposable
        }
    }
    
    public func fetchedResource(_ resource: MediaResource, parameters: MediaResourceFetchParameters?, implNext: Bool = false) -> Signal<FetchResourceSourceType, FetchResourceError> {
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
                    if let (fileContext, releaseContext) = self.fileContext(for: resource) {
                        let fetchResource = self.wrappedFetchResource.get()
                        let fetchedDisposable = fileContext.fetchedFullRange(fetch: { ranges in
                            return fetchResource
                            |> castError(MediaResourceDataFetchError.self)
                            |> mapToSignal { fetch in
                                return fetch(resource, ranges, parameters)
                            }
                        }, error: { _ in
                            subscriber.putError(.generic)
                        }, completed: {
                            if implNext {
                                subscriber.putNext(.remote)
                            }
                            subscriber.putCompletion()
                        })
                        disposable.set(ActionDisposable {
                            fetchedDisposable.dispose()
                            releaseContext()
                        })
                    }
                }
            }
            
            return disposable
        }
    }
    
    public func cancelInteractiveResourceFetch(_ resource: MediaResource) {
        self.dataQueue.async {
            if let (fileContext, releaseContext) = self.fileContext(for: resource) {
                fileContext.cancelFullRangeFetches()
                releaseContext()
            }
        }
    }
    
    public func storeCachedResourceRepresentation(_ resource: MediaResource, representation: CachedMediaResourceRepresentation, data: Data) {
        self.dataQueue.async {
            let path = self.cachedRepresentationPathsForId(resource.id, representation: representation).complete
            let _ = try? data.write(to: URL(fileURLWithPath: path))
        }
    }
    
    public func cachedResourceRepresentation(_ resource: MediaResource, representation: CachedMediaResourceRepresentation, pathExtension: String? = nil, complete: Bool, fetch: Bool = true, attemptSynchronously: Bool = false) -> Signal<MediaResourceData, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            
            let begin: () -> Void = {
                let paths = self.cachedRepresentationPathsForId(resource.id, representation: representation)
                if let size = fileSize(paths.complete) {
                    self.timeBasedCleanup.touch(paths: [
                        paths.complete
                    ])
                    
                    if let pathExtension = pathExtension {
                        let symlinkPath = paths.complete + ".\(pathExtension)"
                        if fileSize(symlinkPath) == nil {
                            let _ = try? FileManager.default.linkItem(atPath: paths.complete, toPath: symlinkPath)
                        }
                        subscriber.putNext(MediaResourceData(path: symlinkPath, offset: 0, size: size, complete: true))
                        subscriber.putCompletion()
                    } else {
                        subscriber.putNext(MediaResourceData(path: paths.complete, offset: 0, size: size, complete: true))
                        subscriber.putCompletion()
                    }
                } else if fetch {
                    if attemptSynchronously && complete {
                        subscriber.putNext(MediaResourceData(path: paths.partial, offset: 0, size: 0, complete: false))
                    }
                    self.dataQueue.async {
                        let key = CachedMediaResourceRepresentationKey(resourceId: resource.id, representation: representation)
                        let context: CachedMediaResourceRepresentationContext
                        if let currentContext = self.cachedRepresentationContexts[key] {
                            context = currentContext
                        } else {
                            context = CachedMediaResourceRepresentationContext()
                            self.cachedRepresentationContexts[key] = context
                        }
                        
                        let index = context.dataSubscribers.add(CachedMediaResourceRepresentationSubscriber(update: { data in
                            if !complete || data.complete {
                                if let pathExtension = pathExtension, data.complete {
                                    let symlinkPath = data.path + ".\(pathExtension)"
                                    if fileSize(symlinkPath) == nil {
                                        let _ = try? FileManager.default.linkItem(atPath: data.path, toPath: symlinkPath)
                                    }
                                    subscriber.putNext(MediaResourceData(path: symlinkPath, offset: data.offset, size: data.size, complete: data.complete))
                                } else {
                                    subscriber.putNext(data)
                                }
                            }
                            if data.complete {
                                subscriber.putCompletion()
                            }
                        }, onlyComplete: complete))
                        if let currentData = context.currentData {
                            if !complete || currentData.complete {
                                subscriber.putNext(currentData)
                            }
                            if currentData.complete {
                                subscriber.putCompletion()
                            }
                        } else if !complete {
                            subscriber.putNext(MediaResourceData(path: paths.partial, offset: 0, size: 0, complete: false))
                        }
                        
                        disposable.set(ActionDisposable { [weak context] in
                            self.dataQueue.async {
                                if let currentContext = self.cachedRepresentationContexts[key], currentContext === context {
                                    currentContext.dataSubscribers.remove(index)
                                    if currentContext.dataSubscribers.isEmpty {
                                        currentContext.disposable.dispose()
                                        self.cachedRepresentationContexts.removeValue(forKey: key)
                                    }
                                }
                            }
                        })
                        
                        if !context.initialized {
                            context.initialized = true
                            let signal = self.wrappedFetchCachedResourceRepresentation.get()
                            |> take(1)
                            |> mapToSignal { fetch in
                                return fetch(resource, representation)
                                |> map(Optional.init)
                            }
                            |> deliverOn(self.dataQueue)
                            context.disposable.set(signal.start(next: { [weak self, weak context] next in
                                guard let strongSelf = self else {
                                    return
                                }
                                if let next = next {
                                    var isDone = false
                                    switch next {
                                    case let .temporaryPath(temporaryPath):
                                        rename(temporaryPath, paths.complete)
                                        isDone = true
                                    case let .tempFile(tempFile):
                                        rename(tempFile.path, paths.complete)
                                        TempBox.shared.dispose(tempFile)
                                        isDone = true
                                    case .reset:
                                        let file = ManagedFile(queue: strongSelf.dataQueue, path: paths.partial, mode: .readwrite)
                                        file?.truncate(count: 0)
                                        unlink(paths.complete)
                                    case let .data(dataPart):
                                        let file = ManagedFile(queue: strongSelf.dataQueue, path: paths.partial, mode: .append)
                                        let dataCount = dataPart.count
                                        dataPart.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> Void in
                                            file?.write(bytes, count: dataCount)
                                        }
                                    case .done:
                                        link(paths.partial, paths.complete)
                                        isDone = true
                                    }
                                    
                                    if let strongSelf = self, let currentContext = strongSelf.cachedRepresentationContexts[key], currentContext === context {
                                        if isDone {
                                            currentContext.disposable.dispose()
                                            strongSelf.cachedRepresentationContexts.removeValue(forKey: key)
                                        }
                                        if let size = fileSize(paths.complete) {
                                            let data = MediaResourceData(path: paths.complete, offset: 0, size: size, complete: isDone)
                                            currentContext.currentData = data
                                            for subscriber in currentContext.dataSubscribers.copyItems() {
                                                if !subscriber.onlyComplete || isDone {
                                                    subscriber.update(data)
                                                }
                                            }
                                        } else if let size = fileSize(paths.partial) {
                                            let data = MediaResourceData(path: paths.partial, offset: 0, size: size, complete: isDone)
                                            currentContext.currentData = data
                                            for subscriber in currentContext.dataSubscribers.copyItems() {
                                                if !subscriber.onlyComplete || isDone {
                                                    subscriber.update(data)
                                                }
                                            }
                                        }
                                    }
                                } else {
                                    if let strongSelf = self, let context = strongSelf.cachedRepresentationContexts[key] {
                                        let data = MediaResourceData(path: paths.partial, offset: 0, size: 0, complete: false)
                                        context.currentData = data
                                        for subscriber in context.dataSubscribers.copyItems() {
                                            if !subscriber.onlyComplete {
                                                subscriber.update(data)
                                            }
                                        }
                                    }
                                }
                            }))
                        }
                    }
                } else {
                    subscriber.putNext(MediaResourceData(path: paths.partial, offset: 0, size: 0, complete: false))
                    subscriber.putCompletion()
                }
            }
            if attemptSynchronously {
                begin()
            } else {
                self.concurrentQueue.async(begin)
            }
            return ActionDisposable {
                disposable.dispose()
            }
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
                    } else if let size = fileSize(paths.partial, useTotalFileAllocatedSize: true) {
                        result[wrappedId] = Int64(size)
                    }
                }
                subscriber.putNext(result)
                subscriber.putCompletion()
            }
            return EmptyDisposable
        }
    }
    
    public func collectOtherResourceUsage(excludeIds: Set<WrappedMediaResourceId>, combinedExcludeIds: Set<WrappedMediaResourceId>) -> Signal<(Int64, [String], Int64), NoError> {
        return Signal { subscriber in
            self.dataQueue.async {
                var result: Int64 = 0
                
                var excludeNames = Set<String>()
                for id in combinedExcludeIds {
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
                
                var excludePrefixes = Set<String>()
                for id in excludeIds {
                    let cachedRepresentationPrefix = self.fileNameForId(id.id)
                    
                    excludePrefixes.insert(cachedRepresentationPrefix)
                }
                
                if let enumerator = FileManager.default.enumerator(at: URL(fileURLWithPath: self.basePath + "/cache"), includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants], errorHandler: nil) {
                    loop: for url in enumerator {
                        if let url = url as? URL {
                            if let prefix = url.lastPathComponent.components(separatedBy: ":").first, excludePrefixes.contains(prefix) {
                                continue loop
                            }
                            
                            if let value = (try? url.resourceValues(forKeys: Set([.fileSizeKey])))?.fileSize, value != 0 {
                                paths.append("cache/" + url.lastPathComponent)
                                cacheResult += Int64(value)
                            }
                        }
                    }
                }
                
                if let enumerator = FileManager.default.enumerator(at: URL(fileURLWithPath: self.basePath + "/short-cache"), includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants], errorHandler: nil) {
                    loop: for url in enumerator {
                        if let url = url as? URL {
                            if let prefix = url.lastPathComponent.components(separatedBy: ":").first, excludePrefixes.contains(prefix) {
                                continue loop
                            }
                            
                            if let value = (try? url.resourceValues(forKeys: Set([.fileSizeKey])))?.fileSize, value != 0 {
                                paths.append("short-cache/" + url.lastPathComponent)
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
                subscriber.putCompletion()
            }
            return EmptyDisposable
        }
    }
    
    public func removeCachedResources(_ ids: Set<WrappedMediaResourceId>) -> Signal<Void, NoError> {
        return Signal { subscriber in
            self.dataQueue.async {
                for id in ids {
                    if self.fileContexts[id] != nil {
                        continue
                    }
                    let paths = self.storePathsForId(id.id)
                    unlink(paths.complete)
                    unlink(paths.partial)
                    unlink(paths.partial + ".meta")
                    self.fileContexts.removeValue(forKey: id)
                }
                
                let uniqueIds = Set(ids.map { $0.id.uniqueId })
                
                var pathsToDelete: [String] = []
                
                for cacheType in ["cache", "short-cache"] {
                    if let enumerator = FileManager.default.enumerator(at: URL(fileURLWithPath: "\(self.basePath)/\(cacheType)"), includingPropertiesForKeys: [], options: [.skipsSubdirectoryDescendants], errorHandler: nil) {
                        while let item = enumerator.nextObject() {
                            guard let url = item as? NSURL, let path = url.path, let fileName = url.lastPathComponent else {
                                continue
                            }
                            
                            if let range = fileName.range(of: ":") {
                                let resourceId = String(fileName[fileName.startIndex ..< range.lowerBound])
                                if uniqueIds.contains(resourceId) {
                                    pathsToDelete.append(path)
                                }
                            }
                        }
                    }
                }
                
                for path in pathsToDelete {
                    unlink(path)
                }
                
                subscriber.putCompletion()
            }
            return EmptyDisposable
        }
    }
    
    public func clearFileContexts() -> Signal<Void, NoError> {
        return Signal { subscriber in
            self.dataQueue.async {
                for (id, _) in self.fileContexts {
                    let paths = self.storePathsForId(id.id)
                    unlink(paths.complete)
                    unlink(paths.partial)
                    unlink(paths.partial + ".meta")
                }
                self.fileContexts.removeAll()
                subscriber.putCompletion()
            }
            return EmptyDisposable
        }
    }
    
    public func fileConxtets() -> Signal<[(partial: String, complete: String)], NoError> {
        return Signal { subscriber in
            self.dataQueue.async {
                var result: [(partial: String, complete: String)] = []
                for (id, _) in self.fileContexts {
                    let paths = self.storePathsForId(id.id)
                    result.append((partial: paths.partial, complete: paths.complete))
                }
                subscriber.putNext(result)
                subscriber.putCompletion()
            }
            return EmptyDisposable
        }
    }
}
