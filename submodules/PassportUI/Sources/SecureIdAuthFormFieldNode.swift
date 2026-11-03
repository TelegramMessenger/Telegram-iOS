import Foundation
import UIKit
import SwiftSignalKit
import AsyncDisplayKit
import Display
import TelegramCore
import TelegramPresentationData
import TelegramStringFormatting
import CountrySelectionUI
import PhoneNumberFormat

enum SecureIdRequestedIdentityDocument: Int32 {
    case passport
    case internalPassport
    case driversLicense
    case idCard
    
    var valueKey: SecureIdValueKey {
        switch self {
            case .passport:
                return .passport
            case .internalPassport:
                return .internalPassport
            case .driversLicense:
                return .driversLicense
            case .idCard:
                return .idCard
        }
    }
}

enum SecureIdRequestedAddressDocument: Int32 {
    case utilityBill
    case bankStatement
    case rentalAgreement
    case passportRegistration
    case temporaryRegistration
    
    var valueKey: SecureIdValueKey {
        switch self {
            case .utilityBill:
                return .utilityBill
            case .bankStatement:
                return .bankStatement
            case .rentalAgreement:
                return .rentalAgreement
            case .passportRegistration:
                return .passportRegistration
            case .temporaryRegistration:
                return .temporaryRegistration
        }
    }
}

struct ParsedRequestedPersonalDetails: Equatable {
    var nativeNames: Bool
}

enum SecureIdParsedRequestedFormField: Equatable {
    case identity(personalDetails: ParsedRequestedPersonalDetails?, document: ParsedRequestedIdentityDocument?)
    case address(addressDetails: Bool, document: ParsedRequestedAddressDocument?)
    case phone
    case email
}

struct SecureIdRequestedIdentityDocumentWithAttributes: Equatable, Hashable {
    let document: SecureIdRequestedIdentityDocument
    let selfie: Bool
    let translation: Bool
}

enum ParsedRequestedIdentityDocument: Equatable {
    case just(SecureIdRequestedIdentityDocumentWithAttributes)
    case oneOf(Set<SecureIdRequestedIdentityDocumentWithAttributes>)
}

struct SecureIdRequestedAddressDocumentWithAttributes: Equatable, Hashable {
    let document: SecureIdRequestedAddressDocument
    let translation: Bool
}

enum ParsedRequestedAddressDocument: Equatable {
    case just(SecureIdRequestedAddressDocumentWithAttributes)
    case oneOf(Set<SecureIdRequestedAddressDocumentWithAttributes>)
}

private struct RequestedIdentity {
    var details: Bool = false
    var nativeNames: Bool = false
    var documents: [ParsedRequestedIdentityDocument] = []
    
    mutating func merge(_ other: RequestedIdentity) {
        self.details = self.details || other.details
        self.nativeNames = self.nativeNames || other.nativeNames
        self.documents.append(contentsOf: other.documents)
    }
}

private struct RequestedAddress {
    var details: Bool = false
    var documents: [ParsedRequestedAddressDocument] = []
    
    mutating func merge(_ other: RequestedAddress) {
        self.details = self.details || other.details
        self.documents.append(contentsOf: other.documents)
    }
}

private struct RequestedFieldValues {
    var identity = RequestedIdentity()
    var address = RequestedAddress()
    var phone: Bool = false
    var email: Bool = false
    
    mutating func merge(_ other: RequestedFieldValues) {
        self.identity.merge(other.identity)
        self.address.merge(other.address)
        self.phone = self.phone || other.phone
        self.email = self.email || other.email
    }
}

