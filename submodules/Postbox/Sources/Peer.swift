import Foundation

public struct PeerId: Hashable, CustomStringConvertible, Comparable {
    public typealias Namespace = Int32
    public typealias Id = Int32
    
    public let namespace: Namespace
    public let id: Id
    
    public init(namespace: Namespace, id: Id) {
        self.namespace = namespace
        self.id = id
    }
    
    public init(_ n: Int64) {
        self.namespace = Int32((n >> 32) & 0x7fffffff)
        self.id = Int32(bitPattern: UInt32(n & 0xffffffff))
    }
    
    public func toInt64() -> Int64 {
        return (Int64(self.namespace) << 32) | Int64(bitPattern: UInt64(UInt32(bitPattern: self.id)))
    }
    
    public static func encodeArrayToBuffer(_ array: [PeerId], buffer: WriteBuffer) {
        var length: Int32 = Int32(array.count)
        buffer.write(&length, offset: 0, length: 4)
        for id in array {
            var value = id.toInt64()
            buffer.write(&value, offset: 0, length: 8)
        }
    }
    
    public static func decodeArrayFromBuffer(_ buffer: ReadBuffer) -> [PeerId] {
        var length: Int32 = 0
        memcpy(&length, buffer.memory, 4)
        buffer.offset += 4
        var i = 0
        var array: [PeerId] = []
        array.reserveCapacity(Int(length))
        while i < Int(length) {
            var value: Int64 = 0
            buffer.read(&value, offset: 0, length: 8)
            array.append(PeerId(value))
            i += 1
        }
        return array
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
        var namespace: Int32 = 0
        var id: Int32 = 0
        memcpy(&namespace, buffer.memory, 4)
        self.namespace = namespace
        memcpy(&id, buffer.memory + 4, 4)
        self.id = id
    }
    
    public func encodeToBuffer(_ buffer: WriteBuffer) {
        var namespace = self.namespace
        var id = self.id
        buffer.write(&namespace, offset: 0, length: 4);
        buffer.write(&id, offset: 0, length: 4);
    }

    public static func <(lhs: PeerId, rhs: PeerId) -> Bool {
        if lhs.namespace != rhs.namespace {
            return lhs.namespace < rhs.namespace
        }
        
        if lhs.id != rhs.id {
            return lhs.id < rhs.id
        }
        
        return false
    }
}

public protocol Peer: class, PostboxCoding {
    var id: PeerId { get }
    var indexName: PeerIndexNameRepresentation { get }
    var associatedPeerId: PeerId? { get }
    var notificationSettingsPeerId: PeerId? { get }
    
    func isEqual(_ other: Peer) -> Bool
}

public func arePeersEqual(_ lhs: Peer?, _ rhs: Peer?) -> Bool {
    if let lhs = lhs, let rhs = rhs {
        return lhs.isEqual(rhs)
    } else {
        return (lhs != nil) == (rhs != nil)
    }
}

public func arePeerArraysEqual(_ lhs: [Peer], _ rhs: [Peer]) -> Bool {
    if lhs.count != rhs.count {
        return false
    }
    for i in 0 ..< lhs.count {
        if !lhs[i].isEqual(rhs[i]) {
            return false
        }
    }
    return true
}

public func arePeerDictionariesEqual(_ lhs: SimpleDictionary<PeerId, Peer>, _ rhs: SimpleDictionary<PeerId, Peer>) -> Bool {
    if lhs.count != rhs.count {
        return false
    }
    for (id, lhsPeer) in lhs {
        if let rhsPeer = rhs[id] {
            if !lhsPeer.isEqual(rhsPeer) {
                return false
            }
        } else {
            return false
        }
    }
    return true
}

public func arePeerDictionariesEqual(_ lhs: [PeerId: Peer], _ rhs: [PeerId: Peer]) -> Bool {
    if lhs.count != rhs.count {
        return false
    }
    for (id, lhsPeer) in lhs {
        if let rhsPeer = rhs[id] {
            if !lhsPeer.isEqual(rhsPeer) {
                return false
            }
        } else {
            return false
        }
    }
    return true
}

public struct PeerSummaryCounterTags: OptionSet, Sequence, Hashable {
    public var rawValue: Int32
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public init() {
        self.rawValue = 0
    }
    
    public func makeIterator() -> AnyIterator<PeerSummaryCounterTags> {
        var index = 0
        return AnyIterator { () -> PeerSummaryCounterTags? in
            while index < 31 {
                let currentTags = self.rawValue >> UInt32(index)
                let tag = PeerSummaryCounterTags(rawValue: 1 << UInt32(index))
                index += 1
                if currentTags == 0 {
                    break
                }
                
                if (currentTags & 1) != 0 {
                    return tag
                }
            }
            return nil
        }
    }
}
