import Postbox

public final class EngineMessage {
    public typealias Id = MessageId
    public typealias Index = MessageIndex

    private let impl: Message

    public var stableId: UInt32 {
        return self.impl.stableId
    }
    
    public var stableVersion: UInt32 {
        return self.impl.stableVersion
    }
    
    public var id: Id {
        return self.impl.id
    }
    public var globallyUniqueId: Int64? {
        return self.impl.globallyUniqueId
    }
    public var groupingKey: Int64? {
        return self.impl.groupingKey
    }
    public var groupInfo: MessageGroupInfo? {
        return self.impl.groupInfo
    }
    public var threadId: Int64? {
        return self.impl.threadId
    }
    public var timestamp: Int32 {
        return self.impl.timestamp
    }
    public var flags: MessageFlags {
        return self.impl.flags
    }
    public var tags: MessageTags {
        return self.impl.tags
    }
    public var globalTags: GlobalMessageTags {
        return self.impl.globalTags
    }
    public var localTags: LocalMessageTags {
        return self.impl.localTags
    }
    public var forwardInfo: MessageForwardInfo? {
        return self.impl.forwardInfo
    }
    public var author: EnginePeer? {
        return self.impl.author.flatMap(EnginePeer.init)
    }
    public var text: String {
        return self.impl.text
    }
    public var attributes: [MessageAttribute] {
        return self.impl.attributes
    }
    public var media: [Media] {
        return self.impl.media
    }
    public var peers: SimpleDictionary<PeerId, Peer> {
        return self.impl.peers
    }
    public var associatedMessages: SimpleDictionary<MessageId, Message> {
        return self.impl.associatedMessages
    }
    public var associatedMessageIds: [MessageId] {
        return self.impl.associatedMessageIds
    }
    
    public var index: MessageIndex {
        return self.impl.index
    }

    public init(_ impl: Message) {
        self.impl = impl
    }

    public func _asMessage() -> Message {
        return self.impl
    }
}
