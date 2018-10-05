import Foundation
#if os(macOS)
import PostboxMac
import SwiftSignalKitMac
import MtProtoKitMac
#else
import Postbox
import SwiftSignalKit
import MtProtoKitDynamic
#endif

enum MultiplexedRequestTarget: Equatable, Hashable {
    case main(Int)
    case cdn(Int)
}

private final class RequestData {
    let id: Int32
    let consumerId: Int64
    let target: MultiplexedRequestTarget
    let functionDescription: FunctionDescription
    let payload: Buffer
    let tag: MediaResourceFetchTag?
    let deserializeResponse: (Buffer) -> Any?
    let completed: (Any) -> Void
    let error: (MTRpcError) -> Void
    
    init(id: Int32, consumerId: Int64, target: MultiplexedRequestTarget, functionDescription: FunctionDescription, payload: Buffer, tag: MediaResourceFetchTag?, deserializeResponse: @escaping (Buffer) -> Any?, completed: @escaping (Any) -> Void, error: @escaping (MTRpcError) -> Void) {
        self.id = id
        self.consumerId = consumerId
        self.target = target
        self.functionDescription = functionDescription
        self.tag = tag
        self.payload = payload
        self.deserializeResponse = deserializeResponse
        self.completed = completed
        self.error = error
    }
}

private final class ExecutingRequestData {
    let requestId: Int32
    let disposable: Disposable
    
    init(requestId: Int32, disposable: Disposable) {
        self.requestId = requestId
        self.disposable = disposable
    }
}

private final class RequestTargetContext {
    let id: Int32
    let worker: Download
    var requests: [ExecutingRequestData]
    
    init(id: Int32, worker: Download) {
        self.id = id
        self.worker = worker
        self.requests = []
    }
}

private struct MultiplexedRequestTargetTimerKey: Equatable, Hashable {
    let target: MultiplexedRequestTarget
    let id: Int32
}

#if os(macOS)
private typealias SignalKitTimer = SwiftSignalKitMac.Timer
#else
private typealias SignalKitTimer = SwiftSignalKit.Timer
#endif

private final class MultiplexedRequestManagerContext {
    private let queue: Queue
    private let takeWorker: (MultiplexedRequestTarget, MediaResourceFetchTag?) -> Download?
    
    private var queuedRequests: [RequestData] = []
    private var nextId: Int32 = 0
    
    private var targetContexts: [MultiplexedRequestTarget: [RequestTargetContext]] = [:]
    private var emptyTargetTimers: [MultiplexedRequestTargetTimerKey: SignalKitTimer] = [:]
    
    init(queue: Queue, takeWorker: @escaping (MultiplexedRequestTarget, MediaResourceFetchTag?) -> Download?) {
        self.queue = queue
        self.takeWorker = takeWorker
    }
    
    deinit {
        for targetContextList in targetContexts.values {
            for targetContext in targetContextList {
                for request in targetContext.requests {
                    request.disposable.dispose()
                }
            }
        }
        for timer in emptyTargetTimers.values {
            timer.invalidate()
        }
    }
    
    func request(to target: MultiplexedRequestTarget, consumerId: Int64, data: (FunctionDescription, Buffer, (Buffer) -> Any?), tag: MediaResourceFetchTag?, completed: @escaping (Any) -> Void, error: @escaping (MTRpcError) -> Void) -> Disposable {
        let requestId = self.nextId
        self.nextId += 1
        self.queuedRequests.append(RequestData(id: requestId, consumerId: consumerId, target: target, functionDescription: data.0, payload: data.1, tag: tag, deserializeResponse: { buffer in
            return data.2(buffer)
        }, completed: { result in
            completed(result)
        }, error: { e in
            error(e)
        }))
        
        self.updateState()
        
        let queue = self.queue
        return ActionDisposable { [weak self] in
            queue.async {
                guard let strongSelf = self else {
                    return
                }
                for i in 0 ..< strongSelf.queuedRequests.count {
                    if strongSelf.queuedRequests[i].id == requestId {
                        strongSelf.queuedRequests.remove(at: i)
                        break
                    }
                }
                
                if strongSelf.targetContexts[target] != nil {
                    outer: for targetContext in strongSelf.targetContexts[target]! {
                        for i in 0 ..< targetContext.requests.count {
                            if targetContext.requests[i].requestId == requestId {
                                targetContext.requests[i].disposable.dispose()
                                targetContext.requests.remove(at: i)
                                break outer
                            }
                        }
                    }
                }
                
                strongSelf.updateState()
            }
        }
    }
    
