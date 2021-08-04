import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import Postbox
import SwiftSignalKit
import TelegramPresentationData
import TelegramStringFormatting
import AccountContext
import GalleryUI
import CountrySelectionUI
import DateSelectionUI
import AppBundle

private enum SecureIdDocumentFormTextField {
    case identifier
    case firstName
    case middleName
    case lastName
    case nativeFirstName
    case nativeMiddleName
    case nativeLastName
    case street1
    case street2
    case city
    case state
    case postcode
}

private enum SecureIdDocumentFormDateField {
    case birthdate
    case expiry
}

private enum SecureIdDocumentFormGenderField {
    case gender
}

private enum SecureIdDocumentFormSelectionField {
    case country
    case residenceCountry
    case date(Int32?, SecureIdDocumentFormDateField)
    case gender
}

enum SecureIdAddFileTarget {
    case scan
    case selfie
    case frontSide(SecureIdRequestedIdentityDocument?)
    case backSide(SecureIdRequestedIdentityDocument?)
    case translation
}

final class SecureIdDocumentFormParams {
    fileprivate let account: Account
    fileprivate let context: SecureIdAccessContext
    fileprivate let addFile: (SecureIdAddFileTarget) -> Void
    fileprivate let openDocument: (SecureIdVerificationDocument) -> Void
    fileprivate let deleteDocument: (SecureIdVerificationDocument) -> Void
    fileprivate let updateText: (SecureIdDocumentFormTextField, String) -> Void
    fileprivate let selectNextInputItem: (SecureIdDocumentFormEntry) -> Void
    fileprivate let endEditing: () -> Void
    fileprivate let activateSelection: (SecureIdDocumentFormSelectionField) -> Void
    fileprivate let scanPassport: () -> Void
    fileprivate let deleteValue: () -> Void
    
    fileprivate init(account: Account, context: SecureIdAccessContext, addFile: @escaping (SecureIdAddFileTarget) -> Void, openDocument: @escaping (SecureIdVerificationDocument) -> Void, deleteDocument: @escaping (SecureIdVerificationDocument) -> Void, updateText: @escaping (SecureIdDocumentFormTextField, String) -> Void, selectNextInputItem: @escaping (SecureIdDocumentFormEntry) -> Void, endEditing: @escaping () -> Void, activateSelection: @escaping (SecureIdDocumentFormSelectionField) -> Void, scanPassport: @escaping () -> Void, deleteValue: @escaping () -> Void) {
        self.account = account
        self.context = context
        self.addFile = addFile
        self.openDocument = openDocument
        self.deleteDocument = deleteDocument
        self.updateText = updateText
        self.selectNextInputItem = selectNextInputItem
        self.endEditing = endEditing
        self.activateSelection = activateSelection
        self.scanPassport = scanPassport
        self.deleteValue = deleteValue
    }
}

private struct SecureIdDocumentFormIdentityDetailsState: Equatable {
    let primaryLanguageByCountry: [String: String]
    let nativeNameRequired: Bool
    
    var firstName: String
    var middleName: String
    var lastName: String
    var nativeFirstName: String
    var nativeMiddleName: String
    var nativeLastName: String
    var countryCode: String
    var residenceCountryCode: String
    var birthdate: SecureIdDate?
    var gender: SecureIdGender?
    
    func isComplete() -> Bool {
        let nameMaxLength = 255
        
        if self.firstName.isEmpty || self.firstName.count > nameMaxLength {
            return false
        }
        if self.middleName.count > nameMaxLength {
            return false
        }
        if self.lastName.isEmpty || self.lastName.count > nameMaxLength {
            return false
        }
        if self.nativeNameRequired && self.primaryLanguageByCountry[self.residenceCountryCode] != "en" {
            if self.nativeFirstName.isEmpty || self.nativeFirstName.count > nameMaxLength {
                return false
            }
            if self.nativeLastName.isEmpty || self.nativeLastName.count > nameMaxLength {
                return false
            }
        }
        if self.countryCode.isEmpty {
            return false
        }
        if self.residenceCountryCode.isEmpty {
            return false
        }
        if self.birthdate == nil {
            return false
        }
        if self.gender == nil {
            return false
        }
        return true
    }
}

enum DocumentExpirationDate: Equatable {
    case notSet
    case date(SecureIdDate)
    case doesNotExpire
}

private struct SecureIdDocumentFormIdentityDocumentState: Equatable {
    var type: SecureIdRequestedIdentityDocument
    var identifier: String
    var expiryDate: DocumentExpirationDate
    
    func isComplete() -> Bool {
        let identifierMaxLength = 24
        
        if self.identifier.isEmpty || self.identifier.count > identifierMaxLength {
            return false
        }
        
        if case .notSet = expiryDate {
            return false
        }
        return true
    }
}

private struct SecureIdDocumentFormIdentityState {
    var details: SecureIdDocumentFormIdentityDetailsState?
    var document: SecureIdDocumentFormIdentityDocumentState?
    
    func isEqual(to: SecureIdDocumentFormIdentityState) -> Bool {
        if self.details != to.details {
            return false
        }
        if self.document != to.document {
            return false
        }
        return true
    }
    
    func isComplete() -> Bool {
        if let details = self.details {
            if !details.isComplete() {
                return false
            }
        }
        if let document = self.document {
            if !document.isComplete() {
                return false
            }
        }
        return true
    }
}

private struct SecureIdDocumentFormAddressDetailsState: Equatable {
    var street1: String
    var street2: String
    var city: String
    var state: String
    var countryCode: String
    var postcode: String
    
    func isComplete() -> Bool {
        let cityMinLength = 2
        let stateMinLength = 2
        let postcodeMaxLength = 12

        if self.street1.isEmpty {
            return false
        }
        if self.city.count < cityMinLength {
            return false
        }
        if self.countryCode.isEmpty {
            return false
        }
        if self.countryCode == "US" && self.state.count < stateMinLength {
            return false
        }
        if self.postcode.isEmpty || self.postcode.count > postcodeMaxLength {
            return false
        }
        return true
    }
}

private struct SecureIdDocumentFormAddressState {
    var details: SecureIdDocumentFormAddressDetailsState?
    var document: SecureIdRequestedAddressDocument?
    
    func isEqual(to: SecureIdDocumentFormAddressState) -> Bool {
        if self.details != to.details {
            return false
        }
        if self.document != to.document {
            return false
        }
        return true
    }
    
    func isComplete() -> Bool {
        if let details = self.details {
            if !details.isComplete() {
                return false
            }
        }
        return true
    }
}

private enum SecureIdDocumentFormDocumentState {
    case identity(SecureIdDocumentFormIdentityState)
    case address(SecureIdDocumentFormAddressState)
    
    mutating func updateTextField(type: SecureIdDocumentFormTextField, value: String) {
        switch self {
            case var .identity(state):
                switch type {
                    case .firstName:
                        state.details?.firstName = value
                    case .middleName:
                        state.details?.middleName = value
                    case .lastName:
                        state.details?.lastName = value
                    case .nativeFirstName:
                        state.details?.nativeFirstName = value
                    case .nativeMiddleName:
                        state.details?.nativeMiddleName = value
                    case .nativeLastName:
                        state.details?.nativeLastName = value
                    case .identifier:
                        state.document?.identifier = value
                    default:
                        break
                }
                self = .identity(state)
            case var .address(state):
                switch type {
                    case .street1:
                        state.details?.street1 = value
                    case .street2:
                        state.details?.street2 = value
                    case .city:
                        state.details?.city = value
                    case .state:
                        state.details?.state = value
                    case .postcode:
                        state.details?.postcode = value
                    default:
                        break
                }
                self = .address(state)
        }
    }
    
    mutating func updateCountryCode(value: String) {
        switch self {
            case var .identity(state):
                state.details?.countryCode = value
                self = .identity(state)
            case var .address(state):
                state.details?.countryCode = value
                self = .address(state)
        }
    }
    
    mutating func updateResidenceCountryCode(value: String) {
        switch self {
            case var .identity(state):
                state.details?.residenceCountryCode = value
                self = .identity(state)
            case .address:
                break
        }
    }
    
    mutating func updateDateField(type: SecureIdDocumentFormDateField, value: SecureIdDate?) {
        switch self {
            case var .identity(state):
                switch type {
                    case .birthdate:
                        state.details?.birthdate = value
                    case .expiry:
                        if let value = value {
                            state.document?.expiryDate = .date(value)
                        } else {
                            state.document?.expiryDate = .doesNotExpire
                        }
                }
                self = .identity(state)
            case .address:
                break
        }
    }
    
    mutating func updateGenderField(type: SecureIdDocumentFormGenderField, value: SecureIdGender?) {
        switch self {
            case var .identity(state):
                switch type {
                    case .gender:
                        state.details?.gender = value
                }
                self = .identity(state)
            case .address:
                break
        }
    }
    
    func isEqual(to: SecureIdDocumentFormDocumentState) -> Bool {
        switch self {
            case let .identity(lhsValue):
                if case let .identity(rhsValue) = to, lhsValue.isEqual(to: rhsValue) {
                    return true
                } else {
                    return false
                }
            case let .address(lhsValue):
                if case let .address(rhsValue) = to, lhsValue.isEqual(to: rhsValue) {
                    return true
                } else {
                    return false
                }
        }
    }
}

extension SecureIdDocumentFormDocumentState {
    mutating func updateWithRecognizedData(_ data: SecureIdRecognizedDocumentData) {
        if case var .identity(state) = self {
            if var details = state.details {
                if details.firstName.isEmpty {
                    details.firstName = data.firstName ?? ""
                }
                if details.lastName.isEmpty {
                    details.lastName = data.lastName ?? ""
                }
                if details.birthdate == nil, let birthdate = data.birthDate {
                    details.birthdate = SecureIdDate(timestamp: Int32(birthdate.timeIntervalSince1970))
                }
                if details.gender == nil, let gender = data.gender {
                    if gender == "M" {
                        details.gender = .male
                    } else {
                        details.gender = .female
                    }
                }
                if details.countryCode.isEmpty {
                    details.countryCode = data.nationality ?? ""
                }
                if details.residenceCountryCode.isEmpty {
                    details.residenceCountryCode = data.issuingCountry ?? ""
                }
                state.details = details
            }
            
            if var document = state.document {
                switch document.type {
                    case .passport:
                        break
                    case .internalPassport:
                        break
                    case .driversLicense:
                        break
                    case .idCard:
                        break
                }
                
                if document.identifier.isEmpty {
                    document.identifier = data.documentNumber ?? ""
                }
                if document.expiryDate == .notSet {
                    if let expiryDate = data.expiryDate {
                        document.expiryDate = SecureIdDate(timestamp: Int32(expiryDate.timeIntervalSince1970)).flatMap(DocumentExpirationDate.date) ?? .notSet
                    } else {
                        document.expiryDate = .doesNotExpire
                    }
                }
                state.document = document
            }
            self = .identity(state)
        }
    }
}

private enum SecureIdDocumentFormActionState {
    case none
    case saving
    case deleting
}

enum SecureIdDocumentFormInputState {
    case saveAvailable
    case saveNotAvailable
    case inProgress
}

private func maybeAddError(key: SecureIdValueContentErrorKey, value: SecureIdValueWithContext, entries: inout [FormControllerItemEntry<SecureIdDocumentFormEntry>], errorIndex: inout Int) {
    if let error = value.errors[key] {
        entries.append(.entry(SecureIdDocumentFormEntry.error(errorIndex, error, key)))
        errorIndex += 1
    }
}

struct SecureIdDocumentFormState: FormControllerInnerState {
    fileprivate var previousValues: [SecureIdValueKey: SecureIdValueWithContext]
    fileprivate var documentState: SecureIdDocumentFormDocumentState
    fileprivate var documents: [SecureIdVerificationDocument]
    fileprivate var selfieRequired: Bool
    fileprivate var selfieDocument: SecureIdVerificationDocument?
    fileprivate var frontSideRequired: Bool
    fileprivate var frontSideDocument: SecureIdVerificationDocument?
    fileprivate var backSideRequired: Bool
    fileprivate var backSideDocument: SecureIdVerificationDocument?
    fileprivate var translationsRequired: Bool
    fileprivate var translations: [SecureIdVerificationDocument]
    fileprivate var actionState: SecureIdDocumentFormActionState
    fileprivate var requestOptionalData: Bool
    
    func isEqual(to: SecureIdDocumentFormState) -> Bool {
        if !self.documentState.isEqual(to: to.documentState) {
            return false
        }
        if self.actionState != to.actionState {
            return false
        }
        if self.documents.count != to.documents.count {
            return false
        }
        for i in 0 ..< self.documents.count {
            if self.documents[i] != to.documents[i] {
                return false
            }
        }
        if self.selfieRequired != to.selfieRequired {
            return false
        }
        if self.selfieDocument != to.selfieDocument {
            return false
        }
        if self.frontSideDocument != to.frontSideDocument {
            return false
        }
        if self.backSideDocument != to.backSideDocument {
            return false
        }
        if self.translationsRequired != to.translationsRequired {
            return false
        }
        if self.translations.count != to.translations.count {
            return false
        }
        for i in 0 ..< self.translations.count {
            if self.translations[i] != to.translations[i] {
                return false
            }
        }
        if self.requestOptionalData != to.requestOptionalData {
            return false
        }
        return true
    }
    
