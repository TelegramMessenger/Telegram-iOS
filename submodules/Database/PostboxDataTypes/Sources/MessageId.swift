import Foundation
import Buffers

public struct MessageId: Hashable, Comparable, CustomStringConvertible {
    public typealias Namespace = Int32
    public typealias Id = Int32
    
    public let peerId: PeerId
    public let namespace: Namespace
    public let id: Id
    
    public var description: String {
        get {
            return "\(namespace)_\(id)"
        }
    }
    
    public init(peerId: PeerId, namespace: Namespace, id: Id) {
        self.peerId = peerId
        self.namespace = namespace
        self.id = id
    }
    
    public init(_ buffer: ReadBuffer) {
        var peerIdNamespaceValue: Int32 = 0
        memcpy(&peerIdNamespaceValue, buffer.memory + buffer.offset, 4)
        var peerIdIdValue: Int32 = 0
        memcpy(&peerIdIdValue, buffer.memory + (buffer.offset + 4), 4)
        self.peerId = PeerId(namespace: peerIdNamespaceValue, id: peerIdIdValue)
        
        var namespaceValue: Int32 = 0
        memcpy(&namespaceValue, buffer.memory + (buffer.offset + 8), 4)
        self.namespace = namespaceValue
        var idValue: Int32 = 0
        memcpy(&idValue, buffer.memory + (buffer.offset + 12), 4)
        self.id = idValue
        
        buffer.offset += 16
    }
    
    public func encodeToBuffer(_ buffer: WriteBuffer) {
        var peerIdNamespace = self.peerId.namespace
        var peerIdId = self.peerId.id
        var namespace = self.namespace
        var id = self.id
        buffer.write(&peerIdNamespace, offset: 0, length: 4);
        buffer.write(&peerIdId, offset: 0, length: 4);
        buffer.write(&namespace, offset: 0, length: 4);
        buffer.write(&id, offset: 0, length: 4);
    }
    
    public static func encodeArrayToBuffer(_ array: [MessageId], buffer: WriteBuffer) {
        var length: Int32 = Int32(array.count)
        buffer.write(&length, offset: 0, length: 4)
        for id in array {
            id.encodeToBuffer(buffer)
        }
    }
    
    public static func decodeArrayFromBuffer(_ buffer: ReadBuffer) -> [MessageId] {
        var length: Int32 = 0
        memcpy(&length, buffer.memory, 4)
        buffer.offset += 4
        var i = 0
        var array: [MessageId] = []
        while i < Int(length) {
            array.append(MessageId(buffer))
            i += 1
        }
        return array
    }

    public static func <(lhs: MessageId, rhs: MessageId) -> Bool {
        if lhs.namespace == rhs.namespace {
            if lhs.id == rhs.id {
                return lhs.peerId < rhs.peerId
            } else {
                return lhs.id < rhs.id
            }
        } else {
            return lhs.namespace < rhs.namespace
        }
    }
}

public struct ChatListIndex: Comparable, Hashable {
    public let pinningIndex: UInt16?
    public let messageIndex: MessageIndex
    
    public init(pinningIndex: UInt16?, messageIndex: MessageIndex) {
        self.pinningIndex = pinningIndex
        self.messageIndex = messageIndex
    }
    
    public static func <(lhs: ChatListIndex, rhs: ChatListIndex) -> Bool {
        if let lhsPinningIndex = lhs.pinningIndex, let rhsPinningIndex = rhs.pinningIndex {
            if lhsPinningIndex > rhsPinningIndex {
                return true
            } else if lhsPinningIndex < rhsPinningIndex {
                return false
            }
        } else if lhs.pinningIndex != nil {
            return false
        } else if rhs.pinningIndex != nil {
            return true
        }
        return lhs.messageIndex < rhs.messageIndex
    }
    
    public var hashValue: Int {
        return self.messageIndex.hashValue
    }
    
    public static var absoluteUpperBound: ChatListIndex {
        return ChatListIndex(pinningIndex: 0, messageIndex: MessageIndex.absoluteUpperBound())
    }
    
    public static var absoluteLowerBound: ChatListIndex {
        return ChatListIndex(pinningIndex: nil, messageIndex: MessageIndex.absoluteLowerBound())
    }
    
    public var predecessor: ChatListIndex {
        return ChatListIndex(pinningIndex: self.pinningIndex, messageIndex: self.messageIndex.predecessor())
    }
    
    public var successor: ChatListIndex {
        return ChatListIndex(pinningIndex: self.pinningIndex, messageIndex: self.messageIndex.successor())
    }
}

public struct MessageTags: OptionSet, Sequence, Hashable {
    public var rawValue: UInt32
    
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
    
    public init() {
        self.rawValue = 0
    }
    
    public static let All = MessageTags(rawValue: 0xffffffff)
    
    public var containsSingleElement: Bool {
        var hasOne = false
        for i in 0 ..< 31 {
            let tag = (self.rawValue >> UInt32(i)) & 1
            if tag != 0 {
                if hasOne {
                    return false
                } else {
                    hasOne = true
                }
            }
        }
        return hasOne
    }
    
    public func makeIterator() -> AnyIterator<MessageTags> {
        var index = 0
        return AnyIterator { () -> MessageTags? in
            while index < 31 {
                let currentTags = self.rawValue >> UInt32(index)
                let tag = MessageTags(rawValue: 1 << UInt32(index))
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

public struct GlobalMessageTags: OptionSet, Sequence, Hashable {
    public var rawValue: UInt32
    
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
    
    public init() {
        self.rawValue = 0
    }
    
    var isSingleTag: Bool {
        let t = Int32(bitPattern: self.rawValue)
        return t != 0 && t == (t & (-t))
    }
    
    public func makeIterator() -> AnyIterator<GlobalMessageTags> {
        var index = 0
        return AnyIterator { () -> GlobalMessageTags? in
            while index < 31 {
                let currentTags = self.rawValue >> UInt32(index)
                let tag = GlobalMessageTags(rawValue: 1 << UInt32(index))
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
    
    public var hashValue: Int {
        return self.rawValue.hashValue
    }
}

public struct LocalMessageTags: OptionSet, Sequence, Hashable {
    public var rawValue: UInt32
    
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
    
    public init() {
        self.rawValue = 0
    }
    
    var isSingleTag: Bool {
        let t = Int32(bitPattern: self.rawValue)
        return t != 0 && t == (t & (-t))
    }
    
    public func makeIterator() -> AnyIterator<LocalMessageTags> {
        var index = 0
        return AnyIterator { () -> LocalMessageTags? in
            while index < 31 {
                let currentTags = self.rawValue >> UInt32(index)
                let tag = LocalMessageTags(rawValue: 1 << UInt32(index))
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
    
    public var hashValue: Int {
        return self.rawValue.hashValue
    }
}

public struct MessageFlags: OptionSet {
    public var rawValue: UInt32
    
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
    
    public init() {
        self.rawValue = 0
    }
    
    public static let Unsent = MessageFlags(rawValue: 1)
    public static let Failed = MessageFlags(rawValue: 2)
    public static let Incoming = MessageFlags(rawValue: 4)
    public static let TopIndexable = MessageFlags(rawValue: 16)
    public static let Sending = MessageFlags(rawValue: 32)
    public static let CanBeGroupedIntoFeed = MessageFlags(rawValue: 64)
    public static let WasScheduled = MessageFlags(rawValue: 128)
    public static let CountedAsIncoming = MessageFlags(rawValue: 256)
    
    public static let IsIncomingMask = MessageFlags([.Incoming, .CountedAsIncoming])
}
