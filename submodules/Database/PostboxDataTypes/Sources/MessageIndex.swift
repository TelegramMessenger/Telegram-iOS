import Foundation

public struct MessageIndex: Comparable, Hashable {
    public let id: MessageId
    public let timestamp: Int32
    
    public init(id: MessageId, timestamp: Int32) {
        self.id = id
        self.timestamp = timestamp
    }
    
    public func predecessor() -> MessageIndex {
        if self.id.id != 0 {
            return MessageIndex(id: MessageId(peerId: self.id.peerId, namespace: self.id.namespace, id: self.id.id - 1), timestamp: self.timestamp)
        } else if self.id.namespace != 0 {
            return MessageIndex(id: MessageId(peerId: self.id.peerId, namespace: self.id.namespace - 1, id: Int32.max - 1), timestamp: self.timestamp)
        } else if self.timestamp != 0 {
            return MessageIndex(id: MessageId(peerId: self.id.peerId, namespace: Int32(Int8.max) - 1, id: Int32.max - 1), timestamp: self.timestamp - 1)
        } else {
            return self
        }
    }
    
    public func successor() -> MessageIndex {
        return MessageIndex(id: MessageId(peerId: self.id.peerId, namespace: self.id.namespace, id: self.id.id == Int32.max ? self.id.id : (self.id.id + 1)), timestamp: self.timestamp)
    }
    
    public var hashValue: Int {
        return self.id.hashValue
    }
    
    public static func absoluteUpperBound() -> MessageIndex {
        return MessageIndex(id: MessageId(peerId: PeerId(namespace: Int32(Int8.max), id: Int32.max), namespace: Int32(Int8.max), id: Int32.max), timestamp: Int32.max)
    }
    
    public static func absoluteLowerBound() -> MessageIndex {
        return MessageIndex(id: MessageId(peerId: PeerId(namespace: 0, id: 0), namespace: 0, id: 0), timestamp: 0)
    }
    
    public static func lowerBound(peerId: PeerId) -> MessageIndex {
        return MessageIndex(id: MessageId(peerId: peerId, namespace: 0, id: 0), timestamp: 0)
    }
    
    public static func lowerBound(peerId: PeerId, namespace: MessageId.Namespace) -> MessageIndex {
        return MessageIndex(id: MessageId(peerId: peerId, namespace: namespace, id: 0), timestamp: 0)
    }
    
    public static func upperBound(peerId: PeerId) -> MessageIndex {
        return MessageIndex(id: MessageId(peerId: peerId, namespace: Int32(Int8.max), id: Int32.max), timestamp: Int32.max)
    }
    
    public static func upperBound(peerId: PeerId, namespace: MessageId.Namespace) -> MessageIndex {
        return MessageIndex(id: MessageId(peerId: peerId, namespace: namespace, id: Int32.max), timestamp: Int32.max)
    }
    
    public static func upperBound(peerId: PeerId, timestamp: Int32, namespace: MessageId.Namespace) -> MessageIndex {
        return MessageIndex(id: MessageId(peerId: peerId, namespace: namespace, id: Int32.max), timestamp: timestamp)
    }
    
    func withPeerId(_ peerId: PeerId) -> MessageIndex {
        return MessageIndex(id: MessageId(peerId: peerId, namespace: self.id.namespace, id: self.id.id), timestamp: self.timestamp)
    }
    
    func withNamespace(_ namespace: MessageId.Namespace) -> MessageIndex {
        return MessageIndex(id: MessageId(peerId: self.id.peerId, namespace: namespace, id: self.id.id), timestamp: self.timestamp)
    }

    public static func <(lhs: MessageIndex, rhs: MessageIndex) -> Bool {
        if lhs.timestamp != rhs.timestamp {
            return lhs.timestamp < rhs.timestamp
        }
        
        if lhs.id.namespace != rhs.id.namespace {
            return lhs.id.namespace < rhs.id.namespace
        }
        
        return lhs.id.id < rhs.id.id
    }
}
