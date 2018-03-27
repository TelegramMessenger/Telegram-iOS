import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore

enum SecureIdIdentityFormType {
    case passport
}

final class SecureIdIdentityFormController: FormController<SecureIdIdentityFormState, SecureIdIdentityFormControllerNode> {
    private let account: Account
    private var presentationData: PresentationData
    private let updatedValue: (SecureIdIdentityValue?) -> Void
    
    private let context: SecureIdAccessContext
    private let type: SecureIdIdentityFormType
    private var value: SecureIdIdentityValue?
    
    private var doneItem: UIBarButtonItem?
    
    init(account: Account, context: SecureIdAccessContext, type: SecureIdIdentityFormType, value: SecureIdIdentityValue?, updatedValue: @escaping (SecureIdIdentityValue?) -> Void) {
        self.account = account
        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        self.context = context
        self.type = type
        self.value = value
        self.updatedValue = updatedValue
        
        super.init(presentationData: self.presentationData)
        
        self.title = self.presentationData.strings.SecureId_Title
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
        self.controllerNode.verify()
    }
}
