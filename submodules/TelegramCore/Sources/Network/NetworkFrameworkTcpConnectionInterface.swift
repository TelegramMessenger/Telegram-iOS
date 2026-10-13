import Foundation
import Network

import MtProtoKit
import SwiftSignalKit

@available(iOS 12.0, macOS 14.0, *)
private func describeState(_ state: NWConnection.State) -> String {
    switch state {
    case .setup:
        return "setup"
    case let .waiting(error):
        return "waiting(\(error))"
    case .preparing:
        return "preparing"
    case .ready:
        return "ready"
    case let .failed(error):
        return "failed(\(error))"
    case .cancelled:
        return "cancelled"
    @unknown default:
        return "unknown"
    }
}

@available(iOS 12.0, macOS 14.0, *)
final class NetworkFrameworkTcpConnectionInterface: NSObject, MTTcpConnectionInterface {
    private struct ReadRequest {
        let length: Int
        let tag: Int
    }
    
    private final class ExecutingReadRequest {
        let request: ReadRequest
        var data: Data
        var readyLength: Int = 0
        
        init(request: ReadRequest) {
            self.request = request
            self.data = Data(count: request.length)
        }
    }
    
    private final class Impl {
        private let queue: Queue
        
        private weak var delegate: MTTcpConnectionInterfaceDelegate?
        private let delegateQueue: DispatchQueue
        
        private let requestChunkLength: Int
        
        private var connection: NWConnection?
        private var reportedDisconnection: Bool = false
        
        private var currentInterfaceIsWifi: Bool = true
        
        private var connectTimeoutTimer: SwiftSignalKit.Timer?
        
        private var usageCalculationInfo: MTNetworkUsageCalculationInfo?
        private var networkUsageManager: MTNetworkUsageManager?
        
        private var readRequests: [ReadRequest] = []
        private var currentReadRequest: ExecutingReadRequest?
        
        private var getLogPrefix: (() -> String)?
        
        private var instanceId: String
        // Identifies this connection in the log. Extended with the account prefix and the remote
        // address in `connect`, so that a line here can be lined up with the [MTTcpConnection#...]
        // lines MtProtoKit emits for the same connection.
        private var logId: String
        
        init(
            queue: Queue,
            delegate: MTTcpConnectionInterfaceDelegate,
            delegateQueue: DispatchQueue
        ) {
            self.queue = queue
            
            self.delegate = delegate
            self.delegateQueue = delegateQueue
            
            self.requestChunkLength = 256 * 1024
            
            self.instanceId = ""
            self.logId = ""
            self.instanceId = String(UInt(bitPattern: ObjectIdentifier(self)), radix: 16)
            self.logId = "[NWTcp#\(self.instanceId)]"
        }
        
        deinit {
            // Network.framework keeps a started connection (and its socket) alive until it is
            // cancelled, so an Impl released without going through `cancelWithError` would leak it.
            if let connection = self.connection {
                self.connection = nil
                connection.cancel()
            }
        }
        
        func setUsageCalculationInfo(_ usageCalculationInfo: MTNetworkUsageCalculationInfo?) {
            if self.usageCalculationInfo !== usageCalculationInfo {
                self.usageCalculationInfo = usageCalculationInfo
                if let usageCalculationInfo = usageCalculationInfo {
                    self.networkUsageManager = MTNetworkUsageManager(info: usageCalculationInfo)
                } else {
                    self.networkUsageManager = nil
                }
            }
        }
        
        func setGetLogPrefix(_ getLogPrefix: (() -> String)?) {
            self.getLogPrefix = getLogPrefix
        }
        