func parseRequestedFormFields(_ types: [SecureIdRequestedFormField], values: [SecureIdValueWithContext], primaryLanguageByCountry: [String: String]) -> [(SecureIdParsedRequestedFormField, [SecureIdValueWithContext], Bool)] {
    var requestedValues = RequestedFieldValues()
    
    for type in types {
        switch type {
            case let .just(value):
                let subResult = parseRequestedFieldValues(type: value)
                requestedValues.merge(subResult)
            case let .oneOf(subTypes):
                var oneOfResult = RequestedFieldValues()
                var oneOfIdentity = Set<SecureIdRequestedIdentityDocumentWithAttributes>()
                var oneOfAddress = Set<SecureIdRequestedAddressDocumentWithAttributes>()
                for type in subTypes {
                    let subResult = parseRequestedFieldValues(type: type)
                    for document in subResult.identity.documents {
                        if case let .just(document) = document {
                            oneOfIdentity.insert(document)
                        }
                    }
                    for document in subResult.address.documents {
                        if case let .just(document) = document {
                            oneOfAddress.insert(document)
                        }
                    }
                    oneOfResult.identity.details = oneOfResult.identity.details || subResult.identity.details
                    oneOfResult.address.details = oneOfResult.address.details || subResult.address.details
                }
                if !oneOfIdentity.isEmpty {
                    oneOfResult.identity.documents.append(.oneOf(oneOfIdentity))
                }
                if !oneOfAddress.isEmpty {
                    oneOfResult.address.documents.append(.oneOf(oneOfAddress))
                }
                requestedValues.merge(oneOfResult)
        }
    }
    
    var result: [SecureIdParsedRequestedFormField] = []
    if requestedValues.identity.details || !requestedValues.identity.documents.isEmpty {
        if requestedValues.identity.documents.isEmpty {
            result.append(.identity(personalDetails: ParsedRequestedPersonalDetails(nativeNames: requestedValues.identity.nativeNames), document: nil))
        } else {
            if requestedValues.identity.details && requestedValues.identity.documents.count == 1 {
                result.append(.identity(personalDetails: requestedValues.identity.details ? ParsedRequestedPersonalDetails(nativeNames: requestedValues.identity.nativeNames) : nil, document: requestedValues.identity.documents.first))
            } else {
                if requestedValues.identity.details {
                    result.append(.identity(personalDetails: ParsedRequestedPersonalDetails(nativeNames: requestedValues.identity.nativeNames), document: nil))
                }
                for document in requestedValues.identity.documents {
                    result.append(.identity(personalDetails: nil, document: document))
                }
            }
        }
    }
    if requestedValues.address.details || !requestedValues.address.documents.isEmpty {
        if requestedValues.address.documents.isEmpty {
            result.append(.address(addressDetails: true, document: nil))
        } else {
            if requestedValues.address.details && requestedValues.address.documents.count == 1 {
                result.append(.address(addressDetails: true, document: requestedValues.address.documents.first))
            } else {
                if requestedValues.address.details {
                    result.append(.address(addressDetails: true, document: nil))
                }
                for document in requestedValues.address.documents {
                    result.append(.address(addressDetails: false, document: document))
                }
            }
        }
    }
    if requestedValues.phone {
        result.append(.phone)
    }
    if requestedValues.email {
        result.append(.email)
    }
    
    return result.map { field in
        let (fieldValues, filled) = findValuesForField(field: field, values: values, primaryLanguageByCountry: primaryLanguageByCountry)
        return (field, fieldValues, filled)
    }
}

private func findValuesForField(field: SecureIdParsedRequestedFormField, values: [SecureIdValueWithContext], primaryLanguageByCountry: [String: String]) -> ([SecureIdValueWithContext], Bool) {
    switch field {
        case let .identity(personalDetails, document):
            var filled = true
            var result: [SecureIdValueWithContext] = []
            if let personalDetails = personalDetails {
                if let value = findValue(values, key: .personalDetails)?.1 {
                    result.append(value)
                    if case let .personalDetails(value) = value.value {
                        let hasNativeNames = value.nativeName?.isComplete() ?? false
                        let requiresNativeNames = primaryLanguageByCountry[value.residenceCountryCode] != "en"
                        if personalDetails.nativeNames && !hasNativeNames && requiresNativeNames {
                            filled = false
                        }
                    }
                    
                    if errorForErrorKey(.personalDetails, value) != nil {
                        filled = false
                    }
                } else {
                    filled = false
                }
            }
            if let document = document {
                switch document {
                    case let .just(type):
                        if let value = findValue(values, key: type.document.valueKey)?.1 {
                            result.append(value)
                            let data = extractSecureIdValueAdditionalData(value.value)
                            if type.selfie && !data.selfie {
                                filled = false
                            }
                            if type.translation && !data.translation {
                                filled = false
                            }
                            if errorForErrorKey(type.document.valueKey, value) != nil {
                                filled = false
                            }
                        } else {
                            filled = false
                        }
                    case let .oneOf(types):
                        var anyDocument = false
                        var bestMatchingValue: SecureIdValueWithContext?
                        inner: for type in types.sorted(by: { $0.document.valueKey.rawValue < $1.document.valueKey.rawValue }) {
                            if let value = findValue(values, key: type.document.valueKey)?.1 {
                                if bestMatchingValue == nil {
                                    bestMatchingValue = value
                                }
                                let data = extractSecureIdValueAdditionalData(value.value)
                                var dataFilled = true
                                if type.selfie && !data.selfie {
                                    dataFilled = false
                                }
                                if type.translation && !data.translation {
                                    dataFilled = false
                                }
                                if dataFilled {
                                    bestMatchingValue = value
                                    anyDocument = true
                                    break inner
                                }
                            }
                        }
                        if !anyDocument {
                            filled = false
                        }
                        if let bestMatchingValue = bestMatchingValue {
                            result.append(bestMatchingValue)
                            if errorForErrorKey(bestMatchingValue.value.key, bestMatchingValue) != nil {
                                filled = false
                            }
                        }
                }
            }
            return (result, filled)
        case let .address(addressDetails, document):
            var filled = true
            var result: [SecureIdValueWithContext] = []
            if addressDetails {
                if let value = findValue(values, key: .address)?.1 {
                    result.append(value)
                    if errorForErrorKey(.address, value) != nil {
                        filled = false
                    }
                } else {
                    filled = false
                }
            }
            if let document = document {
                switch document {
                    case let .just(type):
                        if let value = findValue(values, key: type.document.valueKey)?.1 {
                            result.append(value)
                            let data = extractSecureIdValueAdditionalData(value.value)
                            if type.translation && !data.translation {
                                filled = false
                            }
                            if errorForErrorKey(type.document.valueKey, value) != nil {
                                filled = false
                            }
                        } else {
                            filled = false
                        }
                    case let .oneOf(types):
                        var anyDocument = false
                        var bestMatchingValue: SecureIdValueWithContext?
                        inner: for type in types.sorted(by: { $0.document.valueKey.rawValue < $1.document.valueKey.rawValue }) {
                            if let value = findValue(values, key: type.document.valueKey)?.1 {
                                if bestMatchingValue == nil {
                                    bestMatchingValue = value
                                }
                                let data = extractSecureIdValueAdditionalData(value.value)
                                var dataFilled = true
                                if type.translation && !data.translation {
                                    dataFilled = false
                                }
                                if dataFilled {
                                    bestMatchingValue = value
                                    anyDocument = true
                                    break inner
                                }
                            }
                        }
                        if !anyDocument {
                            filled = false
                        }
                        if let bestMatchingValue = bestMatchingValue {
                            result.append(bestMatchingValue)
                            if errorForErrorKey(bestMatchingValue.value.key, bestMatchingValue) != nil {
                                filled = false
                            }
                        }
                }
            }
            return (result, filled)
        case .phone:
            if let value = findValue(values, key: .phone)?.1 {
                return ([value], true)
            } else {
                return ([], false)
            }
        case .email:
            if let value = findValue(values, key: .email)?.1 {
                return ([value], true)
            } else {
                return ([], false)
            }
    }
}