    func entries() -> [FormControllerItemEntry<SecureIdDocumentFormEntry>] {
        switch self.documentState {
            case let .identity(identity):
                var result: [FormControllerItemEntry<SecureIdDocumentFormEntry>] = []
                var errorIndex = 0
                
                if let details = identity.details {
                    if identity.document == nil {
                        result.append(.spacer)
                        result.append(.entry(SecureIdDocumentFormEntry.scanYourPassport))
                        result.append(.entry(SecureIdDocumentFormEntry.scanYourPassportInfo))
                        result.append(.spacer)
                    }
                    
                    result.append(.entry(SecureIdDocumentFormEntry.infoHeader(.identity)))
                    
                    let previousValue: SecureIdValueWithContext? = self.previousValues[.personalDetails]
                    let valueErrorKey: SecureIdValueContentErrorKey = .value(.personalDetails)
                    
                    if let previousValue = previousValue {
                        maybeAddError(key: valueErrorKey, value: previousValue, entries: &result, errorIndex: &errorIndex)
                    }
                    result.append(.entry(SecureIdDocumentFormEntry.firstName(details.firstName, self.previousValues[.personalDetails]?.errors[.field(.personalDetails(.firstName))])))
                    result.append(.entry(SecureIdDocumentFormEntry.middleName(details.middleName, self.previousValues[.personalDetails]?.errors[.field(.personalDetails(.middleName))])))
                    result.append(.entry(SecureIdDocumentFormEntry.lastName(details.lastName, self.previousValues[.personalDetails]?.errors[.field(.personalDetails(.lastName))])))
                    
                    result.append(.entry(SecureIdDocumentFormEntry.birthdate(details.birthdate, self.previousValues[.personalDetails]?.errors[.field(.personalDetails(.birthdate))])))
                    result.append(.entry(SecureIdDocumentFormEntry.gender(details.gender, self.previousValues[.personalDetails]?.errors[.field(.personalDetails(.gender))])))
                    result.append(.entry(SecureIdDocumentFormEntry.countryCode(.identity, details.countryCode, self.previousValues[.personalDetails]?.errors[.field(.personalDetails(.countryCode))])))
                    result.append(.entry(SecureIdDocumentFormEntry.residenceCountryCode(details.residenceCountryCode, self.previousValues[.personalDetails]?.errors[.field(.personalDetails(.residenceCountryCode))])))
                    
                    if (details.nativeNameRequired || self.requestOptionalData) && !details.residenceCountryCode.isEmpty && details.primaryLanguageByCountry[details.residenceCountryCode] != "en" {
                        if let last = result.last, case .spacer = last {
                        } else {
                            result.append(.spacer)
                        }
                        result.append(.entry(SecureIdDocumentFormEntry.nativeInfoHeader(details.primaryLanguageByCountry[details.residenceCountryCode] ?? "")))
                        result.append(.entry(SecureIdDocumentFormEntry.nativeFirstName(details.nativeFirstName, self.previousValues[.personalDetails]?.errors[.field(.personalDetails(.firstNameNative))])))
                        result.append(.entry(SecureIdDocumentFormEntry.nativeMiddleName(details.nativeMiddleName, self.previousValues[.personalDetails]?.errors[.field(.personalDetails(.middleNameNative))])))
                        result.append(.entry(SecureIdDocumentFormEntry.nativeLastName(details.nativeLastName, self.previousValues[.personalDetails]?.errors[.field(.personalDetails(.lastNameNative))])))
                        result.append(.entry(SecureIdDocumentFormEntry.nativeInfo(details.primaryLanguageByCountry[details.residenceCountryCode] ?? "", details.residenceCountryCode)))
                        result.append(.spacer)
                    }
                }
                
                if let document = identity.document {
                    if identity.details == nil {
                        result.append(.entry(SecureIdDocumentFormEntry.infoHeader(.identity)))
                    }
                    
                    let previousValue: SecureIdValueWithContext?
                    let valueErrorKey: SecureIdValueContentErrorKey
                    
                    var identifierError: String?
                    var expiryDateError: String?
                    
                    switch document.type {
                        case .passport:
                            previousValue = self.previousValues[.passport]
                            valueErrorKey = .value(.passport)
                            identifierError = self.previousValues[.passport]?.errors[.field(.passport(.documentId))]
                            expiryDateError = self.previousValues[.passport]?.errors[.field(.passport(.expiryDate))]
                        case .internalPassport:
                            previousValue = self.previousValues[.internalPassport]
                            valueErrorKey = .value(.internalPassport)
                            identifierError = self.previousValues[.internalPassport]?.errors[.field(.internalPassport(.documentId))]
                            expiryDateError = self.previousValues[.internalPassport]?.errors[.field(.internalPassport(.expiryDate))]
                        case .driversLicense:
                            previousValue = self.previousValues[.driversLicense]
                            valueErrorKey = .value(.driversLicense)
                            identifierError = self.previousValues[.driversLicense]?.errors[.field(.driversLicense(.documentId))]
                            expiryDateError = self.previousValues[.driversLicense]?.errors[.field(.driversLicense(.expiryDate))]
                        case .idCard:
                            previousValue = self.previousValues[.idCard]
                            valueErrorKey = .value(.idCard)
                            identifierError = self.previousValues[.idCard]?.errors[.field(.idCard(.documentId))]
                            expiryDateError = self.previousValues[.idCard]?.errors[.field(.idCard(.expiryDate))]
                    }
                    
                    if let previousValue = previousValue {
                        maybeAddError(key: valueErrorKey, value: previousValue, entries: &result, errorIndex: &errorIndex)
                    }
                    result.append(.entry(SecureIdDocumentFormEntry.identifier(document.identifier, identifierError)))
                    result.append(.entry(SecureIdDocumentFormEntry.expiryDate(document.expiryDate, expiryDateError)))
                }
                
                if ((self.selfieRequired || self.requestOptionalData) && identity.document != nil) || self.frontSideRequired || self.backSideRequired {
                    let type = identity.document?.type
                    
                    if let last = result.last, case .spacer = last {
                    } else {
                        result.append(.spacer)
                    }
                    result.append(.entry(SecureIdDocumentFormEntry.requestedDocumentsHeader))
                    if self.frontSideRequired {
                        if let document = self.frontSideDocument {
                            var error: String?
                            if case let .remote(file) = document {
                                switch self.documentState {
                                case let .identity(identity):
                                    if let document = identity.document {
                                        switch document.type {
                                        case .passport:
                                            error = self.previousValues[.passport]?.errors[.frontSide(hash: file.fileHash)]
                                        case .internalPassport:
                                            error = self.previousValues[.internalPassport]?.errors[.frontSide(hash: file.fileHash)]
                                        case .driversLicense:
                                            error = self.previousValues[.driversLicense]?.errors[.frontSide(hash: file.fileHash)]
                                        case .idCard:
                                            error = self.previousValues[.idCard]?.errors[.frontSide(hash: file.fileHash)]
                                        }
                                    }
                                case .address:
                                    break
                                }
                            }
                            result.append(.entry(SecureIdDocumentFormEntry.frontSide(1, type, document, error)))
                        } else {
                            result.append(.entry(SecureIdDocumentFormEntry.frontSide(1, type, nil, nil)))
                        }
                    }
                    if self.backSideRequired {
                        if let document = self.backSideDocument {
                            var error: String?
                            if case let .remote(file) = document {
                                switch self.documentState {
                                case let .identity(identity):
                                    if let document = identity.document {
                                        switch document.type {
                                        case .passport:
                                            error = self.previousValues[.passport]?.errors[.backSide(hash: file.fileHash)]
                                        case .internalPassport:
                                            error = self.previousValues[.internalPassport]?.errors[.backSide(hash: file.fileHash)]
                                        case .driversLicense:
                                            error = self.previousValues[.driversLicense]?.errors[.backSide(hash: file.fileHash)]
                                        case .idCard:
                                            error = self.previousValues[.idCard]?.errors[.backSide(hash: file.fileHash)]
                                        }
                                    }
                                case .address:
                                    break
                                }
                            }
                            result.append(.entry(SecureIdDocumentFormEntry.backSide(2, type, document, error)))
                        } else {
                            result.append(.entry(SecureIdDocumentFormEntry.backSide(2, type, nil, nil)))
                        }
                    }
                    
                    if self.selfieRequired || self.requestOptionalData {
                        if let document = self.selfieDocument {
                            var error: String?
                            if case let .remote(file) = document {
                                switch self.documentState {
                                case let .identity(identity):
                                    if let document = identity.document {
                                        switch document.type {
                                        case .passport:
                                            error = self.previousValues[.passport]?.errors[.selfie(hash: file.fileHash)]
                                        case .internalPassport:
                                            error = self.previousValues[.internalPassport]?.errors[.selfie(hash: file.fileHash)]
                                        case .driversLicense:
                                            error = self.previousValues[.driversLicense]?.errors[.selfie(hash: file.fileHash)]
                                        case .idCard:
                                            error = self.previousValues[.idCard]?.errors[.selfie(hash: file.fileHash)]
                                        }
                                    }
                                case .address:
                                    break
                                }
                            }
                            result.append(.entry(SecureIdDocumentFormEntry.selfie(0, document, error)))
                        } else {
                            result.append(.entry(SecureIdDocumentFormEntry.selfie(0, nil, nil)))
                        }
                    }
                    
                    result.append(.entry(SecureIdDocumentFormEntry.scansInfo(.identity)))
                }
                
                if let document = identity.document, self.translationsRequired || self.requestOptionalData {
                    if let last = result.last, case .spacer = last {
                    } else {
                        result.append(.spacer)
                    }
                    result.append(.entry(SecureIdDocumentFormEntry.translationsHeader))
                    
                    let filesType: SecureIdValueKey
                    switch document.type {
                        case .passport:
                            filesType = .passport
                        case .internalPassport:
                            filesType = .internalPassport
                        case .driversLicense:
                            filesType = .driversLicense
                        case .idCard:
                            filesType = .idCard
                    }
                    
                    if let value = self.previousValues[filesType] {
                        var fileHashes: Set<Data>? = Set()
                        loop: for document in self.translations {
                            switch document {
                                case .local:
                                    fileHashes = nil
                                    break loop
                                case let .remote(file):
                                    fileHashes?.insert(file.fileHash)
                            }
                        }
                        
                        if let fileHashes = fileHashes, !fileHashes.isEmpty {
                            maybeAddError(key: .translationFiles(hashes: fileHashes), value: value, entries: &result, errorIndex: &errorIndex)
                        }
                    }
                    
                    for i in 0 ..< self.translations.count {
                        var error: String?
                        switch self.translations[i] {
                            case .local:
                                break
                            case let .remote(file):
                                switch self.documentState {
                                case let .identity(identity):
                                    if let document = identity.document {
                                        switch document.type {
                                        case .passport:
                                            error = self.previousValues[.passport]?.errors[.translationFile(hash: file.fileHash)]
                                        case .internalPassport:
                                            error = self.previousValues[.internalPassport]?.errors[.translationFile(hash: file.fileHash)]
                                        case .driversLicense:
                                            error = self.previousValues[.driversLicense]?.errors[.translationFile(hash: file.fileHash)]
                                        case .idCard:
                                            error = self.previousValues[.idCard]?.errors[.translationFile(hash: file.fileHash)]
                                        }
                                    }
                                case let .address(address):
                                    if let document = address.document {
                                        switch document {
                                        case .passportRegistration:
                                            error = self.previousValues[.passportRegistration]?.errors[.translationFile(hash: file.fileHash)]
                                        case .temporaryRegistration:
                                            error = self.previousValues[.temporaryRegistration]?.errors[.translationFile(hash: file.fileHash)]
                                        case .bankStatement:
                                            error = self.previousValues[.bankStatement]?.errors[.translationFile(hash: file.fileHash)]
                                        case .utilityBill:
                                            error = self.previousValues[.utilityBill]?.errors[.translationFile(hash: file.fileHash)]
                                        case .rentalAgreement:
                                            error = self.previousValues[.rentalAgreement]?.errors[.translationFile(hash: file.fileHash)]
                                        }
                                    }
                            }
                        }
                        result.append(.entry(SecureIdDocumentFormEntry.translation(i, self.translations[i], error)))
                    }
                    result.append(.entry(SecureIdDocumentFormEntry.addTranslation(!self.translations.isEmpty)))
                    result.append(.entry(SecureIdDocumentFormEntry.translationsInfo))
                    result.append(.spacer)
                }
                
                if !self.previousValues.isEmpty {
                    if let last = result.last, case .spacer = last {
                    } else {
                        result.append(.spacer)
                    }
                    result.append(.entry(SecureIdDocumentFormEntry.deleteDocument(.identity, identity.document != nil)))
                }
                
                return result
            case let .address(address):
                var result: [FormControllerItemEntry<SecureIdDocumentFormEntry>] = []
                var errorIndex = 0
                
                if let details = address.details {
                    result.append(.entry(SecureIdDocumentFormEntry.infoHeader(.address)))
                    
                    let previousValue: SecureIdValueWithContext? = self.previousValues[.address]
                    let valueErrorKey: SecureIdValueContentErrorKey = .value(.address)
                    if let previousValue = previousValue {
                        maybeAddError(key: valueErrorKey, value: previousValue, entries: &result, errorIndex: &errorIndex)
                    }
                    result.append(.entry(SecureIdDocumentFormEntry.street1(details.street1, self.previousValues[.address]?.errors[.field(.address(.streetLine1))])))
                    result.append(.entry(SecureIdDocumentFormEntry.street2(details.street2, self.previousValues[.address]?.errors[.field(.address(.streetLine2))])))
                    result.append(.entry(SecureIdDocumentFormEntry.city(details.city, self.previousValues[.address]?.errors[.field(.address(.city))])))
                    result.append(.entry(SecureIdDocumentFormEntry.state(details.state, self.previousValues[.address]?.errors[.field(.address(.state))])))
                    result.append(.entry(SecureIdDocumentFormEntry.countryCode(.address, details.countryCode, self.previousValues[.address]?.errors[.field(.address(.countryCode))])))
                    result.append(.entry(SecureIdDocumentFormEntry.postcode(details.postcode, self.previousValues[.address]?.errors[.field(.address(.postCode))])))
                }
                
                if let document = address.document {
                    if let last = result.last, case .spacer = last {
                    } else {
                        result.append(.spacer)
                    }
                    result.append(.entry(SecureIdDocumentFormEntry.scansHeader))
                    
                    let filesType: SecureIdValueKey
                    switch document {
                        case .passportRegistration:
                            filesType = .passportRegistration
                        case .temporaryRegistration:
                            filesType = .temporaryRegistration
                        case .bankStatement:
                            filesType = .bankStatement
                        case .rentalAgreement:
                            filesType = .rentalAgreement
                        case .utilityBill:
                            filesType = .utilityBill
                    }
                    
                    if let value = self.previousValues[filesType] {
                        var fileHashes: Set<Data>? = Set()
                        loop: for document in self.documents {
                            switch document {
                                case .local:
                                    fileHashes = nil
                                    break loop
                                case let .remote(file):
                                    fileHashes?.insert(file.fileHash)
                            }
                        }
                        
                        if let fileHashes = fileHashes, !fileHashes.isEmpty {
                            maybeAddError(key: .files(hashes: fileHashes), value: value, entries: &result, errorIndex: &errorIndex)
                        }
                    }
                    
                    for i in 0 ..< self.documents.count {
                        var error: String?
                        switch self.documents[i] {
                        case .local:
                            break
                        case let .remote(file):
                            switch self.documentState {
                            case let .identity(identity):
                                if let document = identity.document {
                                    switch document.type {
                                    case .passport:
                                        error = self.previousValues[.passport]?.errors[.file(hash: file.fileHash)]
                                    case .internalPassport:
                                        error = self.previousValues[.internalPassport]?.errors[.file(hash: file.fileHash)]
                                    case .driversLicense:
                                        error = self.previousValues[.driversLicense]?.errors[.file(hash: file.fileHash)]
                                    case .idCard:
                                        error = self.previousValues[.idCard]?.errors[.file(hash: file.fileHash)]
                                    }
                                }
                            case let .address(address):
                                if let document = address.document {
                                    switch document {
                                    case .passportRegistration:
                                        error = self.previousValues[.passportRegistration]?.errors[.file(hash: file.fileHash)]
                                    case .temporaryRegistration:
                                        error = self.previousValues[.temporaryRegistration]?.errors[.file(hash: file.fileHash)]
                                    case .bankStatement:
                                        error = self.previousValues[.bankStatement]?.errors[.file(hash: file.fileHash)]
                                    case .utilityBill:
                                        error = self.previousValues[.utilityBill]?.errors[.file(hash: file.fileHash)]
                                    case .rentalAgreement:
                                        error = self.previousValues[.rentalAgreement]?.errors[.file(hash: file.fileHash)]
                                    }
                                }
                            }
                        }
                        result.append(.entry(SecureIdDocumentFormEntry.scan(i, self.documents[i], error)))
                    }
                    result.append(.entry(SecureIdDocumentFormEntry.addScan(!self.documents.isEmpty)))
                    result.append(.entry(SecureIdDocumentFormEntry.scansInfo(.address)))
                    result.append(.spacer)
                }
                
                if let document = address.document, self.translationsRequired || self.requestOptionalData {
                    if let last = result.last, case .spacer = last {
                    } else {
                        result.append(.spacer)
                    }
                    
                    result.append(.entry(SecureIdDocumentFormEntry.translationsHeader))
                    
                    let filesType: SecureIdValueKey
                    switch document {
                        case .passportRegistration:
                            filesType = .passportRegistration
                        case .temporaryRegistration:
                            filesType = .temporaryRegistration
                        case .bankStatement:
                            filesType = .bankStatement
                        case .rentalAgreement:
                            filesType = .rentalAgreement
                        case .utilityBill:
                            filesType = .utilityBill
                    }
                    
                    if let value = self.previousValues[filesType] {
                        var fileHashes: Set<Data>? = Set()
                        loop: for document in self.translations {
                            switch document {
                                case .local:
                                    fileHashes = nil
                                    break loop
                                case let .remote(file):
                                    fileHashes?.insert(file.fileHash)
                            }
                        }
                        
                        if let fileHashes = fileHashes, !fileHashes.isEmpty {
                            maybeAddError(key: .translationFiles(hashes: fileHashes), value: value, entries: &result, errorIndex: &errorIndex)
                        }
                    }
                    
                    for i in 0 ..< self.translations.count {
                        var error: String?
                        switch self.translations[i] {
                            case .local:
                                break
                            case let .remote(file):
                                switch self.documentState {
                                case let .address(address):
                                    if let document = address.document {
                                        switch document {
                                        case .passportRegistration:
                                            error = self.previousValues[.passportRegistration]?.errors[.translationFile(hash: file.fileHash)]
                                        case .temporaryRegistration:
                                            error = self.previousValues[.temporaryRegistration]?.errors[.translationFile(hash: file.fileHash)]
                                        case .bankStatement:
                                            error = self.previousValues[.bankStatement]?.errors[.translationFile(hash: file.fileHash)]
                                        case .utilityBill:
                                            error = self.previousValues[.utilityBill]?.errors[.translationFile(hash: file.fileHash)]
                                        case .rentalAgreement:
                                            error = self.previousValues[.rentalAgreement]?.errors[.translationFile(hash: file.fileHash)]
                                        }
                                    }
                                default:
                                    break
                            }
                        }
                        result.append(.entry(SecureIdDocumentFormEntry.translation(i, self.translations[i], error)))
                    }
                    result.append(.entry(SecureIdDocumentFormEntry.addTranslation(!self.translations.isEmpty)))
                    result.append(.entry(SecureIdDocumentFormEntry.translationsInfo))
                    result.append(.spacer)
                }
                
                if !self.previousValues.isEmpty {
                    if let last = result.last, case .spacer = last {
                    } else {
                        result.append(.spacer)
                    }
                    result.append(.entry(SecureIdDocumentFormEntry.deleteDocument(.address, address.document != nil)))
                }
                
                return result
        }
    }
    
