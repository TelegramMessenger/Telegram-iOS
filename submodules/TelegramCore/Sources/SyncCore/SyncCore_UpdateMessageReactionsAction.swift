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
