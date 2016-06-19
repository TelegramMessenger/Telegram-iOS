import Foundation
import SwiftSignalKit

private final class ResourceStatusContext {
    var status: MediaResourceStatus?
    let subscribers = Bag<(MediaResourceStatus) -> Void>()
}

private final class ResourceDataContext {
    var data: MediaResourceData
    let progresiveDataSubscribers = Bag<(MediaResourceData) -> Void>()
    let completeDataSubscribers = Bag<(MediaResourceData) -> Void>()
    
    var fetchDisposable: Disposable?
    let fetchSubscribers = Bag<Void>()
    
    init(data: MediaResourceData) {
        self.data = data
    }
}

private func fileSize(_ path: String) -> Int {
    var value = stat()
    stat(path, &value)
    return Int(value.st_size)
}

public final class MediaBox {
    let basePath: String
    let buffer = WriteBuffer()
    
    private let statusQueue = Queue()
    private let dataQueue = Queue()
    
    private var statusContexts: [String: ResourceStatusContext] = [:]
    private var dataContexts: [String: ResourceDataContext] = [:]
    
    private var wrappedFetchResource = Promise<(MediaResource, Int) -> Signal<Data, NoError>>()
    public var fetchResource: ((MediaResource, Int) -> Signal<Data, NoError>)? {
        didSet {
            if let fetchResource = self.fetchResource {
                wrappedFetchResource.set(.single(fetchResource))
            } else {
                wrappedFetchResource.set(.never())
            }
        }
    }
    
    lazy var ensureDirectoryCreated: Void = {
        try! FileManager.default().createDirectory(atPath: self.basePath, withIntermediateDirectories: true, attributes: nil)
    }()
    
    public init(basePath: String) {
        self.basePath = basePath
    }
    
    private func pathForId(_ id: String) -> String {
        return "\(self.basePath)/\(id)"
    }
    
