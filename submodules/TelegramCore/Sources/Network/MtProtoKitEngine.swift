import Foundation
import SwiftSignalKit
import MtProtoKit

private struct MTProtoConnectionFlags: OptionSet {
    let rawValue: Int
    
    static let NetworkAvailable = MTProtoConnectionFlags(rawValue: 1)
    static let Connected = MTProtoConnectionFlags(rawValue: 2)
    static let UpdatingConnectionContext = MTProtoConnectionFlags(rawValue: 4)
    static let PerformingServiceTasks = MTProtoConnectionFlags(rawValue: 8)
    static let ProxyHasConnectionIssues = MTProtoConnectionFlags(rawValue: 16)
}

private struct MTProtoConnectionInfo: Equatable {
    var flags: MTProtoConnectionFlags
    var proxyAddress: String?
}

private class MTProtoConnectionStatusDelegate: NSObject, MTProtoDelegate {
    var action: (MTProtoConnectionInfo) -> () = { _ in }
    let info = Atomic<MTProtoConnectionInfo>(value: MTProtoConnectionInfo(flags: [], proxyAddress: nil))
    
    @objc func mtProtoNetworkAvailabilityChanged(_ mtProto: MTProto!, isNetworkAvailable: Bool) {
        self.action(self.info.modify { info in
            var info = info
            if isNetworkAvailable {
                info.flags = info.flags.union([.NetworkAvailable])
            } else {
                info.flags = info.flags.subtracting([.NetworkAvailable])
            }
            return info
        })
    }
    
    @objc func mtProtoConnectionStateChanged(_ mtProto: MTProto!, state: MTProtoConnectionState!) {
        self.action(self.info.modify { info in
            var info = info
            if let state = state {
                if state.isConnected {
                    info.flags.insert(.Connected)
                    info.flags.remove(.ProxyHasConnectionIssues)
                } else {
                    info.flags.remove(.Connected)
                    if state.proxyHasConnectionIssues {
                        info.flags.insert(.ProxyHasConnectionIssues)
                    } else {
                        info.flags.remove(.ProxyHasConnectionIssues)
                    }
                }
            } else {
                info.flags.remove(.Connected)
                info.flags.remove(.ProxyHasConnectionIssues)
            }
            info.proxyAddress = state?.proxyAddress
            return info
        })
    }
    
    @objc func mtProtoConnectionContextUpdateStateChanged(_ mtProto: MTProto!, isUpdatingConnectionContext: Bool) {
        self.action(self.info.modify { info in
            var info = info
            if isUpdatingConnectionContext {
                info.flags = info.flags.union([.UpdatingConnectionContext])
            } else {
                info.flags = info.flags.subtracting([.UpdatingConnectionContext])
            }
            return info
        })
    }
    
    @objc func mtProtoServiceTasksStateChanged(_ mtProto: MTProto!, isPerformingServiceTasks: Bool) {
        self.action(self.info.modify { info in
            var info = info
            if isPerformingServiceTasks {
                info.flags = info.flags.union([.PerformingServiceTasks])
            } else {
                info.flags = info.flags.subtracting([.PerformingServiceTasks])
            }
            return info
        })
    }
}

private extension NetworkEngineConnectionState {
    init(_ info: MTProtoConnectionInfo) {
        self.init(
            isNetworkAvailable: info.flags.contains(.NetworkAvailable),
            isConnected: info.flags.contains(.Connected),
            isUpdatingConnectionContext: info.flags.contains(.UpdatingConnectionContext),
            isPerformingServiceTasks: info.flags.contains(.PerformingServiceTasks),
            proxyAddress: info.proxyAddress,
            proxyHasConnectionIssues: info.flags.contains(.ProxyHasConnectionIssues)
        )
    }
}

private extension NetworkEngineErrorContext {
    init(_ errorContext: MTRequestErrorContext) {
        self.init(
            floodWaitSeconds: Int(errorContext.floodWaitSeconds),
            floodWaitErrorText: errorContext.floodWaitErrorText,
            internalServerErrorCount: Int(errorContext.internalServerErrorCount)
        )
    }
}

private extension NetworkEngineResponseInfo {
    init(_ info: MTRequestResponseInfo?) {
        if let info = info {
            self.init(timestamp: info.timestamp, networkType: info.networkType, duration: info.duration)
        } else {
            self.init(timestamp: 0.0, networkType: 1, duration: 0.0)
        }
    }
}

final class MtProtoKitEngine: NetworkEngine {
    let kind: NetworkEngineKind = .mtProtoKit
    
    private let context: MTContext
    
