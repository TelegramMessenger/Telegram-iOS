import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore

enum SecureIdDocumentFormRequestedData {
    case identity(details: Bool, document: SecureIdRequestedIdentityDocument?, selfie: Bool)
    case address(details: Bool, document: SecureIdRequestedAddressDocument?)
}

final class SecureIdDocumentFormController: FormController<SecureIdDocumentFormState, SecureIdDocumentFormControllerNodeInitParams, SecureIdDocumentFormControllerNode> {
    private let account: Account
    private var presentationData: PresentationData
    private let updatedValues: ([SecureIdValueWithContext]) -> Void
    
    private let context: SecureIdAccessContext
    private let requestedData: SecureIdDocumentFormRequestedData
    private var values: [SecureIdValueWithContext]
    
    private var doneItem: UIBarButtonItem?
    
    init(account: Account, context: SecureIdAccessContext, requestedData: SecureIdDocumentFormRequestedData, values: [SecureIdValueWithContext], updatedValues: @escaping ([SecureIdValueWithContext]) -> Void) {
        self.account = account
        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        self.context = context
        self.requestedData = requestedData
        self.values = values
        self.updatedValues = updatedValues
        
        super.init(initParams: SecureIdDocumentFormControllerNodeInitParams(account: account, context: context), presentationData: self.presentationData)
        
        switch requestedData {
            case let .identity(_, document, _):
                if let document = document {
                    switch document {
                        case .passport:
                            self.title = "Passport"
                        case .internalPassport:
                            self.title = "Internal Passport"
                        case .driversLicense:
                            self.title = "Driver's License"
                        case .idCard:
                            self.title = "ID Card"
                    }
                } else {
                    self.title = "Personal Details"
                }
            case let .address(_, document):
                if let document = document {
                    switch document {
                        case .passportRegistration:
                            self.title = "Passport Registration"
                        case .temporaryRegistration:
                            self.title = "Temporary Registration"
                        case .utilityBill:
                            self.title = "Utility Bill"
                        case .bankStatement:
                            self.title = "Bank Statement"
                        case .rentalAgreement:
                            self.title = "Rental Agreement"
                    }
                } else {
                    self.title = "Address"
                }
        }
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Cancel, style: .plain, target: self, action: #selector(self.cancelPressed))
        
        self.doneItem = UIBarButtonItem(title: self.presentationData.strings.Common_Done, style: .done, target: self, action: #selector(self.donePressed))
        self.navigationItem.rightBarButtonItem = doneItem
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
    }
    
    @objc private func cancelPressed() {
        self.dismiss()
    }
    
    @objc private func donePressed() {
        self.controllerNode.save()
    }
    
    override func displayNodeDidLoad() {
        super.displayNodeDidLoad()
        
        self.controllerNode.actionInputStateUpdated = { [weak self] state in
            if let strongSelf = self {
                switch state {
                    case .inProgress:
                        strongSelf.navigationItem.rightBarButtonItem = UIBarButtonItem(customDisplayNode: ProgressNavigationButtonNode(theme: strongSelf.presentationData.theme))
                    case .saveAvailable, .saveNotAvailable:
                        if strongSelf.navigationItem.rightBarButtonItem !== strongSelf.doneItem {
                            strongSelf.navigationItem.rightBarButtonItem = strongSelf.doneItem
                        }
                        if case .saveAvailable = state {
                            strongSelf.doneItem?.isEnabled = true
                        } else {
                            strongSelf.doneItem?.isEnabled = false
                        }
                }
            }
        }
        
        self.controllerNode.completedWithValues = { [weak self] values in
            if let strongSelf = self {
                strongSelf.updatedValues(values ?? [])
                strongSelf.dismiss()
            }
        }
        
        self.controllerNode.dismiss = { [weak self] in
            self?.dismiss()
        }
        
        var values: [SecureIdValueKey: SecureIdValueWithContext] = [:]
        for value in self.values {
            values[value.value.key] = value
        }
        self.controllerNode.updateInnerState(transition: .immediate, with: SecureIdDocumentFormState(requestedData: self.requestedData, values: values))
    }
}
