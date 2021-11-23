import Foundation

public struct MessageId: Hashable, Comparable, CustomStringConvertible, PostboxCoding, Codable {
    public typealias Namespace = Int32
    public typealias Id = Int32
    
    public let peerId: PeerId
    public let namespace: Namespace
    public let id: Id
    
    public var description: String {
        get {
            return "\(peerId):\(namespace)_\(id)"
        }
    }
    
    public init(peerId: PeerId, namespace: Namespace, id: Id) {
        self.peerId = peerId
        self.namespace = namespace
        self.id = id
        if namespace == 0 && id == 0 {
            assert(true)
        }
    }
    
    public init(_ buffer: ReadBuffer) {
        var peerIdInt64Value: Int64 = 0
        memcpy(&peerIdInt64Value, buffer.memory + buffer.offset, 8)

        self.peerId = PeerId(peerIdInt64Value)
        
        var namespaceValue: Int32 = 0
        memcpy(&namespaceValue, buffer.memory + (buffer.offset + 8), 4)
        self.namespace = namespaceValue
        var idValue: Int32 = 0
        memcpy(&idValue, buffer.memory + (buffer.offset + 12), 4)
        self.id = idValue
        
        buffer.offset += 16
    }

    private init(bytes: UnsafePointer<UInt8>, offset: inout Int) {
        var peerIdInt64Value: Int64 = 0
        memcpy(&peerIdInt64Value, bytes.advanced(by: offset), 8)

        self.peerId = PeerId(peerIdInt64Value)

        var namespaceValue: Int32 = 0
        memcpy(&namespaceValue, bytes.advanced(by: offset + 8), 4)
        self.namespace = namespaceValue
        var idValue: Int32 = 0
        memcpy(&idValue, bytes.advanced(by: offset + 12), 4)
        self.id = idValue

        offset += 16
    }
    
    public init(decoder: PostboxDecoder) {
        self.peerId = PeerId(decoder.decodeInt64ForKey("p", orElse: 0))
        self.namespace = decoder.decodeInt32ForKey("n", orElse: 0)
        self.id = decoder.decodeInt32ForKey("i", orElse: 0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.peerId.toInt64(), forKey: "p")
        encoder.encodeInt32(self.namespace, forKey: "n")
        encoder.encodeInt32(self.id, forKey: "i")
    }
    
    public func encodeToBuffer(_ buffer: WriteBuffer) {
        var peerIdValue = self.peerId.toInt64()
        var namespace = self.namespace
        var id = self.id
        buffer.write(&peerIdValue, offset: 0, length: 8)
        buffer.write(&namespace, offset: 0, length: 4)
        buffer.write(&id, offset: 0, length: 4)
    }

    public func encodeToData(_ data: inout Data) {
        var peerIdValue = self.peerId.toInt64()
        var namespace = self.namespace
        var id = self.id
        data.append(Data(bytesNoCopy: &peerIdValue, count: 8, deallocator: .none))
        data.append(Data(bytesNoCopy: &namespace, count: 4, deallocator: .none))
        data.append(Data(bytesNoCopy: &id, count: 4, deallocator: .none))
    }
    
    public static func encodeArrayToBuffer(_ array: [MessageId], buffer: WriteBuffer) {
        var length: Int32 = Int32(array.count)
        buffer.write(&length, offset: 0, length: 4)
        for id in array {
            id.encodeToBuffer(buffer)
        }
    }

