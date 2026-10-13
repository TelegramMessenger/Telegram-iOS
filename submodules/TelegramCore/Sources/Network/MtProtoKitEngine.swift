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
    let sequence: Int
    var isTaken = false
    var isCancelled = false
    var moved: Disposable?

    init(request: NetworkEngineRequest, internalId: Any!, sequence: Int) {
        self.request = request
        self.internalId = internalId
        self.sequence = sequence
    }
}

private final class MtProtoKitPendingRequests {
    private let lock = NSLock()
    private var requests: [ObjectIdentifier: MtProtoKitPendingRequest] = [:]
    private var nextSequence = 0

    func insert(request: NetworkEngineRequest, internalId: Any!) -> MtProtoKitPendingRequest {
        self.lock.lock()
        let pending = MtProtoKitPendingRequest(request: request, internalId: internalId, sequence: self.nextSequence)
        self.nextSequence += 1
        self.requests[ObjectIdentifier(pending)] = pending
        self.lock.unlock()
        return pending
    }

    func complete(_ pending: MtProtoKitPendingRequest) -> Bool {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        if pending.isTaken {
            return false
        }
        self.requests.removeValue(forKey: ObjectIdentifier(pending))
        return true
    }

    func cancel(_ pending: MtProtoKitPendingRequest) -> Disposable? {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        pending.isCancelled = true
        self.requests.removeValue(forKey: ObjectIdentifier(pending))
        return pending.moved
    }

    func takeAll() -> [MtProtoKitPendingRequest] {
        self.lock.lock()
        let taken = self.requests.values.filter { !$0.isCancelled }.sorted(by: { $0.sequence < $1.sequence })
        for pending in taken {
            pending.isTaken = true
        }
        self.requests.removeAll()
        self.lock.unlock()
        return taken
    }

    func setMoved(_ pending: MtProtoKitPendingRequest, disposable: Disposable) -> Bool {
        self.lock.lock()
        pending.moved = disposable
        let isCancelled = pending.isCancelled
        self.lock.unlock()
        return isCancelled
    }
}

private final class MtProtoKitRequestService: NetworkEngineRequestService {
    private let requestService: MTRequestMessageService
    private let pendingRequests = MtProtoKitPendingRequests()
    
    init(requestService: MTRequestMessageService) {
        self.requestService = requestService
    }
    
    func movePendingRequests(to service: NetworkEngineRequestService) {
        for pending in self.pendingRequests.takeAll() {
            self.requestService.removeRequest(byInternalId: pending.internalId)
            let disposable = service.add(pending.request)
            if self.pendingRequests.setMoved(pending, disposable: disposable) {
                disposable.dispose()
            }
        }
    }
    
    func add(_ request: NetworkEngineRequest) -> Disposable {
        let mtRequest = MTRequest()
        let internalId: Any! = mtRequest.internalId
        let pendingRequests = self.pendingRequests
        let pending = pendingRequests.insert(request: request, internalId: internalId)
        
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
            if !pendingRequests.complete(pending) {
                return
            }
            let responseInfo = NetworkEngineResponseInfo(info)
            if let error = error {
                request.completed(.failure(NetworkEngineRequestFailure(error: error, info: responseInfo)))
            } else if let boxedResponse = boxedResponse {
                request.completed(.success(NetworkEngineResponse(result: boxedResponse, info: responseInfo)))
            } else {
                request.completed(.success(NetworkEngineResponse(result: boxedResponse as Any, info: responseInfo)))
            }
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
            if let moved = pendingRequests.cancel(pending) {
                moved.dispose()
            } else {
                requestService?.removeRequest(byInternalId: internalId)
            }
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
    
    func movePendingRequests(to service: NetworkEngineRequestService, completion: @escaping () -> Void) {
        self.mtProtoKitRequestService.movePendingRequests(to: service)
        completion()
    }
}