        func connect(host: String, port: UInt16, timeout: Double) {
            if self.connection != nil {
                Logger.shared.log("NWTcp", "\(self.logId) connect to \(host):\(port) ignored: a connection already exists")
                assertionFailure("A connection already exists")
                return
            }
            
            if let logPrefix = self.getLogPrefix?(), !logPrefix.isEmpty {
                self.logId = "[NWTcp#\(self.instanceId) \(logPrefix) \(host):\(port)]"
            } else {
                self.logId = "[NWTcp#\(self.instanceId) \(host):\(port)]"
            }
            
            let host = NWEndpoint.Host(host)
            let port = NWEndpoint.Port(rawValue: port)!
            
            let tcpOptions = NWProtocolTCP.Options()
            tcpOptions.noDelay = true
            tcpOptions.enableKeepalive = true
            tcpOptions.keepaliveIdle = 5
            tcpOptions.keepaliveCount = 2
            tcpOptions.keepaliveInterval = 5
            tcpOptions.enableFastOpen = true
            
            let parameters = NWParameters(tls: nil, tcp: tcpOptions)
            // nw_parameters_set_prefer_no_proxy defaults to false, so Network.framework routes
            // through whatever proxy/PAC the current network advertises. MTProto does its own
            // proxying, and a system proxy would otherwise silently hold the connection in
            // preparing/waiting -- a failure mode the GCDAsyncSocket backend cannot have.
            parameters.preferNoProxies = true
            
            let connection = NWConnection(host: host, port: port, using: parameters)
            self.connection = connection
            
            let queue = self.queue
            connection.stateUpdateHandler = { [weak self] state in
                queue.async {
                    self?.stateUpdated(state: state)
                }
            }
            
            connection.pathUpdateHandler = { [weak self] path in
                queue.async {
                    guard let self = self else {
                        return
                    }
                    Logger.shared.log("NWTcp", "\(self.logId) path update: status: \(path.status), cellular: \(path.usesInterfaceType(.cellular)), wifi: \(path.usesInterfaceType(.wifi))")
                    if path.usesInterfaceType(.cellular) {
                        self.currentInterfaceIsWifi = false
                    } else {
                        self.currentInterfaceIsWifi = true
                    }
                }
            }
            
            connection.viabilityUpdateHandler = { [weak self] isViable in
                queue.async {
                    guard let self = self else {
                        return
                    }
                    Logger.shared.log("NWTcp", "\(self.logId) viability update: \(isViable)")
                    if !isViable {
                        self.cancelWithError(error: nil, reason: "connection is no longer viable")
                    }
                }
            }
            
            /*connection.betterPathUpdateHandler = { [weak self] hasBetterPath in
                queue.async {
                    guard let self = self else {
                        return
                    }
                    if hasBetterPath {
                        self.cancelWithError(error: nil)
                    }
                }
            }*/
            
            self.connectTimeoutTimer = SwiftSignalKit.Timer(timeout: timeout, repeat: false, completion: { [weak self] in
                guard let self = self else {
                    return
                }
                self.connectTimeoutTimer = nil
                self.cancelWithError(error: nil, reason: "connect timeout (\(timeout)s)")
            }, queue: self.queue)
            self.connectTimeoutTimer?.start()
            
            Logger.shared.log("NWTcp", "\(self.logId) starting connection (timeout: \(timeout)s)")
            
            connection.start(queue: self.queue.queue)
            
            self.processReadRequests()
        }
        
        private func stateUpdated(state: NWConnection.State) {
            guard self.connection != nil else {
                // This connection has already been torn down (timeout, viability, explicit
                // disconnect). A state update queued before that must not be reported as a fresh
                // connect, and must not re-report a disconnect.
                Logger.shared.log("NWTcp", "\(self.logId) state after teardown (ignored): \(describeState(state))")
                return
            }
            
            Logger.shared.log("NWTcp", "\(self.logId) state: \(describeState(state))")
            
            switch state {
            case .ready:
                if let path = self.connection?.currentPath {
                    if path.usesInterfaceType(.cellular) {
                        self.currentInterfaceIsWifi = false
                    } else {
                        self.currentInterfaceIsWifi = true
                    }
                }
                
                if let connectTimeoutTimer = self.connectTimeoutTimer {
                    self.connectTimeoutTimer = nil
                    connectTimeoutTimer.invalidate()
                }
                
                let delegate = self.delegate
                self.delegateQueue.async { [weak delegate] in
                    if let delegate = delegate {
                        delegate.connectionInterfaceDidConnect()
                    }
                }
            case let .failed(error):
                self.cancelWithError(error: error, reason: "connection failed")
            default:
                break
            }
        }
        