    private func updateState() {
        let maxRequestsPerWorker = 2
        let maxWorkersPerTarget = 4
        
        var requestIndex = 0
        while requestIndex < self.queuedRequests.count {
            let request = self.queuedRequests[requestIndex]
            
            if self.targetContexts[request.target] == nil {
                self.targetContexts[request.target] = []
            }
            var selectedContext: RequestTargetContext?
            for targetContext in self.targetContexts[request.target]! {
                if targetContext.requests.count < maxRequestsPerWorker {
                    selectedContext = targetContext
                    break
                }
            }
            if selectedContext == nil && self.targetContexts[request.target]!.count < maxWorkersPerTarget {
                if let worker = self.takeWorker(request.target, request.tag) {
                    let contextId = self.nextId
                    self.nextId += 1
                    let targetContext = RequestTargetContext(id: contextId, worker: worker)
                    self.targetContexts[request.target]!.append(targetContext)
                    selectedContext = targetContext
                } else {
                    Logger.shared.log("MultiplexedRequestManager", "couldn't take worker")
                }
            }
            if let selectedContext = selectedContext {
                let disposable = MetaDisposable()
                let requestId = request.id
                selectedContext.requests.append(ExecutingRequestData(requestId: requestId, disposable: disposable))
                let queue = self.queue
                disposable.set(selectedContext.worker.rawRequest((request.functionDescription, request.payload, request.deserializeResponse)).start(next: { [weak self, weak selectedContext] result in
                    queue.async {
                        guard let strongSelf = self else {
                            return
                        }
                        if let selectedContext = selectedContext {
                            for i in 0 ..< selectedContext.requests.count {
                                if selectedContext.requests[i].requestId == requestId {
                                    selectedContext.requests.remove(at: i)
                                    break
                                }
                            }
                        }
                        request.completed(result)
                        strongSelf.updateState()
                    }
                }, error: { [weak self, weak selectedContext] error in
                    queue.async {
                        guard let strongSelf = self else {
                            return
                        }
                        request.error(error)
                        if let selectedContext = selectedContext {
                            for i in 0 ..< selectedContext.requests.count {
                                if selectedContext.requests[i].requestId == requestId {
                                    selectedContext.requests.remove(at: i)
                                    break
                                }
                            }
                        }
                        strongSelf.updateState()
                    }
                }))
                
                self.queuedRequests.remove(at: requestIndex)
                continue
            }
            
            requestIndex += 1
        }
        
        self.checkEmptyContexts()
    }
    
    private func checkEmptyContexts() {
        for (target, contexts) in self.targetContexts {
            for context in contexts {
                let key = MultiplexedRequestTargetTimerKey(target: target, id: context.id)
                if context.requests.isEmpty {
                    if self.emptyTargetTimers[key] == nil {
                        let timer = SignalKitTimer(timeout: 2.0, repeat: false, completion: { [weak self] in
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.emptyTargetTimers.removeValue(forKey: key)
                            if strongSelf.targetContexts[target] != nil {
                                for i in 0 ..< strongSelf.targetContexts[target]!.count {
                                    if strongSelf.targetContexts[target]![i].id == key.id {
                                        strongSelf.targetContexts[target]!.remove(at: i)
                                        break
                                    }
                                }
                            }
                        }, queue: self.queue)
                        self.emptyTargetTimers[key] = timer
                        timer.start()
                    }
                } else {
                    if let timer = self.emptyTargetTimers[key] {
                        timer.invalidate()
                        self.emptyTargetTimers.removeValue(forKey: key)
                    }
                }
            }
        }
    }
}

final class MultiplexedRequestManager {
    private let queue = Queue()
    private let context: QueueLocalObject<MultiplexedRequestManagerContext>
    
    init(takeWorker: @escaping (MultiplexedRequestTarget, MediaResourceFetchTag?) -> Download?) {
        let queue = self.queue
        self.context = QueueLocalObject(queue: self.queue, generate: {
            return MultiplexedRequestManagerContext(queue: queue, takeWorker: takeWorker)
        })
    }
    
    func request<T>(to target: MultiplexedRequestTarget, consumerId: Int64, data: (FunctionDescription, Buffer, DeserializeFunctionResponse<T>), tag: MediaResourceFetchTag?) -> Signal<T, MTRpcError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.context.with { context in
                disposable.set(context.request(to: target, consumerId: consumerId, data: (data.0, data.1, { buffer in
                    return data.2.parse(buffer)
                }), tag: tag, completed: { result in
                    if let result = result as? T {
                        subscriber.putNext(result)
                        subscriber.putCompletion()
                    } else {
                        subscriber.putError(MTRpcError(errorCode: 500, errorDescription: "TL_VERIFICATION_ERROR"))
                    }
                }, error: { error in
                    subscriber.putError(error)
                }))
            }
            return disposable
        }
    }
}
