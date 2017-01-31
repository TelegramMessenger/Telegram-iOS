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

final class CloudChatRemoveMessagesOperation: Coding {
    let messageIds: [MessageId]
    let type: CloudChatRemoveMessagesType
    
    init(messageIds: [MessageId], type: CloudChatRemoveMessagesType) {
        self.messageIds = messageIds
        self.type = type
    }
    
    init(decoder: Decoder) {
        self.messageIds = MessageId.decodeArrayFromBuffer(decoder.decodeBytesForKeyNoCopy("i")!)
        self.type = CloudChatRemoveMessagesType(rawValue: decoder.decodeInt32ForKey("t"))!
    }
    
    func encode(_ encoder: Encoder) {
        let buffer = WriteBuffer()
        MessageId.encodeArrayToBuffer(self.messageIds, buffer: buffer)
        encoder.encodeBytes(buffer, forKey: "i")
        encoder.encodeInt32(self.type.rawValue, forKey: "t")
    }
}

final class CloudChatRemoveChatOperation: Coding {
    let peerId: PeerId
    
    init(peerId: PeerId) {
        self.peerId = peerId
    }
    
    init(decoder: Decoder) {
        self.peerId = PeerId(decoder.decodeInt64ForKey("p"))
    }
    
    func encode(_ encoder: Encoder) {
        encoder.encodeInt64(self.peerId.toInt64(), forKey: "p")
    }
}

func cloudChatAddRemoveMessagesOperation(modifier: Modifier, peerId: PeerId, messageIds: [MessageId], type: CloudChatRemoveMessagesType) {
    modifier.operationLogAddEntry(peerId: peerId, tag: OperationLogTags.CloudChatRemoveMessages, tagLocalIndex: .automatic, tagMergedIndex: .automatic, contents: CloudChatRemoveMessagesOperation(messageIds: messageIds, type: type))
}

func cloudChatAddRemoveChatOperation(modifier: Modifier, peerId: PeerId) {
    modifier.operationLogAddEntry(peerId: peerId, tag: OperationLogTags.CloudChatRemoveMessages, tagLocalIndex: .automatic, tagMergedIndex: .automatic, contents: CloudChatRemoveChatOperation(peerId: peerId))
}