private func parseRequestedFieldValues(type: SecureIdRequestedFormFieldValue) -> RequestedFieldValues {
    var values = RequestedFieldValues()
    
    switch type {
        case let .personalDetails(nativeNames):
            values.identity.details = true
            values.identity.nativeNames = nativeNames
        case let .passport(selfie, translation):
            values.identity.documents.append(.just(SecureIdRequestedIdentityDocumentWithAttributes(document: .passport, selfie: selfie, translation: translation)))
        case let .internalPassport(selfie, translation):
            values.identity.documents.append(.just(SecureIdRequestedIdentityDocumentWithAttributes(document: .internalPassport, selfie: selfie, translation: translation)))
        case let .driversLicense(selfie, translation):
            values.identity.documents.append(.just(SecureIdRequestedIdentityDocumentWithAttributes(document: .driversLicense, selfie: selfie, translation: translation)))
        case let .idCard(selfie, translation):
            values.identity.documents.append(.just(SecureIdRequestedIdentityDocumentWithAttributes(document: .idCard, selfie: selfie, translation: translation)))
        case .address:
            values.address.details = true
        case let .passportRegistration(translation):
            values.address.documents.append(.just(SecureIdRequestedAddressDocumentWithAttributes(document: .passportRegistration, translation: translation)))
        case let .temporaryRegistration(translation):
            values.address.documents.append(.just(SecureIdRequestedAddressDocumentWithAttributes(document: .temporaryRegistration, translation: translation)))
        case let .bankStatement(translation):
            values.address.documents.append(.just(SecureIdRequestedAddressDocumentWithAttributes(document: .bankStatement, translation: translation)))
        case let .utilityBill(translation):
            values.address.documents.append(.just(SecureIdRequestedAddressDocumentWithAttributes(document: .utilityBill, translation: translation)))
        case let .rentalAgreement(translation):
            values.address.documents.append(.just(SecureIdRequestedAddressDocumentWithAttributes(document: .rentalAgreement, translation: translation)))
        case .phone:
            values.phone = true
        case .email:
            values.email = true
    }
    return values
}

private let titleFont = Font.regular(17.0)
private let textFont = Font.regular(15.0)

private func fieldsText(_ fields: String...) -> String {
    var result = ""
    for field in fields {
        if !field.isEmpty {
            if !result.isEmpty {
                result.append(", ")
            }
            result.append(field)
        }
    }
    return result
}

private func countryName(code: String, strings: PresentationStrings) -> String {
    return AuthorizationSequenceCountrySelectionController.lookupCountryNameById(code, strings: strings) ?? ""
}

