import Foundation
import Network

import MtProtoKit
import SwiftSignalKit

@available(iOS 12.0, macOS 10.14, *)
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
        
        init(
            queue: Queue,
            delegate: MTTcpConnectionInterfaceDelegate,
            delegateQueue: DispatchQueue
        ) {
            self.queue = queue
            
            self.delegate = delegate
            self.delegateQueue = delegateQueue
            
            self.requestChunkLength = 256 * 1024
        }
        
        deinit {
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
        
        func connect(host: String, port: UInt16, timeout: Double) {
            if self.connection != nil {
                assertionFailure("A connection already exists")
                return
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
                    if !isViable {
                        self.cancelWithError(error: nil)
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
                self.cancelWithError(error: nil)
            }, queue: self.queue)
            self.connectTimeoutTimer?.start()
            
            connection.start(queue: self.queue.queue)
            
            self.processReadRequests()
        }
        
        private func stateUpdated(state: NWConnection.State) {
            switch state {
            case .ready:
                if let path = self.connection?.currentPath {
                    if path.usesInterfaceType(.cellular) {
                        self.currentInterfaceIsWifi = false
                    } else {
                        self.currentInterfaceIsWifi = true
                    }
                }
                
                if let connectTimeoutTimer = connectTimeoutTimer {
                    self.connectTimeoutTimer = nil
                    connectTimeoutTimer.invalidate()
                }
                
                weak var delegate = self.delegate
                self.delegateQueue.async {
                    if let delegate = delegate {
                        delegate.connectionInterfaceDidConnect()
                    }
                }
            case let .failed(error):
                self.cancelWithError(error: error)
            default:
                break
            }
        }
        
        func write(data: Data) {
            guard let connection = self.connection else {
                Logger.shared.log("NetworkFrameworkTcpConnectionInterface", "write called while connection == nil")
                return
            }
            
            connection.send(content: data, completion: .contentProcessed({ _ in
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
        
        private func processCurrentRead() {
            guard let currentReadRequest = self.currentReadRequest else {
                return
            }
            guard let connection = self.connection else {
                print("Connection not ready")
                return
            }
            
            let requestChunkLength = min(self.requestChunkLength, currentReadRequest.request.length - currentReadRequest.readyLength)
            if requestChunkLength == 0 {
                self.currentReadRequest = nil
                
                weak var delegate = self.delegate
                let currentInterfaceIsWifi = self.currentInterfaceIsWifi
                self.delegateQueue.async {
                    if let delegate = delegate {
                        delegate.connectionInterfaceDidRead(currentReadRequest.data, withTag: currentReadRequest.request.tag, networkType: currentInterfaceIsWifi ? 0 : 1)
                    }
                }
                
                self.processReadRequests()
            } else {
                connection.receive(minimumIncompleteLength: requestChunkLength, maximumLength: requestChunkLength, completion: { [weak self] data, context, isComplete, error in
                    guard let self = self, let currentReadRequest = self.currentReadRequest else {
                        return
                    }
                    if let data = data {
                        self.networkUsageManager?.addIncomingBytes(UInt(data.count), interface: self.currentInterfaceIsWifi ? MTNetworkUsageManagerInterfaceOther : MTNetworkUsageManagerInterfaceWWAN)
                        
                        if data.count != 0 && data.count <= currentReadRequest.request.length - currentReadRequest.readyLength {
                            currentReadRequest.data.withUnsafeMutableBytes { currentBuffer in
                                guard let currentBytes = currentBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                                    return
                                }
                                data.copyBytes(to: currentBytes.advanced(by: currentReadRequest.readyLength), count: data.count)
                            }
                            currentReadRequest.readyLength += data.count
                            
                            let tag = currentReadRequest.request.tag
                            let readCount = data.count
                            weak var delegate = self.delegate
                            self.delegateQueue.async {
                                if let delegate = delegate {
                                    delegate.connectionInterfaceDidReadPartialData(ofLength: UInt(readCount), tag: tag)
                                }
                            }
                            
                            self.processCurrentRead()
                        } else {
                            self.cancelWithError(error: error)
                        }
                        
                        if isComplete && data.count == 0 {
                            self.cancelWithError(error: nil)
                        }
                    } else {
                        self.cancelWithError(error: error)
                    }
                })
            }
        }
        
        private func cancelWithError(error: Error?) {
            if let connectTimeoutTimer = self.connectTimeoutTimer {
                self.connectTimeoutTimer = nil
                connectTimeoutTimer.invalidate()
            }
            
            if !self.reportedDisconnection {
                self.reportedDisconnection = true
                weak var delegate = self.delegate
                self.delegateQueue.async {
                    if let delegate = delegate {
                        delegate.connectionInterfaceDidDisconnectWithError(error)
                    }
                }
            }
            if let connection = self.connection {
                self.connection = nil
                connection.cancel()
            }
        }
        
        func disconnect() {
            self.cancelWithError(error: nil)
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
