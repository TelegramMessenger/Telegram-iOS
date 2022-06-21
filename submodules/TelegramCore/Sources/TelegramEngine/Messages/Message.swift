import Postbox

public final class EngineMessage {
    public typealias Id = MessageId
    public typealias Index = MessageIndex
    public typealias Tags = MessageTags
    public typealias Attribute = MessageAttribute
    public typealias GroupInfo = MessageGroupInfo
    public typealias Flags = MessageFlags
    public typealias GlobalTags = GlobalMessageTags
    public typealias LocalTags = LocalMessageTags
    public typealias ForwardInfo = MessageForwardInfo

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
    public var groupInfo: GroupInfo? {
        return self.impl.groupInfo
    }
    public var threadId: Int64? {
        return self.impl.threadId
    }
    public var timestamp: Int32 {
        return self.impl.timestamp
    }
    public var flags: Flags {
        return self.impl.flags
    }
    public var tags: Tags {
        return self.impl.tags
    }
    public var globalTags: GlobalTags {
        return self.impl.globalTags
    }
    public var localTags: LocalTags {
        return self.impl.localTags
    }
    public var forwardInfo: ForwardInfo? {
        return self.impl.forwardInfo
    }
    public var author: EnginePeer? {
        return self.impl.author.flatMap(EnginePeer.init)
    }
    public var text: String {
        return self.impl.text
    }
    public var attributes: [Attribute] {
        return self.impl.attributes
    }
    public var media: [Media] {
        return self.impl.media
    }
    public var peers: SimpleDictionary<EnginePeer.Id, Peer> {
        return self.impl.peers
    }
    public var associatedMessages: SimpleDictionary<EngineMessage.Id, Message> {
        return self.impl.associatedMessages
    }
    public var associatedMessageIds: [EngineMessage.Id] {
        return self.impl.associatedMessageIds
    }
    
    public var index: MessageIndex {
        return self.impl.index
    }

    public init(
        stableId: UInt32,
        stableVersion: UInt32,
        id: EngineMessage.Id,
        globallyUniqueId: Int64?,
        groupingKey: Int64?,
        groupInfo: EngineMessage.GroupInfo?,
        threadId: Int64?,
        timestamp: Int32,
        flags: EngineMessage.Flags,
        tags: EngineMessage.Tags,
        globalTags: EngineMessage.GlobalTags,
        localTags: EngineMessage.LocalTags,
        forwardInfo: EngineMessage.ForwardInfo?,
        author: EnginePeer?,
        text: String,
        attributes: [Attribute],
        media: [EngineMedia],
        peers: [EnginePeer.Id: EnginePeer],
        associatedMessages: [EngineMessage.Id: EngineMessage],
        associatedMessageIds: [EngineMessage.Id]
    ) {
        var mappedPeers: [PeerId: Peer] = [:]
        for (id, peer) in peers {
            mappedPeers[id] = peer._asPeer()
        }

        var mappedAssociatedMessages: [MessageId: Message] = [:]
        for (id, message) in associatedMessages {
            mappedAssociatedMessages[id] = message._asMessage()
        }

        self.impl = Message(
            stableId: stableId,
            stableVersion: stableVersion,
            id: id,
            globallyUniqueId: globallyUniqueId,
            groupingKey: groupingKey,
            groupInfo: groupInfo,
            threadId: threadId,
            timestamp: timestamp,
            flags: flags,
            tags: tags,
            globalTags: globalTags,
            localTags: localTags,
            forwardInfo: forwardInfo,
            author: author?._asPeer(),
            text: text,
            attributes: attributes,
            media: media.map { $0._asMedia() },
            peers: SimpleDictionary(mappedPeers),
            associatedMessages: SimpleDictionary(mappedAssociatedMessages),
            associatedMessageIds: associatedMessageIds
        )
    }

    public init(_ impl: Message) {
        self.impl = impl
    }

    public func _asMessage() -> Message {
        return self.impl
    }
}
