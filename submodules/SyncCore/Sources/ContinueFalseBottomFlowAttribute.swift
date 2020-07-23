import Foundation
import Postbox

public final class ContinueFalseBottomFlowAttribute: AccountRecordAttribute {
    public let accountRecordId: AccountRecordId
    
    public init(accountRecordId: AccountRecordId) {
        self.accountRecordId = accountRecordId
    }
    
    public init(decoder: PostboxDecoder) {
        let rawValue = decoder.decodeOptionalInt64ForKey("i")!
        self.accountRecordId = AccountRecordId(rawValue: rawValue)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(accountRecordId.int64, forKey: "i")
    }
    
    public func isEqual(to: AccountRecordAttribute) -> Bool {
        return to is ContinueFalseBottomFlowAttribute
    }
}
