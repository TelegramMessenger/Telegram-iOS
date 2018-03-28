import Foundation

public enum SecureIdAddressValueType {
    case passportRegistration
    case utilityBill
    case bankStatement
    case rentalAgreement
}

public struct SecureIdAddressValue: Equatable {
    public var type: SecureIdAddressValueType
    public var street1: String
    public var street2: String
    public var city: String
    public var region: String
    public var countryCode: String
    public var postcode: String
    public var verificationDocuments: [SecureIdVerificationDocumentReference]
    
    public init(type: SecureIdAddressValueType, street1: String, street2: String, city: String, region: String, countryCode: String, postcode: String, verificationDocuments: [SecureIdVerificationDocumentReference]) {
        self.type = type
        self.street1 = street1
        self.street2 = street2
        self.city = city
        self.region = region
        self.countryCode = countryCode
        self.postcode = postcode
        self.verificationDocuments = verificationDocuments
    }
    
    public static func ==(lhs: SecureIdAddressValue, rhs: SecureIdAddressValue) -> Bool {
        if lhs.street1 != rhs.street1 {
            return false
        }
        if lhs.street2 != rhs.street2 {
            return false
        }
        if lhs.city != rhs.city {
            return false
        }
        if lhs.region != rhs.region {
            return false
        }
        if lhs.countryCode != rhs.countryCode {
            return false
        }
        if lhs.postcode != rhs.postcode {
            return false
        }
        if lhs.verificationDocuments != rhs.verificationDocuments {
            return false
        }
        return true
    }
}

private extension SecureIdAddressValueType {
    init?(serializedString: String) {
        switch serializedString {
            case "passport_registration":
                self = .passportRegistration
            case "utility_bill":
                self = .utilityBill
            case "bank_statement":
                self = .bankStatement
            case "rental_agreement":
                self = .rentalAgreement
            default:
                return nil
        }
    }
    
    func serialize() -> String {
        switch self {
            case .passportRegistration:
                return "passport_registration"
            case .utilityBill:
                return "utility_bill"
            case .bankStatement:
                return "bank_statement"
            case .rentalAgreement:
                return "rental_agreement"
        }
    }
}

extension SecureIdAddressValue {
    init?(data: Data, fileReferences: [SecureIdVerificationDocumentReference]) {
        guard let dict = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any] else {
            return nil
        }
        
        guard let documentTypeString = dict["document_type"] as? String, let type = SecureIdAddressValueType(serializedString: documentTypeString) else {
            return nil
        }
        guard let street1 = dict["street_line1"] as? String else {
            return nil
        }
        let street2 = (dict["street_line2"] as? String) ?? ""
        guard let city = dict["city"] as? String else {
            return nil
        }
        guard let region = dict["region"] as? String else {
            return nil
        }
        guard let countryCode = dict["country_code"] as? String else {
            return nil
        }
        guard let postcode = dict["postcode"] as? String else {
            return nil
        }
        
        let verificationDocuments: [SecureIdVerificationDocumentReference] = fileReferences
        
        self.init(type: type, street1: street1, street2: street2, city: city, region: region, countryCode: countryCode, postcode: postcode, verificationDocuments: verificationDocuments)
    }
    
    func serialize() -> (Data, [SecureIdVerificationDocumentReference])? {
        var dict: [String: Any] = [:]
        dict["document_type"] = self.type.serialize()
        dict["street_line1"] = self.street1
        if !self.street2.isEmpty {
            dict["street_line2"] = self.street2   
        }
        dict["city"] = self.city
        dict["region"] = self.region
        dict["country_code"] = self.countryCode
        dict["postcode"] = self.postcode
        
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: []) else {
            return nil
        }
        return (data, self.verificationDocuments)
    }
}
