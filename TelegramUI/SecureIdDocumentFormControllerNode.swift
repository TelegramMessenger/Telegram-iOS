import Foundation
import AsyncDisplayKit
import Display
import TelegramCore
import Postbox
import SwiftSignalKit

private enum SecureIdDocumentFormTextField {
    case identifier
    case firstName
    case lastName
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

private enum AddFileTarget {
    case scan
    case selfie
    case frontSide
    case backSide
}

final class SecureIdDocumentFormParams {
    fileprivate let account: Account
    fileprivate let context: SecureIdAccessContext
    fileprivate let addFile: (AddFileTarget) -> Void
    fileprivate let openDocument: (SecureIdVerificationDocument) -> Void
    fileprivate let updateText: (SecureIdDocumentFormTextField, String) -> Void
    fileprivate let activateSelection: (SecureIdDocumentFormSelectionField) -> Void
    fileprivate let deleteValue: () -> Void
    
    fileprivate init(account: Account, context: SecureIdAccessContext, addFile: @escaping (AddFileTarget) -> Void, openDocument: @escaping (SecureIdVerificationDocument) -> Void, updateText: @escaping (SecureIdDocumentFormTextField, String) -> Void, activateSelection: @escaping (SecureIdDocumentFormSelectionField) -> Void, deleteValue: @escaping () -> Void) {
        self.account = account
        self.context = context
        self.addFile = addFile
        self.openDocument = openDocument
        self.updateText = updateText
        self.activateSelection = activateSelection
        self.deleteValue = deleteValue
    }
}

private struct SecureIdDocumentFormIdentityDetailsState: Equatable {
    var firstName: String
    var lastName: String
    var countryCode: String
    var residenceCountryCode: String
    var birthdate: SecureIdDate?
    var gender: SecureIdGender?
    
