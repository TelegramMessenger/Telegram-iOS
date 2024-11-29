import Foundation
import SwiftSignalKit
import Network

@available(macOS 10.14, *)
public final class ReflectorBenchmark {
    public struct Results {
        public let bandwidthBytesPerSecond: Int
        public let expectedBandwidthBytesPerSecond: Int
        public let averageDelay: Double
        
        public init(bandwidthBytesPerSecond: Int, expectedBandwidthBytesPerSecond: Int, averageDelay: Double) {
            self.bandwidthBytesPerSecond = bandwidthBytesPerSecond
            self.expectedBandwidthBytesPerSecond = expectedBandwidthBytesPerSecond
            self.averageDelay = averageDelay
        }
    }
    @available(macOS 10.14, *)
    private final class Impl {
        let queue: Queue
        let address: String
        let port: Int
        
        let incomingTag: Data
        let outgoingTag: Data
        let outgoingRandomTag: Data
        
        let targetBandwidthBytesPerSecond: Int
        let sendPacketInterval: Double
        let maxPacketCount: Int
        
        var outgoingConnection: NWConnection?
        var incomingConnection: NWConnection?
        
        var completion: ((Results) -> Void)?
        
        var incomingPingSendTimestamp: Double?
        var didReceiveIncomingPing: Bool = false
        var outgoingPingSendTimestamp: Double?
        var didReceiveOutgoingPing: Bool = false
        
        var sentPacketCount: Int = 0
        var receivedPacketCount: Int = 0
        var firstReceiveTimestamp: Double?
        var lastReceiveTimestamp: Double?
        var unconfirmedPacketSendTimestamp: [Data: Double] = [:]
        var packetSizeAndTimeToReceive: [(Int, Double)] = []
        
        var pingTimer: SwiftSignalKit.Timer?
        var sendPacketTimer: SwiftSignalKit.Timer?
        var bandwidthTimer: SwiftSignalKit.Timer?
        
        init(queue: Queue, address: String, port: Int) {
            self.queue = queue
            self.address = address
            self.port = port
            
            self.targetBandwidthBytesPerSecond = 700 * 1024 / 8
            self.sendPacketInterval = 1.0 / 30.0
            self.maxPacketCount = Int(5.0 / self.sendPacketInterval)
            
            var incomingTag = Data(count: 16)
            var outgoingTag = Data(count: 16)
            
            incomingTag.withUnsafeMutableBytes { incomingBuffer -> Void in
                outgoingTag.withUnsafeMutableBytes { outgoingBuffer -> Void in
                    let incoming = incomingBuffer.baseAddress!.assumingMemoryBound(to: UInt8.self)
                    let outgoing = outgoingBuffer.baseAddress!.assumingMemoryBound(to: UInt8.self)
                    
                    arc4random_buf(incoming, incomingBuffer.count)
                    memcpy(outgoing, incoming, incomingBuffer.count)
                    
                    incoming[0] = 0
                    outgoing[0] = 1
                }
            }
            
            var outgoingRandomTag = Data(count: 4)
            outgoingRandomTag.withUnsafeMutableBytes { buffer -> Void in
                arc4random_buf(buffer.baseAddress!, buffer.count)
            }
            
            self.incomingTag = incomingTag
            self.outgoingTag = outgoingTag
            self.outgoingRandomTag = outgoingRandomTag
        }
        
        deinit {
            self.incomingConnection?.cancel()
            self.outgoingConnection?.cancel()
            self.pingTimer?.invalidate()
            self.sendPacketTimer?.invalidate()
            self.bandwidthTimer?.invalidate()
        }
        
        func start(completion: @escaping (Results) -> Void) {
            self.completion = completion
            
            let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(self.address), port: NWEndpoint.Port(integerLiteral: UInt16(self.port)))
            let incomingConnection = NWConnection(to: endpoint, using: .udp)
            self.incomingConnection = incomingConnection
            
            let outgoingConnection = NWConnection(to: endpoint, using: .udp)
            self.outgoingConnection = outgoingConnection
            
            incomingConnection.start(queue: self.queue.queue)
            outgoingConnection.start(queue: self.queue.queue)
            
            self.receiveIncomingPacket()
            self.receiveOutgoingPacket()
            self.sendIncomingPingPackets()
            
            self.pingTimer = SwiftSignalKit.Timer(timeout: 1.0, repeat: true, completion: { [weak self] in
                guard let self else {
                    return
                }
                self.sendIncomingPingPackets()
                self.sendOutgoingPingPackets()
            }, queue: self.queue)
            self.pingTimer?.start()
            
            self.sendPacketTimer = SwiftSignalKit.Timer(timeout: self.sendPacketInterval, repeat: true, completion: { [weak self] in
                guard let self else {
                    return
                }
                self.sendOutgoingPacket()
            }, queue: self.queue)
            self.sendPacketTimer?.start()
            
            self.bandwidthTimer = SwiftSignalKit.Timer(timeout: 1.0, repeat: true, completion: { [weak self] in
                guard let self else {
                    return
                }
                self.calculateStats()
            }, queue: self.queue)
            self.bandwidthTimer?.start()
        }
        
