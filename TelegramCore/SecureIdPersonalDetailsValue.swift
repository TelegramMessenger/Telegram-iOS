import Foundation

public struct SecureIdPersonalDetailsValue: Equatable {
    public var firstName: String
    public var lastName: String
    public var birthdate: SecureIdDate
    public var countryCode: String
    public var residenceCountryCode: String
    public var gender: SecureIdGender
    
    public init(firstName: String, lastName: String, birthdate: SecureIdDate, countryCode: String, residenceCountryCode: String, gender: SecureIdGender) {
        self.firstName = firstName
        self.lastName = lastName
        self.birthdate = birthdate
        self.countryCode = countryCode
        self.residenceCountryCode = residenceCountryCode
        self.gender = gender
    }
    
    public static func ==(lhs: SecureIdPersonalDetailsValue, rhs: SecureIdPersonalDetailsValue) -> Bool {
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
        if lhs.residenceCountryCode != rhs.residenceCountryCode {
            return false
        }
        if lhs.gender != rhs.gender {
            return false
        }
        return true
    }
}

extension SecureIdPersonalDetailsValue {
    init?(dict: [String: Any], fileReferences: [SecureIdVerificationDocumentReference]) {
        guard let firstName = dict["first_name"] as? String else {
            return nil
        }
        guard let lastName = dict["last_name"] as? String else {
            return nil
        }
        guard let birthdate = (dict["birth_date"] as? String).flatMap(SecureIdDate.init) else {
            return nil
        }
        guard let gender = (dict["gender"] as? String).flatMap(SecureIdGender.init) else {
            return nil
        }
        guard let countryCode = dict["country_code"] as? String else {
            return nil
        }
        guard let residenceCountryCode = dict["residence_country_code"] as? String else {
            return nil
        }
        
        self.init(firstName: firstName, lastName: lastName, birthdate: birthdate, countryCode: countryCode, residenceCountryCode: residenceCountryCode, gender: gender)
    }
    
    func serialize() -> ([String: Any], [SecureIdVerificationDocumentReference]) {
        var dict: [String: Any] = [:]
        dict["first_name"] = self.firstName
        dict["last_name"] = self.lastName
        dict["birth_date"] = self.birthdate.serialize()
        dict["gender"] = self.gender.serialize()
        dict["country_code"] = self.countryCode
        dict["residenceCountryCode"] = self.residenceCountryCode
        
        return (dict, [])
    }
}
