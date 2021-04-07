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
