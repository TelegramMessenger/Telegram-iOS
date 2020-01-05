import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import SyncCore
import SwiftSignalKit
import TelegramPresentationData
import ProgressNavigationButtonNode
import AccountContext
import AlertUI
import PresentationDataUtils
import CountrySelectionUI
import PhoneNumberFormat

final class ChangePhoneNumberController: ViewController {
    private var controllerNode: ChangePhoneNumberControllerNode {
        return self.displayNode as! ChangePhoneNumberControllerNode
    }
    
    private let context: AccountContext
    
    private var currentData: (Int32, String?, String)?
    private let requestDisposable = MetaDisposable()
    
    var inProgress: Bool = false {
        didSet {
            if self.inProgress {
                let item = UIBarButtonItem(customDisplayNode: ProgressNavigationButtonNode(color: self.presentationData.theme.rootController.navigationBar.accentTextColor))
                self.navigationItem.rightBarButtonItem = item
            } else {
                self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Next, style: .done, target: self, action: #selector(self.nextPressed))
            }
            self.controllerNode.inProgress = self.inProgress
        }
    }
    var loginWithNumber: ((String) -> Void)?
    
    private let hapticFeedback = HapticFeedback()
    
    private var presentationData: PresentationData
    
    init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
        
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        
        self.title = self.presentationData.strings.ChangePhoneNumberNumber_Title
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Next, style: .done, target: self, action: #selector(self.nextPressed))
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.requestDisposable.dispose()
    }
    
    func updateData(countryCode: Int32, countryName: String, number: String) {
        if self.currentData == nil || self.currentData! != (countryCode, countryName, number) {
            self.currentData = (countryCode, countryName, number)
            if self.isNodeLoaded {
                self.controllerNode.codeAndNumber = (countryCode, countryName, number)
            }
        }
    }
    
    override public func loadDisplayNode() {
        self.displayNode = ChangePhoneNumberControllerNode(presentationData: self.presentationData)
        self.displayNodeDidLoad()
        self.controllerNode.selectCountryCode = { [weak self] in
            if let strongSelf = self {
                let controller = AuthorizationSequenceCountrySelectionController(strings: strongSelf.presentationData.strings, theme: strongSelf.presentationData.theme)
                controller.completeWithCountryCode = { code, name in
                    if let strongSelf = self {
                        strongSelf.updateData(countryCode: Int32(code), countryName: name, number: strongSelf.controllerNode.codeAndNumber.2)
                        strongSelf.controllerNode.activateInput()
                    }
                }
                strongSelf.controllerNode.view.endEditing(true)
                strongSelf.push(controller)
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.controllerNode.activateInput()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.controllerNode.activateInput()
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: 0.0, transition: transition)
    }
    
    @objc func nextPressed() {
        let (code, _, number) = self.controllerNode.codeAndNumber
        var phoneNumber = number
        if let code = code {
            phoneNumber = "\(code)\(phoneNumber)"
        }
        if !number.isEmpty {
            self.inProgress = true
            self.requestDisposable.set((requestChangeAccountPhoneNumberVerification(account: self.context.account, phoneNumber: self.controllerNode.currentNumber) |> deliverOnMainQueue).start(next: { [weak self] next in
                if let strongSelf = self {
                    strongSelf.inProgress = false
                    (strongSelf.navigationController as? NavigationController)?.pushViewController(changePhoneNumberCodeController(context: strongSelf.context, phoneNumber: strongSelf.controllerNode.currentNumber, codeData: next))
                }
            }, error: { [weak self] error in
                if let strongSelf = self {
                    strongSelf.inProgress = false
                    
                    let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                
                    let text: String
                    switch error {
                        case .limitExceeded:
                            text = presentationData.strings.Login_CodeFloodError
                        case .invalidPhoneNumber:
                            text = presentationData.strings.Login_InvalidPhoneError
                        case .phoneNumberOccupied:
                            text = presentationData.strings.ChangePhone_ErrorOccupied(formatPhoneNumber(phoneNumber)).0
                        case .generic:
                            text = presentationData.strings.Login_UnknownError
                    }
                    
                    strongSelf.present(textAlertController(context: strongSelf.context, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                }
            }))
        } else {
            self.hapticFeedback.error()
            self.controllerNode.animateError()
        }
    }
}