    init(context: MTContext) {
        self.context = context
    }
    
    func makeSession(datacenterId: Int, role: NetworkEngineSessionRole, usageCalculationInfo: MTNetworkUsageCalculationInfo?, delegate: NetworkEngineSessionDelegate?) -> NetworkEngineSession {
        return MtProtoKitSession(context: self.context, datacenterId: datacenterId, role: role, usageCalculationInfo: usageCalculationInfo, delegate: delegate)
    }
}

private final class MtProtoKitPendingRequest {
    let request: NetworkEngineRequest
    let internalId: Any!
    var isTaken = false
    var isCancelled = false
    var moved: Disposable?

    init(request: NetworkEngineRequest, internalId: Any!) {
        self.request = request
        self.internalId = internalId
    }
}

/// A handover in progress (`movePendingRequests`): where released requests go, and its deadline.
private struct MtProtoKitHandover {
    static let extensionStep: Double = 5.0
    static let longest: Double = 30.0

    let target: NetworkEngineRequestService
    var completions: [() -> Void]
    let startedAt: Double
    var deadline: Double
    var lastAnswerAt: Double?
    var releasedAll = false
    var finished = false
}

private func mtProtoKitHandoverClock() -> Double {
    return ProcessInfo.processInfo.systemUptime
}

private final class MtProtoKitPendingRequests {
    private let lock = NSLock()
    private var requests: [ObjectIdentifier: MtProtoKitPendingRequest] = [:]
    private var handover: MtProtoKitHandover?

    /// Nil when the request was taken; otherwise the session hands its requests over and this one goes
    /// straight to the returned service.
    func insert(_ pending: MtProtoKitPendingRequest, key: ObjectIdentifier) -> NetworkEngineRequestService? {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        if let handover = self.handover {
            return handover.target
        }
        self.requests[key] = pending
        return nil
    }

    /// Whether the answer goes to the caller, and the handover's completion when it was the last request.
    func complete(_ pending: MtProtoKitPendingRequest, key: ObjectIdentifier) -> (deliver: Bool, finished: (() -> Void)?) {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        if pending.isTaken {
            return (false, nil)
        }
        self.requests.removeValue(forKey: key)
        if self.handover != nil {
            self.handover?.lastAnswerAt = mtProtoKitHandoverClock()
            return (true, self.finishIfEmpty())
        }
        return (true, nil)
    }

    func cancel(_ pending: MtProtoKitPendingRequest, key: ObjectIdentifier) -> (moved: Disposable?, finished: (() -> Void)?) {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        pending.isCancelled = true
        self.requests.removeValue(forKey: key)
        return (pending.moved, self.handover != nil ? self.finishIfEmpty() : nil)
    }

    /// A request MtProtoKit let go during the handover, and where it goes.
    func take(key: ObjectIdentifier) -> (MtProtoKitPendingRequest, NetworkEngineRequestService)? {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        guard let handover = self.handover, let pending = self.requests.removeValue(forKey: key), !pending.isCancelled else {
            return nil
        }
        pending.isTaken = true
        return (pending, handover.target)
    }

    /// Every request still here, in no particular order: the handover ends without them being released.
    func takeAll() -> [(MtProtoKitPendingRequest, NetworkEngineRequestService)] {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        guard let handover = self.handover else {
            return []
        }
        let taken = self.requests.values.filter { !$0.isCancelled }
        for pending in taken {
            pending.isTaken = true
        }
        self.requests.removeAll()
        return taken.map { ($0, handover.target) }
    }

    func setMoved(_ pending: MtProtoKitPendingRequest, disposable: Disposable) -> Bool {
        self.lock.lock()
        pending.moved = disposable
        let isCancelled = pending.isCancelled
        self.lock.unlock()
        return isCancelled
    }

    func beginHandover(target: NetworkEngineRequestService, deadline: Double, completion: @escaping () -> Void) -> Bool {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        if var handover = self.handover {
            if handover.finished {
                Queue.concurrentDefaultQueue().async {
                    completion()
                }
            } else {
                handover.completions.append(completion)
                self.handover = handover
            }
            return false
        }
        let now = mtProtoKitHandoverClock()
        self.handover = MtProtoKitHandover(target: target, completions: [completion], startedAt: now, deadline: now + min(max(deadline, 0.0), MtProtoKitHandover.longest))
        return true
    }

    /// The handover's completions once nothing is left, at most once.
    func finishIfDone() -> (() -> Void)? {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        return self.finishIfEmpty()
    }