        func write(data: Data) {
            guard let connection = self.connection else {
                Logger.shared.log("NWTcp", "\(self.logId) write called while connection == nil")
                return
            }
            
            connection.send(content: data, completion: .contentProcessed({ [weak self] error in
                // Delivered on the connection's queue, which is this Impl's queue.
                guard let self = self, let error = error else {
                    return
                }
                self.cancelWithError(error: error, reason: "send failed")
            }))
            
            self.networkUsageManager?.addOutgoingBytes(UInt(data.count), interface: self.currentInterfaceIsWifi ? MTNetworkUsageManagerInterfaceOther : MTNetworkUsageManagerInterfaceWWAN)
        }
        
        func read(length: Int, timeout: Double, tag: Int) {
            self.readRequests.append(NetworkFrameworkTcpConnectionInterface.ReadRequest(length: length, tag: tag))
            self.processReadRequests()
        }
        
        private func processReadRequests() {
            if self.currentReadRequest != nil {
                return
            }
            if self.readRequests.isEmpty {
                return
            }
            
            let readRequest = self.readRequests.removeFirst()
            let currentReadRequest = ExecutingReadRequest(request: readRequest)
            self.currentReadRequest = currentReadRequest
            
            self.processCurrentRead()
        }
        
        // Hands the current request to the delegate once it has been fully satisfied. Split out of
        // processCurrentRead so that a terminal receive (a read close or an error) can still deliver
        // a packet that arrived in the same callback: reporting the disconnection first sets
        // MTTcpConnection's _closed flag, and it then drops any connectionInterfaceDidReadData.
        private func deliverCurrentReadIfComplete() -> Bool {
            guard let currentReadRequest = self.currentReadRequest else {
                return false
            }
            if currentReadRequest.readyLength != currentReadRequest.request.length {
                return false
            }
            
            self.currentReadRequest = nil
            
            let delegate = self.delegate
            let currentInterfaceIsWifi = self.currentInterfaceIsWifi
            self.delegateQueue.async { [weak delegate] in
                if let delegate = delegate {
                    delegate.connectionInterfaceDidRead(currentReadRequest.data, withTag: currentReadRequest.request.tag, networkType: currentInterfaceIsWifi ? 0 : 1)
                }
            }
            
            return true
        }
        
        private func processCurrentRead() {
            guard let currentReadRequest = self.currentReadRequest else {
                return
            }
            if self.deliverCurrentReadIfComplete() {
                self.processReadRequests()
                return
            }
            guard let connection = self.connection else {
                Logger.shared.log("NWTcp", "\(self.logId) read requested while connection == nil")
                return
            }
            
            let requestChunkLength = min(self.requestChunkLength, currentReadRequest.request.length - currentReadRequest.readyLength)
            // `minimumIncompleteLength: 1` is load-bearing, not a micro-optimization:
            // MTTcpConnection refreshes its response timeout from
            // connectionInterfaceDidReadPartialData. Asking the framework to withhold
            // everything until the whole chunk has arrived means no partial callbacks at all
            // for a body under requestChunkLength, so that watchdog expires on a slow link and
            // tears down a healthy connection. GCDAsyncSocket delivers per segment; match it.
            connection.receive(minimumIncompleteLength: 1, maximumLength: requestChunkLength, completion: { [weak self] data, context, isComplete, error in
                guard let self = self else {
                    return
                }
                guard let currentReadRequest = self.currentReadRequest else {
                    Logger.shared.log("NWTcp", "\(self.logId) receive completed with no pending read request (ignored)")
                    return
                }
                
                // A stream protocol has a single context for the whole connection and it is marked
                // final, so a completed final context is a read close -- for TCP, a received FIN.
                // Nothing more will ever arrive on this connection.
                let isReadClosed = isComplete && (context?.isFinal ?? true)
                
                if error != nil || isReadClosed {
                    Logger.shared.log("NWTcp", "\(self.logId) receive completed: length: \(data?.count ?? 0), readClosed: \(isReadClosed), isComplete: \(isComplete), error: \(error.map({ "\($0)" }) ?? "none")")
                }
                
                // Content can be delivered *together with* a terminal condition -- the framework
                // contract is explicit that content may be non-nil alongside an error and that the
                // caller should process it rather than discard it. So consume the data first and
                // only then act on the error / read close.
                if let data = data, !data.isEmpty {
                    self.networkUsageManager?.addIncomingBytes(UInt(data.count), interface: self.currentInterfaceIsWifi ? MTNetworkUsageManagerInterfaceOther : MTNetworkUsageManagerInterfaceWWAN)
                    
                    if data.count > currentReadRequest.request.length - currentReadRequest.readyLength {
                        // Unreachable while maximumLength is the remaining length, but guard rather
                        // than overrun the destination buffer.
                        self.cancelWithError(error: error, reason: "receive overflowed the pending read (\(data.count) bytes)")
                        return
                    }
                    
                    currentReadRequest.data.withUnsafeMutableBytes { currentBuffer in
                        guard let currentBytes = currentBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                            return
                        }
                        data.copyBytes(to: currentBytes.advanced(by: currentReadRequest.readyLength), count: data.count)
                    }
                    currentReadRequest.readyLength += data.count
                    
                    let tag = currentReadRequest.request.tag
                    let readCount = data.count
                    let delegate = self.delegate
                    self.delegateQueue.async { [weak delegate] in
                        if let delegate = delegate {
                            delegate.connectionInterfaceDidReadPartialData(ofLength: UInt(readCount), tag: tag)
                        }
                    }
                }
                
                if error != nil || isReadClosed {
                    let _ = self.deliverCurrentReadIfComplete()
                    if let error = error {
                        self.cancelWithError(error: error, reason: "receive failed")
                    } else {
                        self.cancelWithError(error: nil, reason: "remote closed the connection (read close)")
                    }
                    return
                }
                
                self.processCurrentRead()
            })
        }
        