private func stringForDocumentType(_ type: SecureIdRequestedIdentityDocument, strings: PresentationStrings) -> String {
    switch type {
    case .passport:
        return strings.Passport_Identity_TypePassport
    case .internalPassport:
        return strings.Passport_Identity_TypeInternalPassport
    case .idCard:
        return strings.Passport_Identity_TypeIdentityCard
    case .driversLicense:
        return strings.Passport_Identity_TypeDriversLicense
    }
}

private func placeholderForDocumentType(_ type: SecureIdRequestedIdentityDocument, strings: PresentationStrings) -> String {
    switch type {
    case .passport:
        return strings.Passport_Identity_TypePassportUploadScan
    case .internalPassport:
        return strings.Passport_Identity_TypeInternalPassportUploadScan
    case .idCard:
        return strings.Passport_Identity_TypeIdentityCardUploadScan
    case .driversLicense:
        return strings.Passport_Identity_TypeDriversLicenseUploadScan
    }
}

private func stringForDocumentType(_ type: SecureIdRequestedAddressDocument, strings: PresentationStrings) -> String {
    switch type {
    case .rentalAgreement:
        return strings.Passport_Address_TypeRentalAgreement
    case .bankStatement:
        return strings.Passport_Address_TypeBankStatement
    case .passportRegistration:
        return strings.Passport_Address_TypePassportRegistration
    case .temporaryRegistration:
        return strings.Passport_Address_TypeTemporaryRegistration
    case .utilityBill:
        return strings.Passport_Address_TypeUtilityBill
    }
}

private func placeholderForDocumentType(_ type: SecureIdRequestedAddressDocument, strings: PresentationStrings) -> String {
    switch type {
    case .rentalAgreement:
        return strings.Passport_Address_TypeRentalAgreementUploadScan
    case .bankStatement:
        return strings.Passport_Address_TypeBankStatementUploadScan
    case .passportRegistration:
        return strings.Passport_Address_TypePassportRegistrationUploadScan
    case .temporaryRegistration:
        return strings.Passport_Address_TypeTemporaryRegistrationUploadScan
    case .utilityBill:
        return strings.Passport_Address_TypeUtilityBillUploadScan
    }
}

private func placeholderForDocumentTypes(_ types: [SecureIdRequestedIdentityDocumentWithAttributes], strings: PresentationStrings) -> String {
    func stringForDocumentType(_ type: SecureIdRequestedIdentityDocument, strings: PresentationStrings) -> String {
        switch type {
            case .passport:
                return strings.Passport_Identity_OneOfTypePassport
            case .internalPassport:
                return strings.Passport_Identity_OneOfTypeInternalPassport
            case .idCard:
                return strings.Passport_Identity_OneOfTypeIdentityCard
            case .driversLicense:
                return strings.Passport_Identity_OneOfTypeDriversLicense
        }
    }
    
    var string = ""
    for i in 0 ..< types.count {
        let type = types[i]
        string.append(stringForDocumentType(type.document, strings: strings))
        if i < types.count - 2 {
            string.append(strings.Passport_FieldOneOf_Delimeter)
        } else if i < types.count - 1 {
            string.append(strings.Passport_FieldOneOf_FinalDelimeter)
        }
    }
    
    return strings.Passport_Identity_UploadOneOfScan(string).string
}

private func placeholderForDocumentTypes(_ types: [SecureIdRequestedAddressDocumentWithAttributes], strings: PresentationStrings) -> String {
    func stringForDocumentType(_ type: SecureIdRequestedAddressDocument, strings: PresentationStrings) -> String {
        switch type {
            case .rentalAgreement:
                return strings.Passport_Address_OneOfTypeRentalAgreement
            case .bankStatement:
                return strings.Passport_Address_OneOfTypeBankStatement
            case .passportRegistration:
                return strings.Passport_Address_OneOfTypePassportRegistration
            case .temporaryRegistration:
                return strings.Passport_Address_OneOfTypeTemporaryRegistration
            case .utilityBill:
                return strings.Passport_Address_OneOfTypeUtilityBill
        }
    }
    
    var string = ""
    for i in 0 ..< types.count {
        let type = types[i]
        string.append(stringForDocumentType(type.document, strings: strings))
        if i < types.count - 2 {
            string.append(strings.Passport_FieldOneOf_Delimeter)
        } else if i < types.count - 1 {
            string.append(strings.Passport_FieldOneOf_FinalDelimeter)
        }
    }
    
    return strings.Passport_Address_UploadOneOfScan(string).string
}