    /// Call with `lock` held. The completion runs on another queue: it stops the session, which must not
    /// happen inside one of MtProtoKit's own callbacks.
    private func finishIfEmpty() -> (() -> Void)? {
        guard var handover = self.handover, !handover.finished, self.requests.isEmpty else {
            return nil
        }
        handover.finished = true
        self.handover = handover
        let completions = handover.completions
        return {
            Queue.concurrentDefaultQueue().async {
                for completion in completions {
                    completion()
                }
            }
        }
    }

    enum DeadlineStep {
        case wait(Double)
        case releaseAll
        case done
    }

    /// At the deadline: extended while answers keep arriving (5 s steps, 30 s at most), then every
    /// request still waiting is released.
    func deadlineStep() -> DeadlineStep {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        guard var handover = self.handover, !handover.finished else {
            return .done
        }
        let now = mtProtoKitHandoverClock()
        let limit = handover.startedAt + MtProtoKitHandover.longest
        while now >= handover.deadline && handover.deadline < limit && (handover.lastAnswerAt.map { $0 > handover.deadline - MtProtoKitHandover.extensionStep } ?? false) {
            handover.deadline = min(handover.deadline + MtProtoKitHandover.extensionStep, limit)
        }
        defer {
            self.handover = handover
        }
        if now < handover.deadline {
            return .wait(handover.deadline - now)
        }
        if handover.releasedAll {
            return .done
        }
        handover.releasedAll = true
        return .releaseAll
    }
}

private final class MtProtoKitRequestService: NetworkEngineRequestService {
    private let requestService: MTRequestMessageService
    private let pendingRequests = MtProtoKitPendingRequests()
    
    init(requestService: MTRequestMessageService) {
        self.requestService = requestService
    }
    
    /// See `NetworkEngineSession.movePendingRequests`: MtProtoKit keeps a request that has a message id
    /// until its answer or the deadline and lets every other one go (`handOverRequests:`).
    func movePendingRequests(to service: NetworkEngineRequestService, deadline: Double, completion: @escaping () -> Void) {
        guard self.pendingRequests.beginHandover(target: service, deadline: deadline, completion: completion) else {
            return
        }
        let pendingRequests = self.pendingRequests
        self.requestService.handOverRequests { mtRequest, mayHaveReachedServer, retryAfter in
            guard let mtRequest = mtRequest else {
                return
            }
            MtProtoKitRequestService.released(mtRequest, mayHaveReachedServer: mayHaveReachedServer, retryAfter: retryAfter, pendingRequests: pendingRequests)
        }
        self.scheduleDeadline(after: 0.0)
        pendingRequests.finishIfDone()?()
    }

    private func scheduleDeadline(after delay: Double) {
        let pendingRequests = self.pendingRequests
        let requestService = self.requestService
        Queue.concurrentDefaultQueue().after(delay, { [weak self] in
            switch pendingRequests.deadlineStep() {
            case let .wait(remaining):
                self?.scheduleDeadline(after: remaining + 0.01)
            case .releaseAll:
                requestService.releaseHandedOverRequests()
                Queue.concurrentDefaultQueue().after(2.0, {
                    for (pending, target) in pendingRequests.takeAll() {
                        MtProtoKitRequestService.decide(pending, mayHaveReachedServer: true, retryAfter: 0.0, errorContext: nil, target: target, pendingRequests: pendingRequests)
                    }
                    pendingRequests.finishIfDone()?()
                })
            case .done:
                break
            }
        })
    }

    private static func released(_ mtRequest: MTRequest, mayHaveReachedServer: Bool, retryAfter: Double, pendingRequests: MtProtoKitPendingRequests) {
        if let (pending, target) = pendingRequests.take(key: ObjectIdentifier(mtRequest)) {
            decide(pending, mayHaveReachedServer: mayHaveReachedServer, retryAfter: retryAfter, errorContext: mtRequest.errorContext, target: target, pendingRequests: pendingRequests)
        }
        pendingRequests.finishIfDone()?()
    }

    private static func decide(_ pending: MtProtoKitPendingRequest, mayHaveReachedServer: Bool, retryAfter: Double, errorContext: MTRequestErrorContext?, target: NetworkEngineRequestService, pendingRequests: MtProtoKitPendingRequests) {
        let decision = networkEngineReleaseDecision(mayHaveRun: mayHaveReachedServer, retryAfter: retryAfter, allowsServerError: {
            return pending.request.shouldContinueAfterError(NetworkEngineErrorContext(
                floodWaitSeconds: Int(errorContext?.floodWaitSeconds ?? 0),
                floodWaitErrorText: errorContext?.floodWaitErrorText,
                internalServerErrorCount: Int(errorContext?.internalServerErrorCount ?? 0) + 1
            ))
        })
        switch decision {
        case let .move(delay):
            let disposable = networkEngineMove(pending.request, to: target, after: delay)
            if pendingRequests.setMoved(pending, disposable: disposable) {
                disposable.dispose()
            }
        case .fail:
            if !pending.isCancelled {
                pending.request.completed(.failure(NetworkEngineRequestFailure(error: networkEngineSwitchedError, info: NetworkEngineResponseInfo(nil))))
            }
        }
    }
    
