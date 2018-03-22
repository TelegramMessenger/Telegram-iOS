import Foundation

public struct SecureIdPhoneField: Equatable {
    public let rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
    
    public static func ==(lhs: SecureIdPhoneField, rhs: SecureIdPhoneField) -> Bool {
        if lhs.rawValue != rhs.rawValue {
            return false
        }
        return true
    }
}
