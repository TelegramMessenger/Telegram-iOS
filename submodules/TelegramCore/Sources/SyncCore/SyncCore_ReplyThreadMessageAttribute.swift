import Foundation
import Postbox

public class ReplyThreadMessageAttribute: MessageAttribute {
    public let count: Int32
    public let latestUsers: [PeerId]
    public let commentsPeerId: PeerId?
    public let maxMessageId: MessageId.Id?
    public let maxReadMessageId: MessageId.Id?
    
    public var associatedPeerIds: [PeerId] {
        return self.latestUsers
    }
    
    public init(count: Int32, latestUsers: [PeerId], commentsPeerId: PeerId?, maxMessageId: MessageId.Id?, maxReadMessageId: MessageId.Id?) {
        self.count = count
        self.latestUsers = latestUsers
        self.commentsPeerId = commentsPeerId
        self.maxMessageId = maxMessageId
        self.maxReadMessageId = maxReadMessageId
    }
    
    required public init(decoder: PostboxDecoder) {
        self.count = decoder.decodeInt32ForKey("c", orElse: 0)
        self.latestUsers = decoder.decodeInt64ArrayForKey("u").map(PeerId.init)
        self.commentsPeerId = decoder.decodeOptionalInt64ForKey("cp").flatMap(PeerId.init)
        self.maxMessageId = decoder.decodeOptionalInt32ForKey("mm")
        self.maxReadMessageId = decoder.decodeOptionalInt32ForKey("mrm")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.count, forKey: "c")
        encoder.encodeInt64Array(self.latestUsers.map { $0.toInt64() }, forKey: "u")
        if let commentsPeerId = self.commentsPeerId {
            encoder.encodeInt64(commentsPeerId.toInt64(), forKey: "cp")
        } else {
            encoder.encodeNil(forKey: "cp")
        }
        if let maxMessageId = self.maxMessageId {
            encoder.encodeInt32(maxMessageId, forKey: "mm")
        } else {
            encoder.encodeNil(forKey: "mm")
        }
        if let maxReadMessageId = self.maxReadMessageId {
            encoder.encodeInt32(maxReadMessageId, forKey: "mrm")
        } else {
            encoder.encodeNil(forKey: "mrm")
        }
    }
}
