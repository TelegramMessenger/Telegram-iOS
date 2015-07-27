import Foundation

public struct MessageId: Hashable, CustomStringConvertible {
    public typealias Namespace = Int32
    public typealias Id = Int32
    
    public let peerId: PeerId
    public let namespace: Namespace
    public let id: Id
    
    public var hashValue: Int {
        get {
            return Int(self.id)
        }
    }
    
    public var description: String {
        get {
            return "\(namespace):\(id)"
        }
    }
    
    public init(peerId: PeerId, namespace: Namespace, id: Id) {
        self.peerId = peerId
        self.namespace = namespace
        self.id = id
    }
    
    public init(_ buffer: ReadBuffer) {
        self.peerId = PeerId(namespace: 0, id: 0)
        self.namespace = 0
        self.id = 0
        
        memcpy(&self.peerId.namespace, buffer.memory + buffer.offset, 4)
        memcpy(&self.peerId.id, buffer.memory + (buffer.offset + 4), 4)
        memcpy(&self.namespace, buffer.memory + (buffer.offset + 8), 4)
        memcpy(&self.id, buffer.memory + (buffer.offset + 12), 4)
        buffer.offset += 16
    }
    
    public func encodeToBuffer(buffer: WriteBuffer) {
        var peerIdNamespace = self.peerId.namespace
        var peerIdId = self.peerId.id
        var namespace = self.namespace
        var id = self.id
        buffer.write(&peerIdNamespace, offset: 0, length: 4);
        buffer.write(&peerIdId, offset: 0, length: 4);
        buffer.write(&namespace, offset: 0, length: 4);
        buffer.write(&id, offset: 0, length: 4);
    }
    
    public static func encodeArrayToBuffer(array: [MessageId], buffer: WriteBuffer) {
        var length: Int32 = Int32(array.count)
        buffer.write(&length, offset: 0, length: 4)
        for id in array {
            id.encodeToBuffer(buffer)
        }
    }
    
    public static func decodeArrayFromBuffer(buffer: ReadBuffer) -> [MessageId] {
        var length: Int32 = 0
        memcpy(&length, buffer.memory, 4)
        buffer.offset += 4
        var i = 0
        var array: [MessageId] = []
        while i < Int(length) {
            array[i] = MessageId(buffer)
            i++
        }
        return array
    }
}

public func ==(lhs: MessageId, rhs: MessageId) -> Bool {
    return lhs.id == rhs.id && lhs.namespace == rhs.namespace
}

public struct MessageIndex: Equatable, Comparable {
    public let id: MessageId
    public let timestamp: Int32
    
    public init(_ message: Message) {
        self.id = message.id
        self.timestamp = message.timestamp
    }
    
    public init(id: MessageId, timestamp: Int32) {
        self.id = id
        self.timestamp = timestamp
    }
}

public func ==(lhs: MessageIndex, rhs: MessageIndex) -> Bool {
    return lhs.id == rhs.id && lhs.timestamp == rhs.timestamp
}

public func <(lhs: MessageIndex, rhs: MessageIndex) -> Bool {
    if lhs.timestamp != rhs.timestamp {
        return lhs.timestamp < rhs.timestamp
    }
    
    if lhs.id.namespace != rhs.id.namespace {
        return lhs.id.namespace < rhs.id.namespace
    }
    
    return lhs.id.id < rhs.id.id
}

public protocol Message: Coding {
    var id: MessageId { get }
    var timestamp: Int32 { get }
    var text: String { get }
    var referencedMediaIds: [MediaId] { get }
}
