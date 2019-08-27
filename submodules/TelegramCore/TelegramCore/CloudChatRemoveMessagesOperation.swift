import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

enum CloudChatRemoveMessagesType: Int32 {
    case forLocalPeer
    case forEveryone
}

extension CloudChatRemoveMessagesType {
    init(_ type: InteractiveMessagesDeletionType) {
        switch type {
            case .forLocalPeer:
                self = .forLocalPeer
            case .forEveryone:
                self = .forEveryone
        }
    }
}

final class CloudChatRemoveMessagesOperation: PostboxCoding {
    let messageIds: [MessageId]
    let type: CloudChatRemoveMessagesType
    
    init(messageIds: [MessageId], type: CloudChatRemoveMessagesType) {
        self.messageIds = messageIds
        self.type = type
    }
    
    init(decoder: PostboxDecoder) {
        self.messageIds = MessageId.decodeArrayFromBuffer(decoder.decodeBytesForKeyNoCopy("i")!)
        self.type = CloudChatRemoveMessagesType(rawValue: decoder.decodeInt32ForKey("t", orElse: 0))!
    }
    
    func encode(_ encoder: PostboxEncoder) {
        let buffer = WriteBuffer()
        MessageId.encodeArrayToBuffer(self.messageIds, buffer: buffer)
        encoder.encodeBytes(buffer, forKey: "i")
        encoder.encodeInt32(self.type.rawValue, forKey: "t")
    }
}

final class CloudChatRemoveChatOperation: PostboxCoding {
    let peerId: PeerId
    let reportChatSpam: Bool
    let deleteGloballyIfPossible: Bool
    let topMessageId: MessageId?
    
    init(peerId: PeerId, reportChatSpam: Bool, deleteGloballyIfPossible: Bool, topMessageId: MessageId?) {
        self.peerId = peerId
        self.reportChatSpam = reportChatSpam
        self.deleteGloballyIfPossible = deleteGloballyIfPossible
        self.topMessageId = topMessageId
    }
    
    init(decoder: PostboxDecoder) {
        self.peerId = PeerId(decoder.decodeInt64ForKey("p", orElse: 0))
        self.reportChatSpam = decoder.decodeInt32ForKey("r", orElse: 0) != 0
        self.deleteGloballyIfPossible = decoder.decodeInt32ForKey("deleteGloballyIfPossible", orElse: 0) != 0
        if let messageIdPeerId = decoder.decodeOptionalInt64ForKey("m.p"), let messageIdNamespace = decoder.decodeOptionalInt32ForKey("m.n"), let messageIdId = decoder.decodeOptionalInt32ForKey("m.i") {
            self.topMessageId = MessageId(peerId: PeerId(messageIdPeerId), namespace: messageIdNamespace, id: messageIdId)
        } else {
            self.topMessageId = nil
        }
    }
    
    func encode(_ encoder: PostboxEncoder) {
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

enum CloudChatClearHistoryType: Int32 {
    case forLocalPeer
    case forEveryone
    case scheduledMessages
}

extension CloudChatClearHistoryType {
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

final class CloudChatClearHistoryOperation: PostboxCoding {
    let peerId: PeerId
    let topMessageId: MessageId
    let type: CloudChatClearHistoryType
    
    init(peerId: PeerId, topMessageId: MessageId, type: CloudChatClearHistoryType) {
        self.peerId = peerId
        self.topMessageId = topMessageId
        self.type = type
    }
    
    init(decoder: PostboxDecoder) {
        self.peerId = PeerId(decoder.decodeInt64ForKey("p", orElse: 0))
        self.topMessageId = MessageId(peerId: PeerId(decoder.decodeInt64ForKey("m.p", orElse: 0)), namespace: decoder.decodeInt32ForKey("m.n", orElse: 0), id: decoder.decodeInt32ForKey("m.i", orElse: 0))
        self.type = CloudChatClearHistoryType(rawValue: decoder.decodeInt32ForKey("type", orElse: 0)) ?? .forLocalPeer
    }
    
    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.peerId.toInt64(), forKey: "p")
        encoder.encodeInt64(self.topMessageId.peerId.toInt64(), forKey: "m.p")
        encoder.encodeInt32(self.topMessageId.namespace, forKey: "m.n")
        encoder.encodeInt32(self.topMessageId.id, forKey: "m.i")
        encoder.encodeInt32(self.type.rawValue, forKey: "type")
    }
}

func cloudChatAddRemoveMessagesOperation(transaction: Transaction, peerId: PeerId, messageIds: [MessageId], type: CloudChatRemoveMessagesType) {
    transaction.operationLogAddEntry(peerId: peerId, tag: OperationLogTags.CloudChatRemoveMessages, tagLocalIndex: .automatic, tagMergedIndex: .automatic, contents: CloudChatRemoveMessagesOperation(messageIds: messageIds, type: type))
}

func cloudChatAddRemoveChatOperation(transaction: Transaction, peerId: PeerId, reportChatSpam: Bool, deleteGloballyIfPossible: Bool) {
    transaction.operationLogAddEntry(peerId: peerId, tag: OperationLogTags.CloudChatRemoveMessages, tagLocalIndex: .automatic, tagMergedIndex: .automatic, contents: CloudChatRemoveChatOperation(peerId: peerId, reportChatSpam: reportChatSpam, deleteGloballyIfPossible: deleteGloballyIfPossible, topMessageId: transaction.getTopPeerMessageId(peerId: peerId, namespace: Namespaces.Message.Cloud)))
}

func cloudChatAddClearHistoryOperation(transaction: Transaction, peerId: PeerId, explicitTopMessageId: MessageId?, type: CloudChatClearHistoryType) {
    if type == .scheduledMessages {
        var messageIds: [MessageId] = []
        transaction.withAllMessages(peerId: peerId, namespace: Namespaces.Message.ScheduledCloud) { message -> Bool in
            messageIds.append(message.id)
            return true
        }
        cloudChatAddRemoveMessagesOperation(transaction: transaction, peerId: peerId, messageIds: messageIds, type: .forLocalPeer)
    } else {
        let topMessageId: MessageId?
        if let explicitTopMessageId = explicitTopMessageId {
            topMessageId = explicitTopMessageId
        } else {
            topMessageId = transaction.getTopPeerMessageId(peerId: peerId, namespace: Namespaces.Message.Cloud)
        }
        if let topMessageId = topMessageId {
            transaction.operationLogAddEntry(peerId: peerId, tag: OperationLogTags.CloudChatRemoveMessages, tagLocalIndex: .automatic, tagMergedIndex: .automatic, contents: CloudChatClearHistoryOperation(peerId: peerId, topMessageId: topMessageId, type: type))
        }
    }
}
