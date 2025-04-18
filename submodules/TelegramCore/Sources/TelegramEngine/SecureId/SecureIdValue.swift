import Foundation

public enum SecureIdValueKey: Int32 {
    case personalDetails
    case passport
    case internalPassport
    case driversLicense
    case idCard
    case address
    case utilityBill
    case bankStatement
    case rentalAgreement
    case passportRegistration
    case temporaryRegistration
    case phone
    case email
}

public enum SecureIdValue: Equatable {
    case personalDetails(SecureIdPersonalDetailsValue)
    case passport(SecureIdPassportValue)
    case internalPassport(SecureIdInternalPassportValue)
    case driversLicense(SecureIdDriversLicenseValue)
    case idCard(SecureIdIDCardValue)
    case address(SecureIdAddressValue)
    case passportRegistration(SecureIdPassportRegistrationValue)
    case temporaryRegistration(SecureIdTemporaryRegistrationValue)
    case utilityBill(SecureIdUtilityBillValue)
    case bankStatement(SecureIdBankStatementValue)
    case rentalAgreement(SecureIdRentalAgreementValue)
    case phone(SecureIdPhoneValue)
    case email(SecureIdEmailValue)
    
    var fileReferences: [SecureIdVerificationDocumentReference] {
        switch self {
            case let .passport(passport):
                var result = passport.verificationDocuments
                if let selfie = passport.selfieDocument {
                    result.append(selfie)
                }
                if let frontSide = passport.frontSideDocument {
                    result.append(frontSide)
                }
                result.append(contentsOf: passport.translations)
                return result
            case let .internalPassport(passport):
                var result = passport.verificationDocuments
                if let selfie = passport.selfieDocument {
                    result.append(selfie)
                }
                if let frontSide = passport.frontSideDocument {
                    result.append(frontSide)
                }
                result.append(contentsOf: passport.translations)
                return result
            case let .driversLicense(driversLicense):
                var result = driversLicense.verificationDocuments
                if let selfie = driversLicense.selfieDocument {
                    result.append(selfie)
                }
                if let frontSide = driversLicense.frontSideDocument {
                    result.append(frontSide)
                }
                if let backSide = driversLicense.backSideDocument {
                    result.append(backSide)
                }
                result.append(contentsOf: driversLicense.translations)
                return result
            case let .idCard(idCard):
                var result = idCard.verificationDocuments
                if let selfie = idCard.selfieDocument {
                    result.append(selfie)
                }
                if let frontSide = idCard.frontSideDocument {
                    result.append(frontSide)
                }
                if let backSide = idCard.backSideDocument {
                    result.append(backSide)
                }
                result.append(contentsOf: idCard.translations)
                return result
            case let .passportRegistration(passportRegistration):
                return passportRegistration.verificationDocuments + passportRegistration.translations
            case let .temporaryRegistration(passportRegistration):
                return passportRegistration.verificationDocuments + passportRegistration.translations
            case let .bankStatement(bankStatement):
                return bankStatement.verificationDocuments + bankStatement.translations
            case let .utilityBill(utilityBill):
                return utilityBill.verificationDocuments + utilityBill.translations
            case let .rentalAgreement(rentalAgreement):
                return rentalAgreement.verificationDocuments + rentalAgreement.translations
            default:
                return []
        }
    }
    
    public var key: SecureIdValueKey {
        switch self {
            case .personalDetails:
                return .personalDetails
            case .passport:
                return .passport
            case .internalPassport:
                return .internalPassport
            case .driversLicense:
                return .driversLicense
            case .idCard:
                return .idCard
            case .address:
                return .address
            case .passportRegistration:
                return .passportRegistration
            case .temporaryRegistration:
                return .temporaryRegistration
            case .utilityBill:
                return .utilityBill
            case .bankStatement:
                return .bankStatement
            case .rentalAgreement:
                return .rentalAgreement
            case .phone:
                return .phone
            case .email:
                return .email
        }
    }
}

public struct SecureIdValueAdditionalData {
    public var nativeNames: Bool = false
    public var selfie: Bool = false
    public var translation: Bool = false
}

public func extractSecureIdValueAdditionalData(_ value: SecureIdValue) -> SecureIdValueAdditionalData {
    var data = SecureIdValueAdditionalData()
    switch value {
        case let .personalDetails(value):
            data.nativeNames = value.nativeName?.isComplete() ?? false
        case let .passport(value):
            data.selfie = value.selfieDocument != nil
            data.translation = !value.translations.isEmpty
        case let .internalPassport(value):
            data.selfie = value.selfieDocument != nil
            data.translation = !value.translations.isEmpty
        case let .idCard(value):
            data.selfie = value.selfieDocument != nil
            data.translation = !value.translations.isEmpty
        case let .driversLicense(value):
            data.selfie = value.selfieDocument != nil
            data.translation = !value.translations.isEmpty
        case let .utilityBill(value):
            data.translation = !value.translations.isEmpty
        case let .rentalAgreement(value):
            data.translation = !value.translations.isEmpty
        case let .bankStatement(value):
            data.translation = !value.translations.isEmpty
        case let .temporaryRegistration(value):
            data.translation = !value.translations.isEmpty
        case let .passportRegistration(value):
            data.translation = !value.translations.isEmpty
        default:
            break
    }
    return data
}

public struct SecureIdEncryptedValueFileMetadata: Equatable {
    let hash: Data
    let secret: Data
}

public struct SecureIdEncryptedValueMetadata: Equatable {
    let valueDataHash: Data
    let decryptedSecret: Data
}

public struct SecureIdValueWithContext: Equatable {
    public let value: SecureIdValue
    public let errors: [SecureIdValueContentErrorKey: SecureIdValueContentError]
    let files: [SecureIdEncryptedValueFileMetadata]
    let translations: [SecureIdEncryptedValueFileMetadata]
    let selfie: SecureIdEncryptedValueFileMetadata?
    let frontSide: SecureIdEncryptedValueFileMetadata?
    let backSide: SecureIdEncryptedValueFileMetadata?
    let encryptedMetadata: SecureIdEncryptedValueMetadata?
    let opaqueHash: Data
    
    init(value: SecureIdValue, errors: [SecureIdValueContentErrorKey: SecureIdValueContentError], files: [SecureIdEncryptedValueFileMetadata], translations: [SecureIdEncryptedValueFileMetadata], selfie: SecureIdEncryptedValueFileMetadata?, frontSide: SecureIdEncryptedValueFileMetadata?, backSide: SecureIdEncryptedValueFileMetadata?, encryptedMetadata: SecureIdEncryptedValueMetadata?, opaqueHash: Data) {
        self.value = value
        self.errors = errors
        self.files = files
        self.translations = translations
        self.selfie = selfie
        self.frontSide = frontSide
        self.backSide = backSide
        self.encryptedMetadata = encryptedMetadata
        self.opaqueHash = opaqueHash
    }
    
    public func withRemovedErrors(_ keys: [SecureIdValueContentErrorKey]) -> SecureIdValueWithContext {
        var errors = self.errors
        for key in keys {
            errors.removeValue(forKey: key)
        }
        return SecureIdValueWithContext(value: self.value, errors: errors, files: self.files, translations: self.translations, selfie: self.selfie, frontSide: self.frontSide, backSide: self.backSide, encryptedMetadata: self.encryptedMetadata, opaqueHash: self.opaqueHash)
    }
}