    func isComplete() -> Bool {
        if self.firstName.isEmpty {
            return false
        }
        if self.lastName.isEmpty {
            return false
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

private struct SecureIdDocumentFormIdentityDocumentState: Equatable {
    var type: SecureIdRequestedIdentityDocument
    var identifier: String
    var expiryDate: SecureIdDate?
    
    func isComplete() -> Bool {
        if self.identifier.isEmpty {
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
        if self.street1.isEmpty {
            return false
        }
        if self.city.isEmpty {
            return false
        }
        if self.countryCode.isEmpty {
            return false
        }
        if self.postcode.isEmpty {
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
                    case .lastName:
                        state.details?.lastName = value
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
                        state.document?.expiryDate = value
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
    fileprivate var actionState: SecureIdDocumentFormActionState
    
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
        return true
    }
    
    func entries() -> [FormControllerItemEntry<SecureIdDocumentFormEntry>] {
        switch self.documentState {
            case let .identity(identity):
                var result: [FormControllerItemEntry<SecureIdDocumentFormEntry>] = []
                var errorIndex = 0
                
                if let document = identity.document, false {
                    result.append(.entry(SecureIdDocumentFormEntry.scansHeader))
                    
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
                        loop: for document in self.documents {
                            switch document {
                                case .local:
                                    fileHashes = nil
                                    break loop
                                case let .remote(file):
                                    fileHashes?.insert(file.fileHash)
                            }
                        }
                        
                        if let fileHashes = fileHashes, !fileHashes.isEmpty, let error = value.errors[.files(hashes: fileHashes)] {
                            //result.append(.spacer)
                        result.append(.entry(SecureIdDocumentFormEntry.error(errorIndex, error)))
                            errorIndex += 1
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
                    result.append(.entry(SecureIdDocumentFormEntry.scansInfo(.identity)))
                    result.append(.spacer)
                }
                
                if let details = identity.details {
                    
                    result.append(.entry(SecureIdDocumentFormEntry.infoHeader(.identity)))
                    result.append(.entry(SecureIdDocumentFormEntry.firstName(details.firstName, self.previousValues[.personalDetails]?.errors[.field(.personalDetails(.firstName))])))
                    result.append(.entry(SecureIdDocumentFormEntry.lastName(details.lastName, self.previousValues[.personalDetails]?.errors[.field(.personalDetails(.lastName))])))
                    
                    result.append(.entry(SecureIdDocumentFormEntry.birthdate(details.birthdate, self.previousValues[.personalDetails]?.errors[.field(.personalDetails(.birthdate))])))
                    result.append(.entry(SecureIdDocumentFormEntry.gender(details.gender, self.previousValues[.personalDetails]?.errors[.field(.personalDetails(.gender))])))
                    result.append(.entry(SecureIdDocumentFormEntry.countryCode(details.countryCode, self.previousValues[.personalDetails]?.errors[.field(.personalDetails(.countryCode))])))
                    result.append(.entry(SecureIdDocumentFormEntry.residenceCountryCode(details.residenceCountryCode, self.previousValues[.personalDetails]?.errors[.field(.personalDetails(.residenceCountryCode))])))
                }
                
                if let document = identity.document {
                    if (identity.details == nil) {
                        result.append(.entry(SecureIdDocumentFormEntry.infoHeader(.identity)))
                    }
                    
                    var identifierError: String?
                    var expiryDateError: String?
                    
                    switch document.type {
                        case .passport:
                            identifierError = self.previousValues[.passport]?.errors[.field(.passport(.documentId))]
                            expiryDateError = self.previousValues[.passport]?.errors[.field(.passport(.expiryDate))]
                        case .internalPassport:
                            identifierError = self.previousValues[.internalPassport]?.errors[.field(.internalPassport(.documentId))]
                            expiryDateError = self.previousValues[.internalPassport]?.errors[.field(.internalPassport(.expiryDate))]
                        case .driversLicense:
                            identifierError = self.previousValues[.driversLicense]?.errors[.field(.driversLicense(.documentId))]
                            expiryDateError = self.previousValues[.driversLicense]?.errors[.field(.driversLicense(.expiryDate))]
                        case .idCard:
                            identifierError = self.previousValues[.idCard]?.errors[.field(.idCard(.documentId))]
                            expiryDateError = self.previousValues[.idCard]?.errors[.field(.idCard(.expiryDate))]
                    }
                    result.append(.entry(SecureIdDocumentFormEntry.identifier(document.identifier, identifierError)))
                    result.append(.entry(SecureIdDocumentFormEntry.expiryDate(document.expiryDate, expiryDateError)))
                }
                
                if self.selfieRequired || self.frontSideRequired || self.backSideRequired {
                    result.append(.spacer)
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
                            result.append(.entry(SecureIdDocumentFormEntry.frontSide(1, document, error)))
                        } else {
                            result.append(.entry(SecureIdDocumentFormEntry.frontSide(1, nil, nil)))
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
                            result.append(.entry(SecureIdDocumentFormEntry.backSide(2, document, error)))
                        } else {
                            result.append(.entry(SecureIdDocumentFormEntry.backSide(2, nil, nil)))
                        }
                    }
                    
                    if self.selfieRequired {
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
                }
                
                if !self.previousValues.isEmpty {
                    result.append(.spacer)
                    result.append(.entry(SecureIdDocumentFormEntry.deleteDocument))
                }
                
                return result
            case let .address(address):
                var result: [FormControllerItemEntry<SecureIdDocumentFormEntry>] = []
                var errorIndex = 0
                if let document = address.document {
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
                        
                        if let fileHashes = fileHashes, !fileHashes.isEmpty, let error = value.errors[.files(hashes: fileHashes)] {
                            result.append(.entry(SecureIdDocumentFormEntry.error(errorIndex, error)))
                            errorIndex += 1
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
                
                if let details = address.details {

                    result.append(.entry(SecureIdDocumentFormEntry.infoHeader(.address)))
                    result.append(.entry(SecureIdDocumentFormEntry.street1(details.street1, self.previousValues[.address]?.errors[.field(.address(.streetLine1))])))
                    result.append(.entry(SecureIdDocumentFormEntry.street2(details.street2, self.previousValues[.address]?.errors[.field(.address(.streetLine2))])))
                    result.append(.entry(SecureIdDocumentFormEntry.city(details.city, self.previousValues[.address]?.errors[.field(.address(.city))])))
                    result.append(.entry(SecureIdDocumentFormEntry.state(details.state, self.previousValues[.address]?.errors[.field(.address(.state))])))
                    result.append(.entry(SecureIdDocumentFormEntry.countryCode(details.countryCode, self.previousValues[.address]?.errors[.field(.address(.countryCode))])))
                    result.append(.entry(SecureIdDocumentFormEntry.postcode(details.postcode, self.previousValues[.address]?.errors[.field(.address(.postCode))])))
                }
                
                if !self.previousValues.isEmpty {
                    result.append(.spacer)
                    result.append(.entry(SecureIdDocumentFormEntry.deleteDocument))
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
        
        switch self.documentState {
            case let .identity(identity):
                if !identity.isComplete() {
                    return .saveNotAvailable
                }
            case let .address(address):
                if !address.isComplete() {
                    return .saveNotAvailable
                }
        }
        
        if self.selfieRequired {
            if let selfieDocument = self.selfieDocument {
                switch selfieDocument {
                    case let .local(local):
                        switch local.state {
                            case .uploading:
                                return .saveNotAvailable
                            case .uploaded:
                                break
                        }
                    case .remote:
                        break
                }
            } else {
                return .saveNotAvailable
            }
        }
        
        for document in self.documents {
            switch document {
                case let .local(local):
                    switch local.state {
                        case .uploading:
                            return .saveNotAvailable
                        case .uploaded:
                            break
                    }
                case .remote:
                    break
            }
        }
        
        return .saveAvailable
    }
}

extension SecureIdDocumentFormState {
    init(requestedData: SecureIdDocumentFormRequestedData, values: [SecureIdValueKey: SecureIdValueWithContext]) {
        switch requestedData {
            case let .identity(details, document, selfie):
                var previousValues: [SecureIdValueKey: SecureIdValueWithContext] = [:]
                var detailsState: SecureIdDocumentFormIdentityDetailsState?
                if details {
                    if let value = values[.personalDetails], case let .personalDetails(personalDetailsValue) = value.value {
                        previousValues[.personalDetails] = value
                        detailsState = SecureIdDocumentFormIdentityDetailsState(firstName: personalDetailsValue.firstName, lastName: personalDetailsValue.lastName, countryCode: personalDetailsValue.countryCode, residenceCountryCode: personalDetailsValue.residenceCountryCode, birthdate: personalDetailsValue.birthdate, gender: personalDetailsValue.gender)
                    } else {
                        detailsState = SecureIdDocumentFormIdentityDetailsState(firstName: "", lastName: "", countryCode: "", residenceCountryCode: "", birthdate: nil, gender: nil)
                    }
                }
                var documentState: SecureIdDocumentFormIdentityDocumentState?
                var verificationDocuments: [SecureIdVerificationDocument] = []
                var selfieDocument: SecureIdVerificationDocument?
                var frontSideRequired: Bool = false
                var backSideRequired: Bool = false
                var frontSideDocument: SecureIdVerificationDocument?
                var backSideDocument: SecureIdVerificationDocument?
                if let document = document {
                    var identifier: String = ""
                    var expiryDate: SecureIdDate?
                    switch document {
                        case .passport:
                            if let value = values[.passport], case let .passport(passport) = value.value {
                                previousValues[value.value.key] = value
                                identifier = passport.identifier
                                expiryDate = passport.expiryDate
                                verificationDocuments = passport.verificationDocuments.compactMap(SecureIdVerificationDocument.init)
                                selfieDocument = passport.selfieDocument.flatMap(SecureIdVerificationDocument.init)
                            }
                            frontSideRequired = true
                        case .internalPassport:
                            if let value = values[.internalPassport], case let .internalPassport(internalPassport) = value.value {
                                previousValues[value.value.key] = value
                                identifier = internalPassport.identifier
                                expiryDate = internalPassport.expiryDate
                                verificationDocuments = internalPassport.verificationDocuments.compactMap(SecureIdVerificationDocument.init)
                                selfieDocument = internalPassport.selfieDocument.flatMap(SecureIdVerificationDocument.init)
                                frontSideDocument = internalPassport.frontSideDocument.flatMap(SecureIdVerificationDocument.init)
                            }
                            frontSideRequired = true
                        case .driversLicense:
                            if let value = values[.driversLicense], case let .driversLicense(driversLicense) = value.value {
                                previousValues[value.value.key] = value
                                identifier = driversLicense.identifier
                                expiryDate = driversLicense.expiryDate
                                verificationDocuments = driversLicense.verificationDocuments.compactMap(SecureIdVerificationDocument.init)
                                selfieDocument = driversLicense.selfieDocument.flatMap(SecureIdVerificationDocument.init)
                                frontSideDocument = driversLicense.frontSideDocument.flatMap(SecureIdVerificationDocument.init)
                                backSideDocument = driversLicense.backSideDocument.flatMap(SecureIdVerificationDocument.init)
                            }
                            frontSideRequired = true
                            backSideRequired = true
                        case .idCard:
                            if let value = values[.idCard], case let .idCard(idCard) = value.value {
                                previousValues[value.value.key] = value
                                identifier = idCard.identifier
                                expiryDate = idCard.expiryDate
                                verificationDocuments = idCard.verificationDocuments.compactMap(SecureIdVerificationDocument.init)
                                selfieDocument = idCard.selfieDocument.flatMap(SecureIdVerificationDocument.init)
                                frontSideDocument = idCard.frontSideDocument.flatMap(SecureIdVerificationDocument.init)
                                backSideDocument = idCard.backSideDocument.flatMap(SecureIdVerificationDocument.init)
                            }
                            frontSideRequired = true
                            backSideRequired = true
                    }
                    documentState = SecureIdDocumentFormIdentityDocumentState(type: document, identifier: identifier, expiryDate: expiryDate)
                }
                let formState = SecureIdDocumentFormIdentityState(details: detailsState, document: documentState)
                self.init(previousValues: previousValues, documentState: .identity(formState), documents: verificationDocuments, selfieRequired: selfie, selfieDocument: selfieDocument, frontSideRequired: frontSideRequired, frontSideDocument: frontSideDocument, backSideRequired: backSideRequired, backSideDocument: backSideDocument, actionState: .none)
            case let .address(details, document):
                var previousValues: [SecureIdValueKey: SecureIdValueWithContext] = [:]
                var detailsState: SecureIdDocumentFormAddressDetailsState?
                var documentState: SecureIdRequestedAddressDocument?
                var verificationDocuments: [SecureIdVerificationDocument] = []
                
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
                        }
                    case .temporaryRegistration:
                        if let value = values[.temporaryRegistration], case let .temporaryRegistration(temporaryRegistration) = value.value {
                            previousValues[value.value.key] = value
                            verificationDocuments = temporaryRegistration.verificationDocuments.compactMap(SecureIdVerificationDocument.init)
                        }
                    case .bankStatement:
                        if let value = values[.bankStatement], case let .bankStatement(bankStatement) = value.value {
                            previousValues[value.value.key] = value
                            verificationDocuments = bankStatement.verificationDocuments.compactMap(SecureIdVerificationDocument.init)
                        }
                    case .utilityBill:
                        if let value = values[.utilityBill], case let .utilityBill(utilityBill) = value.value {
                            previousValues[value.value.key] = value
                            verificationDocuments = utilityBill.verificationDocuments.compactMap(SecureIdVerificationDocument.init)
                        }
                    case .rentalAgreement:
                        if let value = values[.rentalAgreement], case let .rentalAgreement(rentalAgreement) = value.value {
                            previousValues[value.value.key] = value
                            verificationDocuments = rentalAgreement.verificationDocuments.compactMap(SecureIdVerificationDocument.init)
                        }
                    }
                    documentState = document
                }
                let formState = SecureIdDocumentFormAddressState(details: detailsState, document: documentState)
                self.init(previousValues: previousValues, documentState: .address(formState), documents: verificationDocuments, selfieRequired: false, selfieDocument: nil, frontSideRequired: false, frontSideDocument: nil, backSideRequired: false, backSideDocument: nil, actionState: .none)
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
                    values[.personalDetails] = .personalDetails(SecureIdPersonalDetailsValue(firstName: details.firstName, lastName: details.lastName, birthdate: birthdate, countryCode: details.countryCode, residenceCountryCode: details.residenceCountryCode, gender: gender))
                }
                if let document = identity.document {
                    guard !document.identifier.isEmpty else {
                        return nil
                    }
                    
                    switch document.type {
                        case .passport:
                            values[.passport] = .passport(SecureIdPassportValue(identifier: document.identifier, expiryDate: document.expiryDate, verificationDocuments: verificationDocuments, selfieDocument: selfieDocument, frontSideDocument: frontSideDocument))
                        case .internalPassport:
                            values[.internalPassport] = .internalPassport(SecureIdInternalPassportValue(identifier: document.identifier, expiryDate: document.expiryDate, verificationDocuments: verificationDocuments, selfieDocument: selfieDocument, frontSideDocument: frontSideDocument))
                        case .driversLicense:
                            values[.driversLicense] = .driversLicense(SecureIdDriversLicenseValue(identifier: document.identifier, expiryDate: document.expiryDate, verificationDocuments: verificationDocuments, selfieDocument: selfieDocument, frontSideDocument: frontSideDocument, backSideDocument: backSideDocument))
                        case .idCard:
                            values[.idCard] = .idCard(SecureIdIDCardValue(identifier: document.identifier, expiryDate: document.expiryDate, verificationDocuments: verificationDocuments, selfieDocument: selfieDocument, frontSideDocument: frontSideDocument, backSideDocument: backSideDocument))
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
                    switch document {
                        case .passportRegistration:
                            values[.passportRegistration] = .passportRegistration(SecureIdPassportRegistrationValue(verificationDocuments: verificationDocuments))
                        case .temporaryRegistration:
                            values[.temporaryRegistration] = .temporaryRegistration(SecureIdTemporaryRegistrationValue(verificationDocuments: verificationDocuments))
                        case .bankStatement:
                            values[.bankStatement] = .bankStatement(SecureIdBankStatementValue(verificationDocuments: verificationDocuments))
                        case .utilityBill:
                            values[.utilityBill] = .utilityBill(SecureIdUtilityBillValue(verificationDocuments: verificationDocuments))
                        case .rentalAgreement:
                            values[.rentalAgreement] = .rentalAgreement(SecureIdRentalAgreementValue(verificationDocuments: verificationDocuments))
                    }
                }
                return values
        }
    }
}

enum SecureIdDocumentFormEntryId: Hashable {
    case scansHeader
    case scan(SecureIdVerificationDocumentId)
    case addScan
    case scansInfo
    case infoHeader
    case identifier
    case firstName
    case lastName
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
    
    case street1
    case street2
    case city
    case state
    case postcode
    
    case error
}

enum SecureIdDocumentFormEntryCategory {
    case identity
    case address
}

enum SecureIdDocumentFormEntry: FormControllerEntry {
    case scansHeader
    case scan(Int, SecureIdVerificationDocument, String?)
    case addScan(Bool)
    case scansInfo(SecureIdDocumentFormEntryCategory)
    case infoHeader(SecureIdDocumentFormEntryCategory)
    case identifier(String, String?)
    case firstName(String, String?)
    case lastName(String, String?)
    case gender(SecureIdGender?, String?)
    case countryCode(String, String?)
    case residenceCountryCode(String, String?)
    case birthdate(SecureIdDate?, String?)
    case expiryDate(SecureIdDate?, String?)
    case deleteDocument
    case requestedDocumentsHeader
    case selfie(Int, SecureIdVerificationDocument?, String?)
    case frontSide(Int, SecureIdVerificationDocument?, String?)
    case backSide(Int, SecureIdVerificationDocument?, String?)
    case documentsInfo
    case error(Int, String)
    
    case street1(String, String?)
    case street2(String, String?)
    case city(String, String?)
    case state(String, String?)
    case postcode(String, String?)
    
    var stableId: SecureIdDocumentFormEntryId {
        switch self {
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
            case .lastName:
                return .lastName
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
            case .error:
                return .error
        }
    }
    
    func isEqual(to: SecureIdDocumentFormEntry) -> Bool {
        switch self {
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
            case let .lastName(value, error):
                if case .lastName(value, error) = to {
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
            case let .countryCode(value, error):
                if case .countryCode(value, error) = to {
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
            case .deleteDocument:
                if case .deleteDocument = to {
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
            case let .frontSide(index, document, error):
                if case .frontSide(index, document, error) = to {
                    return true
                } else {
                    return false
                }
            case let .backSide(index, document, error):
                if case .backSide(index, document, error) = to {
                    return true
                } else {
                    return false
                }
            case .documentsInfo:
                if case .documentsInfo = to {
                    return true
                } else {
                    return false
                }
            case let .error(index, text):
                if case .error(index, text) = to {
                    return true
                } else {
                    return false
                }
        }
    }
    
    func item(params: SecureIdDocumentFormParams, strings: PresentationStrings) -> FormControllerItem {
        switch self {
            case .scansHeader:
                return FormControllerHeaderItem(text: "SCANS")
            case let .scan(index, document, error):
                return SecureIdValueFormFileItem(account: params.account, context: params.context, document: document, placeholder: nil, title: "Scan \(index + 1)", label: error.flatMap(SecureIdValueFormFileItemLabel.error) ?? .timestamp, activated: {
                    params.openDocument(document)
                })
            case let .addScan(hasAny):
                return FormControllerActionItem(type: .accent, title: hasAny ? "Upload Additional Scan" : "Upload Scan", fullTopInset: true, activated: {
                    params.addFile(.scan)
                })
            case let .scansInfo(type):
                let text: String
                switch type {
                    case .identity:
                        text = "The document must contain your photograph, name, surname, date of birth, citizenship, document issue date and document number."
                    case .address:
                        text = "The document must contain your first and last name, your residential address, a stamp / barcode / QR code / logo, and issue date, no more that 3 months ago."
                }
                return FormControllerTextItem(text: text)
            case let .infoHeader(type):
                let text: String
                switch type {
                    case .identity:
                        text = "DOCUMENT DETAILS"
                    case .address:
                        text = "ADDRESS"
                }
                return FormControllerHeaderItem(text: text)
            case let .identifier(value, error):
                return FormControllerTextInputItem(title: "Document #", text: value, placeholder: "Document Number", error: error, textUpdated: { text in
                    params.updateText(.identifier, text)
                })
            case let .firstName(value, error):
                return FormControllerTextInputItem(title: "First Name", text: value, placeholder: "First Name", error: error, textUpdated: { text in
                    params.updateText(.firstName, text)
                })
            case let .lastName(value, error):
                return FormControllerTextInputItem(title: "Last Name", text: value, placeholder: "Last Name", error: error, textUpdated: { text in
                    params.updateText(.lastName, text)
                })
            case let .gender(value, error):
                var text = ""
                if let value = value {
                    switch value {
                        case .male:
                            text = "Male"
                        case .female:
                            text = "Female"
                    }
                }
                return FormControllerDetailActionItem(title: "Gender", text: text, placeholder: "Gender", error: error, activated: {
                    params.activateSelection(.gender)
                })
            case let .countryCode(value, error):
                return FormControllerDetailActionItem(title: "Country", text: AuthorizationSequenceCountrySelectionController.lookupCountryNameById(value.uppercased(), strings: strings) ?? "", placeholder: "Country", error: error, activated: {
                    params.activateSelection(.country)
                })
            case let .residenceCountryCode(value, error):
                return FormControllerDetailActionItem(title: "Residence", text: AuthorizationSequenceCountrySelectionController.lookupCountryNameById(value.uppercased(), strings: strings) ?? "", placeholder: "Residence Country", error: error, activated: {
                    params.activateSelection(.residenceCountry)
                })
            case let .birthdate(value, error):
                return FormControllerDetailActionItem(title: "Date of Birth", text: value.flatMap({ stringForDate(timestamp: $0.timestamp, strings: strings) }) ?? "", placeholder: "Date of Birth", error: error, activated: {
                    params.activateSelection(.date(value?.timestamp, .birthdate))
                })
            case let .expiryDate(value, error):
                return FormControllerDetailActionItem(title: "Expiry Date", text: value.flatMap({ stringForDate(timestamp: $0.timestamp, strings: strings) }) ?? "", placeholder: "Expiry Date", error: error, activated: {
                    params.activateSelection(.date(value?.timestamp, .expiry))
                })
            case .deleteDocument:
                return FormControllerActionItem(type: .destructive, title: "Delete Document", activated: {
                    params.deleteValue()
                })
            case let .street1(value, error):
                return FormControllerTextInputItem(title: "Street", text: value, placeholder: "Street and number, P.O. box", error: error, textUpdated: { text in
                    params.updateText(.street1, text)
                })
            case let .street2(value, error):
                return FormControllerTextInputItem(title: "", text: value, placeholder: "Apt., suite, unit, builting, block", error: error, textUpdated: { text in
                    params.updateText(.street2, text)
                })
            case let .city(value, error):
                return FormControllerTextInputItem(title: "City", text: value, placeholder: "City", error: error, textUpdated: { text in
                    params.updateText(.city, text)
                })
            case let .state(value, error):
                return FormControllerTextInputItem(title: "Region", text: value, placeholder: "State / Province / Region", error: error, textUpdated: { text in
                    params.updateText(.state, text)
                })
            case let .postcode(value, error):
                return FormControllerTextInputItem(title: "Postcode", text: value, placeholder: "Postcode", error: error, textUpdated: { text in
                    params.updateText(.postcode, text)
                })
            case .requestedDocumentsHeader:
                return FormControllerHeaderItem(text: "REQUESTED FILES")
            case let .selfie(_, document, error):
                let label: SecureIdValueFormFileItemLabel
                if let error = error {
                    label = .error(error)
                } else if document != nil {
                    label = .timestamp
                } else {
                    label = .text("Upload a selfie of yourself holding document")
                }
                return SecureIdValueFormFileItem(account: params.account, context: params.context, document: document, placeholder: UIImage(bundleImageName: "Secure ID/DocumentInputSelfie"), title: "Selfie", label: label, activated: {
                    if let document = document {
                        params.openDocument(document)
                    } else {
                        params.addFile(.selfie)
                    }
                })
            case let .frontSide(_, document, error):
                let label: SecureIdValueFormFileItemLabel
                if let error = error {
                    label = .error(error)
                } else if document != nil {
                    label = .timestamp
                } else {
                    label = .text("Upload a front side photo of a document")
                }
                return SecureIdValueFormFileItem(account: params.account, context: params.context, document: document, placeholder: UIImage(bundleImageName: "Secure ID/PassportInputFrontSide"), title: "Front Side", label: label, activated: {
                    if let document = document {
                        params.openDocument(document)
                    } else {
                        params.addFile(.frontSide)
                    }
                })
            case let .backSide(_, document, error):
                let label: SecureIdValueFormFileItemLabel
                if let error = error {
                    label = .error(error)
                } else if document != nil {
                    label = .timestamp
                } else {
                    label = .text("Upload a reverse side photo of a document")
                }
                return SecureIdValueFormFileItem(account: params.account, context: params.context, document: document, placeholder: UIImage(bundleImageName: "Secure ID/DocumentInputBackSide"), title: "Reverse Side", label: label, activated: {
                    if let document = document {
                        params.openDocument(document)
                    } else {
                        params.addFile(.backSide)
                    }
                })
            case .documentsInfo:
                return FormControllerTextItem(text: "")
            case let .error(_, text):
                return FormControllerTextItem(text: text, color: .error)
        }
    }
}

struct SecureIdDocumentFormControllerNodeInitParams {
    let account: Account
    let context: SecureIdAccessContext
}

final class SecureIdDocumentFormControllerNode: FormControllerNode<SecureIdDocumentFormControllerNodeInitParams, SecureIdDocumentFormState> {
    private var _itemParams: SecureIdDocumentFormParams?
    override var itemParams: SecureIdDocumentFormParams {
        return self._itemParams!
    }
    
    private var theme: PresentationTheme
    private var strings: PresentationStrings
    
    private let account: Account
    private let context: SecureIdAccessContext
    
    private let uploadContext: SecureIdVerificationDocumentsContext
    
    var actionInputStateUpdated: ((SecureIdDocumentFormInputState) -> Void)?
    var completedWithValues: (([SecureIdValueWithContext]?) -> Void)?
    var dismiss: (() -> Void)?
    
    private let actionDisposable = MetaDisposable()
    private let hiddenItemDisposable = MetaDisposable()
    
    required init(initParams: SecureIdDocumentFormControllerNodeInitParams, theme: PresentationTheme, strings: PresentationStrings) {
        self.theme = theme
        self.strings = strings
        self.account = initParams.account
        self.context = initParams.context
        
        var updateImpl: ((Int64, SecureIdVerificationLocalDocumentState) -> Void)?
        
        self.uploadContext = SecureIdVerificationDocumentsContext(postbox: self.account.postbox, network: self.account.network, context: self.context, update: { id, state in
            updateImpl?(id, state)
        })
        
        super.init(initParams: initParams, theme: theme, strings: strings)
        
        self._itemParams = SecureIdDocumentFormParams(account: self.account, context: self.context, addFile: { [weak self] type in
            if let strongSelf = self {
                strongSelf.presentAssetPicker(type)
            }
        }, openDocument: { [weak self] document in
            if let strongSelf = self {
                strongSelf.presentGallery(document: document)
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
                            default:
                                break
                        }
                }
                if let valueKey = valueKey, let errorKey = errorKey {
                    if let previousValue = innerState.previousValues[valueKey] {
                        innerState.previousValues[valueKey] = previousValue.withRemovedErrors([errorKey])
                    }
                }
                strongSelf.updateInnerState(transition: .immediate, with: innerState)
            }
        }, activateSelection: { [weak self] field in
            if let strongSelf = self {
                switch field {
                    case .country:
                        let controller = AuthorizationSequenceCountrySelectionController(strings: strings, theme: AuthorizationSequenceCountrySelectionTheme(presentationTheme: strongSelf.theme), displayCodes: false)
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
                                    if let previousValue = innerState.previousValues[valueKey] {
                                        innerState.previousValues[valueKey] = previousValue.withRemovedErrors([errorKey])
                                    }
                                }
                                strongSelf.updateInnerState(transition: .immediate, with: innerState)
                            }
                        }
                        strongSelf.view.endEditing(true)
                        strongSelf.present(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                    case .residenceCountry:
                        let controller = AuthorizationSequenceCountrySelectionController(strings: strings, theme: AuthorizationSequenceCountrySelectionTheme(presentationTheme: strongSelf.theme), displayCodes: false)
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
                                    if let previousValue = innerState.previousValues[valueKey] {
                                        innerState.previousValues[valueKey] = previousValue.withRemovedErrors([errorKey])
                                    }
                                }
                                strongSelf.updateInnerState(transition: .immediate, with: innerState)
                            }
                        }
                        strongSelf.view.endEditing(true)
                        strongSelf.present(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                    case let .date(current, field):
                        var emptyTitle: String?
                        if case .expiry = field {
                            emptyTitle = "Does not expire"
                        }
                        let controller = DateSelectionActionSheetController(theme: theme, strings: strings, currentValue: current ?? Int32(Date().timeIntervalSince1970), emptyTitle: emptyTitle, applyValue: { value in
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
                                    if let previousValue = innerState.previousValues[valueKey] {
                                        innerState.previousValues[valueKey] = previousValue.withRemovedErrors([errorKey])
                                    }
                                }
                                strongSelf.updateInnerState(transition: .immediate, with: innerState)
                            }
                        })
                        strongSelf.view.endEditing(true)
                        strongSelf.present(controller, nil)
                    case .gender:
                        let controller = ActionSheetController(presentationTheme: theme)
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
                                    if let previousValue = innerState.previousValues[valueKey] {
                                        innerState.previousValues[valueKey] = previousValue.withRemovedErrors([errorKey])
                                    }
                                }
                                strongSelf.updateInnerState(transition: .immediate, with: innerState)
                            }
                        }
                        controller.setItemGroups([
                            ActionSheetItemGroup(items: [
                                ActionSheetButtonItem(title: "Male", action: {
                                    dismissAction()
                                    applyAction(.male)
                                }),
                                ActionSheetButtonItem(title: "Female", action: {
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
                strongSelf.updateInnerState(transition: .immediate, with: innerState)
            }
        }
    }
    
    deinit {
        self.actionDisposable.dispose()
    }
    
    private func presentAssetPicker(_ type: AddFileTarget) {
        guard let validLayout = self.layoutState?.layout else {
            return
        }
        let attachmentType: SecureIdAttachmentMenuType
        switch type {
            case .scan:
                attachmentType = .multiple
            case .backSide, .frontSide:
                attachmentType = .generic
            case .selfie:
                attachmentType = .selfie
        }
        presentLegacySecureIdAttachmentMenu(account: self.account, present: { [weak self] c in
            self?.present(c, nil)
            }, validLayout: validLayout, type: attachmentType, completion: { [weak self] resources, recognizedData in
            self?.addDocuments(type: type, resources: resources, recognizedData: recognizedData)
        })
    }
    
    private func addDocuments(type: AddFileTarget, resources: [TelegramMediaResource], recognizedData: SecureIdRecognizedDocumentData?) {
        guard var innerState = self.innerState else {
            return
        }
        switch type {
            case .scan:
                for resource in resources {
                    let id = arc4random64()
                    innerState.documents.append(.local(SecureIdVerificationLocalDocument(id: id, resource: SecureIdLocalImageResource(localId: id, source: resource), timestamp: Int32(Date().timeIntervalSince1970), state: .uploading(0.0))))
                }
            case .selfie:
                loop: for resource in resources {
                    let id = arc4random64()
                    innerState.selfieDocument = .local(SecureIdVerificationLocalDocument(id: id, resource: SecureIdLocalImageResource(localId: id, source: resource), timestamp: Int32(Date().timeIntervalSince1970), state: .uploading(0.0)))
                    break loop
                }
            case .frontSide:
                loop: for resource in resources {
                    let id = arc4random64()
                    innerState.frontSideDocument = .local(SecureIdVerificationLocalDocument(id: id, resource: SecureIdLocalImageResource(localId: id, source: resource), timestamp: Int32(Date().timeIntervalSince1970), state: .uploading(0.0)))
                    break loop
                }
            case .backSide:
                loop: for resource in resources {
                    let id = arc4random64()
                    innerState.backSideDocument = .local(SecureIdVerificationLocalDocument(id: id, resource: SecureIdLocalImageResource(localId: id, source: resource), timestamp: Int32(Date().timeIntervalSince1970), state: .uploading(0.0)))
                    break loop
                }
        }
        if let recognizedData = recognizedData {
            switch innerState.documentState {
                case var .identity(identity):
                    if var document = identity.document {
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
                        
                        if var details = identity.details {
                            if details.firstName.isEmpty {
                                details.firstName = recognizedData.firstName ?? ""
                            }
                            if details.lastName.isEmpty {
                                details.lastName = recognizedData.lastName ?? ""
                            }
                            if details.birthdate == nil, let birthdate = recognizedData.birthDate {
                                details.birthdate = SecureIdDate(timestamp: Int32(birthdate.timeIntervalSince1970))
                            }
                            if details.gender == nil, let gender = recognizedData.gender {
                                if gender == "M" {
                                    details.gender = .male
                                } else {
                                    details.gender = .female
                                }
                            }
                            if details.countryCode.isEmpty {
                                
                                details.countryCode = recognizedData.issuingCountry ?? ""
                            }
                            identity.details = details
                        }
                        if document.identifier.isEmpty {
                            document.identifier = recognizedData.documentNumber ?? ""
                        }
                        if document.expiryDate == nil, let expiryDate = recognizedData.expiryDate {
                            document.expiryDate = SecureIdDate(timestamp: Int32(expiryDate.timeIntervalSince1970))
                        }
                        identity.document = document
                        innerState.documentState = .identity(identity)
                    }
                default:
                    break
            }
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
        self.uploadContext.stateUpdated(documents)
        
        let actionInputState = innerState.actionInputState()
        if previousActionInputState != actionInputState {
            self.actionInputStateUpdated?(actionInputState)
        }
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
            saveValues.append(saveSecureIdValue(postbox: self.account.postbox, network: self.account.network, context: self.context, value: value, uploadedFiles: self.uploadContext.uploadedFiles))
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
        guard var innerState = self.innerState, !innerState.previousValues.isEmpty else {
            return
        }
        guard case .none = innerState.actionState else {
            return
        }
        
        innerState.actionState = .deleting
        self.updateInnerState(transition: .immediate, with: innerState)
        
        self.actionDisposable.set((deleteSecureIdValues(network: self.account.network, keys: Set(innerState.previousValues.keys))
        |> deliverOnMainQueue).start(error: { [weak self] error in
            if let strongSelf = self {
                guard var innerState = strongSelf.innerState else {
                    return
                }
                guard case .deleting = innerState.actionState else {
                    return
                }
                innerState.actionState = .none
                strongSelf.updateInnerState(transition: .immediate, with: innerState)
            }
        }, completed: { [weak self] in
            if let strongSelf = self {
                strongSelf.completedWithValues?([])
            }
        }))
    }
    
    private func presentGallery(document: SecureIdVerificationDocument) {
        guard let innerState = self.innerState else {
            return
        }
        
        var entries: [SecureIdDocumentGalleryEntry] = []
        var index = 0
        var centralIndex = 0
        if let selfieDocument = innerState.selfieDocument, selfieDocument.id == document.id {
            entries.append(SecureIdDocumentGalleryEntry(index: Int32(index), resource: selfieDocument.resource, location: SecureIdDocumentGalleryEntryLocation(position: Int32(index), totalCount: 1), error: ""))
            centralIndex = index
            index += 1
        } else {
            for itemDocument in innerState.documents {
                entries.append(SecureIdDocumentGalleryEntry(index: Int32(index), resource: itemDocument.resource, location: SecureIdDocumentGalleryEntryLocation(position: Int32(index), totalCount: Int32(innerState.documents.count)), error: ""))
                if document.id == itemDocument.id {
                    centralIndex = index
                }
                index += 1
            }
        }
        
        let galleryController = SecureIdDocumentGalleryController(account: self.account, context: self.context, entries: entries, centralIndex: centralIndex, replaceRootController: { _, _ in
            
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
                innerState.selfieDocument = nil
            }
            
            for i in 0 ..< innerState.documents.count {
                if innerState.documents[i].resource.isEqual(to: resource) {
                    innerState.documents.remove(at: i)
                    break
                }
            }
            
            strongSelf.updateInnerState(transition: .immediate, with: innerState)
        }
        self.hiddenItemDisposable.set((galleryController.hiddenMedia |> deliverOnMainQueue).start(next: { [weak self] entry in
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
        self.present(galleryController, SecureIdDocumentGalleryControllerPresentationArguments(transitionArguments: { [weak self] entry in
            guard let strongSelf = self else {
                return nil
            }
            for itemNode in strongSelf.itemNodes {
                if let itemNode = itemNode as? SecureIdValueFormFileItemNode, let item = itemNode.item, let document = item.document {
                    if document.resource.isEqual(to: entry.resource) {
                        return GalleryTransitionArguments(transitionNode: (itemNode.imageNode, {
                            return itemNode.imageNode.view.snapshotContentTree(unhide: true)
                        }), addToTransitionSurface: { view in
                            self?.view.addSubview(view)
                        })
                    }
                }
            }
            return nil
        }))
    }
}