private func stringForDocumentValue(_ value: SecureIdValue, strings: PresentationStrings) -> String? {
    let stringForIdentityDocument: (String, SecureIdDate?) -> String = { identifier, date in
        var string = identifier
        if let date = date {
            string.append(", ")
            string.append(stringForDate(timestamp: date.timestamp, strings: strings))
        }
        return string
    }
    
    let stringForAddressDocument: (Int) -> String = { count in
        return strings.Passport_Scans(Int32(count))
    }
    
    switch value {
        case let .passport(value):
            return stringForIdentityDocument(value.identifier, value.expiryDate)
        case let .internalPassport(value):
            return stringForIdentityDocument(value.identifier, value.expiryDate)
        case let .idCard(value):
            return stringForIdentityDocument(value.identifier, value.expiryDate)
        case let .driversLicense(value):
            return stringForIdentityDocument(value.identifier, value.expiryDate)
        case let .utilityBill(value):
            return stringForAddressDocument(value.verificationDocuments.count)
        case let .rentalAgreement(value):
            return stringForAddressDocument(value.verificationDocuments.count)
        case let .bankStatement(value):
            return stringForAddressDocument(value.verificationDocuments.count)
        case let .temporaryRegistration(value):
            return stringForAddressDocument(value.verificationDocuments.count)
        case let .passportRegistration(value):
            return stringForAddressDocument(value.verificationDocuments.count)
        default:
            return nil
    }
}

private func fieldTitleAndText(field: SecureIdParsedRequestedFormField, strings: PresentationStrings, values: [SecureIdValueWithContext]) -> (String, String) {
    var title: String
    var placeholder: String
    var text: String = ""
    
    switch field {
        case let .identity(personalDetails, document):
            var isOneOf = false
            var filledDocument: (SecureIdRequestedIdentityDocument, SecureIdValue)?
            
            if let document = document {
                title = strings.Passport_FieldIdentity
                placeholder = strings.Passport_FieldIdentityUploadHelp
                
                switch document {
                    case let .just(type):
                        title = stringForDocumentType(type.document, strings: strings)
                        placeholder = placeholderForDocumentType(type.document, strings: strings)
                        if let value = findValue(values, key: type.document.valueKey)?.1.value {
                            filledDocument = (type.document, value)
                        }
                    case let .oneOf(types):
                        isOneOf = true
                        let typesArray = Array(types)
                        if typesArray.count == 2 {
                            title = strings.Passport_FieldOneOf_Or(stringForDocumentType(typesArray[0].document, strings: strings), stringForDocumentType(typesArray[1].document, strings: strings)).string
                        }
                        placeholder = placeholderForDocumentTypes(typesArray, strings: strings)
                        for type in types.sorted(by: { $0.document.valueKey.rawValue < $1.document.valueKey.rawValue }) {
                            if let value = findValue(values, key: type.document.valueKey)?.1.value {
                                filledDocument = (type.document, value)
                                break
                            }
                        }
                }
            } else {
                title = strings.Passport_Identity_TypePersonalDetails
                placeholder = strings.Passport_FieldIdentityDetailsHelp
            }
            
            if let filledDocument = filledDocument, isOneOf {
                text = stringForDocumentType(filledDocument.0, strings: strings)
            }
            if let _ = personalDetails {
                if let value = findValue(values, key: .personalDetails), case let .personalDetails(personalDetailsValue) = value.1.value {
                    if !text.isEmpty {
                        text.append(", ")
                    }
                    let fullName = personalDetailsValue.latinName.firstName + " " + personalDetailsValue.latinName.lastName
                    text.append(fieldsText(fullName, countryName(code: personalDetailsValue.countryCode, strings: strings)))
                }
            }
            if let filledDocument = filledDocument, let string = stringForDocumentValue(filledDocument.1, strings: strings) {
                if !text.isEmpty {
                    text.append(", ")
                }
                text.append(string)
            }
        case let .address(addressDetails, document):
            var isOneOf = false
            var filledDocument: (SecureIdRequestedAddressDocument, SecureIdValue)?
            
            if let document = document {
                title = strings.Passport_FieldAddress
                placeholder = strings.Passport_FieldAddressUploadHelp
                switch document {
                    case let .just(type):
                        title = stringForDocumentType(type.document, strings: strings)
                        placeholder = placeholderForDocumentType(type.document, strings: strings)
                        if let value = findValue(values, key: type.document.valueKey)?.1.value {
                            filledDocument = (type.document, value)
                        }
                    case let .oneOf(types):
                        isOneOf = true
                        let typesArray = Array(types)
                        if typesArray.count == 2 {
                            title = strings.Passport_FieldOneOf_Or(stringForDocumentType(typesArray[0].document, strings: strings), stringForDocumentType(typesArray[1].document, strings: strings)).string
                        }
                        placeholder = placeholderForDocumentTypes(typesArray, strings: strings)
                        for type in types.sorted(by: { $0.document.valueKey.rawValue < $1.document.valueKey.rawValue }) {
                            if let value = findValue(values, key: type.document.valueKey)?.1.value {
                                filledDocument = (type.document, value)
                                break
                            }
                        }
                }
            } else {
                title = strings.Passport_FieldAddress
                placeholder = strings.Passport_FieldAddressHelp
            }
            
            if let filledDocument = filledDocument, isOneOf {
                text = stringForDocumentType(filledDocument.0, strings: strings)
            }
            if addressDetails {
                if let value = findValue(values, key: .address), case let .address(addressValue) = value.1.value {
                    if !text.isEmpty {
                        text.append(", ")
                    }
                    text.append(fieldsText(addressValue.street1, addressValue.street2, addressValue.city, addressValue.state, addressValue.postcode, countryName(code: addressValue.countryCode, strings: strings)))
                }
            } else if let filledDocument = filledDocument, let string = stringForDocumentValue(filledDocument.1, strings: strings) {
                if !text.isEmpty {
                    text.append(", ")
                }
                text.append(string)
            }
        case .phone:
            title = strings.Passport_FieldPhone
            placeholder = strings.Passport_FieldPhoneHelp
            
            if let value = findValue(values, key: .phone), case let .phone(phoneValue) = value.1.value {
                if !text.isEmpty {
                    text.append(", ")
                }
                text = formatPhoneNumber(phoneValue.phone)
            }
        case .email:
            title = strings.Passport_FieldEmail
            placeholder = strings.Passport_FieldEmailHelp
        
            if let value = findValue(values, key: .email), case let .email(emailValue) = value.1.value {
                if !text.isEmpty {
                    text.append(", ")
                }
                text = formatPhoneNumber(emailValue.email)
            }
    }
    
    return (title, text.isEmpty ? placeholder : text)
}

