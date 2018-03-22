import Foundation

public struct SecureIdEmailField: Equatable {
    public let rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
    
    public static func ==(lhs: SecureIdEmailField, rhs: SecureIdEmailField) -> Bool {
        if lhs.rawValue != rhs.rawValue {
            return false
        }
        return true
    }
}