        private func cancelWithError(error: Error?, reason: String) {
            if let connectTimeoutTimer = self.connectTimeoutTimer {
                self.connectTimeoutTimer = nil
                connectTimeoutTimer.invalidate()
            }
            
            let errorSuffix = error.map({ " error: \($0)" }) ?? ""
            if !self.reportedDisconnection {
                self.reportedDisconnection = true
                Logger.shared.log("NWTcp", "\(self.logId) reporting disconnection: \(reason)\(errorSuffix)")
                let delegate = self.delegate
                self.delegateQueue.async { [weak delegate] in
                    if let delegate = delegate {
                        delegate.connectionInterfaceDidDisconnectWithError(error)
                    }
                }
            } else {
                Logger.shared.log("NWTcp", "\(self.logId) already disconnected, ignoring: \(reason)\(errorSuffix)")
            }
            if let connection = self.connection {
                self.connection = nil
                connection.cancel()
            }
        }
        
        func disconnect() {
            self.cancelWithError(error: nil, reason: "disconnect requested")
        }
        
        func resetDelegate() {
            self.delegate = nil
        }
    }
    
    private static let sharedQueue = Queue(name: "NetworkFrameworkTcpConnectionInteface")
    
    private let queue: Queue
    private let impl: QueueLocalObject<Impl>
    
    init(delegate: MTTcpConnectionInterfaceDelegate, delegateQueue: DispatchQueue) {
        let queue = NetworkFrameworkTcpConnectionInterface.sharedQueue
        self.queue = queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(queue: queue, delegate: delegate, delegateQueue: delegateQueue)
        })
    }
    
    func setGetLogPrefix(_ getLogPrefix: (() -> String)?) {
        self.impl.with { impl in
            impl.setGetLogPrefix(getLogPrefix)
        }
    }
    
    func setUsageCalculationInfo(_ usageCalculationInfo: MTNetworkUsageCalculationInfo?) {
        self.impl.with { impl in
            impl.setUsageCalculationInfo(usageCalculationInfo)
        }
    }
    
    func connect(toHost inHost: String, onPort port: UInt16, viaInterface inInterface: String?, withTimeout timeout: TimeInterval, error errPtr: NSErrorPointer) -> Bool {
        self.impl.with { impl in
            impl.connect(host: inHost, port: port, timeout: timeout)
        }
        return true
    }
    
    func write(_ data: Data) {
        self.impl.with { impl in
            impl.write(data: data)
        }
    }
    
    func readData(toLength length: UInt, withTimeout timeout: TimeInterval, tag: Int) {
        self.impl.with { impl in
            impl.read(length: Int(length), timeout: timeout, tag: tag)
        }
    }
    
    func disconnect() {
        self.impl.with { impl in
            impl.disconnect()
        }
    }
    
    func resetDelegate() {
        self.impl.with { impl in
            impl.resetDelegate()
        }
    }
}
