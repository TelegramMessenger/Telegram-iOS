import Foundation

public struct PeerId: Hashable, Printable, Comparable {
    public typealias Namespace = Int32
    public typealias Id = Int32
    
    public let namespace: Namespace
    public let id: Id
    
    public init(namespace: Namespace, id: Id) {
        self.namespace = namespace
        self.id = id
    }
    
    public init(_ n: Int64) {
        self.namespace = Int32((n >> 32) & 0xffffffff)
        self.id = Int32(n & 0xffffffff)
    }
    
    public func toInt64() -> Int64 {
        return (Int64(self.namespace) << 32) | Int64(self.id)
    }
    
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
    
    public init(_ buffer: ReadBuffer) {
        self.namespace = 0
        self.id = 0
        
        memcpy(&self.namespace, buffer.memory, 4)
        memcpy(&self.id, buffer.memory + 4, 4)
    }
    
    public func encodeToBuffer(buffer: WriteBuffer) {
        var namespace = self.namespace
        var id = self.id
        buffer.write(&namespace, offset: 0, length: 4);
        buffer.write(&id, offset: 0, length: 4);
    }
}

public func ==(lhs: PeerId, rhs: PeerId) -> Bool {
    return lhs.id == rhs.id && lhs.namespace == rhs.namespace
}

public func <(lhs: PeerId, rhs: PeerId) -> Bool {
    if lhs.namespace != rhs.namespace {
        return lhs.namespace < rhs.namespace
    }
    
    if lhs.id != rhs.id {
        return lhs.id < rhs.id
    }
    
    return false
}

public protocol Peer: Coding {
    var id: PeerId { get }
}
