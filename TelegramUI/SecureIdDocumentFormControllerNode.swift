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
    case region
    case postcode
}

private enum SecureIdDocumentFormDateField {
    case birthdate
    case issue
    case expiry
}

private enum SecureIdDocumentFormGenderField {
    case gender
}

private enum SecureIdDocumentFormSelectionField {
    case country
    case date(Int32?, SecureIdDocumentFormDateField)
    case gender
}

private enum AddFileTarget {
    case scan
    case selfie
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
    var issueDate: SecureIdDate?
    var expiryDate: SecureIdDate?
    
    func isComplete() -> Bool {
        if self.identifier.isEmpty {
            return false
        }
        if self.issueDate == nil {
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
    var region: String
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
                    case .region:
                        state.details?.region = value
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
    
    mutating func updateDateField(type: SecureIdDocumentFormDateField, value: SecureIdDate?) {
        switch self {
            case var .identity(state):
                switch type {
                    case .birthdate:
                        state.details?.birthdate = value
                    case .issue:
                        state.document?.issueDate = value
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
    fileprivate let previousValues: [SecureIdValueKey: SecureIdValueWithContext]
    fileprivate var documentState: SecureIdDocumentFormDocumentState
    fileprivate var documents: [SecureIdVerificationDocument]
    fileprivate var selfieRequired: Bool
    fileprivate var selfieDocument: SecureIdVerificationDocument?
    fileprivate var actionState: SecureIdDocumentFormActionState
    fileprivate var errors: [SecureIdErrorKey: [String]]
    
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
            if !self.documents[i].isEqual(to: to.documents[i]) {
                return false
            }
        }
        if self.selfieRequired != to.selfieRequired {
            return false
        }
        if self.selfieDocument != to.selfieDocument {
            return false
        }
        return true
    }
    
    func entries() -> [FormControllerItemEntry<SecureIdDocumentFormEntry>] {
        switch self.documentState {
            case let .identity(identity):
                var result: [FormControllerItemEntry<SecureIdDocumentFormEntry>] = []
                
                var errorIndex = 0
                if let errors = self.errors[.personalDetails], !errors.isEmpty {
                    result.append(.spacer)
                    for error in errors {
                        result.append(.entry(SecureIdDocumentFormEntry.error(errorIndex, error)))
                        errorIndex += 1
                    }
                    result.append(.spacer)
                }
                
                if let _ = identity.document {
                    result.append(.entry(SecureIdDocumentFormEntry.scansHeader))
                    for i in 0 ..< self.documents.count {
                        result.append(.entry(SecureIdDocumentFormEntry.scan(i, self.documents[i])))
                    }
                    result.append(.entry(SecureIdDocumentFormEntry.addScan(!self.documents.isEmpty)))
                    result.append(.entry(SecureIdDocumentFormEntry.scansInfo(.identity)))
                    result.append(.spacer)
                }
                
                if self.selfieRequired {
                    result.append(.entry(SecureIdDocumentFormEntry.selfieHeader))
                    if let document = self.selfieDocument {
                        result.append(.entry(SecureIdDocumentFormEntry.selfie(0, document)))
                    }
                    result.append(.entry(SecureIdDocumentFormEntry.addSelfie))
                    result.append(.entry(SecureIdDocumentFormEntry.selfieInfo))
                    result.append(.spacer)
                }
                
                if let details = identity.details {
                    result.append(.entry(SecureIdDocumentFormEntry.infoHeader(.identity)))
                    result.append(.entry(SecureIdDocumentFormEntry.firstName(details.firstName)))
                    result.append(.entry(SecureIdDocumentFormEntry.lastName(details.lastName)))
                    result.append(.entry(SecureIdDocumentFormEntry.gender(details.gender)))
                    result.append(.entry(SecureIdDocumentFormEntry.birthdate(details.birthdate)))
                    result.append(.entry(SecureIdDocumentFormEntry.countryCode(details.countryCode)))
                }
                
                if let document = identity.document {
                    result.append(.entry(SecureIdDocumentFormEntry.identifier(document.identifier)))
                    result.append(.entry(SecureIdDocumentFormEntry.issueDate(document.issueDate)))
                    result.append(.entry(SecureIdDocumentFormEntry.expiryDate(document.expiryDate)))
                    if !self.previousValues.isEmpty {
                        result.append(.spacer)
                        result.append(.entry(SecureIdDocumentFormEntry.deleteDocument))
                    }
                }
                
                return result
            case let .address(address):
                var result: [FormControllerItemEntry<SecureIdDocumentFormEntry>] = []
                if let _ = address.document {
                    result.append(.entry(SecureIdDocumentFormEntry.scansHeader))
                    for i in 0 ..< self.documents.count {
                        result.append(.entry(SecureIdDocumentFormEntry.scan(i, self.documents[i])))
                    }
                    result.append(.entry(SecureIdDocumentFormEntry.addScan(!self.documents.isEmpty)))
                    result.append(.entry(SecureIdDocumentFormEntry.scansInfo(.address)))
                    result.append(.spacer)
                }
                
                if let details = address.details {
                    result.append(.entry(SecureIdDocumentFormEntry.infoHeader(.address)))
                    result.append(.entry(SecureIdDocumentFormEntry.street1(details.street1)))
                    result.append(.entry(SecureIdDocumentFormEntry.street2(details.street2)))
                    result.append(.entry(SecureIdDocumentFormEntry.city(details.city)))
                    result.append(.entry(SecureIdDocumentFormEntry.region(details.region)))
                    result.append(.entry(SecureIdDocumentFormEntry.countryCode(details.countryCode)))
                    result.append(.entry(SecureIdDocumentFormEntry.postcode(details.postcode)))
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
    init(requestedData: SecureIdDocumentFormRequestedData, values: [SecureIdValueKey: SecureIdValueWithContext], errors: [SecureIdErrorKey: [String]]) {
        switch requestedData {
            case let .identity(details, document, selfie):
                var previousValues: [SecureIdValueKey: SecureIdValueWithContext] = [:]
                var detailsState: SecureIdDocumentFormIdentityDetailsState?
                if details {
                    if let value = values[.personalDetails], case let .personalDetails(personalDetailsValue) = value.value {
                        previousValues[.personalDetails] = value
                        detailsState = SecureIdDocumentFormIdentityDetailsState(firstName: personalDetailsValue.firstName, lastName: personalDetailsValue.lastName, countryCode: personalDetailsValue.countryCode, birthdate: personalDetailsValue.birthdate, gender: personalDetailsValue.gender)
                    } else {
                        detailsState = SecureIdDocumentFormIdentityDetailsState(firstName: "", lastName: "", countryCode: "", birthdate: nil, gender: nil)
                    }
                }
                var documentState: SecureIdDocumentFormIdentityDocumentState?
                var verificationDocuments: [SecureIdVerificationDocument] = []
                var selfieDocument: SecureIdVerificationDocument?
                if let document = document {
                    var identifier: String = ""
                    var issueDate: SecureIdDate?
                    var expiryDate: SecureIdDate?
                    switch document {
                        case .passport:
                            if let value = values[.passport], case let .passport(passport) = value.value {
                                previousValues[value.value.key] = value
                                identifier = passport.identifier
                                issueDate = passport.issueDate
                                expiryDate = passport.expiryDate
                                verificationDocuments = passport.verificationDocuments.compactMap(SecureIdVerificationDocument.init)
                                selfieDocument = passport.selfieDocument.flatMap(SecureIdVerificationDocument.init)
                            }
                        case .driversLicense:
                            if let value = values[.driversLicense], case let .driversLicense(driversLicense) = value.value {
                                previousValues[value.value.key] = value
                                identifier = driversLicense.identifier
                                issueDate = driversLicense.issueDate
                                expiryDate = driversLicense.expiryDate
                                verificationDocuments = driversLicense.verificationDocuments.compactMap(SecureIdVerificationDocument.init)
                                selfieDocument = driversLicense.selfieDocument.flatMap(SecureIdVerificationDocument.init)
                            }
                        case .idCard:
                            if let value = values[.idCard], case let .idCard(idCard) = value.value {
                                previousValues[value.value.key] = value
                                identifier = idCard.identifier
                                issueDate = idCard.issueDate
                                expiryDate = idCard.expiryDate
                                verificationDocuments = idCard.verificationDocuments.compactMap(SecureIdVerificationDocument.init)
                                selfieDocument = idCard.selfieDocument.flatMap(SecureIdVerificationDocument.init)
                            }
                    }
                    documentState = SecureIdDocumentFormIdentityDocumentState(type: document, identifier: identifier, issueDate: issueDate, expiryDate: expiryDate)
                }
                let formState = SecureIdDocumentFormIdentityState(details: detailsState, document: documentState)
                self.init(previousValues: previousValues, documentState: .identity(formState), documents: verificationDocuments, selfieRequired: selfie, selfieDocument: selfieDocument, actionState: .none, errors: errors)
            case let .address(details, document):
                var previousValues: [SecureIdValueKey: SecureIdValueWithContext] = [:]
                var detailsState: SecureIdDocumentFormAddressDetailsState?
                var documentState: SecureIdRequestedAddressDocument?
                var verificationDocuments: [SecureIdVerificationDocument] = []
                
                if details {
                    if let value = values[.address], case let .address(address) = value.value {
                        previousValues[value.value.key] = value
                        detailsState = SecureIdDocumentFormAddressDetailsState(street1: address.street1, street2: address.street2, city: address.city, region: address.region, countryCode: address.countryCode, postcode: address.postcode)
                    } else {
                        detailsState = SecureIdDocumentFormAddressDetailsState(street1: "", street2: "", city: "", region: "", countryCode: "", postcode: "")
                    }
                }
                if let document = document {
                    switch document {
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
                self.init(previousValues: previousValues, documentState: .address(formState), documents: verificationDocuments, selfieRequired: false, selfieDocument: nil, actionState: .none, errors: errors)
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
                    guard let birthdate = details.birthdate else {
                        return nil
                    }
                    guard let gender = details.gender else {
                        return nil
                    }
                    values[.personalDetails] = .personalDetails(SecureIdPersonalDetailsValue(firstName: details.firstName, lastName: details.lastName, birthdate: birthdate, countryCode: details.countryCode, gender: gender))
                }
                if let document = identity.document {
                    guard !document.identifier.isEmpty else {
                        return nil
                    }
                    guard let issueDate = document.issueDate else {
                        return nil
                    }
                    
                    switch document.type {
                        case .passport:
                            values[.passport] = .passport(SecureIdPassportValue(identifier: document.identifier, issueDate: issueDate, expiryDate: document.expiryDate, verificationDocuments: verificationDocuments, selfieDocument: selfieDocument))
                        case .driversLicense:
                            values[.driversLicense] = .driversLicense(SecureIdDriversLicenseValue(identifier: document.identifier, issueDate: issueDate, expiryDate: document.expiryDate, verificationDocuments: verificationDocuments, selfieDocument: selfieDocument))
                        case .idCard:
                            values[.idCard] = .idCard(SecureIdIDCardValue(identifier: document.identifier, issueDate: issueDate, expiryDate: document.expiryDate, verificationDocuments: verificationDocuments, selfieDocument: selfieDocument))
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
                    values[.address] = .address(SecureIdAddressValue(street1: details.street1, street2: details.street2, city: details.city, region: details.region, countryCode: details.countryCode, postcode: details.postcode))
                }
                if let document = address.document {
                    switch document {
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
    case birthdate
    case issueDate
    case expiryDate
    case deleteDocument
    case selfieHeader
    case selfie
    case addSelfie
    case selfieInfo
    
    case street1
    case street2
    case city
    case region
    case postcode
    
    case error
}

enum SecureIdDocumentFormEntryCategory {
    case identity
    case address
}

enum SecureIdDocumentFormEntry: FormControllerEntry {
    case scansHeader
    case scan(Int, SecureIdVerificationDocument)
    case addScan(Bool)
    case scansInfo(SecureIdDocumentFormEntryCategory)
    case infoHeader(SecureIdDocumentFormEntryCategory)
    case identifier(String)
    case firstName(String)
    case lastName(String)
    case gender(SecureIdGender?)
    case countryCode(String)
    case birthdate(SecureIdDate?)
    case issueDate(SecureIdDate?)
    case expiryDate(SecureIdDate?)
    case deleteDocument
    case selfieHeader
    case selfie(Int, SecureIdVerificationDocument)
    case addSelfie
    case selfieInfo
    case error(Int, String)
    
    case street1(String)
    case street2(String)
    case city(String)
    case region(String)
    case postcode(String)
    
    var stableId: SecureIdDocumentFormEntryId {
        switch self {
            case .scansHeader:
                return .scansHeader
            case let .scan(_, document):
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
            case .birthdate:
                return .birthdate
            case .issueDate:
                return .issueDate
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
            case .region:
                return .region
            case .postcode:
                return .postcode
            case .gender:
                return .gender
            case .selfieHeader:
                return .selfieHeader
            case .selfie:
                return .selfie
            case .addSelfie:
                return .addSelfie
            case .selfieInfo:
                return .selfieInfo
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
            case let .scan(lhsId, lhsDocument):
                if case let .scan(rhsId, rhsDocument) = to, lhsId == rhsId, lhsDocument.isEqual(to: rhsDocument) {
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
            case let .identifier(value):
                if case .identifier(value) = to {
                    return true
                } else {
                    return false
                }
            case let .firstName(value):
                if case .firstName(value) = to {
                    return true
                } else {
                    return false
                }
            case let .lastName(value):
                if case .lastName(value) = to {
                    return true
                } else {
                    return false
                }
            case let .gender(value):
                if case .gender(value) = to {
                    return true
                } else {
                    return false
                }
            case let .countryCode(value):
                if case .countryCode(value) = to {
                    return true
                } else {
                    return false
                }
            case let .birthdate(lhsValue):
                if case let .birthdate(rhsValue) = to, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .issueDate(lhsValue):
                if case let .issueDate(rhsValue) = to, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .expiryDate(lhsValue):
                if case let .expiryDate(rhsValue) = to, lhsValue == rhsValue {
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
            case let .street1(value):
                if case .street1(value) = to {
                    return true
                } else {
                    return false
                }
            case let .street2(value):
                if case .street2(value) = to {
                    return true
                } else {
                    return false
                }
            case let .city(value):
                if case .city(value) = to {
                    return true
                } else {
                    return false
                }
            case let .region(value):
                if case .region(value) = to {
                    return true
                } else {
                    return false
                }
            case let .postcode(value):
                if case .postcode(value) = to {
                    return true
                } else {
                    return false
                }
            case .selfieHeader:
                if case .selfieHeader = to {
                    return true
                } else {
                    return false
                }
            case let .selfie(index, document):
                if case .selfie(index, document) = to {
                    return true
                } else {
                    return false
                }
            case .addSelfie:
                if case .addSelfie = to {
                    return true
                } else {
                    return false
                }
            case .selfieInfo:
                if case .selfieInfo = to {
                    return true
                } else {
                    return false
                }
            case .error:
                if case .error = to {
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
            case let .scan(index, document):
                return SecureIdValueFormFileItem(account: params.account, context: params.context, document: document, title: "Scan \(index + 1)", activated: {
                    params.openDocument(document)
                })
            case let .addScan(hasAny):
                return FormControllerActionItem(type: .accent, title: hasAny ? "Upload More Scans" : "Upload Scan", fullTopInset: true, activated: {
                    params.addFile(.scan)
                })
            case let .scansInfo(type):
                let text: String
                switch type {
                    case .identity:
                        text = "The document must contain your photograph, name, surname, date of birth, citizenship, document issue date and document number."
                    case .address:
                        text = "The scans must contain proof of address."
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
            case let .identifier(value):
                return FormControllerTextInputItem(title: "ID", text: value, placeholder: "ID", textUpdated: { text in
                    params.updateText(.identifier, text)
                })
            case let .firstName(value):
                return FormControllerTextInputItem(title: "First Name", text: value, placeholder: "First Name", textUpdated: { text in
                    params.updateText(.firstName, text)
                })
            case let .lastName(value):
                return FormControllerTextInputItem(title: "Last Name", text: value, placeholder: "Last Name", textUpdated: { text in
                    params.updateText(.lastName, text)
                })
            case let .gender(value):
                var text = ""
                if let value = value {
                    switch value {
                        case .male:
                            text = "Male"
                        case .female:
                            text = "Female"
                    }
                }
                return FormControllerDetailActionItem(title: "Gender", text: text, placeholder: "Gender", activated: {
                    params.activateSelection(.gender)
                })
            case let .countryCode(value):
                return FormControllerDetailActionItem(title: "Country", text: AuthorizationSequenceCountrySelectionController.lookupCountryNameById(value.uppercased(), strings: strings) ?? "", placeholder: "Country", activated: {
                    params.activateSelection(.country)
                })
            case let .birthdate(value):
                return FormControllerDetailActionItem(title: "Date of Birth", text: value.flatMap({ stringForDate(timestamp: $0.timestamp, strings: strings) }) ?? "", placeholder: "Date of Birth", activated: {
                    params.activateSelection(.date(value?.timestamp, .birthdate))
                })
            case let .issueDate(value):
                return FormControllerDetailActionItem(title: "Issued", text: value.flatMap({ stringForDate(timestamp: $0.timestamp, strings: strings) }) ?? "", placeholder: "Issued", activated: {
                    params.activateSelection(.date(value?.timestamp, .issue))
                })
            case let .expiryDate(value):
                return FormControllerDetailActionItem(title: "Expires", text: value.flatMap({ stringForDate(timestamp: $0.timestamp, strings: strings) }) ?? "", placeholder: "Expires", activated: {
                    params.activateSelection(.date(value?.timestamp, .expiry))
                })
            case .deleteDocument:
                return FormControllerActionItem(type: .destructive, title: "Delete Document", activated: {
                    params.deleteValue()
                })
            case let .street1(value):
                return FormControllerTextInputItem(title: "Street 1", text: value, placeholder: "Street 1", textUpdated: { text in
                    params.updateText(.street1, text)
                })
            case let .street2(value):
                return FormControllerTextInputItem(title: "Street 2", text: value, placeholder: "Street 2", textUpdated: { text in
                    params.updateText(.street2, text)
                })
            case let .city(value):
                return FormControllerTextInputItem(title: "City", text: value, placeholder: "City", textUpdated: { text in
                    params.updateText(.city, text)
                })
            case let .region(value):
                return FormControllerTextInputItem(title: "Region", text: value, placeholder: "Region", textUpdated: { text in
                    params.updateText(.region, text)
                })
            case let .postcode(value):
                return FormControllerTextInputItem(title: "Postcode", text: value, placeholder: "Postcode", textUpdated: { text in
                    params.updateText(.postcode, text)
                })
            case .selfieHeader:
                return FormControllerHeaderItem(text: "SELFIE")
            case let .selfie(_, document):
                return SecureIdValueFormFileItem(account: params.account, context: params.context, document: document, title: "Selfie", activated: {
                    params.openDocument(document)
                })
            case .addSelfie:
                return FormControllerActionItem(type: .accent, title: "Upload Selfie", fullTopInset: true, activated: {
                    params.addFile(.selfie)
                })
            case .selfieInfo:
                return FormControllerTextItem(text: "Take a selfie picture with youself holding the document.")
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
                strongSelf.updateInnerState(transition: .immediate, with: innerState)
            }
        }, activateSelection: { [weak self] field in
            if let strongSelf = self {
                switch field {
                    case .country:
                        let controller = AuthorizationSequenceCountrySelectionController(strings: strings, theme: defaultLightAuthorizationTheme, displayCodes: false)
                        controller.completeWithCountryCode = { _, id in
                            if let strongSelf = self, var innerState = strongSelf.innerState {
                                innerState.documentState.updateCountryCode(value: id)
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
                        controller.setItemGroups([
                            ActionSheetItemGroup(items: [
                                ActionSheetButtonItem(title: "Male", action: {
                                    dismissAction()
                                    if let strongSelf = self, var innerState = strongSelf.innerState {
                                        innerState.documentState.updateGenderField(type: .gender, value: .male)
                                        strongSelf.updateInnerState(transition: .immediate, with: innerState)
                                    }
                                }),
                                ActionSheetButtonItem(title: "Female", action: {
                                    dismissAction()
                                    if let strongSelf = self, var innerState = strongSelf.innerState {
                                        innerState.documentState.updateGenderField(type: .gender, value: .female)
                                        strongSelf.updateInnerState(transition: .immediate, with: innerState)
                                    }
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
                strongSelf.updateInnerState(transition: .immediate, with: innerState)
            }
        }
    }
    
    deinit {
        self.actionDisposable.dispose()
    }
    
    private func presentAssetPicker(_ type: AddFileTarget) {
        let _ = legacyAssetPicker(theme: self.theme, fileMode: true, peer: nil, saveEditedPhotos: false, allowGrouping: false).start(next: { [weak self] generator in
            if let strongSelf = self {
                let legacyController = LegacyController(presentation: .modal(animateIn: true), theme: strongSelf.theme, initialLayout: strongSelf.layoutState?.layout)
                legacyController.statusBar.statusBarStyle = strongSelf.theme.rootController.statusBar.style.style
                let controller = generator(legacyController.context)
                legacyController.bind(controller: controller)
                legacyController.deferScreenEdgeGestures = [.top]
                
                controller.captionsEnabled = false
                controller.inhibitDocumentCaptions = true
                controller.suggestionContext = nil
                controller.dismissalBlock = {
                    
                }
                controller.localMediaCacheEnabled = false
                controller.shouldStoreAssets = false
                controller.shouldShowFileTipIfNeeded = false
                
                controller.descriptionGenerator = legacyAssetPickerItemGenerator()
                controller.completionBlock = { [weak legacyController] signals in
                    if let strongSelf = self, let legacyController = legacyController {
                        legacyController.dismiss()
                        let _ = (legacyAssetPickerDataSignals(account: strongSelf.account, signals: signals!)
                        |> deliverOnMainQueue).start(next: { resources in
                            if let strongSelf = self {
                                strongSelf.addDocuments(type: type, resources: resources)
                            }
                        })
                    }
                }
                controller.dismissalBlock = { [weak legacyController] in
                    if let legacyController = legacyController {
                        legacyController.dismiss()
                    }
                }
                strongSelf.view.endEditing(true)
                strongSelf.present(legacyController, nil)
            }
        })
    }
    
    private func addDocuments(type: AddFileTarget, resources: [TelegramMediaResource]) {
        guard var innerState = self.innerState else {
            return
        }
        switch type {
            case .scan:
                for resource in resources {
                    let id = arc4random64()
                    innerState.documents.append(.local(SecureIdVerificationLocalDocument(id: id, resource: resource, state: .uploading(0.0))))
                }
            case .selfie:
                loop: for resource in resources {
                    let id = arc4random64()
                    innerState.selfieDocument = .local(SecureIdVerificationLocalDocument(id: id, resource: resource, state: .uploading(0.0)))
                    break loop
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
            saveValues.append(saveSecureIdValue(network: self.account.network, context: self.context, value: value))
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
        |> deliverOnMainQueue).start(next: { [weak self] result in
            if let strongSelf = self {
                strongSelf.completedWithValues?([])
            }
        }, error: { [weak self] error in
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
            entries.append(SecureIdDocumentGalleryEntry(index: Int32(index), resource: selfieDocument.resource, location: SecureIdDocumentGalleryEntryLocation(position: Int32(index), totalCount: 1)))
            centralIndex = index
            index += 1
        } else {
            for itemDocument in innerState.documents {
                entries.append(SecureIdDocumentGalleryEntry(index: Int32(index), resource: itemDocument.resource, location: SecureIdDocumentGalleryEntryLocation(position: Int32(index), totalCount: Int32(innerState.documents.count))))
                if document.id == itemDocument.id {
                    centralIndex = index
                }
                index += 1
            }
        }
        
        let galleryController = SecureIdDocumentGalleryController(account: self.account, context: self.context, entries: entries, centralIndex: centralIndex, replaceRootController: { _, _ in
            
        })
        self.hiddenItemDisposable.set((galleryController.hiddenMedia |> deliverOnMainQueue).start(next: { [weak self] entry in
            guard let strongSelf = self else {
                return
            }
            for itemNode in strongSelf.itemNodes {
                if let itemNode = itemNode as? SecureIdValueFormFileItemNode, let item = itemNode.item {
                    if let entry = entry, item.document.resource.isEqual(to: entry.resource) {
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
                if let itemNode = itemNode as? SecureIdValueFormFileItemNode, let item = itemNode.item {
                    if item.document.resource.isEqual(to: entry.resource) {
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