        private func calculateStats() {
            guard let firstReceiveTimestamp = self.firstReceiveTimestamp, let lastReceiveTimestamp = self.lastReceiveTimestamp else {
                return
            }
            if self.sentPacketCount < self.maxPacketCount {
                return
            }
            var totalSize = 0
            var totalDelay: Double = 0.0
            let totalTime: Double = lastReceiveTimestamp - firstReceiveTimestamp
            
            for item in self.packetSizeAndTimeToReceive {
                totalSize += item.0
                totalDelay += item.1
            }
            
            let averageDelay: Double
            if !self.packetSizeAndTimeToReceive.isEmpty {
                averageDelay = totalDelay / Double(self.packetSizeAndTimeToReceive.count)
            } else {
                averageDelay = 0.0
            }
            
            if totalTime != 0.0 {
                let bandwidthBytesPerSecond = Int(Double(totalSize) / totalTime)
                if let completion = self.completion {
                    self.completion = nil
                    completion(Results(
                        bandwidthBytesPerSecond: bandwidthBytesPerSecond,
                        expectedBandwidthBytesPerSecond: self.targetBandwidthBytesPerSecond,
                        averageDelay: averageDelay
                    ))
                }
            }
        }
        
        private func sendIncomingPingPackets() {
            guard let connection = self.incomingConnection else {
                return
            }
            
            var packetData = Data()
            packetData.append(self.incomingTag)
            
            var controlByte1: UInt8 = 0xff
            for _ in 0 ..< 12 {
                packetData.append(&controlByte1, count: 1)
            }
            
            var controlByte2: UInt8 = 0xfe
            packetData.append(&controlByte2, count: 1)
            for _ in 0 ..< 3 {
                packetData.append(&controlByte1, count: 1)
            }
            
            var testValue: UInt64 = 123
            withUnsafeBytes(of: &testValue, { buffer -> Void in
                packetData.append(buffer.assumingMemoryBound(to: UInt8.self).baseAddress!, count: 8)
            })
            
            var zeroByte: UInt8 = 0
            while packetData.count % 4 != 0 {
                packetData.append(&zeroByte, count: 1)
            }
            
            if self.incomingPingSendTimestamp == nil {
                self.incomingPingSendTimestamp = CFAbsoluteTimeGetCurrent()
            }
            connection.send(content: packetData, completion: .contentProcessed({ _ in }))
        }
        
        private func sendOutgoingPingPackets() {
            guard let connection = self.outgoingConnection else {
                return
            }
            
            var packetData = Data()
            packetData.append(self.outgoingTag)
            
            var controlByte1: UInt8 = 0xff
            for _ in 0 ..< 12 {
                packetData.append(&controlByte1, count: 1)
            }
            
            var controlByte2: UInt8 = 0xfe
            packetData.append(&controlByte2, count: 1)
            for _ in 0 ..< 3 {
                packetData.append(&controlByte1, count: 1)
            }
            
            var testValue: UInt64 = 123
            withUnsafeBytes(of: &testValue, { buffer -> Void in
                packetData.append(buffer.assumingMemoryBound(to: UInt8.self).baseAddress!, count: 8)
            })
            
            var zeroByte: UInt8 = 0
            while packetData.count % 4 != 0 {
                packetData.append(&zeroByte, count: 1)
            }
            
            if self.outgoingPingSendTimestamp == nil {
                self.outgoingPingSendTimestamp = CFAbsoluteTimeGetCurrent()
            }
            connection.send(content: packetData, completion: .contentProcessed({ _ in }))
        }
        
