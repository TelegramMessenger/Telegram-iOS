import Foundation

struct IntermediateMessageForwardInfo {
    let authorId: PeerId?
    let sourceId: PeerId?
    let sourceMessageId: MessageId?
    let date: Int32
    let authorSignature: String?
    let psaType: String?
    let flags: MessageForwardInfo.Flags
    
    init(authorId: PeerId?, sourceId: PeerId?, sourceMessageId: MessageId?, date: Int32, authorSignature: String?, psaType: String?, flags: MessageForwardInfo.Flags) {
        self.authorId = authorId
        self.sourceId = sourceId
        self.sourceMessageId = sourceMessageId
        self.date = date
        self.authorSignature = authorSignature
        self.psaType = psaType
        self.flags = flags
    }
    
    init(_ storeInfo: StoreMessageForwardInfo) {
        self.authorId = storeInfo.authorId
        self.sourceId = storeInfo.sourceId
        self.sourceMessageId = storeInfo.sourceMessageId
        self.date = storeInfo.date
        self.authorSignature = storeInfo.authorSignature
        self.psaType = storeInfo.psaType
        self.flags = storeInfo.flags
    }
}

class IntermediateMessage {
    let stableId: UInt32
    let stableVersion: UInt32
    let id: MessageId
    let globallyUniqueId: Int64?
    let groupingKey: Int64?
    let groupInfo: MessageGroupInfo?
    let threadId: Int64?
    let timestamp: Int32
    let flags: MessageFlags
    let tags: MessageTags
    let globalTags: GlobalMessageTags
    let localTags: LocalMessageTags
    let forwardInfo: IntermediateMessageForwardInfo?
    let authorId: PeerId?
    let text: String
    let attributesData: ReadBuffer
    let embeddedMediaData: ReadBuffer
    let referencedMedia: [MediaId]
    
    var index: MessageIndex {
        return MessageIndex(id: self.id, timestamp: self.timestamp)
    }
    
    init(stableId: UInt32, stableVersion: UInt32, id: MessageId, globallyUniqueId: Int64?, groupingKey: Int64?, groupInfo: MessageGroupInfo?, threadId: Int64?, timestamp: Int32, flags: MessageFlags, tags: MessageTags, globalTags: GlobalMessageTags, localTags: LocalMessageTags, forwardInfo: IntermediateMessageForwardInfo?, authorId: PeerId?, text: String, attributesData: ReadBuffer, embeddedMediaData: ReadBuffer, referencedMedia: [MediaId]) {
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
        self.authorId = authorId
        self.text = text
        self.attributesData = attributesData
        self.embeddedMediaData = embeddedMediaData
        self.referencedMedia = referencedMedia
    }
    
    func withUpdatedTimestamp(_ timestamp: Int32) -> IntermediateMessage {
        return IntermediateMessage(stableId: self.stableId, stableVersion: self.stableVersion, id: self.id, globallyUniqueId: self.globallyUniqueId, groupingKey: self.groupingKey, groupInfo: self.groupInfo, threadId: self.threadId, timestamp: timestamp, flags: self.flags, tags: self.tags, globalTags: self.globalTags, localTags: self.localTags, forwardInfo: self.forwardInfo, authorId: self.authorId, text: self.text, attributesData: self.attributesData, embeddedMediaData: self.embeddedMediaData, referencedMedia: self.referencedMedia)
    }
    
    func withUpdatedGroupingKey(_ groupingKey: Int64?) -> IntermediateMessage {
        return IntermediateMessage(stableId: self.stableId, stableVersion: self.stableVersion, id: self.id, globallyUniqueId: self.globallyUniqueId, groupingKey: groupingKey, groupInfo: self.groupInfo, threadId: self.threadId, timestamp: self.timestamp, flags: self.flags, tags: self.tags, globalTags: self.globalTags, localTags: self.localTags, forwardInfo: self.forwardInfo, authorId: self.authorId, text: self.text, attributesData: self.attributesData, embeddedMediaData: self.embeddedMediaData, referencedMedia: self.referencedMedia)
    }
    
    func withUpdatedGroupInfo(_ groupInfo: MessageGroupInfo?) -> IntermediateMessage {
        return IntermediateMessage(stableId: self.stableId, stableVersion: self.stableVersion, id: self.id, globallyUniqueId: self.globallyUniqueId, groupingKey: self.groupingKey, groupInfo: groupInfo, threadId: self.threadId, timestamp: self.timestamp, flags: self.flags, tags: self.tags, globalTags: self.globalTags, localTags: self.localTags, forwardInfo: self.forwardInfo, authorId: self.authorId, text: self.text, attributesData: self.attributesData, embeddedMediaData: self.embeddedMediaData, referencedMedia: self.referencedMedia)
    }
    
    func withUpdatedEmbeddedMedia(_ embeddedMedia: ReadBuffer) -> IntermediateMessage {
        return IntermediateMessage(stableId: self.stableId, stableVersion: self.stableVersion, id: self.id, globallyUniqueId: self.globallyUniqueId, groupingKey: self.groupingKey, groupInfo: self.groupInfo, threadId: self.threadId, timestamp: self.timestamp, flags: self.flags, tags: self.tags, globalTags: self.globalTags, localTags: self.localTags, forwardInfo: self.forwardInfo, authorId: self.authorId, text: self.text, attributesData: self.attributesData, embeddedMediaData: embeddedMedia, referencedMedia: self.referencedMedia)
    }
}
