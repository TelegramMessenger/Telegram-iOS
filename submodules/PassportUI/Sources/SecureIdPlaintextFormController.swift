import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import ProgressNavigationButtonNode
import AccountContext

public enum SecureIdPlaintextFormType {
    case phone
    case email
}

public final class SecureIdPlaintextFormController: FormController<SecureIdPlaintextFormInnerState, SecureIdPlaintextFormControllerNodeInitParams, SecureIdPlaintextFormControllerNode> {
    private let context: AccountContext
    private var presentationData: PresentationData
    private let updatedValue: (SecureIdValueWithContext?) -> Void
    
    private let secureIdContext: SecureIdAccessContext
    private let type: SecureIdPlaintextFormType
    private var immediatelyAvailableValue: SecureIdValue?
    
    private var nextItem: UIBarButtonItem?
    private var doneItem: UIBarButtonItem?
    
    public init(context: AccountContext, secureIdContext: SecureIdAccessContext, type: SecureIdPlaintextFormType, immediatelyAvailableValue: SecureIdValue?, updatedValue: @escaping (SecureIdValueWithContext?) -> Void) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.secureIdContext = secureIdContext
        self.type = type
        self.immediatelyAvailableValue = immediatelyAvailableValue
        self.updatedValue = updatedValue
        
        super.init(initParams: SecureIdPlaintextFormControllerNodeInitParams(context: context, secureIdContext: secureIdContext), presentationData: self.presentationData)
        
        self.navigationPresentation = .modal
        
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
    
    required public init(coder aDecoder: NSCoder) {
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
    
    override public func displayNodeDidLoad() {
        super.displayNodeDidLoad()
        
        self.controllerNode.actionInputStateUpdated = { [weak self] state in
            if let strongSelf = self {
                switch state {
                    case .inProgress:
                        strongSelf.navigationItem.rightBarButtonItem = UIBarButtonItem(customDisplayNode: ProgressNavigationButtonNode(color: strongSelf.presentationData.theme.rootController.navigationBar.controlColor))
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
    
    public func applyPhoneCode(_ code: Int) {
        self.controllerNode.applyPhoneCode(code)
    }
}
