import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore

enum SecureIdPlaintextFormType {
    case phone
    case email
}

final class SecureIdPlaintextFormController: FormController<SecureIdPlaintextFormInnerState, SecureIdPlaintextFormControllerNodeInitParams, SecureIdPlaintextFormControllerNode> {
    private let account: Account
    private var presentationData: PresentationData
    private let updatedValue: (SecureIdValueWithContext?) -> Void
    
    private let context: SecureIdAccessContext
    private let type: SecureIdPlaintextFormType
    private var immediatelyAvailableValue: SecureIdValue?
    
    private var nextItem: UIBarButtonItem?
    private var doneItem: UIBarButtonItem?
    
    init(account: Account, context: SecureIdAccessContext, type: SecureIdPlaintextFormType, immediatelyAvailableValue: SecureIdValue?, updatedValue: @escaping (SecureIdValueWithContext?) -> Void) {
        self.account = account
        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        self.context = context
        self.type = type
        self.immediatelyAvailableValue = immediatelyAvailableValue
        self.updatedValue = updatedValue
        
        super.init(initParams: SecureIdPlaintextFormControllerNodeInitParams(account: account, context: context), presentationData: self.presentationData)
        
        switch type {
            case .phone:
                self.title = self.presentationData.strings.Passport_Phone_Title
            case .email:
                self.title = self.presentationData.strings.Passport_Email_Title
        }
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Cancel, style: .plain, target: self, action: #selector(self.cancelPressed))
        
        self.nextItem = UIBarButtonItem(title: self.presentationData.strings.Common_Next, style: .done, target: self, action: #selector(self.donePressed))
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
                    case .nextAvailable, .nextNotAvailable:
                        if strongSelf.navigationItem.rightBarButtonItem !== strongSelf.nextItem {
                            strongSelf.navigationItem.rightBarButtonItem = strongSelf.nextItem
                        }
                        if case .nextAvailable = state {
                            strongSelf.nextItem?.isEnabled = true
                        } else {
                            strongSelf.nextItem?.isEnabled = false
                        }
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
        
        self.controllerNode.completedWithValue = { [weak self] valueWithContext in
            if let strongSelf = self {
                strongSelf.updatedValue(valueWithContext)
                strongSelf.dismiss()
            }
        }
        
        self.controllerNode.dismiss = { [weak self] in
            self?.dismiss()
        }
        
        self.controllerNode.updateInnerState(transition: .immediate, with: SecureIdPlaintextFormInnerState(type: self.type, immediatelyAvailableValue: self.immediatelyAvailableValue))
    }
    
    func applyPhoneCode(_ code: Int) {
        self.controllerNode.applyPhoneCode(code)
    }
}
