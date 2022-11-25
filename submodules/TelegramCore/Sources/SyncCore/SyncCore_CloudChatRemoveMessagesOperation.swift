import Foundation
import Postbox

public enum InteractiveMessagesDeletionType: Int32 {
    case forLocalPeer = 0
    case forEveryone = 1
}

public enum CloudChatRemoveMessagesType: Int32 {
    case forLocalPeer
    case forEveryone
}

public extension CloudChatRemoveMessagesType {
    init(_ type: InteractiveMessagesDeletionType) {
        switch type {
            case .forLocalPeer:
                self = .forLocalPeer
            case .forEveryone:
                self = .forEveryone
        }
    }
}

public final class CloudChatRemoveMessagesOperation: PostboxCoding {
    public let messageIds: [MessageId]
    public let type: CloudChatRemoveMessagesType
    
    public init(messageIds: [MessageId], type: CloudChatRemoveMessagesType) {
        self.messageIds = messageIds
        self.type = type
    }
    
    public init(decoder: PostboxDecoder) {
        self.messageIds = MessageId.decodeArrayFromBuffer(decoder.decodeBytesForKeyNoCopy("i")!)
        self.type = CloudChatRemoveMessagesType(rawValue: decoder.decodeInt32ForKey("t", orElse: 0))!
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        let buffer = WriteBuffer()
        MessageId.encodeArrayToBuffer(self.messageIds, buffer: buffer)
        encoder.encodeBytes(buffer, forKey: "i")
        encoder.encodeInt32(self.type.rawValue, forKey: "t")
    }
}

public final class CloudChatRemoveChatOperation: PostboxCoding {
    public let peerId: PeerId
    public let reportChatSpam: Bool
    public let deleteGloballyIfPossible: Bool
    public let topMessageId: MessageId?
    
    public init(peerId: PeerId, reportChatSpam: Bool, deleteGloballyIfPossible: Bool, topMessageId: MessageId?) {
        self.peerId = peerId
        self.reportChatSpam = reportChatSpam
        self.deleteGloballyIfPossible = deleteGloballyIfPossible
        self.topMessageId = topMessageId
    }
    
    public init(decoder: PostboxDecoder) {
        self.peerId = PeerId(decoder.decodeInt64ForKey("p", orElse: 0))
        self.reportChatSpam = decoder.decodeInt32ForKey("r", orElse: 0) != 0
        self.deleteGloballyIfPossible = decoder.decodeInt32ForKey("deleteGloballyIfPossible", orElse: 0) != 0
        if let messageIdPeerId = decoder.decodeOptionalInt64ForKey("m.p"), let messageIdNamespace = decoder.decodeOptionalInt32ForKey("m.n"), let messageIdId = decoder.decodeOptionalInt32ForKey("m.i") {
            self.topMessageId = MessageId(peerId: PeerId(messageIdPeerId), namespace: messageIdNamespace, id: messageIdId)
        } else {
            self.topMessageId = nil
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.peerId.toInt64(), forKey: "p")
        encoder.encodeInt32(self.reportChatSpam ? 1 : 0, forKey: "r")
        encoder.encodeInt32(self.deleteGloballyIfPossible ? 1 : 0, forKey: "deleteGloballyIfPossible")
        if let topMessageId = self.topMessageId {
            encoder.encodeInt64(topMessageId.peerId.toInt64(), forKey: "m.p")
            encoder.encodeInt32(topMessageId.namespace, forKey: "m.n")
            encoder.encodeInt32(topMessageId.id, forKey: "m.i")
        } else {
            encoder.encodeNil(forKey: "m.p")
            encoder.encodeNil(forKey: "m.n")
            encoder.encodeNil(forKey: "m.i")
        }
    }
}

public enum CloudChatClearHistoryType: Int32 {
    case forLocalPeer
    case forEveryone
    case scheduledMessages
}

public enum InteractiveHistoryClearingType: Int32 {
    case forLocalPeer = 0
    case forEveryone = 1
    case scheduledMessages = 2
}

public extension CloudChatClearHistoryType {
    init(_ type: InteractiveHistoryClearingType) {
        switch type {
            case .forLocalPeer:
                self = .forLocalPeer
            case .forEveryone:
                self = .forEveryone
            case .scheduledMessages:
                self = .scheduledMessages
        }
    }
}

public final class CloudChatClearHistoryOperation: PostboxCoding {
    public let peerId: PeerId
    public let topMessageId: MessageId
    public let threadId: Int64?
    public let minTimestamp: Int32?
    public let maxTimestamp: Int32?
    public let type: CloudChatClearHistoryType
    
    public init(peerId: PeerId, topMessageId: MessageId, threadId: Int64?, minTimestamp: Int32?, maxTimestamp: Int32?, type: CloudChatClearHistoryType) {
        self.peerId = peerId
        self.topMessageId = topMessageId
        self.threadId = threadId
        self.minTimestamp = minTimestamp
        self.maxTimestamp = maxTimestamp
        self.type = type
    }
    
    public init(decoder: PostboxDecoder) {
        self.peerId = PeerId(decoder.decodeInt64ForKey("p", orElse: 0))
        self.topMessageId = MessageId(peerId: PeerId(decoder.decodeInt64ForKey("m.p", orElse: 0)), namespace: decoder.decodeInt32ForKey("m.n", orElse: 0), id: decoder.decodeInt32ForKey("m.i", orElse: 0))
        self.threadId = decoder.decodeOptionalInt64ForKey("threadId")
        self.minTimestamp = decoder.decodeOptionalInt32ForKey("minTimestamp")
        self.maxTimestamp = decoder.decodeOptionalInt32ForKey("maxTimestamp")
        self.type = CloudChatClearHistoryType(rawValue: decoder.decodeInt32ForKey("type", orElse: 0)) ?? .forLocalPeer
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.peerId.toInt64(), forKey: "p")
        encoder.encodeInt64(self.topMessageId.peerId.toInt64(), forKey: "m.p")
        encoder.encodeInt32(self.topMessageId.namespace, forKey: "m.n")
        encoder.encodeInt32(self.topMessageId.id, forKey: "m.i")
        if let threadId = self.threadId {
            encoder.encodeInt64(threadId, forKey: "threadId")
        } else {
            encoder.encodeNil(forKey: "threadId")
        }
        if let minTimestamp = self.minTimestamp {
            encoder.encodeInt32(minTimestamp, forKey: "minTimestamp")
        } else {
            encoder.encodeNil(forKey: "minTimestamp")
        }
        if let maxTimestamp = self.maxTimestamp {
            encoder.encodeInt32(maxTimestamp, forKey: "maxTimestamp")
        } else {
            encoder.encodeNil(forKey: "maxTimestamp")
        }
        encoder.encodeInt32(self.type.rawValue, forKey: "type")
    }
}
