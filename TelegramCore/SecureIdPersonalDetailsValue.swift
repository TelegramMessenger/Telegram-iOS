import Foundation

public struct SecureIdPersonalDetailsValue: Equatable {
    public var firstName: String
    public var middleName: String
    public var lastName: String
    public var birthdate: SecureIdDate
    public var countryCode: String
    public var residenceCountryCode: String
    public var gender: SecureIdGender
    
    public init(firstName: String, middleName: String, lastName: String, birthdate: SecureIdDate, countryCode: String, residenceCountryCode: String, gender: SecureIdGender) {
        self.firstName = firstName
        self.middleName = middleName
        self.lastName = lastName
        self.birthdate = birthdate
        self.countryCode = countryCode
        self.residenceCountryCode = residenceCountryCode
        self.gender = gender
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
        let middleName = dict["middle_name"] as? String ?? ""
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
        
        self.init(firstName: firstName, middleName: middleName, lastName: lastName, birthdate: birthdate, countryCode: countryCode, residenceCountryCode: residenceCountryCode, gender: gender)
    }
    
    func serialize() -> ([String: Any], [SecureIdVerificationDocumentReference]) {
        var dict: [String: Any] = [:]
        dict["first_name"] = self.firstName
        if !self.middleName.isEmpty {
            dict["middle_name"] = self.middleName
        }
        dict["last_name"] = self.lastName
        dict["birth_date"] = self.birthdate.serialize()
        dict["gender"] = self.gender.serialize()
        dict["country_code"] = self.countryCode
        dict["residence_country_code"] = self.residenceCountryCode
        
        return (dict, [])
    }
}
