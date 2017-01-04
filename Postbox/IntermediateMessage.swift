import Foundation

struct IntermediateMessageForwardInfo {
    let authorId: PeerId
    let sourceId: PeerId?
    let sourceMessageId: MessageId?
    let date: Int32
    
    init(authorId: PeerId, sourceId: PeerId?, sourceMessageId: MessageId?, date: Int32) {
        self.authorId = authorId
        self.sourceId = sourceId
        self.sourceMessageId = sourceMessageId
        self.date = date
    }
    
    init(_ storeInfo: StoreMessageForwardInfo) {
        self.authorId = storeInfo.authorId
        self.sourceId = storeInfo.sourceId
        self.sourceMessageId = storeInfo.sourceMessageId
        self.date = storeInfo.date
    }
}

class IntermediateMessage {
    let stableId: UInt32
    let stableVersion: UInt32
    let id: MessageId
    let globallyUniqueId: Int64?
    let timestamp: Int32
    let flags: MessageFlags
    let tags: MessageTags
    let forwardInfo: IntermediateMessageForwardInfo?
    let authorId: PeerId?
    let text: String
    let attributesData: ReadBuffer
    let embeddedMediaData: ReadBuffer
    let referencedMedia: [MediaId]
    
    init(stableId: UInt32, stableVersion: UInt32, id: MessageId, globallyUniqueId: Int64?, timestamp: Int32, flags: MessageFlags, tags: MessageTags, forwardInfo: IntermediateMessageForwardInfo?, authorId: PeerId?, text: String, attributesData: ReadBuffer, embeddedMediaData: ReadBuffer, referencedMedia: [MediaId]) {
        self.stableId = stableId
        self.stableVersion = stableVersion
        self.id = id
        self.globallyUniqueId = globallyUniqueId
        self.timestamp = timestamp
        self.flags = flags
        self.tags = tags
        self.forwardInfo = forwardInfo
        self.authorId = authorId
        self.text = text
        self.attributesData = attributesData
        self.embeddedMediaData = embeddedMediaData
        self.referencedMedia = referencedMedia
    }
}
