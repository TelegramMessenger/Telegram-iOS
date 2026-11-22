import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import AccountContext

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
        case let .identity(personalDetails, document):
            var result: [(String, SecureIdDocumentFormRequestedData)] = []
            if let document = document {
                switch document {
                    case let .just(type):
                        result.append((stringForDocumentType(type.document, strings: strings), .identity(details: personalDetails, document: type.document, selfie: type.selfie, translations: type.translation)))
                    case let .oneOf(types):
                        for type in types.sorted(by: { $0.document.rawValue < $1.document.rawValue }) {
                            result.append((stringForDocumentType(type.document, strings: strings), .identity(details: personalDetails, document: type.document, selfie: type.selfie, translations: type.translation)))
                        }
                }
            } else if let personalDetails = personalDetails {
                result.append((strings.Passport_Identity_TypePersonalDetails, .identity(details: personalDetails, document: nil, selfie: false, translations: false)))
            }
            return result
        case let .address(addressDetails, document):
            var result: [(String, SecureIdDocumentFormRequestedData)] = []
            if let document = document {
                switch document {
                    case let .just(type):
                        result.append((stringForDocumentType(type.document, strings: strings), .address(details: addressDetails, document: type.document, translations: type.translation)))
                    case let .oneOf(types):
                        for type in types.sorted(by: { $0.document.rawValue < $1.document.rawValue }) {
                            result.append((stringForDocumentType(type.document, strings: strings), .address(details: addressDetails, document: type.document, translations: type.translation)))
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
    private var presentationDisposable: Disposable?
    private let completion: (SecureIdDocumentFormRequestedData) -> Void
    
    private let _ready = Promise<Bool>()
    override var ready: Promise<Bool> {
        return self._ready
    }
    
    init(context: AccountContext, field: SecureIdParsedRequestedFormField, currentValues: [SecureIdValueWithContext], completion: @escaping (SecureIdDocumentFormRequestedData) -> Void) {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let strings = presentationData.strings
        
        self.completion = completion
        
        super.init(theme: ActionSheetControllerTheme(presentationData: presentationData))
        
        self.presentationDisposable = context.sharedContext.presentationData.start(next: { [weak self] presentationData in
            if let strongSelf = self {
                strongSelf.theme = ActionSheetControllerTheme(presentationData: presentationData)
            }
        })
        
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
    
    deinit {
        self.presentationDisposable?.dispose()
    }
}
