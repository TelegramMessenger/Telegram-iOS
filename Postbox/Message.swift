import Foundation

public struct MessageId: Hashable, Comparable, CustomStringConvertible {
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
}

public func ==(lhs: MessageId, rhs: MessageId) -> Bool {
    return lhs.id == rhs.id && lhs.namespace == rhs.namespace && lhs.peerId == rhs.peerId
}

public func <(lhs: MessageId, rhs: MessageId) -> Bool {
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

public struct MessageIndex: Equatable, Comparable, Hashable {
    public let id: MessageId
    public let timestamp: Int32
    
    public init(_ message: Message) {
        self.id = message.id
        self.timestamp = message.timestamp
    }
    
    init(_ message: InternalStoreMessage) {
        self.id = message.id
        self.timestamp = message.timestamp
    }
    
    init (_ message: IntermediateMessage) {
        self.id = message.id
        self.timestamp = message.timestamp
    }
    
    public init(id: MessageId, timestamp: Int32) {
        self.id = id
        self.timestamp = timestamp
    }
    
    public func predecessor() -> MessageIndex {
        return MessageIndex(id: MessageId(peerId: self.id.peerId, namespace: self.id.namespace, id: self.id.id - 1), timestamp: self.timestamp)
    }
    
    public func successor() -> MessageIndex {
        return MessageIndex(id: MessageId(peerId: self.id.peerId, namespace: self.id.namespace, id: self.id.id == Int32.max ? self.id.id : (self.id.id + 1)), timestamp: self.timestamp)
    }
    
    public var hashValue: Int {
        return self.id.hashValue
    }
    
    public static func absoluteUpperBound() -> MessageIndex {
        return MessageIndex(id: MessageId(peerId: PeerId(namespace: Int32.max, id: Int32.max), namespace: Int32.max, id: Int32.max), timestamp: Int32.max)
    }
    
    public static func absoluteLowerBound() -> MessageIndex {
        return MessageIndex(id: MessageId(peerId: PeerId(namespace: 0, id: 0), namespace: 0, id: 0), timestamp: 0)
    }
    
    public static func lowerBound(peerId: PeerId) -> MessageIndex {
        return MessageIndex(id: MessageId(peerId: peerId, namespace: 0, id: 0), timestamp: 0)
    }
    
    public static func upperBound(peerId: PeerId) -> MessageIndex {
        return MessageIndex(id: MessageId(peerId: peerId, namespace: Int32.max, id: Int32.max), timestamp: Int32.max)
    }
    
    public static func upperBound(peerId: PeerId, timestamp: Int32, namespace: MessageId.Namespace) -> MessageIndex {
        return MessageIndex(id: MessageId(peerId: peerId, namespace: namespace, id: Int32.max), timestamp: timestamp)
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

public struct ChatListIndex: Comparable, Hashable {
    public let pinningIndex: UInt16?
    public let messageIndex: MessageIndex
    
    public init(pinningIndex: UInt16?, messageIndex: MessageIndex) {
        self.pinningIndex = pinningIndex
        self.messageIndex = messageIndex
    }
    
    public static func ==(lhs: ChatListIndex, rhs: ChatListIndex) -> Bool {
        return lhs.pinningIndex == rhs.pinningIndex && lhs.messageIndex == rhs.messageIndex
    }
    
    public static func <(lhs: ChatListIndex, rhs: ChatListIndex) -> Bool {
        if let lhsPinningIndex = lhs.pinningIndex, let rhsPinningIndex = rhs.pinningIndex {
            if lhsPinningIndex < rhsPinningIndex {
                return true
            } else if lhsPinningIndex > rhsPinningIndex {
                return false
            }
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

public struct MessageTags: OptionSet {
    public var rawValue: UInt32
    
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
    
    public init() {
        self.rawValue = 0
    }
    
    public static let All = MessageTags(rawValue: 0xffffffff)
}

public struct MessageFlags: OptionSet {
    public var rawValue: UInt32
    
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
    
    public init() {
        self.rawValue = 0
    }
    
    public init(_ flags: StoreMessageFlags) {
        var rawValue: UInt32 = 0
        
        if flags.contains(StoreMessageFlags.Unsent) {
            rawValue |= MessageFlags.Unsent.rawValue
        }
        
        if flags.contains(StoreMessageFlags.Failed) {
            rawValue |= MessageFlags.Failed.rawValue
        }
        
        if flags.contains(StoreMessageFlags.Incoming) {
            rawValue |= MessageFlags.Incoming.rawValue
        }
        
        if flags.contains(StoreMessageFlags.Personal) {
            rawValue |= MessageFlags.Personal.rawValue
        }
        
        if flags.contains(StoreMessageFlags.TopIndexable) {
            rawValue |= MessageFlags.TopIndexable.rawValue
        }
        
        if flags.contains(StoreMessageFlags.Sending) {
            rawValue |= MessageFlags.Sending.rawValue
        }
        
        self.rawValue = rawValue
    }
    
    public static let Unsent = MessageFlags(rawValue: 1)
    public static let Failed = MessageFlags(rawValue: 2)
    public static let Incoming = MessageFlags(rawValue: 4)
    public static let Personal = MessageFlags(rawValue: 8)
    public static let TopIndexable = MessageFlags(rawValue: 16)
    public static let Sending = MessageFlags(rawValue: 32)
}

public struct StoreMessageForwardInfo {
    public let authorId: PeerId
    public let sourceId: PeerId?
    public let sourceMessageId: MessageId?
    public let date: Int32
    
    public init(authorId: PeerId, sourceId: PeerId?, sourceMessageId: MessageId?, date: Int32) {
        self.authorId = authorId
        self.sourceId = sourceId
        self.sourceMessageId = sourceMessageId
        self.date = date
    }
}

public struct MessageForwardInfo: Equatable {
    public let author: Peer
    public let source: Peer?
    public let sourceMessageId: MessageId?
    public let date: Int32
}

public func ==(lhs: MessageForwardInfo, rhs: MessageForwardInfo) -> Bool {
    if !lhs.author.isEqual(rhs.author) {
        return false
    }
    if let lhsSource = lhs.source, let rhsSource = rhs.source {
        if !lhsSource.isEqual(rhsSource) {
            return false
        }
    } else if (lhs.source == nil) != (rhs.source == nil) {
        return false
    }
    if lhs.sourceMessageId != rhs.sourceMessageId {
        return false
    }
    if lhs.date != rhs.date {
        return false
    }
    
    return true
}

public protocol MessageAttribute: Coding {
    var associatedPeerIds: [PeerId] { get }
    var associatedMessageIds: [MessageId] { get }
}

public extension MessageAttribute {
    var associatedPeerIds: [PeerId] {
        return []
    }
    
    var associatedMessageIds: [MessageId] {
        return []
    }
}

public final class Message {
    public let stableId: UInt32
    public let stableVersion: UInt32
    
    public let id: MessageId
    public let globallyUniqueId: Int64?
    public let timestamp: Int32
    public let flags: MessageFlags
    public let tags: MessageTags
    public let forwardInfo: MessageForwardInfo?
    public let author: Peer?
    public let text: String
    public let attributes: [MessageAttribute]
    public let media: [Media]
    public let peers: SimpleDictionary<PeerId, Peer>
    public let associatedMessages: SimpleDictionary<MessageId, Message>
    public let associatedMessageIds: [MessageId]
    
    public init(stableId: UInt32, stableVersion: UInt32, id: MessageId, globallyUniqueId: Int64?, timestamp: Int32, flags: MessageFlags, tags: MessageTags, forwardInfo: MessageForwardInfo?, author: Peer?, text: String, attributes: [MessageAttribute], media: [Media], peers: SimpleDictionary<PeerId, Peer>, associatedMessages: SimpleDictionary<MessageId, Message>, associatedMessageIds: [MessageId]) {
        self.stableId = stableId
        self.stableVersion = stableVersion
        self.id = id
        self.globallyUniqueId = globallyUniqueId
        self.timestamp = timestamp
        self.flags = flags
        self.tags = tags
        self.forwardInfo = forwardInfo
        self.author = author
        self.text = text
        self.attributes = attributes
        self.media = media
        self.peers = peers
        self.associatedMessages = associatedMessages
        self.associatedMessageIds = associatedMessageIds
    }
}

public struct StoreMessageFlags: OptionSet {
    public var rawValue: UInt32
    
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
    
    public init() {
        self.rawValue = 0
    }
    
    public init(_ flags: MessageFlags) {
        var rawValue: UInt32 = 0
        
        if flags.contains(.Unsent) {
            rawValue |= StoreMessageFlags.Unsent.rawValue
        }
        
        if flags.contains(.Failed) {
            rawValue |= StoreMessageFlags.Failed.rawValue
        }
        
        if flags.contains(.Incoming) {
            rawValue |= StoreMessageFlags.Incoming.rawValue
        }
        
        if flags.contains(.Personal) {
            rawValue |= StoreMessageFlags.Personal.rawValue
        }
        
        if flags.contains(.TopIndexable) {
            rawValue |= StoreMessageFlags.TopIndexable.rawValue
        }
        
        if flags.contains(.Sending) {
            rawValue |= StoreMessageFlags.Sending.rawValue
        }
        
        self.rawValue = rawValue
    }
    
    public static let Unsent = StoreMessageFlags(rawValue: 1)
    public static let Failed = StoreMessageFlags(rawValue: 2)
    public static let Incoming = StoreMessageFlags(rawValue: 4)
    public static let Personal = StoreMessageFlags(rawValue: 8)
    public static let TopIndexable = StoreMessageFlags(rawValue: 16)
    public static let Sending = StoreMessageFlags(rawValue: 32)
}

public enum StoreMessageId {
    case Id(MessageId)
    case Partial(PeerId, MessageId.Namespace)
    
    public var peerId: PeerId {
        switch self {
            case let .Id(id):
                return id.peerId
            case let .Partial(peerId, _):
                return peerId
        }
    }
}

public final class StoreMessage {
    public let id: StoreMessageId
    public let timestamp: Int32
    public let globallyUniqueId: Int64?
    public let flags: StoreMessageFlags
    public let tags: MessageTags
    public let forwardInfo: StoreMessageForwardInfo?
    public let authorId: PeerId?
    public let text: String
    public let attributes: [MessageAttribute]
    public let media: [Media]
    
    public init(id: MessageId, globallyUniqueId: Int64?, timestamp: Int32, flags: StoreMessageFlags, tags: MessageTags, forwardInfo: StoreMessageForwardInfo?, authorId: PeerId?, text: String, attributes: [MessageAttribute], media: [Media]) {
        self.id = .Id(id)
        self.globallyUniqueId = globallyUniqueId
        self.timestamp = timestamp
        self.flags = flags
        self.tags = tags
        self.forwardInfo = forwardInfo
        self.authorId = authorId
        self.text = text
        self.attributes = attributes
        self.media = media
    }
    
    public init(peerId: PeerId, namespace: MessageId.Namespace, globallyUniqueId: Int64?, timestamp: Int32, flags: StoreMessageFlags, tags: MessageTags, forwardInfo: StoreMessageForwardInfo?, authorId: PeerId?, text: String, attributes: [MessageAttribute], media: [Media]) {
        self.id = .Partial(peerId, namespace)
        self.timestamp = timestamp
        self.globallyUniqueId = globallyUniqueId
        self.flags = flags
        self.tags = tags
        self.forwardInfo = forwardInfo
        self.authorId = authorId
        self.text = text
        self.attributes = attributes
        self.media = media
    }
}

final class InternalStoreMessage {
    let id: MessageId
    let timestamp: Int32
    let globallyUniqueId: Int64?
    let flags: StoreMessageFlags
    let tags: MessageTags
    let forwardInfo: StoreMessageForwardInfo?
    let authorId: PeerId?
    let text: String
    let attributes: [MessageAttribute]
    let media: [Media]
    
    init(id: MessageId, timestamp: Int32, globallyUniqueId: Int64?, flags: StoreMessageFlags, tags: MessageTags, forwardInfo: StoreMessageForwardInfo?, authorId: PeerId?, text: String, attributes: [MessageAttribute], media: [Media]) {
        self.id = id
        self.timestamp = timestamp
        self.globallyUniqueId = globallyUniqueId
        self.flags = flags
        self.tags = tags
        self.forwardInfo = forwardInfo
        self.authorId = authorId
        self.text = text
        self.attributes = attributes
        self.media = media
    }
}
