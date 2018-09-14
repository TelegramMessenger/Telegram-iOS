import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore

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

func documentSelectionItemsForField(field: SecureIdParsedRequestedFormField, strings: PresentationStrings) -> [(String, SecureIdDocumentFormRequestedData)] {
    switch field {
        case let .identity(personalDetails, document, selfie, translation):
            var result: [(String, SecureIdDocumentFormRequestedData)] = []
            if let document = document {
                switch document {
                    case let .just(type):
                        result.append((stringForDocumentType(type, strings: strings), .identity(details: personalDetails, document: type, selfie: selfie, translations: translation)))
                    case let .oneOf(types):
                        for type in types.sorted(by: { $0.rawValue < $1.rawValue }) {
                            result.append((stringForDocumentType(type, strings: strings), .identity(details: personalDetails, document: type, selfie: selfie, translations: translation)))
                        }
                }
            } else if let personalDetails = personalDetails {
                result.append((strings.Passport_Identity_TypePersonalDetails, .identity(details: personalDetails, document: nil, selfie: false, translations: false)))
            }
            return result
        case let .address(addressDetails, document, translations):
            var result: [(String, SecureIdDocumentFormRequestedData)] = []
            if let document = document {
                switch document {
                    case let .just(type):
                        result.append((stringForDocumentType(type, strings: strings), .address(details: addressDetails, document: type, translations: translations)))
                    case let .oneOf(types):
                        for type in types.sorted(by: { $0.rawValue < $1.rawValue }) {
                            result.append((stringForDocumentType(type, strings: strings), .address(details: addressDetails, document: type, translations: translations)))
                        }
                }
            } else if addressDetails {
                result.append((strings.Passport_Address_TypeResidentialAddress, .address(details: true, document: nil, translations: false)))
            }
            return result
        default:
            return []
    }
}

final class SecureIdDocumentTypeSelectionController: ActionSheetController {
    private let theme: PresentationTheme
    private let strings: PresentationStrings
    private let completion: (SecureIdDocumentFormRequestedData) -> Void
    
    private let _ready = Promise<Bool>()
    override var ready: Promise<Bool> {
        return self._ready
    }
    
    init(theme: PresentationTheme, strings: PresentationStrings, field: SecureIdParsedRequestedFormField, currentValues: [SecureIdValueWithContext], completion: @escaping (SecureIdDocumentFormRequestedData) -> Void) {
        self.theme = theme
        self.strings = strings
        self.completion = completion
        
        super.init(theme: ActionSheetControllerTheme(presentationTheme: theme))
        
        self._ready.set(.single(true))
        
        var items: [ActionSheetItem] = []
        for (title, data) in documentSelectionItemsForField(field: field, strings: strings) {
            items.append(ActionSheetButtonItem(title: title, action: { [weak self] in
                self?.dismissAnimated()
                completion(data)
            }))
        }
        self.setItemGroups([
            ActionSheetItemGroup(items: items),
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: strings.Common_Cancel, action: { [weak self] in
                    self?.dismissAnimated()
                }),
            ])
        ])
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
