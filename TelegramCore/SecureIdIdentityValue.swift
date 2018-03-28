import Foundation

public enum SecureIdIdentityValue: Equatable {
    case passport(SecureIdIdentityPassportValue)
    case internationalPassport(SecureIdIdentityInternationalPassportValue)
    case driversLicense(SecureIdIdentityDriversLicenseValue)
    case idCard(SecureIdIdentityIDCardValue)
    
    public static func ==(lhs: SecureIdIdentityValue, rhs: SecureIdIdentityValue) -> Bool {
        switch lhs {
            case let .passport(value):
                if case .passport(value) = rhs {
                    return true
                } else {
                    return false
                }
            case let .internationalPassport(value):
                if case .internationalPassport(value) = rhs {
                    return true
                } else {
                    return false
                }
            case let .driversLicense(value):
                if case .driversLicense(value) = rhs {
                    return true
                } else {
                    return false
                }
            case let .idCard(value):
                if case .idCard(value) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

extension SecureIdIdentityValue {
    init?(data: Data, fileReferences: [SecureIdVerificationDocumentReference]) {
        guard let dict = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any] else {
            return nil
        }
        guard let documentType = dict["document_type"] as? String else {
            return nil
        }
        
        switch documentType {
            case "passport":
                if let passport = SecureIdIdentityPassportValue(dict: dict, fileReferences: fileReferences) {
                    self = .passport(passport)
                } else {
                    return nil
                }
            case "international_passport":
                if let internationalPassport = SecureIdIdentityInternationalPassportValue(dict: dict, fileReferences: fileReferences) {
                    self = .internationalPassport(internationalPassport)
                } else {
                    return nil
                }
            case "driver_license":
                if let driversLicense = SecureIdIdentityDriversLicenseValue(dict: dict, fileReferences: fileReferences) {
                    self = .driversLicense(driversLicense)
                } else {
                    return nil
                }
            case "identity_card":
                if let idCard = SecureIdIdentityIDCardValue(dict: dict, fileReferences: fileReferences) {
                    self = .idCard(idCard)
                } else {
                    return nil
                }
            default:
                return nil
        }
    }
    
    func serialize() -> (Data, [SecureIdVerificationDocumentReference])? {
        var dict: [String: Any] = [:]
        let fileReferences: [SecureIdVerificationDocumentReference]
        switch self {
            case let .passport(value):
                dict["document_type"] = "passport"
                let (valueDict, references) = value.serialize()
                dict.merge(valueDict, uniquingKeysWith: { lhs, _ in return lhs })
                fileReferences = references
            case let .internationalPassport(value):
                dict["document_type"] = "international_passport"
                let (valueDict, references) = value.serialize()
                dict.merge(valueDict, uniquingKeysWith: { lhs, _ in return lhs })
                fileReferences = references
            case let .driversLicense(value):
                dict["document_type"] = "driver_license"
                let (valueDict, references) = value.serialize()
                dict.merge(valueDict, uniquingKeysWith: { lhs, _ in return lhs })
                fileReferences = references
            case let .idCard(value):
                dict["document_type"] = "identity_card"
                let (valueDict, references) = value.serialize()
                dict.merge(valueDict, uniquingKeysWith: { lhs, _ in return lhs })
                fileReferences = references
        }
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: []) else {
            return nil
        }
        return (data, fileReferences)
    }
}
