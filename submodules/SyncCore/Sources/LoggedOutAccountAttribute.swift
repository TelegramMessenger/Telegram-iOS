import Foundation
import Postbox

public final class LoggedOutAccountAttribute: AccountRecordAttribute {
    public init() {
    }
    
    public init(decoder: PostboxDecoder) {
    }
    
    public func encode(_ encoder: PostboxEncoder) {
    }
    
    public func isEqual(to: AccountRecordAttribute) -> Bool {
        return to is LoggedOutAccountAttribute
    }
}