private func errorForErrorKey(_ key: SecureIdValueKey, _ value: SecureIdValueWithContext) -> String? {
    if let error = value.errors[.value(key)] {
        return error
    } else if let error = value.errors.first {
        if case .value = error.key {} else {
            return error.value
        }
    }
    return nil
}

private func fieldErrorText(field: SecureIdParsedRequestedFormField, values: [SecureIdValueWithContext]) -> String? {
    switch field {
        case let .identity(personalDetails, document):
            if let _ = personalDetails, let value = findValue(values, key: .personalDetails)?.1, let error = errorForErrorKey(.personalDetails, value)  {
                return error
            }
            if let document = document {
                switch document {
                    case let .just(type):
                        if let value = findValue(values, key: type.document.valueKey)?.1, let error = errorForErrorKey(type.document.valueKey, value) {
                            return error
                        }
                    case let .oneOf(types):
                        for type in types.sorted(by: { $0.document.valueKey.rawValue < $1.document.valueKey.rawValue }) {
                            if let value = findValue(values, key: type.document.valueKey)?.1, let error = errorForErrorKey(type.document.valueKey, value) {
                                return error
                            }
                        }
                }
            }
        case let .address(addressDetails, document):
            if addressDetails, let value = findValue(values, key: .address)?.1, let error = errorForErrorKey(.address, value) {
                return error
            }
            if let document = document {
                switch document {
                    case let .just(type):
                        if let value = findValue(values, key: type.document.valueKey)?.1, let error = errorForErrorKey(type.document.valueKey, value) {
                            return error
                        }
                    case let .oneOf(types):
                        for type in types.sorted(by: { $0.document.valueKey.rawValue < $1.document.valueKey.rawValue }) {
                            if let value = findValue(values, key: type.document.valueKey)?.1, let error = errorForErrorKey(type.document.valueKey, value) {
                                return error
                            }
                        }
                }
            }
        default:
            return nil
    }
    return nil
}

final class SecureIdAuthFormFieldNode: ASDisplayNode {
    private let selected: () -> Void
    
    private let topSeparatorNode: ASDisplayNode
    private let bottomSeparatorNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    
    private let titleNode: ImmediateTextNode
    private let textNode: ImmediateTextNode
    private let disclosureNode: ASImageNode
    private let checkNode: ASImageNode
    
    private let buttonNode: HighlightableButtonNode
    
    private var validLayout: (CGFloat, Bool, Bool)?
    
    let field: SecureIdParsedRequestedFormField
    private let theme: PresentationTheme
    private let strings: PresentationStrings
    