    func add(_ request: NetworkEngineRequest) -> Disposable {
        let mtRequest = MTRequest()
        let internalId: Any! = mtRequest.internalId
        let key = ObjectIdentifier(mtRequest)
        let pendingRequests = self.pendingRequests
        let pending = MtProtoKitPendingRequest(request: request, internalId: internalId)
        if let target = pendingRequests.insert(pending, key: key) {
            return target.add(request)
        }
        
        let parse = request.parse
        mtRequest.setPayload(request.payload, metadata: request.metadata, shortMetadata: request.shortMetadata, responseParser: { response in
            guard let response = response else {
                return nil
            }
            return parse(response)
        })
        
        mtRequest.dependsOnPasswordEntry = false
        mtRequest.needsTimeoutTimer = request.options.needsTimeoutTimer
        mtRequest.expectedResponseSize = request.options.expectedResponseSize
        
        mtRequest.shouldContinueExecutionWithErrorContext = { errorContext in
            guard let errorContext = errorContext else {
                return true
            }
            return request.shouldContinueAfterError(NetworkEngineErrorContext(errorContext))
        }
        
        if let acknowledged = request.acknowledged {
            mtRequest.acknowledgementReceived = {
                acknowledged()
            }
        }
        
        if let progress = request.progress {
            mtRequest.progressUpdated = { value, packetLength in
                progress(value, Int(packetLength))
            }
        }
        
        mtRequest.completed = { (boxedResponse, info, error) -> () in
            let (deliver, finished) = pendingRequests.complete(pending, key: key)
            if deliver {
                let responseInfo = NetworkEngineResponseInfo(info)
                if let error = error {
                    request.completed(.failure(NetworkEngineRequestFailure(error: error, info: responseInfo)))
                } else if let boxedResponse = boxedResponse {
                    request.completed(.success(NetworkEngineResponse(result: boxedResponse, info: responseInfo)))
                } else {
                    request.completed(.success(NetworkEngineResponse(result: boxedResponse as Any, info: responseInfo)))
                }
            }
            finished?()
        }
        
        if let dependsOn = request.dependsOn {
            mtRequest.shouldDependOnRequest = { other in
                if let other = other, let metadata = other.metadata as? WrappedRequestMetadata {
                    return dependsOn(metadata)
                }
                return false
            }
        }
        
        let requestService = self.requestService
        requestService.add(mtRequest)
        
        return ActionDisposable { [weak requestService] in
            let (moved, finished) = pendingRequests.cancel(pending, key: key)
            if let moved = moved {
                moved.dispose()
            } else {
                requestService?.removeRequest(byInternalId: internalId)
            }
            finished?()
        }
    }
}

private final class MtProtoKitUpdateSinkService: NSObject, MTMessageService {
    private let sink: NetworkEngineUpdateSink
    private var mtProto: MTProto?
    
    init(sink: NetworkEngineUpdateSink) {
        self.sink = sink
        
        super.init()
    }
    
    func mtProtoWillAdd(_ mtProto: MTProto!) {
        self.mtProto = mtProto
    }
    
    func mtProtoDidChangeSession(_ mtProto: MTProto!) {
        self.sink.networkSessionDidReset()
    }
    
    func mtProtoServerDidChangeSession(_ mtProto: MTProto!, firstValidMessageId: Int64, otherValidMessageIds: [Any]!) {
        self.sink.networkSessionDidReset()
    }
    
    func mtProto(_ mtProto: MTProto!, receivedMessage message: MTIncomingMessage!, authInfoSelector: MTDatacenterAuthInfoSelector, networkType: Int32) {
        if let body = message.body {
            self.sink.networkSessionDidReceive(message: body)
        }
    }
}

private final class MtProtoKitSession: NSObject, NetworkEngineSession, MTRequestMessageServiceDelegate {
    let datacenterId: Int
    let requestService: NetworkEngineRequestService
    private let mtProtoKitRequestService: MtProtoKitRequestService
    