    func actionInputState() -> SecureIdDocumentFormInputState {
        switch self.actionState {
            case .deleting, .saving:
                return .inProgress
            default:
                break
        }
        
        var badHashes: Set<Data> = []
        var badFileHashes: Set<Data>?
        var badTranslationHashes: Set<Data>?
        for value in self.previousValues {
            for error in value.value.errors {
                switch error.key {
                    case .value(value.key), .field:
                        return .saveNotAvailable
                    case let .file(hash), let .selfie(hash), let .frontSide(hash), let .backSide(hash), let .translationFile(hash):
                        badHashes.insert(hash)
                    case let .files(hashes):
                        badFileHashes = hashes
                    case let .translationFiles(hashes):
                        badTranslationHashes = hashes
                    default:
                        break
                }
            }
        }
        
        var documentsRequired = false
        
        switch self.documentState {
            case let .identity(identity):
                if !identity.isComplete() {
                    return .saveNotAvailable
                }
            case let .address(address):
                if !address.isComplete() {
                    return .saveNotAvailable
                }
                if address.document != nil {
                    documentsRequired = true
                }
        }
        
        func isDocumentReady(_ document: SecureIdVerificationDocument?, badHashes: Set<Data>? = nil) -> Bool {
            if let document = document {
                switch document {
                    case let .local(local):
                        switch local.state {
                            case .uploading:
                                return false
                            case .uploaded:
                                return true
                        }
                    case let .remote(reference):
                        if let badHashes = badHashes {
                            return !badHashes.contains(reference.fileHash)
                        } else {
                            return true
                        }
                    }
            } else {
                return false
            }
        }
        
        if self.frontSideRequired {
            guard isDocumentReady(self.frontSideDocument, badHashes: badHashes) else {
                return .saveNotAvailable
            }
        }
        
        if self.backSideRequired {
            guard isDocumentReady(self.backSideDocument, badHashes: badHashes) else {
                return .saveNotAvailable
            }
        }
        
        if self.selfieRequired {
            guard isDocumentReady(self.selfieDocument, badHashes: badHashes) else {
                return .saveNotAvailable
            }
        }
        
        var fileHashes: Set<Data> = []
        for document in self.documents {
            guard isDocumentReady(document) else {
                return .saveNotAvailable
            }
            switch document {
                case let .remote(reference):
                    fileHashes.insert(reference.fileHash)
                case let .local(document):
                    if case let .uploaded(file) = document.state {
                        fileHashes.insert(file.fileHash)
                    }
            }
        }
        if documentsRequired && self.documents.isEmpty {
            return .saveNotAvailable
        }
        if let badFileHashes = badFileHashes, badFileHashes == fileHashes {
            return .saveNotAvailable
        }
        
        var translationHashes: Set<Data> = []
        for document in self.translations {
            guard isDocumentReady(document) else {
                return .saveNotAvailable
            }
            switch document {
                case let .remote(reference):
                    translationHashes.insert(reference.fileHash)
                case let .local(document):
                    if case let .uploaded(file) = document.state {
                        translationHashes.insert(file.fileHash)
                    }
            }
        }
        if self.translationsRequired && self.translations.isEmpty {
            return .saveNotAvailable
        }
        if let badTranslationHashes = badTranslationHashes, badTranslationHashes == translationHashes {
            return .saveNotAvailable
        }
        
        return .saveAvailable
    }
}

extension SecureIdDocumentFormState {
    init(requestedData: SecureIdDocumentFormRequestedData, values: [SecureIdValueKey: SecureIdValueWithContext], requestOptionalData: Bool, primaryLanguageByCountry: [String: String]) {
        switch requestedData {
            case let .identity(details, document, selfie, translations):
                var previousValues: [SecureIdValueKey: SecureIdValueWithContext] = [:]
                var detailsState: SecureIdDocumentFormIdentityDetailsState?
                if let details = details {
                    if let value = values[.personalDetails], case let .personalDetails(personalDetailsValue) = value.value {
                        previousValues[.personalDetails] = value
                        detailsState = SecureIdDocumentFormIdentityDetailsState(primaryLanguageByCountry: primaryLanguageByCountry, nativeNameRequired: details.nativeNames, firstName: personalDetailsValue.latinName.firstName, middleName: personalDetailsValue.latinName.middleName, lastName: personalDetailsValue.latinName.lastName, nativeFirstName: personalDetailsValue.nativeName?.firstName ?? "", nativeMiddleName: personalDetailsValue.nativeName?.middleName ?? "", nativeLastName: personalDetailsValue.nativeName?.lastName ?? "", countryCode: personalDetailsValue.countryCode, residenceCountryCode: personalDetailsValue.residenceCountryCode, birthdate: personalDetailsValue.birthdate, gender: personalDetailsValue.gender)
                    } else {
                        detailsState = SecureIdDocumentFormIdentityDetailsState(primaryLanguageByCountry: primaryLanguageByCountry, nativeNameRequired: details.nativeNames, firstName: "", middleName: "", lastName: "", nativeFirstName: "", nativeMiddleName: "", nativeLastName: "", countryCode: "", residenceCountryCode: "", birthdate: nil, gender: nil)
                    }
                }
                var documentState: SecureIdDocumentFormIdentityDocumentState?
                var verificationDocuments: [SecureIdVerificationDocument] = []
                var selfieDocument: SecureIdVerificationDocument?
                var frontSideRequired: Bool = false
                var backSideRequired: Bool = false
                var frontSideDocument: SecureIdVerificationDocument?
                var backSideDocument: SecureIdVerificationDocument?
                var translationDocuments: [SecureIdVerificationDocument] = []
                if let document = document {
                    var identifier: String = ""
                    var expiryDate: DocumentExpirationDate = .notSet
                    switch document {
                        case .passport:
                            if let value = values[.passport], case let .passport(passport) = value.value {
                                previousValues[value.value.key] = value
                                identifier = passport.identifier
                                expiryDate = passport.expiryDate.flatMap(DocumentExpirationDate.date) ?? .doesNotExpire
                                verificationDocuments = passport.verificationDocuments.compactMap(SecureIdVerificationDocument.init)
                                frontSideDocument = passport.frontSideDocument.flatMap(SecureIdVerificationDocument.init)
                                selfieDocument = passport.selfieDocument.flatMap(SecureIdVerificationDocument.init)
                                translationDocuments = passport.translations.compactMap(SecureIdVerificationDocument.init)
                            }
                            frontSideRequired = true
                        case .internalPassport:
                            if let value = values[.internalPassport], case let .internalPassport(internalPassport) = value.value {
                                previousValues[value.value.key] = value
                                identifier = internalPassport.identifier
                                expiryDate = internalPassport.expiryDate.flatMap(DocumentExpirationDate.date) ?? .doesNotExpire
                                verificationDocuments = internalPassport.verificationDocuments.compactMap(SecureIdVerificationDocument.init)
                                selfieDocument = internalPassport.selfieDocument.flatMap(SecureIdVerificationDocument.init)
                                frontSideDocument = internalPassport.frontSideDocument.flatMap(SecureIdVerificationDocument.init)
                                translationDocuments = internalPassport.translations.compactMap(SecureIdVerificationDocument.init)
                            }
                            frontSideRequired = true
                        case .driversLicense:
                            if let value = values[.driversLicense], case let .driversLicense(driversLicense) = value.value {
                                previousValues[value.value.key] = value
                                identifier = driversLicense.identifier
                                expiryDate = driversLicense.expiryDate.flatMap(DocumentExpirationDate.date) ?? .doesNotExpire
                                verificationDocuments = driversLicense.verificationDocuments.compactMap(SecureIdVerificationDocument.init)
                                selfieDocument = driversLicense.selfieDocument.flatMap(SecureIdVerificationDocument.init)
                                frontSideDocument = driversLicense.frontSideDocument.flatMap(SecureIdVerificationDocument.init)
                                backSideDocument = driversLicense.backSideDocument.flatMap(SecureIdVerificationDocument.init)
                                translationDocuments = driversLicense.translations.compactMap(SecureIdVerificationDocument.init)
                            }
                            frontSideRequired = true
                            backSideRequired = true
                        case .idCard:
                            if let value = values[.idCard], case let .idCard(idCard) = value.value {
                                previousValues[value.value.key] = value
                                identifier = idCard.identifier
                                expiryDate = idCard.expiryDate.flatMap(DocumentExpirationDate.date) ?? .doesNotExpire
                                verificationDocuments = idCard.verificationDocuments.compactMap(SecureIdVerificationDocument.init)
                                selfieDocument = idCard.selfieDocument.flatMap(SecureIdVerificationDocument.init)
                                frontSideDocument = idCard.frontSideDocument.flatMap(SecureIdVerificationDocument.init)
                                backSideDocument = idCard.backSideDocument.flatMap(SecureIdVerificationDocument.init)
                                translationDocuments = idCard.translations.compactMap(SecureIdVerificationDocument.init)
                            }
                            frontSideRequired = true
                            backSideRequired = true
                    }
                    documentState = SecureIdDocumentFormIdentityDocumentState(type: document, identifier: identifier, expiryDate: expiryDate)
                }
                let formState = SecureIdDocumentFormIdentityState(details: detailsState, document: documentState)
                self.init(previousValues: previousValues, documentState: .identity(formState), documents: verificationDocuments, selfieRequired: selfie, selfieDocument: selfieDocument, frontSideRequired: frontSideRequired, frontSideDocument: frontSideDocument, backSideRequired: backSideRequired, backSideDocument: backSideDocument, translationsRequired: translations, translations: translationDocuments, actionState: .none, requestOptionalData: requestOptionalData)
            case let .address(details, document, translations):
                var previousValues: [SecureIdValueKey: SecureIdValueWithContext] = [:]
                var detailsState: SecureIdDocumentFormAddressDetailsState?
                var documentState: SecureIdRequestedAddressDocument?
                var verificationDocuments: [SecureIdVerificationDocument] = []
                var translationDocuments: [SecureIdVerificationDocument] = []
                
                if details {
                    if let value = values[.address], case let .address(address) = value.value {
                        previousValues[value.value.key] = value
                        detailsState = SecureIdDocumentFormAddressDetailsState(street1: address.street1, street2: address.street2, city: address.city, state: address.state, countryCode: address.countryCode, postcode: address.postcode)
                    } else {
                        detailsState = SecureIdDocumentFormAddressDetailsState(street1: "", street2: "", city: "", state: "", countryCode: "", postcode: "")
                    }
                }
                if let document = document {
                    switch document {
                    case .passportRegistration:
                        if let value = values[.passportRegistration], case let .passportRegistration(passportRegistration) = value.value {
                            previousValues[value.value.key] = value
                            verificationDocuments = passportRegistration.verificationDocuments.compactMap(SecureIdVerificationDocument.init)
                            translationDocuments = passportRegistration.translations.compactMap(SecureIdVerificationDocument.init)
                        }
                    case .temporaryRegistration:
                        if let value = values[.temporaryRegistration], case let .temporaryRegistration(temporaryRegistration) = value.value {
                            previousValues[value.value.key] = value
                            verificationDocuments = temporaryRegistration.verificationDocuments.compactMap(SecureIdVerificationDocument.init)
                            translationDocuments = temporaryRegistration.translations.compactMap(SecureIdVerificationDocument.init)
                        }
                    case .bankStatement:
                        if let value = values[.bankStatement], case let .bankStatement(bankStatement) = value.value {
                            previousValues[value.value.key] = value
                            verificationDocuments = bankStatement.verificationDocuments.compactMap(SecureIdVerificationDocument.init)
                            translationDocuments = bankStatement.translations.compactMap(SecureIdVerificationDocument.init)
                        }
                    case .utilityBill:
                        if let value = values[.utilityBill], case let .utilityBill(utilityBill) = value.value {
                            previousValues[value.value.key] = value
                            verificationDocuments = utilityBill.verificationDocuments.compactMap(SecureIdVerificationDocument.init)
                            translationDocuments = utilityBill.translations.compactMap(SecureIdVerificationDocument.init)
                        }
                    case .rentalAgreement:
                        if let value = values[.rentalAgreement], case let .rentalAgreement(rentalAgreement) = value.value {
                            previousValues[value.value.key] = value
                            verificationDocuments = rentalAgreement.verificationDocuments.compactMap(SecureIdVerificationDocument.init)
                            translationDocuments = rentalAgreement.translations.compactMap(SecureIdVerificationDocument.init)
                        }
                    }
                    documentState = document
                }
                let formState = SecureIdDocumentFormAddressState(details: detailsState, document: documentState)
                self.init(previousValues: previousValues, documentState: .address(formState), documents: verificationDocuments, selfieRequired: false, selfieDocument: nil, frontSideRequired: false, frontSideDocument: nil, backSideRequired: false, backSideDocument: nil, translationsRequired: translations, translations: translationDocuments, actionState: .none, requestOptionalData: requestOptionalData)
        }
    }
    
