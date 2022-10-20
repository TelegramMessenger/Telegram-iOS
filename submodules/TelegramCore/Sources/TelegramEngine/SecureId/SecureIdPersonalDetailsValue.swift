import Foundation

public struct SecureIdPersonalDetailsValue: Equatable {
    public var latinName: SecureIdPersonName
    public var nativeName: SecureIdPersonName?
    public var birthdate: SecureIdDate
    public var countryCode: String
    public var residenceCountryCode: String
    public var gender: SecureIdGender
    
    public init(latinName: SecureIdPersonName, nativeName: SecureIdPersonName?, birthdate: SecureIdDate, countryCode: String, residenceCountryCode: String, gender: SecureIdGender) {
        self.latinName = latinName
        self.nativeName = nativeName
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
        
        var nativeName: SecureIdPersonName?
        if let nativeFirstName = dict["first_name_native"] as? String, let nativeLastName = dict["last_name_native"] as? String {
            nativeName = SecureIdPersonName(firstName: nativeFirstName, lastName: nativeLastName, middleName: dict["middle_name_native"] as? String ?? "")
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
        
        self.init(latinName: SecureIdPersonName(firstName: firstName, lastName: lastName, middleName: middleName), nativeName: nativeName, birthdate: birthdate, countryCode: countryCode, residenceCountryCode: residenceCountryCode, gender: gender)
    }
    
    func serialize() -> ([String: Any], [SecureIdVerificationDocumentReference]) {
        var dict: [String: Any] = [:]
        dict["first_name"] = self.latinName.firstName
        if !self.latinName.middleName.isEmpty {
            dict["middle_name"] = self.latinName.middleName
        }
        dict["last_name"] = self.latinName.lastName
        if let nativeName = self.nativeName {
            dict["first_name_native"] = nativeName.firstName
            if !nativeName.middleName.isEmpty {
                dict["middle_name_native"] = nativeName.middleName
            }
            dict["last_name_native"] = nativeName.lastName
        }
        dict["birth_date"] = self.birthdate.serialize()
        dict["gender"] = self.gender.serialize()
        dict["country_code"] = self.countryCode
        dict["residence_country_code"] = self.residenceCountryCode
        
        return (dict, [])
    }
}
