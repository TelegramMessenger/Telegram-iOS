import Foundation

public enum SecureIdValueContentErrorKey: Hashable {
    case field(SecureIdValueContentErrorField)
    case file(hash: Data)
    case files(hashes: Set<Data>)
    case selfie(hash: Data)
    case frontSide(hash: Data)
    case backSide(hash: Data)
}

public enum SecureIdValueContentErrorField: Hashable {
    case personalDetails(SecureIdValueContentErrorPersonalDetailsField)
    case passport(SecureIdValueContentErrorPassportField)
    case internalPassport(SecureIdValueContentErrorInternalPassportField)
    case driversLicense(SecureIdValueContentErrorDriversLicenseField)
    case idCard(SecureIdValueContentErrorIdCardField)
    case address(SecureIdValueContentErrorAddressField)
}

public enum SecureIdValueContentErrorPersonalDetailsField: String, Hashable {
    case firstName = "first_name"
    case lastName = "last_name"
    case birthdate = "birth_date"
    case gender = "gender"
    case countryCode = "country_code"
}

public enum SecureIdValueContentErrorPassportField: String, Hashable {
    case documentId = "document_no"
    case expiryDate = "expiry_date"
}

public enum SecureIdValueContentErrorInternalPassportField: String, Hashable {
    case documentId = "document_no"
    case expiryDate = "expiry_date"
}

public enum SecureIdValueContentErrorDriversLicenseField: String, Hashable {
    case documentId = "document_no"
    case expiryDate = "expiry_date"
}

public enum SecureIdValueContentErrorIdCardField: String, Hashable {
    case documentId = "document_no"
    case expiryDate = "expiry_date"
}

public enum SecureIdValueContentErrorAddressField: String, Hashable {
    case streetLine1 = "street_line1"
    case streetLine2 = "street_line2"
    case city = "city"
    case state = "state"
    case countryCode = "country_code"
    case postCode = "post_code"
}

public typealias SecureIdValueContentError = String

/*func parseSecureIdValueContentErrors(dataHash: Data?, fileHashes: Set<Data>, selfieHash: Data?, frontSideHash: Data?, backSideHash: Data?, errors: [Api.SecureValueError]) -> [SecureIdValueContentErrorKey: SecureIdValueContentError] {
    var result: [SecureIdValueContentErrorKey: SecureIdValueContentError] = [:]
    for error in errors {
        switch error {
            case let .secureValueErrorData(type, errorDataHash, field, text):
                if errorDataHash.makeData() == dataHash {
                    switch type {
                        case .secureValueTypePersonalDetails:
                            if let parsedField = SecureIdValueContentErrorPersonalDetailsField(rawValue: field) {
                            result[.field(.personalDetails(parsedField))] = text
                            }
                        case .secureValueTypePassport:
                            if let parsedField = SecureIdValueContentErrorPassportField(rawValue: field) {
                                result[.field(.passport(parsedField))] = text
                            }
                        case .secureValueTypeInternalPassport:
                            if let parsedField = SecureIdValueContentErrorInternalPassportField(rawValue: field) {
                                result[.field(.internalPassport(parsedField))] = text
                            }
                        case .secureValueTypeDriverLicense:
                            if let parsedField = SecureIdValueContentErrorDriversLicenseField(rawValue: field) {
                                result[.field(.driversLicense(parsedField))] = text
                            }
                        case .secureValueTypeIdentityCard:
                            if let parsedField = SecureIdValueContentErrorIdCardField(rawValue: field) {
                                result[.field(.idCard(parsedField))] = text
                            }
                        case .secureValueTypeAddress:
                            if let parsedField = SecureIdValueContentErrorAddressField(rawValue: field) {
                                result[.field(.address(parsedField))] = text
                            }
                        default:
                            break
                    }
                }
            case let .secureValueErrorFile(_, fileHash, text):
                if fileHashes.contains(fileHash.makeData()) {
                    result[.file(hash: fileHash.makeData())] = text
                }
            case let .secureValueErrorFiles(_, fileHash, text):
                var containsAll = true
                loop: for hash in fileHash {
                    if !fileHashes.contains(hash.makeData()) {
                        containsAll = false
                        break loop
                    }
                }
                if containsAll {
                    result[.files(hashes: Set(fileHash.map { $0.makeData() }))] = text
                }
            case let .secureValueErrorSelfie(_, fileHash, text):
                if selfieHash == fileHash.makeData() {
                    result[.selfie(hash: fileHash.makeData())] = text
                }
            case .secureValueErrorFrontSide(let type, let fileHash, let text):
                if frontSideHash == fileHash.makeData() {
                    result[.frontSide(hash: fileHash.makeData())] = text
                }
            case .secureValueErrorReverseSide(let type, let fileHash, let text):
                if backSideHash == fileHash.makeData() {
                    result[.backSide(hash: fileHash.makeData())] = text
                }
        }
    }
    return result
}*/