    func makeValues() -> [SecureIdValueKey: SecureIdValue]? {
        var verificationDocuments: [SecureIdVerificationDocumentReference] = []
        for document in self.documents {
            switch document {
                case let .remote(file):
                    verificationDocuments.append(.remote(file))
                case let .local(file):
                    switch file.state {
                        case let .uploaded(file):
                            verificationDocuments.append(.uploaded(file))
                        case .uploading:
                            return nil
                    }
            }
        }
        var selfieDocument: SecureIdVerificationDocumentReference?
        if let document = self.selfieDocument {
            switch document {
                case let .remote(file):
                    selfieDocument = .remote(file)
                case let .local(file):
                    switch file.state {
                        case let .uploaded(file):
                            selfieDocument = .uploaded(file)
                        case .uploading:
                            return nil
                    }
            }
        }
        var frontSideDocument: SecureIdVerificationDocumentReference?
        if let document = self.frontSideDocument {
            switch document {
                case let .remote(file):
                    frontSideDocument = .remote(file)
                case let .local(file):
                    switch file.state {
                        case let .uploaded(file):
                            frontSideDocument = .uploaded(file)
                        case .uploading:
                            return nil
                    }
            }
        }
        var backSideDocument: SecureIdVerificationDocumentReference?
        if let document = self.backSideDocument {
            switch document {
                case let .remote(file):
                    backSideDocument = .remote(file)
                case let .local(file):
                    switch file.state {
                        case let .uploaded(file):
                            backSideDocument = .uploaded(file)
                        case .uploading:
                            return nil
                    }
            }
        }
        var translationDocuments: [SecureIdVerificationDocumentReference] = []
        for document in self.translations {
            switch document {
                case let .remote(file):
                    translationDocuments.append(.remote(file))
                case let .local(file):
                    switch file.state {
                        case let .uploaded(file):
                            translationDocuments.append(.uploaded(file))
                        case .uploading:
                            return nil
                    }
            }
        }
        
        switch self.documentState {
            case let .identity(identity):
                var values: [SecureIdValueKey: SecureIdValue] = [:]
                if let details = identity.details {
                    guard !details.firstName.isEmpty else {
                        return nil
                    }
                    guard !details.lastName.isEmpty else {
                        return nil
                    }
                    guard !details.countryCode.isEmpty else {
                        return nil
                    }
                    guard !details.residenceCountryCode.isEmpty else {
                        return nil
                    }
                    guard let birthdate = details.birthdate else {
                        return nil
                    }
                    guard let gender = details.gender else {
                        return nil
                    }
                    values[.personalDetails] = .personalDetails(SecureIdPersonalDetailsValue(latinName: SecureIdPersonName(firstName: details.firstName, lastName: details.lastName, middleName: details.middleName), nativeName: SecureIdPersonName(firstName: details.nativeFirstName, lastName: details.nativeLastName, middleName: details.nativeMiddleName), birthdate: birthdate, countryCode: details.countryCode, residenceCountryCode: details.residenceCountryCode, gender: gender))
                }
                if let document = identity.document {
                    guard !document.identifier.isEmpty else {
                        return nil
                    }
                    
                    let expirationDate: SecureIdDate?
                    switch document.expiryDate {
                        case .notSet:
                            return nil
                        case .doesNotExpire:
                            expirationDate = nil
                        case let .date(value):
                            expirationDate = value
                    }
                    
                    switch document.type {
                        case .passport:
                            values[.passport] = .passport(SecureIdPassportValue(identifier: document.identifier, expiryDate: expirationDate, verificationDocuments: verificationDocuments, translations: translationDocuments, selfieDocument: selfieDocument, frontSideDocument: frontSideDocument))
                        case .internalPassport:
                            values[.internalPassport] = .internalPassport(SecureIdInternalPassportValue(identifier: document.identifier, expiryDate: expirationDate, verificationDocuments: verificationDocuments, translations: translationDocuments, selfieDocument: selfieDocument, frontSideDocument: frontSideDocument))
                        case .driversLicense:
                            values[.driversLicense] = .driversLicense(SecureIdDriversLicenseValue(identifier: document.identifier, expiryDate: expirationDate, verificationDocuments: verificationDocuments, translations: translationDocuments, selfieDocument: selfieDocument, frontSideDocument: frontSideDocument, backSideDocument: backSideDocument))
                        case .idCard:
                            values[.idCard] = .idCard(SecureIdIDCardValue(identifier: document.identifier, expiryDate: expirationDate, verificationDocuments: verificationDocuments, translations: translationDocuments, selfieDocument: selfieDocument, frontSideDocument: frontSideDocument, backSideDocument: backSideDocument))
                    }
                }
                return values
            case let .address(address):
                var values: [SecureIdValueKey: SecureIdValue] = [:]
                if let details = address.details {
                    guard !details.street1.isEmpty else {
                        return nil
                    }
                    guard !details.city.isEmpty else {
                        return nil
                    }
                    guard !details.countryCode.isEmpty else {
                        return nil
                    }
                    guard !details.postcode.isEmpty else {
                        return nil
                    }
                    values[.address] = .address(SecureIdAddressValue(street1: details.street1, street2: details.street2, city: details.city, state: details.state, countryCode: details.countryCode, postcode: details.postcode))
                }
                if let document = address.document {
                    guard !verificationDocuments.isEmpty else {
                        return nil
                    }
                    switch document {
                        case .passportRegistration:
                            values[.passportRegistration] = .passportRegistration(SecureIdPassportRegistrationValue(verificationDocuments: verificationDocuments, translations: translationDocuments))
                        case .temporaryRegistration:
                            values[.temporaryRegistration] = .temporaryRegistration(SecureIdTemporaryRegistrationValue(verificationDocuments: verificationDocuments, translations: translationDocuments))
                        case .bankStatement:
                            values[.bankStatement] = .bankStatement(SecureIdBankStatementValue(verificationDocuments: verificationDocuments, translations: translationDocuments))
                        case .utilityBill:
                            values[.utilityBill] = .utilityBill(SecureIdUtilityBillValue(verificationDocuments: verificationDocuments, translations: translationDocuments))
                        case .rentalAgreement:
                            values[.rentalAgreement] = .rentalAgreement(SecureIdRentalAgreementValue(verificationDocuments: verificationDocuments, translations: translationDocuments))
                    }
                }
                return values
        }
    }
}

private func removeDocumentWithId(_ innerState: SecureIdDocumentFormState, id: SecureIdVerificationDocumentId) -> SecureIdDocumentFormState {
    var innerState = innerState
    
    if let selfieDocument = innerState.selfieDocument, selfieDocument.id == id {
        innerState.selfieDocument = nil
    }
    
    if let frontSideDocument = innerState.frontSideDocument, frontSideDocument.id == id {
        innerState.frontSideDocument = nil
    }
    
    if let backSideDocument = innerState.backSideDocument, backSideDocument.id == id {
        innerState.backSideDocument = nil
    }
    
    for i in 0 ..< innerState.documents.count {
        if innerState.documents[i].id == id {
            innerState.documents.remove(at: i)
            break
        }
    }
    
    for i in 0 ..< innerState.translations.count {
        if innerState.translations[i].id == id {
            innerState.translations.remove(at: i)
            break
        }
    }
    
    return innerState
}

enum SecureIdDocumentFormEntryId: Hashable {
    case scanYourPassport
    case scanYourPassportInfo
    case scansHeader
    case scan(SecureIdVerificationDocumentId)
    case addScan
    case scansInfo
    case infoHeader
    case identifier
    case firstName
    case middleName
    case lastName
    case nativeInfoHeader
    case nativeFirstName
    case nativeMiddleName
    case nativeLastName
    case nativeInfo
    case gender
    case countryCode
    case residenceCountryCode
    case birthdate
    case expiryDate
    case deleteDocument
    case requestedDocumentsHeader
    case selfie
    case frontSide
    case backSide
    case documentsInfo
    case translationsHeader
    case translation(SecureIdVerificationDocumentId)
    case addTranslation
    case translationsInfo
    
    case street1
    case street2
    case city
    case state
    case postcode
    
    case error(SecureIdValueContentErrorKey)
}

enum SecureIdDocumentFormEntryCategory {
    case identity
    case address
}

enum SecureIdDocumentFormEntry: FormControllerEntry {
    case scanYourPassport
    case scanYourPassportInfo
    case scansHeader
    case scan(Int, SecureIdVerificationDocument, String?)
    case addScan(Bool)
    case scansInfo(SecureIdDocumentFormEntryCategory)
    case infoHeader(SecureIdDocumentFormEntryCategory)
    case identifier(String, String?)
    case firstName(String, String?)
    case middleName(String, String?)
    case lastName(String, String?)
    case nativeInfoHeader(String)
    case nativeFirstName(String, String?)
    case nativeMiddleName(String, String?)
    case nativeLastName(String, String?)
    case nativeInfo(String, String)
    case gender(SecureIdGender?, String?)
    case countryCode(SecureIdDocumentFormEntryCategory, String, String?)
    case residenceCountryCode(String, String?)
    case birthdate(SecureIdDate?, String?)
    case expiryDate(DocumentExpirationDate, String?)
    case deleteDocument(SecureIdDocumentFormEntryCategory, Bool)
    case requestedDocumentsHeader
    case selfie(Int, SecureIdVerificationDocument?, String?)
    case frontSide(Int, SecureIdRequestedIdentityDocument?, SecureIdVerificationDocument?, String?)
    case backSide(Int, SecureIdRequestedIdentityDocument?, SecureIdVerificationDocument?, String?)
    case documentsInfo(SecureIdDocumentFormEntryCategory)
    case translationsHeader
    case translation(Int, SecureIdVerificationDocument, String?)
    case addTranslation(Bool)
    case translationsInfo
    case error(Int, String, SecureIdValueContentErrorKey)
    