    private let context: MTContext
    private let role: NetworkEngineSessionRole
    private let mtProto: MTProto
    private let mtRequestService: MTRequestMessageService
    private let connectionStatusDelegate: MTProtoConnectionStatusDelegate?
    private weak var delegate: NetworkEngineSessionDelegate?
    private let logPrefix = Atomic<String?>(value: nil)
    
    init(context: MTContext, datacenterId: Int, role: NetworkEngineSessionRole, usageCalculationInfo: MTNetworkUsageCalculationInfo?, delegate: NetworkEngineSessionDelegate?) {
        self.context = context
        self.datacenterId = datacenterId
        self.role = role
        self.delegate = delegate
        
        switch role {
        case .main:
            let mtProto = MTProto(context: context, datacenterId: datacenterId, usageCalculationInfo: usageCalculationInfo, requiredAuthToken: nil, authTokenMasterDatacenterId: 0)!
            mtProto.useTempAuthKeys = context.useTempAuthKeys
            mtProto.checkForProxyConnectionIssues = true
            self.mtProto = mtProto
            
            self.mtRequestService = MTRequestMessageService(context: context)!
            self.connectionStatusDelegate = MTProtoConnectionStatusDelegate()
        case let .worker(masterDatacenterId, isMedia, isCdn):
            var requiredAuthToken: Any?
            var authTokenMasterDatacenterId: Int = 0
            if !isCdn && datacenterId != masterDatacenterId {
                authTokenMasterDatacenterId = masterDatacenterId
                requiredAuthToken = Int(datacenterId) as NSNumber
            }
            
            self.mtProto = MTProto(context: context, datacenterId: datacenterId, usageCalculationInfo: usageCalculationInfo, requiredAuthToken: requiredAuthToken, authTokenMasterDatacenterId: authTokenMasterDatacenterId)
            let logPrefix = self.logPrefix
            self.mtProto.getLogPrefix = {
                return logPrefix.with { $0 }
            }
            self.mtProto.cdn = isCdn
            self.mtProto.useTempAuthKeys = context.useTempAuthKeys && !isCdn
            self.mtProto.media = isMedia
            self.mtRequestService = MTRequestMessageService(context: context)
            self.mtRequestService.forceBackgroundRequests = true
            self.connectionStatusDelegate = nil
        }
        
        self.mtProtoKitRequestService = MtProtoKitRequestService(requestService: self.mtRequestService)
        self.requestService = self.mtProtoKitRequestService
        
        super.init()
        
        switch role {
        case .main:
            if let connectionStatusDelegate = self.connectionStatusDelegate {
                connectionStatusDelegate.action = { [weak delegate] info in
                    delegate?.networkSessionConnectionStateChanged(NetworkEngineConnectionState(info))
                }
                self.mtProto.delegate = connectionStatusDelegate
            }
            self.mtProto.add(self.mtRequestService)
            
            self.mtRequestService.didReceiveSoftAuthResetError = { [weak delegate] in
                delegate?.networkSessionSoftAuthReset()
            }
            self.mtRequestService.delegate = self
        case .worker:
            self.mtRequestService.delegate = self
            self.mtProto.add(self.mtRequestService)
        }
    }
    
    func requestMessageServiceAuthorizationRequired(_ requestMessageService: MTRequestMessageService!) {
        switch self.role {
        case .main:
            self.delegate?.networkSessionAuthorizationRequired()
        case .worker:
            self.context.updateAuthTokenForDatacenter(withId: self.datacenterId, authToken: nil)
            self.context.authTokenForDatacenter(withIdRequired: self.datacenterId, authToken:self.mtProto.requiredAuthToken, masterDatacenterId: self.mtProto.authTokenMasterDatacenterId)
        }
    }
    
    func setPaused(_ paused: Bool) {
        if paused {
            self.mtProto.pause()
        } else {
            self.mtProto.resume()
        }
    }

    func setOnline(_ online: Bool) {
        // MtProtoKit has no keepalive whose timing depends on presence.
    }
    
    func addUpdateSink(_ sink: NetworkEngineUpdateSink) {
        self.mtProto.add(MtProtoKitUpdateSinkService(sink: sink))
    }
    
    func stop() {
        self.mtProto.remove(self.mtRequestService)
        self.mtProto.stop()
        self.mtProto.finalizeSession()
    }
    
    func movePendingRequests(to service: NetworkEngineRequestService, deadline: Double, completion: @escaping () -> Void) {
        self.mtProtoKitRequestService.movePendingRequests(to: service, deadline: deadline, completion: completion)
    }
}