    public static func encodeArrayToData(_ array: [MessageId]) -> Data {
        var result = Data()
        var length: Int32 = Int32(array.count)
        result.append(Data(bytesNoCopy: &length, count: 4, deallocator: .none))
        for id in array {
            id.encodeToData(&result)
        }
        return result
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

    public static func decodeArrayFromData(_ data: Data) -> [MessageId] {
        return data.withUnsafeBytes { bytes -> [MessageId] in
            guard let baseAddress = bytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return []
            }
            var offset = 0
            var length: Int32 = 0
            memcpy(&length, baseAddress, 4)
            offset += 4
            var i = 0
            var array: [MessageId] = []
            while i < Int(length) {
                array.append(MessageId(bytes: baseAddress, offset: &offset))
                i += 1
            }
            return array
        }
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

public struct MessageIndex: Codable, Comparable, Hashable {
    public let id: MessageId
    public let timestamp: Int32
    
    public init(id: MessageId, timestamp: Int32) {
        self.id = id
        self.timestamp = timestamp
    }
    
    public func globalPredecessor() -> MessageIndex {
        let previousPeerId = self.id.peerId.predecessor
        if previousPeerId != self.id.peerId {
            return MessageIndex(id: MessageId(peerId: previousPeerId, namespace: self.id.namespace, id: self.id.id), timestamp: self.timestamp)
        } else if self.id.id != 0 {
            return MessageIndex(id: MessageId(peerId: self.id.peerId, namespace: self.id.namespace, id: self.id.id - 1), timestamp: self.timestamp)
        } else if self.id.namespace != 0 {
            return MessageIndex(id: MessageId(peerId: self.id.peerId, namespace: self.id.namespace - 1, id: Int32.max - 1), timestamp: self.timestamp)
        } else if self.timestamp != 0 {
            return MessageIndex(id: MessageId(peerId: self.id.peerId, namespace: Int32(Int8.max) - 1, id: Int32.max - 1), timestamp: self.timestamp - 1)
        } else {
            return self
        }
    }

    public func peerLocalPredecessor() -> MessageIndex {
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
    
    public func globalSuccessor() -> MessageIndex {
        let nextPeerId = self.id.peerId.successor
        if nextPeerId != self.id.peerId {
            return MessageIndex(id: MessageId(peerId: nextPeerId, namespace: self.id.namespace, id: self.id.id), timestamp: self.timestamp)
        } else {
            return MessageIndex(id: MessageId(peerId: self.id.peerId, namespace: self.id.namespace, id: self.id.id == Int32.max ? self.id.id : (self.id.id + 1)), timestamp: self.timestamp)
        }
    }

    public func peerLocalSuccessor() -> MessageIndex {
        return MessageIndex(id: MessageId(peerId: self.id.peerId, namespace: self.id.namespace, id: self.id.id == Int32.max ? self.id.id : (self.id.id + 1)), timestamp: self.timestamp)
    }
    
    public static func absoluteUpperBound() -> MessageIndex {
        return MessageIndex(id: MessageId(peerId: PeerId.max, namespace: Int32(Int8.max), id: Int32.max), timestamp: Int32.max)
    }
    
    public static func absoluteLowerBound() -> MessageIndex {
        return MessageIndex(id: MessageId(peerId: PeerId(0), namespace: 0, id: 0), timestamp: 0)
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
        
        if lhs.id.id != rhs.id.id {
            return lhs.id.id < rhs.id.id
        }
        
        return lhs.id.peerId.toInt64() < rhs.id.peerId.toInt64()
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
    
    public static var absoluteUpperBound: ChatListIndex {
        return ChatListIndex(pinningIndex: 0, messageIndex: MessageIndex.absoluteUpperBound())
    }
    
    public static var absoluteLowerBound: ChatListIndex {
        return ChatListIndex(pinningIndex: nil, messageIndex: MessageIndex.absoluteLowerBound())
    }
    
    public static var pinnedLowerBound: ChatListIndex {
        return ChatListIndex(pinningIndex: UInt16(Int8.max - 1), messageIndex: MessageIndex.absoluteLowerBound())
    }
    
    public var predecessor: ChatListIndex {
        return ChatListIndex(pinningIndex: self.pinningIndex, messageIndex: self.messageIndex.globalPredecessor())
    }
    
    public var successor: ChatListIndex {
        return ChatListIndex(pinningIndex: self.pinningIndex, messageIndex: self.messageIndex.globalSuccessor())
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
        
        if flags.contains(StoreMessageFlags.TopIndexable) {
            rawValue |= MessageFlags.TopIndexable.rawValue
        }
        
        if flags.contains(StoreMessageFlags.Sending) {
            rawValue |= MessageFlags.Sending.rawValue
        }
        
        if flags.contains(StoreMessageFlags.CanBeGroupedIntoFeed) {
            rawValue |= MessageFlags.CanBeGroupedIntoFeed.rawValue
        }
        
        if flags.contains(StoreMessageFlags.WasScheduled) {
            rawValue |= MessageFlags.WasScheduled.rawValue
        }
        
        if flags.contains(StoreMessageFlags.CountedAsIncoming) {
            rawValue |= MessageFlags.CountedAsIncoming.rawValue
        }
        
        if flags.contains(StoreMessageFlags.CopyProtected) {
            rawValue |= MessageFlags.CopyProtected.rawValue
        }
        
        self.rawValue = rawValue
    }
    
    public static let Unsent = MessageFlags(rawValue: 1)
    public static let Failed = MessageFlags(rawValue: 2)
    public static let Incoming = MessageFlags(rawValue: 4)
    public static let TopIndexable = MessageFlags(rawValue: 16)
    public static let Sending = MessageFlags(rawValue: 32)
    public static let CanBeGroupedIntoFeed = MessageFlags(rawValue: 64)
    public static let WasScheduled = MessageFlags(rawValue: 128)
    public static let CountedAsIncoming = MessageFlags(rawValue: 256)
    public static let CopyProtected = MessageFlags(rawValue: 512)
    
    public static let IsIncomingMask = MessageFlags([.Incoming, .CountedAsIncoming])
}

public struct StoreMessageForwardInfo {
    public let authorId: PeerId?
    public let sourceId: PeerId?
    public let sourceMessageId: MessageId?
    public let date: Int32
    public let authorSignature: String?
    public let psaType: String?
    public let flags: MessageForwardInfo.Flags
    
    public init(authorId: PeerId?, sourceId: PeerId?, sourceMessageId: MessageId?, date: Int32, authorSignature: String?, psaType: String?, flags: MessageForwardInfo.Flags) {
        self.authorId = authorId
        self.sourceId = sourceId
        self.sourceMessageId = sourceMessageId
        self.date = date
        self.authorSignature = authorSignature
        self.psaType = psaType
        self.flags = flags
    }
    
    public init(_ info: MessageForwardInfo) {
        self.init(authorId: info.author?.id, sourceId: info.source?.id, sourceMessageId: info.sourceMessageId, date: info.date, authorSignature: info.authorSignature, psaType: info.psaType, flags: info.flags)
    }
}

public struct MessageForwardInfo: Equatable {
    public struct Flags: OptionSet {
        public var rawValue: Int32
        
        public init(rawValue: Int32) {
            self.rawValue = rawValue
        }
        
        public static let isImported = Flags(rawValue: 1 << 0)
    }
    
    public let author: Peer?
    public let source: Peer?
    public let sourceMessageId: MessageId?
    public let date: Int32
    public let authorSignature: String?
    public let psaType: String?
    public let flags: MessageForwardInfo.Flags
    
    public init(author: Peer?, source: Peer?, sourceMessageId: MessageId?, date: Int32, authorSignature: String?, psaType: String?, flags: MessageForwardInfo.Flags) {
        self.author = author
        self.source = source
        self.sourceMessageId = sourceMessageId
        self.date = date
        self.authorSignature = authorSignature
        self.psaType = psaType
        self.flags = flags
    }

    public static func ==(lhs: MessageForwardInfo, rhs: MessageForwardInfo) -> Bool {
        if !arePeersEqual(lhs.author, rhs.author) {
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
        if lhs.authorSignature != rhs.authorSignature {
            return false
        }
        if lhs.psaType != rhs.psaType {
            return false
        }
        if lhs.flags != rhs.flags {
            return false
        }
        
        return true
    }
}

public protocol MessageAttribute: AnyObject, PostboxCoding {
    var associatedPeerIds: [PeerId] { get }
    var associatedMessageIds: [MessageId] { get }
    var automaticTimestampBasedAttribute: (UInt16, Int32)? { get }
}

public extension MessageAttribute {
    var associatedPeerIds: [PeerId] {
        return []
    }
    
    var associatedMessageIds: [MessageId] {
        return []
    }
    
    var automaticTimestampBasedAttribute: (UInt16, Int32)? {
        return nil
    }
}

public struct MessageGroupInfo: Equatable {
    public let stableId: UInt32
}

public final class Message {
    public let stableId: UInt32
    public let stableVersion: UInt32
    
    public let id: MessageId
    public let globallyUniqueId: Int64?
    public let groupingKey: Int64?
    public let groupInfo: MessageGroupInfo?
    public let threadId: Int64?
    public let timestamp: Int32
    public let flags: MessageFlags
    public let tags: MessageTags
    public let globalTags: GlobalMessageTags
    public let localTags: LocalMessageTags
    public let forwardInfo: MessageForwardInfo?
    public let author: Peer?
    public let text: String
    public let attributes: [MessageAttribute]
    public let media: [Media]
    public let peers: SimpleDictionary<PeerId, Peer>
    public let associatedMessages: SimpleDictionary<MessageId, Message>
    public let associatedMessageIds: [MessageId]
    
    public var index: MessageIndex {
        return MessageIndex(id: self.id, timestamp: self.timestamp)
    }
    
    public init(stableId: UInt32, stableVersion: UInt32, id: MessageId, globallyUniqueId: Int64?, groupingKey: Int64?, groupInfo: MessageGroupInfo?, threadId: Int64?, timestamp: Int32, flags: MessageFlags, tags: MessageTags, globalTags: GlobalMessageTags, localTags: LocalMessageTags, forwardInfo: MessageForwardInfo?, author: Peer?, text: String, attributes: [MessageAttribute], media: [Media], peers: SimpleDictionary<PeerId, Peer>, associatedMessages: SimpleDictionary<MessageId, Message>, associatedMessageIds: [MessageId]) {
        self.stableId = stableId
        self.stableVersion = stableVersion
        self.id = id
        self.globallyUniqueId = globallyUniqueId
        self.groupingKey = groupingKey
        self.groupInfo = groupInfo
        self.threadId = threadId
        self.timestamp = timestamp
        self.flags = flags
        self.tags = tags
        self.globalTags = globalTags
        self.localTags = localTags
        self.forwardInfo = forwardInfo
        self.author = author
        self.text = text
        self.attributes = attributes
        self.media = media
        self.peers = peers
        self.associatedMessages = associatedMessages
        self.associatedMessageIds = associatedMessageIds
    }
    
    public func withUpdatedText(_ text: String) -> Message {
        return Message(stableId: self.stableId, stableVersion: self.stableVersion, id: self.id, globallyUniqueId: self.globallyUniqueId, groupingKey: self.groupingKey, groupInfo: self.groupInfo, threadId: self.threadId, timestamp: self.timestamp, flags: self.flags, tags: self.tags, globalTags: self.globalTags, localTags: self.localTags, forwardInfo: self.forwardInfo, author: self.author, text: text, attributes: self.attributes, media: self.media, peers: self.peers, associatedMessages: self.associatedMessages, associatedMessageIds: self.associatedMessageIds)
    }
    
    public func withUpdatedTimestamp(_ timestamp: Int32) -> Message {
        return Message(stableId: self.stableId, stableVersion: self.stableVersion, id: self.id, globallyUniqueId: self.globallyUniqueId, groupingKey: self.groupingKey, groupInfo: self.groupInfo, threadId: self.threadId, timestamp: timestamp, flags: self.flags, tags: self.tags, globalTags: self.globalTags, localTags: self.localTags, forwardInfo: self.forwardInfo, author: self.author, text: self.text, attributes: self.attributes, media: self.media, peers: self.peers, associatedMessages: self.associatedMessages, associatedMessageIds: self.associatedMessageIds)
    }
    
    public func withUpdatedMedia(_ media: [Media]) -> Message {
        return Message(stableId: self.stableId, stableVersion: self.stableVersion, id: self.id, globallyUniqueId: self.globallyUniqueId, groupingKey: self.groupingKey, groupInfo: self.groupInfo, threadId: self.threadId, timestamp: self.timestamp, flags: self.flags, tags: self.tags, globalTags: self.globalTags, localTags: self.localTags, forwardInfo: self.forwardInfo, author: self.author, text: self.text, attributes: self.attributes, media: media, peers: self.peers, associatedMessages: self.associatedMessages, associatedMessageIds: self.associatedMessageIds)
    }
    
    public func withUpdatedPeers(_ peers: SimpleDictionary<PeerId, Peer>) -> Message {
        return Message(stableId: self.stableId, stableVersion: self.stableVersion, id: self.id, globallyUniqueId: self.globallyUniqueId, groupingKey: self.groupingKey, groupInfo: self.groupInfo, threadId: self.threadId, timestamp: self.timestamp, flags: self.flags, tags: self.tags, globalTags: self.globalTags, localTags: self.localTags, forwardInfo: self.forwardInfo, author: self.author, text: self.text, attributes: self.attributes, media: self.media, peers: peers, associatedMessages: self.associatedMessages, associatedMessageIds: self.associatedMessageIds)
    }
    
    public func withUpdatedFlags(_ flags: MessageFlags) -> Message {
        return Message(stableId: self.stableId, stableVersion: self.stableVersion, id: self.id, globallyUniqueId: self.globallyUniqueId, groupingKey: self.groupingKey, groupInfo: self.groupInfo, threadId: self.threadId, timestamp: self.timestamp, flags: flags, tags: self.tags, globalTags: self.globalTags, localTags: self.localTags, forwardInfo: self.forwardInfo, author: self.author, text: self.text, attributes: self.attributes, media: self.media, peers: self.peers, associatedMessages: self.associatedMessages, associatedMessageIds: self.associatedMessageIds)
    }
    
    func withUpdatedGroupInfo(_ groupInfo: MessageGroupInfo?) -> Message {
        return Message(stableId: self.stableId, stableVersion: self.stableVersion, id: self.id, globallyUniqueId: self.globallyUniqueId, groupingKey: self.groupingKey, groupInfo: groupInfo, threadId: self.threadId, timestamp: self.timestamp, flags: self.flags, tags: self.tags, globalTags: self.globalTags, localTags: self.localTags, forwardInfo: self.forwardInfo, author: self.author, text: self.text, attributes: self.attributes, media: self.media, peers: self.peers, associatedMessages: self.associatedMessages, associatedMessageIds: self.associatedMessageIds)
    }
    
    public func withUpdatedAttributes(_ attributes: [MessageAttribute]) -> Message {
        return Message(stableId: self.stableId, stableVersion: self.stableVersion, id: self.id, globallyUniqueId: self.globallyUniqueId, groupingKey: self.groupingKey, groupInfo: self.groupInfo, threadId: self.threadId, timestamp: self.timestamp, flags: self.flags, tags: self.tags, globalTags: self.globalTags, localTags: self.localTags, forwardInfo: self.forwardInfo, author: self.author, text: self.text, attributes: attributes, media: self.media, peers: self.peers, associatedMessages: self.associatedMessages, associatedMessageIds: self.associatedMessageIds)
    }
    
    func withUpdatedAssociatedMessages(_ associatedMessages: SimpleDictionary<MessageId, Message>) -> Message {
        return Message(stableId: self.stableId, stableVersion: self.stableVersion, id: self.id, globallyUniqueId: self.globallyUniqueId, groupingKey: self.groupingKey, groupInfo: self.groupInfo, threadId: self.threadId, timestamp: self.timestamp, flags: self.flags, tags: self.tags, globalTags: self.globalTags, localTags: self.localTags, forwardInfo: self.forwardInfo, author: self.author, text: self.text, attributes: self.attributes, media: self.media, peers: self.peers, associatedMessages: associatedMessages, associatedMessageIds: self.associatedMessageIds)
    }
    
    public func withUpdatedForwardInfo(_ forwardInfo: MessageForwardInfo?) -> Message {
        return Message(stableId: self.stableId, stableVersion: self.stableVersion, id: self.id, globallyUniqueId: self.globallyUniqueId, groupingKey: self.groupingKey, groupInfo: self.groupInfo, threadId: self.threadId, timestamp: self.timestamp, flags: self.flags, tags: self.tags, globalTags: self.globalTags, localTags: self.localTags, forwardInfo: forwardInfo, author: self.author, text: self.text, attributes: self.attributes, media: self.media, peers: self.peers, associatedMessages: self.associatedMessages, associatedMessageIds: self.associatedMessageIds)
    }
    
    public func withUpdatedAuthor(_ author: Peer?) -> Message {
        return Message(stableId: self.stableId, stableVersion: self.stableVersion, id: self.id, globallyUniqueId: self.globallyUniqueId, groupingKey: self.groupingKey, groupInfo: self.groupInfo, threadId: self.threadId, timestamp: self.timestamp, flags: self.flags, tags: self.tags, globalTags: self.globalTags, localTags: self.localTags, forwardInfo: self.forwardInfo, author: author, text: self.text, attributes: self.attributes, media: self.media, peers: self.peers, associatedMessages: self.associatedMessages, associatedMessageIds: self.associatedMessageIds)
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
        
        if flags.contains(.TopIndexable) {
            rawValue |= StoreMessageFlags.TopIndexable.rawValue
        }
        
        if flags.contains(.Sending) {
            rawValue |= StoreMessageFlags.Sending.rawValue
        }
        
        if flags.contains(.CanBeGroupedIntoFeed) {
            rawValue |= StoreMessageFlags.CanBeGroupedIntoFeed.rawValue
        }
        
        if flags.contains(.WasScheduled) {
            rawValue |= StoreMessageFlags.WasScheduled.rawValue
        }
        
        if flags.contains(.CountedAsIncoming) {
            rawValue |= StoreMessageFlags.CountedAsIncoming.rawValue
        }
        
        if flags.contains(.CopyProtected) {
            rawValue |= StoreMessageFlags.CopyProtected.rawValue
        }
        
        self.rawValue = rawValue
    }
    
    public static let Unsent = StoreMessageFlags(rawValue: 1)
    public static let Failed = StoreMessageFlags(rawValue: 2)
    public static let Incoming = StoreMessageFlags(rawValue: 4)
    public static let TopIndexable = StoreMessageFlags(rawValue: 16)
    public static let Sending = StoreMessageFlags(rawValue: 32)
    public static let CanBeGroupedIntoFeed = StoreMessageFlags(rawValue: 64)
    public static let WasScheduled = StoreMessageFlags(rawValue: 128)
    public static let CountedAsIncoming = StoreMessageFlags(rawValue: 256)
    public static let CopyProtected = StoreMessageFlags(rawValue: 512)
    
    public static let IsIncomingMask = StoreMessageFlags([.Incoming, .CountedAsIncoming])
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
    
    public var namespace: MessageId.Namespace {
        switch self {
            case let .Id(id):
                return id.namespace
            case let .Partial(_, namespace):
                return namespace
        }
    }
}

public func makeMessageThreadId(_ messageId: MessageId) -> Int64 {
    return (Int64(messageId.namespace) << 32) | Int64(bitPattern: UInt64(UInt32(bitPattern: messageId.id)))
}

public func makeThreadIdMessageId(peerId: PeerId, threadId: Int64) -> MessageId {
    let namespace = Int32((threadId >> 32) & 0x7fffffff)
    let id = Int32(bitPattern: UInt32(threadId & 0xffffffff))
    return MessageId(peerId: peerId, namespace: namespace, id: id)
}

public final class StoreMessage {
    public let id: StoreMessageId
    public let timestamp: Int32
    public let globallyUniqueId: Int64?
    public let groupingKey: Int64?
    public let threadId: Int64?
    public let flags: StoreMessageFlags
    public let tags: MessageTags
    public let globalTags: GlobalMessageTags
    public let localTags: LocalMessageTags
    public let forwardInfo: StoreMessageForwardInfo?
    public let authorId: PeerId?
    public let text: String
    public let attributes: [MessageAttribute]
    public let media: [Media]
    
    public init(id: MessageId, globallyUniqueId: Int64?, groupingKey: Int64?, threadId: Int64?, timestamp: Int32, flags: StoreMessageFlags, tags: MessageTags, globalTags: GlobalMessageTags, localTags: LocalMessageTags, forwardInfo: StoreMessageForwardInfo?, authorId: PeerId?, text: String, attributes: [MessageAttribute], media: [Media]) {
        self.id = .Id(id)
        self.globallyUniqueId = globallyUniqueId
        self.groupingKey = groupingKey
        self.threadId = threadId
        self.timestamp = timestamp
        self.flags = flags
        self.tags = tags
        self.globalTags = globalTags
        self.localTags = localTags
        self.forwardInfo = forwardInfo
        self.authorId = authorId
        self.text = text
        self.attributes = attributes
        self.media = media
    }
    
    public init(peerId: PeerId, namespace: MessageId.Namespace, globallyUniqueId: Int64?, groupingKey: Int64?, threadId: Int64?, timestamp: Int32, flags: StoreMessageFlags, tags: MessageTags, globalTags: GlobalMessageTags, localTags: LocalMessageTags, forwardInfo: StoreMessageForwardInfo?, authorId: PeerId?, text: String, attributes: [MessageAttribute], media: [Media]) {
        self.id = .Partial(peerId, namespace)
        self.timestamp = timestamp
        self.globallyUniqueId = globallyUniqueId
        self.groupingKey = groupingKey
        self.threadId = threadId
        self.flags = flags
        self.tags = tags
        self.globalTags = globalTags
        self.localTags = localTags
        self.forwardInfo = forwardInfo
        self.authorId = authorId
        self.text = text
        self.attributes = attributes
        self.media = media
    }
    
    public init(id: StoreMessageId, globallyUniqueId: Int64?, groupingKey: Int64?, threadId: Int64?, timestamp: Int32, flags: StoreMessageFlags, tags: MessageTags, globalTags: GlobalMessageTags, localTags: LocalMessageTags, forwardInfo: StoreMessageForwardInfo?, authorId: PeerId?, text: String, attributes: [MessageAttribute], media: [Media]) {
        self.id = id
        self.timestamp = timestamp
        self.globallyUniqueId = globallyUniqueId
        self.groupingKey = groupingKey
        self.threadId = threadId
        self.flags = flags
        self.tags = tags
        self.globalTags = globalTags
        self.localTags = localTags
        self.forwardInfo = forwardInfo
        self.authorId = authorId
        self.text = text
        self.attributes = attributes
        self.media = media
    }
    
    public var index: MessageIndex? {
        if case let .Id(id) = self.id {
            return MessageIndex(id: id, timestamp: self.timestamp)
        } else {
            return nil
        }
    }
    
    public func withUpdatedFlags(_ flags: StoreMessageFlags) -> StoreMessage {
        if flags == self.flags {
            return self
        } else {
            return StoreMessage(id: self.id, globallyUniqueId: self.globallyUniqueId, groupingKey: self.groupingKey, threadId: self.threadId, timestamp: self.timestamp, flags: flags, tags: self.tags, globalTags: self.globalTags, localTags: self.localTags, forwardInfo: self.forwardInfo, authorId: self.authorId, text: self.text, attributes: attributes, media: self.media)
        }
    }
    
    public func withUpdatedAttributes(_ attributes: [MessageAttribute]) -> StoreMessage {
        return StoreMessage(id: self.id, globallyUniqueId: self.globallyUniqueId, groupingKey: self.groupingKey, threadId: self.threadId, timestamp: self.timestamp, flags: self.flags, tags: self.tags, globalTags: self.globalTags, localTags: self.localTags, forwardInfo: self.forwardInfo, authorId: self.authorId, text: self.text, attributes: attributes, media: self.media)
    }
    
    public func withUpdatedLocalTags(_ localTags: LocalMessageTags) -> StoreMessage {
        if localTags == self.localTags {
            return self
        } else {
            return StoreMessage(id: self.id, globallyUniqueId: self.globallyUniqueId, groupingKey: self.groupingKey, threadId: self.threadId, timestamp: self.timestamp, flags: self.flags, tags: self.tags, globalTags: self.globalTags, localTags: localTags, forwardInfo: self.forwardInfo, authorId: self.authorId, text: self.text, attributes: self.attributes, media: self.media)
        }
    }
}

final class InternalStoreMessage {
    let id: MessageId
    let timestamp: Int32
    let globallyUniqueId: Int64?
    let groupingKey: Int64?
    let threadId: Int64?
    let flags: StoreMessageFlags
    let tags: MessageTags
    let globalTags: GlobalMessageTags
    let localTags: LocalMessageTags
    let forwardInfo: StoreMessageForwardInfo?
    let authorId: PeerId?
    let text: String
    let attributes: [MessageAttribute]
    let media: [Media]
    
    var index: MessageIndex {
        return MessageIndex(id: self.id, timestamp: self.timestamp)
    }
    
    init(id: MessageId, timestamp: Int32, globallyUniqueId: Int64?, groupingKey: Int64?, threadId: Int64?, flags: StoreMessageFlags, tags: MessageTags, globalTags: GlobalMessageTags, localTags: LocalMessageTags, forwardInfo: StoreMessageForwardInfo?, authorId: PeerId?, text: String, attributes: [MessageAttribute], media: [Media]) {
        self.id = id
        self.timestamp = timestamp
        self.globallyUniqueId = globallyUniqueId
        self.groupingKey = groupingKey
        self.threadId = threadId
        self.flags = flags
        self.tags = tags
        self.globalTags = globalTags
        self.localTags = localTags
        self.forwardInfo = forwardInfo
        self.authorId = authorId
        self.text = text
        self.attributes = attributes
        self.media = media
    }
}

public enum MessageIdNamespaces {
    case all
    case just(Set<MessageId.Namespace>)
    case not(Set<MessageId.Namespace>)
    
    public func contains(_ namespace: MessageId.Namespace) -> Bool {
        switch self {
        case .all:
            return true
        case let .just(namespaces):
            return namespaces.contains(namespace)
        case let .not(namespaces):
            return !namespaces.contains(namespace)
        }
    }
}
