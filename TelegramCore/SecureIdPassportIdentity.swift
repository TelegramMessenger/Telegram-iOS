import Foundation

public struct SecureIdPassportIdentity: Equatable {
    public var id: String
    public var firstName: String
    public var lastName: String
    public var birthdate: SecureIdDate
    public var countryCode: String
    public var gender: SecureIdGender
    
    public init(id: String, firstName: String, lastName: String, birthdate: SecureIdDate, countryCode: String, gender: SecureIdGender) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.birthdate = birthdate
        self.countryCode = countryCode
        self.gender = gender
    }
    
    public static func ==(lhs: SecureIdPassportIdentity, rhs: SecureIdPassportIdentity) -> Bool {
        if lhs.id != rhs.id {
            return false
        }
        if lhs.firstName != rhs.firstName {
            return false
        }
        if lhs.lastName != rhs.lastName {
            return false
        }
        if lhs.birthdate != rhs.birthdate {
            return false
        }
        if lhs.countryCode != rhs.countryCode {
            return false
        }
        if lhs.gender != rhs.gender {
            return false
        }
        return true
    }
}
