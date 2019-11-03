import Foundation
import Postbox

public final class ConsumePersonalMessageAction: PendingMessageActionData {
    public init() {
    }
    
    public init(decoder: PostboxDecoder) {
    }
    
    public func encode(_ encoder: PostboxEncoder) {
    }
    
    public func isEqual(to: PendingMessageActionData) -> Bool {
        if let _ = to as? ConsumePersonalMessageAction {
            return true
        } else {
            return false
        }
    }
}
