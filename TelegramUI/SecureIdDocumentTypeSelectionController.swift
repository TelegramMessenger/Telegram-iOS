import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore

private func itemsForField(field: SecureIdParsedRequestedFormField, strings: PresentationStrings) -> [(String, SecureIdDocumentFormRequestedData)] {
    switch field {
        case let .identity(personalDetails, document, selfie):
            var result: [(String, SecureIdDocumentFormRequestedData)] = []
            if document.contains(.passport) {
                result.append(("Passport", .identity(details: personalDetails, document: .passport, selfie: selfie)))
            }
            if document.contains(.driversLicense) {
                result.append(("Driver's License", .identity(details: personalDetails, document: .driversLicense, selfie: selfie)))
            }
            if document.contains(.idCard) {
                result.append(("ID Card", .identity(details: personalDetails, document: .idCard, selfie: selfie)))
            }
            return result
        case let .address(addressDetails, document):
            var result: [(String, SecureIdDocumentFormRequestedData)] = []
            if document.contains(.utilityBill) {
                result.append(("Utility Bill", .address(details: addressDetails, document: .utilityBill)))
            }
            if document.contains(.bankStatement) {
                result.append(("Bank Statement", .address(details: addressDetails, document: .bankStatement)))
            }
            if document.contains(.rentalAgreement) {
                result.append(("Rental Agreement", .address(details: addressDetails, document: .rentalAgreement)))
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
        for (title, data) in itemsForField(field: field, strings: strings) {
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
