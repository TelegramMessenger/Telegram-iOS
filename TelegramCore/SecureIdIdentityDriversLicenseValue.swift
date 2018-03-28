import Foundation

public struct SecureIdIdentityDriversLicenseValue: Equatable {
    public var identifier: String
    public var firstName: String
    public var lastName: String
    public var birthdate: SecureIdDate
    public var countryCode: String
    public var gender: SecureIdGender
    public var issueDate: SecureIdDate
    public var expiryDate: SecureIdDate?
    public var verificationDocuments: [SecureIdVerificationDocumentReference]
    
    public init(identifier: String, firstName: String, lastName: String, birthdate: SecureIdDate, countryCode: String, gender: SecureIdGender, issueDate: SecureIdDate, expiryDate: SecureIdDate?, verificationDocuments: [SecureIdVerificationDocumentReference]) {
        self.identifier = identifier
        self.firstName = firstName
        self.lastName = lastName
        self.birthdate = birthdate
        self.countryCode = countryCode
        self.gender = gender
        self.issueDate = issueDate
        self.expiryDate = expiryDate
        self.verificationDocuments = verificationDocuments
    }
    
    public static func ==(lhs: SecureIdIdentityDriversLicenseValue, rhs: SecureIdIdentityDriversLicenseValue) -> Bool {
        if lhs.identifier != rhs.identifier {
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
        if lhs.issueDate != rhs.issueDate {
            return false
        }
        if lhs.expiryDate != rhs.expiryDate {
            return false
        }
        if lhs.verificationDocuments != rhs.verificationDocuments {
            return false
        }
        return true
    }
}

extension SecureIdIdentityDriversLicenseValue {
    init?(dict: [String: Any], fileReferences: [SecureIdVerificationDocumentReference]) {
        guard let identifier = dict["document_no"] as? String else {
            return nil
        }
        guard let firstName = dict["first_name"] as? String else {
            return nil
        }
        guard let lastName = dict["last_name"] as? String else {
            return nil
        }
        guard let birthdate = (dict["date_of_birth"] as? String).flatMap(SecureIdDate.init) else {
            return nil
        }
        guard let gender = (dict["gender"] as? String).flatMap(SecureIdGender.init) else {
            return nil
        }
        guard let countryCode = dict["country_code"] as? String else {
            return nil
        }
        guard let issueDate = (dict["issue_date"] as? String).flatMap(SecureIdDate.init) else {
            return nil
        }
        let expiryDate = (dict["expiry_date"] as? String).flatMap(SecureIdDate.init)
        
        let verificationDocuments: [SecureIdVerificationDocumentReference] = fileReferences
        
        self.init(identifier: identifier, firstName: firstName, lastName: lastName, birthdate: birthdate, countryCode: countryCode, gender: gender, issueDate: issueDate, expiryDate: expiryDate, verificationDocuments: verificationDocuments)
    }
    
    func serialize() -> ([String: Any], [SecureIdVerificationDocumentReference]) {
        var dict: [String: Any] = [:]
        dict["document_no"] = self.identifier
        dict["first_name"] = self.firstName
        dict["last_name"] = self.lastName
        dict["date_of_birth"] = self.birthdate.serialize()
        dict["gender"] = self.gender.serialize()
        dict["country_code"] = self.countryCode
        dict["issue_date"] = self.issueDate.serialize()
        if let expiryDate = self.expiryDate {
            dict["expiry_date"] = expiryDate.serialize()
        }
        
        return (dict, self.verificationDocuments)
    }
}

