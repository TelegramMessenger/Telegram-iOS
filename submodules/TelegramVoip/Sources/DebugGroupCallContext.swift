import Foundation
import SwiftSignalKit
import TgVoipWebrtc
import Network

private final class ContextQueueImpl: NSObject, OngoingCallThreadLocalContextQueueWebrtc {
    private let queue: Queue
    
    init(queue: Queue) {
        self.queue = queue
        
        super.init()
    }
    
    func dispatch(_ f: @escaping () -> Void) {
        self.queue.async {
            f()
        }
    }
    
    func dispatch(after seconds: Double, block f: @escaping () -> Void) {
        self.queue.after(seconds, f)
    }
    
    func isCurrent() -> Bool {
        return self.queue.isCurrent()
    }
}

@available(iOS 12.0, *)
public final class DebugOngoingGroupCallContext {
    @available(iOS 12.0, *)
    private final class Impl {
        let queue: Queue
        let context: GroupCallCustomThreadLocalContext
        
        let connection: NWConnection
        let address: NWEndpoint.Host
        let port: NWEndpoint.Port
        
        var pingTimer: SwiftSignalKit.Timer?
        
        init(queue: Queue) {
            self.queue = queue
            
            var sendPacketImpl: ((Data) -> Void)?
            
            self.context = GroupCallCustomThreadLocalContext(
                queue: ContextQueueImpl(queue: queue),
                sendPacket: { data in
                    sendPacketImpl?(data)
                }
            )
            
            let codedAddress = IPv4Address("192.168.93.160")!
            let codedPort = NWEndpoint.Port(rawValue: 9999)!
            self.address = .ipv4(codedAddress)
            self.port = codedPort
            self.connection = NWConnection(host: self.address, port: self.port, using: .udp)
            
            let queue = self.queue
            
            sendPacketImpl = { [weak self] data in
                queue.async {
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.sendPacket(data: data)
                }
            }
            
            connection.stateUpdateHandler = { [weak self] newState in
                switch newState {
                case .ready:
                    print("State: Ready")
                    queue.async {
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.beginNetworking()
                    }
                case .setup:
                    print("State: Setup")
                case .cancelled:
                    print("State: Cancelled")
                case .preparing:
                    print("State: Preparing")
                default:
                    print("ERROR! State not defined!\n")
                }
            }
            self.connection.start(queue: .global())
        }
        
        deinit {
            self.pingTimer?.invalidate()
        }
        
        private func beginNetworking() {
            self.receiveMessage()
            
            let pingTimer = SwiftSignalKit.Timer(timeout: 1.0, repeat: true, completion: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.sendPacket(data: Data(count: 1))
            }, queue: self.queue)
            self.pingTimer = pingTimer
            pingTimer.start()
        }
        
        private func receiveMessage() {
            let queue = self.queue
            self.connection.receiveMessage { [weak self] data, context, _, error in
                queue.async {
                    guard let strongSelf = self else {
                        return
                    }
                    if let error = error {
                        print("Receive error: \(error)")
                    } else if let data = data {
                        strongSelf.context.receivePacket(data)
                    }
                    
                    strongSelf.receiveMessage()
                }
            }
        }
        
        private func sendPacket(data: Data) {
            self.connection.send(content: data, completion: NWConnection.SendCompletion.contentProcessed { error in
                if let error = error {
                    print("Send error: \(error)")
                }
            })
        }
        
        func stop() {
            self.context.stop()
        }
    }
    
    private let queue = Queue()
    private let impl: QueueLocalObject<Impl>
    
    public init() {
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(queue: queue)
        })
    }
    
    public func stop() {
        self.impl.with { impl in
            impl.stop()
        }
    }
}

