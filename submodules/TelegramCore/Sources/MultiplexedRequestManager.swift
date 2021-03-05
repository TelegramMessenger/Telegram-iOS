import Foundation
import TelegramApi
import Postbox
import SwiftSignalKit
import MtProtoKit

enum MultiplexedRequestTarget: Equatable, Hashable {
    case main(Int)
    case cdn(Int)
}

private struct MultiplexedRequestTargetKey: Equatable, Hashable {
    let target: MultiplexedRequestTarget
    let continueInBackground: Bool
}

private final class RequestData {
    let id: Int32
    let consumerId: Int64
    let target: MultiplexedRequestTarget
    let functionDescription: FunctionDescription
    let payload: Buffer
    let tag: MediaResourceFetchTag?
    let continueInBackground: Bool
    let automaticFloodWait: Bool
    let deserializeResponse: (Buffer) -> Any?
    let completed: (Any, Double) -> Void
    let error: (MTRpcError, Double) -> Void
    
    init(id: Int32, consumerId: Int64, target: MultiplexedRequestTarget, functionDescription: FunctionDescription, payload: Buffer, tag: MediaResourceFetchTag?, continueInBackground: Bool, automaticFloodWait: Bool, deserializeResponse: @escaping (Buffer) -> Any?, completed: @escaping (Any, Double) -> Void, error: @escaping (MTRpcError, Double) -> Void) {
        self.id = id
        self.consumerId = consumerId
        self.target = target
        self.functionDescription = functionDescription
        self.tag = tag
        self.continueInBackground = continueInBackground
        self.automaticFloodWait = automaticFloodWait
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


private final class MultiplexedRequestManagerContext {
    private let queue: Queue
    private let takeWorker: (MultiplexedRequestTarget, MediaResourceFetchTag?, Bool) -> Download?
    
    private var queuedRequests: [RequestData] = []
    private var nextId: Int32 = 0
    
    private var targetContexts: [MultiplexedRequestTargetKey: [RequestTargetContext]] = [:]
    private var emptyTargetTimers: [MultiplexedRequestTargetTimerKey: SignalKitTimer] = [:]
    
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
        for timer in emptyTargetTimers.values {
            timer.invalidate()
        }
    }
    
    func request(to target: MultiplexedRequestTarget, consumerId: Int64, data: (FunctionDescription, Buffer, (Buffer) -> Any?), tag: MediaResourceFetchTag?, continueInBackground: Bool, automaticFloodWait: Bool, completed: @escaping (Any, Double) -> Void, error: @escaping (MTRpcError, Double) -> Void) -> Disposable {
        let targetKey = MultiplexedRequestTargetKey(target: target, continueInBackground: continueInBackground)
        
        let requestId = self.nextId
        self.nextId += 1
        self.queuedRequests.append(RequestData(id: requestId, consumerId: consumerId, target: target, functionDescription: data.0, payload: data.1, tag: tag, continueInBackground: continueInBackground, automaticFloodWait: automaticFloodWait, deserializeResponse: { buffer in
            return data.2(buffer)
        }, completed: { result, timestamp in
            completed(result, timestamp)
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
        
        var requestIndex = 0
        while requestIndex < self.queuedRequests.count {
            let request = self.queuedRequests[requestIndex]
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
                disposable.set(selectedContext.worker.rawRequest((request.functionDescription, request.payload, request.deserializeResponse), automaticFloodWait: request.automaticFloodWait).start(next: { [weak self, weak selectedContext] result, timestamp in
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
                        request.completed(result, timestamp)
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
                
                self.queuedRequests.remove(at: requestIndex)
                continue
            }
            
            requestIndex += 1
        }
        
        self.checkEmptyContexts()
    }
    
    private func checkEmptyContexts() {
        for (targetKey, contexts) in self.targetContexts {
            for context in contexts {
                let key = MultiplexedRequestTargetTimerKey(key: targetKey, id: context.id)
                if context.requests.isEmpty {
                    if self.emptyTargetTimers[key] == nil {
                        let timer = SignalKitTimer(timeout: 2.0, repeat: false, completion: { [weak self] in
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.emptyTargetTimers.removeValue(forKey: key)
                            if strongSelf.targetContexts[targetKey] != nil {
                                for i in 0 ..< strongSelf.targetContexts[targetKey]!.count {
                                    if strongSelf.targetContexts[targetKey]![i].id == key.id {
                                        strongSelf.targetContexts[targetKey]!.remove(at: i)
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
    
    init(takeWorker: @escaping (MultiplexedRequestTarget, MediaResourceFetchTag?, Bool) -> Download?) {
        let queue = self.queue
        self.context = QueueLocalObject(queue: self.queue, generate: {
            return MultiplexedRequestManagerContext(queue: queue, takeWorker: takeWorker)
        })
    }
    
    func request<T>(to target: MultiplexedRequestTarget, consumerId: Int64, data: (FunctionDescription, Buffer, DeserializeFunctionResponse<T>), tag: MediaResourceFetchTag?, continueInBackground: Bool, automaticFloodWait: Bool = true) -> Signal<T, MTRpcError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.context.with { context in
                disposable.set(context.request(to: target, consumerId: consumerId, data: (data.0, data.1, { buffer in
                    return data.2.parse(buffer)
                }), tag: tag, continueInBackground: continueInBackground, automaticFloodWait: automaticFloodWait, completed: { result, _ in
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
    
    func requestWithAdditionalInfo<T>(to target: MultiplexedRequestTarget, consumerId: Int64, data: (FunctionDescription, Buffer, DeserializeFunctionResponse<T>), tag: MediaResourceFetchTag?, continueInBackground: Bool, automaticFloodWait: Bool = true) -> Signal<(T, Double), (MTRpcError, Double)> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.context.with { context in
                disposable.set(context.request(to: target, consumerId: consumerId, data: (data.0, data.1, { buffer in
                    return data.2.parse(buffer)
                }), tag: tag, continueInBackground: continueInBackground, automaticFloodWait: automaticFloodWait, completed: { result, timestamp in
                    if let result = result as? T {
                        subscriber.putNext((result, timestamp))
                        subscriber.putCompletion()
                    } else {
                        subscriber.putError((MTRpcError(errorCode: 500, errorDescription: "TL_VERIFICATION_ERROR"), timestamp))
                    }
                }, error: { error, timestamp in
                    subscriber.putError((error, timestamp))
                }))
            }
            return disposable
        }
    }
}