    case street1(String, String?)
    case street2(String, String?)
    case city(String, String?)
    case state(String, String?)
    case postcode(String, String?)
    
    var stableId: SecureIdDocumentFormEntryId {
        switch self {
            case .scanYourPassport:
                return .scanYourPassport
            case .scanYourPassportInfo:
                return .scanYourPassportInfo
            case .scansHeader:
                return .scansHeader
            case let .scan(_, document, _):
                return .scan(document.id)
            case .addScan:
                return .addScan
            case .scansInfo:
                return .scansInfo
            case .infoHeader:
                return .infoHeader
            case .identifier:
                return .identifier
            case .firstName:
                return .firstName
            case .middleName:
                return .middleName
            case .lastName:
                return .lastName
            case .nativeInfoHeader:
                return .nativeInfoHeader
            case .nativeFirstName:
                return .nativeFirstName
            case .nativeMiddleName:
                return .nativeMiddleName
            case .nativeLastName:
                return .nativeLastName
            case .nativeInfo:
                return .nativeInfo
            case .countryCode:
                return .countryCode
            case .residenceCountryCode:
                return .residenceCountryCode
            case .birthdate:
                return .birthdate
            case .expiryDate:
                return .expiryDate
            case .deleteDocument:
                return .deleteDocument
            case .street1:
                return .street1
            case .street2:
                return .street2
            case .city:
                return .city
            case .state:
                return .state
            case .postcode:
                return .postcode
            case .gender:
                return .gender
            case .requestedDocumentsHeader:
                return .requestedDocumentsHeader
            case .selfie:
                return .selfie
            case .frontSide:
                return .frontSide
            case .backSide:
                return .backSide
            case .documentsInfo:
                return .documentsInfo
            case .translationsHeader:
                return .translationsHeader
            case let .translation(_, document, _):
                return .translation(document.id)
            case .addTranslation:
                return .addTranslation
            case .translationsInfo:
                return .translationsInfo
            case let .error(_, _, key):
                return .error(key)
        }
    }
    
    func isEqual(to: SecureIdDocumentFormEntry) -> Bool {
        switch self {
            case .scanYourPassport:
                if case .scanYourPassport = to {
                    return true
                } else {
                    return false
                }
            case .scanYourPassportInfo:
                if case .scanYourPassportInfo = to {
                    return true
                } else {
                    return false
                }
            case .scansHeader:
                if case .scansHeader = to {
                    return true
                } else {
                    return false
                }
            case let .scan(lhsId, lhsDocument, lhsError):
                if case let .scan(rhsId, rhsDocument, rhsError) = to, lhsId == rhsId, lhsDocument == rhsDocument, lhsError == rhsError {
                    return true
                } else {
                    return false
                }
            case let .addScan(hasAny):
                if case .addScan(hasAny) = to {
                    return true
                } else {
                    return false
                }
            case let .scansInfo(value):
                if case .scansInfo(value) = to {
                    return true
                } else {
                    return false
                }
            case let .infoHeader(value):
                if case .infoHeader(value) = to {
                    return true
                } else {
                    return false
                }
            case let .identifier(value, error):
                if case .identifier(value, error) = to {
                    return true
                } else {
                    return false
                }
            case let .firstName(value, error):
                if case .firstName(value, error) = to {
                    return true
                } else {
                    return false
                }
            case let .middleName(value, error):
                if case .middleName(value, error) = to {
                    return true
                } else {
                    return false
                }
            case let .lastName(value, error):
                if case .lastName(value, error) = to {
                    return true
                } else {
                    return false
                }
            case let .nativeInfoHeader(language):
                if case .nativeInfoHeader(language) = to {
                    return true
                } else {
                    return false
                }
            case let .nativeFirstName(value, error):
                if case .nativeFirstName(value, error) = to {
                    return true
                } else {
                    return false
                }
            case let .nativeMiddleName(value, error):
                if case .nativeMiddleName(value, error) = to {
                    return true
                } else {
                    return false
                }
            case let .nativeLastName(value, error):
                if case .nativeLastName(value, error) = to {
                    return true
                } else {
                    return false
                }
            case let .nativeInfo(language, countryCode):
                if case .nativeInfo(language, countryCode) = to {
                    return true
                } else {
                    return false
                }
            case let .gender(value, error):
                if case .gender(value, error) = to {
                    return true
                } else {
                    return false
                }
            case let .countryCode(category, value, error):
                if case .countryCode(category, value, error) = to {
                    return true
                } else {
                    return false
                }
            case let .residenceCountryCode(value, error):
                if case .residenceCountryCode(value, error) = to {
                    return true
                } else {
                    return false
                }
            case let .birthdate(lhsValue, lhsError):
                if case let .birthdate(rhsValue, rhsError) = to, lhsValue == rhsValue, lhsError == rhsError {
                    return true
                } else {
                    return false
                }
            case let .expiryDate(lhsValue, lhsError):
                if case let .expiryDate(rhsValue, rhsError) = to, lhsValue == rhsValue, lhsError == rhsError {
                    return true
                } else {
                    return false
                }
            case let .deleteDocument(lhsCategory, lhsHasDocument):
                if case let .deleteDocument(rhsCategory, rhsHasDocument) = to, lhsCategory == rhsCategory, lhsHasDocument == rhsHasDocument {
                    return true
                } else {
                    return false
                }
            case let .street1(value, error):
                if case .street1(value, error) = to {
                    return true
                } else {
                    return false
                }
            case let .street2(value, error):
                if case .street2(value, error) = to {
                    return true
                } else {
                    return false
                }
            case let .city(value, error):
                if case .city(value, error) = to {
                    return true
                } else {
                    return false
                }
            case let .state(value, error):
                if case .state(value, error) = to {
                    return true
                } else {
                    return false
                }
            case let .postcode(value, error):
                if case .postcode(value, error) = to {
                    return true
                } else {
                    return false
                }
            case .requestedDocumentsHeader:
                if case .requestedDocumentsHeader = to {
                    return true
                } else {
                    return false
                }
            case let .selfie(index, document, error):
                if case .selfie(index, document, error) = to {
                    return true
                } else {
                    return false
                }
            case let .frontSide(index, type, document, error):
                if case .frontSide(index, type, document, error) = to {
                    return true
                } else {
                    return false
                }
            case let .backSide(index, type, document, error):
                if case .backSide(index, type, document, error) = to {
                    return true
                } else {
                    return false
                }
            case let .documentsInfo(category):
                if case .documentsInfo(category) = to {
                    return true
                } else {
                    return false
                }
            case .translationsHeader:
                if case .translationsHeader = to {
                    return true
                } else {
                    return false
                }
            case let .translation(index, document, error):
                if case .translation(index, document, error) = to {
                    return true
                } else {
                    return false
                }
            case let .addTranslation(hasAny):
                if case .addTranslation(hasAny) = to {
                    return true
                } else{
                    return false
                }
            case .translationsInfo:
                if case .translationsInfo = to {
                    return true
                } else {
                    return false
                }
            case let .error(index, text, key):
                if case .error(index, text, key) = to {
                    return true
                } else {
                    return false
                }
        }
    }
    