        private func sendOutgoingPacket() {
            let timestamp = CFAbsoluteTimeGetCurrent()
            var timedOutPacketIds: [Data] = []
            for (packetId, packetTimestamp) in self.unconfirmedPacketSendTimestamp {
                let packetDelay = timestamp - packetTimestamp
                if packetDelay > 2.0 {
                    timedOutPacketIds.append(packetId)
                    self.receivedPacketCount += 1
                    self.lastReceiveTimestamp = timestamp
                }
            }
            for packetId in timedOutPacketIds {
                self.unconfirmedPacketSendTimestamp.removeValue(forKey: packetId)
            }
            if let outgoingPingSendTimestamp = self.outgoingPingSendTimestamp, !self.didReceiveOutgoingPing {
                if outgoingPingSendTimestamp < timestamp - 2.0 {
                    self.didReceiveOutgoingPing = true
                    self.sentPacketCount = self.maxPacketCount
                }
            }
            if let incomingPingSendTimestamp = self.incomingPingSendTimestamp, !self.didReceiveIncomingPing {
                if incomingPingSendTimestamp < timestamp - 2.0 {
                    self.didReceiveIncomingPing = true
                    self.sentPacketCount = self.maxPacketCount
                }
            }
            
            guard let connection = self.outgoingConnection else {
                return
            }
            if self.sentPacketCount >= self.maxPacketCount {
                return
            }
            if !self.didReceiveIncomingPing && self.didReceiveOutgoingPing {
                return
            }
            
            let bandwidthAdjustedPacketLength: Int32 = Int32(Double(self.targetBandwidthBytesPerSecond) * self.sendPacketInterval) + Int32.random(in: 0 ..< 1 * 1024)
            var remainingPacketLength = bandwidthAdjustedPacketLength
            
            while remainingPacketLength > 0 {
                var packetData = Data()
                
                packetData.append(self.outgoingTag)
                packetData.append(self.outgoingRandomTag)
                
                let packetLength = min(remainingPacketLength, 1 * 1024)
                var dataLength: Int32 = 8 + bandwidthAdjustedPacketLength
                withUnsafeBytes(of: &dataLength, { buffer -> Void in
                    packetData.append(buffer.assumingMemoryBound(to: UInt8.self).baseAddress!, count: buffer.count)
                })
                
                var packetId = Data(count: 8)
                packetId.withUnsafeMutableBytes { buffer -> Void in
                    arc4random_buf(buffer.baseAddress!, buffer.count)
                }
                packetData.append(packetId)
                
                var innerData = Data(count: Int(packetLength))
                innerData.withUnsafeMutableBytes { buffer -> Void in
                    arc4random_buf(buffer.baseAddress!, buffer.count)
                }
                packetData.append(innerData)
                
                var zeroByte: UInt8 = 0
                while packetData.count % 4 != 0 {
                    packetData.append(&zeroByte, count: 1)
                }
                
                self.unconfirmedPacketSendTimestamp[packetId] = timestamp
                remainingPacketLength -= packetLength
                self.sentPacketCount += 1
                
                if self.firstReceiveTimestamp == nil {
                    self.firstReceiveTimestamp = timestamp
                }
                
                connection.send(content: packetData, completion: .contentProcessed({ _ in }))
            }
        }
        
        private func receiveIncomingPacket() {
            guard let connection = self.incomingConnection else {
                return
            }
            connection.receive(minimumIncompleteLength: 1, maximumLength: 32 * 1024, completion: { [weak self] content, _, _, error in
                guard let self else {
                    return
                }
                if let content {
                    if content.count >= 16 + 4 + 4 + 8 {
                        let tag = content.subdata(in: 0 ..< 16)
                        if tag == self.incomingTag {
                            let packetId = content.subdata(in: (16 + 4 + 4) ..< (16 + 4 + 4 + 8))
                            if let sentTimestamp = self.unconfirmedPacketSendTimestamp.removeValue(forKey: packetId) {
                                let timestamp = CFAbsoluteTimeGetCurrent()
                                let packetSendReceiveDuration = timestamp - sentTimestamp
                                self.lastReceiveTimestamp = timestamp
                                self.receivedPacketCount += 1
                                self.packetSizeAndTimeToReceive.append((content.count, packetSendReceiveDuration))
                            } else {
                                var pingHeaderData = Data()
                                var controlByte1: UInt8 = 0xff
                                for _ in 0 ..< 8 {
                                    pingHeaderData.append(&controlByte1, count: 1)
                                }
                                let pingPacketId = content.subdata(in: 16 ..< (16 + 8))
                                if pingPacketId == pingHeaderData {
                                    self.didReceiveIncomingPing = true
                                } else {
                                    //print("Unknown incoming packet id")
                                }
                            }
                        } else {
                            print("Invalid incoming tag")
                        }
                    } else {
                        print("Invalid content length: \(content.count)")
                    }
                } else {
                    print("Incoming data receive error")
                }
                
                self.receiveIncomingPacket()
            })
        }
        
        private func receiveOutgoingPacket() {
            guard let connection = self.outgoingConnection else {
                return
            }
            connection.receive(minimumIncompleteLength: 1, maximumLength: 32 * 1024, completion: { [weak self] content, _, _, error in
                guard let self else {
                    return
                }
                
                if let content {
                    if content.count >= 16 + 8 {
                        let tag = content.subdata(in: 0 ..< 16)
                        if tag == self.outgoingTag {
                        let packetId = content.subdata(in: 16 ..< (16 + 8))
                            var pingHeaderData = Data()
                            var controlByte1: UInt8 = 0xff
                            for _ in 0 ..< 8 {
                                pingHeaderData.append(&controlByte1, count: 1)
                            }
                            if packetId == pingHeaderData {
                                self.didReceiveOutgoingPing = true
                            } else {
                                print("Unknown outgoing packet id")
                            }
                        } else {
                            print("Invalid outgoing tag")
                        }
                    } else {
                        print("Invalid content length: \(content.count)")
                    }
                }
                
                self.receiveOutgoingPacket()
            })
        }
    }
    
    private static let sharedQueue = Queue(name: "ReflectorBenchmark")
    private let impl: QueueLocalObject<Impl>
    
    public init(address: String, port: Int) {
        let queue = ReflectorBenchmark.sharedQueue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(queue: queue, address: address, port: port)
        })
    }
    
    public func start(completion: @escaping (Results) -> Void) {
        self.impl.with { impl in
            impl.start(completion: completion)
        }
    }
}