    public func resourceStatus(_ resource: MediaResource) -> Signal<MediaResourceStatus, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            
            self.statusQueue.async {
                let statusContext: ResourceStatusContext
                if let current = self.statusContexts[resource.id] {
                    statusContext = current
                } else {
                    statusContext = ResourceStatusContext()
                    self.statusContexts[resource.id] = statusContext
                }
                
                let index = statusContext.subscribers.add({ status in
                    subscriber.putNext(status)
                })
                
                if let status = statusContext.status {
                    subscriber.putNext(status)
                } else {
                    self.dataQueue.async {
                        let status: MediaResourceStatus
                        
                        let path = self.pathForId(resource.id)
                        let currentSize = fileSize(path)
                        if currentSize >= resource.size {
                            status = .Local
                        } else {
                            var fetchingData = false
                            if let dataContext = self.dataContexts[resource.id] {
                                fetchingData = dataContext.fetchDisposable != nil
                            }
                            
                            if fetchingData {
                                status = .Fetching(progress: Float(currentSize) / Float(resource.size))
                            } else {
                                status = .Remote
                            }
                        }
                        
                        self.statusQueue.async {
                            if let statusContext = self.statusContexts[resource.id] where statusContext.status == nil {
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
                        if let current = self.statusContexts[resource.id] {
                            current.subscribers.remove(index)
                            if current.subscribers.isEmpty {
                                self.statusContexts.removeValue(forKey: resource.id)
                            }
                        }
                    }
                })
            }
            
            return disposable
        }
    }
    
    public func resourceData(_ resource: MediaResource, complete: Bool = true) -> Signal<MediaResourceData, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            
            self.dataQueue.async {
                let path = self.pathForId(resource.id)
                let currentSize = fileSize(path)
                
                if currentSize >= resource.size {
                    subscriber.putNext(MediaResourceData(path: path, size: currentSize))
                    subscriber.putCompletion()
                } else {
                    let dataContext: ResourceDataContext
                    if let current = self.dataContexts[resource.id] {
                        dataContext = current
                    } else {
                        dataContext = ResourceDataContext(data: MediaResourceData(path: path, size: currentSize))
                        self.dataContexts[resource.id] = dataContext
                    }
                    
                    let index: Bag<(MediaResourceData) -> Void>.Index
                    if complete {
                        index = dataContext.completeDataSubscribers.add { data in
                            subscriber.putNext(data)
                            if data.size >= resource.size {
                                subscriber.putCompletion()
                            }
                        }
                        if dataContext.data.size >= resource.size {
                            subscriber.putNext(dataContext.data)
                        } else {
                            subscriber.putNext(MediaResourceData(path: dataContext.data.path, size: 0))
                        }
                    } else {
                        index = dataContext.progresiveDataSubscribers.add { data in
                            subscriber.putNext(data)
                            if data.size >= resource.size {
                                subscriber.putCompletion()
                            }
                        }
                        subscriber.putNext(dataContext.data)
                    }
                    
                    disposable.set(ActionDisposable {
                        self.dataQueue.async {
                            if let dataContext = self.dataContexts[resource.id] {
                                if complete {
                                    dataContext.completeDataSubscribers.remove(index)
                                } else {
                                    dataContext.progresiveDataSubscribers.remove(index)
                                }
                                
                                if dataContext.progresiveDataSubscribers.isEmpty && dataContext.completeDataSubscribers.isEmpty && dataContext.fetchSubscribers.isEmpty {
                                    self.dataContexts.removeValue(forKey: resource.id)
                                }
                            }
                        }
                    })
                }
            }
            
            return disposable
        }
    }
    
    public func fetchedResource(_ resource: MediaResource, interactive: Bool) -> Signal<Void, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            
            self.dataQueue.async {
                let path = self.pathForId(resource.id)
                let currentSize = fileSize(path)
                
                if currentSize >= resource.size {
                    subscriber.putCompletion()
                } else {
                    let dataContext: ResourceDataContext
                    if let current = self.dataContexts[resource.id] {
                        dataContext = current
                    } else {
                        dataContext = ResourceDataContext(data: MediaResourceData(path: path, size: currentSize))
                        self.dataContexts[resource.id] = dataContext
                    }
                    
                    let index: Bag<Void>.Index = dataContext.fetchSubscribers.add(Void())
                    
                    if dataContext.fetchDisposable == nil {
                        let status: MediaResourceStatus = .Fetching(progress: Float(currentSize) / Float(resource.size))
                        self.statusQueue.async {
                            if let statusContext = self.statusContexts[resource.id] {
                                statusContext.status = status
                                for subscriber in statusContext.subscribers.copyItems() {
                                    subscriber(status)
                                }
                            }
                        }
                        
                        var offset = currentSize
                        var fd: Int32?
                        dataContext.fetchDisposable = (self.wrappedFetchResource.get() |> mapToSignal { fetch -> Signal<Data, NoError> in
                            return fetch(resource, offset)
                        } |> afterDisposed {
                            if let fd = fd {
                                close(fd)
                            }
                        }).start(next: { data in
                            self.dataQueue.async {
                                let _ = self.ensureDirectoryCreated
                                
                                if fd == nil {
                                    let handle = open(path, O_WRONLY | O_CREAT | O_APPEND, S_IRUSR | S_IWUSR)
                                    if handle >= 0 {
                                        fd = handle
                                    }
                                }
                                
                                if let fd = fd {
                                    data.withUnsafeBytes { bytes in
                                        write(fd, bytes, data.count)
                                    }
                                    
                                    offset += data.count
                                    let updatedSize = offset
                                    
                                    for subscriber in dataContext.progresiveDataSubscribers.copyItems() {
                                        subscriber(MediaResourceData(path: path, size: updatedSize))
                                    }
                                    
                                    if updatedSize >= resource.size {
                                        for subscriber in dataContext.completeDataSubscribers.copyItems() {
                                            subscriber(MediaResourceData(path: path, size: updatedSize))
                                        }
                                    }
                                    
                                    let status: MediaResourceStatus
                                    if updatedSize >= resource.size {
                                        status = .Local
                                    } else {
                                        status = .Fetching(progress: Float(updatedSize) / Float(resource.size))
                                    }
                                    
                                    self.statusQueue.async {
                                        if let statusContext = self.statusContexts[resource.id] {
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
                            if let dataContext = self.dataContexts[resource.id] {
                                dataContext.fetchSubscribers.remove(index)
                                
                                if dataContext.fetchSubscribers.isEmpty {
                                    dataContext.fetchDisposable?.dispose()
                                    dataContext.fetchDisposable = nil
                                    
                                    let currentSize = fileSize(path)
                                    let status: MediaResourceStatus
                                    if currentSize >= resource.size {
                                        status = .Local
                                    } else {
                                        status = .Remote
                                    }
                                    
                                    self.statusQueue.async {
                                        if let statusContext = self.statusContexts[resource.id] where statusContext.status != status {
                                            statusContext.status = status
                                            for subscriber in statusContext.subscribers.copyItems() {
                                                subscriber(status)
                                            }
                                        }
                                    }
                                }
                                
                                if dataContext.completeDataSubscribers.isEmpty && dataContext.progresiveDataSubscribers.isEmpty && dataContext.fetchSubscribers.isEmpty {
                                    self.dataContexts.removeValue(forKey: resource.id)
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
            if let dataContext = self.dataContexts[resource.id] where dataContext.fetchDisposable != nil {
                dataContext.fetchDisposable?.dispose()
                dataContext.fetchDisposable = nil
                    
                let currentSize = fileSize(self.pathForId(resource.id))
                let status: MediaResourceStatus
                if currentSize >= resource.size {
                    status = .Local
                } else {
                    status = .Remote
                }
                
                self.statusQueue.async {
                    if let statusContext = self.statusContexts[resource.id] where statusContext.status != status {
                        statusContext.status = status
                        for subscriber in statusContext.subscribers.copyItems() {
                            subscriber(status)
                        }
                    }
                }
            }
        }
    }
}