    func item(params: SecureIdDocumentFormParams, strings: PresentationStrings) -> FormControllerItem {
        switch self {
            case .scanYourPassport:
                return FormControllerActionItem(type: .accent, title: strings.Passport_ScanPassport, activated: {
                    params.scanPassport()
                })
            case .scanYourPassportInfo:
                return FormControllerTextItem(text: strings.Passport_ScanPassportHelp)
            case .scansHeader:
                return FormControllerHeaderItem(text: strings.Passport_ScansHeader)
            case let .scan(index, document, error):
                return SecureIdValueFormFileItem(account: params.account, context: params.context, document: document, placeholder: nil, title: strings.Passport_Scans_ScanIndex("\(index + 1)").string, label: error.flatMap(SecureIdValueFormFileItemLabel.error) ?? .timestamp, activated: {
                    params.openDocument(document)
                }, deleted: {
                    params.deleteDocument(document)
                })
            case let .addScan(hasAny):
                return FormControllerActionItem(type: .accent, title: hasAny ? strings.Passport_Scans_UploadNew : strings.Passport_Scans_Upload, fullTopInset: true, activated: {
                    params.addFile(.scan)
                })
            case let .scansInfo(type):
                let text: String
                switch type {
                    case .identity:
                        text = strings.Passport_Identity_ScansHelp
                    case .address:
                        text = strings.Passport_Address_ScansHelp
                }
                return FormControllerTextItem(text: text)
            case let .infoHeader(type):
                let text: String
                switch type {
                    case .identity:
                        text = strings.Passport_Identity_DocumentDetails
                    case .address:
                        text = strings.Passport_Address_Address
                }
                return FormControllerHeaderItem(text: text)
            case let .identifier(value, error):
                return FormControllerTextInputItem(title: strings.Passport_Identity_DocumentNumber, text: value, placeholder: strings.Passport_Identity_DocumentNumberPlaceholder, type: .regular(capitalization: .words, autocorrection: false), error: error, textUpdated: { text in
                    params.updateText(.identifier, text)
                }, returnPressed: {
                    params.selectNextInputItem(self)
                })
            case let .firstName(value, error):
                return FormControllerTextInputItem(title: strings.Passport_Identity_Name, text: value, placeholder: strings.Passport_Identity_NamePlaceholder, type: .latin(capitalization: .words), error: error, textUpdated: { text in
                    params.updateText(.firstName, text)
                }, returnPressed: {
                    params.selectNextInputItem(self)
                })
            case let .middleName(value, error):
                return FormControllerTextInputItem(title: strings.Passport_Identity_MiddleName, text: value, placeholder: strings.Passport_Identity_MiddleNamePlaceholder, type: .latin(capitalization: .words), error: error, textUpdated: { text in
                    params.updateText(.middleName, text)
                }, returnPressed: {
                    params.selectNextInputItem(self)
                })
            case let .lastName(value, error):
                return FormControllerTextInputItem(title: strings.Passport_Identity_Surname, text: value, placeholder: strings.Passport_Identity_SurnamePlaceholder, type: .latin(capitalization: .words), error: error, textUpdated: { text in
                    params.updateText(.lastName, text)
                }, returnPressed: {
                    params.selectNextInputItem(self)
                })
            case let .nativeInfoHeader(language):
                let title: String
                
                var value: String?
                if !language.isEmpty {
                    let key = "Passport.Language.\(language)"
                    if let string = strings.primaryComponent.dict[key] {
                        value = string
                    } else if let string = strings.secondaryComponent?.dict[key] {
                        value = string
                    }
                }
                
                if let value = value {
                    title = strings.Passport_Identity_NativeNameTitle(value).string.uppercased()
                } else {
                    title = strings.Passport_Identity_NativeNameGenericTitle
                }
                return FormControllerHeaderItem(text: title)
            case let .nativeFirstName(value, error):
                return FormControllerTextInputItem(title: strings.Passport_Identity_Name, text: value, placeholder: strings.Passport_Identity_NamePlaceholder, type: .regular(capitalization: .words, autocorrection: false), error: error, textUpdated: { text in
                    params.updateText(.nativeFirstName, text)
                }, returnPressed: {
                    params.selectNextInputItem(self)
                })
            case let .nativeMiddleName(value, error):
                return FormControllerTextInputItem(title: strings.Passport_Identity_MiddleName, text: value, placeholder: strings.Passport_Identity_MiddleNamePlaceholder, type: .regular(capitalization: .words, autocorrection: false), error: error, textUpdated: { text in
                    params.updateText(.nativeMiddleName, text)
                }, returnPressed: {
                    params.selectNextInputItem(self)
                })
            case let .nativeLastName(value, error):
                return FormControllerTextInputItem(title: strings.Passport_Identity_Surname, text: value, placeholder: strings.Passport_Identity_SurnamePlaceholder, type: .regular(capitalization: .words, autocorrection: false), returnKeyType: .`default`, error: error, textUpdated: { text in
                    params.updateText(.nativeLastName, text)
                }, returnPressed: {
                    params.endEditing()
                })
            case let .nativeInfo(language, countryCode):
                let text: String
                
                var value: String?
                if !language.isEmpty {
                    let key = "Passport.Language.\(language)"
                    if let string = strings.primaryComponent.dict[key] {
                        value = string
                    } else if let string = strings.secondaryComponent?.dict[key] {
                        value = string
                    }
                }
                
                if let _ = value {
                    text = strings.Passport_Identity_NativeNameHelp
                } else {
                    let countryName = AuthorizationSequenceCountrySelectionController.lookupCountryNameById(countryCode.uppercased(), strings: strings) ?? ""
                    text = strings.Passport_Identity_NativeNameGenericHelp(countryName).string
                }
                return FormControllerTextItem(text: text)
            case let .gender(value, error):
                var text = ""
                if let value = value {
                    switch value {
                        case .male:
                            text = strings.Passport_Identity_GenderMale
                        case .female:
                            text = strings.Passport_Identity_GenderFemale
                    }
                }
                return FormControllerDetailActionItem(title: strings.Passport_Identity_Gender, text: text, placeholder: strings.Passport_Identity_GenderPlaceholder, error: error, activated: {
                    params.activateSelection(.gender)
                })
            case let .countryCode(category, value, error):
                let title: String
                let placeholder: String
                switch category {
                    case .identity:
                        title = strings.Passport_Identity_Country
                        placeholder = strings.Passport_Identity_CountryPlaceholder
                    case .address:
                        title = strings.Passport_Address_Country
                        placeholder = strings.Passport_Address_CountryPlaceholder
                }
                return FormControllerDetailActionItem(title: title, text: AuthorizationSequenceCountrySelectionController.lookupCountryNameById(value.uppercased(), strings: strings) ?? "", placeholder: placeholder, error: error, activated: {
                    params.activateSelection(.country)
                })
            case let .residenceCountryCode(value, error):
                return FormControllerDetailActionItem(title: strings.Passport_Identity_ResidenceCountry, text: AuthorizationSequenceCountrySelectionController.lookupCountryNameById(value.uppercased(), strings: strings) ?? "", placeholder: strings.Passport_Identity_ResidenceCountryPlaceholder, error: error, activated: {
                    params.activateSelection(.residenceCountry)
                })
            case let .birthdate(value, error):
                return FormControllerDetailActionItem(title: strings.Passport_Identity_DateOfBirth, text: value.flatMap({ stringForDate(timestamp: $0.timestamp, strings: strings) }) ?? "", placeholder: strings.Passport_Identity_DateOfBirthPlaceholder, error: error, activated: {
                    params.activateSelection(.date(value?.timestamp, .birthdate))
                })
            case let .expiryDate(value, error):
                let title: String
                switch value {
                    case .notSet:
                        title = ""
                    case .doesNotExpire:
                        title = strings.Passport_Identity_ExpiryDateNone
                    case let .date(date):
                        title = stringForDate(timestamp: date.timestamp, strings: strings)
                }
                return FormControllerDetailActionItem(title: strings.Passport_Identity_ExpiryDate, text: title, placeholder: strings.Passport_Identity_ExpiryDatePlaceholder, error: error, activated: {
                    let timestamp: Int32?
                    switch value {
                        case .notSet, .doesNotExpire:
                            timestamp = nil
                        case let .date(date):
                            timestamp = date.timestamp
                    }
                    params.activateSelection(.date(timestamp, .expiry))
                })
            case let .deleteDocument(category, hasDocument):
                var title = strings.Passport_DeleteDocument
                if !hasDocument {
                    switch category {
                        case .identity:
                            title = strings.Passport_DeletePersonalDetails
                        case .address:
                            title = strings.Passport_DeleteAddress
                    }
                }
                return FormControllerActionItem(type: .destructive, title: title, activated: {
                    params.deleteValue()
                })
            case let .street1(value, error):
                return FormControllerTextInputItem(title: strings.Passport_Address_Street, text: value, placeholder: strings.Passport_Address_Street1Placeholder, type: .regular(capitalization: .words, autocorrection: false), error: error, textUpdated: { text in
                    params.updateText(.street1, text)
                }, returnPressed: {
                    params.selectNextInputItem(self)
                })
            case let .street2(value, error):
                return FormControllerTextInputItem(title: "", text: value, placeholder: strings.Passport_Address_Street2Placeholder, type: .regular(capitalization: .words, autocorrection: false), error: error, textUpdated: { text in
                    params.updateText(.street2, text)
                }, returnPressed: {
                    params.selectNextInputItem(self)
                })
            case let .city(value, error):
                return FormControllerTextInputItem(title: strings.Passport_Address_City, text: value, placeholder: strings.Passport_Address_CityPlaceholder, type: .regular(capitalization: .words, autocorrection: false), error: error, textUpdated: { text in
                    params.updateText(.city, text)
                }, returnPressed: {
                    params.selectNextInputItem(self)
                })
            case let .state(value, error):
                return FormControllerTextInputItem(title: strings.Passport_Address_Region, text: value, placeholder: strings.Passport_Address_RegionPlaceholder, type: .regular(capitalization: .words, autocorrection: false), error: error, textUpdated: { text in
                    params.updateText(.state, text)
                }, returnPressed: {
                    params.selectNextInputItem(self)
                })
            case let .postcode(value, error):
                let color: FormControllerTextInputItemColor
                if value.count > 12 {
                    color = .error
                } else {
                    color = .primary
                }
                return FormControllerTextInputItem(title: strings.Passport_Address_Postcode, text: value, placeholder: strings.Passport_Address_PostcodePlaceholder, color: color, type: .latin(capitalization: .allCharacters), returnKeyType: .`default`, error: error, textUpdated: { text in
                    params.updateText(.postcode, text)
                }, returnPressed: {
                    params.endEditing()
                })
            case .requestedDocumentsHeader:
                return FormControllerHeaderItem(text: strings.Passport_Identity_FilesTitle)
            case let .selfie(_, document, error):
                let label: SecureIdValueFormFileItemLabel
                if let error = error {
                    label = .error(error)
                } else if document != nil {
                    label = .timestamp
                } else {
                    label = .text(strings.Passport_Identity_SelfieHelp)
                }
                return SecureIdValueFormFileItem(account: params.account, context: params.context, document: document, placeholder: UIImage(bundleImageName: "Secure ID/DocumentInputSelfie"), title: strings.Passport_Identity_Selfie, label: label, activated: {
                    if let document = document {
                        params.openDocument(document)
                    } else {
                        params.addFile(.selfie)
                    }
                }, deleted: {
                    if let document = document {
                        params.deleteDocument(document)
                    }
                })
            case let .frontSide(_, type, document, error):
                let label: SecureIdValueFormFileItemLabel
                if let error = error {
                    label = .error(error)
                } else if document != nil {
                    label = .timestamp
                } else {
                    switch type {
                        case .passport?, .internalPassport?:
                            label = .text(strings.Passport_Identity_MainPageHelp)
                        default:
                            label = .text(strings.Passport_Identity_FrontSideHelp)
                    }
                }
                let title: String
                let placeholder: UIImage?
                    switch type {
                        case .passport?, .internalPassport?:
                            title = strings.Passport_Identity_MainPage
                            placeholder = UIImage(bundleImageName: "Secure ID/PassportInputFrontSide")
                        case .driversLicense?:
                            title = strings.Passport_Identity_FrontSide
                            placeholder = UIImage(bundleImageName: "Secure ID/DriversLicenseInputFrontSide")
                        default:
                            title = strings.Passport_Identity_FrontSide
                            placeholder = UIImage(bundleImageName: "Secure ID/IdCardInputFrontSide")
                }
                return SecureIdValueFormFileItem(account: params.account, context: params.context, document: document, placeholder: placeholder, title: title, label: label, activated: {
                    if let document = document {
                        params.openDocument(document)
                    } else {
                        params.addFile(.frontSide(type))
                    }
                }, deleted: {
                    if let document = document {
                        params.deleteDocument(document)
                    }
                })
            case let .backSide(_, type, document, error):
                let label: SecureIdValueFormFileItemLabel
                if let error = error {
                    label = .error(error)
                } else if document != nil {
                    label = .timestamp
                } else {
                    label = .text(strings.Passport_Identity_ReverseSideHelp)
                }
                return SecureIdValueFormFileItem(account: params.account, context: params.context, document: document, placeholder: UIImage(bundleImageName: "Secure ID/DocumentInputBackSide"), title: strings.Passport_Identity_ReverseSide, label: label, activated: {
                    if let document = document {
                        params.openDocument(document)
                    } else {
                        params.addFile(.backSide(type))
                    }
                }, deleted: {
                    if let document = document {
                        params.deleteDocument(document)
                    }
                })
            case let .documentsInfo(category):
                let text: String
                switch category {
                    case .identity:
                        text = strings.Passport_Identity_ScansHelp
                    case .address:
                        text = strings.Passport_Address_ScansHelp
                }
                return FormControllerTextItem(text: text)
            case .translationsHeader:
                return FormControllerHeaderItem(text: strings.Passport_Identity_Translations)
            case let .translation(index, document, error):
                return SecureIdValueFormFileItem(account: params.account, context: params.context, document: document, placeholder: nil, title: strings.Passport_Scans_ScanIndex("\(index + 1)").string, label: error.flatMap(SecureIdValueFormFileItemLabel.error) ?? .timestamp, activated: {
                    params.openDocument(document)
                }, deleted: {
                    params.deleteDocument(document)
                })
            case let .addTranslation(hasAny):
                return FormControllerActionItem(type: .accent, title: hasAny ? strings.Passport_Scans_UploadNew : strings.Passport_Scans_Upload, fullTopInset: true, activated: {
                    params.addFile(.translation)
                })
            case .translationsInfo:
                return FormControllerTextItem(text: strings.Passport_Identity_TranslationsHelp)
            case let .error(_, text, _):
                return FormControllerTextItem(text: text, color: .error)
        }
    }
}

struct SecureIdDocumentFormControllerNodeInitParams {
    let context: AccountContext
    let secureIdContext: SecureIdAccessContext
}

final class SecureIdDocumentFormControllerNode: FormControllerNode<SecureIdDocumentFormControllerNodeInitParams, SecureIdDocumentFormState> {
    private var _itemParams: SecureIdDocumentFormParams?
    override var itemParams: SecureIdDocumentFormParams {
        return self._itemParams!
    }
    
    private var presentationData: PresentationData
    private var theme: PresentationTheme
    private var strings: PresentationStrings
    
    private let context: AccountContext
    private let secureIdContext: SecureIdAccessContext
    
    private let uploadContext: SecureIdVerificationDocumentsContext
    
    var actionInputStateUpdated: ((SecureIdDocumentFormInputState) -> Void)?
    var completedWithValues: (([SecureIdValueWithContext]?) -> Void)?
    var dismiss: (() -> Void)?
    
    var initiallyScrollTo: SecureIdDocumentFormScrollToSubject?
    
    private let actionDisposable = MetaDisposable()
    private let hiddenItemDisposable = MetaDisposable()
    
