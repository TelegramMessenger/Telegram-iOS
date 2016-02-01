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

public func <(lhs: MessageId, rhs: MessageId) -> Bool {
    if lhs.namespace == rhs.namespace {
        return lhs.id < rhs.id
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
    
    init(_ message: StoreMessage) {
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
        return MessageIndex(id: MessageId(peerId: self.id.peerId, namespace: self.id.namespace, id: self.id.id + 1), timestamp: self.timestamp)
    }
    
    public var hashValue: Int {
        return self.id.hashValue
    }
    
    static func upperBound(peerId: PeerId) -> MessageIndex {
        return MessageIndex(id: MessageId(peerId: peerId, namespace: Int32.max, id: Int32.max), timestamp: Int32.max)
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

public class Message {
    public let id: MessageId
    public let timestamp: Int32
    public let author: Peer?
    public let text: String
    public let attributes: [Coding]
    public let media: [Media]
    public let peers: SimpleDictionary<PeerId, Peer>
    
    init(id: MessageId, timestamp: Int32, author: Peer?, text: String, attributes: [Coding], media: [Media], peers: SimpleDictionary<PeerId, Peer>) {
        self.id = id
        self.timestamp = timestamp
        self.author = author
        self.text = text
        self.attributes = attributes
        self.media = media
        self.peers = peers
    }
}

public final class StoreMessage {
    public let id: MessageId
    public let timestamp: Int32
    public let authorId: PeerId?
    public let text: String
    public let attributes: [Coding]
    public let media: [Media]
    
    public init(id: MessageId, timestamp: Int32, authorId: PeerId?, text: String, attributes: [Coding], media: [Media]) {
        self.id = id
        self.authorId = authorId
        self.timestamp = timestamp
        self.text = text
        self.attributes = attributes
        self.media = media
    }
}

class IntermediateMessage {
    let id: MessageId
    let timestamp: Int32
    let authorId: PeerId?
    let text: String
    let attributesData: ReadBuffer
    let embeddedMediaData: ReadBuffer
    let referencedMedia: [MediaId]
    
    init(id: MessageId, timestamp: Int32, authorId: PeerId?, text: String, attributesData: ReadBuffer, embeddedMediaData: ReadBuffer, referencedMedia: [MediaId]) {
        self.id = id
        self.timestamp = timestamp
        self.authorId = authorId
        self.text = text
        self.attributesData = attributesData
        self.embeddedMediaData = embeddedMediaData
        self.referencedMedia = referencedMedia
    }
}