    init(theme: PresentationTheme, strings: PresentationStrings, field: SecureIdParsedRequestedFormField, values: [SecureIdValueWithContext], primaryLanguageByCountry: [String: String], selected: @escaping () -> Void) {
        self.field = field
        self.theme = theme
        self.strings = strings
        self.selected = selected
        
        self.topSeparatorNode = ASDisplayNode()
        self.topSeparatorNode.isLayerBacked = true
        self.topSeparatorNode.backgroundColor = theme.list.itemBlocksSeparatorColor
        
        self.bottomSeparatorNode = ASDisplayNode()
        self.bottomSeparatorNode.isLayerBacked = true
        self.bottomSeparatorNode.backgroundColor = theme.list.itemBlocksSeparatorColor
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        self.highlightedBackgroundNode.backgroundColor = theme.list.itemHighlightedBackgroundColor
        self.highlightedBackgroundNode.alpha = 0.0
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.displaysAsynchronously = false
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.maximumNumberOfLines = 1
        
        self.textNode = ImmediateTextNode()
        self.textNode.displaysAsynchronously = false
        self.textNode.isUserInteractionEnabled = false
        self.textNode.maximumNumberOfLines = 4
        
        self.disclosureNode = ASImageNode()
        self.disclosureNode.isLayerBacked = true
        self.disclosureNode.displayWithoutProcessing = true
        self.disclosureNode.displaysAsynchronously = false
        self.disclosureNode.image = PresentationResourcesItemList.disclosureArrowImage(theme)
        
        self.checkNode = ASImageNode()
        self.checkNode.isLayerBacked = true
        self.checkNode.displayWithoutProcessing = true
        self.checkNode.displaysAsynchronously = false
        self.checkNode.image = PresentationResourcesItemList.checkIconImage(theme)
        
        self.buttonNode = HighlightableButtonNode()
        
        super.init()
        
        self.addSubnode(self.topSeparatorNode)
        self.addSubnode(self.bottomSeparatorNode)
        self.addSubnode(self.highlightedBackgroundNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.disclosureNode)
        self.addSubnode(self.checkNode)
        self.addSubnode(self.buttonNode)
        
        self.updateValues(values, primaryLanguageByCountry: primaryLanguageByCountry)
        
        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.highlightedBackgroundNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.highlightedBackgroundNode.alpha = 1.0
                    strongSelf.view.superview?.bringSubviewToFront(strongSelf.view)
                } else {
                    strongSelf.highlightedBackgroundNode.alpha = 0.0
                    strongSelf.highlightedBackgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                }
            }
        }
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
    }
    
    func updateValues(_ values: [SecureIdValueWithContext], primaryLanguageByCountry: [String: String]) {
        var (title, text) = fieldTitleAndText(field: self.field, strings: self.strings, values: values)
        var textColor = self.theme.list.itemSecondaryTextColor

        var filled = true
        
        if let errorText = fieldErrorText(field: self.field, values: values) {
            filled = false
            textColor = self.theme.list.itemDestructiveColor
            text = errorText
        } else {
            switch self.field {
                case let .identity(personalDetails, document):
                    if let personalDetails = personalDetails {
                        if let value = findValue(values, key: .personalDetails)?.1 {
                            if case let .personalDetails(value) = value.value {
                                let hasNativeNames = value.nativeName?.isComplete() ?? false
                                let requiresNativeNames = primaryLanguageByCountry[value.residenceCountryCode] != "en"
                                if personalDetails.nativeNames && !hasNativeNames && requiresNativeNames {
                                    filled = false
                                    text = strings.Passport_FieldIdentityDetailsHelp
                                }
                            }
                        } else {
                            filled = false
                            text = strings.Passport_FieldIdentityDetailsHelp
                        }
                    }
                    if let document = document {
                        switch document {
                            case let .just(type):
                                if let value = findValue(values, key: type.document.valueKey)?.1 {
                                    let data = extractSecureIdValueAdditionalData(value.value)
                                    if type.selfie && !data.selfie {
                                        filled = false
                                        text = strings.Passport_FieldIdentitySelfieHelp
                                    }
                                    if type.translation && !data.translation {
                                        filled = false
                                        text = strings.Passport_FieldIdentityTranslationHelp
                                    }
                                } else {
                                    filled = false
                                }
                            case let .oneOf(types):
                                var anyDocument = false
                                var missingSelfie = false
                                var missingTranslation = false
                                for type in types {
                                    if let value = findValue(values, key: type.document.valueKey)?.1 {
                                        let data = extractSecureIdValueAdditionalData(value.value)
                                        var dataFilled = true
                                        if type.selfie && !data.selfie {
                                            dataFilled = false
                                            missingSelfie = true
                                        }
                                        if type.translation && !data.translation {
                                            dataFilled = false
                                            missingTranslation = true
                                        }
                                        if dataFilled {
                                            anyDocument = true
                                        }
                                    }
                                }
                                if !anyDocument {
                                    filled = false
                                    if missingSelfie {
                                        text = strings.Passport_FieldIdentitySelfieHelp
                                    } else if missingTranslation {
                                        text = strings.Passport_FieldIdentityTranslationHelp
                                    }
                                }
                        }
                    }
                case let .address(addressDetails, document):
                    if addressDetails {
                        if findValue(values, key: .address) == nil {
                            filled = false
                            text = strings.Passport_FieldAddressHelp
                        }
                    }
                    if let document = document {
                        switch document {
                            case let .just(type):
                                if let value = findValue(values, key: type.document.valueKey)?.1 {
                                    let data = extractSecureIdValueAdditionalData(value.value)
                                    if type.translation && !data.translation {
                                        filled = false
                                        text = strings.Passport_FieldAddressTranslationHelp
                                    }
                                } else {
                                    filled = false
                                }
                            case let .oneOf(types):
                                var anyDocument = false
                                var missingTranslation = false
                                for type in types {
                                    if let value = findValue(values, key: type.document.valueKey)?.1 {
                                        let data = extractSecureIdValueAdditionalData(value.value)
                                        var dataFilled = true
                                        if type.translation && !data.translation {
                                            dataFilled = false
                                            missingTranslation = true
                                        }
                                        if dataFilled {
                                            anyDocument = true
                                        }
                                    }
                                }
                                if !anyDocument {
                                    filled = false
                                    if missingTranslation {
                                        text = strings.Passport_FieldIdentityTranslationHelp
                                    }
                                }
                        }
                    }
                case .phone:
                    if findValue(values, key: .phone) == nil {
                        filled = false
                    }
                case .email:
                    if findValue(values, key: .email) == nil {
                        filled = false
                    }
            }
        }
        
        self.titleNode.attributedText = NSAttributedString(string: title, font: titleFont, textColor: self.theme.list.itemPrimaryTextColor)
        self.textNode.attributedText = NSAttributedString(string: text, font: textFont, textColor: textColor)
        
        self.checkNode.isHidden = !filled
        self.disclosureNode.isHidden = filled
        
        if let (width, hasPrevious, hasNext) = self.validLayout {
            let _ = self.updateLayout(width: width, hasPrevious: hasPrevious, hasNext: hasNext, transition: .immediate)
        }
    }
    
    func updateLayout(width: CGFloat, hasPrevious: Bool, hasNext: Bool, transition: ContainedViewLayoutTransition) -> CGFloat {
        self.validLayout = (width, hasPrevious, hasNext)
        let leftInset: CGFloat = 16.0
        let rightInset: CGFloat = 16.0
        
        let rightTextInset = rightInset + 24.0
        let titleTextSpacing: CGFloat = 5.0
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: width - leftInset - rightTextInset, height: 100.0))
        let textSize = self.textNode.updateLayout(CGSize(width: width - leftInset - rightTextInset, height: 100.0))
        let height = max(64.0, 11.0 + titleSize.height + titleTextSpacing + textSize.height + 11.0)
        
        let textOrigin: CGFloat = 11.0
        let titleFrame = CGRect(origin: CGPoint(x: leftInset, y: textOrigin), size: titleSize)
        self.titleNode.frame = titleFrame
        let textFrame = CGRect(origin: CGPoint(x: leftInset, y: titleFrame.maxY + titleTextSpacing), size: textSize)
        self.textNode.frame = textFrame
        
        transition.updateFrame(node: self.topSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: width, height: UIScreenPixel)))
        transition.updateAlpha(node: self.topSeparatorNode, alpha: hasPrevious ? 0.0 : 1.0)
        let bottomSeparatorInset: CGFloat = hasNext ? leftInset : 0.0
        transition.updateFrame(node: self.bottomSeparatorNode, frame: CGRect(origin: CGPoint(x: bottomSeparatorInset, y: height - UIScreenPixel), size: CGSize(width: width - bottomSeparatorInset, height: UIScreenPixel)))
        
        transition.updateFrame(node: self.buttonNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: width, height: height)))
        transition.updateFrame(node: self.highlightedBackgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -(hasPrevious ? UIScreenPixel : 0.0)), size: CGSize(width: width, height: height + (hasPrevious ? UIScreenPixel : 0.0))))
        
        if let image = self.disclosureNode.image {
            self.disclosureNode.frame = CGRect(origin: CGPoint(x: width - 7.0 - image.size.width, y: floor((height - image.size.height) / 2.0)), size: image.size)
        }
        
        if let image = self.checkNode.image {
            self.checkNode.frame = CGRect(origin: CGPoint(x: width - 15.0 - image.size.width, y: floor((height - image.size.height) / 2.0)), size: image.size)
        }
        
        return height
    }
    
    @objc private func buttonPressed() {
        self.selected()
    }
    
    func highlight() {
        self.highlightedBackgroundNode.layer.removeAnimation(forKey: "opacity")
        self.highlightedBackgroundNode.alpha = 1.0
        self.view.superview?.bringSubviewToFront(self.view)
        
        Queue.mainQueue().after(1.0, {
            self.highlightedBackgroundNode.alpha = 0.0
            self.highlightedBackgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
        })
    }
}
