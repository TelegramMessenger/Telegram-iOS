import Postbox

public final class UpdateMessageReactionsAction: PendingMessageActionData {
    public init() {
    }
    
    public init(decoder: PostboxDecoder) {
    }
    
    public func encode(_ encoder: PostboxEncoder) {
    }
    
    public func isEqual(to: PendingMessageActionData) -> Bool {
        if let _ = to as? UpdateMessageReactionsAction {
            return true
        } else {
            return false
        }
    }
}

public final class SendStarsReactionsAction: PendingMessageActionData {
    public let randomId: Int64
    
    public init(randomId: Int64) {
        self.randomId = randomId
    }
    
    public init(decoder: PostboxDecoder) {
        self.randomId = decoder.decodeInt64ForKey("id", orElse: 0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.randomId, forKey: "id")
    }
    
    public func isEqual(to: PendingMessageActionData) -> Bool {
        if let other = to as? SendStarsReactionsAction {
            if self.randomId != other.randomId {
                return false
            }
            return true
        } else {
            return false
        }
    }
}
