import Postbox

public final class SendScheduledMessageImmediatelyAction: PendingMessageActionData {
    public init() {
    }
    
    public init(decoder: PostboxDecoder) {
    }
    
    public func encode(_ encoder: PostboxEncoder) {
    }
    
    public func isEqual(to: PendingMessageActionData) -> Bool {
        if let _ = to as? SendScheduledMessageImmediatelyAction {
            return true
        } else {
            return false
        }
    }
}
