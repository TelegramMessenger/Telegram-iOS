import Postbox

public final class SynchronizeMarkAllUnseenPersonalMessagesOperation: PostboxCoding {
    public let maxId: MessageId.Id
    
    public init(maxId: MessageId.Id) {
        self.maxId = maxId
    }
    
    public init(decoder: PostboxDecoder) {
        self.maxId = decoder.decodeInt32ForKey("maxId", orElse: Int32.min + 1)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.maxId, forKey: "maxId")
    }
}

public final class SynchronizeMarkAllUnseenReactionsOperation: PostboxCoding {
    public let threadId: Int64?
    public let maxId: MessageId.Id
    
    public init(threadId: Int64?, maxId: MessageId.Id) {
        self.threadId = threadId
        self.maxId = maxId
    }
    
    public init(decoder: PostboxDecoder) {
        self.threadId = decoder.decodeOptionalInt64ForKey("threadId")
        self.maxId = decoder.decodeInt32ForKey("maxId", orElse: Int32.min + 1)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        if let threadId = self.threadId {
            encoder.encodeInt64(threadId, forKey: "threadId")
        } else {
            encoder.encodeNil(forKey: "threadId")
        }
        encoder.encodeInt32(self.maxId, forKey: "maxId")
    }
}
