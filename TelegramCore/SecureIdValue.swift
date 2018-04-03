import Foundation

public enum SecureIdValue: Equatable {
    case personalDetails(SecureIdPersonalDetailsValue)
    case passport(SecureIdPassportValue)
    case driversLicense(SecureIdDriversLicenseValue)
    case idCard(SecureIdIDCardValue)
    case address(SecureIdAddressValue)
    case utilityBill(SecureIdUtilityBillValue)
    case bankStatement(SecureIdBankStatementValue)
    case rentalAgreement(SecureIdRentalAgreementValue)
    case phone(SecureIdPhoneValue)
    case email(SecureIdEmailValue)
    
    func serialize() -> ([String: Any], [SecureIdVerificationDocumentReference], SecureIdVerificationDocumentReference?)? {
        switch self {
            case let .personalDetails(personalDetails):
                let (dict, files) = personalDetails.serialize()
                return (dict, files, nil)
            case let .passport(passport):
                return passport.serialize()
            case let .driversLicense(driversLicense):
                return driversLicense.serialize()
            case let .idCard(idCard):
                return idCard.serialize()
            case let .address(address):
                let (dict, files) = address.serialize()
                return (dict, files, nil)
            case let .utilityBill(utilityBill):
                let (dict, files) = utilityBill.serialize()
                return (dict, files, nil)
            case let .bankStatement(bankStatement):
                let (dict, files) = bankStatement.serialize()
                return (dict, files, nil)
            case let .rentalAgreement(rentalAgreement):
                let (dict, files) = rentalAgreement.serialize()
                return (dict, files, nil)
            case .phone:
                return nil
            case .email:
                return nil
        }
    }
}

struct SecureIdEncryptedValueFileMetadata: Equatable {
    let hash: Data
    let secret: Data
}

struct SecureIdEncryptedValueMetadata: Equatable {
    let valueDataHash: Data
    let decryptedSecret: Data
    let files: [SecureIdEncryptedValueFileMetadata]
}

public struct SecureIdValueWithContext: Equatable {
    public let value: SecureIdValue
    let encryptedMetadata: SecureIdEncryptedValueMetadata?
    let opaqueHash: Data
    
    init(value: SecureIdValue, encryptedMetadata: SecureIdEncryptedValueMetadata?, opaqueHash: Data) {
        self.value = value
        self.encryptedMetadata = encryptedMetadata
        self.opaqueHash = opaqueHash
    }
}
