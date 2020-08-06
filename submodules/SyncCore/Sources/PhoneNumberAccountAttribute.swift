import Foundation
import Postbox

public final class PhoneNumberAccountAttribute: AccountRecordAttribute {
    public let phoneNumber: String
    
    public init(phoneNumber: String) {
        self.phoneNumber = phoneNumber
    }
    
    public init(decoder: PostboxDecoder) {
        self.phoneNumber = decoder.decodeStringForKey("n", orElse: "")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(phoneNumber, forKey: "n")
    }
    
    public func isEqual(to: AccountRecordAttribute) -> Bool {
        guard let to = to as? PhoneNumberAccountAttribute else {
            return false
        }
        if self.phoneNumber != to.phoneNumber {
            return false
        }
        return true
    }
}
