import Foundation
import Network

import MtProtoKit
import SwiftSignalKit

@available(iOS 12.0, *)
final class NetworkFrameworkTcpConnectionInterface: NSObject, MTTcpConnectionInterface {
    private final class Impl {
        private let queue: Queue
        
        private weak var delegate: MTTcpConnectionInterfaceDelegate?
        private let delegateQueue: DispatchQueue
        
        private var connection: NWConnection?
        private var reportedDisconnection: Bool = false
        
        private var currentInterfaceIsWifi: Bool = true
        
        private var connectTimeoutTimer: SwiftSignalKit.Timer?
        
        private var usageCalculationInfo: MTNetworkUsageCalculationInfo?
        private var networkUsageManager: MTNetworkUsageManager?
        
        init(
            queue: Queue,
            delegate: MTTcpConnectionInterfaceDelegate,
            delegateQueue: DispatchQueue
        ) {
            self.queue = queue
            
            self.delegate = delegate
            self.delegateQueue = delegateQueue
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
            
            connection.betterPathUpdateHandler = { [weak self] hasBetterPath in
                queue.async {
                    guard let self = self else {
                        return
                    }
                    if hasBetterPath {
                        self.cancelWithError(error: nil)
                    }
                }
            }
            
            self.connectTimeoutTimer = SwiftSignalKit.Timer(timeout: timeout, repeat: false, completion: { [weak self] in
                guard let self = self else {
                    return
                }
                self.connectTimeoutTimer = nil
                self.cancelWithError(error: nil)
            }, queue: self.queue)
            self.connectTimeoutTimer?.start()
            
            connection.start(queue: self.queue.queue)
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
                assertionFailure("Connection not ready")
                return
            }
            
            connection.send(content: data, completion: .contentProcessed({ _ in
            }))
            
            self.networkUsageManager?.addOutgoingBytes(UInt(data.count), interface: self.currentInterfaceIsWifi ? MTNetworkUsageManagerInterfaceOther : MTNetworkUsageManagerInterfaceWWAN)
        }
        
        func read(length: Int, timeout: Double, tag: Int) {
            guard let connection = self.connection else {
                print("Connection not ready")
                return
            }
            
            connection.receive(minimumIncompleteLength: length, maximumLength: length, completion: { [weak self] data, context, isComplete, error in
                guard let self = self else {
                    return
                }
                if let data = data {
                    self.networkUsageManager?.addIncomingBytes(UInt(data.count), interface: self.currentInterfaceIsWifi ? MTNetworkUsageManagerInterfaceOther : MTNetworkUsageManagerInterfaceWWAN)
                    
                    if isComplete || data.count == length {
                        if data.count == length {
                            weak var delegate = self.delegate
                            self.delegateQueue.async {
                                if let delegate = delegate {
                                    delegate.connectionInterfaceDidRead(data, withTag: tag)
                                }
                            }
                        } else {
                            self.cancelWithError(error: error)
                        }
                    } else {
                        weak var delegate = self.delegate
                        let dataCount = data.count
                        self.delegateQueue.async {
                            if let delegate = delegate {
                                delegate.connectionInterfaceDidReadPartialData(ofLength: UInt(dataCount), tag: tag)
                            }
                        }
                    }
                } else {
                    self.cancelWithError(error: error)
                }
            })
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
