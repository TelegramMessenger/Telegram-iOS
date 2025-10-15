import Foundation

public struct SecureIdPhoneValue: Equatable {
    public let phone: String
    
    public init(phone: String) {
        self.phone = phone
    }
    
    public static func ==(lhs: SecureIdPhoneValue, rhs: SecureIdPhoneValue) -> Bool {
        if lhs.phone != rhs.phone {
            return false
        }
        return true
    }
}
