import Foundation

public struct SecureIdIdentityField: Equatable {
    public var passport: SecureIdPassportIdentity?
    
    public init(passport: SecureIdPassportIdentity?) {
        self.passport = passport
    }
    
    public static func ==(lhs: SecureIdIdentityField, rhs: SecureIdIdentityField) -> Bool {
        if lhs.passport != rhs.passport {
            return false
        }
        return true
    }
}
