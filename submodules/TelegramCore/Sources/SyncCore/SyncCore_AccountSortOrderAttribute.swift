import Foundation
import Postbox

public final class AccountSortOrderAttribute: AccountRecordAttribute {
    public let order: Int32
    
    public init(order: Int32) {
        self.order = order
    }
    
    public init(decoder: PostboxDecoder) {
        self.order = decoder.decodeInt32ForKey("order", orElse: 0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.order, forKey: "order")
    }
    
    public func isEqual(to: AccountRecordAttribute) -> Bool {
        guard let to = to as? AccountSortOrderAttribute else {
            return false
        }
        if self.order != to.order {
            return false
        }
        return true
    }
}
