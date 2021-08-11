import Foundation
import Postbox

public struct SynchronizeableChatInputState: PostboxCoding, Equatable {
    public let replyToMessageId: MessageId?
    public let text: String
    public let entities: [MessageTextEntity]
    public let timestamp: Int32
    
    public init(replyToMessageId: MessageId?, text: String, entities: [MessageTextEntity], timestamp: Int32) {
        self.replyToMessageId = replyToMessageId
        self.text = text
        self.entities = entities
        self.timestamp = timestamp
    }
    
    public init(decoder: PostboxDecoder) {
        self.text = decoder.decodeStringForKey("t", orElse: "")
        self.entities = decoder.decodeObjectArrayWithDecoderForKey("e")
        self.timestamp = decoder.decodeInt32ForKey("s", orElse: 0)
        if let messageIdPeerId = decoder.decodeOptionalInt64ForKey("m.p"), let messageIdNamespace = decoder.decodeOptionalInt32ForKey("m.n"), let messageIdId = decoder.decodeOptionalInt32ForKey("m.i") {
            self.replyToMessageId = MessageId(peerId: PeerId(messageIdPeerId), namespace: messageIdNamespace, id: messageIdId)
        } else {
            self.replyToMessageId = nil
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.text, forKey: "t")
        encoder.encodeObjectArray(self.entities, forKey: "e")
        encoder.encodeInt32(self.timestamp, forKey: "s")
        if let replyToMessageId = self.replyToMessageId {
            encoder.encodeInt64(replyToMessageId.peerId.toInt64(), forKey: "m.p")
            encoder.encodeInt32(replyToMessageId.namespace, forKey: "m.n")
            encoder.encodeInt32(replyToMessageId.id, forKey: "m.i")
        } else {
            encoder.encodeNil(forKey: "m.p")
            encoder.encodeNil(forKey: "m.n")
            encoder.encodeNil(forKey: "m.i")
        }
    }
    
    public static func ==(lhs: SynchronizeableChatInputState, rhs: SynchronizeableChatInputState) -> Bool {
        if lhs.replyToMessageId != rhs.replyToMessageId {
            return false
        }
        if lhs.text != rhs.text {
            return false
        }
        if lhs.entities != rhs.entities {
            return false
        }
        if lhs.timestamp != rhs.timestamp {
            return false
        }
        return true
    }
}

public protocol SynchronizeableChatInterfaceState: PeerChatInterfaceState {
    var synchronizeableInputState: SynchronizeableChatInputState? { get }
    func withUpdatedSynchronizeableInputState(_ state: SynchronizeableChatInputState?) -> SynchronizeableChatInterfaceState
}
