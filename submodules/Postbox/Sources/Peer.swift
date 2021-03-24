import Foundation

public struct PeerId: Hashable, CustomStringConvertible, Comparable, Codable {
    public struct Namespace: Comparable, Hashable, Codable {
        public static var max: Namespace {
            return Namespace(rawValue: 0x7)
        }

        fileprivate var rawValue: UInt32

        public init(rawValue: UInt32) {
            precondition((rawValue | 0x7) == 0x7)

            self.rawValue = rawValue
        }

        public static func _internalFromInt32Value(_ value: Int32) -> Namespace {
            return Namespace(rawValue: UInt32(bitPattern: value))
        }

        public func _internalGetInt32Value() -> Int32 {
            return Int32(bitPattern: self.rawValue)
        }

        public static func <(lhs: Namespace, rhs: Namespace) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }

    public struct Id: Comparable, Hashable, Codable {
        fileprivate var rawValue: UInt64

        public init(rawValue: UInt64) {
            precondition((rawValue | 0xFFFFFFFFFFFFF) == 0xFFFFFFFFFFFFF)

            self.rawValue = rawValue
        }

        public static func _internalFromInt32Value(_ value: Int32) -> Id {
            return Id(rawValue: UInt64(UInt32(bitPattern: value)))
        }

        public func _internalGetInt32Value() -> Int32 {
            return Int32(clamping: self.rawValue)
        }

        public static func <(lhs: Id, rhs: Id) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }

    public static var max: PeerId {
        return PeerId(Int64(bitPattern: UInt64.max))
    }
    
    public let namespace: Namespace
    public let id: Id
    
    public init(namespace: Namespace, id: Id) {
        self.namespace = namespace
        self.id = id
    }
    
    public init(_ n: Int64) {
        let data = UInt64(bitPattern: n)

        let namespaceBits = ((data >> 32) & 0x7)
        self.namespace = Namespace(rawValue: UInt32(namespaceBits))

        let idLowBits = data & 0xffffffff
        let idHighBits = (data >> (32 + 3)) & 0xffffffff
        assert(idHighBits == 0)

        self.id = Id(rawValue: idLowBits)
    }
    
    public func toInt64() -> Int64 {
        var data: UInt64 = 0
        data |= UInt64(self.namespace.rawValue) << 32

        let idLowBits = self.id.rawValue & 0xffffffff
        let idHighBits = (self.id.rawValue >> 32) & 0x3FFFFFFF
        assert(idHighBits == 0)

        data |= idLowBits

        return Int64(bitPattern: data)
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
    
    public var description: String {
        get {
            return "\(namespace):\(id)"
        }
    }
    
    /*public init(_ buffer: ReadBuffer) {
        var value: Int64 = 0
        memcpy(&value, buffer.memory, 8)
        buffer.offset += 8

        self.init(value)
    }*/
    
    public func encodeToBuffer(_ buffer: WriteBuffer) {
        var value = self.toInt64()
        buffer.write(&value, offset: 0, length: 8);
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