    required init(initParams: SecureIdDocumentFormControllerNodeInitParams, presentationData: PresentationData) {
        self.presentationData = presentationData
        self.theme = presentationData.theme
        self.strings = presentationData.strings
        self.context = initParams.context
        self.secureIdContext = initParams.secureIdContext
        
        var updateImpl: ((Int64, SecureIdVerificationLocalDocumentState) -> Void)?
        
        self.uploadContext = SecureIdVerificationDocumentsContext(postbox: self.context.account.postbox, network: self.context.account.network, context: self.secureIdContext, update: { id, state in
            updateImpl?(id, state)
        })
        
        super.init(initParams: initParams, presentationData: presentationData)
        
        self._itemParams = SecureIdDocumentFormParams(account: self.context.account, context: self.secureIdContext, addFile: { [weak self] type in
            if let strongSelf = self {
                strongSelf.view.endEditing(true)
                strongSelf.presentAssetPicker(type)
            }
        }, openDocument: { [weak self] document in
            if let strongSelf = self {
                strongSelf.openDocument(document: document)
            }
        }, deleteDocument: { [weak self] document in
            if let strongSelf = self {
                strongSelf.deleteDocument(document: document)
            }
        }, updateText: { [weak self] field, value in
            if let strongSelf = self, var innerState = strongSelf.innerState {
                innerState.documentState.updateTextField(type: field, value: value)
                var valueKey: SecureIdValueKey?
                var errorKey: SecureIdValueContentErrorKey?
                switch innerState.documentState {
                    case let .identity(identity):
                        switch field {
                            case .firstName:
                                valueKey = .personalDetails
                                errorKey = .field(.personalDetails(.firstName))
                            case .lastName:
                                valueKey = .personalDetails
                                errorKey = .field(.personalDetails(.lastName))
                            case .middleName:
                                valueKey = .personalDetails
                                errorKey = .field(.personalDetails(.middleName))
                            case .nativeFirstName:
                                valueKey = .personalDetails
                                errorKey = .field(.personalDetails(.firstNameNative))
                            case .nativeLastName:
                                valueKey = .personalDetails
                                errorKey = .field(.personalDetails(.lastNameNative))
                            case .nativeMiddleName:
                                valueKey = .personalDetails
                                errorKey = .field(.personalDetails(.middleNameNative))
                            case .identifier:
                                if let document = identity.document {
                                    switch document.type {
                                        case .passport:
                                            valueKey = .passport
                                            errorKey = .field(.passport(.documentId))
                                        case .internalPassport:
                                            valueKey = .internalPassport
                                            errorKey = .field(.internalPassport(.documentId))
                                        case .driversLicense:
                                            valueKey = .driversLicense
                                            errorKey = .field(.driversLicense(.documentId))
                                        case .idCard:
                                            valueKey = .idCard
                                            errorKey = .field(.idCard(.documentId))
                                    }
                                }
                            default:
                                break
                        }
                    case .address:
                        switch field {
                            case .street1:
                                valueKey = .address
                                errorKey = .field(.address(.streetLine1))
                            case .street2:
                                valueKey = .address
                                errorKey = .field(.address(.streetLine2))
                            case .state:
                                valueKey = .address
                                errorKey = .field(.address(.state))
                            case .postcode:
                                valueKey = .address
                                errorKey = .field(.address(.postCode))
                            case .city:
                                valueKey = .address
                                errorKey = .field(.address(.city))
                            default:
                                break
                        }
                }
                if let valueKey = valueKey, let errorKey = errorKey {
                    let valueErrorKey: SecureIdValueContentErrorKey = .value(valueKey)
                    if let previousValue = innerState.previousValues[valueKey] {
                        innerState.previousValues[valueKey] = previousValue.withRemovedErrors([errorKey, valueErrorKey])
                    }
                }
                strongSelf.updateInnerState(transition: .immediate, with: innerState)
            }
        }, selectNextInputItem: { [weak self] entry in
            guard let strongSelf = self else {
                return
            }
            var useNext = false
            strongSelf.enumerateItemsAndEntries({ itemEntry, itemNode in
                if itemEntry.isEqual(to: entry) {
                    useNext = true
                } else if useNext {
                    if case .deleteDocument = itemEntry {
                        return false
                    } else if let inputNode = itemNode as? FormControllerTextInputItemNode {
                        inputNode.activate()
                        return false
                    } else if let actionNode = itemNode as? FormControllerDetailActionItemNode {
                        actionNode.activate()
                        return false
                    }
                }
                return true
            })
            strongSelf.forceUpdateState(transition: .animated(duration: 0.2, curve: .spring))
        }, endEditing: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.view.endEditing(true)
        }, activateSelection: { [weak self] field in
            if let strongSelf = self {
                switch field {
                    case .country:
                        let controller = AuthorizationSequenceCountrySelectionController(strings: strongSelf.strings, theme: strongSelf.theme, displayCodes: false)
                        controller.completeWithCountryCode = { _, id in
                            if let strongSelf = self, var innerState = strongSelf.innerState {
                                innerState.documentState.updateCountryCode(value: id)
                                var valueKey: SecureIdValueKey?
                                var errorKey: SecureIdValueContentErrorKey?
                                switch innerState.documentState {
                                    case .identity:
                                        valueKey = .personalDetails
                                        errorKey = .field(.personalDetails(.countryCode))
                                    case .address:
                                        valueKey = .address
                                        errorKey = .field(.address(.countryCode))
                                }
                                if let valueKey = valueKey, let errorKey = errorKey {
                                    let valueErrorKey: SecureIdValueContentErrorKey = .value(valueKey)
                                    if let previousValue = innerState.previousValues[valueKey] {
                                        innerState.previousValues[valueKey] = previousValue.withRemovedErrors([errorKey, valueErrorKey])
                                    }
                                }
                                strongSelf.updateInnerState(transition: .immediate, with: innerState)
                            }
                        }
                        strongSelf.view.endEditing(true)
                        strongSelf.present(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                    case .residenceCountry:
                        let controller = AuthorizationSequenceCountrySelectionController(strings: strongSelf.strings, theme: strongSelf.theme, displayCodes: false)
                        controller.completeWithCountryCode = { _, id in
                            if let strongSelf = self, var innerState = strongSelf.innerState {
                                innerState.documentState.updateResidenceCountryCode(value: id)
                                var valueKey: SecureIdValueKey?
                                var errorKey: SecureIdValueContentErrorKey?
                                switch innerState.documentState {
                                    case .identity:
                                        valueKey = .personalDetails
                                        errorKey = .field(.personalDetails(.residenceCountryCode))
                                    case .address:
                                        break
                                }
                                if let valueKey = valueKey, let errorKey = errorKey {
                                    let valueErrorKey: SecureIdValueContentErrorKey = .value(valueKey)
                                    if let previousValue = innerState.previousValues[valueKey] {
                                        innerState.previousValues[valueKey] = previousValue.withRemovedErrors([errorKey, valueErrorKey])
                                    }
                                }
                                strongSelf.updateInnerState(transition: .immediate, with: innerState)
                            }
                        }
                        strongSelf.view.endEditing(true)
                        strongSelf.present(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                    case let .date(current, field):
                        var emptyTitle: String?
                        var minimumDate: Date? = nil
                        var maximumDate: Date? = nil
                        let calendar = Calendar(identifier: .gregorian)
                        let now = Date()
                        var title: String? = nil
                        if case .expiry = field {
                            title = strongSelf.strings.Passport_Identity_ExpiryDate
                            emptyTitle = strongSelf.strings.Passport_Identity_DoesNotExpire
                            var deltaComponents = DateComponents()
                            deltaComponents.month = 6
                            minimumDate = calendar.date(byAdding: deltaComponents, to: now)
                            
                        } else if case .birthdate = field {
                            title = strongSelf.strings.Passport_Identity_DateOfBirth
                            var components = calendar.dateComponents([.year, .month, .day], from: now)
                            if let year = components.year {
                                components.year = year - 18
                                components.hour = 0
                                components.minute = 0
                                maximumDate = calendar.date(from: components)
                            }
                        }
                        
                        let controller = DateSelectionActionSheetController(context: strongSelf.context, title: title, currentValue: current ?? Int32(Date().timeIntervalSince1970), minimumDate: minimumDate, maximumDate: maximumDate, emptyTitle: emptyTitle, applyValue: { value in
                            if let strongSelf = self, var innerState = strongSelf.innerState {
                                innerState.documentState.updateDateField(type: field, value: value.flatMap(SecureIdDate.init))
                                var valueKey: SecureIdValueKey?
                                var errorKey: SecureIdValueContentErrorKey?
                                
                                switch innerState.documentState {
                                    case let .identity(identity):
                                        switch field {
                                            case .birthdate:
                                                valueKey = .personalDetails
                                                errorKey = .field(.personalDetails(.birthdate))
                                            case .expiry:
                                                if let document = identity.document {
                                                    switch document.type {
                                                        case .passport:
                                                            valueKey = .passport
                                                            errorKey = .field(.passport(.expiryDate))
                                                        case .internalPassport:
                                                            valueKey = .internalPassport
                                                            errorKey = .field(.internalPassport(.expiryDate))
                                                        case .driversLicense:
                                                            valueKey = .driversLicense
                                                            errorKey = .field(.driversLicense(.expiryDate))
                                                        case .idCard:
                                                            valueKey = .idCard
                                                            errorKey = .field(.idCard(.expiryDate))
                                                    }
                                                }
                                        }
                                    case .address:
                                        break
                                }
                                
                                if let valueKey = valueKey, let errorKey = errorKey {
                                    let valueErrorKey: SecureIdValueContentErrorKey = .value(valueKey)
                                    if let previousValue = innerState.previousValues[valueKey] {
                                        innerState.previousValues[valueKey] = previousValue.withRemovedErrors([errorKey, valueErrorKey])
                                    }
                                }
                                strongSelf.updateInnerState(transition: .immediate, with: innerState)
                            }
                        })
                        strongSelf.view.endEditing(true)
                        strongSelf.present(controller, nil)
                    case .gender:
                        let controller = ActionSheetController(presentationData: strongSelf.presentationData)
                        let dismissAction: () -> Void = { [weak controller] in
                            controller?.dismissAnimated()
                        }
                        let applyAction: (SecureIdGender) -> Void = { gender in
                            if let strongSelf = self, var innerState = strongSelf.innerState {
                                innerState.documentState.updateGenderField(type: .gender, value: gender)
                                var valueKey: SecureIdValueKey?
                                var errorKey: SecureIdValueContentErrorKey?
                                valueKey = .personalDetails
                                errorKey = .field(.personalDetails(.gender))
                                if let valueKey = valueKey, let errorKey = errorKey {
                                    let valueErrorKey: SecureIdValueContentErrorKey = .value(valueKey)
                                    if let previousValue = innerState.previousValues[valueKey] {
                                        innerState.previousValues[valueKey] = previousValue.withRemovedErrors([errorKey, valueErrorKey])
                                    }
                                }
                                strongSelf.updateInnerState(transition: .immediate, with: innerState)
                            }
                        }
                        controller.setItemGroups([
                            ActionSheetItemGroup(items: [
                                ActionSheetButtonItem(title: strongSelf.strings.Passport_Identity_GenderMale, action: {
                                    dismissAction()
                                    applyAction(.male)
                                }),
                                ActionSheetButtonItem(title: strongSelf.strings.Passport_Identity_GenderFemale, action: {
                                    dismissAction()
                                    applyAction(.female)
                                })
                            ]),
                            ActionSheetItemGroup(items: [ActionSheetButtonItem(title: strongSelf.strings.Common_Cancel, action: { dismissAction() })])
                        ])
                        strongSelf.view.endEditing(true)
                        strongSelf.present(controller, nil)
                }
            }
        }, scanPassport: { [weak self] in
            if let strongSelf = self {
                let controller = legacySecureIdScanController(theme: strongSelf.theme, strings: strongSelf.strings, finished: { recognizedData in
                    if let strongSelf = self, let recognizedData = recognizedData, var innerState = strongSelf.innerState {
                        innerState.documentState.updateWithRecognizedData(recognizedData)
                        strongSelf.updateInnerState(transition: .immediate, with: innerState)
                    }
                })
                strongSelf.present(controller, nil)
            }
        }, deleteValue: { [weak self] in
            if let strongSelf = self {
                strongSelf.deleteValue()
            }
        })
        
        updateImpl = { [weak self] id, state in
            if let strongSelf = self, var innerState = strongSelf.innerState {
                outer: for i in 0 ..< innerState.documents.count {
                    switch innerState.documents[i] {
                        case var .local(local):
                            if local.id == id {
                                local.state = state
                                innerState.documents[i] = .local(local)
                                break outer
                            }
                        case .remote:
                            break
                    }
                }
                if let selfieDocument = innerState.selfieDocument {
                    switch selfieDocument {
                        case var .local(local):
                            if local.id == id {
                                local.state = state
                                innerState.selfieDocument = .local(local)
                            }
                        case .remote:
                            break
                    }
                }
                if let frontSideDocument = innerState.frontSideDocument {
                    switch frontSideDocument {
                    case var .local(local):
                        if local.id == id {
                            local.state = state
                            innerState.frontSideDocument = .local(local)
                        }
                    case .remote:
                        break
                    }
                }
                if let backSideDocument = innerState.backSideDocument {
                    switch backSideDocument {
                    case var .local(local):
                        if local.id == id {
                            local.state = state
                            innerState.backSideDocument = .local(local)
                        }
                    case .remote:
                        break
                    }
                }
                outer: for i in 0 ..< innerState.translations.count {
                    switch innerState.translations[i] {
                        case var .local(local):
                            if local.id == id {
                                local.state = state
                                innerState.translations[i] = .local(local)
                                break outer
                            }
                        case .remote:
                            break
                    }
                }
                strongSelf.updateInnerState(transition: .immediate, with: innerState)
            }
        }
    }
    
    deinit {
        self.actionDisposable.dispose()
    }
    
    private func presentAssetPicker(_ type: SecureIdAddFileTarget, replaceDocumentId: SecureIdVerificationDocumentId? = nil) {
        guard let validLayout = self.layoutState?.layout else {
            return
        }
        let attachmentType: SecureIdAttachmentMenuType
        var recognizeDocumentData = false
        switch type {
            case .scan:
                attachmentType = .multiple
                if let innerState = self.innerState {
                    switch innerState.documentState {
                        case .identity:
                            recognizeDocumentData = true
                        default:
                            break
                    }
                }
            case let .backSide(type):
                switch type {
                    case .idCard?, .driversLicense?:
                        attachmentType = .idCard
                    default:
                        attachmentType = .generic
                }
                recognizeDocumentData = true
            case let .frontSide(type):
                switch type {
                case .idCard?, .driversLicense?:
                    attachmentType = .idCard
                default:
                    attachmentType = .generic
                }
                recognizeDocumentData = true
            case .selfie:
                attachmentType = .selfie
            case .translation:
                attachmentType = .multiple
        }
        presentLegacySecureIdAttachmentMenu(context: self.context, present: { [weak self] c in
            self?.view.endEditing(true)
            self?.present(c, nil)
            }, validLayout: validLayout, type: attachmentType, recognizeDocumentData: recognizeDocumentData, completion: { [weak self] resources, recognizedData in
                self?.addDocuments(type: type, resources: resources, recognizedData: recognizedData, removeDocumentId: replaceDocumentId)
        })
    }
    
    func addDocuments(type: SecureIdAddFileTarget, resources: [TelegramMediaResource], recognizedData: SecureIdRecognizedDocumentData?, removeDocumentId: SecureIdVerificationDocumentId?) {
        guard var innerState = self.innerState else {
            return
        }
        
        switch type {
            case .scan:
                var addIndex = innerState.documents.count
                if let removeDocumentId = removeDocumentId {
                    for i in 0 ..< innerState.documents.count {
                        if innerState.documents[i].id == removeDocumentId {
                            innerState.documents.remove(at: i)
                            addIndex = i
                            break
                        }
                    }
                }
                for resource in resources {
                    let id = Int64.random(in: Int64.min ... Int64.max)
                    innerState.documents.insert(.local(SecureIdVerificationLocalDocument(id: id, resource: SecureIdLocalImageResource(localId: id, source: resource), timestamp: Int32(Date().timeIntervalSince1970), state: .uploading(0.0))), at: addIndex)
                    addIndex += 1
                }
                if innerState.documents.count > 20 {
                    innerState.documents = Array(innerState.documents[0 ..< 20])
                }
            case .selfie:
                if let removeDocumentId = removeDocumentId {
                    innerState = removeDocumentWithId(innerState, id: removeDocumentId)
                }
                loop: for resource in resources {
                    let id = Int64.random(in: Int64.min ... Int64.max)
                    innerState.selfieDocument = .local(SecureIdVerificationLocalDocument(id: id, resource: SecureIdLocalImageResource(localId: id, source: resource), timestamp: Int32(Date().timeIntervalSince1970), state: .uploading(0.0)))
                    break loop
                }
            case .frontSide:
                if let removeDocumentId = removeDocumentId {
                    innerState = removeDocumentWithId(innerState, id: removeDocumentId)
                }
                loop: for resource in resources {
                    let id = Int64.random(in: Int64.min ... Int64.max)
                    innerState.frontSideDocument = .local(SecureIdVerificationLocalDocument(id: id, resource: SecureIdLocalImageResource(localId: id, source: resource), timestamp: Int32(Date().timeIntervalSince1970), state: .uploading(0.0)))
                    break loop
                }
            case .backSide:
                if let removeDocumentId = removeDocumentId {
                    innerState = removeDocumentWithId(innerState, id: removeDocumentId)
                }
                loop: for resource in resources {
                    let id = Int64.random(in: Int64.min ... Int64.max)
                    innerState.backSideDocument = .local(SecureIdVerificationLocalDocument(id: id, resource: SecureIdLocalImageResource(localId: id, source: resource), timestamp: Int32(Date().timeIntervalSince1970), state: .uploading(0.0)))
                    break loop
                }
            case .translation:
                var addIndex = innerState.translations.count
                if let removeDocumentId = removeDocumentId {
                    for i in 0 ..< innerState.translations.count {
                        if innerState.translations[i].id == removeDocumentId {
                            innerState.translations.remove(at: i)
                            addIndex = i
                            break
                        }
                    }
                }
                for resource in resources {
                    let id = Int64.random(in: Int64.min ... Int64.max)
                    innerState.translations.insert(.local(SecureIdVerificationLocalDocument(id: id, resource: SecureIdLocalImageResource(localId: id, source: resource), timestamp: Int32(Date().timeIntervalSince1970), state: .uploading(0.0))), at: addIndex)
                    addIndex += 1
                }
                if innerState.translations.count > 20 {
                    innerState.translations = Array(innerState.documents[0 ..< 20])
                }
        }
        if let recognizedData = recognizedData {
            innerState.documentState.updateWithRecognizedData(recognizedData)
        }
        self.updateInnerState(transition: .immediate, with: innerState)
    }
    
    override func updateInnerState(transition: ContainedViewLayoutTransition, with innerState: SecureIdDocumentFormState) {
        let previousActionInputState = self.innerState?.actionInputState()
        super.updateInnerState(transition: transition, with: innerState)
        var documents = innerState.documents
        if let selfieDocument = innerState.selfieDocument {
            documents.append(selfieDocument)
        }
        if let frontSideDocument = innerState.frontSideDocument {
            documents.append(frontSideDocument)
        }
        if let backSideDocument = innerState.backSideDocument {
            documents.append(backSideDocument)
        }
        documents.append(contentsOf: innerState.translations)
        self.uploadContext.stateUpdated(documents)
        
        let actionInputState = innerState.actionInputState()
        if previousActionInputState != actionInputState {
            self.actionInputStateUpdated?(actionInputState)
        }
    }
    
    func hasUnsavedData() -> Bool {
        guard let innerState = self.innerState else {
            return false
        }
        guard let values = innerState.makeValues(), !values.isEmpty else {
            return false
        }
        
        for (key, value) in values {
            if innerState.previousValues[key]?.value != value {
                return true
            }
        }
        for (key, _) in innerState.previousValues {
            if values[key] == nil {
                return true
            }
        }
        
        return false
    }
    
    func save() {
        guard var innerState = self.innerState else {
            return
        }
        guard case .none = innerState.actionState else {
            return
        }
        guard case .saveAvailable = innerState.actionInputState() else {
            return
        }
        guard let values = innerState.makeValues(), !values.isEmpty else {
            return
        }
        if !innerState.previousValues.isEmpty, values == innerState.previousValues.mapValues({ $0.value }) {
            self.dismiss?()
            return
        }
        
        innerState.actionState = .saving
        self.updateInnerState(transition: .immediate, with: innerState)
        
        var saveValues: [Signal<SecureIdValueWithContext, SaveSecureIdValueError>] = []
        for (_, value) in values {
            saveValues.append(saveSecureIdValue(postbox: self.context.account.postbox, network: self.context.account.network, context: self.secureIdContext, value: value, uploadedFiles: self.uploadContext.uploadedFiles))
        }
        
        self.actionDisposable.set((combineLatest(saveValues)
        |> deliverOnMainQueue).start(next: { [weak self] result in
            if let strongSelf = self {
                strongSelf.completedWithValues?(result)
            }
        }, error: { [weak self] error in
            if let strongSelf = self {
                guard var innerState = strongSelf.innerState else {
                    return
                }
                guard case .saving = innerState.actionState else {
                    return
                }
                innerState.actionState = .none
                strongSelf.updateInnerState(transition: .immediate, with: innerState)
            }
        }))
    }
    
    func deleteValue() {
        guard let innerState = self.innerState, !innerState.previousValues.isEmpty else {
            return
        }
        guard case .none = innerState.actionState else {
            return
        }
        
        let controller = ActionSheetController(presentationData: self.presentationData)
        let dismissAction: () -> Void = { [weak controller] in
            controller?.dismissAnimated()
        }
        
        let text: String
        let title: String
        switch innerState.documentState {
            case let .identity(state) where state.details != nil:
                text = self.strings.Passport_DeletePersonalDetailsConfirmation
                title = self.strings.Passport_DeletePersonalDetails
            case let .address(state) where state.details != nil:
                text = self.strings.Passport_DeleteAddressConfirmation
                title = self.strings.Passport_DeleteAddress
            default:
                text = self.strings.Passport_DeleteDocumentConfirmation
                title = self.strings.Passport_DeleteDocument
        }
        
        controller.setItemGroups([
            ActionSheetItemGroup(items: [
                ActionSheetTextItem(title: text),
                ActionSheetButtonItem(title: title, color: .destructive, action: { [weak self] in
                    dismissAction()
                    guard let strongSelf = self else {
                        return
                    }
                    guard var innerState = strongSelf.innerState, !innerState.previousValues.isEmpty else {
                        return
                    }
                    innerState.actionState = .deleting
                    strongSelf.updateInnerState(transition: .immediate, with: innerState)
                    
                    strongSelf.actionDisposable.set((deleteSecureIdValues(network: strongSelf.context.account.network, keys: Set(innerState.previousValues.keys))
                    |> deliverOnMainQueue).start(error: { error in
                        guard let strongSelf = self else {
                            return
                        }
                        guard var innerState = strongSelf.innerState else {
                            return
                        }
                        guard case .deleting = innerState.actionState else {
                            return
                        }
                        innerState.actionState = .none
                        strongSelf.updateInnerState(transition: .immediate, with: innerState)
                    }, completed: { [weak self] in
                        self?.completedWithValues?([])
                    }))
                })
            ]),
            ActionSheetItemGroup(items: [ActionSheetButtonItem(title: self.strings.Common_Cancel, action: {
                dismissAction()
            })])
        ])
        self.view.endEditing(true)
        self.present(controller, nil)
    }
    
    private func openDocument(document: SecureIdVerificationDocument) {
        let controller = ActionSheetController(presentationData: self.presentationData)
        let dismissAction: () -> Void = { [weak controller] in
            controller?.dismissAnimated()
        }
        controller.setItemGroups([
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: strings.Passport_Identity_FilesView, action: { [weak self] in
                    dismissAction()
                    self?.presentGallery(document: document)
                }),
                ActionSheetButtonItem(title: strings.Passport_Identity_FilesUploadNew, action: { [weak self] in
                    dismissAction()
                    guard let strongSelf = self else {
                        return
                    }
                    guard let innerState = strongSelf.innerState else {
                        return
                    }
                    
                    var target: SecureIdAddFileTarget?
                    
                    let id = document.id
                    
                    if let selfieDocument = innerState.selfieDocument, selfieDocument.id == id {
                        target = .selfie
                    }
                    
                    if let frontSideDocument = innerState.frontSideDocument, frontSideDocument.id == id {
                        switch innerState.documentState {
                            case let .identity(identity):
                                if let document = identity.document {
                                    target = .frontSide(document.type)
                                }
                            case .address:
                                break
                        }
                    }
                    
                    if let backSideDocument = innerState.backSideDocument, backSideDocument.id == id {
                        switch innerState.documentState {
                            case let .identity(identity):
                                if let document = identity.document {
                                    target = .backSide(document.type)
                                }
                            case .address:
                                break
                        }
                    }
                    
                    for i in 0 ..< innerState.documents.count {
                        if innerState.documents[i].id == id {
                            target = .scan
                            break
                        }
                    }
                    
                    for i in 0 ..< innerState.translations.count {
                        if innerState.translations[i].id == id {
                            target = .translation
                            break
                        }
                    }
                    
                    if let target = target {
                        strongSelf.view.endEditing(true)
                        strongSelf.presentAssetPicker(target, replaceDocumentId: document.id)
                    }
                }),
                ActionSheetButtonItem(title: strings.Common_Delete, color: .destructive, action: { [weak self] in
                    dismissAction()
                    guard let strongSelf = self else {
                        return
                    }
                    guard var innerState = strongSelf.innerState else {
                        return
                    }
                    
                    innerState = removeDocumentWithId(innerState, id: document.id)
                    
                    strongSelf.updateInnerState(transition: .immediate, with: innerState)
                })
            ]),
            ActionSheetItemGroup(items: [ActionSheetButtonItem(title: self.strings.Common_Cancel, action: { dismissAction() })])
        ])
        self.view.endEditing(true)
        self.present(controller, nil)
    }
    
    private func deleteDocument(document: SecureIdVerificationDocument) {
        guard var innerState = self.innerState else {
            return
        }
        innerState = removeDocumentWithId(innerState, id: document.id)
        self.updateInnerState(transition: .animated(duration: 0.2, curve: .spring), with: innerState)
    }
    
    private func presentGallery(document: SecureIdVerificationDocument) {
        guard let innerState = self.innerState else {
            return
        }
        
        var entries: [SecureIdDocumentGalleryEntry] = []
        var index = 0
        var centralIndex = 0
        var totalCount: Int32 = 0
        if innerState.frontSideDocument != nil {
            totalCount += 1
        }
        if innerState.backSideDocument != nil {
            totalCount += 1
        }
        if innerState.selfieDocument != nil {
            totalCount += 1
        }
        totalCount += Int32(innerState.documents.count)
        totalCount += Int32(innerState.translations.count)
        
        if let frontSideDocument = innerState.frontSideDocument {
            entries.append(SecureIdDocumentGalleryEntry(index: Int32(index), resource: frontSideDocument.resource, location: SecureIdDocumentGalleryEntryLocation(position: Int32(index), totalCount: totalCount), error: ""))
            if document.id == frontSideDocument.id {
                centralIndex = index
            }
            index += 1
        }
        if let backSideDocument = innerState.backSideDocument {
            entries.append(SecureIdDocumentGalleryEntry(index: Int32(index), resource: backSideDocument.resource, location: SecureIdDocumentGalleryEntryLocation(position: Int32(index), totalCount: totalCount), error: ""))
            if document.id == backSideDocument.id {
                centralIndex = index
            }
            index += 1
        }
        if let selfieDocument = innerState.selfieDocument {
            entries.append(SecureIdDocumentGalleryEntry(index: Int32(index), resource: selfieDocument.resource, location: SecureIdDocumentGalleryEntryLocation(position: Int32(index), totalCount: totalCount), error: ""))
            if document.id == selfieDocument.id {
                centralIndex = index
            }
            index += 1
        }
        if let _ = innerState.documents.firstIndex(where: { $0.id == document.id }) {
            for itemDocument in innerState.documents {
                entries.append(SecureIdDocumentGalleryEntry(index: Int32(index), resource: itemDocument.resource, location: SecureIdDocumentGalleryEntryLocation(position: Int32(index), totalCount: totalCount), error: ""))
                if document.id == itemDocument.id {
                    centralIndex = index
                }
                index += 1
            }
        }
        if let _ = innerState.translations.firstIndex(where: { $0.id == document.id }) {
            for itemDocument in innerState.translations {
                entries.append(SecureIdDocumentGalleryEntry(index: Int32(index), resource: itemDocument.resource, location: SecureIdDocumentGalleryEntryLocation(position: Int32(index), totalCount: totalCount), error: ""))
                if document.id == itemDocument.id {
                    centralIndex = index
                }
                index += 1
            }
        }
        
        let galleryController = SecureIdDocumentGalleryController(context: self.context, secureIdContext: self.secureIdContext, entries: entries, centralIndex: centralIndex, replaceRootController: { _, _ in
            
        })
        galleryController.deleteResource = { [weak self] resource in
            guard let strongSelf = self else {
                return
            }
            guard var innerState = strongSelf.innerState else {
                return
            }
            
            if let selfieDocument = innerState.selfieDocument, selfieDocument.resource.isEqual(to: resource) {
                innerState.selfieDocument = nil
            }
            
            if let frontSideDocument = innerState.frontSideDocument, frontSideDocument.resource.isEqual(to: resource) {
                innerState.frontSideDocument = nil
            }
            
            if let backSideDocument = innerState.backSideDocument, backSideDocument.resource.isEqual(to: resource) {
                innerState.backSideDocument = nil
            }
            
            for i in 0 ..< innerState.documents.count {
                if innerState.documents[i].resource.isEqual(to: resource) {
                    innerState.documents.remove(at: i)
                    break
                }
            }
            
            for i in 0 ..< innerState.translations.count {
                if innerState.translations[i].resource.isEqual(to: resource) {
                    innerState.translations.remove(at: i)
                    break
                }
            }
            
            strongSelf.updateInnerState(transition: .immediate, with: innerState)
        }
        self.hiddenItemDisposable.set((galleryController.hiddenMedia
        |> deliverOnMainQueue).start(next: { [weak self] entry in
            guard let strongSelf = self else {
                return
            }
            for itemNode in strongSelf.itemNodes {
                if let itemNode = itemNode as? SecureIdValueFormFileItemNode, let item = itemNode.item {
                    if let entry = entry, let document = item.document, document.resource.isEqual(to: entry.resource) {
                        itemNode.imageNode.isHidden = true
                    } else {
                        itemNode.imageNode.isHidden = false
                    }
                }
            }
        }))
        self.view.endEditing(true)
        self.present(galleryController, SecureIdDocumentGalleryControllerPresentationArguments(transitionArguments: { [weak self] entry in
            guard let strongSelf = self else {
                return nil
            }
            for itemNode in strongSelf.itemNodes {
                if let itemNode = itemNode as? SecureIdValueFormFileItemNode, let item = itemNode.item, let document = item.document {
                    if document.resource.isEqual(to: entry.resource) {
                        return GalleryTransitionArguments(transitionNode: (itemNode.imageNode, itemNode.imageNode.bounds, {
                            return (itemNode.imageNode.view.snapshotContentTree(unhide: true), nil)
                        }), addToTransitionSurface: { view in
                            self?.view.addSubview(view)
                        })
                    }
                }
            }
            return nil
        }))
    }
    
    override func didAppear() {
        if let scrollTo = self.initiallyScrollTo {
            self.scrollTo(scrollTo)
        }
    }
    
    func scrollTo(_ subject: SecureIdDocumentFormScrollToSubject) {
        self.enumerateItemsAndEntries { entry, itemNode -> Bool in
            switch subject {
                case .selfie:
                    if case .selfie = entry {
                        self.scrollToItemNode(itemNode)
                        return false
                    }
                case .translation:
                    if case .translationsHeader = entry {
                        self.scrollToItemNode(itemNode)
                        return false
                    }
            }
            return true
        }
    }
}
