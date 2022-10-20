import Foundation

public struct SecureIdEmailValue: Equatable {
    public let email: String
    
    public init(email: String) {
        self.email = email
    }
    
    public static func ==(lhs: SecureIdEmailValue, rhs: SecureIdEmailValue) -> Bool {
        if lhs.email != rhs.email {
            return false
        }
        return true
    }
}
