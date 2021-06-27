import Foundation

public struct PeerId: Hashable, CustomStringConvertible, Comparable, Codable {
    public struct Namespace: Comparable, Hashable, Codable, CustomStringConvertible {
        public static var max: Namespace {
            return Namespace(rawValue: 0x7)
        }

        fileprivate var rawValue: UInt32

        var predecessor: Namespace {
            if self.rawValue != 0 {
                return Namespace(rawValue: self.rawValue - 1)
            } else {
                return self
            }
        }

        var successor: Namespace {
            if self.rawValue != Namespace.max.rawValue {
                return Namespace(rawValue: self.rawValue + 1)
            } else {
                return self
            }
        }

        public var description: String {
            return "\(self.rawValue)"
        }

        fileprivate init(rawValue: UInt32) {
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
        public static var min: Id {
            return Id(rawValue: 0)
        }

        public static var max: Id {
            return Id(rawValue: 0x000000007fffffff)
        }

        fileprivate var rawValue: Int32

        var predecessor: Id {
            if self.rawValue != 0 {
                return Id(rawValue: self.rawValue - 1)
            } else {
                return self
            }
        }

        var successor: Id {
            if self.rawValue != Id.max.rawValue {
                return Id(rawValue: self.rawValue + 1)
            } else {
                return self
            }
        }

        public var description: String {
            return "\(self.rawValue)"
        }

        fileprivate init(rawValue: Int32) {
            //precondition((rawValue | 0x000FFFFFFFFFFFFF) == 0x000FFFFFFFFFFFFF)

            self.rawValue = rawValue
        }

        public static func _internalFromInt32Value(_ value: Int32) -> Id {
            return Id(rawValue: value)
        }

        public func _internalGetInt32Value() -> Int32 {
            return self.rawValue
        }

        public static func <(lhs: Id, rhs: Id) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }

    public static var max: PeerId {
        return PeerId(namespace: .max, id: .max)
    }
    
    public let namespace: Namespace
    public let id: Id

    var predecessor: PeerId {
        let previousId = self.id.predecessor
        if previousId != self.id {
            return PeerId(namespace: self.namespace, id: previousId)
        } else {
            let previousNamespace = self.namespace.predecessor
            if previousNamespace != self.namespace {
                return PeerId(namespace: previousNamespace, id: .max)
            } else {
                return self
            }
        }
    }

    var successor: PeerId {
        let nextId = self.id.successor
        if nextId != self.id {
            return PeerId(namespace: self.namespace, id: nextId)
        } else {
            let nextNamespace = self.namespace.successor
            if nextNamespace != self.namespace {
                return PeerId(namespace: nextNamespace, id: .min)
            } else {
                return self
            }
        }
    }
    
    public init(namespace: Namespace, id: Id) {
        self.namespace = namespace
        self.id = id
    }
    
    public init(_ n: Int64) {
        let data = UInt64(bitPattern: n)

        let legacyNamespaceBits = ((data >> 32) & 0xffffffff)
        let idLowBits = data & 0xffffffff

        if legacyNamespaceBits == 0x7fffffff && idLowBits == 0 {
            self.namespace = .max
            self.id = Id(rawValue: Int32(bitPattern: UInt32(clamping: idLowBits)))
        } else {
            let namespaceBits = ((data >> 32) & 0x7)
            self.namespace = Namespace(rawValue: UInt32(namespaceBits))

            let idHighBits = (data >> (32 + 3)) & 0xffffffff
            //assert(idHighBits == 0)

            self.id = Id(rawValue: Int32(bitPattern: UInt32(clamping: idLowBits)))
        }
    }
    
    public func toInt64() -> Int64 {
        let idLowBits = UInt32(bitPattern: self.id.rawValue)

        let result: Int64
        if self.namespace == .max && self.id.rawValue == 0 {
            var data: UInt64 = 0

            let namespaceBits: UInt64 = 0x7fffffff
            data |= namespaceBits << 32

            data |= UInt64(idLowBits)

            result = Int64(bitPattern: data)
        } else {
            var data: UInt64 = 0
            data |= UInt64(self.namespace.rawValue) << 32

            let idValue = UInt32(bitPattern: self.id.rawValue)
            let idHighBits = (idValue >> 32) & 0x3FFFFFFF
            assert(idHighBits == 0)

            data |= UInt64(idLowBits)

            result = Int64(bitPattern: data)
        }

        assert(PeerId(result) == self)

        return result
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
