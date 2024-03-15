import Foundation
import TelegramApi
import Postbox
import SwiftSignalKit
import MtProtoKit

enum MultiplexedRequestTarget: Equatable, Hashable, CustomStringConvertible {
    case main(Int)
    case cdn(Int)
    
    var description: String {
        switch self {
        case let .main(id):
            return "dc\(id)"
        case let .cdn(id):
            return "cdn\(id)"
        }
    }
}

private struct MultiplexedRequestTargetKey: Equatable, Hashable {
    let target: MultiplexedRequestTarget
    let continueInBackground: Bool
}

private final class RequestData {
    let id: Int32
    let consumerId: Int64
    let resourceId: String?
    let target: MultiplexedRequestTarget
    let functionDescription: FunctionDescription
    let payload: Buffer
    let tag: MediaResourceFetchTag?
    let continueInBackground: Bool
    let automaticFloodWait: Bool
    let expectedResponseSize: Int32?
    let deserializeResponse: (Buffer) -> Any?
    let completed: (Any, NetworkResponseInfo) -> Void
    let error: (MTRpcError, Double) -> Void
    
    init(id: Int32, consumerId: Int64, resourceId: String?, target: MultiplexedRequestTarget, functionDescription: FunctionDescription, payload: Buffer, tag: MediaResourceFetchTag?, continueInBackground: Bool, automaticFloodWait: Bool, expectedResponseSize: Int32?, deserializeResponse: @escaping (Buffer) -> Any?, completed: @escaping (Any, NetworkResponseInfo) -> Void, error: @escaping (MTRpcError, Double) -> Void) {
        self.id = id
        self.consumerId = consumerId
        self.resourceId = resourceId
        self.target = target
        self.functionDescription = functionDescription
        self.tag = tag
        self.continueInBackground = continueInBackground
        self.automaticFloodWait = automaticFloodWait
        self.expectedResponseSize = expectedResponseSize
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
    let key: MultiplexedRequestTargetKey
    let id: Int32
}

private typealias SignalKitTimer = SwiftSignalKit.Timer

struct NetworkResponseInfo {
    var timestamp: Double
    var networkType: NetworkStatsContext.NetworkType
    var networkDuration: Double
}

private final class MultiplexedRequestManagerContext {
    final class RequestManagerPriorityContext {
        var resourceCounters: [String: Bag<Int>] = [:]
    }
    
    private let queue: Queue
    private let takeWorker: (MultiplexedRequestTarget, MediaResourceFetchTag?, Bool) -> Download?
    
    private let priorityContext = RequestManagerPriorityContext()
    private var queuedRequests: [RequestData] = []
    private var nextId: Int32 = 0
    
    private var targetContexts: [MultiplexedRequestTargetKey: [RequestTargetContext]] = [:]
    private var emptyTargetDisposables: [MultiplexedRequestTargetTimerKey: Disposable] = [:]
    
    init(queue: Queue, takeWorker: @escaping (MultiplexedRequestTarget, MediaResourceFetchTag?, Bool) -> Download?) {
        self.queue = queue
        self.takeWorker = takeWorker
    }
    
    deinit {
        for targetContextList in self.targetContexts.values {
            for targetContext in targetContextList {
                for request in targetContext.requests {
                    request.disposable.dispose()
                }
            }
        }
        for disposable in emptyTargetDisposables.values {
            disposable.dispose()
        }
    }
    
    func pushPriority(resourceId: String, priority: Int) -> Disposable {
        let queue = self.queue
        
        let counters: Bag<Int>
        if let current = self.priorityContext.resourceCounters[resourceId] {
            counters = current
        } else {
            counters = Bag()
            self.priorityContext.resourceCounters[resourceId] = counters
        }
        
        let index = counters.add(priority)
        
        self.updateState()
        
        return ActionDisposable { [weak self, weak counters] in
            queue.async {
                guard let `self` = self else {
                    return
                }
                
                if let current = self.priorityContext.resourceCounters[resourceId], current === counters {
                    current.remove(index)
                    if current.isEmpty {
                        self.priorityContext.resourceCounters.removeValue(forKey: resourceId)
                    }
                    self.updateState()
                }
            }
        }
    }
    
    func request(to target: MultiplexedRequestTarget, consumerId: Int64, resourceId: String?, data: (FunctionDescription, Buffer, (Buffer) -> Any?), tag: MediaResourceFetchTag?, continueInBackground: Bool, automaticFloodWait: Bool, expectedResponseSize: Int32?, completed: @escaping (Any, NetworkResponseInfo) -> Void, error: @escaping (MTRpcError, Double) -> Void) -> Disposable {
        let targetKey = MultiplexedRequestTargetKey(target: target, continueInBackground: continueInBackground)
        
        let requestId = self.nextId
        self.nextId += 1
        self.queuedRequests.append(RequestData(id: requestId, consumerId: consumerId, resourceId: resourceId, target: target, functionDescription: data.0, payload: data.1, tag: tag, continueInBackground: continueInBackground, automaticFloodWait: automaticFloodWait, expectedResponseSize: expectedResponseSize, deserializeResponse: { buffer in
            return data.2(buffer)
        }, completed: { result, info in
            completed(result, info)
        }, error: { e, timestamp in
            error(e, timestamp)
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
                
                if strongSelf.targetContexts[targetKey] != nil {
                    outer: for targetContext in strongSelf.targetContexts[targetKey]! {
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
        let maxRequestsPerWorker = 3
        let maxWorkersPerTarget = 4
        
        for request in self.queuedRequests.sorted(by: { lhs, rhs in
            let lhsPriority = lhs.resourceId.flatMap { id in
                if let counters = self.priorityContext.resourceCounters[id] {
                    return counters.copyItems().max() ?? 0
                } else {
                    return 0
                }
            } ?? 0
            let rhsPriority = rhs.resourceId.flatMap { id in
                if let counters = self.priorityContext.resourceCounters[id] {
                    return counters.copyItems().max() ?? 0
                } else {
                    return 0
                }
            } ?? 0
            
            if lhsPriority != rhsPriority {
                return lhsPriority > rhsPriority
            }
            
            return lhs.id < rhs.id
        }) {
            let targetKey = MultiplexedRequestTargetKey(target: request.target, continueInBackground: request.continueInBackground)
            
            if self.targetContexts[targetKey] == nil {
                self.targetContexts[targetKey] = []
            }
            var selectedContext: RequestTargetContext?
            for targetContext in self.targetContexts[targetKey]! {
                if targetContext.requests.count < maxRequestsPerWorker {
                    selectedContext = targetContext
                    break
                }
            }
            if selectedContext == nil && self.targetContexts[targetKey]!.count < maxWorkersPerTarget {
                if let worker = self.takeWorker(request.target, request.tag, request.continueInBackground) {
                    let contextId = self.nextId
                    self.nextId += 1
                    let targetContext = RequestTargetContext(id: contextId, worker: worker)
                    self.targetContexts[targetKey]!.append(targetContext)
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
                disposable.set(selectedContext.worker.rawRequest((request.functionDescription, request.payload, request.deserializeResponse), automaticFloodWait: request.automaticFloodWait, expectedResponseSize: request.expectedResponseSize).start(next: { [weak self, weak selectedContext] result, info in
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
                        request.completed(result, info)
                        strongSelf.updateState()
                    }
                }, error: { [weak self, weak selectedContext] error, timestamp in
                    queue.async {
                        guard let strongSelf = self else {
                            return
                        }
                        request.error(error, timestamp)
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
                
                if let requestIndex = self.queuedRequests.firstIndex(where: { $0 === request }) {
                    self.queuedRequests.remove(at: requestIndex)
                }
                continue
            }
        }
        
        self.checkEmptyContexts()
    }
    
    private func checkEmptyContexts() {
        for (targetKey, contexts) in self.targetContexts {
            for context in contexts {
                let key = MultiplexedRequestTargetTimerKey(key: targetKey, id: context.id)
                if context.requests.isEmpty {
                    if self.emptyTargetDisposables[key] == nil {
                        let disposable = MetaDisposable()
                        self.emptyTargetDisposables[key] = disposable
                        
                        disposable.set((Signal<Never, NoError>.complete()
                        |> delay(20 * 60, queue: self.queue)
                        |> deliverOn(self.queue)).start(completed: { [weak self] in
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.emptyTargetDisposables.removeValue(forKey: key)
                            if strongSelf.targetContexts[targetKey] != nil {
                                for i in 0 ..< strongSelf.targetContexts[targetKey]!.count {
                                    if strongSelf.targetContexts[targetKey]![i].id == key.id {
                                        strongSelf.targetContexts[targetKey]!.remove(at: i)
                                        break
                                    }
                                }
                            }
                        }))
                    }
                } else {
                    if let disposable = self.emptyTargetDisposables[key] {
                        disposable.dispose()
                        self.emptyTargetDisposables.removeValue(forKey: key)
                    }
                }
            }
        }
    }
}

final class MultiplexedRequestManager {
    private let queue = Queue()
    private let context: QueueLocalObject<MultiplexedRequestManagerContext>
    
    init(takeWorker: @escaping (MultiplexedRequestTarget, MediaResourceFetchTag?, Bool) -> Download?) {
        let queue = self.queue
        self.context = QueueLocalObject(queue: self.queue, generate: {
            return MultiplexedRequestManagerContext(queue: queue, takeWorker: takeWorker)
        })
    }
    
    func pushPriority(resourceId: String, priority: Int) -> Disposable {
        let disposable = MetaDisposable()
        self.context.with { context in
            disposable.set(context.pushPriority(resourceId: resourceId, priority: priority))
        }
        return disposable
    }
    
    func request<T>(to target: MultiplexedRequestTarget, consumerId: Int64, resourceId: String?, data: (FunctionDescription, Buffer, DeserializeFunctionResponse<T>), tag: MediaResourceFetchTag?, continueInBackground: Bool, automaticFloodWait: Bool = true, expectedResponseSize: Int32?) -> Signal<T, MTRpcError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.context.with { context in
                disposable.set(context.request(to: target, consumerId: consumerId, resourceId: resourceId, data: (data.0, data.1, { buffer in
                    return data.2.parse(buffer)
                }), tag: tag, continueInBackground: continueInBackground, automaticFloodWait: automaticFloodWait, expectedResponseSize: expectedResponseSize, completed: { result, _ in
                    if let result = result as? T {
                        subscriber.putNext(result)
                        subscriber.putCompletion()
                    } else {
                        subscriber.putError(MTRpcError(errorCode: 500, errorDescription: "TL_VERIFICATION_ERROR"))
                    }
                }, error: { error, _ in
                    subscriber.putError(error)
                }))
            }
            return disposable
        }
    }
    
    func requestWithAdditionalInfo<T>(to target: MultiplexedRequestTarget, consumerId: Int64, resourceId: String?, data: (FunctionDescription, Buffer, DeserializeFunctionResponse<T>), tag: MediaResourceFetchTag?, continueInBackground: Bool, automaticFloodWait: Bool = true, expectedResponseSize: Int32?) -> Signal<(T, NetworkResponseInfo), (MTRpcError, Double)> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.context.with { context in
                disposable.set(context.request(to: target, consumerId: consumerId, resourceId: resourceId, data: (data.0, data.1, { buffer in
                    return data.2.parse(buffer)
                }), tag: tag, continueInBackground: continueInBackground, automaticFloodWait: automaticFloodWait, expectedResponseSize: expectedResponseSize, completed: { result, info in
                    if let result = result as? T {
                        subscriber.putNext((result, info))
                        subscriber.putCompletion()
                    } else {
                        subscriber.putError((MTRpcError(errorCode: 500, errorDescription: "TL_VERIFICATION_ERROR"), info.timestamp))
                    }
                }, error: { error, timestamp in
                    subscriber.putError((error, timestamp))
                }))
            }
            return disposable
        }
    }
}
